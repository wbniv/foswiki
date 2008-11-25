# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006-2008 Michael Daum http://michaeldaumconsulting.com
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
use TWiki::Users::TopicUserMapping;
use TWiki::Contrib::LdapContrib;
use TWiki::Plugins;

use base 'TWiki::Users::TopicUserMapping';
use vars qw($isLoadedMapping);

=pod

---+++ TWiki::Users::LdapUserMapping

This class allows to use user names and groups stored in an LDAP
database within the wiki in a transparent way. This replaces the
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

  return $this;
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

=pod

---++++ addUser ($login, $wikiname, $password, $emails) -> $cUID

overrides and thus disables the SUPER method

=cut

sub addUser {
  my $this = shift;

  return $this->SUPER::addUser(@_)
    if $this->{ldap}{WikiGroupsBackoff};

  return '';
}

=begin 

---++++ getLoginName ($cUID) -> $login

Converts an internal cUID to that user's login
(undef on failure)

=cut

sub getLoginName {
  my ($this, $cUID) = @_;

  my $login = $cUID;

  # Remove the mapping id in case this is a subclass
  $login =~ s/$this->{mapping_id}// if $this->{mapping_id};

  use bytes;
  # Reverse the encoding used to generate cUIDs in login2cUID
  # use bytes to ignore character encoding
  $login =~ s/_([0-9a-f][0-9a-f])/chr(hex($1))/gei;
  no bytes;

  return $login;
}


=pod

---++++ getWikiName ($cUID) -> wikiname

Maps a canonical user name to a wikiname

=cut

