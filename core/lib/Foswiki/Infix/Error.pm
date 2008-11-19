
=pod

---+ package Foswiki::Infix::Error

Class of errors used with Foswiki::Infix::Parser

=cut

package Foswiki::Infix::Error;
use base 'Error';

use strict;

sub new {
    my ( $class, $message, $expr, $at ) = @_;
    if ( defined $expr && length($expr) ) {
        $message .= " in '$expr'";
    }
    if ( defined $at && length($at) ) {
        $message .= " at '$at'";
    }
    return $class->SUPER::new(
        -text => $message,
        -file => 'dummy',
        -line => 'dummy'
    );
}

1;

__DATA__

Module of Foswiki - The Free Open Source Wiki, http://foswiki.org/, http://Foswiki.org/

Copyright (C) 2005-2007 Foswiki Contributors. All Rights Reserved.
Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

Author: Crawford Currie http://c-dot.co.uk
