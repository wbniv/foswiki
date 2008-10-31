#
# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2006 TWiki Contributors.
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
package TWiki::Configure::Checkers::LowerNational;
use base 'TWiki::Configure::Checker';

use strict;

sub check {
    my $this = shift;

    # support upgrade from old configuration, where LowerNational and
    # UpperNational were stored as REGEX'es (now they are STRING's):
    if ( $TWiki::cfg{LowerNational} =~ /^\(\?-xism:(.*)\)$/ ) {
        $TWiki::cfg{LowerNational} = $1;
    }

    if ( $] < 5.006 || !$TWiki::cfg{UseLocale} ) {

        # Locales are off/broken, or using pre-5.6 Perl, so have to
        # explicitly list the accented characters (but not if using UTF-8)
        my $forLowerNat = join '',
          grep { uc($_) ne $_ and m/[^a-z]/ } map { chr($_) } 1 .. 255;

        if ($forLowerNat) {
            return $this->WARN(
                <<HERE
The following lower case accented characters have been found in this locale
and should be considered for use in this parameter:
<strong>$forLowerNat</strong>
HERE
            );
        }
    }
    return '';
}

1;
