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
package Foswiki::Configure::Checkers::WebMasterEmail;

use strict;

use Foswiki::Configure::Checker;

use base 'Foswiki::Configure::Checker';

sub check {
    my $this = shift;

    if ( !$Foswiki::cfg{WebMasterEmail} ) {
        return $this->WARN(
'Please make sure you enter the e-mail address of the webmaster. This is required for registration to work.'
        );
    }
    if ( $Foswiki::cfg{WebMasterEmail} !~
        /^[A-Z0-9._%-]+@[A-Z0-9.-]+\.[A-Z]{2,4}$/i )
    {
        return $this->WARN('I don\'t recognise this as a valid email address.');
    }
    return '';
}

1;
