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
# This is the Syntax Highlighting TWiki plugin.
# written by
# Nicolas Tisserand (tisser_n@epita.fr), Nicolas Burrus (burrus_n@epita.fr)
# and Perceval Anichini (anichi_p@epita.fr)
# 
# It uses enscript as syntax highlighter.
# 
# Use it in your twiki text by writing %begin language% ... %end%
# with language = ada asm awk bash c changelog c++ csh delphi diff diffs diffu elisp fortran fortran_pp haskell html idl inf java javascript
# ksh m4 mail makefile maple matlab modula_2 nested nroff objc outline pascal perl postscript python rfc scheme sh skill sql states synopsys
# tcl tcsh tex vba verilog vhdl vrml wmlscript zsh 

package TWiki::Plugins::SyntaxHighlightingPlugin;

use IPC::Open2;

use vars qw(
	    $web $topic $user $installWeb $VERSION $RELEASE $debug
	    );

# This should always be $Rev: 6827 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 6827 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';


sub pipeThru
{
    my $out;

    $pid = open2( \*Reader, \*Writer, $_[0]);

    print Writer $_[1];
    close(Writer);

    while (<Reader>)
    {
	$out .= $_;
    }
    close (Reader);

    return $out;
}

sub highlight
{
    my %langs = (
		 "ada" => "ada",
		 "asm" => "asm",
		 "awk" => "awk",
		 "bash" => "bash",
		 "c" => "c",
		 "changelog" => "changelog",
		 "cpp" => "cpp",
		 "c++" => "cpp",
		 "csh" => "csh",
		 "delphi" => "delphi",
		 "diff" => "diff",
		 "diffs" => "diffs",
		 "diffu" => "diffu",
		 "elisp" => "elisp",
		 "fortran" => "fortran",
		 "fortran_pp" => "fortran_pp",
		 "haskell" => "haskell",
		 "html" => "html",
		 "idl" => "idl",
		 "inf" => "inf",
		 "java" => "java",
		 "javascript" => "javascript",
		 "ksh" => "ksh",
		 "m4" => "m4",
		 "mail" => "mail",
		 "makefile" => "makefile",
		 "maple" => "maple",
		 "matlab" => "matlab",
		 "modula_2" => "modula_2",
		 "nested" => "nested",
		 "nroff" => "nroff",
		 "objc" => "objc",
		 "outline" => "outline",
		 "pascal" => "pascal",
		 "perl" => "perl",
		 "postscript" => "postscript",
		 "python" => "python",
		 "rfc" => "rfc",
		 "scheme" => "scheme",
		 "sh" => "sh",
		 "skill" => "skill",
		 "sql" => "sql",
		 "states" => "states",
		 "synopsys" => "synopsys",
		 "tcl" => "tcl",
		 "tcsh" => "tcsh",
		 "tex" => "tex",
		 "tiger" => "tiger",
		 "vba" => "vba",
		 "verilog" => "verilog",
		 "vhdl" => "vhdl",
		 "vrml" => "vrml",
		 "wmlscript" => "wmlscript",
		 "zsh" => "zsh"
		 );
    
    return "<font color=\"red\"> Syntax Highlighting: error: $_[0]: undefined language </font>" unless exists $langs{lc($_[0])};
    
    my ($lang, $text, $nb_option, $nb_start) = @_;
    
    my $highlighted = pipeThru("enscript --color --language=html --highlight=$langs{lc($lang)} -o - -q", $text);
    
    if ($highlighted =~ s/.*\<PRE\>\n(.*?)\n?\<\/PRE\>.*/$1/os)
    {
	if ($nb_option eq " numbered")
	{
	    my $line = ($nb_start eq "") ? 1 : $nb_start;
	    $highlighted =~ s/(^.*)/sprintf("<b><font color=\"#000000\">%5d<\/font><\/b>\t%s", $line++, $1)/mgeo
	}
	return "<table width=\"100%\" border=\"0\" cellpadding=\"5\" cellspacing=\"0\"><tr><td bgcolor=\"#FFFFFF\"><pre>".$highlighted."</pre><\/td><\/tr><\/table>";
    }	
    else
    {
	return "<font color=\"red\"> Syntax Highlighting: internal error  </font>";
    }
}

# =========================

sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;
    
    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning( "Version mismatch between SyntaxHighlightingPlugin and Plugins.pm" );
        return 0;
    }
    
    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag( "SYNTAXHIGHLIGHTINGPLUGIN_DEBUG" );
    
    # Plugin correctly initialized
    &TWiki::Func::writeDebug( "- TWiki::Plugins::SyntaxHighlightingPlugin::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================

sub startRenderingHandler
{
    &TWiki::Func::writeDebug( "- SyntaxHighlightingPlugin::startRenderingHandler( $_[1] )" ) if $debug;

    # matches %begin [numbered][:n] language% ... %end%
    $_[0] =~ s/^%begin( numbered)?(?:\:(\d+))? ([^%]*?)%\n(.*?)^%end%$/highlight($3, $4, $1, $2)/megos;
}

# =========================

1;
