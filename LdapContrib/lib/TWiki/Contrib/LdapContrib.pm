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

package TWiki::Contrib::LdapContrib;

use strict;
use Net::LDAP;
use Net::LDAP::Constant qw(LDAP_SUCCESS LDAP_SIZELIMIT_EXCEEDED LDAP_CONTROL_PAGED);
use Digest::MD5 qw(md5_hex);
use Unicode::MapUTF8 qw(from_utf8 to_utf8);
use DB_File;
use Net::LDAP::Control::Paged;
use TWiki::Func;

use vars qw($VERSION $RELEASE %sharedLdapContrib);

$VERSION = '$Rev$';
$RELEASE = 'v2.99.7';

=pod

---+++ TWiki::Contrib::LdapContrib

General LDAP services module. This class encapsulates the platform-specific
means to integrate an LDAP directory service.  Used by TWiki::Users::LdapPassword
for authentication, TWiki::Users::LdapUserMapping for group definitions and
TWiki::Plugins::LdapNgPlugin to interface general query services.

---+++ Typical usage
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

---+++ Cache storage format

The cache stores a series of key-value pairs in a DB_File. The following
keys are used:

   * WIKINAMES - list of all wikiNames
   * LOGINNAMES - list of all loginNames
   * GROUPS - list of all groups
   * GROUPS::$groupName - list of all loginNames in group groupName (membership)
   * EMAIL2U::$emailAddr - stores the loginName of an emailAddr
   * U2EMAIL::$loginName - stores the emailAddr of a loginName 
   * U2W::$loginName - stores the wikiName of a  loginName
   * W2U::$wikiName - stores the loginName of a wikiName
   * DN2U::$dn - stores the loginName of a distinguishedName
   * U2DN::$loginName - stores the distinguishedName of a loginName

=cut

=pod

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

  print STDERR "- LdapContrib - $msg\n" if $level <= $this->{debug};
}


=pod

---+++ writeWarning($msg, $level) 

Method to write a warning messages. Works also
if TWiki::Plugins::SESSION isn't initialized yet.

=cut

sub writeWarning {
  my ($this, $msg) = @_;

  my $session = $TWiki::Plugins::SESSION || $this->{session};
  if ($session) {
    $session->writeWarning("LdapContrib - $msg");
  } else {
    print STDERR "- LdapContrib - $msg\n";
  }
}


