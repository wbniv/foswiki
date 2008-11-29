#!/usr/bin/perl -w
#
# Build file for OrphansPlugin
#
package OrphansPluginBuild;

BEGIN {
  foreach my $pc (split(/:/, $ENV{FOSWIKI_LIBS})) {
    unshift @INC, $pc;
  }
}

use TWiki::Contrib::Build;

$build = new TWiki::Contrib::Build("OrphansPlugin");
$build->build($build->{target});
