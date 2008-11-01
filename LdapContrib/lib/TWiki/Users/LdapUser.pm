# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
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

package TWiki::Users::LdapUser;

use strict;
use TWiki::Users::Password;
use TWiki::Contrib::LdapContrib;

@TWiki::Users::LdapUser::ISA = qw( TWiki::Users::Password );

=pod

---+++ TWiki::Users::LdapUser

Password manager that uses Net::LDAP to manage users and passwords.

Subclass of =TWiki::Users::Password=.

This class does not grant any write access to the ldap server for security reasons. 
So you need to use your ldap tools to create user accounts.

Configuration: add the following variables to your <nop>LocalSite.cfg 
   * $TWiki::cfg{Ldap}{server} = &lt;ldap-server uri>, defaults to localhost
   * $TWiki::cfg{Ldap}{base} = &lt;base dn> subtree that holds the user accounts
     e.g. ou=people,dc=your,dc=domain,dc=com

=cut

=pod

---++++ new($session) -> $ldapUser

Takes a session object, creates an LdapContrib object used to
delegate LDAP calls and returns a new TWiki::User::LdapUser object

=cut

sub new {
  my ($class, $session) = @_;

  my $this = bless($class->SUPER::new( $session ), $class);
  $this->{ldap} = &TWiki::Contrib::LdapContrib::getLdapContrib($session);

  my $secondaryImpl = $this->{ldap}->{secondaryPasswordManager};
  if ($secondaryImpl) {
    eval "use $secondaryImpl";
    die "Secondary Password Manager: $@" if $@;
    $this->{secondaryPasswordManager} = $secondaryImpl->new($session);
  }

  return $this;
}

=pod

---++++ error() -> $errorMsg

return the last error during LDAP operations

=cut

sub error {
  my $this = shift;
  $this->{error} = $this->{ldap}->getError();
  return return $this->{error};
}

=pod 

---++++ fetchPass($login) -> $passwd

SMELL: this method is used most of the time to detect if a given
login user is known to the database. the concrete (encrypted) password 
is of no interest: so better would be to implement an interface like
existsUser() or the like

=cut

sub fetchPass {
  my ($this, $login) = @_;

  $this->{ldap}->writeDebug("called fetchPass($login)");

  my $entry = $this->{ldap}->getAccount($login);
  return $entry->get_value('userPassword') 
    if $entry;

  return $this->{secondaryPasswordManager}->fetchPass($login)
    if $this->{secondaryPasswordManager};

  return 0;
}

=pod 

---++++ checkPassword($login, $password) -> $boolean

check passwd by binding to the ldap server

=cut

sub checkPassword {
  my ($this, $login, $passU) = @_;

  $this->{ldap}->writeDebug("called checkPassword($login, passU)");

  # guest has no password
  return 1 if $login eq $TWiki::cfg{DefaultUserWikiName};

  # get user record
  my $dn = $this->{ldap}->getDnOfLogin($login);
  $this->{ldap}->writeDebug("dn not found") unless $dn;

  return $this->{ldap}->connect($dn, $passU)
    if $dn;

  return $this->{secondaryPasswordManager}->checkPassword($login, $passU)
    if $this->{secondaryPasswordManager};

  return 0;
}

=pod

---++ isManagingEmails() -> $boolean

we aare managing emails, but don't allow setting emails. alas the
core does not distinguish this case, e.g. by using readOnly()

=cut

sub isManagingEmails {
  return 1;
}


=pod 

---++++ getEmails($login) -> @emails

emails might be stored in the ldap account as well if
the record is of type possixAccount and inetOrgPerson.
if this is not the case we fallback to twiki's default behavior

=cut

sub getEmails {
  my ($this, $login) = @_;

  # guest has no email addrs
  return () if $login eq $TWiki::cfg{DefaultUserWikiName};

  # get emails from ldap
  my $emails = $this->{ldap}->getEmails($login);

  return @{$emails} if $emails;

  return $this->{secondaryPasswordManager}->getEmails($login)
    if $this->{secondaryPasswordManager};

  return ();
}

