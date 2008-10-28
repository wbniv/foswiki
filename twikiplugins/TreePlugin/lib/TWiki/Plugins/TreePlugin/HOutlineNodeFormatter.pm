#
# Copyright (C) Slava Kozlov 2002 - All rights reserved
#
# TWiki extension TWiki::Plugins::TreePlugin::HOutlineNodeFormatter
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

package TWiki::Plugins::TreePlugin::HOutlineNodeFormatter;
use base qw(TWiki::Plugins::TreePlugin::FormatOutlineNodeFormatter);

# class to format the nodes in a tree in an outline format
# for example: Node1<ul><li>Child1</li><li>Child2</li></ul>
#
# each node is appended with its children
#
#

# Constructor
sub new {
    my $class = shift;
    my $this  = $class->SUPER::new(@_);
    return bless( $this, $class );
}

sub formatLevel {
    my $level = $_[1] + 1;
    return ( $level < 6 ) ? $level : 6;
}

1;

