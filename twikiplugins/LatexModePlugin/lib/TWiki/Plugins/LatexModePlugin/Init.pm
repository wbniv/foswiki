# LatexModePlugin::Init.pm
# Copyright (C) 2005-2006 W Scott Hoge, shoge at bwh dot harvard dot edu
# Copyright (C) 2002 Graeme Lufkin, gwl@u.washington.edu
#
# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at 
# http://www.gnu.org/copyleft/gpl.html
#
# =========================

package TWiki::Plugins::LatexModePlugin::Init;

use strict;

my $debug = TWiki::Plugins::LatexModePlugin::debug;

sub doInit{

    my %LMPcontext = ();

    # Get preferences values
    $LMPcontext{'default_density'} = 
        &TWiki::Func::getPreferencesValue( "DENSITY" ) ||
        &TWiki::Func::getPreferencesValue( "LATEXMODEPLUGIN_DENSITY" ) || 
        116;
    $LMPcontext{'default_gamma'} = 
        &TWiki::Func::getPreferencesValue( "GAMMA" ) ||
        &TWiki::Func::getPreferencesValue( "LATEXMODEPLUGIN_GAMMA" ) ||
        0.6;
    $LMPcontext{'default_scale'} = 
        &TWiki::Func::getPreferencesValue( "SCALE" ) ||
        &TWiki::Func::getPreferencesValue( "LATEXMODEPLUGIN_SCALE" ) ||
        1.0;

    $LMPcontext{'preamble'} = 
        &TWiki::Func::getPreferencesValue( "PREAMBLE" ) ||
        &TWiki::Func::getPreferencesValue( "LATEXMODEPLUGIN_PREAMBLE" ) ||
        '\usepackage{latexsym}'."\n";

    # initialize counters
    # Note, these can be over-written by topic declarations
    $LMPcontext{'eqn'} = &TWiki::Func::getPreferencesValue( "EQN" ) || 0;
    $LMPcontext{'fig'} = &TWiki::Func::getPreferencesValue( "FIG" ) || 0;
    $LMPcontext{'tbl'} = &TWiki::Func::getPreferencesValue( "TBL" ) || 0;
    
    $LMPcontext{'maxdepth'} = 
        &TWiki::Func::getPreferencesValue( "LATEXMODEPLUGIN_MAXSECDEPTH" ) ||
        0;

    # initialize section counters
    $LMPcontext{'curdepth'} = 0;
    for my $c (1 .. $LMPcontext{'maxdepth'}) {
        $LMPcontext{'sec'.$c.'cnt'} = 0;
        # &TWiki::Func::getPreferencesValue( "SEC".$c ) || 0;
    }

    $LMPcontext{'eqnrefs'} = (); # equation back-references 
    $LMPcontext{'figrefs'} = (); # figure back-references 
    $LMPcontext{'tblrefs'} = (); # table back-references 
    $LMPcontext{'secrefs'} = (); # table back-references 

    my %e = ();
    $LMPcontext{'hashed_math_strings'} = \%e;
    # $LMPcontext{'markup_opts'} = \%e;
    $LMPcontext{'error_catch_all'} = '';

    # $LMPcontext{'topic'} = $topic;
    # $LMPcontext{'web'} = $web;

    $LMPcontext{'use_color'} = 0; # initialize color setting.

    # $latexout = 1 if ($script =~ m/genpdflatex/);

    my $query = &TWiki::Func::getCgiQuery();
    $LMPcontext{'rerender'} = &TWiki::Func::getPreferencesValue( "RERENDER" ) || 0;
    if (($query) and $query->param( 'latex' )) {
        $LMPcontext{'rerender'} = ($query->param( 'latex' ) eq 'rerender');
    }

    $LMPcontext{'alltexmode'} = &TWiki::Func::getPreferencesValue( "LATEXMODEPLUGIN_ALLTEXMODE" ) || 0;
    if (($query) and $query->param( 'latex' )) {
        $LMPcontext{'alltexmode'} = ($query->param( 'latex' ) eq 'tml');
    }

    TWiki::Func::getContext()->{'LMPcontext'} = \%LMPcontext;

    # Plugin correctly initialized
    &TWiki::Func::writeDebug( "- TWiki::Plugins::LatexModePlugin::doInit() is OK" ) if $debug; 

    return 1;
}

1;