=pod

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
    allowChangePassword=>$TWiki::cfg{Ldap}{AllowChangePassword} || 0,

    wikiNameAttribute=>$TWiki::cfg{Ldap}{WikiNameAttributes} 
      || $TWiki::cfg{Ldap}{WikiNameAttribute} || 'cn',

    wikiNameAliases=>$TWiki::cfg{Ldap}{WikiNameAliases} || '',

    normalizeWikiName=>$TWiki::cfg{Ldap}{NormalizeWikiNames},
    normalizeLoginName=>$TWiki::cfg{Ldap}{NormalizeLoginNames},
    normalizeGroupName=>$TWiki::cfg{Ldap}{NormalizeGroupNames},

    loginFilter=>$TWiki::cfg{Ldap}{LoginFilter} || 'objectClass=posixAccount',

    groupAttribute=>$TWiki::cfg{Ldap}{GroupAttribute} || 'cn',
    primaryGroupAttribute=>$TWiki::cfg{Ldap}{PrimaryGroupAttribute} || '',
    groupFilter=>$TWiki::cfg{Ldap}{GroupFilter} || 'objectClass=posixGroup',
    memberAttribute=>$TWiki::cfg{Ldap}{MemberAttribute} || 'memberUid',
    memberIndirection=>$TWiki::cfg{Ldap}{MemberIndirection} || 0,
    wikiGroupsBackoff=>$TWiki::cfg{Ldap}{WikiGroupsBackoff} || 0,
    bindDN=>$TWiki::cfg{Ldap}{BindDN} || '',
    bindPassword=>$TWiki::cfg{Ldap}{BindPassword} || '',
    mapGroups=>$TWiki::cfg{Ldap}{MapGroups} || 0,

    mailAttribute=>$TWiki::cfg{Ldap}{MailAttribute} || 'mail',

    exclude=>$TWiki::cfg{Ldap}{Exclude} || 
      'WikiGuest, TWikiContributor, ProjectContributor, RegistrationAgent, AdminGroup, NobodyGroup',

    pageSize=>$TWiki::cfg{Ldap}{PageSize} || 200,
    isConnected=>0,
    maxCacheAge=>$TWiki::cfg{Ldap}{MaxCacheAge} || 86400,

    useSASL=>$TWiki::cfg{Ldap}{UseSASL} || 0,
    saslMechanism=>$TWiki::cfg{Ldap}{SASLMechanism} || 'PLAIN CRAM-MD4 EXTERNAL ANONYMOUS',

    useTLS=>$TWiki::cfg{Ldap}{UseTLS} || 0,
    tlsVerify=>$TWiki::cfg{Ldap}{TLSVerify} || 'require',
    tlsSSLVersion=>$TWiki::cfg{Ldap}{TLSSSLVersion} || 'tlsv1',
    tlsCAFile=>$TWiki::cfg{Ldap}{TLSCAFile} || '',
    tlsCAPath=>$TWiki::cfg{Ldap}{TLSCAPath} || '',
    tlsClientCert=>$TWiki::cfg{Ldap}{TLSClientCert} || '',
    tlsClientKey=>$TWiki::cfg{Ldap}{TLSClientKey} || '',

    secondaryPasswordManager=>$TWiki::cfg{Ldap}{SecondaryPasswordManager} || '',
    @_
  };
  bless($this, $class);

  $this->{session} = $session;

  if ($this->{useSASL}) {
    #$this->writeDebug("will use SASL authentication");
    require Authen::SASL;
  }

  # protect against actidental misconfiguration, that might lead
  # to an infinite loop during authorization etc.
  if ($this->{secondaryPasswordManager} eq 'TWiki::Users::LdapPassword') {
    $this->writeWarning("hey, you want infinite loops? naw.");
    $this->{secondaryPasswordManager} = '';
  }
  
  if ($this->{secondaryPasswordManager} eq 'none') {
    $this->{secondaryPasswordManager} = '';
  }

  my $workArea = $session->{store}->getWorkArea('LdapContrib');
  mkdir $workArea unless -d $workArea;
  $this->{cacheFile} = $workArea.'/cache.db';

  # normalize normalization flags
  $this->{normalizeWikiName} = $TWiki::cfg{Ldap}{NormalizeWikiName} 
    unless defined $this->{normalizeWikiName};
  $this->{normalizeLoginName} = $TWiki::cfg{Ldap}{NormalizeLoginName} 
    unless defined $this->{normalizeLoginName};
  $this->{normalizeGroupName} = $TWiki::cfg{Ldap}{NormalizeGroupName} 
    unless defined $this->{normalizeGroupName};
  $this->{normalizeWikiName} = 1 unless defined $this->{normalizeWikiName};

  @{$this->{wikiNameAttributes}} = split(/\s*,\s*/, $this->{wikiNameAttribute});

  # create exclude map
  my %excludeMap = map {$_ => 1} split(/\s*,\s*/, $this->{exclude});
  $this->{excludeMap} = \%excludeMap;

  # creating alias map
  my %aliasMap = ();
  foreach my $alias (split(/\s*,\s*/, $this->{wikiNameAliases})) {
    if ($alias =~ /^\s*(.+?)\s*=\s*(.+?)\s*$/) {
      $aliasMap{$1} = $2;
    }
  }
  $this->{wikiNameAliases} = \%aliasMap;

  # default value for cache expiration is every 24h
  $this->{maxCacheAge} = 86400 unless defined $this->{maxCacheAge};

  $this->writeDebug("constructed a new LdapContrib object");

  return $this;
}

=pod

---++++ getLdapContrib($session) -> $ldap

Returns a standard singleton TWiki::Contrib::LdapContrib object based on the site-wide
configuration. 

=cut

sub getLdapContrib {
  my $session = shift;

  my $obj = $sharedLdapContrib{$session};
  return $obj if $obj;

  $obj = new TWiki::Contrib::LdapContrib($session);
  $obj->initCache();
  $sharedLdapContrib{$session} = $obj;

  return $obj;
}

=pod

---++++ connect($login, $passwd) -> $boolean

Connect to LDAP server. If a $login name and a $passwd is given then a bind is done.
Otherwise the communication is anonymous. You don't have to connect() explicitely
by calling this method. The methods below will do that automatically when needed.

=cut

