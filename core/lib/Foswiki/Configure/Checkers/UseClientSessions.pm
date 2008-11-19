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
package Foswiki::Configure::Checkers::UseClientSessions;

use strict;

use Foswiki::Configure::Checker;

use base 'Foswiki::Configure::Checker';

my @modules = (
    {
        name            => 'CGI::Session',
        usage           => "Sessions",
        requiredVersion => 1,
    },
    {
        name               => 'CGI::Cookie',
        usage              => "Sessions",
        recommendedVersion => 1,
    },
);

sub check {
    my $this = shift;

    my $mess = '';
    if ( !eval "use CGI::Cookie; 1" ) {
        $mess .= <<HERE;
The CGI::Cookie Perl module is required for session support, but is not
available.
HERE
    }
    if ( !eval "use CGI::Session; 1" ) {
        $mess .= <<HERE;
The CGI::Session Perl module is required for session support, but is not
available.
HERE
    }
    if ($mess) {
        if ( $Foswiki::cfg{UseClientSessions} ) {
            $mess = $this->ERROR($mess);
        }
        else {
            $mess = $this->WARN($mess);
        }
    }
    return $mess;
}

1;
