# Plugin for Foswiki - The Free Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2002-2006 Peter Thoeny, peter@thoeny.org
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#
# As per the GPL, removal of this notice is prohibited.

package TWiki::Plugins::SlidyPlugin;

use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $debug
    );

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning( "Version mismatch between SlidyPlugin and Plugins.pm" );
        return 0;
    }

    return 1;
}

sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead
    if( $_[0] =~ /%SLIDYSTART/ ) {
        require TWiki::Plugins::SlidyPlugin::Slidy;
        TWiki::Plugins::SlidyPlugin::Slidy::init( $installWeb );
        $_[0] = TWiki::Plugins::SlidyPlugin::Slidy::handler( @_ );
    }
}

1;
