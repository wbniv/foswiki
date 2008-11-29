#!/usr/bin/perl -w
#
# Example build class. Copy this file to the equivalent place in your
# plugin or contrib and edit.
#
# Read the comments at the top of lib/Foswiki/Contrib/Build.pm for
# details of how the build process works, and what files you
# have to provide and where.
#
# Requires the environment variable FOSWIKI_LIBS (a colon-separated path
# list) to be set to point at the build system and any required dependencies.
# Usage: ./build.pl [-n] [-v] [target]
# where [target] is the optional build target (build, test,
# install, release, uninstall), test is the default.
# Two command-line options are supported:
# -n Don't actually do anything, just print commands
# -v Be verbose
#

# Standard preamble
BEGIN {
  foreach my $pc (split(/:/, $ENV{FOSWIKI_LIBS})) {
    unshift @INC, $pc;
  }
}

use Foswiki::Contrib::Build;

# Declare our build package
{ package SpacedWikiWordPluginBuild;

  @SpacedWikiWordPluginBuild::ISA = ( "Foswiki::Contrib::Build" );

  sub new {
    my $class = shift;
    return bless( $class->SUPER::new( "SpacedWikiWordPlugin"), $class );
  }

  # Example: Override the build target
  sub target_build {
    my $this = shift;

    $this->SUPER::target_build();

    # Do other build stuff here
  }
}

# Create the build object
$build = new SpacedWikiWordPluginBuild();

# Build the target on the command line, or the default target
$build->build($build->{target});