sub connect {
  my ($this, $dn, $passwd) = @_;

  $this->writeDebug("called connect");
  #$this->writeDebug("dn=$dn", 2) if $dn;
  #$this->writeDebug("passwd=***", 2) if $passwd;

  $this->{ldap} = Net::LDAP->new($this->{host},
    port=>$this->{port},
    version=>$this->{version},
  );
  unless ($this->{ldap}) {
    $this->{error} = "failed to connect to $this->{host}";
    $this->{error} .= ": $@" if $@;
    return 0;
  }

  # TLS bind
  if ($this->{useTLS}) {
    $this->writeDebug("using TLS");
    my %args = (
      verify => $this->{tlsVerify},
      cafile => $this->{tlsCAFile},
      capath => $this->{tlsCAPath},
    );
    $args{"clientcert"} = $this->{tlsClientCert} if $this->{tlsClientCert};
    $args{"clientkey"} = $this->{tlsClientKey} if $this->{tlsClientKey};
    $args{"sslversion"} = $this->{tlsSSLVersion} if $this->{tlsSSLVersion};
    $this->{ldap}->start_tls(%args);
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

    if ($this->{useSASL}) {
      # sasl bind
      my $sasl = Authen::SASL->new(
	mechanism => $this->{saslMechanism}, #'DIGEST-MD5 PLAIN CRAM-MD5 EXTERNAL ANONYMOUS',
	callback => {
	  user => $this->{bindDN},
	  pass => $this->{bindPassword},
	},
      );
      $this->writeDebug("sasl bind to $this->{bindDN}");
      $msg = $this->{ldap}->bind($this->{bindDN}, sasl=>$sasl, version=>$this->{version} );
    } else {
      # simple bind
      $this->writeDebug("proxy bind");
      $msg = $this->{ldap}->bind($this->{bindDN},password=>$this->{bindPassword});
    }
  }
  
  # anonymous bind
  else {
    #$this->writeDebug("anonymous bind");
    $msg = $this->{ldap}->bind;
  }

  $this->{isConnected} = ($this->checkError($msg) == LDAP_SUCCESS)?1:0;
  $this->writeDebug("failed to bind") unless $this->{isConnected};
  return $this->{isConnected};
}

=pod

---++++ disconnect()

Unbind the LDAP object from the server. This method can be used to force
a reconnect and possibly rebind as a different user.

=cut

sub disconnect {
  my $this = shift;

  return unless defined($this->{ldap}) && $this->{isConnected};

  $this->writeDebug("called disconnect()");
  $this->{ldap}->unbind();
  $this->{ldap} = undef;
  $this->{isConnected} = 0;
}

=pod

---++++ finish

finalize this ldap object.

=cut

sub finish {
  my $this = shift;

  return if $this->{isFinished};
  $this->{isFinished} = 1;

  $this->writeDebug("finishing");
  $this->disconnect();
  delete $sharedLdapContrib{$this->{session}};
  undef $this->{cacheDB};
  untie %{$this->{data}};
}


=pod

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

=pod

---++++ getError() -> $errorMsg

Returns the error message of the last LDAP action or undef it no
error occured.

=cut

sub getError {
  my $this = shift;
  return $this->{error};
}


=pod

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
    #$this->writeDebug("no such account");
    return undef;
  }
  if ($msg->count() != 1) {
    $this->{error} = 'Login invalid';
    #$this->writeDebug($this->{error});
    return undef;
  }

  return $msg->entry(0);
}


=pod

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

  unless ($this->{ldap}) {
    unless ($this->connect()) {
      $this->writeDebug("error in search: ".$this->getError());
      return undef;
    }
  }

  my $msg = $this->{ldap}->search(%args);
  my $errorCode = $this->checkError($msg);

  # we set a limit so it is ok that it exceeds
  if ($args{limit} && $errorCode == LDAP_SIZELIMIT_EXCEEDED) {
    $this->writeDebug("limit exceeded");
    return $msg;
  }
  
  if ($errorCode != LDAP_SUCCESS) {
    #$this->writeDebug("error in search: ".$this->getError());
    return undef;
  }
  $this->writeDebug("found ".$msg->count." entries");

  return $msg;
}

=pod

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

  #$this->writeDebug("called cacheBlob()");

  my $systemWeb = &TWiki::Func::getTwikiWebname();
  my $dir = &TWiki::Func::getPubDir().'/'.$systemWeb.'/LdapContrib';
  my $key = md5_hex($entry->dn().$attr);
  my $fileName = $dir.'/'.$key;

  if ($refresh || !-f $fileName) {
    #$this->writeDebug("caching blob");
    my $value = $entry->get_value($attr);
    return undef unless defined $value;
    mkdir($dir, 0775) unless -e $dir;

    open (FILE, ">$fileName");
    binmode(FILE);
    print FILE $value;
    close (FILE);
  } else {
    #$this->writeDebug("already got blob");
  }
  
  #$this->writeDebug("done cacheBlob()");
  return &TWiki::Func::getPubUrlPath().'/'.$systemWeb.'/LdapContrib/'.$key;
}

=pod

---++++ initCache()

loads/connects to the LDAP cache

=cut

