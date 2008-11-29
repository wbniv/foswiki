#!/usr/bin/perl -w
#
# Build file
#
package GenPDFAddOnBuild;

BEGIN {
    foreach my $pc (split(/:/, $ENV{FOSWIKI_LIBS})) {
        unshift @INC, $pc;
    }
}

use TWiki::Contrib::Build;

@GenPDFAddOnBuild::ISA = ( "TWiki::Contrib::Build" );

sub new {
    my $class = shift;
    return bless( $class->SUPER::new( "GenPDFAddOn" ), $class );
}

$build = new GenPDFAddOnBuild();
$build->build($build->{target});
