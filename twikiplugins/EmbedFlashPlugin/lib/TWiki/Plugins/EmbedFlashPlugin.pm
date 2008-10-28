# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2003 Peter Thoeny, peter@thoeny.com
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
# This is an empty TWiki plugin. Use it as a template
# for your own plugins; see TWiki.TWikiPlugins for details.
#
# Each plugin is a package that may contain these functions:        VERSION:
#
#   initPlugin              ( $topic, $web, $user, $installWeb )    1.000
#   initializeUserHandler   ( $loginName, $url, $pathInfo )         1.010
#   registrationHandler     ( $web, $wikiName, $loginName )         1.010
#   commonTagsHandler       ( $text, $topic, $web )                 1.000
#   startRenderingHandler   ( $text, $web )                         1.000
#   outsidePREHandler       ( $text )                               1.000
#   insidePREHandler        ( $text )                               1.000
#   endRenderingHandler     ( $text )                               1.000
#   beforeEditHandler       ( $text, $topic, $web )                 1.010
#   afterEditHandler        ( $text, $topic, $web )                 1.010
#   beforeSaveHandler       ( $text, $topic, $web )                 1.010
#   writeHeaderHandler      ( $query )                              1.010  Use only in one Plugin
#   redirectCgiQueryHandler ( $query, $url )                        1.010  Use only in one Plugin
#   getSessionValueHandler  ( $key )                                1.010  Use only in one Plugin
#   setSessionValueHandler  ( $key, $value )                        1.010  Use only in one Plugin
#
# initPlugin is required, all other are optional. 
# For increased performance, all handlers except initPlugin are
# disabled. To enable a handler remove the leading DISABLE_ from
# the function name. Remove disabled handlers you do not need.
#
# NOTE: To interact with TWiki use the official TWiki functions 
# in the TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!


# =========================
package TWiki::Plugins::EmbedFlashPlugin;    # change the package name and $pluginName!!!

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $pluginName
        $debug $exampleCfgVar
    );

# This should always be $Rev: 6827 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 6827 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'EmbedFlashPlugin';  # Name of this Plugin

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag( "\U$pluginName\E_DEBUG" );

    # Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
    $exampleCfgVar = &TWiki::Func::getPreferencesValue( "EMPTYPLUGIN_EXAMPLE" ) || "default";

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    # do custom extension rule, like for example:
    # $_[0] =~ s/%XYZ%/&handleXyz()/ge;
    # $_[0] =~ s/%XYZ{(.*?)}%/&handleXyz($1)/ge;

    $_[0] =~ s/%EMBEDFLASH{(.*?)}%/&handleEmbedFlash($1)/ge;
}

# =========================
sub handleEmbedFlash
{
    my ( $theAttributes ) = @_;
    my $FlashFileName = "";
    my $FlashID;
    my $FlashWidth = "100%";
    my $FlashHeight = "100%";
    my $FlashOBJECTBackground = "";
    my $FlashEMBEDBackground = "";
    my $FlashVersion = "6";
    my $FlashQuality = "high";
    my $FlashCodebase;
    my $FlashAllowContextMenu = "false";
    my $FlashAlign = "";
    my $FlashOBJECTScale = "";
    my $FlashEMBEDScale = "";
        
    my $fileName = &TWiki::Func::extractNameValuePair($theAttributes, "filename");
	if ($fileName) { $FlashFileName = $fileName; }
	my $movieId = &TWiki::Func::extractNameValuePair($theAttributes, "id");
	if (!$movieId) {
		my @arr = split(/.swf/, $fileName); # string before .swf
		my @arr2 = split(/\//, pop @arr); # remove .swf
		$FlashID = pop @arr2; # remove string before filename
	} else {
		$FlashID = $movieId;
	}
    my $width = &TWiki::Func::extractNameValuePair($theAttributes, "width");
    if ($width) { $FlashWidth = $width; }
    my $height = &TWiki::Func::extractNameValuePair($theAttributes, "height");
    if ($height) { $FlashHeight = $height; }
    my $background = &TWiki::Func::extractNameValuePair($theAttributes, "background");
    if ($background) {
    	$FlashOBJECTBackground = "<param name=bgcolor value=$background>";
    	$FlashEMBEDBackground = "bgcolor=$background";
    }
	my $version = &TWiki::Func::extractNameValuePair($theAttributes, "version");
    if ($version) { $FlashVersion = $version; }
    my $quality = &TWiki::Func::extractNameValuePair($theAttributes, "quality");
    if ($quality) { $FlashQuality = $quality; }
    my $menu = &TWiki::Func::extractNameValuePair($theAttributes, "menu");
    if ($menu) { $FlashAllowContextMenu = $menu; }
    my $align = &TWiki::Func::extractNameValuePair($theAttributes, "align");
    if ($align) { $FlashAlign = $align; }
    my $scale = &TWiki::Func::extractNameValuePair($theAttributes, "scale");
    if ($scale) {
    	$FlashOBJECTScale = "<param name=scale value=$scale>";
    	$FlashEMBEDScale = "scale=$scale";
    }
    if ($FlashVersion == "5") {
    	$FlashCodebase = "http://download.macromedia.com/pub/shockwave/cabs/flash/swflash.cab#version=6,0,0,0";
	}
    if ($FlashVersion == "6") {
    	$FlashCodebase = "http://download.macromedia.com/pub/shockwave/cabs/flash/swflash.cab#version=6,0,0,0";
	}
    if ($FlashVersion == "7") {
    	$FlashCodebase = "http://fpdownload.macromedia.com/pub/shockwave/cabs/flash/swflash.cab#version=7,0,0,0";
	}
   	return "<object classid=\"clsid:D27CDB6E-AE6D-11cf-96B8-444553540000\" codebase=\"$FlashCodebase\" width=\"$FlashWidth\" height=\"$FlashHeight\" id=\"$FlashID\" align=$FlashAlign> <param name=movie value=\"$FlashFileName\"> <param name=quality value=$FlashQuality> $FlashOBJECTScale $FlashOBJECTBackground <param name=menu value=$FlashAllowContextMenu> <embed src=\"$FlashFileName\" menu=$FlashAllowContextMenu quality=$FlashQuality $FlashEMBEDScale $FlashEMBEDBackground width=\"$FlashWidth\" height=\"$FlashHeight\" name=\"$FlashID\" align=$FlashAlign type=\"application/x-shockwave-flash\" pluginspage=\"http://www.macromedia.com/go/getflashplayer\"> </embed> </object>"
}

1;