sub initCache {
  my $this = shift;

  return unless $TWiki::cfg{UserMappingManager} =~ /LdapUserMapping/ ||
                $TWiki::cfg{PasswordManager} =~ /LdapPassword/;

  #$this->writeDebug("called initCache");

  # open database
  #$this->writeDebug("opening ldap cache from $this->{cacheFile}");
  $this->{cacheDB} = 
    tie %{$this->{data}}, 'DB_File', $this->{cacheFile}, O_CREAT|O_RDWR, 0664, $DB_HASH
    or die "Cannot open file $this->{cacheFile}: $!";

  # refresh by user interaction
  my $refresh = CGI::param('refreshldap') || '';
  $refresh = $refresh eq 'on'?1:0;
  #$this->writeDebug("refreshing cache explicitly") if $refresh;

  if ($this->{maxCacheAge} > 0) { # is cache expiration enabled

    # compute age of data
    my $cacheAge = 9999999999;
    my $now = time();
    my $lastUpdate = $this->{data}{lastUpdate} || 0;
    $cacheAge = $now - $lastUpdate if $lastUpdate;

    # don't refresh within 60 seconds
    if ($cacheAge < 10) {
      $refresh = 0;
      $this->writeDebug("suppressing cache refresh within 10 seconds");
    } else {
      $refresh = 1 if $cacheAge > $this->{maxCacheAge}
    }

    #$this->writeDebug("cacheAge=$cacheAge, maxCacheAge=$this->{maxCacheAge}, lastUpdate=$lastUpdate, refresh=$refresh");
  }

  # clear to reload it
  if ($refresh) {
    $this->writeDebug("updating cache");
    $this->refreshCache();
  }
}

=pod

---++++ refreshCache() -> $boolean

download all relevant records from the LDAP server and
store it into a database

=cut

sub refreshCache {
  my ($this) = @_;

  $this->writeDebug("called refreshCache");

  # create a temporary tie
  my $tempCacheFile = $this->{cacheFile}.'_tmp';
  my %tempData;
  my $tempCache = 
    tie %tempData, 'DB_File', $tempCacheFile, O_CREAT|O_RDWR, 0664, $DB_HASH
    or die "Cannot open file $tempCacheFile: $!";

  my $isOk = $this->refreshUsersCache(\%tempData);
  if ($isOk && $this->{mapGroups}) {
    $isOk = $this->refreshGroupsCache(\%tempData);
  }

  if (!$isOk) { # we had an error: keep the old cache til the error is resolved
    undef $tempCache;
    untie %tempData;
    unlink $tempCacheFile;
    return 0;
  }

  $this->writeDebug("flushing db to disk");
  $tempData{lastUpdate} = time();
  $tempCache->sync();
  undef $tempCache;
  untie %tempData;

  # try to be transactional
  undef $this->{cacheDB};
  untie %{$this->{data}};

  $this->writeDebug("replacing working copy");
  rename $tempCacheFile,$this->{cacheFile};

  # reconnect hash
  $this->{cacheDB} = 
    tie %{$this->{data}}, 'DB_File', $this->{cacheFile}, O_CREAT|O_RDWR, 0664, $DB_HASH
    or die "Cannot open file $this->{cacheFile}: $!";

  return 1;
}

=pod

---++++ refreshUsersCache($data) -> $boolean

download all user records from the LDAP server and cache it into the
given hash reference

returns true if new records have been loaded

=cut

sub refreshUsersCache {
  my ($this, $data) = @_;

  $this->writeDebug("called refreshUsersCache()");
  $data ||= $this->{data};

  # prepare search
  my $page = Net::LDAP::Control::Paged->new(size=>$this->{pageSize});
  my $cookie;
  my @args = (
    filter=>$this->{loginFilter}, 
    base=>$this->{userBase},
    attrs=>[$this->{loginAttribute}, 
            $this->{mailAttribute},
            $this->{primaryGroupAttribute},
            @{$this->{wikiNameAttributes}}
          ],
    control=>[$page],
  );

  # read pages
  my $nrRecords = 0;
  my %wikiNames = ();
  my %loginNames = ();
  my $gotError = 0;
  while (1) {

    # perform search
    my $mesg = $this->search(@args);
    unless ($mesg) {
      #$this->writeDebug("oops, no result");
      $this->writeWarning("error refeshing the user cashe: ".
        $this->getError());
      $gotError = 1;
      last;
    }

    # process each entry on a page
    while (my $entry = $mesg->pop_entry()) {
      $this->cacheUserFromEntry($entry, $data, \%wikiNames, \%loginNames) && $nrRecords++;
    } 

    # get cookie from paged control to remember the offset
    my ($resp) = $mesg->control(LDAP_CONTROL_PAGED) or last;
    $cookie = $resp->cookie or last;
    if ($cookie) {
      # set cookie in paged control
      $page->cookie($cookie);
    } else {
      # found all
      $this->writeDebug("ok, no more cookie");
      last;
    }
  } # end reading pages
  $this->writeDebug("done reading pages");

  # clean up
  if ($cookie) {
    $page->cookie($cookie);
    $page->size(0);
    $this->search(@args);
  }

  # check for error
  return 0 if $gotError;

  # remember list of all user names
  $data->{WIKINAMES} = join(',', keys %wikiNames);
  $data->{LOGINNAMES} = join(',', keys %loginNames);

  $this->writeDebug("got $nrRecords keys in cache");

  return 1;
}

