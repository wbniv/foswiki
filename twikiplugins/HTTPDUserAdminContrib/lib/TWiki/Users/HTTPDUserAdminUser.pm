# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2007 SvenDowideit@home.org.au
# All Rights Reserved. 
# TWiki Contributors are listed in the AUTHORS file in the root of 
# this distribution. NOTE: Please extend that file, not this notice.
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

package TWiki::Users::HTTPDUserAdminUser;
use base 'TWiki::Users::Password';

use HTTPD::UserAdmin ();
use HTTPD::Authen ();
use Assert;
use strict;
use TWiki::Users::Password;
use Error qw( :try );

=pod

---+ package TWiki::Users::HTTPDUserAdminUser

Password manager that uses HTTPD::UserAdmin to manage users and passwords.

Subclass of [[TWikiUsersPasswordDotPm][ =TWiki::Users::Password= ]].
See documentation of that class for descriptions of the methods of this class.

Duplicates functionality of
[[TWikiUsersHtPasswdUserDotPm][ =TWiki::Users::HtPasswdUser=]];
and Adds the possiblilty of using DBM files, and databases to store the user information.

see http://search.cpan.org/~lds/HTTPD-User-Manage-1.66/lib/HTTPD/UserAdmin.pm

=cut

sub new {
    my( $class, $session ) = @_;

    my $this = $class->SUPER::new( $session );
    #$this->{apache} = new Apache::Htpasswd
    #  ( { passwdFile => $TWiki::cfg{Htpasswd}{FileName} } );
	my @config =  (
			DBType =>					$TWiki::cfg{HTTPDUserAdminContrib}{DBType} || 'Text',
			Host =>						$TWiki::cfg{HTTPDUserAdminContrib}{Host} || '',
			Port =>						$TWiki::cfg{HTTPDUserAdminContrib}{Port} || '',
			DB =>						$TWiki::cfg{HTTPDUserAdminContrib}{DB} || $TWiki::cfg{Htpasswd}{FileName},
			#uncommenting User seems to crash when using Text DBType :(
			#User =>						$TWiki::cfg{HTTPDUserAdminContrib}{User},
			Auth =>						$TWiki::cfg{HTTPDUserAdminContrib}{Auth} || '',
			Encrypt =>					$TWiki::cfg{HTTPDUserAdminContrib}{Encrypt} || 'crypt',
			Locking =>					$TWiki::cfg{HTTPDUserAdminContrib}{Locking} || '',
			Path =>						$TWiki::cfg{HTTPDUserAdminContrib}{Path} || '',
			Debug =>					$TWiki::cfg{HTTPDUserAdminContrib}{Debug},
			Flags =>					$TWiki::cfg{HTTPDUserAdminContrib}{Flags} || '',
			Driver =>					$TWiki::cfg{HTTPDUserAdminContrib}{Driver} || '',
			Server =>					$TWiki::cfg{HTTPDUserAdminContrib}{Server},	#undef == go detect
			UserTable =>				$TWiki::cfg{HTTPDUserAdminContrib}{UserTable} || '',
			NameField =>				$TWiki::cfg{HTTPDUserAdminContrib}{NameField} || '',
			PasswordField =>			$TWiki::cfg{HTTPDUserAdminContrib}{PasswordField} || '',
			#Debug =>				1
             );
             
    $this->{configuration} = \@config;
    $this->{userDatabase} = new HTTPD::UserAdmin(@{$this->{configuration}});
	
	print STDERR "new HTTPDAuth".join(', ', $this->{userDatabase}->list())."\n" if ($TWiki::cfg{HTTPDUserAdminContrib}{Debug});

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
    $this->SUPER::finish();
    undef $this->{userDatabase};
}

sub fetchUsers {
    my $this = shift;
    my @users = $this->{userDatabase}->list();
    return new ListIterator(\@users);
}

sub fetchPass {
    my( $this, $login ) = @_;
    ASSERT( $login ) if DEBUG;
    my $r = $this->{userDatabase}->password( $login );
    $this->{error} = undef;
    return $r;
}

sub checkPassword {
    my ( $this, $login, $password ) = @_;
	
	#TODO: this should be extracted to a new LoginManager i think
	my $authen = new HTTPD::Authen (@{$this->{configuration}});
	return $authen->check($login, $password);
}

sub removeUser {
    my( $this, $login ) = @_;
    ASSERT( $login ) if DEBUG;

    $this->{error} = undef;
    my $r;
    try {
        $r = $this->{userDatabase}->delete( $login );
        #$this->{error} = $this->{apache}->error() unless (defined($r));        
    } catch Error::Simple with {
        $this->{error} = 'problem deleting user';
    };
    return $r;
}

sub setPassword {
    my( $this, $login, $newPassU, $oldPassU ) = @_;
    ASSERT( $login ) if DEBUG;

    if( defined($oldPassU)) {
        my $ok = 0;
        try {
            $ok = $this->checkPassword( $login, $oldPassU );
        } catch Error::Simple with {
        };
        unless( $ok ) {
            $this->{error} = "Wrong password";
            return 0;
        }
    }

    my $added = 0;
    try {
        $added = $this->{userDatabase}->add( $login, $newPassU );
        $this->{error} = undef;
    } catch Error::Simple with {
        $this->{error} = 'problem changing password';
    };

    return $added;
}

sub error {
    my $this = shift;
    return $this->{error} || undef;
}

sub isManagingEmails {
    return 1;
}

# emails are stored in extra info field as a ; separated list
sub getEmails {
    my( $this, $login) = @_;
	return unless ($this->{userDatabase}->exists($login));
	my $settings = $this->{userDatabase}->fetch($login, ('emails'));
	
	
	#use Data::Dumper;
	#print STDERR "\nsettings . ".$settings." ..".Dumper($settings, keys(%{$settings}));

    my @r = split(/;/, $$settings{emails});
    $this->{error} = undef;
    return @r;
}

sub setEmails {
    my $this = shift;
    my $login = shift;
    my $r = $this->{userDatabase}->update($login, undef,  {emails=>join(';', @_)} );
    $this->{error} =  undef;
    return $r;
}

1;
