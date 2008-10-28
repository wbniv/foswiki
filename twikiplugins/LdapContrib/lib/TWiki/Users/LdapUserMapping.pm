# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2006 Michael Daum http://wikiring.com
# Portions Copyright (C) 2006 Spanlink Communications
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.

package TWiki::Users::LdapUserMapping;

use strict;
use Unicode::MapUTF8 qw(from_utf8);
use TWiki::Users::TWikiUserMapping;
use TWiki::Contrib::LdapContrib;
use TWiki::Contrib::LdapContrib::Cache;

use Net::LDAP::Constant qw(LDAP_SUCCESS LDAP_CONTROL_PAGED);

use vars qw($isLoadedMapping);

@TWiki::Users::LdapUserMapping::ISA = qw(TWiki::Users::TWikiUserMapping);

=pod

---+++ TWiki::Users::LdapUserMapping

This class allows to use user names and groups stored in an LDAP
database inside TWiki in a transparent way. This replaces TWiki's
native way to represent users and groups using topics with
according LDAP records.

=cut

=pod 

---++++ new($session) -> $ldapUserMapping

create a new TWiki::Users::LdapUserMapping object and constructs an <nop>LdapContrib
object to delegate LDAP services to.

=cut

sub new {
  my ($class, $session) = @_;

  my $this = bless($class->SUPER::new( $session ), $class);
  $this->{ldap} = &TWiki::Contrib::LdapContrib::getLdapContrib($session);

  $this->{maxCacheHits} = defined($TWiki::cfg{Ldap}{MaxCacheHits})?
    $TWiki::cfg{Ldap}{MaxCacheHits}:-1;

  return $this;
}

=pod

---++++ getListOfGroups( ) -> @listOfUserObjects

Get a list of groups defined in the LDAP database. If 
=twikiGroupsBackoff= is defined the set of LDAP and native groups will
merged whereas LDAP groups have precedence in case of a name clash.

=cut

sub getListOfGroups {
  my $this = shift;

  unless ($this->{ldap}{mapGroups}) {
    return $this->SUPER::getListOfGroups();
  }

  $this->{ldap}->writeDebug("called getListOfGroups()");
  my %groups;
  if ($this->{ldap}{twikiGroupsBackoff}) {
    %groups = map { $_->wikiName() => $_ } $this->SUPER::getListOfGroups();
  } else {
    %groups = ();
  }
  my $groupNames = $this->{ldap}{cache}{GROUPS};
  unless ($groupNames) {
    @{$groupNames} = $this->{ldap}->getGroupNames() unless $groupNames;
    $this->{ldap}{cache}{GROUPS} = $groupNames;
  }

  foreach my $groupName (@$groupNames) {
    $groups{$groupName} = $this->{session}->{users}->findUser($groupName, $groupName);
  }


  #$this->{ldap}->writeDebug("got " . (scalar keys %groups) . " overall groups=".join(',',keys %groups));

  return values %groups;
}

=pod 

---++++ groupMembers($group) -> @listOfTWikiUsers

Returns a list of all members of a given group. Members are 
TWiki::User objects.

=cut

sub groupMembers {
  my ($this, $group) = @_;

  unless ($this->{ldap}{mapGroups}) {
    return $this->SUPER::groupMembers($group);
  }

  unless (defined($group->{members})) {
    $this->{ldap}->writeDebug("called groupMembers(".$group->wikiName().")");

    my $members = $this->getGroupMembers($group->wikiName);
    if (defined($members)) {
      $group->{members} = [];
      #$this->{ldap}->writeDebug("found ".scalar(@$members)." members:".join(', ', @$members));
      foreach my $member (@$members) {
        my $memberUser = $this->{session}->{users}->findUser($member); ## provide the wikiName
        push @{$group->{members}}, $memberUser if $memberUser;
	push @{$memberUser->{groups}}, $group; # backlink the user to the group
      }
    } else {
      # fallback to twiki groups,
      # try also to find the SuperAdminGroup
      if ($this->{ldap}{twikiGroupsBackoff} 
        || $group->wikiName eq $TWiki::cfg{SuperAdminGroup}) {
        return $this->SUPER::groupMembers($group) || [];
      } else {
        $group->{members} = [];
      }
    }
  }

  return $group->{members};
}

