# Plugin for Foswiki - The Free Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2003 Micahel Sparks
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

package TWiki::Plugins::RandomTopicPlugin;

use strict;

use vars qw(
            $VERSION $RELEASE @topicList $defaultIncludes $defaultExcludes
    );

# This should always be $Rev: 8003 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 8003 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';


sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    $defaultIncludes = TWiki::Func::getPreferencesValue( "RANDOMTOPICPLUGIN_INCLUDE" );
    $defaultExcludes = TWiki::Func::getPreferencesValue( "RANDOMTOPICPLUGIN_EXCLUDE" );

    @topicList = TWiki::Func::getTopicList( $web );

    return 1;
}

sub handleRandomPage {
    my $attr = shift;

    my $format;
    my $topics = 1;
    my $includes;
    my $excludes;

    $format =
      TWiki::Func::extractNameValuePair( $attr, "format" ) ||
          "\$t* \$topic\$n";
    $topics =
      TWiki::Func::extractNameValuePair( $attr, "topics" ) || 1;

    $includes =
      TWiki::Func::extractNameValuePair( $attr, "include" ) ||
          $defaultIncludes || "^.+\$";

    $excludes =
      TWiki::Func::extractNameValuePair( $attr, "exclude" ) ||
          $defaultExcludes || "^\$";

    my @pickFrom = grep { /$includes/ && !/$excludes/ } @topicList;

    my $result = "";
    my %chosen = ();
    my $pickable = scalar( @pickFrom );
    while ( $topics && $pickable ) {
        my $i = int( rand( scalar @pickFrom ));
        unless ( $chosen{$i} ) {
            my $line = $format;
            $line =~ s/\$topic/$pickFrom[$i]/g;
            $line =~ s/\$t/\t/g;
            $line =~ s/\$n/\n/g;
            $result .= $line;
            $topics--;
            $pickable--;
            $chosen{$i} = 1;
        }
    }
    return $result;
}

sub commonTagsHandler {
### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead
    $_[0] =~ s/%RANDOMTOPIC%/&handleRandomPage()/ge;
    $_[0] =~ s/%RANDOMTOPIC{(.*?)}%/&handleRandomPage($1)/ge;
}

1;