=pod

---++++ refreshGroups($data) -> $boolean

download all group records from the LDAP server

returns true if new records have been loaded

=cut

sub refreshGroupsCache {
  my ($this, $data) = @_;

  $data ||= $this->{data};

  # prepare search
  my $page = Net::LDAP::Control::Paged->new(size=>$this->{pageSize});
  my $cookie;
  my @args = (
    filter=>$this->{groupFilter}, 
    base=>$this->{groupBase}, 
    attrs=>[
      $this->{groupAttribute}, 
      $this->{memberAttribute}, 
      $this->{primaryGroupAttribute}
    ],
    control=>[$page],
  );

  # read pages
  my $nrRecords = 0;
  my %groupNames;
  my $gotError = 0;
  while (1) {

    # perform search
    my $mesg = $this->search(@args);
    unless ($mesg) {
      #$this->writeDebug("oops, no result");
      $this->writeWarning("error refeshing the groups cashe: ".
        $this->getError());
      last;
    }

    # process each entry on a page
    while (my $entry = $mesg->pop_entry()) {
      $this->cacheGroupFromEntry($entry, $data, \%groupNames) && $nrRecords++;
    }
    # get cookie from paged control to remember the offset
    my ($resp) = $mesg->control(LDAP_CONTROL_PAGED) or last;
    $cookie = $resp->cookie or last;
    if ($cookie) {
      # set cookie in paged control
      $page->cookie($cookie);
    } else {
      # found all
      #$this->writeDebug("ok, no more cookie");
      last;
    }
  } # end reading pages

  # clean up
  if ($cookie) {
    $page->cookie($cookie);
    $page->size(0);
    $this->search(@args);
  }

  # check for error
  return 0 if $gotError;

  # check for primary group membership
  foreach my $groupId (keys %{$this->{_primaryGroup}}) {
    my $groupName = $this->{_groupId}{$groupId};
    foreach my $member (keys %{$this->{_primaryGroup}{$groupId}}) {
      $this->writeDebug("adding $member to its primary group $groupName");
      $this->{_groups}{$groupName}{$member} = 1;
    }
  }

  # assert group members to data store 
  foreach my $groupName (keys %{$this->{_groups}}) {

    my %members = ();
    foreach my $member (keys %{$this->{_groups}{$groupName}}) {

      # groups may store DNs to members instead of a memberUid, in this case we
      # have to lookup the corresponding loginAttribute
      if ($this->{memberIndirection}) {
	#$this->writeDebug("following indirection for $member");
	my $memberName = $data->{"DN2U::$member"};
	if ($memberName) {
	  $members{$memberName} = 1;
	} else {
	  $this->writeDebug("oops, $member not found, but member of $groupName");
	} 
      } else {
	$members{$member} = 1;
      }
    }
    
    $data->{"GROUPS::$groupName"} = join(',', keys %members);
    undef $this->{_groups}{$groupName};
  }
  undef $this->{_groups};

  # remember list of all groups
  $data->{GROUPS} = join(',', keys %groupNames);

  #$this->writeDebug("got $nrRecords keys in cache");

  return 1;
}

=pod

---++++ cacheUserFromEntry($entry, $data, $wikiNames, $loginNames) -> $boolean

store a user LDAP::Entry to our internal cache 

returns true if new records have been created

=cut