=pod 

---++++ addUserToMapping($user, $me)

overrides and thus disables the SUPER method

=cut

sub addUserToMapping {
    my ( $this, $user, $me ) = @_;

    return '';
}

=pod

---++++ lookupLoginName($loginName) -> $wikiName

Map a loginName to the corresponding wikiName. This is used for lookups during
user resolution, and should be as fast as possible.

=cut

sub lookupLoginName {
  my ($this, $thisName) = @_;

  # no login names for groups
  return $thisName if $this->isGroup($thisName);

  $this->{ldap}->writeDebug("called lookupLoginName($thisName)");

  my $wikiName;
  # make all login names same case for LDAP
  my $name = lc($thisName);

  unless ($this->{ldap}{excludeMap}{$name}) {
    # load the mapping in parts as long as needed
    while (1) {
      $wikiName = $this->{ldap}{cache}{U2W}{$name};
      if (defined($wikiName) && $wikiName ne '_unknown_') {
	$this->{ldap}->writeDebug("found loginName in cache");
	return $wikiName;
      }
      $wikiName = $this->{ldap}{cache}{W2U}{$thisName};
      if (defined($wikiName)) {
	$this->{ldap}->writeDebug("hey, you called lookupLoginName with a wikiName");
	return undef;
      }
      last if $isLoadedMapping;
      $this->loadLdapMapping();
    }
  }

  # look it up
  $wikiName = $this->{ldap}{cache}{U2W}{$name};
  if (defined($wikiName) && $wikiName ne '_unknown_') {
    $this->{ldap}->writeDebug("found loginName in cache again");
    return $wikiName;
  }
  $wikiName = $this->{ldap}{cache}{W2U}{$thisName};
  if (defined($wikiName)) {
    $this->{ldap}->writeDebug("hey, you called lookupLoginName with a wikiName again");
    return undef;
  }
 
  # fallback
  $this->{ldap}->writeDebug("asking SUPER");
  $wikiName = $this->SUPER::lookupLoginName($thisName);
  
  unless ($wikiName) {
    $this->{ldap}->writeDebug("WOOPS, wikiName for $thisName not found");
    $wikiName = $thisName;
  }

  $wikiName =~ s/^(.*)\.(.*?)$/$2/;
  $this->{ldap}->writeDebug("got wikiName=$wikiName and loginName=$thisName");
  $this->{ldap}{cache}{U2W}{$name} = $wikiName;
  $this->{ldap}{cache}{W2U}{$wikiName} = $thisName;

  return $wikiName; 
}

=pod

---++++ lookupWikiName($wikiName) -> $loginName

Map a wikiName to the corresponding loginName. This is used for lookups during
user resolution, and should be as fast as possible.

=cut

sub lookupWikiName {
  my ($this, $wikiName) = @_;

  # removing leading web
  $wikiName =~ s/^.*\.(.*?)$/$1/o;

  # no login names for groups
  return $wikiName if $this->isGroup($wikiName);

  $this->{ldap}->writeDebug("called lookupWikiName($wikiName)");

  my $loginName;
  unless ($this->{ldap}{excludeMap}{$wikiName}) {
    while (1) {
      # load the mapping in parts as long as needed
      $loginName = $this->{ldap}{cache}{W2U}{$wikiName};
      if (defined($loginName) && $loginName ne '_unknown_') {
	$this->{ldap}->writeDebug("found wikiName in cache");
        return $loginName; 
      }
      $loginName = $this->{ldap}{cache}{U2W}{$wikiName};
      if (defined($loginName)) {
	$this->{ldap}->writeDebug("hey, you called lookupWikiName with a loginName");
        return undef;
      }
      last if $isLoadedMapping;
      $this->loadLdapMapping();
    }
  }

  # look it up
  $loginName = $this->{ldap}{cache}{W2U}{$wikiName};
  if (defined($loginName) && $loginName ne '_unknown_') {
    $this->{ldap}->writeDebug("found wikiName in cache again");
    return $loginName;
  }
  $loginName = $this->{ldap}{cache}{U2W}{$wikiName};
  if (defined($loginName)) {
    $this->{ldap}->writeDebug("hey, you called lookupWikiName with a loginName again");
    return undef;
  }

  # fallback
  $this->{ldap}->writeDebug("asking SUPER");
  $loginName = $this->SUPER::lookupWikiName($wikiName) || '_unknown_';
  $this->{ldap}->writeDebug("got wikiName=$wikiName and loginName=$loginName");
  $this->{ldap}{cache}{U2W}{$loginName} = $wikiName;
  $this->{ldap}{cache}{W2U}{$wikiName} = $loginName;

  return undef if $loginName eq '_unknown_';
  return $loginName;
}

