# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
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

use strict;
use TWiki::Func;

package TWiki::Plugins::SlidyPlugin::Slidy;

use vars qw( $imgRoot $installWeb );

sub init {
    $installWeb = shift;
    $imgRoot    = '%PUBURLPATH%/' . $installWeb . '/SlidyPlugin';
}

sub handler {
    my ( $text, $theTopic, $theWeb ) = @_;
    my $origtext = $text;

    my $textPre  = "";
    my $textPost = "";
    my $args     = "";
    if ( $text =~ /^(.*)%SLIDYSTART%(.*)$/s ) {
        $textPre = $1;
        $text    = $2;
    }
    elsif ( $text =~ /^(.*)%SLIDYSTART{(.*?)}%(.*)$/s ) {
        $textPre = $1;
        $args    = $2;
        $text    = $3;
    }
    if ( $text =~ /^(.*)%SLIDYEND%(.*)$/s ) {
        $text     = $1;
        $textPost = $2;
    }

    # Make sure we don't end up back in the handler again
    # SMELL: there should be a better block
    $text =~ s/%SLIDY/%<nop>SLIDY/g;

    my $query = TWiki::Func::getCgiQuery();
    my $cover = "";

    if ( $query && $query->param('skin') eq 'slidy' ) {

        # in presentation mode

        if ( $text =~ /^\s*[\n\r]\-\-\-\% (.*?)([\n\r]\-\-\-\+ .*)$/s ) {
            $cover = "\n<div class='slide cover'>\n";
            $cover .=
'<!-- hidden style graphics to ensure they are saved with other content -->';
            $cover .=
'<img class="hidden" src="%PUBURLPATH%/%SYSTEMWEB%/SlidyPlugin/bullet.png" alt="" />';
            $cover .=
'<img class="hidden" src="%PUBURLPATH%/%SYSTEMWEB%/SlidyPlugin/fold.bmp" alt="" />';
            $cover .=
'<img class="hidden" src="%PUBURLPATH%/%SYSTEMWEB%/SlidyPlugin/unfold.bmp" alt="" />';
            $cover .=
'<img class="hidden" src="%PUBURLPATH%/%SYSTEMWEB%/SlidyPlugin/fold-dim.bmp" alt="" />';
            $cover .=
'<img class="hidden" src="%PUBURLPATH%/%SYSTEMWEB%/SlidyPlugin/nofold-dim.bmp" alt="" />';
            $cover .=
'<img class="hidden" src="%PUBURLPATH%/%SYSTEMWEB%/SlidyPlugin/unfold-dim.bmp" alt="" />';
            $cover .=
'<img class="hidden" src="%PUBURLPATH%/%SYSTEMWEB%/SlidyPlugin/bullet-fold.gif" alt="" />';
            $cover .=
'<img class="hidden" src="%PUBURLPATH%/%SYSTEMWEB%/SlidyPlugin/bullet-unfold.gif" alt="" />';
            $cover .=
'<img class="hidden" src="%PUBURLPATH%/%SYSTEMWEB%/SlidyPlugin/bullet-fold-dim.gif" alt="" />';
            $cover .=
'<img class="hidden" src="%PUBURLPATH%/%SYSTEMWEB%/SlidyPlugin/bullet-nofold-dim.gif" alt="" />';
            $cover .=
'<img class="hidden" src="%PUBURLPATH%/%SYSTEMWEB%/SlidyPlugin/bullet-unfold-dim.gif" alt="" />';
            $cover .= "\n---+ " . $1 . "</div>";
            $text = $2;
        }

        my @slides = split( /[\n\r]\-\-\-\+ /, $text );
        $text = "\n";

        foreach (@slides) {
            if ( $_ =~ /\S+/ ) {
                $text .= "<div class='slide'>\n---+ " . $_ . "</div>\n";
            }
        }
        $text = $cover . $text;
    }
    else {

        # in normal topic view mode, substitute special slide cover heading
        $text =~ s/[\n\r]\-\-\-\% /\n\-\-\-\+ /s;

        # add start slideshow link
        $text =
            "$textPre \n#StartPresentation\n"
          . "<a href=\"%SCRIPTURLPATH%/view%SCRIPTSUFFIX%/$theWeb/$theTopic?skin=slidy\">"
          . "Start presentation</a>"
          . "\n$text $textPost";
    }

    return $text;
}

1;
