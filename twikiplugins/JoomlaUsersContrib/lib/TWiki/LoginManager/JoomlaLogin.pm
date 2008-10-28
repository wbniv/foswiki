# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2006 Sven Dowideit, SvenDowideit@home.org.au
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

=pod

---+ package TWiki::LoginManager::JoomlaLogin

This is a login manager that you can specify in the security setup section of [[%SCRIPTURL%/configure%SCRIPTSUFFIX%][configure]]. It provides users with a template-based form to enter usernames and passwords, and works with the PasswordManager that you specify to verify those passwords.

Subclass of TWiki::LoginManager; see that class for documentation of the
methods of this class.

=cut

package TWiki::LoginManager::JoomlaLogin;

use strict;
use Assert;
use TWiki::LoginManager::TemplateLogin;

@TWiki::LoginManager::JoomlaLogin::ISA = ('TWiki::LoginManager::TemplateLogin');

sub new {
    my ( $class, $session ) = @_;

    my $this = bless( $class->SUPER::new($session), $class );
    $session->enterContext('can_login');
    return $this;
}

=pod

---++ ObjectMethod loadSession()

add Joomla cookie to the session management

=cut

sub loadSession {
    my $this  = shift;
    my $twiki = $this->{twiki};
    my $query = $twiki->{cgiQuery};

    ASSERT( $this->isa('TWiki::LoginManager::JoomlaLogin') ) if DEBUG;

    my $authUser = '';

    # see if there is a joomla username and password cookie
    #TODO: think i should check the password is right too.. otherwise ignore it
    my %cookies = fetch CGI::Cookie;
    if ( defined( $cookies{'usercookie[username]'} ) ) {
        my $id       = $cookies{'usercookie[username]'}->value;
        my $password = $cookies{'usercookie[password]'}->value;
        my $user     = $twiki->{users}->getCanonicalUserID( $id, undef, 1 );

        #print STDERR "$id, $password, $user";
        my $passwordHandler = $twiki->{users}->{passwords};

        #return $passwordHandler->checkPassword($this->{login}, $password);

        if ( defined($user)
            && $twiki->{users}->checkPassword( $user->login(), $password, 1 ) )
        {
            $authUser = $id;
        }
        else {

#mmm, if they have a cookie, but are not in the dba, either the db connection is busted, or we're in trouble
        }

        $this->userLoggedIn($authUser);
    }
    else {
        $authUser = $this->SUPER::loadSession();
    }
    return $authUser;
}

1;
