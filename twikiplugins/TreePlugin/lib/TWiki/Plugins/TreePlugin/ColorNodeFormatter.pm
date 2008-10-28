#
# Copyright (C) Slava Kozlov 2002 - All rights reserved
#
# TWiki extension TWiki::Plugins::TreePlugin::ColorNodeFormatter
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#

package TWiki::Plugins::TreePlugin::ColorNodeFormatter;
use base qw(TWiki::Plugins::TreePlugin::FormatOutlineNodeFormatter);

# class to format the nodes in a tree in an

# Constructor
sub new {
    my ( $class, $colors ) = @_;
    my $this = $class->SUPER::new();
    bless( $this, $class );
    $this->colors( split /,/, ( $colors || "pink,yellow" ) );
    return $this;
}

sub formatLevel {
    my ( $this, $level ) = @_;
    return $this->colors()->[ ( $level - 1 ) % ( $this->colorTotal() + 1 ) ];
}

# lazy, $#{$this->colors()} doesn't work

sub colorTotal {
    return $#{ $_[0]->{_colors} };
}

sub colors {
    my $this = shift;
    if (@_) { @{ $this->{_colors} } = @_ }
    return \@{ $this->{_colors} };
}

1;
