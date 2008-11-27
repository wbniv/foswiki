#!/usr/bin/perl -w
#
# Example build class. Copy this file to the equivalent place in your
# plugin and edit.
#
# Requires the environment variable TWIKI_LIBS to be
# set to point at the AttrsContrib code repository
# Usage: ./build.pl [-n] [-v] [target]
# where [target] is the optional build target (build, test,
# install, release, uninstall), test is the default.
# Two command-line options are supported:
# -n Don't actually do anything, just print commands
# -v Be verbose
#
# Read the comments at the top of lib/TWiki/Plugins/Build.pm for
# details of how the build process works, and what files you
# have to provide and where.
#
BEGIN {
  foreach my $pc (split(/:/, $ENV{TWIKI_LIBS})) {
    unshift @INC, $pc;
  }
}

use TWiki::Contrib::Build;

# Declare our build package
{ package PublishContribBuild;

  @PublishContribBuild::ISA = ( "TWiki::Contrib::Build" );

  sub new {
    my $class = shift;
    return bless( $class->SUPER::new( "PublishContrib", "Publish" ), $class );
  }
}

# Create the build object
$build = new PublishContribBuild();

# Build the target on the command line, or the default target
$build->build($build->{target});

