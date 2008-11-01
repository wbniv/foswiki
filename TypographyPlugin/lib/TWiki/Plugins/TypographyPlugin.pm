#  *****************************************************************************
#
#   TypographyPlugin.pm
#   Improve typography of TWiki generated text.
#
#   Copyright (C) 2002, Eric Scouten
#   Started Sat, 07 Dec 2002
#
#  *****************************************************************************
#
#   This program is free software; you can redistribute it and/or
#   modify it under the terms of the GNU General Public License
#   as published by the Free Software Foundation; either version 2
#   of the License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details, published at 
#   http://www.gnu.org/copyleft/gpl.html
#
#  *****************************************************************************

package TWiki::Plugins::TypographyPlugin;

use vars qw($web $topic $user $installWeb $VERSION $RELEASE $debug $doOldInclude $renderingWeb);

# This should always be $Rev: 6827 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 6827 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';




# ******************************************************************************

sub initPlugin {

    ($topic, $web, $user, $installWeb) = @_;

    # Check for Plugins.pm versions.

    if ($TWiki::Plugins::VERSION < 1) {
        &TWiki::Func::writeWarning( "Version mismatch between TypographyPlugin and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag.

    $debug = &TWiki::Func::getPreferencesFlag("TYPOGRAPHYPLUGIN_DEBUG");

    # Plugin correctly initialized.

    &TWiki::Func::writeDebug("- TWiki::Plugins::TypographyPlugin::initPlugin( $web.$topic ) is OK") if $debug;
    return 1;

}


# ******************************************************************************

sub startRenderingHandler {

### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    &TWiki::Func::writeDebug("- TypographyPlugin::startRenderingHandler( $_[1].$topic )") if $debug;

	# See if we have Internet Explorer. Other browsers (esp. older Netscapes) aren't
	# very savvy about typography.

	my $userAgent = $ENV{'HTTP_USER_AGENT'} || "";
	my $isInternetExplorer = $userAgent =~ m/msie ([\d]+)/i;
	my $ieMajorVersion = int $1 if ($isInternetExplorer);

	my $isModernNetscape = $userAgent =~ m/Netscape\d?\/([\d]+)/i;
	my $nsMajorVersion = int $1 if ($isModernNetscape);

	# Render little grey arrows.

	if ($isInternetExplorer || ($isModernNetscape && $userAgent =~ m/win/i)) {
		$_[0] =~ s((<<)|(&lt;&lt;))(<font face="Webdings">&nbsp;</font>)go;
		$_[0] =~ s((>>)|(&gt;&gt;))( <font face="Webdings">4</font>)go;
	} else {
		$_[0] =~ s(\s(<<)|(&lt;&lt;)\s)()go;
		$_[0] =~ s(\s(>>)|(&gt;&gt;)\s)( <b>&gt;</b>)go;
	}

	# Render special character sequences.

	if ($_[0] !~ /chgUpper/) {   # Ugly hack to prevent TWikiRegistration page from breaking.

		if (($isInternetExplorer && $ieMajorVersion >= 5) || ($isModernNetscape && $nsMajorVersion >= 6)) {
			$_[0] =~ s((?<=[^\w\-])\-\-\-(?=[^\w\-\+]))(&mdash;)go;
			$_[0] =~ s((?<=[^\w\-])\-\-(?=[^\w\-\+]))( &ndash; )go;
			$_[0] =~ s((?<=\s)(&quot;|\")(?![^<]+>)(?![^<{]*}))(&ldquo;)go;
			$_[0] =~ s((&quot;|\")(?![^<]*>)(?![^<{]*}))(&rdquo; )go;
			$_[0] =~ s((?<=\s)(&apos;|\')(?![^<]+>)(?![^<{]*}))(&lsquo;)go;
			$_[0] =~ s((&apos;|\')(?![^<]+>)(?![^<{]*}))(&rsquo;)go;
		} else {
			$_[0] =~ s((?<=[^\w\-!])\-\-\-(?=[^\w\-\+]))(\-\-)go;
			$_[0] =~ s(&(m|n)dash;)(\-\-)go;
			$_[0] =~ s(&(l|r)dquo;)(&quot;)go;
			$_[0] =~ s(&(l|r)squo;)(&apos;)go;
		}

	}

}


# ******************************************************************************

sub endRenderingHandler {

### my ($text) = @_;   # do not uncomment, use $_[0] instead

    &TWiki::Func::writeDebug("- TypographyPlugin::endRenderingHandler( $_[0] )") if $debug;

	# Patch out <expand> tags.

	$_[0] =~ s(\<expand\>(.*?)\</expand\>)(&renderExpandSection($1))geo;

}


# ******************************************************************************

sub renderExpandSection {

	my ($renderSection) = @_;

    &TWiki::Func::writeDebug("- TypographyPlugin::renderExpandSection( $renderSection )") if $debug;

	$renderSection =~ s(\b([A-Z]+[a-z]+[A-Z0-9]+[a-zA-Z0-9]*)\b(?![^<]+>)(?![^<{]*}))(&expandWikiWord($1))geo;

	return $renderSection;

}


# ******************************************************************************

sub expandWikiWord {

	my ($wikiWord) = @_;

    &TWiki::Func::writeDebug("- TypographyPlugin::expandWikiWord( $wikiWord )") if $debug;

	# Insert spaces between each part of WikiWord.

	$wikiWord =~ s(([a-z])([A-Z0-9]))($1 $2)go;
	$wikiWord =~ s(([0-9])([A-Z]))($1 $2)go;
	$wikiWord =~ s(([A-Z]{2})([A-Z][a-z]{2}))($1 $2)go;

	# Convert a few known words to lower case (proper English titling).

	$wikiWord =~ s(\bA(?=[A-Z]))(A )go;
	$wikiWord =~ s((.+)\bA\b)($1a)go;
	$wikiWord =~ s((.+)\bAnd\b)($1and)go;
	$wikiWord =~ s((.+)\bFrom\b)($1from)go;
	$wikiWord =~ s((.+)\bIn\b)($1in)go;
	$wikiWord =~ s((.+)\bOf\b)($1of)go;
	$wikiWord =~ s((.+)\bTo\b)($1to)go;
	$wikiWord =~ s((.+)\bThe\b)($1the)go;
	$wikiWord =~ s((.+)\bWith\b)($1with)go;

	# Expand a few known words with appropriate punctuation.

	my $userAgent = $ENV{'HTTP_USER_AGENT'} || "";
	my $isInternetExplorer = $userAgent =~ m/msie/i;

	if ($isInternetExplorer) {
        $wikiWord =~ s(\bCouldnt\b)(Couldn&rsquo;t)go;       
		$wikiWord =~ s(\bYouve\b)(You&rsquo;ve)go;
		$wikiWord =~ s(\bPMLs\b)(PML&rsquo;s)go;
	} else {
		$wikiWord =~ s(\bCouldnt\b)(Couldn\'t)go;
		$wikiWord =~ s(\bYouve\b)(You\'ve)go;
		$wikiWord =~ s(\bPMLs\b)(PML\'s)go;
	}

    &TWiki::Func::writeDebug("-      expanded to $wikiWord") if $debug;

	return $wikiWord;

}


# ******************************************************************************

1;
