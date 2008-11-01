# LatexModePlugin.pm
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
#
# This is the Math Mode TWiki plugin.  See TWiki.LatexModePlugin for details.
#
# Each plugin is a package that contains the subs:
#
#   initPlugin           ( $topic, $web, $user, $installWeb )
#   commonTagsHandler    ( $text, $topic, $web )
#   outsidePREHandler    ( $text )
#   insidePREHandler     ( $text )
#   postRenderingHandler  ( $text )
#
# initPlugin is required, all other are optional. 
# For increased performance, all handlers except initPlugin are
# disabled. To enable a handler remove the leading DISABLE_ from
# the function name.
# 
# NOTE: To interact with TWiki use the official TWiki functions
# in the &TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!

# LatexModePlugin: This plugin allows you to include mathematics and
# other Latex markup commands in TWiki pages.  To declare a portion of
# the text as latex, enclose it within any of the available markup tags:
#    %$ ... $%    for in-line equations
#    %\[ ... \]%  or
#    %MATHMODE{ ... }% for own-line equations
#
# For multi-line, or more complex markup, the syntax
# %BEGINLATEX{}% ... %ENDLATEX% is also available.
#
# An image is generated for each latex expression on a page by
# generating an intermediate PostScript file, and then using the
# 'convert' command from ImageMagick.  The rendering is done the first
# time an expression is used.  Subsequent views of the page will not
# require a re-render.  Images from old expressions no longer included
# in the page will be deleted.

# =========================
package TWiki::Plugins::LatexModePlugin;

use strict;

# =========================
use vars qw( $VERSION $RELEASE $debug
             $sandbox $initialized
             );
#             @EXPORT_OK
#             $user $installWeb 
#             $default_density $default_gamma $default_scale $preamble
#             $eqn $fig $tbl $use_color @norender $tweakinline $rerender


use vars qw( %TWikiCompatibility );

# number the release version of this plugin
$VERSION = '$Rev$';
$RELEASE = '3.71';

# =========================
sub initPlugin
{
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.025 ) { 
        # this version is Dakar and Cairo compatible
        &TWiki::Func::writeWarning( "Version mismatch between LatexModePlugin (Dakar edition) and Plugins.pm" );
        return 0;
    }

    #get the relative URL to the attachment directory for this page
    # $pubUrlPath = # &TWiki::Func::getUrlHost() . 
    #     &TWiki::Func::getPubUrlPath() . "/$web/$topic";
    
    # Get preferences values
    $debug = &TWiki::Func::getPreferencesFlag( "LATEXMODEPLUGIN_DEBUG" );

    $initialized = 0;

    if( $TWiki::Plugins::VERSION >= 1.1 ) {
        # Dakar provides a sandbox
        $sandbox = $TWiki::sharedSandbox || 
            $TWiki::sandbox;    # for TWiki 4.2
    } else {
        # in Cairo, must use the contrib package
        eval("use TWiki::Contrib::DakarContrib;");
        $sandbox = new TWiki::Sandbox();
    }

    return 1;
}


sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    ######################################################

    if ( !($initialized) ) {
        if ( ($_[0]=~m/%(REFLATEX|MATHMODE){.*?}%/) ||
             ($_[0]=~m/%BEGINALLTEX.*?%/)  ||
             ($_[0]=~m/%SECLABEL.*?%/)  ||
             ($_[0]=~m/%BEGINLATEX.*?%/)  ||
             ($_[0]=~m/%BEGIN(FIGURE|TABLE){.*?}%/) ||
             ($_[0] =~ m/%(\$.*?\$)%/) ||
             ($_[0] =~ m/%(\\\[.*?\\\])%/) 
             ) 
        {   use TWiki::Plugins::LatexModePlugin::Init;
            use TWiki::Plugins::LatexModePlugin::Render;
            use TWiki::Plugins::LatexModePlugin::CrossRef;
            eval(" use TWiki::Plugins::LatexModePlugin::Parse;");
            $initialized = &TWiki::Plugins::LatexModePlugin::Init::doInit(); 
        }
        else 
        { return; }
    }

    TWiki::Func::getContext()->{'LMPcontext'}->{'topic'} = $_[1];
    TWiki::Func::getContext()->{'LMPcontext'}->{'web'} = $_[2];

    TWiki::Func::writeDebug( " TWiki::Plugins::LatexModePlugin::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    $_[0] =~ s!%BEGINALLTEX({.*?})?%(.*?)%ENDALLTEX%!&handleAlltex($2,$1)!gseo;
    return if ( TWiki::Func::getContext()->{'LMPcontext'}->{'alltexmode'} );

    ### pass through text to assign labels to section numbers
    ###
    $_[0] =~ s!---(\++)(\!*)\s*(%SECLABEL{.*?}%)?\s(.*?)\n!&handleSections($1,$2,$3,$4) !gseo;

    # handle floats first, in case of latex markup in captions.
    $_[0] =~ s!%BEGINFIGURE{(.*?)}%(.*?)%ENDFIGURE%!&handleFloat($2,$1,'fig')!giseo;
    $_[0] =~ s!%BEGINTABLE{(.*?)}%(.*?)%ENDTABLE%!&handleFloat($2,$1,'tbl')!giseo;

    ### handle the standard syntax next
    $_[0] =~ s/%(\$.*?\$)%/&handleLatex($1,'inline="1"')/gseo;
    $_[0] =~ s/%(\\\[.*?\\\])%/&handleLatex($1,'inline="0"')/gseo;
    $_[0] =~ s/%MATHMODE{(.*?)}%/&handleLatex("\\[".$1."\\]",'inline="0"')/gseo;
    
    # pass everything between the latex BEGIN and END tags to the handler
    # 
    $_[0] =~ s!%BEGINLATEX{(.*?)}%(.*?)%ENDLATEX%!&handleLatex($2,$1)!giseo;
    $_[0] =~ s!%BEGINLATEX%(.*?)%ENDLATEX%!&handleLatex($1,'inline="0"')!giseo;
    $_[0] =~ s!%BEGINLATEXPREAMBLE%(.*?)%ENDLATEXPREAMBLE%!&handlePreamble($1)!giseo;

    # last, but not least, replace the references to equations with hyperlinks
    $_[0] =~ s!%REFLATEX{(.*?)}%!&handleReferences($1)!giseo;
}

# =========================
sub handleAlltex
{
    return unless ($initialized);

    &TWiki::Plugins::LatexModePlugin::Parse::handleAlltex(@_);
}

# =========================
sub handleFloat
{
    return unless ($initialized);

    &TWiki::Plugins::LatexModePlugin::CrossRef::handleFloat(@_);
}

# =========================
sub handleSections
{
    return unless ($initialized);

    &TWiki::Plugins::LatexModePlugin::CrossRef::handleSections(@_);
}

# =========================
sub handleReferences
{
    return unless ($initialized);

    &TWiki::Plugins::LatexModePlugin::CrossRef::handleReferences(@_);
}

# =========================
sub handleLatex
{
    return unless ($initialized);

    &TWiki::Plugins::LatexModePlugin::Render::handleLatex(@_);
}

# =========================
sub handlePreamble
{
    my $text = $_[0];	

    TWiki::Func::getContext()->{'LMPcontext'}->{'preamble'} .= $text;

    return('');
}



## disable the call to endRenderingHandler in Dakar (i.e. TWiki::Plugins::VERSION >= 1.1)
$TWikiCompatibility{endRenderingHandler} = 1.1;
# =========================
sub endRenderingHandler
{
    # for backwards compatibility with Cairo
    postRenderingHandler($_[0]);

}
	
# =========================
sub afterCommonTagsHandler # postRenderingHandler
{
# Here we check if we saw any math, try to delete old files, render new math, and clean up
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    return unless ($initialized);

    &TWiki::Plugins::LatexModePlugin::Render::renderEquations(@_);
}


# =========================

1;


__DATA__
