# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2000-2006 Peter Thoeny, peter@thoeny.org
#
# For licensing info read LICENSE file in the TWiki root.
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
# As per the GPL, removal of this notice is prohibited.
#
# =========================
#
# Use EmptyPlugin.pm as a template
# for your own plugins; see %SYSTEMWEB%.Plugins for details.
#
# This plugin implements compatability functions that support
# data defined using earlier versions of TWiki. The chances are
# good that you don't need it, and can simply disable it (add
# it to the DISABLEDPLUGINS list)

# =========================
package TWiki::Plugins::DefaultPlugin;

use TWiki::Func;

use strict;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $pluginName
        $debug $doOldInclude
    );

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'DefaultPlugin';  # Name of this Plugin

sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Get plugin preferences
    $doOldInclude = TWiki::Func::getPluginPreferencesFlag( 'OLDINCLUDE' ) || '';

    # Get plugin debug flag
    $debug = TWiki::Func::getPluginPreferencesFlag( 'DEBUG' );

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # for compatibility for earlier TWiki versions:

    ######################
    # Old INCLUDE syntax
    if( $doOldInclude ) {
        # allow two level includes
        $_[0] =~ s/%INCLUDE:"([^%\"]*?)"%/$TWiki::Plugins::SESSION->_INCLUDE( new TWiki::Attrs( $1 ), $_[1], $_[2], '' )/geo;
        $_[0] =~ s/%INCLUDE:"([^%\"]*?)"%/$TWiki::Plugins::SESSION->_INCLUDE( new TWiki::Attrs( $1 ), $_[1], $_[2], '' )/geo;
    }

    ######################
    # Full attachment filename
    # Process the filename suffixed to %ATTACHURLPATH%
    # Required for migration purposes
    my $pubUrlPath = TWiki::Func::getPubUrlPath();
    my $attfexpr = TWiki::urlEncode( "$pubUrlPath/$_[2]/$_[1]" );
    my $fnRE =  TWiki::Func::getRegularExpression( 'filenameRegex' );
    $_[0] =~ s!$attfexpr/($fnRE)!"$attfexpr/".TWiki::urlEncode($1)!ge;
}

# Remove DISABLE_ if you uncomment any of the functionality in here
sub DISABLE_outsidePREHandler {
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    TWiki::Func::writeDebug( "- ${pluginName}::outsidePREHandler( $topic )" ) if $debug;

    # This handler is called by getRenderedVersion, once per line, before any changes,
    # for lines outside <pre> and <verbatim> tags. 
    # Use it to define customized rendering rules

    # do custom extension rule, like for example:
    # $_[0] =~ s/old/new/go;

    # render deprecated *_text_* as "bold italic" text:
    #$_[0] =~ s/(^|\s)\*_([^\s].*?[^\s])_\*(\s|$)/$1<strong><em>$2<\/em><\/strong>$3/go;

    # Use alternate %Web:WikiName% syntax (versus the standard Web.WikiName).
    # This is an old JosWiki render option. (Uncomment for JosWiki compatibility)
    #$_[0] =~ s/(^|\s|\()\%([^\s].*?[^\s]):([^\s].*?[^\s])\%/$1.$TWiki::Plugins::SESSION->_handleWikiWord($web,$2,$3)/geo;

    # Use 'forced' non-WikiName links (i.e. %Linkname%)
    # This is an old JosWiki render option. (Uncomment for JosWiki compatibility)
    #$_[0] =~ s/(^|\s|\()\%([^\s].*?[^\s])\%/$1.$TWiki::Plugins::SESSION->_handleWikiWord($web,$web,$2)/geo;

    # Use 'forced' non-WikiName links (i.e. %Web.Linkname%)
    # This is an old JosWiki render option combined with the new Web.LinkName notation
    # (Uncomment for JosWiki compatibility)
    #$_[0] =~ s/(^|\s|\()\%([a-zA-Z0-9]+)\.(.*?[^\s])\%(\s|\)|$)/$1.$TWiki::Plugins::SESSION->_handleWikiWord($web,$2,$3)/geo;

    # Use <link>....</link> links
    # This is an old JosWiki render option. (Uncomment for JosWiki compatibility)
    #$_[0] =~ s/<link>(.*?)<\/link>/$1.$TWiki::Plugins::SESSION->_handleWikiWord($web,$web,$1)/geo;
}

1;
