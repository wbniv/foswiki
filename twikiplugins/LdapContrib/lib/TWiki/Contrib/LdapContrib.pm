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

package TWiki::Contrib::LdapContrib;

use strict;
use Net::LDAP;
use Net::LDAP::Control::Paged;
use Net::LDAP::Constant qw(LDAP_SUCCESS LDAP_SIZELIMIT_EXCEEDED LDAP_CONTROL_PAGED);
use Digest::MD5 qw( md5_hex );
use Unicode::MapUTF8 qw(from_utf8 to_utf8);
use TWiki::Contrib::LdapContrib::Cache;

use vars qw($VERSION $RELEASE $sharedLdapContrib);

$VERSION = '$Rev$';
$RELEASE = 'v1.11';

=begin text

---+++ TWiki::Contrib::LdapContrib

General LDAP services for TWiki. This class encapsulates the TWiki-specific
means to integrate an LDAP directory service.  Used by TWiki::Users::LdapUser
for authentication, TWiki::Users::LdapUserMapping for group definitions and
TWiki::Plugins::LdapNgPlugin to interface general query services.

Typical usage:
<verbatim>
my $ldap = new TWiki::Contrib::LdapContrib;

my $result = $ldap->search(filter=>'mail=*@gmx*');
my $errorMsg = $ldap->getError();

my $count = $result->count();

my @entries = $result->sorted('sn');
my $entry = $result->entry(0);

my $value = $entry->get_value('cn');
my @emails = $entry->get_value('mail');
</verbatim>

=cut

=begin text

---+++ writeDebug($msg, $level) 

Method to write a debug messages. The $msg is only
written if the given current debug level is high enough
($level <= $TWiki::cfg{Ldap}{Debug}). The higher the 
debug level, the more verbose the debug output.

Debug output is written to STDERR.

=cut

sub writeDebug {
  my ($this, $msg, $level) = @_;

  $level ||= 1;

  print STDERR $msg."\n" if $level <= $this->{debug};
}


=begin text

---++++ new($session, host=>'...', base=>'...', ...) -> $ldap

Construct a new TWiki::Contrib::LdapContrib object

Possible options are:
   * host: ip address (or hostname) 
   * base: the base DN to use in searches
   * port: port address used when binding to the LDAP server
   * version: protocol version 
   * userBase: sub-tree DN of user accounts
   * groupBase: sub-tree DN of group definitions
   * loginAttribute: user login name attribute
   * loginFilter: filter to be used to find login accounts
   * groupAttribute: the group name attribute 
   * groupFilter: filter to be used to find groups
   * memberAttribute: the attribute that should be used to collect group members
   * bindDN: the dn to use when binding to the LDAP server
   * bindPassword: the password used when binding to the LDAP server
   * ssl: negotiate ssl when binding to the server

Options not passed to the constructor are taken from the global settings
in =lib/LocalSite.cfg=.

=cut

