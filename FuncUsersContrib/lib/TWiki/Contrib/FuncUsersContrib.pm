use TWiki::Plugins;
use strict;

# Copyright (C) Crawford Currie 2006
# An emergency module to make up for defisciences in the TWiki::Func API
# These methods are designed to be added to TWiki::Func; though the Users object
# should probably implement them.

package TWiki::Contrib::FuncUsersContrib;

use vars qw( $VERSION $RELEASE );
my( $web, $topic, $rev ) = @_;

$VERSION = '$Rev: 10558$';
$RELEASE = 1.000;

# Compatibility for plugins that used it before the methods
# moved to TWiki::Func
sub getListOfUsers { return TWiki::Func::getListOfUsers(@_); }
sub getListOfGroups { return TWiki::Func::getListOfGroups(@_); }
sub lookupUser { return TWiki::Func::lookupUser(@_); }
sub getACLs { return TWiki::Func::getACLs(@_); }
sub setACLs { return TWiki::Func::setACLs(@_); }
sub isAdmin { return TWiki::Func::isAdmin(@_); }
sub isInGroup { return TWiki::Func::isInGroup(@_); }

# Extend TWiki::Func
package TWiki::Func;

=pod

---++ getListOfUsers() -> \@list
Get a list of the registered users *not* including groups. The returned
list is a list of TWiki::User objects.


To get a combined list of users and groups, you can do this:
<verbatim>
@usersandgroups = ( @{TWiki::Func::getListOfUsers()}, TWiki::Func::getListOfGroups() );
</verbatim>

=cut

sub getListOfUsers {
    my $session = $TWiki::Plugins::SESSION;
    my $users = $session->{users};

    #if we have the UserMapping changes (post 4.0.2)
    return $session->{users}->getAllUsers() if (defined (&TWiki::Users::getAllUsers));

    $users->lookupLoginName('guest'); # load the cache

    unless( $users->{_LIST_OF_REGISTERED_USERS} ) {
        my @list =
            grep { $_ }
              map {
                  my( $w, $t ) = TWiki::Func::normalizeWebTopicName(
                      $TWiki::cfg{UsersWebName}, $_);
                  $users->findUser( $t, "$w.$t");
              } values %{$users->{U2W}};
        $users->{_LIST_OF_REGISTERED_USERS} = \@list;
    }
    return $users->{_LIST_OF_REGISTERED_USERS};
}

sub _collateGroups {
    my $ref = shift;
    my $group = shift;
    return unless $group;
    my $groupObject = $ref->{users}->findUser( $group );
    push (@{$ref->{list}}, $groupObject) if $groupObject;
}

=pod

---++ getListOfGroups() -> \@list
Get a list of groups. The returned list is a list of TWiki::User objects.

=cut

sub getListOfGroups {
    my $session = $TWiki::Plugins::SESSION;
    my $users = $session->{users};

    #if we have the UserMapping changes (post 4.0.2)
    return $session->{users}->getAllGroups() if (defined (&TWiki::Users::getAllGroups));

    #This code assumes we are using TWiki topic based Group mapping
    unless( $users->{_LIST_OF_GROUPS} ) {
        my @list;
        $session->{search}->searchWeb(
            _callback     => \&_collateGroups,
            _cbdata       =>  { list => \@list, users => $users },
            inline        => 1,
            search        => "Set GROUP =",
            web           => 'all',
            topic         => "*Group",
            type          => 'regex',
            nosummary     => 'on',
            nosearch      => 'on',
            noheader      => 'on',
            nototal       => 'on',
            noempty       => 'on',
            format	     => "\$web.\$topic",
            separator     => '',
           );
        $users->{_LIST_OF_GROUPS} = \@list;
    }

    return $users->{_LIST_OF_GROUPS};
}

=pod

---++ lookupUser( %spec ) -> \$user
Find the TWiki::User object for a named user.
   * =%spec= - the identifying marks of the user. The following options are supported:
      * =wikiname= - the wikiname of the user (web name optional, also supports %MAINWEB%)
      * =login= - login name of the user
      * =email= - email address of the user **returns an array of users**
For example,
<verbatim>
my @pa = TWiki::Func::lookupUser( email => "pa@addams.org" );
my $ma = TWiki::Func::lookupUser( wikiname => "%MAINWEB%.MorticiaAddams" );
</verbatim>


=cut

