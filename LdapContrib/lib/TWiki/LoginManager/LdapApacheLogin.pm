# Module of Foswiki - The Free Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2007 Michael Daum http://michaeldaumconsulting.com
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
# For licensing info read LICENSE file in the TWiki root.

package TWiki::LoginManager::LdapApacheLogin;

use strict;
use Assert;
use TWiki::LoginManager::ApacheLogin;
use TWiki::Contrib::LdapContrib;

@TWiki::LoginManager::LdapApacheLogin::ISA = qw( TWiki::LoginManager::ApacheLogin );

sub new {
  my ($class, $session) = @_;

  my $this = bless( $class->SUPER::new($session), $class );
  $this->{ldap} = TWiki::Contrib::LdapContrib::getLdapContrib($session);
  return $this;
}

sub loadSession {
  my $this = shift;

  my $authUser = $this->SUPER::loadSession(@_);

  $this->{ldap}->checkCacheForLoginName($authUser) if defined $authUser;

  return $authUser;
}

1;
