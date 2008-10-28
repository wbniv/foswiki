#!/usr/bin/perl -w
#
# Build file for OrphansPlugin
#
package OrphansPluginBuild;

BEGIN {
  foreach my $pc (split(/:/, $ENV{TWIKI_LIBS})) {
    unshift @INC, $pc;
  }
}

use TWiki::Contrib::Build;

$build = new TWiki::Contrib::Build("OrphansPlugin");
$build->build($build->{target});
