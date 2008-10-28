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

package TWiki::Users::LdapUser;

use strict;
use TWiki::Users::Password;
use TWiki::Contrib::LdapContrib;

@TWiki::Users::LdapUser::ISA = qw( TWiki::Users::Password );

=pod

---+++ TWiki::Users::LdapUser

Password manager that uses Net::LDAP to manage users and passwords.

Subclass of [[TWikiUsersPasswordDotPm][ =TWiki::Users::Password= ]].

This class does not grant any write access to the ldap server for security reasons. 
So you need to use your ldap tools to create user accounts or change passwords.

Configuration: add the following variables to your <nop>LocalSite.cfg 
   * $TWiki::cfg{Ldap}{server} = &lt;ldap-server uri>, defaults to localhost
   * $TWiki::cfg{Ldap}{base} = &lt;base dn> subtree that holds the user accounts
     e.g. ou=people,dc=your,dc=domain,dc=com

Implemented Interface:
   * checkPassword(login, password)
   * error()
   * fetchPass(login)
   * getEmails(login)
   * setEmails(login, @emails)
   
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

  return $this;
}

=pod

---++++ error() -> $errorMsg

return the last error during LDAP operations

=cut

sub error {
  my $this = shift;
  return $this->{ldap}->getError();
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
  return $entry->get_value('userPassword') if $entry;
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


  # lookup cache
  my $dn = $this->{ldap}{cache}{DN2U}{$login};
  unless ($dn) {
    my $entry = $this->{ldap}->getAccount($login);
    return 0 unless $entry;
    $dn = $entry->dn();
    $this->{ldap}{cache}{DN2U}{$login} = $dn;
    $this->{ldap}{cache}{U2DN}{$dn} = $login;
  }
  return $this->{ldap}->connect($dn, $passU);
}

=pod 

---++++ getEmails($login) -> @emails

emails might be stored in the ldap account as well if
the record is of type possixAccount and inetOrgPerson.
if this is not the case we fallback to twiki's default behavior

=cut

sub getEmails {
  my ($this, $login) = @_;

  $this->{ldap}->writeDebug("getEmails($login)");

  # guest has no email addrs
  return () if $login eq $TWiki::cfg{DefaultUserWikiName};

  # lookup cache
  $login = lc($login);
  my $emails = $this->{ldap}{cache}{U2EMAILS}{$login};
  return @$emails if $emails;

  my $entry = $this->{ldap}->getAccount($login);
  @{$emails} = $entry->get_value($this->{ldap}{mailAttribute}) if $entry;

  unless ($emails) {
    # fall back to the default approach
    $this->{ldap}->writeDebug("fall back to default approach to get email addresses");
    @{$emails} = $this->SUPER::getEmails($login) || ();
    $this->{ldap}->writeDebug("found emails for $login: ".join(',',@{$emails}));
  }
  $this->{ldap}{cache}{U2EMAILS}{$login} = $emails;

  return @{$emails};
}

=pod ObjectMethod finish()

Complete processing after the client's HTTP request has been responded.
i.e. destroy the ldap object.

=cut

sub finish {
  my $this = shift;

  $this->{ldap}->finish() if $this->{ldap};
  $this->{ldap} = undef;
  $this->SUPER::finish();
}

1;
