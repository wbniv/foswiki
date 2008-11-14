# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2007 Sven Dowideit, SvenDowideit@distributedINFORMATION.com
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
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

=begin twiki

---+ package TWiki::Users::TopicUserMapping

The User mapping is the process by which TWiki maps from a username (a login name)
to a wikiname and back. It is also where groups are defined.

By default TWiki maintains user topics and group topics in the %MAINWEB% that
define users and group. These topics are
   * !TWikiUsers - stores a mapping from usernames to TWiki names
   * !WikiName - for each user, stores info about the user
   * !GroupNameGroup - for each group, a topic ending with "Group" stores a list of users who are part of that group.

Many sites will want to override this behaviour, for example to get users and groups from a corporate database.

This class implements the basic TWiki behaviour using topics to store users,
but is also designed to be subclassed so that other services can be used.

Subclasses should be named 'XxxxUserMapping' so that configure can find them.

=cut

package TWiki::Users::TopicUserMapping;
use base 'TWiki::UserMapping';

use strict;
use Assert;
use Error qw( :try );

#use Monitor;
#Monitor::MonitorMethod('TWiki::Users::TopicUserMapping');

=begin twiki

---++ ClassMethod new ($session, $impl)

Constructs a new user mapping handler of this type, referring to $session
for any required TWiki services.

=cut

# The null mapping name is reserved for TWiki for backward-compatibility.
# We declare this as a global variable so we can override it during testing.
our $TWIKI_USER_MAPPING_ID = '';

#our $TWIKI_USER_MAPPING_ID = 'TestMapping_';

sub new {
    my ( $class, $session ) = @_;

    my $this = $class->SUPER::new( $session, $TWIKI_USER_MAPPING_ID );

    my $implPasswordManager = $TWiki::cfg{PasswordManager};
    $implPasswordManager = 'TWiki::Users::Password'
      if ( $implPasswordManager eq 'none' );
    eval "require $implPasswordManager";
    die $@ if $@;
    $this->{passwords} = $implPasswordManager->new($session);

#if password manager says sorry, we're read only today
#'none' is a special case, as it means we're not actually using the password manager for
# registration.
    if ( $this->{passwords}->readOnly()
        && ( $TWiki::cfg{PasswordManager} ne 'none' ) )
    {
        $session->writeWarning(
'TopicUserMapping has TURNED OFF EnableNewUserRegistration, because the password file is read only.'
        );
        $TWiki::cfg{Register}{EnableNewUserRegistration} = 0;
    }

    #SMELL: and this is a second user object
    #TODO: combine with the one in TWiki::Users
    #$this->{U2L} = {};
    $this->{L2U}             = {};
    $this->{U2W}             = {};
    $this->{W2U}             = {};
    $this->{eachGroupMember} = {};

    return $this;
}

=begin twiki

---++ ObjectMethod finish()
Break circular references.

=cut

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub finish {
    my $this = shift;

    $this->{passwords}->finish() if $this->{passwords};
    undef $this->{L2U};
    undef $this->{U2W};
    undef $this->{W2U};
    undef $this->{passwords};
    undef $this->{eachGroupMember};
    $this->SUPER::finish();
}

=begin twiki

---++ ObjectMethod supportsRegistration () -> false
return 1 if the UserMapper supports registration (ie can create new users)

=cut

sub supportsRegistration {
    return 1;
}

=begin twiki

---++ ObjectMethod handlesUser ( $cUID, $login, $wikiname) -> $boolean

Called by the TWiki::Users object to determine which loaded mapping
to use for a given user.

The user can be identified by any of $cUID, $login or $wikiname. Any of
these parameters may be undef, and they should be tested in order; cUID
first, then login, then wikiname. This mapping is special - for backwards
compatibility, it assumes responsibility for _all_ non BaseMapping users.
If you're needing to mix the TopicUserMapping with other mappings,
define $this->{mapping_id} = 'TopicUserMapping_';

=cut

