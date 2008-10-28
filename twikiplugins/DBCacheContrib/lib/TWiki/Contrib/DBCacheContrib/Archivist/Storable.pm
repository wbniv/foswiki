#
# Copyright (C) 2007 Crawford Currie, http://c-dot.co.uk
#
package TWiki::Contrib::DBCacheContrib::Archivist::Storable;

use strict;

sub store {
    my( $this, $map, $cache ) = @_;
    require Storable;
    Storable::lock_store( $map, $cache );
}

sub retrieve {
    my( $this, $cache ) = @_;
    require Storable;
    return Storable::lock_retrieve( $cache );
}

1;
