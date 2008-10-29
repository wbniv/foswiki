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

=pod

---+!! package TWiki::LoginManager::Session

Class to provide CGI::Session like infra-structure, compatible with
TWiki Runtime Engine mechanisms other than CGI.

It inherits from CGI::Session and redefine methods that uses %ENV directly,
replacing by calls to TWiki::Request object, that is passed to constructor.

It also redefines =name= method, to avoid creating CGI object.

=cut

package TWiki::LoginManager::Session;

use strict;
use base 'CGI::Session';

*VERSION = \$CGI::Session::VERSION;
*NAME    = \$CGI::Session::NAME;

sub load {
    my $this = shift;
    local %ENV;
    $ENV{REMOTE_ADDR} = @_ == 1 ? $_[0]->remoteAddress : $_[1]->remoteAddress;
    $this->SUPER::load(@_);
}

sub query {
    my $self = shift;

    if ( $self->{_QUERY} ) {
        return $self->{_QUERY};
    }
    return $self->{_QUERY} = TWiki::Request->new();
}

sub _ip_matches {
  return ( $_[0]->{_DATA}->{_SESSION_REMOTE_ADDR} eq $_[0]->{_QUERY}->remoteAddress );
}

1;
