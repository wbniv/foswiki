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
package Foswiki::Configure::Checkers::AuthScripts;

use strict;

use Foswiki::Configure::Checker;

use base 'Foswiki::Configure::Checker';

sub check {
    my $this = shift;

    if ( $Foswiki::cfg{AuthScripts} ) {
        if ( $Foswiki::cfg{LoginManager} eq 'none' ) {
            return $this->WARN(
                <<'EOF'
You've asked that some scripts require authentication, but haven't
specified a way for users to log in. Please pick a LoginManager
other than 'none'.
EOF
            );
        }
    }
    return '';
}

1;
