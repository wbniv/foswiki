#
# Copyright (C) Motorola 2002 - All rights reserved
#
# TWiki extension that adds tags for action tracking
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
use strict;
use integer;

package TWiki::Plugins::ActionTrackerPlugin::AttrDef;

sub new {
    my ( $class, $type, $size, $match, $candef, $values ) = @_;
    my $this = ();

    $this->{type} = $type;
    $this->{size} = $size || 1;
    $this->{match} = $match || 1;
    $this->{defineable} = $candef;
    $this->{values} = $values;

    return bless( $this, $class );
}

sub stringify {
    my $this = shift;
    my $text = 'type=' . $this->{type} . ' size=' . $this->{size};
    $text .= ' redefinable' if ( $this->{definable} );
    $text .= ' matchable' if ( $this->{match} );
    if ( defined( $this->{values} )) {
        $text .= ' values=' . join( ',', @{$this->{values}} );
    }
    return 'AttrDef('.$text.')';
}

# PUBLIC return the first value in the select set, or undef
sub firstSelect {
    my $this = shift;
    if ( defined( $this->{values} )) {
        return @{$this->{values}}[0];
    }
    return undef;
}

sub isRedefinable {
    my $this = shift;

    return $this->{defineable} == 1;
}

1;