sub handlesUser {
    my ( $this, $cUID, $login, $wikiname ) = @_;

    if ( defined $cUID && !length( $this->{mapping_id} ) ) {

        # Handle all cUIDs if the mapping ID is not defined
        return 1;
    }
    else {

        # Used when (if) TopicUserMapping is subclassed
        return 1 if ( defined $cUID && $cUID =~ /^($this->{mapping_id})/ );
    }

    # Check the login id to see if we know it
    return 1 if ( $login && $this->_userReallyExists($login) );

    # Or the wiki name
    if ($wikiname) {
        _loadMapping($this);    # Sorry Sven, has to be done
        return 1 if defined $this->{W2U}->{$wikiname};
    }

    return 0;
}

=begin twiki

---++ ObjectMethod login2cUID ($login, $dontcheck) -> $cUID

Convert a login name to the corresponding canonical user name. The
canonical name can be any string of 7-bit alphanumeric and underscore
characters, and must correspond 1:1 to the login name.
(undef on failure)

(if dontcheck is true, return a cUID for a nonexistant user too.
This is used for registration)

=cut

sub login2cUID {
    my ( $this, $login, $dontcheck ) = @_;

    unless ($dontcheck) {
        return undef unless ( _userReallyExists( $this, $login ) );
    }

    return $this->{mapping_id} . TWiki::Users::mapLogin2cUID($login);
}

=begin twiki

---++ ObjectMethod getLoginName ($cUID) -> login

Converts an internal cUID to that user's login
(undef on failure)

=cut

sub getLoginName {
    my ( $this, $cUID ) = @_;
    ASSERT($cUID) if DEBUG;

    #can't call userExists - its recursive
    #return unless (userExists($this, $user));

    # Remove the mapping id in case this is a subclass
    $cUID =~ s/$this->{mapping_id}// if $this->{mapping_id};

    use bytes;

    # Reverse the encoding used to generate cUIDs in login2cUID
    # use bytes to ignore character encoding
    $cUID =~ s/_([0-9a-f][0-9a-f])/chr(hex($1))/gei;
    no bytes;

    return undef unless _userReallyExists( $this, $cUID );

    return $cUID;
}

# test if the login is in the TWikiUsers topic, or in the password file
# depending on the AllowLoginNames setting
sub _userReallyExists {
    my ( $this, $login ) = @_;

    if ( $TWiki::cfg{Register}{AllowLoginName} ) {

        # need to use the TWikiUsers file
        _loadMapping($this);
        return 1 if ( defined( $this->{L2U}->{$login} ) );
    }

    if ( $this->{passwords}->canFetchUsers() ) {

        # AllowLoginName mapping failed, maybe the user is however
        # present in the TWiki managed pwd file
        # can use the password file if available
        my $pass = $this->{passwords}->fetchPass($login);
        return unless ( defined($pass) );
        return if ( "$pass" eq "0" );    # login invalid... (SMELL: what
                                         # does that really mean)
        return 1;
    }
    else {

        # passwd==none case generally assumes any login given exists...
        # (not positive if that makes sense for rego..)
        return 1;
    }

    return 0;
}

=begin twiki

---++ ObjectMethod addUser ($login, $wikiname, $password, $emails) -> $cUID

throws an Error::Simple 

Add a user to the persistant mapping that maps from usernames to wikinames
and vice-versa. The default implementation uses a special topic called
"TWikiUsers" in the users web. Subclasses will provide other implementations
(usually stubs if they have other ways of mapping usernames to wikinames).
Names must be acceptable to $TWiki::cfg{NameFilter}
$login must *always* be specified. $wikiname may be undef, in which case
the user mapper should make one up.
This function must return a *canonical user id* that it uses to uniquely
identify the user. This can be the login name, or the wikiname if they
are all guaranteed unigue, or some other string consisting only of 7-bit
alphanumerics and underscores.
if you fail to create a new user (for eg your Mapper has read only access), 
            throw Error::Simple(
               'Failed to add user: '.$ph->error());

=cut

