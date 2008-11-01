#!/usr/bin/perl -w
#
# Build for MathModePlugin
#
BEGIN {
    unshift @INC, split(/:/, $ENV{TWIKI_LIBS});
}

use TWiki::Contrib::Build;

# Create the build object
$build = new TWiki::Contrib::Build( 'MathModePlugin' );

# Build the target on the command line, or the default target
$build->build($build->{target});