sub new {
  my $class = shift;
  my $session = shift;

  my $this = {
    ldap=>undef,# connect later
    error=>undef,
    debug=>$TWiki::cfg{Ldap}{Debug} || 0,
    host=>$TWiki::cfg{Ldap}{Host} || 'localhost',
    base=>$TWiki::cfg{Ldap}{Base} || '',
    port=>$TWiki::cfg{Ldap}{Port} || 389,
    version=>$TWiki::cfg{Ldap}{Version} || 3,

    userBase=>$TWiki::cfg{Ldap}{UserBase} 
      || $TWiki::cfg{Ldap}{BasePasswd} # DEPRECATED
      || $TWiki::cfg{Ldap}{Base} 
      || '',

    groupBase=>$TWiki::cfg{Ldap}{GroupBase} 
      || $TWiki::cfg{Ldap}{BaseGroup} # DEPRECATED
      || $TWiki::cfg{Ldap}{Base} 
      || '',

    loginAttribute=>$TWiki::cfg{Ldap}{LoginAttribute} || 'uid',


    wikiNameAttribute=>$TWiki::cfg{Ldap}{WikiNameAttributes} 
      || $TWiki::cfg{Ldap}{WikiNameAttribute} || 'cn',

    normalizeWikiName=>$TWiki::cfg{Ldap}{NormalizeWikiNames}
      || $TWiki::cfg{Ldap}{NormalizeWikiName},

    loginFilter=>$TWiki::cfg{Ldap}{LoginFilter} || 'objectClass=posixAccount',
    groupAttribute=>$TWiki::cfg{Ldap}{GroupAttribute} || 'cn',
    groupFilter=>$TWiki::cfg{Ldap}{GroupFilter} || 'objectClass=posixGroup',
    memberAttribute=>$TWiki::cfg{Ldap}{MemberAttribute} || 'memberUid',
    memberIndirection=>$TWiki::cfg{Ldap}{MemberIndirection} || 0,
    twikiGroupsBackoff=>$TWiki::cfg{Ldap}{TWikiGroupsBackoff} || 0,
    bindDN=>$TWiki::cfg{Ldap}{BindDN} || '',
    bindPassword=>$TWiki::cfg{Ldap}{BindPassword} || '',
    ssl=>$TWiki::cfg{Ldap}{SSL} || 0,
    mapGroups=>$TWiki::cfg{Ldap}{MapGroups} || 0,

    mailAttribute=>$TWiki::cfg{Ldap}{MailAttribute} || 'mail',

    exclude=>$TWiki::cfg{Ldap}{Exclude} || 
      'TWikiGuest, TWikiContributor, TWikiRegistrationAgent, TWikiAdminGroup, NobodyGroup',

    pageSize=>$TWiki::cfg{Ldap}{PageSize} || 200,
    isConnected=>0,
    @_
  };
  $this->{normalizeWikiName} = 1 unless defined $this->{normalizeWikiName};
  @{$this->{wikiNameAttributes}} = split(/,\s/, $this->{wikiNameAttribute});
  %{$this->{groupNames}} = (); # caches known groups
  $this->{cachedGroupNames} = 0; # flag to indicate that the cache is filled

  # create exclude map
  my %excludeMap = map {$_ => 1} split(/,\s/, $this->{exclude});
  $this->{excludeMap} = \%excludeMap;

  bless($this, $class);
  $this->writeDebug("constructed a new LdapContrib object");

  # init the ldap cache
  $this->{cache} = TWiki::Contrib::LdapContrib::Cache::init($session);

  return $this;
}

=begin text

---++++ getLdapContrib($session) -> $ldap

Returns a standard singleton TWiki::Contrib::LdapContrib object based on the site-wide
configuration. 

=cut

sub getLdapContrib {
  my $session = shift;

  if ($sharedLdapContrib) {
    $sharedLdapContrib->{cache} = TWiki::Contrib::LdapContrib::Cache::init($session);
  } else {
    $sharedLdapContrib = new TWiki::Contrib::LdapContrib($session);
  }
  return $sharedLdapContrib;
}

=begin text

---++++ connect($login, $passwd) -> $boolean

Connect to LDAP server. If a $login name and a $passwd is given then a bind is done.
Otherwise the communication is anonymous. You don't have to connect() explicitely
by calling this method. The methods below will do that automatically when needed.

=cut

sub connect {
  my ($this, $dn, $passwd) = @_;

  $this->writeDebug("called connect");
  $this->writeDebug("dn=$dn", 2) if $dn;
  $this->writeDebug("passwd=***", 2) if $passwd;

  $this->{ldap} = Net::LDAP->new($this->{host},
    port=>$this->{port},
    version=>$this->{version},
  );
  die $@ if $@;
  unless ($this->{ldap}) {
    $this->{error} = "failed to connect to $this->{host}";
    return 0;
  }

  # authenticated bind
  my $msg;
  if (defined($dn)) {
    die "illegal call to connect()" unless defined($passwd);
    $msg = $this->{ldap}->bind($dn, password=>$passwd);
    $this->writeDebug("bind for $dn");
  } 

  # proxy user 
  elsif ($this->{bindDN} && $this->{bindPassword}) {
    $this->writeDebug("proxy bind");
    $msg = $this->{ldap}->bind($this->{bindDN},password=>$this->{bindPassword});
  }
  
  # anonymous bind
  else {
    $this->writeDebug("anonymous bind");
    $msg = $this->{ldap}->bind;
  }

  $this->{isConnected} = ($this->checkError($msg) == LDAP_SUCCESS)?1:0;
  $this->writeDebug("failed to bind") unless $this->{isConnected};
  return $this->{isConnected};
}

=begin text

---++++ disconnect()

Unbind the LDAP object from the server. This method can be used to force
a reconnect and possibly rebind as a different user.

=cut

sub disconnect {
  my $this = shift;

  if (defined($this->{ldap}) && $this->{isConnected}) {
    $this->writeDebug("called disconnect()");

    $this->{ldap}->unbind();
    $this->{ldap} = undef;
    $this->{isConnected} = 0;
  }
}

=begin text

---++++ finish

finalize this ldap object.

=cut

sub finish {
  my $this = shift;
  TWiki::Contrib::LdapContrib::Cache::finish();
  $this->disconnect();
}


