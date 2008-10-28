#!/usr/bin/perl -w
#
package FamilyTreePluginBuild;

BEGIN {
    foreach my $pc (split(/:/, $ENV{TWIKI_LIBS}||'')) {
        unshift @INC, $pc;
    }
}
use TWiki::Contrib::Build;

$build = new TWiki::Contrib::Build( "FamilyTreePlugin" );
$build->build($build->{target});