=pod

---++++ lookupDistinguishedName($dn) -> $loginName

Map a DN to the corresponding loginName. This is used for getting
members of a group where their membership is stored as a DN but we need
the loginName.

=cut

sub lookupDistinguishedName {
  my ($this, $dn) = @_;

  $this->{ldap}->writeDebug("called lookupDistinguishedName($dn)");
  my $loginName = $this->{ldap}{cache}{DN2U}{$dn};
  return $loginName if $loginName;

  my $msg = $this->{ldap}->search(filter=>'objectClass=*', base=>$dn);
  my $errorCode;

  $errorCode = $this->{ldap}->checkError($msg) if $msg;
  if (!$msg || $errorCode != LDAP_SUCCESS) {
    $this->{ldap}->writeDebug("error in search: ".$this->{ldap}->getError());
    return undef;
  }

  my $entry = $msg->pop_entry();
  $loginName = $entry->get_value($this->{ldap}{loginAttribute});
  $loginName = $entry->get_value($this->{ldap}{groupAttribute}) unless $loginName;
  $loginName = from_utf8(-string=>$loginName, -charset=>$TWiki::cfg{Site}{CharSet})
    unless $TWiki::cfg{Site}{CharSet} =~ /^utf-?8$/i;

  $this->{ldap}{cache}{DN2U}{$dn} = $loginName;
  $this->{ldap}->writeDebug("found $loginName");

  return $loginName;
}

=pod

---++++ loadLdapMapping() -> $boolean

This is the workhorse of this module, loading user objects on demand
and harvest the needed information into internal caches.
Returns true if an additional page of results was fetched, and
false if the search result has been cached completely.

=cut

