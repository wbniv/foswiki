#!/usr/bin/perl -w
#
package FamilyTreePluginBuild;

BEGIN {
    foreach my $pc (split(/:/, $ENV{FOSWIKI_LIBS}||'')) {
        unshift @INC, $pc;
    }
}
use TWiki::Contrib::Build;

$build = new TWiki::Contrib::Build( "FamilyTreePlugin" );
$build->build($build->{target});