sub cacheUserFromEntry {
  my ($this, $entry, $data, $wikiNames, $loginNames) = @_;

  #$this->writeDebug("called cacheUserFromEntry()");

  $data ||= $this->{data};
  $wikiNames ||= {};
  $loginNames ||= {};

  my $dn = $entry->dn();
  my $loginName = $entry->get_value($this->{loginAttribute});
  $loginName =~ s/^\s+//o;
  $loginName =~ s/\s+$//o;
  unless ($loginName) {
    $this->writeDebug("no loginName for $dn ... skipping");
    return 0;
  }

  $loginName = lc($loginName);
  $loginName = from_utf8(-string=>$loginName, -charset=>$TWiki::cfg{Site}{CharSet})
    unless $TWiki::cfg{Site}{CharSet} =~ /^utf-?8$/i;

  if ($this->{normalizeLoginName}) {
    $loginName = $this->normalizeLoginName($loginName);
  }

  # construct the wikiName
  my $wikiName;
  foreach my $attr (@{$this->{wikiNameAttributes}}) {
    my $value = $entry->get_value($attr);
    next unless $value;
    $value =~ s/^\s+//o;
    $value =~ s/\s+$//o;

    $value = from_utf8(-string=>$value, -charset=>$TWiki::cfg{Site}{CharSet})
      unless $TWiki::cfg{Site}{CharSet} =~ /^utf-?8$/i;

    #$this->writeDebug("$attr=$value");

    if ($this->{normalizeWikiName}) {
      $wikiName .= $this->normalizeWikiName($value);
    } else {
      $wikiName .= $value;
    }
  }
  unless ($wikiName) {
    if ($this->{normalizeWikiName}) {
      $wikiName = $this->normalizeWikiName($loginName);
    } else {
      $wikiName = $loginName;
    }
    $this->writeWarning("no WikiNameAttributes found for $dn ... deriving WikiName from LoginName: '$wikiName'");
  }
  if (defined($wikiNames->{$wikiName})) {
    $this->writeWarning("$dn clashes with wikiName $wikiNames->{$wikiName} on $wikiName");
  }
  $wikiNames->{$wikiName} = $dn;
  if (defined($loginNames->{$loginName})) {
    $this->writeWarning("$dn clashes with loginName $loginNames->{$loginName} on $loginName");
  }
  $loginNames->{$loginName} = $dn;

  # get email addrs
  my $emails;
  @{$emails} = $entry->get_value($this->{mailAttribute});

  # get primary group 
  if ($this->{primaryGroupAttribute}) {
    my $groupId = $entry->get_value($this->{primaryGroupAttribute});
    $this->{_primaryGroup}{$groupId}{$loginName} = 1; # delayed
  }

  # store it
  $this->writeDebug("adding wikiName='$wikiName', loginName='$loginName', dn=$dn");
  $data->{"U2W::$loginName"} = $wikiName;
  $data->{"W2U::$wikiName"} = $loginName;
  $data->{"DN2U::$dn"} = $loginName;
  $data->{"U2DN::$loginName"} = $dn;
  $data->{"U2EMAIL::$loginName"} = join(',',@$emails);

  if ($emails) {
    foreach my $email (@$emails) {
      $email =~ s/^\s+//o;
      $email =~ s/\s+$//o;
      my $prevMapping = $data->{"EMAIL2U::$email"};
      my %emails = ();
      if ($prevMapping) {
        %emails = map {$_ => 1} split(/\s*,\s*/, $prevMapping);
      }
      $emails{$loginName} = $email;
      $data->{"EMAIL2U::$email"} = join(',', sort keys %emails);
    }
  }

  return 1;
}

=pod

---++++ cacheGroupFromEntry($entry, $data, $groupNames) -> $boolean

store a group LDAP::Entry to our internal cache 

returns true if new records have been created

=cut

sub cacheGroupFromEntry {
  my ($this, $entry, $data, $groupNames) = @_;

  $data ||= $this->{data};
  $groupNames ||= {};

  my $dn = $entry->dn();

  my $groupName = $entry->get_value($this->{groupAttribute});
  unless ($groupName) {
    $this->writeDebug("no groupName for $dn ... skipping");
    return 0;
  }
  $groupName =~ s/^\s+//o;
  $groupName =~ s/\s+$//o;

  $groupName = from_utf8(-string=>$groupName, -charset=>$TWiki::cfg{Site}{CharSet})
    unless $TWiki::cfg{Site}{CharSet} =~ /^utf-?8$/i;

  if ($this->{normalizeGroupName}) {
    $groupName = $this->normalizeWikiName($groupName);
  }

  if (defined($groupNames->{$groupName})) {
    $this->writeWarning("$dn clashes with group $groupNames->{$groupName} on $groupName");
    return 0;
  }

  if (defined($data->{"U2W::$groupName"}) || defined($data->{"W2U::$groupName"})) {
    my $groupSuffix = '';
    if ($this->{normalizeGroupName}) {
      $groupSuffix = 'Group';
    } else {
      $groupSuffix = '_group';
    }
    $this->writeWarning("group $dn clashes with user $groupName ... appending $groupSuffix");
    $groupName .= $groupSuffix;
  }

  # cache groupIds
  my $groupId = $entry->get_value($this->{primaryGroupAttribute});
  $this->{_groupId}{$groupId} = $groupName;

  # fetch all members of this group
  foreach my $member ($entry->get_value($this->{memberAttribute})) {
    next unless $member;
    $member =~ s/^\s+//o;
    $member =~ s/\s+$//o;
    $this->{_groups}{$groupName}{$member} = 1; # delay til all groups have been fetched
  }

  # store it
  $this->writeDebug("adding groupName='$groupName', dn=$dn");
  $data->{"DN2U::$dn"} = $groupName;
  $data->{"U2DN::$groupName"} = $dn;
  $groupNames->{$groupName} = 1;

  return 1;
}

