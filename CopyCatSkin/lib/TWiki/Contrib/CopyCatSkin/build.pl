#!/usr/bin/perl -w
BEGIN {
  foreach my $pc (split(/:/, $ENV{FOSWIKI_LIBS})) {
    unshift @INC, $pc;
  }
}
use TWiki::Contrib::Build;
$build = new TWiki::Contrib::Build("CopyCatSkin" );
$build->build($build->{target});
