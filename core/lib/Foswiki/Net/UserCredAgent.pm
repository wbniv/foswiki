# See bottom of file for license and copyright information

# LWP::UserAgent subclass used to pass in username and password,
# and use the Foswiki proxy setup

package Foswiki::Net::UserCredAgent;
use base 'LWP::UserAgent';

sub new {
    my ( $class, $user, $pass ) = @_;
    my $this = $class->SUPER::new();
    $this->{user} = $user;
    $this->{pass} = $pass;
    if ( $Foswiki::cfg{PROXY}{HOST} ) {
        my $proxy = $Foswiki::cfg{PROXY}{HOST};
        if ( $Foswiki::cfg{PROXY}{PORT} ) {
            $proxy .= ':' . $Foswiki::cfg{PROXY}{PORT};
        }
        $this->proxy( [ 'http', 'https' ], $proxy );
    }
    return $this;
}

sub get_basic_credentials {
    my ( $this, $realm, $uri ) = @_;
    return ( $this->{user}, $this->{pass} );
}

1;
__DATA__
# Module of Foswiki - The Free Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008 Foswiki Contributors. All Rights Reserved.
# Foswiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 2007 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
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