sub lookupUser {
    my( %opts ) = @_;
    my $user;
    my $users = $TWiki::Plugins::SESSION->{users};

    if( $opts{wikiname} ) {
        if( $user = $users->findUser($opts{wikiname},$opts{wikiname},1)) {
            return $user;
        }
    }

    if( $opts{login} ) {
        if( $user = $users->findUser($opts{login},undef,1)) {
            return $user;
        }
    }

    if( $opts{email} ) {
        #if we have the UserMapping changes (post 4.0.3)
        if (defined &TWiki::Users::findUserByEmail) {
            return $users->findUserByEmail( $opts{email} );
        } else {
            # SMELL: there is no way in TWiki to map from an email back to a user, so
        	# we have to cheat. We do this as follows:
            unless( $users->{_MAP_OF_EMAILS} ) {
        	    $users->lookupLoginName('guest'); # load the cache
                #SMELL: this will not work for non-topic based users
            	foreach my $wn ( keys %{$users->{W2U}} ) {
                    my $ou = $users->findUser( $users->{W2U}{$wn}, $wn, 1 );
                    map { push( @{$users->{_MAP_OF_EMAILS}->{$_}}, $ou); } $ou->emails();

            	}
            }
            return $users->{_MAP_OF_EMAILS}->{$opts{email}};
        }
    }

    return undef;
}

=pod

---++ getACLs( \@modes, $web, $topic ) -> \%acls
Get the Access Control Lists controlling which registered users *and groups* are allowed to access the topic (web).
   * =\@modes= - list of access modes you are interested in; e.g. [ "VIEW","CHANGE" ]
   * =$web= - the web
   * =$topic= - if =undef=  then the setting is taken as a web setting e.g. WEBVIEW. Otherwise it is taken as a topic setting e.g. TOPICCHANGE

=\%acls= is a hash indexed by *user name* (web.wikiname). This maps to a hash indexed by *access mode* e.g. =VIEW=, =CHANGE= etc. This in turn maps to a boolean; 0 for access denied, non-zero for access permitted.
<verbatim>
my $acls = TWiki::Func::getACLs( [ 'VIEW', 'CHANGE', 'RENAME' ], $web, $topic );
foreach my $user ( keys %$acls ) {
    if( $acls->{$user}->{VIEW} ) {
        print STDERR "$user can view $web.$topic\n";
    }
}
</verbatim>
The =\%acls= object may safely be written to e.g. for subsequent use with =setACLs=.

__Note__ topic ACLs are *not* the final permissions used to control access to a topic. Web level restrictions may apply that prevent certain access modes for individual topics.

*WARNING* when you use =setACLs= to set the ACLs of a web or topic, the change is not committed to the database until the current session exist. After =setACLs= has been called on a web or topic, the results of =getACLS= for that web/topic are *undefined*.

=cut

sub getACLs {
    my( $modes, $web, $topic ) = @_;

    my $context = 'TOPIC';
    unless( $topic ) {
        $context = 'WEB';
        $topic = $TWiki::cfg{WebPrefsTopicName};
    }

    my @knownusers = map { $_->webDotWikiName() }
      ( @{getListOfUsers()}, @{getListOfGroups()} );

    my %acls;

    # By default, allow all to access all
    foreach my $user ( @knownusers ) {
        foreach my $mode ( @$modes ) {
            $acls{$user}->{$mode} = 1;
        }
    }
    #print STDERR "Got users ",join(',',keys %acls),"\n";
    foreach my $mode ( @$modes ) {
        foreach my $perm ( 'ALLOW', 'DENY' ) {
            my $users;
            if ($context eq 'WEB') {
                $users = $TWiki::Plugins::SESSION->{prefs}->getWebPreferencesValue(
                    $perm.$context.$mode, $web, $topic );
                #print STDERR "$perm$context$mode ($web) is not defined\n" unless defined($users);
            } else {
                $users = $TWiki::Plugins::SESSION->{prefs}->getTopicPreferencesValue(
                    $perm.$context.$mode, $web, $topic );
                #print STDERR "$perm$context$mode ($web, $topic) is not defined\n" unless defined($users);
            }
            next unless defined($users);
            #print STDERR "$perm$context$mode\n";

            my @lusers =
              grep { $_ }
                map {
                    my( $w, $t ) = TWiki::Func::normalizeWebTopicName(
                        $TWiki::cfg{UsersWebName}, $_);
                    lookupUser( wikiname => "$w.$t");
                } split( /[ ,]+/, $users || '' );

            # expand groups
            my @users;
            while( scalar( @lusers )) {
                my $user = pop( @lusers );
                if( $user->isGroup()) {
                    # expand groups and add individual users
                    my $group = $user->groupMembers();
                    push( @lusers, @$group ) if $group;
                }
                push( @users, $user->webDotWikiName() );
            }

            if( $perm eq 'ALLOW' ) {
                # If ALLOW, only users in the ALLOW list are permitted,
                # so change the default for all other users to 0.
                foreach my $user ( @knownusers ) {
                    #print STDERR "Disallow ",$user,"\n";
                    $acls{$user}->{$mode} = 0;
                }
                foreach my $user ( @users ) {
                    #print STDERR "Allow ",$user,"\n";
                    $acls{$user}->{$mode} = 1;
                }
            } else {
                foreach my $user ( @users ) {
                    #print STDERR "Deny ",$user,"\n";
                    $acls{$user}->{$mode} = 0;
                }
            }
        }
    }

    return \%acls;
}

