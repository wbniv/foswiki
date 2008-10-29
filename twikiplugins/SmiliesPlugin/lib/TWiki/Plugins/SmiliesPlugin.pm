# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
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
#
# This plugin replaces smilies with small smilies bitmaps

package TWiki::Plugins::SmiliesPlugin;

use strict;

use TWiki::Func;

use vars qw( $VERSION $RELEASE
            %smiliesUrls %smiliesEmotions
            $smiliesPubUrl $allPattern $smiliesFormat );

# This should always be $Rev: 16049 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 16049 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between InterwikiPlugin and Plugins.pm" );
        return 0;
    }

    # Get plugin preferences
    $smiliesFormat =
      TWiki::Func::getPreferencesValue( 'SMILIESPLUGIN_FORMAT' ) 
          || '<img src="$url" alt="$tooltip" title="$tooltip" border="0" />';

    $topic =
      TWiki::Func::getPreferencesValue( 'SMILIESPLUGIN_TOPIC' ) 
          || "$installWeb.SmiliesPlugin";

    $web = $installWeb;
    if( $topic =~ /(.+)\.(.+)/ ) {
        $web = $1;
        $topic = $2;
    }

    $allPattern = "(";
    foreach( split( /\n/, TWiki::Func::readTopicText( $web, $topic, undef, 1 ) ) ) {
        # smilie       url            emotion
        if( m/^\s*\|\s*<nop>(?:\&nbsp\;)?([^\s|]+)\s*\|\s*%ATTACHURL%\/([^\s]+)\s*\|\s*"([^"|]+)"\s*\|\s*$/o ) {
            $allPattern .= "\Q$1\E|";
            $smiliesUrls{$1}     = $2;
            $smiliesEmotions{$1} = $3;
        }
    }
    $allPattern =~ s/\|$//o;
    $allPattern .= ")";
    $smiliesPubUrl =
      TWiki::Func::getUrlHost() . TWiki::Func::getPubUrlPath() .
          "/$installWeb/SmiliesPlugin";

    # Initialization OK
    return 1;
}

sub commonTagsHandler {
    # my ( $text, $topic, $web ) = @_;
    $_[0] =~ s/%SMILIES%/_allSmiliesTable()/geo;
}

sub preRenderingHandler {
#    my ( $text, \%removed ) = @_;

    $_[0] =~ s/(\s|^)$allPattern(?=\s|$)/_renderSmily($1,$2)/geo;
}

sub _renderSmily {
    my ( $thePre, $theSmily ) = @_;

    return $thePre unless $theSmily;

    my $text = $thePre.$smiliesFormat;
    $text =~ s/\$emoticon/$theSmily/go;
    $text =~ s/\$tooltip/$smiliesEmotions{$theSmily}/go;
    $text =~ s/\$url/$smiliesPubUrl\/$smiliesUrls{$theSmily}/go;

    return $text;
}

sub _allSmiliesTable {
    my $text = "| *What to Type* | *Graphic That Will Appear* | *Emotion* |\n";

    foreach my $k ( sort { $smiliesEmotions{$b} cmp $smiliesEmotions{$a} }
                 keys %smiliesEmotions ) {
        $text .= "| <nop>$k | $k | ". $smiliesEmotions{$k} ." |\n";
    }
    return $text;
}

1;
