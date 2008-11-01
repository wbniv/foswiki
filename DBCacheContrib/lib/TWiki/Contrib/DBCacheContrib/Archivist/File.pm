#
# Copyright (C) 2007 Crawford Currie, http://c-dot.co.uk
#
package TWiki::Contrib::DBCacheContrib::Archivist::File;
use strict;

use Data::Dumper;

sub store {
    my( $this, $data, $cache ) = @_;

    open(F, ">$cache" ) || die "$cache: $!";
    # get an exclusive lock on the file (2==LOCK_EX)
    flock( F, 2 ) || die $!;
    print F Data::Dumper->Dump( [ $data ], [ 'data' ] );
    flock( F, 8 ) || die( "LOCK_UN failed: $!" );
    close( F );
}

sub retrieve {
    my( $this, $cache ) = @_;

    open(F, "<$cache") || die "$cache: $!";
    # 1==LOCK_SH
    flock( F, 1 ) || die $!;

    local $/;
    my $conts = <F>;
    flock( F, 8 ) || die( "LOCK_UN failed: $!" );
    close( F );

    # MAJOR SECURITY RISK - eval of file contents
    $conts =~ /^(.*)$/; # unchecked untaint
    my $data;
    eval $conts;

    return $data;
}

1;