=pod 

---++++ normalizeWikiName($name) -> $string

normalizes a string to form a proper <nop>WikiName

=cut

sub normalizeWikiName {
  my ($this, $name) = @_;

  # remove a trailing mail domain
  $name =~ s/@.*//o;

  # remove @mydomain.com part for special mail attrs
  # SMELL: you may have a different attribute name for the email address
  
  # replace umlaute
  $name =~ s/ä/ae/go;
  $name =~ s/ö/oe/go;
  $name =~ s/ü/ue/go;
  $name =~ s/Ä/Ae/go;
  $name =~ s/Ö/Oe/go;
  $name =~ s/Ü/Ue/go;
  $name =~ s/ß/ss/go;

  my $wikiName = '';
  foreach my $part (split(/[^$TWiki::regex{mixedAlphaNum}]/, $name)) {
    $wikiName .= ucfirst($part);
  }

  return $wikiName;
}

=pod 

---++++ normalizeLoginName($name) -> $string

normalizes a string to form a proper login

=cut

sub normalizeLoginName {
  my ($this, $name) = @_;

  # remove a trailing mail domain
  $name =~ s/@.*//o;

  # remove @mydomain.com part for special mail attrs
  # SMELL: you may have a different attribute name for the email address
  
  # replace umlaute
  $name =~ s/ä/ae/go;
  $name =~ s/ö/oe/go;
  $name =~ s/ü/ue/go;
  $name =~ s/Ä/Ae/go;
  $name =~ s/Ö/Oe/go;
  $name =~ s/Ü/Ue/go;
  $name =~ s/ß/ss/go;
  $name =~ s/[^$TWiki::cfg{LoginNameFilterIn}]//;

  return $name;
}


=pod

---++++ getGroupNames() -> @array

Returns a list of known group names.

=cut

sub getGroupNames {
  my $this = shift;

  #$this->writeDebug("called getGroupNames()");

  my $groupNames = TWiki::Sandbox::untaintUnchecked($this->{data}{GROUPS}) || '';
  my @groupNames = split(/\s*,\s*/,$groupNames);

  return \@groupNames;
}

=pod

---++++ isGroup($wikiName) -> $boolean

check if a given user is an ldap group actually

=cut

sub isGroup {
  my ($this, $wikiName) = @_;

  #$this->writeDebug("called isGroup($wikiName)");
  return undef if $this->{excludeMap}{$wikiName};
  return 1 if defined($this->{data}{"GROUPS::$wikiName"});
  return undef;
}


=pod

---++++ getEmails($login) -> @emails

fetch emails from LDAP

=cut

sub getEmails {
  my ($this, $login) = @_;

  my $emails = TWiki::Sandbox::untaintUnchecked($this->{data}{"U2EMAIL::".lc($login)}) || '';
  my @emails = split(/\s*,\s*/,$emails);
  return \@emails;
}

=pod

---++++ getLoginOfEmail($email) \@users

get all users matching a given email address

=cut

sub getLoginOfEmail {
  my ($this, $email) = @_;

  my $loginNames = TWiki::Sandbox::untaintUnchecked($this->{data}{"EMAIL2U::".$email}) || '';
  my @loginNames = split(/\s*,\s*/,$loginNames);
  return \@loginNames;
  
}

=pod

---++++ getGroupMembers($groupName) -> \@array

=cut

sub getGroupMembers {
  my ($this, $groupName) = @_;
  return undef if $this->{excludeMap}{$groupName};

  $this->writeDebug("called getGroupMembers $groupName");

  my $members = TWiki::Sandbox::untaintUnchecked($this->{data}{"GROUPS::$groupName"}) || '';
  my @members = split(/\s*,\s*/, $members);

  return \@members;
}

=pod

---++++ isGroupMember($loginName, $groupName) -> $boolean

