# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) Evolved Media Network 2005
# Copyright (C) Spanlink Communications 2006
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
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
#
# Author: Crawford Currie http://c-dot.co.uk
#
# This plugin helps with permissions management by displaying the web
# permissions in a big table that can easily be edited. It updates WebPreferences
# in each affected web.

package TWiki::Plugins::WebPermissionsPlugin;

use strict;

use vars qw( $VERSION $RELEASE $pluginName $antiBeforeSaveRecursion);

use TWiki::Func;
use CGI qw( :all );
use Error;

$pluginName = 'WebPermissionsPlugin';

$VERSION = '$Rev: 160$';

$RELEASE = '1.120';

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.10 ) {
        TWiki::Func::writeWarning(
            'Version mismatch between WebPermissionsPlugin and TWiki::Plugins' );
        return 0;
    }

    TWiki::Func::registerTagHandler( 'WEBPERMISSIONS', \&_WEBPERMISSIONS );
    TWiki::Func::registerTagHandler( 'TOPICPERMISSIONS', \&_TOPICPERMISSIONS );
    # SMELL: need to disable this if the USERSLIST code is ever moved into the
    # core.
    TWiki::Func::registerTagHandler( 'USERSLIST', \&_USERSLIST );
    $antiBeforeSaveRecursion = 0;

    return 1;
}

sub _WEBPERMISSIONS {
    my( $session, $params, $topic, $web ) = @_;

    #return undef unless TWiki::Func::isAdmin();

    require TWiki::Plugins::WebPermissionsPlugin::Core;
    TWiki::Plugins::WebPermissionsPlugin::Core::WEBPERMISSIONS(@_);
}


#TODO: add param topic= and show= specify to list only groups / only users / both
sub _TOPICPERMISSIONS {
    require TWiki::Plugins::WebPermissionsPlugin::Core;
    return TWiki::Plugins::WebPermissionsPlugin::Core::TOPICPERMISSIONS(@_);
}

sub _USERSLIST {
    require TWiki::Plugins::WebPermissionsPlugin::Core;
    return TWiki::Plugins::WebPermissionsPlugin::Core::USERSLIST(@_);
}

#TODO: rejig this so it works for the WEBPERMS too
sub beforeSaveHandler {
    require TWiki::Plugins::WebPermissionsPlugin::Core;
    return TWiki::Plugins::WebPermissionsPlugin::Core::beforeSaveHandler(@_);
}

1;
