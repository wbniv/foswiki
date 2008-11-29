#!/usr/bin/perl -w
#
# Read the comments at the top of lib/TWiki/Plugins/Build.pm for
# details of how the build process works, and what files you
# have to provide and where.
#
BEGIN {
    foreach my $pc (split(/:/, $ENV{FOSWIKI_LIBS})) {
        unshift @INC, $pc;
    }
}

use TWiki::Contrib::Build;

# Create the build object
$build = new TWiki::Contrib::Build( "RandomTopicPlugin" );

# Build the target on the command line, or the default target
$build->build($build->{target});