sub addUser {
    my ( $this, $login, $wikiname, $password, $emails ) = @_;

    ASSERT($login) if DEBUG;

    # SMELL: really ought to be smarter about this e.g. make a wikiword
    $wikiname ||= $login;

    if ( $this->{passwords}->fetchPass($login) ) {

        # They exist; their password must match
        unless ( $this->{passwords}->checkPassword( $login, $password ) ) {
            throw Error::Simple(
                'New password did not match existing password for this user');
        }

        # User exists, and the password was good.
    }
    else {

        # add a new user

        unless ( defined($password) ) {
            require TWiki::Users;
            $password = TWiki::Users::randomPassword();
        }

        unless ( $this->{passwords}->setPassword( $login, $password ) ) {

           #print STDERR "\n Failed to add user:  ".$this->{passwords}->error();
            throw Error::Simple(
                'Failed to add user: ' . $this->{passwords}->error() );
        }
    }

    my $store = $this->{session}->{store};
    my ( $meta, $text );

    if (
        $store->topicExists(
            $TWiki::cfg{UsersWebName},
            $TWiki::cfg{UsersTopicName}
        )
      )
    {
        ( $meta, $text ) = $store->readTopic(
            undef,
            $TWiki::cfg{UsersWebName},
            $TWiki::cfg{UsersTopicName}
        );
    }
    else {
        ( $meta, $text ) = $store->readTopic( undef, $TWiki::cfg{SystemWebName},
            'TWikiUsersTemplate' );
    }

    my $result = '';
    my $entry  = "   * $wikiname - ";
    $entry .= $login . " - " if $login;

    require TWiki::Time;
    my $today =
      TWiki::Time::formatTime( time(), $TWiki::cfg{DefaultDateFormat},
        'gmtime' );

    # add to the mapping caches
    my $user = _cacheUser( $this, $wikiname, $login );
    ASSERT($user) if DEBUG;

    # add name alphabetically to list

 # insidelist is used to see if we are before the first record or after the last
 # 0 before, 1 inside, 2 after
    my $insidelist = 0;
    foreach my $line ( split( /\r?\n/, $text ) ) {

        # TODO: I18N fix here once basic auth problem with 8-bit user names is
        # solved
        if ($entry) {
            my ( $web, $name, $odate ) = ( '', '', '' );
            if ( $line =~
/^\s+\*\s($TWiki::regex{webNameRegex}\.)?($TWiki::regex{wikiWordRegex})\s*(?:-\s*\w+\s*)?-\s*(.*)/
              )
            {
                $web        = $1 || $TWiki::cfg{UsersWebName};
                $name       = $2;
                $odate      = $3;
                $insidelist = 1;
            }
            elsif ( $line =~ /^\s+\*\s([A-Z]) - / ) {

                #	* A - <a name="A">- - - -</a>^M
                $name       = $1;
                $insidelist = 1;
            }
            elsif ( $insidelist == 1 ) {

              # After last entry we have a blank line or some comment
              # We assume no blank lines inside the list of users
              # We cannot look for last after Z because Z is not the last letter
              # in all alphabets
                $insidelist = 2;
                $name       = '';
            }
            if ( ( $name && ( $wikiname le $name ) ) || $insidelist == 2 ) {

                # found alphabetical position or last record
                if ( $wikiname eq $name ) {

                    # adjusting existing user - keep original registration date
                    $entry .= $odate;
                }
                else {
                    $entry .= $today . "\n" . $line;
                }

                # don't adjust if unchanged
                return $user if ( $entry eq $line );
                $line  = $entry;
                $entry = '';
            }
        }

        $result .= $line . "\n";
    }
    if ($entry) {

        # brand new file - add to end
        $result .= "$entry$today\n";
    }
    try {
        $store->saveTopic(

            # SMELL: why is this Admin and not the RegoAgent??
            $this->{session}->{users}
              ->getCanonicalUserID( $TWiki::cfg{AdminUserLogin} ),
            $TWiki::cfg{UsersWebName},
            $TWiki::cfg{UsersTopicName},
            $result, $meta
        );
    }
    catch Error::Simple with {

        # Failed to add user; must remove them from the password system too,
        # otherwise their next registration attempt will be blocked
        my $e = shift;
        $this->{passwords}->removeUser($login);
        throw $e;
    };

#can't call setEmails here - user may be in the process of being registered
#TODO; when registration is moved into the mapping, setEmails will happend after the createUserTOpic
#$this->setEmails( $user, $emails );

    return $user;
}

