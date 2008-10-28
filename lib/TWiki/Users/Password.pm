# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
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

---+ package TWiki::Users::Password

Base class of all password handlers. Default behaviour is no passwords,
so anyone can be anyone they like.

The methods of this class should be overridded by subclasses that want
to implement other password handling methods.

=cut

package TWiki::Users::Password;

use strict;
use Assert;

=pod

---++ ClassMethod new( $session ) -> $object

Constructs a new password handler of this type, referring to $session
for any required TWiki services.

=cut

sub new {
    my( $class, $session ) = @_;

    my $this = bless( { session => $session }, $class );
    $this->{error} = undef;
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
    undef $this->{error};
    undef $this->{session};
}

=pod

---++ ObjectMethod readOnly(  ) -> boolean

returns true if the password database is not currently modifyable
also needs to call
$this->{session}->enter_context('passwords_modifyable');
if you want to be able to use the existing TWikiUserMappingContrib ChangePassword topics

=cut

sub readOnly {
    return 1;   #there _is_ no password file.
}

=pod

---++ ObjectMethod fetchPass( $login ) -> $passwordE

Implements TWiki::Password

Returns encrypted password if succeeds.
Returns 0 if login is invalid.
Returns undef otherwise.

=cut

sub fetchPass {
    return undef;
}

=pod

---++ ObjectMethod checkPassword( $login, $passwordU ) -> $boolean

Finds if the password is valid for the given user.

Returns 1 on success, undef on failure.

=cut

sub checkPassword {
    my $this = shift;
    $this->{error} = undef;
    return 1;
}

=pod

---++ ObjectMethod removeUser( $login ) -> $boolean

Delete the users entry.

=cut

sub removeUser {
    my $this = shift;
    $this->{error} = undef;
    return 1;
}


=pod

---++ ObjectMethod setPassword( $login, $newPassU, $oldPassU ) -> $boolean

If the $oldPassU matches matches the user's password, then it will
replace it with $newPassU.

If $oldPassU is not correct and not 1, will return 0.

If $oldPassU is 1, will force the change irrespective of
the existing password, adding the user if necessary.

Otherwise returns 1 on success, undef on failure.

=cut

sub setPassword {
    my $this = shift;
    $this->{error} = 'System does not support changing passwords';
    return 1;
}

=pod

---++ encrypt( $login, $passwordU, $fresh ) -> $passwordE

Will return an encrypted password. Repeated calls
to encrypt with the same login/passU will return the same passE.

However if the passU is changed, and subsequently changed _back_
to the old login/passU pair, then the old passE is no longer valid.

If $fresh is true, then a new password not based on any pre-existing
salt will be used. Set this if you are generating a completely
new password.

=cut

sub encrypt {
    return '';
}

=pod

---++ ObjectMethod error() -> $string

Return any error raised by the last method call, or undef if the last
method call succeeded.

=cut

sub error {
    my $this = shift;

    return $this->{error};
}

=pod

---++ ObjectMethod isManagingEmails() -> $boolean
Determines if this manager can store and retrieve emails. The password
manager is used in preference to the user mapping manager for storing
emails, on the basis that emails need to be secure, and the password
database is the most secure place. If a password manager does not
manage emails, then TWiki will fall back to using the user mapping
manager (which by default will store emails in user topics)

The default ('none') password manager does *not* manage emails.

=cut

sub isManagingEmails {
    return 0;
}

=pod

---++ ObjectMethod getEmails($login) -> @emails
Fetch the email address(es) for the given login. Default
behaviour is to return an empty list. Called by Users.pm.
Only used if =isManagingEmails= -> =true=.

=cut

sub getEmails {
    ASSERT(0, "should never be called") if DEBUG;
}

=pod

---++ ObjectMethod setEmails($login, @emails) -> $boolean
Set the email address(es) for the given login name. Returns true if
the emails were set successfully.
Default behaviour is a nop, which will result in the user mapping manager
taking over. Called by Users.pm.
Only used if =isManagingEmails= -> =true=.

=cut

sub setEmails {
    ASSERT(0, "should never be called") if DEBUG;
}

=pod

---++ ObjectMethod findUserByEmail($email) -> \@users
Returns an array of login names that relate to a email address.
Defaut behaviour is a nop, which will result in the user mapping manager
being asked for its opinion. If subclass implementations return a value for
this, then the user mapping manager will *not* be asked.
Only used if =isManagingEmails= -> =true=.

Called by Users.pm.

=cut

sub findUserByEmail {
    ASSERT(0, "should never be called") if DEBUG;
}

=pod 

---++ ObjectMethod canFetchUsers() -> boolean

returns true if the fetchUsers method is implemented and can return an iterator of users.
returns undef / nothing in this case, as we are unable to generate a list of users

=cut

sub canFetchUsers {
    return;
}

=pod 

---++ ObjectMethod fetchUsers() -> new TWiki::ListIterator(\@users)

returns a TWikiIterator of loginnames from the password source. If AllowLoginNames is false
this is used to remove the need for a TWikiUsers topic.

=cut

sub fetchUsers {

    die "not Implemented in Base class";
    #return new TWiki::ListIterator(\@users);
}


1;