sub getWikiName {
  my ($this, $cUID) = @_;

  $this->{ldap}->writeDebug("called LdapUserMapping::getWikiName($cUID)");
    
  my $loginName = $this->getLoginName($cUID);

  return $loginName if $this->isGroup($loginName);

  my $wikiName;

  unless ($this->{ldap}{excludeMap}{$loginName}) {
    $wikiName = $this->{ldap}->getWikiNameOfLogin($loginName); 
    $wikiName = undef if $wikiName eq '_unknown_';
  }

  unless ($wikiName) {

    # fallback
    $this->{ldap}->writeDebug("asking SUPER");
    $wikiName = $this->SUPER::getWikiName($cUID);

  # backoff if it does not know
  if (!defined($isGroup) && $this->{ldap}{WikiGroupsBackoff}) {
    $isGroup = $this->SUPER::isGroup($user) if ref $user;
    $isGroup = ($wikiName =~ /Group$/); # SMELL: api overdesign
  }

  # fallback fallback
  $wikiName ||= $loginName;


  $this->{ldap}->writeDebug("returning $wikiName");
  return $wikiName; 
}


=pod

---++++ userExists($cUID) -> $boolean

Determines if the user already exists or not. 

=cut

sub userExists {
  my ($this, $cUID) = @_;

  my $loginName = $this->getLoginName($cUID);
  my $wikiName = $this->{ldap}->getWikiNameOfLogin($loginName);

  return 1 if $wikiName;

  if ($this->{ldap}{WikiGroupsBackoff}) {
    return $this->SUPER::userExists($cUID);
  }

  return 0;
}

=pod

---++++ eachUser () -> listIterator of cUIDs

returns a list iterator for all known users

=cut

sub eachUser {
  my $this = shift;

  require TWiki::ListIterator;

  my @allLoginNames = $this->{ldap}->getAllLoginNames();
  my $ldapIter = new TWiki::ListIterator(@allLoginNames);

  return $ldapIter unless $this->{ldap}{WikiGroupsBackoff};

  my $backOffIter = $this->SUPER::eachUser(@_);
  my @list = ($ldapIter, $backOffIter);

  return new TWiki::AggregateIterator(\@list, 1);
}

=pod

---++++ eachGroup () -> listIterator of groupnames

returns a list iterator for all known groups

=cut

sub eachGroup {
  my ($this) = @_;

  require TWiki::ListIterator;

  my @groups = $this->getListOfGroups();

  return new TWiki::ListIterator(\@groups );
}

=pod

---++++ getListOfGroups( ) -> @listOfUserObjects

Get a list of groups defined in the LDAP database. If 
=wikiGroupsBackoff= is defined the set of LDAP and native groups will
merged whereas LDAP groups have precedence in case of a name clash.

=cut

sub getListOfGroups {
  my $this = shift;

  #$this->{ldap}->writeDebug("called getListOfGroups()");

  my %groups;
  

  return $this->SUPER::_getListOfGroups()
    unless $this->{ldap}{mapGroups};

  if ($this->{ldap}{wikiGroupsBackoff}) {
    %groups = map { $_ => 1 } @{$this->SUPER::_getListOfGroups()};
  } else {
    %groups = ();
  }
  my $groupNames = $this->{ldap}->getGroupNames();
  if ($groupNames) {
    foreach my $groupName (@$groupNames) {
      $groups{$groupName} = 1;
    }
  }
  #$this->{ldap}->writeDebug("got " . (scalar keys %groups) . " overall groups=".join(',',keys %groups));
  return keys %groups;
}


=pod

---++++ eachGroupMember ($groupName) ->  listIterator of cUIDs

returns a list iterator for all groups members

=cut

sub eachGroupMember {
  my ($this, $groupName) = @_;

  $this->{ldap}->writeDebug("called eachGroupMember($groupName)");
  return $this->SUPER::eachGroupMember($groupName) 
    unless $this->{ldap}{mapGroups};

  my $members = $this->{ldap}->getGroupMembers($groupName) || [];

  unless (@$members) {
    # fallback to wiki groups,
    # try also to find the SuperAdminGroup
    if ($this->{ldap}{WikiGroupsBackoff} 
      || $groupName eq $TWiki::cfg{SuperAdminGroup}) {
      return $this->SUPER::eachGroupMember($groupName);
    }
  }

  require TWiki::ListIterator;

  return new TWiki::ListIterator($members);
}

=pod

---++++ eachMembership ($cUID) -> listIterator of groups this user is in

returns a list iterator for all groups a user is in.

=cut

sub eachMembership {
  my ($this, $cUID) = @_;

  my @groups = $this->getListOfGroups();

  require TWiki::ListIterator;

  my $it = new TWiki::ListIterator( \@groups );
  $it->{filter} = sub {
    $this->isInGroup($cUID, $_[0]);
  };

  return $it;
}

=pod

---++++ isGroup($user) -> $boolean

Establish if a user object refers to a user group or not.
This returns true for the <nop>SuperAdminGroup or
the known LDAP groups. Finally, if =wikiGroupsBackoff= 
is set the native mechanism are used to check if $user is 
a group

=cut

sub isGroup {
  my ($this, $user) = @_;

  $this->{ldap}->writeDebug("called isGroup($user)");

  # may be called using a user object or a wikiName of a user
  my $wikiName = (ref $user)?$user->wikiName:$user;

  # special treatment for build-in groups
  return 1 if $wikiName eq $TWiki::cfg{SuperAdminGroup};

  my $isGroup;

  if ($this->{ldap}{mapGroups}) {
    # ask LDAP
    $isGroup = $this->{ldap}->isGroup($wikiName);
  }

  # backoff if it does not know
  if (!defined($isGroup) && $this->{ldap}{wikiGroupsBackoff}) {
    $isGroup = $this->SUPER::isGroup($user) if ref $user;
    $isGroup = ($wikiName =~ /Group$/); 
  }

  return $isGroup;
}

=pod

---++++ findUserByEmail( $email ) -> \@cUIDs
   * =$email= - email address to look up

Return a list of canonical user names for the users that have this email
registered with the password manager or the user mapping manager.

=cut

sub findUserByEmail {
  my ($this, $email) = @_;

  return $this->{ldap}->getLoginOfEmail($email);
}

=pod 

---++++ findUserByWikiName ($wikiName) -> list of cUIDs associated with that wikiname

See baseclass for documentation

=cut

sub findUserByWikiName {
  my ($this, $wikiName) = @_;

  my @users = ();

  if ($this->isGroup($wikiName)) {
    push @users, $wikiName;
  } else {
    my $loginName = $this->{ldap}->getLoginOfWikiName($wikiName);
    push @users, $this->login2cUID($loginName, 1) if $loginName;
  }

  return \@users;
}

=pod

---++++ handlesUser($cUID, $login, $wikiName) -> $boolean

Called by the TWiki::Users object to determine which loaded mapping
to use for a given user.

The user can be identified by any of $cUID, $login or $wikiName. Any of
these parameters may be undef, and they should be tested in order; cUID
first, then login, then wikiName. 

=cut

sub handlesUser {
  my ($this, $cUID, $login, $wikiName) = @_;

  return 1 if defined $cUID && $this->userExists($cUID);
  return 1 if defined $login && $this->{ldap}->getWikiNameOfLogin($login);
  return 1 if defined $wikiName && $this->{ldap}->getLoginOfWikiName($wikiName);

  return 0;
}

=pod

---++++ login2cUID($loginName, $dontcheck) -> $cUID

Convert a login name to the corresponding canonical user name. The
canonical name can be any string of 7-bit alphanumeric and underscore
characters, and must correspond 1:1 to the login name.
(undef on failure)

(if dontcheck is true, return a cUID for a nonexistant user too.
This is used for registration)

=cut

sub login2cUID {
  my ($this, $loginName, $dontcheck) = @_;

  unless ($dontcheck) {
    return undef unless $this->{ldap}->getWikiNameOfLogin($loginName);
  }

  return $this->{mapping_id}.TWiki::Users::mapLogin2cUID($loginName);
}


1;