=begin twiki

---++ ObjectMethod removeUser( $cUID ) -> $boolean

Delete the users entry. Removes the user from the password
manager and user mapping manager. Does *not* remove their personal
topics, which may still be linked.

=cut

sub removeUser {
    my ( $this, $cUID ) = @_;
    my $ln = $this->getLoginName($cUID);
    $this->{passwords}->removeUser($ln);

    # SMELL: does not update the internal caches,
    # needs someone to implement it
}

=begin twiki

---++ ObjectMethod getWikiName ($cUID) -> $wikiname

Map a canonical user name to a wikiname. If it fails to find a
WikiName, it will attempt to find a matching loginname, and use
an escaped version of that.
If there is no matching WikiName or LoginName, it returns undef.

=cut

sub getWikiName {
    my ( $this, $cUID ) = @_;
    ASSERT($cUID) if DEBUG;
    ASSERT( $cUID =~ /^$this->{mapping_id}/ ) if DEBUG;

    my $wikiname;

    if ( $TWiki::cfg{Register}{AllowLoginName} ) {
        _loadMapping($this);
        $wikiname = $this->{U2W}->{$cUID};
    }
    else {

        # If the mapping isn't enabled there's no point in loading it
    }

    unless ($wikiname) {
        $wikiname = $this->getLoginName($cUID);
        if ($wikiname) {

            # sanitise the generated WikiName
            $wikiname =~ s/$TWiki::cfg{NameFilter}//go;
        }
    }

    return $wikiname;
}

=begin twiki

---++ ObjectMethod userExists($cUID) -> $boolean

Determine if the user already exists or not. Whether a user exists
or not is determined by the password manager.

=cut

sub userExists {
    my ( $this, $cUID ) = @_;
    ASSERT($cUID) if DEBUG;

    # Do this to avoid a password manager lookup
    return 1 if $cUID eq $this->{session}->{user};

    my $loginName = $this->getLoginName($cUID);
    return 0 unless defined($loginName);

    return 1 if ( $loginName eq $TWiki::cfg{DefaultUserLogin} );

    # TWiki allows *groups* to log in
    return 1 if ( $this->isGroup($loginName) );

    # Look them up in the password manager (can be slow).
    return 1
      if ( $this->{passwords}->canFetchUsers()
        && $this->{passwords}->fetchPass($loginName) );

    unless ( $TWiki::cfg{Register}{AllowLoginName}
        || $this->{passwords}->canFetchUsers() )
    {

        #if there is no pwd file, then its external auth
        #and if AllowLoginName is also off, then the only way to know if
        #the user has registered is to test for user topic?
        if ( TWiki::Func::topicExists( $TWiki::cfg{UsersWebName}, $loginName ) )
        {
            return 1;
        }
    }

    return 0;
}

=begin twiki

---++ ObjectMethod eachUser () -> TWiki::ListIterator of cUIDs

See baseclass for documentation

=cut

sub eachUser {
    my ($this) = @_;

    _loadMapping($this);
    my @list = keys( %{ $this->{U2W} } );
    require TWiki::ListIterator;
    my $iter = new TWiki::ListIterator( \@list );
    $iter->{filter} = sub {

        # don't claim users that are handled by the basemapping
        my $cUID     = $_[0] || '';
        my $login    = $this->{session}->{users}->getLoginName($cUID);
        my $wikiname = $this->{session}->{users}->getWikiName($cUID);

        #print STDERR "**** $cUID  $login  $wikiname \n";
        require TWiki::Plugins;
        return !( $TWiki::Plugins::SESSION->{users}->{basemapping}
            ->handlesUser( undef, $login, $wikiname ) );
    };
    return $iter;
}

my %expanding;

=begin twiki

