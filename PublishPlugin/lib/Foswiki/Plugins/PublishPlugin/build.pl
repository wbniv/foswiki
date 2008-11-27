#!/usr/bin/perl -w
package PublishPluginBuild;

BEGIN {
    foreach my $pc (split(/:/, $ENV{FOSWIKI_LIBS})) {
        unshift @INC, $pc;
    }
}

# Create the build object
$build = new Foswiki::Contrib::Build("PublishPlugin", "Publish");

# Build the target on the command line, or the default target
$build->build($build->{target});

