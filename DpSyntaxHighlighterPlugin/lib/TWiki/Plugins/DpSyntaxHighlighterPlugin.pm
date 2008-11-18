# Plugin for Foswiki - The Free Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2007 Andrew Jones, andrewjones86@googlemail.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the TWiki root.

package TWiki::Plugins::DpSyntaxHighlighterPlugin;
use strict;

use vars qw( $VERSION $RELEASE $NO_PREFS_IN_TOPIC $SHORTDESCRIPTION $pluginName $rootDir $doneHead );

$VERSION = '$Rev: 9813$';
$RELEASE = '1.5.2';
$pluginName = 'DpSyntaxHighlighterPlugin';
$NO_PREFS_IN_TOPIC = 1;
$SHORTDESCRIPTION = 'Client side syntax highlighting using the [[http://code.google.com/p/syntaxhighlighter/][dp.SyntaxHighlighter]]';

sub initPlugin {

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    $rootDir = TWiki::Func::getPubUrlPath() . '/' . # /pub/
               TWiki::Func::getTwikiWebname() . '/' . # TWiki/
	       $pluginName . '/' . # DpSyntaxHighlighterPlugin
               'dp.SyntaxHighlighter';

    $doneHead = 0;

    # Plugin correctly initialized
    return 1;
}

sub commonTagsHandler {

    $_[0] =~ s/%CODE{(.*?)}%\s*(.*?)%ENDCODE%/&_handleTag/egs;

}

# handles the tag
sub _handleTag {

    my %params = TWiki::Func::extractParameters($1);
    my $el = $params{el} || 'pre';
    my $lang = lc$params{lang} || lc$params{_DEFAULT}; # language
    my $code = $2; # code to highlight

    # start
    my $out = "<$el name='code' class='$lang";
    
    # attributes
    $out .= ":nogutter" if lc$params{nogutter} eq 'on';
    $out .= ":nocontrols" if lc$params{nocontrols} eq 'on';
    $out .= ":collapse" if lc$params{collapse} eq 'on';
    $out .= ":firstline[$params{firstline}]" if $params{firstline};
    $out .= ":showcolumns" if lc$params{showcolumns} eq 'on';
    $out .= "'";

    if ($el eq 'textarea') {
        # used to give sensible size if javascript not available
        $out .= " cols='$params{cols}'" if $params{cols};
        $out .= " rows='$params{rows}'" if $params{rows};
    }

    $out .= ">";

    # code
    $out .= "$code";

    # end
    $out .= "</$el>";

    # brush
    my $brush = '';
    for ($lang){
	/as3|actionscript3/ and $brush = "AS3", last;
	/css/ and $brush = "Css", last;
	/c#|c-sharp|csharp/ and $brush = "CSharp", last;
	/^c$|cpp|c\+\+/ and $brush = "Cpp", last;
	/vb|vb\.net/ and $brush = "Vb", last;
	/delphi|pascal/ and $brush = "Delphi", last;
	/js|jscript|javascript/ and $brush = "JScript", last;
	/^java$/ and $brush = "Java", last;
	/php/ and $brush = "Php", last;
	/py|python/ and $brush = "Python", last;
	/ruby|ror|rails/ and $brush = "Ruby", last;
	/sql/ and $brush = "Sql", last;
	/xml|xhtml|xslt|html/ and $brush = "Xml", last;
    }
    $out .= "<script type=\"text/javascript\" src='$rootDir/Scripts/shBrush$brush.js'></script>";
		
    _doHead();
	
    return $out;
}

# adds styles and core js to head
sub _doHead {

    return if $doneHead;
    $doneHead = 1;

    # style sheet
    TWiki::Func::addToHEAD(
        $pluginName . '_STYLE',
        "<style type='text/css' media='all'>\@import url($rootDir/Styles/SyntaxHighlighter.css);</style>"
    );
            
    # core javascript file
    TWiki::Func::addToHEAD(
        $pluginName . '_CORE',
        "<script type=\"text/javascript\" src='$rootDir/Scripts/shCore.js'></script>"
    );

    my $script = <<"EOT";
<script type="text/javascript">
// use dp.SyntaxHighlighter namespace
dp.SyntaxHighlighter.twikirender = function(){
  dp.SyntaxHighlighter.ClipboardSwf = '$rootDir/Scripts/clipboard.swf';
  dp.SyntaxHighlighter.HighlightAll('code');
}
if (typeof YAHOO != "undefined") {
  // YUI
  YAHOO.util.Event.onDOMReady(dp.SyntaxHighlighter.twikirender);
} else if (typeof twiki != "undefined"){
  // TWiki 4.2
  twiki.Event.addLoadEvent(dp.SyntaxHighlighter.twikirender);
} else if (typeof addLoadEvent != "undefined") {
  // TWiki 4.1
  addLoadEvent(dp.SyntaxHighlighter.twikirender);
} else {
  alert("Can't add load event for DpSyntaxHighlighterPlugin. Please contact your System Administrator.");
}
</script>
EOT

    TWiki::Func::addToHEAD($pluginName . '_RENDER',$script);
}

1;