---++ ObjectMethod eachGroupMember ($group) ->  listIterator of cUIDs

See baseclass for documentation

=cut

sub eachGroupMember {
    my $this  = shift;
    my $group = shift;

    return new TWiki::ListIterator( $this->{eachGroupMember}->{$group} )
      if ( defined( $this->{eachGroupMember}->{$group} ) );

    my $store = $this->{session}->{store};
    my $users = $this->{session}->{users};

    my $members = [];
    if (  !$expanding{$group}
        && $store->topicExists( $TWiki::cfg{UsersWebName}, $group ) )
    {
        $expanding{$group} = 1;
        my $text = $store->readTopicRaw( undef, $TWiki::cfg{UsersWebName},
            $group, undef );

        foreach ( split( /\r?\n/, $text ) ) {
            if (/$TWiki::regex{setRegex}GROUP\s*=\s*(.+)$/) {
                next unless ( $1 eq 'Set' );

                # Note: if there are multiple GROUP assignments in the
                # topic, only the last will be taken.
                my $f = $2;
                $members = _expandUserList( $this, $f );
            }
        }
        delete $expanding{$group};
    }
    $this->{eachGroupMember}->{$group} = $members;

    require TWiki::ListIterator;
    return new TWiki::ListIterator( $this->{eachGroupMember}->{$group} );
}

=begin twiki

---++ ObjectMethod isGroup ($user) -> boolean

See baseclass for documentation

=cut

sub isGroup {
    my ( $this, $user ) = @_;

    # Groups have the same username as wikiname as canonical name
    return 1 if $user eq $TWiki::cfg{SuperAdminGroup};

    return $user =~ /Group$/;
}

=begin twiki

---++ ObjectMethod eachGroup () -> ListIterator of groupnames

See baseclass for documentation

=cut

sub eachGroup {
    my ($this) = @_;
    _getListOfGroups($this);
    require TWiki::ListIterator;
    return new TWiki::ListIterator( \@{ $this->{groupsList} } );
}

=begin twiki

---++ ObjectMethod eachMembership ($cUID) -> ListIterator of groups this user is in

See baseclass for documentation

=cut

sub eachMembership {
    my ( $this, $user ) = @_;

    _getListOfGroups($this);
    require TWiki::ListIterator;
    my $it = new TWiki::ListIterator( \@{ $this->{groupsList} } );
    $it->{filter} = sub {
        $this->isInGroup( $user, $_[0] );
    };
    return $it;
}

=begin twiki

---++ ObjectMethod isAdmin( $cUID ) -> $boolean

True if the user is an admin
   * is $TWiki::cfg{SuperAdminGroup}
   * is a member of the $TWiki::cfg{SuperAdminGroup}

=cut

sub isAdmin {
    my ( $this, $cUID ) = @_;
    my $isAdmin = 0;

    # TODO: this might not apply now that we have BaseUserMapping - test
    if ( $cUID eq $TWiki::cfg{SuperAdminGroup} ) {
        $isAdmin = 1;
    }
    else {
        my $sag = $TWiki::cfg{SuperAdminGroup};
        $isAdmin = $this->isInGroup( $cUID, $sag );
    }

    return $isAdmin;
}

=begin twiki

---++ ObjectMethod findUserByEmail( $email ) -> \@cUIDs
   * =$email= - email address to look up
Return a list of canonical user names for the users that have this email
registered with the password manager or the user mapping manager.

The password manager is asked first for whether it maps emails.
If it doesn't, then the user mapping manager is asked instead.

=cut

sub findUserByEmail {
    my ( $this, $email ) = @_;
    ASSERT($email) if DEBUG;
    my @users;
    if ( $this->{passwords}->isManagingEmails() ) {
        my $logins = $this->{passwords}->findUserByEmail($email);
        if ( defined $logins ) {
            foreach my $l (@$logins) {
                $l = $this->login2cUID($l);
                push( @users, $l ) if $l;
            }
        }
    }
    else {

        # if the password manager didn't want to provide the service, ask
        # the user mapping manager
        unless ( $this->{_MAP_OF_EMAILS} ) {
            $this->{_MAP_OF_EMAILS} = {};
            my $it = $this->eachUser();
            while ( $it->hasNext() ) {
                my $uo = $it->next();
                map { push( @{ $this->{_MAP_OF_EMAILS}->{$_} }, $uo ); }
                  $this->getEmails($uo);
            }
        }
        push( @users, $this->{_MAP_OF_EMAILS}->{$email} );
    }
    return \@users;
}

