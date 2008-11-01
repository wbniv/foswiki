#!/usr/bin/perl -w
#
# Build for NavPlugin
#
BEGIN {
  foreach my $pc (split(/:/, $ENV{TWIKI_LIBS})) {
    unshift @INC, $pc;
  }
}

use TWiki::Contrib::Build;

# Create the build object
$build = new TWiki::Contrib::Build( 'NavPlugin' );

# Build the target on the command line, or the default target
$build->build($build->{target});

