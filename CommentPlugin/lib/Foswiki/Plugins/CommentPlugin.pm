# Plugin for Foswiki - The Free Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2004 Crawford Currie
# Copyright (C) 2001-2006 Foswiki Contributors. All Rights Reserved.
# Foswiki Contributors
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
# See Plugin topic for history and plugin information

package Foswiki::Plugins::CommentPlugin;

use strict;

require Foswiki::Func;
require Foswiki::Plugins;

use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $NO_PREFS_IN_TOPIC );

# This should always be $Rev: 15788 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 15788 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = '03 Aug 2008';

$SHORTDESCRIPTION = 'Allows users to quickly post comments to a page without an edit/preview/save cycle';

sub initPlugin {
    #my ( $topic, $web, $user, $installWeb ) = @_;

    if( $Foswiki::Plugins::VERSION < 1.026 ) {
        Foswiki::Func::writeWarning( "CommentPlugin $VERSION requires Foswiki::Plugins::VERSION >= 1.026, $Foswiki::Plugins::VERSION found." );
        return 0;
    }

    return 1;
}

sub commonTagsHandler {
    my ( $text, $topic, $web, $meta ) = @_;

    require Foswiki::Plugins::CommentPlugin::Comment;

    my $query = Foswiki::Func::getCgiQuery();
    return unless( defined( $query ));

    return unless $_[0] =~ m/%COMMENT({.*?})?%/o;

    # SMELL: Nasty, tacky way to find out where we were invoked from
    my $scriptname = $ENV{'SCRIPT_NAME'} || '';
    # SMELL: unreliable
    my $previewing = ($scriptname =~ /\/(preview|gnusave|rdiff)/);
    Foswiki::Plugins::CommentPlugin::Comment::prompt( $previewing,
                                                    $_[0], $web, $topic );
}

sub beforeSaveHandler {
    #my ( $text, $topic, $web ) = @_;

    require Foswiki::Plugins::CommentPlugin::Comment;

    my $query = Foswiki::Func::getCgiQuery();
    return unless $query;

    my $action = $query->param('comment_action');

    return unless( defined( $action ) && $action eq 'save' );
    Foswiki::Plugins::CommentPlugin::Comment::save( @_ );
}

1;