=begin twiki

---++ ObjectMethod getEmails($name) -> @emailAddress

If $name is a user, return their email addresses. If it is a group,
return the addresses of everyone in the group.

The password manager and user mapping manager are both consulted for emails
for each user (where they are actually found is implementation defined).

Duplicates are removed from the list.

=cut

sub getEmails {
    my ( $this, $user, $seen ) = @_;

    $seen ||= {};

    my %emails = ();

    if ( $seen->{$user} ) {

        #print STDERR "preventing infinit recursion in getEmails($user)\n";
    }
    else {
        $seen->{$user} = 1;

        if ( $this->isGroup($user) ) {
            my $it = $this->eachGroupMember($user);
            while ( $it->hasNext() ) {
                foreach ( $this->getEmails( $it->next(), $seen ) ) {
                    $emails{$_} = 1;
                }
            }
        }
        else {
            if ( $this->{passwords}->isManagingEmails() ) {

                # get emails from the password manager
                foreach ( $this->{passwords}
                    ->getEmails( $this->getLoginName($user), $seen ) )
                {
                    $emails{$_} = 1;
                }
            }
            else {

                # And any on offer from the user mapping manager
                foreach ( mapper_getEmails( $this->{session}, $user ) ) {
                    $emails{$_} = 1;
                }
            }
        }
    }

    return keys %emails;
}

=begin twiki

---++ ObjectMethod setEmails($cUID, @emails) -> boolean

Set the email address(es) for the given user.
The password manager is tried first, and if it doesn't want to know the
user mapping manager is tried.

=cut

sub setEmails {
    my $this = shift;
    my $user = shift;

    if ( $this->{passwords}->isManagingEmails() ) {
        $this->{passwords}->setEmails( $this->getLoginName($user), @_ );
    }
    else {
        mapper_setEmails( $this->{session}, $user, @_ );
    }
}

=begin twiki

---++ StaticMethod mapper_getEmails($session, $user)