check if a given user is member of an ldap group

=cut

sub isGroupMember {
  my ($this, $loginName, $groupName) = @_;

  my $members = $this->{data}{"GROUPS::$groupName"} || '';
  return ($members =~ /\b$loginName\b/)?1:0;
}

=pod 

---++++ getWikiNameOfLogin($loginName) -> $wikiName

returns the wikiName of a loginName or undef if it does not exist

=cut

sub getWikiNameOfLogin {
  my ($this, $loginName) = @_;

  $this->writeDebug("called getWikiNameOfLogin($loginName)");
  $loginName = lc($loginName);
  return TWiki::Sandbox::untaintUnchecked($this->{data}{"U2W::$loginName"});
}

=pod 

---++++ getLoginOfWikiName($wikiName) -> $loginName

returns the loginNAme of a wikiName or undef if it does not exist

=cut

sub getLoginOfWikiName {
  my ($this, $wikiName) = @_;

  my $loginName = TWiki::Sandbox::untaintUnchecked($this->{data}{"W2U::$wikiName"});
  
  unless ($loginName) {
    my $alias = $this->{wikiNameAliases}{$wikiName};
    $loginName = TWiki::Sandbox::untaintUnchecked($this->{data}{"W2U::$alias"})
      if defined($alias);
  }

  return $loginName;
}

=pod 

---++++ getAllWikiNames() -> \@array

returns a list of all known wikiNames

=cut

sub getAllWikiNames {
  my $this = shift;

  my $wikiNames = TWiki::Sandbox::untaintUnchecked($this->{data}{WIKINAMES}) || '';
  my @wikiNames = split(/\s*,\s*/,$wikiNames);
  return \@wikiNames;
}

=pod 

---++++ getAllLoginNames() -> \@array

returns a list of all known loginNames

=cut

sub getAllLoginNames {
  my $this = shift;

  my $loginNames = TWiki::Sandbox::untaintUnchecked($this->{data}{LOGINNAMES}) || '';
  my @loginNames = split(/\s*,\s*/,$loginNames);
  return \@loginNames;
}

=pod 

---++++ getDnOfLogin($loginName) -> $dn

returns the Distinguished Name of the LDAP record of the given name

=cut

sub getDnOfLogin {
  my ($this, $loginName) = @_;
  $loginName = lc($loginName);
  return TWiki::Sandbox::untaintUnchecked($this->{data}{"U2DN::$loginName"});
}

=pod 

---++++ changePassword($loginName, $newPassword, $oldPassword) -> $boolean

=cut

sub changePassword {
  my ($this, $loginName, $newPassword, $oldPassword ) = @_;

  return undef unless 
    $this->{allowChangePassword} && defined($oldPassword) && $oldPassword ne '1';

  my $dn = $this->getDnOfLogin($loginName);
  return undef unless $dn;

  return undef unless $this->connect($dn, $oldPassword);

  my $msg = $this->{ldap}->modify( $dn, 
    replace => { 'userPassword' => $newPassword } 
  );

  my $errorCode = $this->checkError($msg);

  if ($errorCode != LDAP_SUCCESS) {
    $this->writeDebug("error in changePassword: ".$this->getError());
    return undef;
  }

  return 1;
}

=pod

---++++ checkCacheForLoginName($loginName) -> $boolean

grant that the current loginName is cached. If not, it will download the LDAP
record for this specific user and update the LDAP cache with this single record.

This happens when the user is authenticated externally, e.g. using apache's
mod_authz_ldap or some other SSO, and the internal cache 
is not yet updated. It is completely updated regularly on a specific time
interval (default every 24h). See the LdapContrib settings.

=cut

sub checkCacheForLoginName {
  my ($this, $loginName) = @_;

  $this->writeDebug("called checkCacheForLoginName($loginName)");

  my $wikiName = $this->getWikiNameOfLogin($loginName);

  return 1 if $wikiName;

  # update cache selectively
  $this->writeDebug("warning, $loginName is unknown, need to refresh part of the ldap cache");
  my $entry = $this->getAccount($loginName);
  unless ($entry) {
    $this->writeDebug("oops, no result");
  } else {
    # merge this user record

    my %wikiNames = map {$_ => 1} @{$this->getAllWikiNames()};
    my %loginNames = map {$_ => 1} @{$this->getAllLoginNames()};
    $this->cacheUserFromEntry($entry, $this->{data}, \%wikiNames, \%loginNames);

    $this->{data}{WIKINAMES} = join(',', keys %wikiNames);
    $this->{data}{LOGINNAMES} = join(',', keys %loginNames);
  }

  return 0;
}

1;
