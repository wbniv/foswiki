#!/usr/bin/perl -w
#
# Build for LinkOptionsPlugin
#
BEGIN {
  foreach my $pc (split(/:/, $ENV{FOSWIKI_LIBS})) {
    unshift @INC, $pc;
  }
}

use TWiki::Contrib::Build;

# Create the build object
$build = new TWiki::Contrib::Build( 'LinkOptionsPlugin' );

# Build the target on the command line, or the default target
$build->build($build->{target});

