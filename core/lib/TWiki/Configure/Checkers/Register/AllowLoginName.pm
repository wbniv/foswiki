#
# Foswiki - The Free Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2007 TWiki Contributors.
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
package TWiki::Configure::Checkers::Register::AllowLoginName;

use strict;

use TWiki::Configure::Checker;

use base 'TWiki::Configure::Checker';

sub check {
    my $this = shift;
    my $n    = '';

    # Upgrade compatible option
    if ( defined( $TWiki::cfg{MapUserToWikiName} ) ) {
        if (  !$TWiki::cfg{MapUserToWikiName}
            && $TWiki::cfg{Register}{AllowLoginName}
            || $TWiki::cfg{MapUserToWikiName}
            && !$TWiki::cfg{Register}{AllowLoginName} )
        {
            $n = $this->WARN(<<WARNED);
Deprecated {MapUserToWikiName} setting is inconsistent with
{Register}{AllowLoginName}. {MapUserToWikiName} will be ignored.
You can safely remove the {MapUserToWikiName} setting from your
lib/LocalSite.cfg file to remove this warning.
WARNED
        }
    }
    return $n;
}

1;