Only used if passwordManager->isManagingEmails= = =false
(The emails are stored in the user topics.

Note: This method is PUBLIC because it is used by the tools/upgrade_emails.pl
script, which needs to kick down to the mapper to retrieve email addresses
from TWiki topics.

=cut

sub mapper_getEmails {
    my ( $session, $user ) = @_;

    my ( $meta, $text ) = $session->{store}->readTopic(
        undef,
        $TWiki::cfg{UsersWebName},
        $session->{users}->getWikiName($user)
    );

    my @addresses;

    # Try the form first
    my $entry = $meta->get( 'FIELD', 'Email' );
    if ($entry) {
        push( @addresses, split( /;/, $entry->{value} ) );
    }
    else {

        # Now try the topic text
        foreach my $l ( split( /\r?\n/, $text ) ) {
            if ( $l =~ /^\s+\*\s+E-?mail:\s*(.*)$/mi ) {
                push @addresses, split( /;/, $1 );
            }
        }
    }

    return @addresses;
}

=begin twiki

---++ StaticMethod mapper_setEmails ($session, $user, @emails)

Only used if =passwordManager->isManagingEmails= = =false=.
(emails are stored in user topics

=cut

sub mapper_setEmails {
    my $session = shift;
    my $cUID    = shift;

    my $mails = join( ';', @_ );

    my $user = $session->{users}->getWikiName($cUID);

    my ( $meta, $text ) =
      $session->{store}->readTopic( undef, $TWiki::cfg{UsersWebName}, $user );

    if ( $meta->get('FORM') ) {

        # use the form if there is one
        $meta->putKeyed(
            'FIELD',
            {
                name       => 'Email',
                value      => $mails,
                title      => 'Email',
                attributes => 'h'
            }
        );
    }
    else {

        # otherwise use the topic text
        unless ( $text =~ s/^(\s+\*\s+E-?mail:\s*).*$/$1$mails/mi ) {
            $text .= "\n   * Email: $mails\n";
        }
    }

    $session->{store}
      ->saveTopic( $cUID, $TWiki::cfg{UsersWebName}, $user, $text, $meta );
}

=begin twiki

---++ ObjectMethod findUserByWikiName ($wikiname) -> list of cUIDs associated with that wikiname

See baseclass for documentation

The $skipExistanceCheck parameter
is private to this module, and blocks the standard existence check
to avoid reading .htpasswd when checking group memberships).

=cut

sub findUserByWikiName {
    my ( $this, $wn, $skipExistanceCheck ) = @_;
    my @users = ();

    if ( $this->isGroup($wn) ) {
        push( @users, $wn );
    }
    elsif ( $TWiki::cfg{Register}{AllowLoginName} ) {

        # Add additional mappings defined in TWikiUsers
        _loadMapping($this);
        if ( $this->{W2U}->{$wn} ) {

            # Wikiname to UID mapping is defined
            push( @users, $this->{W2U}->{$wn} );
        }
        else {

            # Bloody compatibility!
            # The wikiname is always a registered user for the purposes of this
            # mapping. We have to do this because TWiki defines access controls
            # in terms of mapped users, and if a wikiname is *missing* from the
            # mapping there is "no such user".
            push( @users, $this->login2cUID($wn) );
        }
    }
    else {

        # The wikiname is also the login name, so we can just convert
        # it directly to a cUID
        my $cUID = $this->login2cUID($wn);
        if ( $skipExistanceCheck || ( $cUID && $this->userExists($cUID) ) ) {
            push( @users, $cUID );
        }
    }
    return \@users;
}

=begin twiki

---++ ObjectMethod checkPassword( $login, $password ) -> $boolean

Finds if the password is valid for the given user.

Returns 1 on success, undef on failure.

=cut

sub checkPassword {
    my ( $this, $login, $pw ) = @_;
    return $this->{passwords}->checkPassword( $login, $pw );
}

=begin twiki

---++ ObjectMethod setPassword( $cUID, $newPassU, $oldPassU ) -> $boolean

BEWARE: $user should be a cUID, but is a login when the resetPassword
functionality is used.
The UserMapper needs to convert either one to a valid login for use by
the Password manager

TODO: needs fixing

If the $oldPassU matches matches the user's password, then it will
replace it with $newPassU.

If $oldPassU is not correct and not 1, will return 0.

If $oldPassU is 1, will force the change irrespective of
the existing password, adding the user if necessary.

Otherwise returns 1 on success, undef on failure.

=cut

sub setPassword {
    my ( $this, $user, $newPassU, $oldPassU ) = @_;
    return $this->{passwords}
      ->setPassword( $this->getLoginName($user), $newPassU, $oldPassU );
}

=begin twiki

---++ ObjectMethod passwordError( ) -> $string

returns a string indicating the error that happened in the password handlers
TODO: these delayed error's should be replaced with Exceptions.

returns undef if no error

=cut

sub passwordError {
    my ($this) = @_;
    return $this->{passwords}->error();
}

# TODO: and probably flawed in light of multiple cUIDs mapping to one wikiname
sub _cacheUser {
    my ( $this, $wikiname, $login ) = @_;
    ASSERT($wikiname) if DEBUG;

    $login ||= $wikiname;

    my $cUID = $this->login2cUID( $login, 1 );
    return unless ($cUID);
    ASSERT($cUID) if DEBUG;

    #$this->{U2L}->{$cUID}     = $login;
    $this->{U2W}->{$cUID}     = $wikiname;
    $this->{L2U}->{$login}    = $cUID;
    $this->{W2U}->{$wikiname} = $cUID;

    return $cUID;
}

# callback for search function to collate results
sub _collateGroups {
    my $ref   = shift;
    my $group = shift;
    return unless $group;
    push( @{ $ref->{list} }, $group );
}

# get a list of groups defined in this TWiki
sub _getListOfGroups {
    my $this = shift;
    ASSERT( ref($this) eq 'TWiki::Users::TopicUserMapping' ) if DEBUG;

    unless ( $this->{groupsList} ) {
        my $users = $this->{session}->{users};
        $this->{groupsList} = [];

        $this->{session}->search->searchWeb(
            _callback => \&_collateGroups,
            _cbdata   => {
                list  => $this->{groupsList},
                users => $users
            },
            inline    => 1,
            search    => "Set GROUP =",
            web       => $TWiki::cfg{UsersWebName},
            topic     => "*Group",
            type      => 'regex',
            nosummary => 'on',
            nosearch  => 'on',
            noheader  => 'on',
            nototal   => 'on',
            noempty   => 'on',
            format    => '$topic',
            separator => '',
        );
    }
    return $this->{groupsList};
}

# Build hash to translate between username (e.g. jsmith)
# and WikiName (e.g. Main.JaneSmith).
# PRIVATE subclasses should *not* implement this.
sub _loadMapping {
    my $this = shift;
    return if $this->{CACHED};
    $this->{CACHED} = 1;

  #TODO: should only really do this mapping IF the user is in the password file.
  #       except if we can't 'fetchUsers' like in the Passord='none' case -
  #       in which case the only time we
  #       know a login is real, is when they are logged in :(
    if (   ( $TWiki::cfg{Register}{AllowLoginName} )
        || ( !$this->{passwords}->canFetchUsers() ) )
    {
        my $store = $this->{session}->{store};
        if (
            $store->topicExists(
                $TWiki::cfg{UsersWebName},
                $TWiki::cfg{UsersTopicName}
            )
          )
        {
            my $text = $store->readTopicRaw(
                undef,
                $TWiki::cfg{UsersWebName},
                $TWiki::cfg{UsersTopicName}, undef
            );

            # Get the WikiNames and userids, and build hashes in both directions
            # This matches:
            #   * TWikiGuest - guest - 10 Mar 2005
            #   * TWikiGuest - 10 Mar 2005
            $text =~
s/^\s*\* (?:$TWiki::regex{webNameRegex}\.)?($TWiki::regex{wikiWordRegex})\s*(?:-\s*(\S+)\s*)?-.*$/(_cacheUser( $this, $1, $2)||'')/gome;
        }
    }
    else {

       #loginnames _are_ WikiNames so ask the Password handler for list of users
        my $iter = $this->{passwords}->fetchUsers();
        while ( $iter->hasNext() ) {
            my $login = $iter->next();
            _cacheUser( $this, $login, $login );
        }
    }
}

# Get a list of *canonical user ids* from a text string containing a
# list of user *wiki* names, *login* names, and *group ids*.
sub _expandUserList {
    my ( $this, $names ) = @_;

    $names ||= '';

    # comma delimited list of users or groups
    # i.e.: "%MAINWEB%.UserA, UserB, Main.UserC # something else"
    $names =~ s/(<[^>]*>)//go;    # Remove HTML tags

    my @l;
    foreach my $ident ( split( /[\,\s]+/, $names ) ) {

        # Dump the web specifier if userweb
        $ident =~ s/^($TWiki::cfg{UsersWebName}|%USERSWEB%|%MAINWEB%)\.//;
        next unless $ident;
        if ( $this->isGroup($ident) ) {
            my $it = $this->eachGroupMember($ident);
            while ( $it->hasNext() ) {
                push( @l, $it->next() );
            }
        }
        else {

            # Might be a wiki name (wiki names may map to several cUIDs)
            my %namelist =
              map { $_ => 1 }
              @{ $this->{session}->{users}->findUserByWikiName($ident) };

            # May be a login name (login names map to a single cUID)
            my $cUID = $this->{session}->{users}->getCanonicalUserID($ident);
            $namelist{$cUID} = 1 if $cUID;
            push( @l, keys %namelist );
        }
    }
    return \@l;
}

1;
