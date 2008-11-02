# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2004-2006 Peter Thoeny, peter@thoeny.org
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

# =========================
package TWiki::Plugins::VarCachePlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $pluginName
        $debug $paramMsg
    );

# This should always be $Rev: 8154 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 8154 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'VarCachePlugin';  # Name of this Plugin

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.024 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag( "\U$pluginName\E_DEBUG" );

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub beforeCommonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::beforeCommonTagsHandler( $_[2].$_[1] )" ) if $debug;

    return unless( $_[0] =~ /%VARCACHE/ );

    $_[0] =~ s/%VARCACHE{(.*?)}%/_handleVarCache( $_[2], $_[1], $1 )/ge;

    $_[0] =~ s/^.*(%--VARCACHE\:read\:.*?--%).*$/$1/os; # remove all text if "read cache"
}

# =========================
sub afterCommonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::afterCommonTagsHandler( $_[2].$_[1] )" ) if $debug;

    return unless( $_[0] =~ /%--VARCACHE\:/ );

    if( $_[0] =~ /%--VARCACHE\:([a-z]+)\:?(.*?)--%/ ) {
        my $save = ( $1 eq "save" );
        my $age = $2 || 0;
        my $cacheFilename = _cacheFileName( $_[2], $_[1], $save );

        if( $save ) {
            # update cache
            TWiki::Func::saveFile( $cacheFilename, $_[0] );
            $msg = _formatMsg( $_[2], $_[1] );
            $_[0] =~ s/%--VARCACHE\:.*?--%/$msg/go;

        } else {
            # read cache
            my $text = TWiki::Func::readFile( $cacheFilename );
            $msg = _formatMsg( $_[2], $_[1] );
            $msg =~ s/\$age/_formatAge($age)/geo;
            $text =~ s/%--VARCACHE.*?--%/$msg/go;
            $_[0] = $text;
        }
    }
}

# =========================
sub _formatMsg
{
    my ( $theWeb, $theTopic ) = @_;

    my $msg = $paramMsg; # FIXME: Global variable not reliable in mod_perl
    $msg =~ s|<nop>||go;
    $msg =~ s|\$link|%SCRIPTURL%/view%SCRIPTSUFFIX%/%WEB%/%TOPIC%?varcache=refresh|go;
    $msg =~ s|%ATTACHURL%|%PUBURL%/$installWeb/$pluginName|go;
    $msg =~ s|%ATTACHURLPATH%|%PUBURLPATH%/$installWeb/$pluginName|go;
    $msg = TWiki::Func::expandCommonVariables( $msg, $theTopic, $theWeb );
    return $msg;
}

# =========================
sub _formatAge
{
    my ( $age ) = @_;

    my $unit = "hours";
    if( $age > 24 ) {
        $age /= 24;
        $unit = "days";
    } elsif( $age < 1 ) {
        $age *= 60;
        $unit = "min";
    }
    if( $age >= 3 ) {
        $age = int( $age );
        return "$age $unit";
    }
    return sprintf( "%1.1f $unit", $age );
}

# =========================
sub _handleVarCache
{
    my ( $theWeb, $theTopic, $theArgs ) = @_;

    my $query = TWiki::Func::getCgiQuery();
    my $action = "check";
    if( $query ) {
        my $tmp = $query->param( 'varcache' ) || "";
        if( $tmp eq "refresh" ) {
            $action = "refresh";
        } else {
            $action = "" if( grep{ !/^refresh$/ } $query->param );
        }
    }

    if( $action eq "check" ) {
        my $filename = _cacheFileName( $theWeb, $theTopic, 0 );
        if( -e $filename ) {
            my $now = time();
            my $cacheTime = (stat $filename)[9] || 10000000000;
            # CODE_SMELL: Assume file system for topics
            $filename = TWiki::Func::getDataDir() . "/$theWeb/$theTopic.txt";
            my $topicTime = (stat $filename)[9] || 10000000000;
            my $refresh = TWiki::Func::extractNameValuePair( $theArgs, "refresh" )
                       || TWiki::Func::getPreferencesValue( "\U$pluginName\E_REFRESH" ) || 24;
            $refresh *= 3600;
            if( ( ( $refresh == 0 ) || ( $cacheTime >= $now - $refresh ) )
             && ( $cacheTime >= $topicTime ) ) {
                # add marker for afterCommonTagsHandler to read cached file
                $paramMsg = TWiki::Func::extractNameValuePair( $theArgs, "cachemsg" )
                         || TWiki::Func::getPreferencesValue( "\U$pluginName\E_CACHEMSG" )
                         || 'This topic was cached $age ago ([[$link][refresh]])';
                $cacheTime = sprintf( "%1.6f", ( $now - $cacheTime ) / 3600 );
                return "%--VARCACHE\:read:$cacheTime--%";
            }
        }
        $action = "refresh";
    }

    if( $action eq "refresh" ) {
        # add marker for afterCommonTagsHandler to refresh cache file
        $paramMsg = TWiki::Func::extractNameValuePair( $theArgs, "updatemsg" )
                 || TWiki::Func::getPreferencesValue( "\U$pluginName\E_UPDATEMSG" )
                 || 'This topic is now cached ([[$link][refresh]])';
        return "%--VARCACHE\:save--%";
    }

    # else normal uncached processing
    return "";
}

# =========================
sub _cacheFileName
{
    my ( $web, $topic, $mkDir ) = @_;

    # Create web directory "pub/$web" if needed
    my $dir = TWiki::Func::getPubDir() . "/$web";
    if( ( $mkDir ) && ( ! -e "$dir" ) ) {
        umask( 002 );
        mkdir( $dir, 0775 );
    }
    # Create topic directory "pub/$web/$topic" if needed
    $dir .= "/$topic";
    if( ( $mkDir ) && ( ! -e "$dir" ) ) {
        umask( 002 );
        mkdir( $dir, 0775 );
    }
    return "$dir/_${pluginName}_cache.txt";
}

# =========================
1;