=begin text

---++++ checkError($msg) -> $errorCode

Private method to check a Net::LDAP::Message object for an error, sets
$ldap->{error} and returns the ldap error code. This method is called
internally whenever a message object is returned by the server. Use
$ldap->getError() to return the actual error message.

=cut

sub checkError {
  my ($this, $msg) = @_;

  my $code = $msg->code();
  if ($code == LDAP_SUCCESS) {
    $this->{error} = undef;
  } else {
    $this->{error} = $code.': '.$msg->error();
    $this->writeDebug($this->{error});
  } 
 
  return $code;
}

=begin text

---++++ getError() -> $errorMsg

Returns the error message of the last LDAP action or undef it no
error occured.

=cut

sub getError {
  my $this = shift;
  return $this->{error};
}


=begin text

---++++ getAccount($login) -> Net::LDAP::Entry object

Fetches an account entry from the database and returns a Net::LDAP::Entry
object on success and undef otherwise. Note, the login name is match against
the attribute defined in $ldap->{loginAttribute}. Account records are 
search using $ldap->{loginFilter} in the subtree defined by $ldap->{userBase}.

=cut

sub getAccount {
  my ($this, $login) = @_;

  $login = lc($login);
  $this->writeDebug("called getAccount($login)");
  return undef if $this->{excludeMap}{$login};

  my $filter = '(&('.$this->{loginFilter}.')('.$this->{loginAttribute}.'='.$login.'))';
  my $msg = $this->search(
    filter=>$filter, 
    base=>$this->{userBase}
  );
  unless ($msg) {
    $this->writeDebug("no such account");
    return undef;
  }
  if ($msg->count() != 1) {
    $this->{error} = 'Login invalid';
    $this->writeDebug($this->{error});
    return undef;
  }

  return $msg->entry(0);
}

=begin text

---++++ getAccount() -> $search

CAUTION this can get expensive, don't use.

Returns a Net::LDAP::Search object searching for all user accounts in the database.

=cut

sub getAccounts {
  my $this = shift;

  $this->writeDebug("called getAccounts()");
  return $this->search(
    filter=>$this->{loginFilter}, 
    base=>$this->{userBase}
  );
}


=begin text

---++++ getGroup($name) -> $entry

Returns the named group as a NET::LDAP::Entry object on success and undef otherwise.
Check the error message using $ldap->getError().

=cut

sub getGroup {
  my ($this, $wikiName) = @_;

  $this->writeDebug("called getGroup($wikiName)");
  return undef if $this->{excludeMap}{$wikiName};

  my $filter = '(&('.$this->{groupFilter}.')('.$this->{groupAttribute}.'='.$wikiName.'))';
  my $msg = $this->search(
    filter=>$filter, 
    base=>$this->{groupBase}
  );
  unless ($msg) {
    $this->writeDebug("no such group");
    return undef;
  }
  return $msg->entry(0);
}

=begin text

---++++ getGroups() -> $search

Returns a Net::LDAP::Search object searching for all groups defined in the database.

CAUTION: this can get expensive, if you are only interested in the groups' ids
the use getGroupNames()

=cut

sub getGroups {
  my $this = shift;

  $this->writeDebug("called getGroups()");
  return $this->search(
    filter=>$this->{groupFilter}, 
    base=>$this->{groupBase}
  );
}

=begin text

---++++ getGroupNames() -> @array

Returns a list of known group names.

=cut

sub getGroupNames {
  my $this = shift;

  return keys %{$this->{groupNames}} if $this->{cachedGroupNames};
  $this->{cachedGroupNames} = 1;

  $this->writeDebug("called getGroupNames()");

  my $groupAttribute = $this->{groupAttribute};
  my $msg = $this->search(
    filter=>$this->{groupFilter}, 
    base=>$this->{groupBase}, 
    attrs=>[$groupAttribute]
  );
  
  unless ($msg) {
    $this->writeDebug("nothing found");
    return undef;
  }

  while (my $entry = $msg->pop_entry()) {
    my $groupName = $entry->get_value($groupAttribute);
    $groupName = from_utf8(-string=>$groupName, -charset=>$TWiki::cfg{Site}{CharSet})
      unless $TWiki::cfg{Site}{CharSet} =~ /^utf-?8$/i;
    $this->{groupNames}{$groupName} = 1;
  }

  return keys %{$this->{groupNames}};
}

=begin text

---++++ isGroup($user) -> $boolean

check if a given user is an ldap group actually

=cut

