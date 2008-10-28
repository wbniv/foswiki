#!/usr/bin/perl -w
#
# Build class for FormQueryPlugin
# Requires the environment variable TWIKI_LIBS to be
# set to point at the DBCache repository

# Standard preamble
BEGIN {
  foreach my $pc (split(/:/, $ENV{TWIKI_LIBS})) {
    unshift @INC, $pc;
  }
}

use TWiki::Contrib::Build;

package FormQueryPluginBuild;

@FormQueryPluginBuild::ISA = ( "TWiki::Contrib::Build" );

sub new {
  my $class = shift;
  return bless( $class->SUPER::new( "FormQueryPlugin" ), $class );
}

$build = new FormQueryPluginBuild();

$build->build($build->{target});
