# Plugin for Foswiki - The Free Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2001-2006 Peter Thoeny, peter@thoeny.org
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
# This TWiki plugin displays the current local time of many
# cities around the world in a TWiki topic.
# Based on 4.4BSD-style zoneinfo files or on
# http://TWiki.org/cgi-bin/xtra/x?tz= time and date gateway
#
# initPlugin is required, all other are optional.

# =========================
package TWiki::Plugins::LocalCityTimePlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb
        $tzDir $dateCmd $dateParam $gatewayUrl
        $VERSION $RELEASE $debug $useDateCmd
    );

# =========================
# Plugin configuration
$tzDir     = '/usr/share/zoneinfo';                     # root dir of zone info files
$dateCmd   = '/bin/date';                               # path to date command
$dateParam = "'+\%a, \%d \%b \%Y \%T \%z \%Z'";         # RFC-822 compliant date format
                                                        # Example: Fri, 14 Nov 2003 23:46:52 -0800 PST
$gatewayUrl   = "http://TWiki.org/cgi-bin/xtra/tzdate"; # URL of date and time gateway
$gatewayParam = "?tz=";                                 # parameter of date and time gateway

# do not change
# This should always be $Rev: 8154 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 8154 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';



# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning( "Version mismatch between LocalCityTimePlugin and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag( "LOCALCITYTIMEPLUGIN_DEBUG" );

    # Flag to use external date command
    $useDateCmd = &TWiki::Func::getPreferencesFlag( "LOCALCITYTIMEPLUGIN_USEDATECOMMAND" );

    # Plugin correctly initialized
    &TWiki::Func::writeDebug( "- TWiki::Plugins::LocalCityTimePlugin::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    &TWiki::Func::writeDebug( "- LocalCityTimePlugin::commonTagsHandler( $_[2].$_[1] )" ) if $debug;
    $_[0] =~ s/%LOCALCITYTIME{(.*?)}%/&handleCityTime($1)/geo;
    $_[0] =~ s/%LOCALCITYTIME%/&handleCityTime("")/geo;
}

# =========================
sub handleCityTime
{
    my ( $theAttr ) = @_;

    my $text = "";
    my $timeZone = &TWiki::Func::extractNameValuePair( $theAttr );
    $timeZone =~ s/[^\w\-\/\_\+]//gos;
    unless( $timeZone ) {
        # return help
        return "$installWeb.LocalCityTimePlugin help: Write a Continent/City timezone code listed in $gatewayUrl, "
             . "e.g. %<nop>LOCALCITYTIME{\"Europe/Zurich\"}%";
    }

    # try date command and zoneinfo file
    if( $useDateCmd && -d $tzDir && -f $dateCmd ) {
        my $tz = $tzDir . "/" . $timeZone;
        &TWiki::Func::writeDebug( "- LocalCityTimePlugin::handleCityTime: Try zoneinfo file $tz" ) if $debug;
        unless( -f $tz ) {
            return "$installWeb.LocalCityTimePlugin warning: Invalid Timezone '$timeZone'. Use a Continent/City timezone code "
                 . "listed in $gatewayUrl, e.g. %<nop>LOCALCITYTIME{\"Europe/Zurich\"}%";
        }
        my $saveTZ = $ENV{'TZ'};       # save timezone
        $ENV{'TZ'} = $tz;
        $text = `$dateCmd $dateParam`;
        chomp( $text );
        $ENV{'TZ'} = $saveTZ;          # restore TZ environment
        &TWiki::Func::writeDebug( "- LocalCityTimePlugin::handleCityTime: date cmd returns $text" ) if $debug;
        $text .= " (<a href=\"$gatewayUrl$gatewayParam$timeZone\">$timeZone</a>)";
        return $text;
    }

    # else fall back to slower time & date gateway
    &TWiki::Func::writeDebug( "- LocalCityTimePlugin: getUrl $gatewayUrl$gatewayParam$timeZone" ) if $debug;
    $text = &TWiki::Func::expandCommonVariables( "\%INCLUDE{\"$gatewayUrl$gatewayParam$timeZone\"}\%\n" );
    # &TWiki::Func::writeDebug( "- LocalCityTimePlugin::hand: getUrl has: $text" ) if $debug;

    if( $text =~ /Invalid Timezone/ ) {
        return "$installWeb.LocalCityTimePlugin warning: Invalid Timezone '$timeZone'. Use a Continent/City timezone code "
             . "listed in $gatewayUrl, e.g. %<nop>LOCALCITYTIME{\"Europe/Zurich\"}%";
    }
    $text =~ s/.*<!\-\-tzdate:date\-\->(.*?)<\!\-\-\/tzdate:date\-\->.*/$1/os;
    unless( $1 ) {
        return "$installWeb.LocalCityTimePlugin error: Can't read $gatewayUrl$gatewayParam$timeZone (due to a "
             . "proxy problem?), or received data has invalid format (due to change in web page layout?).";
    }
    &TWiki::Func::writeDebug( "- LocalCityTimePlugin::handleCityTime: gateway returns <<$text>>" ) if $debug;
    $text .= " (<a href=\"$gatewayUrl$gatewayParam$timeZone\">$timeZone</a>)";

    return $text;
}

# =========================

1;
