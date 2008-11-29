#!/usr/bin/perl -w
BEGIN {
  foreach my $pc (split(/:/, $ENV{FOSWIKI_LIBS})) {
    unshift @INC, $pc;
  }
}

use TWiki::Contrib::Build;

# Create the build object
my $build = new TWiki::Contrib::Build( 'PingBackPlugin' );

# Build the target on the command line, or the default target
my $build->build($build->{target});