sub isGroup {
  my ($this, $user) = @_;

  # may be called using a user object or a wikiName string
  my $wikiName = (ref $user)?$user->wikiName():$user;
  #$this->writeDebug("called isGroup($wikiName)");
  return undef if $this->{excludeMap}{$wikiName};

  $this->getGroupNames(); # populate cache
  return defined($this->{groupNames}{$wikiName})?1:0;
}


=begin text

---++++ search($filter, %args) -> $msg

Returns an Net::LDAP::Search object for the given query on success and undef
otherwise. If $args{base} is not defined $ldap->{base} is used.  If $args{scope} is not
defined 'sub' is used (searching down the subtree under $args{base}. If no $args{limit} is
set all matching records are returned.  The $attrs is a reference to an array
of all those attributes that matching entries should contain.  If no $args{attrs} is
defined all attributes are returned.

If undef is returned as an error occured use $ldap->getError() to get the
cleartext message of this search() operation.

Typical usage:
<verbatim>
my $result = $ldap->search(filter=>'uid=TestUser');
</verbatim>

=cut

sub search {
  my ($this, %args) = @_;

  $args{base} = $this->{base} unless $args{base};
  $args{scope} = 'sub' unless $args{scope};
  $args{limit} = 0 unless $args{limit};
  $args{attrs} = ['*'] unless $args{attrs};

  $args{filter} = to_utf8(-string=> $args{filter}, -charset=>$TWiki::cfg{Site}{CharSet})
    if $args{filter} && $TWiki::cfg{Site}{CharSet} !~ /^utf-?8$/i;

  if ($this->{debug}) {
    my $attrString = join(',', @{$args{attrs}});
    $this->writeDebug("called search(filter=$args{filter}, base=$args{base}, scope=$args{scope}, limit=$args{limit}, attrs=$attrString)");
  }

  $this->connect() unless $this->{ldap};
  my $msg = $this->{ldap}->search(%args);
  my $errorCode = $this->checkError($msg);

  # we set a limit so it is ok that it exceeds
  if ($args{limit} && $errorCode == LDAP_SIZELIMIT_EXCEEDED) {
    $this->writeDebug("limit exceeded");
    return $msg;
  }
  
  if ($errorCode != LDAP_SUCCESS) {
    $this->writeDebug("error in search: ".$this->getError());
    return undef;
  }
  if ($this->{debug}) {
    $this->writeDebug("found ".$msg->count." entries");
    $this->writeDebug("done search");
  }


  return $msg;
}

=begin text

---++++ cacheBlob($entry, $attribute, $refresh) -> $pubUrlPath

Takes an Net::LDAP::Entry and an $attribute name, and stores its value into a
file. Returns the pubUrlPath to it. This can be used to store binary large
objects like images (jpegPhotos) into the filesystem accessible to the httpd
which can serve it in return to the client browser. 

Filenames containing the blobs are named using a hash value that is generated
using its DN and the actual attribute name whose value is extracted from the 
database. If the blob already exists in the cache it is _not_ extracted once
again except the $refresh parameter is defined.

Typical usage:
<verbatim>
my $blobUrlPath = $ldap->cacheBlob($entry, $attr);
</verbatim>

=cut

sub cacheBlob {
  my ($this, $entry, $attr, $refresh) = @_;

  $this->writeDebug("called cacheBlob()");

  my $twikiWeb = &TWiki::Func::getTwikiWebname();
  my $dir = &TWiki::Func::getPubDir().'/'.$twikiWeb.'/LdapContrib';
  my $key = md5_hex($entry->dn().$attr);
  my $fileName = $dir.'/'.$key;

  if ($refresh || !-f $fileName) {
    $this->writeDebug("caching blob");
    my $value = $entry->get_value($attr);
    return undef unless defined $value;
    mkdir($dir, 0775) unless -e $dir;

    open (FILE, ">$fileName");
    binmode(FILE);
    print FILE $value;
    close (FILE);
  } else {
    $this->writeDebug("already got blob");
  }
  
  $this->writeDebug("done cacheBlob()");

  return &TWiki::Func::getPubUrlPath().'/'.$twikiWeb.'/LdapContrib/'.$key;
}

=begin text

---++++ getPageControl($size) -> $pageControl

Constructs a new page control object of type Net::LDAP::Control::Paged 
useful to do paged queries on large datasets.

# TODO: write a better api for paged results and move it out of _loadMapping
# to a place where it is reusable, e.g. an object of its own bundling
# the search, page and cookie bits.

=cut

sub getPageControl {
  my ($this, $size) = @_;

  $size ||= $this->{pageSize};

  return Net::LDAP::Control::Paged->new(size=>$size) 
}


1;
