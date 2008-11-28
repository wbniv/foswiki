# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2001-2003 John Talintyre, jet@cheerful.com
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.org
# Copyright (C) 2005-2007 TWiki Contributors
# Copyright (C) 2008 Foswiki Contributors.
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
#
# Allow sorting of tables, plus setting of background colour for
# headings and data cells. See %SYSTEMWEB%.TablePlugin for details of use

use strict;

package Foswiki::Plugins::TablePlugin;

require Foswiki::Func;    # The plugins API
require Foswiki::Plugins; # For the API version

use vars qw( $topic $installWeb $VERSION $RELEASE $initialised );

# This should always be $Rev: 16047 $ so that Foswiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 16047 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = '1.036';

sub initPlugin {
    my( $web, $user );
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $Foswiki::Plugins::VERSION < 1.026 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between TablePlugin and Plugins.pm' );
        return 0;
    }

    my $cgi = Foswiki::Func::getCgiQuery();
    return 0 unless $cgi;

    $initialised = 0;

    return 1;
}

sub preRenderingHandler {
    ### my ( $text, $removed ) = @_;

    my $sort = Foswiki::Func::getPreferencesValue( 'TABLEPLUGIN_SORT' );
    return unless ($sort && $sort =~ /^(all|attachments)$/) ||
      $_[0] =~ /%TABLE{.*?}%/;

    # on-demand inclusion
    require Foswiki::Plugins::TablePlugin::Core;
    Foswiki::Plugins::TablePlugin::Core::handler( @_ );
}

1;