=pod 

---++++ finish()

Complete processing after the client's HTTP request has been responded.
i.e. destroy the ldap object.

=cut

sub finish {
  my $this = shift;

  $this->{ldap}->finish() if $this->{ldap};
  $this->{ldap} = undef;
  $this->{secondaryPasswordManager}->finish(@_)
    if $this->{secondaryPasswordManager};
}

=pod

---++++ deleteUser( $user ) -> $boolean

LDAP users can't be deleted by TWiki.
So this will call the deleteUser interface of the secondary
password manager only

Returns 1 on success, undef on failure.

=cut

sub deleteUser {
  my $this = shift;

  return $this->{secondaryPasswordManager}->deleteUser(@_)
    if $this->{secondaryPasswordManager};

  $this->{error} = 'System does not support deleting users';
  return undef;
}

=pod

---++++ passwd( $user, $newPassword, $newPassword ) -> $boolean

This method can only change the LDAP password. It can not
add the user to the LDAP directory. To change the password the
old password must always be correct. There's no mode to force the
change irrespective of the existing password.

In any other case the secondary password manager gets the job.

=cut

sub passwd {
  my ( $this, $user, $newPassword, $oldPassword ) = @_;

  if ($this->{ldap}->{allowChangePassword} && defined($oldPassword) && $oldPassword ne '1') {
    if ($this->{ldap}->getDnOfLogin($user)) {
      return 1 if $this->{ldap}->changePassword($user, $newPassword, $oldPassword);
      $this->error();
      return undef;
    }
  }

  if ($this->{secondaryPasswordManager}) {
    my $result = $this->{secondaryPasswordManager}->passwd($user, $newPassword, $oldPassword);
    unless ($result) {
      $this->{error} = $this->{secondaryPasswordManager}->{error};
    }
    return $result;
  }

  $this->{error} = 'System does not support adding a user or forcing a  password change';
  return undef;
}

=pod

---++++ encrypt( $user, $passwordU, $fresh ) -> $passwordE

LDAP can't encrypt passwords. But maybe the secondary
password manager can.


=cut

sub encrypt {
  my $this = shift;

  return $this->{secondaryPasswordManager}->encrypt(@_)
    if $this->{secondaryPasswordManager};
  
  $this->{error} = 'System does not support encrypting passwords';
  return '';
}

=pod

---++++ setPassword( $login, $newPassU, $oldPassU ) -> $boolean

If the $oldPassU matches matches the user's password, then it will
replace it with $newPassU.

If $oldPassU is not correct and not 1, will return 0.

If $oldPassU is 1, will force the change irrespective of
the existing password, adding the user if necessary.

Otherwise returns 1 on success, undef on failure.

=cut

sub setPassword {
  my ($this, $login, $newUserPassword, $oldUserPassword) = @_;

  my $isOk = $this->{ldap}->changePassword($login, $newUserPassword, $oldUserPassword);

  if ($isOk) {
    $this->{error} = undef;
    return 1;
  } else {
    $this->error();
    return undef;
  }
}

=pod

---++++ setEmails($user, @emails)

Set the email address(es) for the given username.
TWiki can't set the email stored in LDAP. But may be the secondary
password manager can.

=cut

sub setEmails {
  my $this = shift;

  return $this->{secondaryPasswordManager}->setEmails(@_)
    if $this->{secondaryPasswordManager};
  
  $this->{error} = 'System does not support setting the email adress';
  return '';
}

=pod

---++++ findUserByEmail( $email ) -> \@users
   * =$email= - email address to look up
Return a list of user objects for the users that have this email registered
with the password manager. This will concatenate the result list of the
LDAP manager with the secondary password manager

=cut

sub findUserByEmail {
  my $this = shift;

  return undef unless $this->{secondaryPasswordManager};

  # add those from the secondary
  my @users;
  push @users, $this->{secondaryPasswordManager}->findUserByEmail(@_);

  # remove duplicates
  my %users = map {$_ => 1} @users;
  @users = keys %users;
  return \@users;
}

1;
