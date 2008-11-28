# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2007 Andrew Jones, andrewjones86@googlemail.com
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

package TWiki::Plugins::HostnamePlugin;

use strict;

use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC );

$VERSION = '$Rev$';
$RELEASE = 'TWiki-4.2';
$SHORTDESCRIPTION = 'Displays the hostname of the server serving TWiki.';
$NO_PREFS_IN_TOPIC = 1;
$pluginName = 'HostnamePlugin';

sub initPlugin {
    #my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    TWiki::Func::registerTagHandler( 'HOSTNAME', \&_handleTag);

    # Plugin correctly initialized
    return 1;
}

sub _handleTag {
    #my($session, $params, $theTopic, $theWeb) = @_;

    eval 'use Sys::Hostname';
    if (! $@ ){
        return hostname();
    } else {
        TWiki::Func::writeWarning( $@ );
        return "<span class='twikiAlert'>$pluginName error: Sys::Hostname not found in \@INC. Please contact %WIKIWEBMASTER%.";
    }
}

1;