=pod

---++ setACLs( \@modes, \%acls, $web, $topic, $plainText )
Set the access controls on the named topic.
   * =\@modes= - list of access modes you want to set; e.g. [ "VIEW","CHANGE" ]
   * =$web= - the web
   * =$topic= - if =undef=, then this is the ACL for the web. otherwise it's for the topic.
   * =\%acls= - must be a hash indexed by *user name* (web.wikiname). This maps to a hash indexed by *access mode* e.g. =VIEW=, =CHANGE= etc. This in turn maps to a boolean value; 1 for allowed, and 0 for denied. See =getACLs= for an example of this kind of object.
   * =$plainText - if set, permissions will be written using plain text (* Set) in the topic body rather than being stored in meta-data (the default)

Access modes used in \%acls that do not appear in \@modes are simply ignored.

If there are any errors, then an =Error::Simple= will be thrown.

*WARNING* when you use =setACLs= to set the ACLs of a web or topic, the change is not committed to the database until the current session exist. After =setACLs= has been called on a web or topic, the results of =getACLS= for that web/topic are *undefined*.

=cut

sub setACLs {
    my( $modes, $acls, $web, $topic, $plainText ) = @_;

    my $context = 'TOPIC';
    unless( $topic ) {
        $context = 'WEB';
        $topic = $TWiki::cfg{WebPrefsTopicName};
    }

    my( $meta, $text ) = TWiki::Func::readTopic( $web, $topic );

    my @knownusers = map { $_->webDotWikiName() }
      ( @{getListOfUsers()}, @{getListOfGroups()} );
    if( $plainText ) {
        $text .= "\n" unless $text =~ /\n$/s;
    }

    foreach my $op ( @$modes ) {
        my @allowed = grep { $acls->{$_}->{$op} } @knownusers;
        my @denied = grep { !$acls->{$_}->{$op} } @knownusers;
        # Remove existing preferences of this type in text
        $text =~ s/^(   |\t)+\* Set (ALLOW|DENY)$context$op =.*$//gm;
        $meta->remove('PREFERENCE', 'DENY'.$context.$op);
        $meta->remove('PREFERENCE', 'ALLOW'.$context.$op);

        if( scalar( @denied )) {
            # Work out the access modes
            my $name;
            my $set;
            if( scalar( @denied ) <= scalar( @allowed )) {
                $name = 'DENY'.$context.$op;
                $set = \@denied;
            } else {
                $name = 'ALLOW'.$context.$op;
                $set = \@allowed;
            }
            if ($plainText) {
                $text .= "   * Set $name = ". join(' ', @$set)."\n";
            } else {
                $meta->putKeyed( 'PREFERENCE',
                                 {
                                     name => $name,
                                     type => 'Set',
                                     title => 'PREFERENCE_'.$name,
                                     value => join(' ', @$set)
                                    }
                                );
            }
        }
    }

    # If there is an access control violation this will throw.
    #SMELL: if you call setACLs from a plugin save handler, you will get an undefined mess as saveTopic calls them again
    TWiki::Func::saveTopic( $web, $topic,
                            $meta, $text, { minor => 1 } );
}

=pod

---++ isAdmin() -> $boolean

Find out if the currently logged-in user is an admin or not.

=cut

sub isAdmin {
    return $TWiki::Plugins::SESSION->{user}->isAdmin();
}

=pod

---++ isInGroup( $group ) -> $boolean

Find out if the currently logged-in user is in the named group. e.g.
<verbatim>
if( TWiki::Func::isInGroup( "PopGroup" )) {
    ...
}
</verbatim>

=cut

sub isInGroup {
    my $group = shift;

    return $TWiki::Plugins::SESSION->{user}->isInList( $group );
}


1;
