# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.com
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
#
# =========================
package TWiki::Plugins::MaketextCompatibilityPlugin;

# =========================
use vars qw(
        $VERSION $RELEASE 
        $debug
    );

$VERSION = '$Rev$';
$RELEASE = '1.11';
$debug = 0; # toggle me

# =========================
sub initPlugin {
    return 1;
}

# =========================
sub commonTagsHandler {
    $_[0] =~ s/%MAKETEXT{(.*?)}%/&_MAKETEXT($1)/ge;
}

# =========================
sub _MAKETEXT {
    my( $attrs ) = @_;

    my $str = TWiki::Func::extractNameValuePair($attrs) ||
              TWiki::Func::extractNameValuePair($attrs, 'string') || '';

    return '' unless $str;

    # escape everything:
    $str =~ s/\[/~[/go;
    $str =~ s/\]/~]/go;

    # restore already escaped stuff:
    $str =~ s/~~\[/~[/go;
    $str =~ s/~~\]/~]/go;

    # unescape parameters and calculate highest parameter number:
    my $max = 0;
    $str =~ s/~\[(\_(\d+))~\]/ $max = $2 if ($2 > $max); "[$1]"/ge;
    $str =~ s/~\[(\*,\_(\d+),[^,]+(,([^,]+))?)~\]/ $max = $2 if ($2 > $max); "[$1]"/ge;

    # get the args to be interpolated.
    my $argsStr = TWiki::Func::extractNameValuePair($attrs, 'args');

    my @args = split (/\s*,\s*/, $argsStr) ;
    # fill omitted args with zeros
    while ((scalar @args) < $max) {
        push(@args, 0);
    }

    # do the magic:
    my $result = _doMagic($str, @args);

    # replace accesskeys:
    $result =~ s#(^|[^&])&([a-zA-Z])#$1<span class='twikiAccessKey'>$2</span>#g;

    # replace escaped amperstands:
    $result =~ s/&&/\&/g;

    return $result;
}

# taken from TWiki::I18N::Fallback
sub _doMagic {
    my ( $text, @args ) = @_;

    return '' unless $text;

    # substitute parameters:
    $text =~ s/\[\_(\d+)\]/$args[$1-1]/ge;

    # unescape escaped square brackets:
    $text =~ s/~(\[|\])/$1/g;

    #plurals:
    $text =~ s/\[\*,\_(\d+),([^,]+)(,([^,]+))?\]/_handlePlurals($args[$1-1],$2,$4)/ge;

    return $text;
}

# taken from TWiki::I18N::Fallback
sub _handlePlurals {
    my ( $number, $singular, $plural ) = @_;
    # bad hack, but Locale::Maketext does it the same way ;)
    return $number . ' ' . (($number == 1) ? $singular : ( $plural ? ($plural) : ($singular . 's') ) );
}

1;
