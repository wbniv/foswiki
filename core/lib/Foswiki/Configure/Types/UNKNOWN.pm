#
# Foswiki - The Free Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2006 Foswiki Contributors.
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
#
# Value type for objects of unknown type, such as uncommented
# config settings from LocalSite.cfg
package Foswiki::Configure::Types::UNKNOWN;

use strict;

use base 'Foswiki::Configure::Type';

sub new {
    my $class = shift;

    return bless( { name => 'UNKNOWN' }, $class );
}

1;
