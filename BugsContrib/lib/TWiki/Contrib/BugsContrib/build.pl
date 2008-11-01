#!/usr/bin/perl -w
#
# Build file
#
package BugsContribBuild;

BEGIN {
    foreach my $pc (split(/:/, $ENV{TWIKI_LIBS})) {
        unshift @INC, $pc;
    }
}

use TWiki::Contrib::Build;

@BugsContribBuild::ISA = ( "TWiki::Contrib::Build" );

sub new {
    my $class = shift;
    return bless( $class->SUPER::new( "BugsContrib" ), $class );
}

$build = new BugsContribBuild();
$build->build($build->{target});
