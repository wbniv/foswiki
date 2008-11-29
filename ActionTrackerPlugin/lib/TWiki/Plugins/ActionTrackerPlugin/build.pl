#!/usr/bin/perl -w
#
# Build file for Action Tracker Plugin
#
BEGIN {
  foreach my $pc (split(/:/, $ENV{FOSWIKI_LIBS})) {
    unshift @INC, $pc;
  }
}

use TWiki::Contrib::Build;

$build = new TWiki::Contrib::Build("ActionTrackerPlugin");
$build->build($build->{target});