sub loadLdapMapping {
  my $this = shift;

  $this->{ldap}->writeDebug("called loadLdapMapping()");
  if ($isLoadedMapping) {
    $this->{ldap}->writeDebug("already loaded");
    return 0;
  } 
  $this->{ldap}->writeDebug("need to fetch mapping");

  # prepare search
  $this->{_page} = $this->{ldap}->getPageControl() 
    unless $this->{_page}; 

  my @args = (
    filter=>$this->{ldap}{loginFilter}, 
    base=>$this->{ldap}{userBase},
    attrs=>[$this->{ldap}{loginAttribute}, @{$this->{ldap}{wikiNameAttributes}}],
    control=>[$this->{_page}],
  );

  # do it
  my $mesg = $this->{ldap}->search(@args);
  unless ($mesg) {
    $this->{ldap}->writeDebug("oops, no result");
    $isLoadedMapping = 1;
  } else {

    # insert results into the mapping
    while (my $entry = $mesg->pop_entry()) {
      my $loginName = $entry->get_value($this->{ldap}{loginAttribute});
      my $dn = $entry->dn();
      $loginName = lc($loginName);
      $loginName = from_utf8(-string=>$loginName, -charset=>$TWiki::cfg{Site}{CharSet})
        unless $TWiki::cfg{Site}{CharSet} =~ /^utf-?8$/i;

      # construct the wikiName
      my $wikiName;
      foreach my $attr (@{$this->{ldap}{wikiNameAttributes}}) {
        my $value = $entry->get_value($attr);
        next unless $value;
        $value = from_utf8(-string=>$value, -charset=>$TWiki::cfg{Site}{CharSet})
          unless $TWiki::cfg{Site}{CharSet} =~ /^utf-?8$/i;

        unless ($this->{ldap}{normalizeWikiName}) {
          $wikiName .= $value;
          next;
        }

        # normalize the parts of the wikiName
        $value =~ s/@.*//o if $attr eq 'mail'; 
          # remove @mydomain.com part for special mail attrs
          # SMELL: you may have a different attribute name for the email address
        
        # replace umlaute
        $value =~ s/ä/ae/go;
        $value =~ s/ö/oe/go;
        $value =~ s/ü/ue/go;
        $value =~ s/Ä/Ae/go;
        $value =~ s/Ö/Oe/go;
        $value =~ s/Ü/Ue/go;
        $value =~ s/ß/ss/go;
        foreach my $part (split(/[^$TWiki::regex{mixedAlphaNum}]/, $value)) {
          $wikiName .= ucfirst($part);
        }
      }
      $wikiName ||= $loginName;

      $this->{ldap}->writeDebug("adding wikiName=$wikiName, loginName=$loginName");
      $this->{ldap}{cache}{U2W}{$loginName} = $wikiName;
      $this->{ldap}{cache}{W2U}{$wikiName} = $loginName;
      $this->{ldap}{cache}{DN2U}{$dn} = $loginName;
      $this->{ldap}{cache}{U2DN}{$loginName} = $dn;
    }

    # get cookie from paged control to remember the offset
    my ($resp) = $mesg->control(LDAP_CONTROL_PAGED);
    if ($resp) {

      $this->{_cookie} = $resp->cookie;
      if ($this->{_cookie}) {
        # set cookie in paged control
        $this->{_page}->cookie($this->{_cookie});
      } else {

        # found all
        #$this->{ldap}->writeDebug("ok, no more cookie");
        $isLoadedMapping = 1;
      }
    } else {

      # never reach
      $this->{ldap}->writeDebug("oops, no resp");
      $isLoadedMapping = 1;
    }
  }

  # clean up error cases
  if ($isLoadedMapping && $this->{_cookie}) {
    $this->{ldap}->writeDebug("cleaning up page");
    $this->{_page}->cookie($this->{_cookie});
    $this->{_page}->size(0);
    $this->{ldap}->search(@args);
    return 0;
  }

  if ($this->{ldap}{debug}) {
    $this->{ldap}->writeDebug("got ".
      scalar(keys %{$this->{ldap}{cache}{U2W}}).
      " keys in cache");
  }

  return 1;
}

=pod

---++++ getListOfAllWikiNames() -> @wikiNames

CAUTION: This function is rarely used if at all. Asking large LDAP directories
for all of their content is insane anyway.  This function gets called by the
=%<nop>GROUPS%= and the =%<nop>USERINFO{userdebug="1"}%= tags. These should be avoided,
i.e. better remove the =%<nop>GROUPS%= tag from the Main.TWikiGroups topic in such cases.
Better use a TWikiApplication build on top of the TWiki:Plugins/LdapNgPlugin
that is able to display groups and members in a paginated way.

=cut

sub getListOfAllWikiNames {
  my $this = shift;

  $this->{ldap}->writeDebug("called getListOfAllWikiNames");
  while($this->loadLdapMapping()) {}
  return keys %{$this->{ldap}{cache}{W2U}};
}

=pod

---++++ isGroup($user) -> $boolean

Establish if a user object refers to a user group or not.
This returns true for the <nop>SuperAdminGroup or
the known LDAP groups. Finally, if =twikiGroupsBackoff= 
is set the native mechanism are used to check if $user is 
a group

=cut

