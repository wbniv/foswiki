#!/usr/bin/perl -w
#
# Build file for Action Tracker Plugin
#
package WebPermissionsPluginBuild;

BEGIN {
  foreach my $pc (split(/:/, $ENV{TWIKI_LIBS})) {
    unshift @INC, $pc;
  }
}

use TWiki::Contrib::Build;

@WebPermissionsPluginBuild::ISA = ( "TWiki::Contrib::Build" );

sub new {
    my $class = shift;
    return bless( $class->SUPER::new( "WebPermissionsPlugin" ), $class );
}

$build = new WebPermissionsPluginBuild();
$build->build($build->{target});