sub isGroup {
  my ($this, $user) = @_;

  # may be called using a user object or a wikiName of a user
  my $wikiName = (ref $user)?$user->wikiName:$user;

  $this->{ldap}->writeDebug("called isGroup($wikiName)");

  unless ($this->{ldap}{mapGroups}) {
    return $this->SUPER::isGroup($user) if ref $user;
    return $wikiName =~ /Group$/; # SMELL: api overdesign
  }

  # special treatment for build-in groups
  return 1 if $wikiName eq $TWiki::cfg{SuperAdminGroup};

  # check cache
  my $isGroup = $this->{ldap}{cache}{ISGROUP}{$wikiName};
  $isGroup = $this->{ldap}->isGroup($user) unless defined $isGroup;

  # backoff
  if (!defined($isGroup) && $this->{ldap}{twikiGroupsBackoff}) {
    $isGroup = $this->SUPER::isGroup($user) if ref $user;
    $isGroup = ($wikiName =~ /Group$/); # SMELL: api overdesign
  }
  $isGroup = ($isGroup)?1:0;
  $this->{ldap}{cache}{ISGROUP}{$wikiName} = $isGroup;

  $this->{ldap}->writeDebug("isGroup{$wikiName}=$isGroup");

  return $isGroup;
}

=pod

---++++ isMemberOf($user, $group) -> $boolean

Returns true if the $user is a member of the $group. Note, that both
$user and $group can either be a WikiName or a reference to a User object

=cut

sub isMemberOf {
    my ($this, $user, $group) = @_;

    unless ($this->{ldap}{mapGroups}) {
      # don't use ldap groups 
      return $this->SUPER::isMemberOf($user, $group);
    }

    # get names
    my $loginName;
    if (ref $user) {
      $loginName = $user->login;
    } else {
      $loginName = $this->lookupWikiName($user) || $user;
    }

    my $groupName = (ref $group)?$group->login:$group;
    return $this->SUPER::isMemberOf($user, $group) 
      if $this->{ldap}{excludeMap}{$loginName} || 
         $this->{ldap}{excludeMap}{$groupName};

    # get membership info
    my $isMemberOf = 0;
    my $groupMembers = $this->getGroupMembers($groupName);
    if ($groupMembers) {
      foreach my $member (@$groupMembers) {
        if ($member eq $loginName) {
          $isMemberOf = 1;
          last;
        }
      }
    }

    # backoff
    if (!$isMemberOf && $this->{ldap}{twikiGroupsBackoff}) {
      $isMemberOf = $this->SUPER::isMemberOf($user, $group);
    }

    return $isMemberOf;
}

=pod

---++++ getGroupMembers($name) -> \@members

Returns a list of user ids that are in a given group, undef if the group does
not exist.

=cut

sub getGroupMembers {
  my ($this, $groupName) = @_;

  $this->{ldap}->writeDebug("called getGroupMembers($groupName)");
  return undef if $this->{ldap}{excludeMap}{$groupName};

  my $members = $this->{ldap}{cache}{GROUPMEMBERS}{$groupName};
  if (defined $members) {
    $this->{ldap}->writeDebug("found members of $groupName in cache");
    return $members;
  }

  my $groupEntry = $this->{ldap}->getGroup($groupName);
  return undef unless $groupEntry;

  $this->{ldap}->writeDebug("this is an ldap group");

  # fetch all members
  my %members;
  foreach my $member ($groupEntry->get_value($this->{ldap}{memberAttribute})) {

    # groups may store DNs to members instead of a memberUid, in this case we
    # have to lookup the corresponding loginAttribute
    if ($this->{ldap}{memberIndirection}) {
      my $found = 0;
      $this->{ldap}->writeDebug("following indirection for $member");
      $member = $this->lookupDistinguishedName($member);
      unless ($member) {
        $this->{ldap}->writeDebug("oops, member not found");
        next;
      }
    }

    if ($this->isGroup($member)) {
      $this->{ldap}->writeDebug("adding members of group $member");
      foreach (@{$this->getGroupMembers($member)}) {
        $members{$_} = 1;
      }
    } else {
      $this->{ldap}->writeDebug("found member=$member");
      $members{$member} = 1;
    }
  }
  @{$members} = sort keys %members;

  $this->{ldap}{cache}{GROUPMEMBERS}{$groupName} = $members;
  return $members;
}


=pod

---++++ finish()

Complete processing after the client's HTTP request has been responded
to. I.e. it disconnects the LDAP database connection.

=cut

sub finish {
  my $this = shift;
    
  $this->{ldap}->finish() if $this->{ldap};
  $this->{ldap} = undef;
  $this->SUPER::finish();
}

1;
