# Plugin for Foswiki - The Free Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2001-2007 Peter Thoeny, peter@thoeny.org
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
# As per the GPL, removal of this notice is prohibited.
# =========================

# =========================
package TWiki::Plugins::RenderListPlugin
  ;    # change the package name and $pluginName!!!

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $pluginName
  $debug $pubUrl $attachUrl
);

$VERSION    = '$Rev: 16234 $';
$RELEASE    = '2.0';
$pluginName = 'RenderListPlugin';    # Name of this Plugin

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag("\U$pluginName\E_DEBUG");

    # one time initialization
    $pubUrl    = TWiki::Func::getUrlHost() . TWiki::Func::getPubUrlPath();
    $attachUrl = "$pubUrl/$installWeb/$pluginName";

    # Plugin correctly initialized
    TWiki::Func::writeDebug(
        "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK")
      if $debug;
    return 1;
}

# =========================
sub startRenderingHandler {
### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    TWiki::Func::writeDebug("- ${pluginName}::startRenderingHandler( $_[1] )")
      if $debug;

    # This handler is called by getRenderedVersion just before the line loop

    # Render here, not in commonTagsHandler so that lists produced by
    # Plugins, TOC and SEARCH can be rendered
    if ( $_[0] =~ /%RENDERLIST/o ) {
        unless ( $_[0] =~
s/%RENDERLIST{(.*?)}%(([\n\r]+[^ ]{3}[^\n\r]*)*?)(([\n\r]+ {3}[^\n\r]*)+)/&handleRenderList($1, $2, $4)/ges
          )
        {

            # Cairo compatibility fallback
            $_[0] =~
s/%RENDERLIST{(.*?)}%(([\n\r]+[^\t]{1}[^\n\r]*)*?)(([\n\r]+\t[^\n\r]*)+)/&handleRenderList($1, $2, $4)/ges;
        }
    }
}

# =========================
sub handleRenderList {
    my ( $theAttr, $thePre, $theList ) = @_;

    $theAttr =~ s/ {3}/\t/gs;
    $thePre  =~ s/ {3}/\t/gs;
    $theList =~ s/ {3}/\t/gs;

    my $focus = &TWiki::Func::extractNameValuePair( $theAttr, "focus" );
    my $depth = &TWiki::Func::extractNameValuePair( $theAttr, "depth" );
    my $theme = &TWiki::Func::extractNameValuePair( $theAttr, "theme" )
      || &TWiki::Func::extractNameValuePair($theAttr);
    $theme = "RENDERLISTPLUGIN_" . uc($theme) . "_THEME";
    $theme = &TWiki::Func::getPreferencesValue($theme)
      || "unrecognized theme type";
    my ( $type, $params ) = split( /, */, $theme, 2 );
    $type = lc($type);

    if ( $type eq "tree" || $type eq "icon" ) {
        return $thePre
          . renderIconList( $type, $params, $focus, $depth, $theList );
    }
    else {
        return "$thePre$theList";
    }
}

# =========================
sub renderIconList {
    my ( $theType, $theParams, $theFocus, $theDepth, $theText ) = @_;

    $theText =~ s/^[\n\r]*//os;
    my @tree       = ();
    my $level      = 0;
    my $type       = "";
    my $text       = "";
    my $focusIndex = -1;
    foreach ( split( /[\n\r]+/, $theText ) ) {
        m/^(\t+)(.) *(.*)/;
        $level = length($1);
        $type  = $2;
        $text  = $3;
        if ( ($theFocus) && ( $focusIndex < 0 ) && ( $text =~ /$theFocus/ ) ) {
            $focusIndex = scalar(@tree);
        }
        push( @tree, { level => $level, type => $type, text => $text } );
    }

    # reduce tree to relatives around focus
    if ( $focusIndex >= 0 ) {

        # splice tree into before, current node and after parts
        my @after = splice( @tree, $focusIndex + 1 );
        my $nref = pop(@tree);

        # highlight node with focus and remove links
        $text = $nref->{'text'};
        $text =~
          s/^([^\-]*)\[\[.*?\]\[(.*?)\]\]/$1$2/o;    # remove [[...][...]] link
        $text =~ s/^([^\-]*)\[\[(.*?)\]\]/$1$2/o;    # remove [[...]] link
        $text = "<b> $text </b>";                    # bold focus text
        $nref->{'text'} = $text;

        # remove uncles and siblings below current node
        $level = $nref->{'level'};
        for ( my $i = 0 ; $i < scalar(@after) ; $i++ ) {
            if (
                ( $after[$i]->{'level'} < $level )
                || (   $after[$i]->{'level'} <= $level
                    && $after[$i]->{'type'} ne " " )
              )
            {
                splice( @after, $i );
                last;
            }
        }

        # remove uncles and siblings above current node
        my @before = ();
        for ( my $i = scalar(@tree) - 1 ; $i >= 0 ; $i-- ) {
            if ( $tree[$i]->{'level'} < $level ) {
                push( @before, $tree[$i] );
                $level = $tree[$i]->{'level'};
            }
        }
        @tree       = reverse(@before);
        $focusIndex = scalar(@tree);
        push( @tree, $nref );
        push( @tree, @after );
    }

    # limit depth of tree
    my $depth = $theDepth;
    unless ( $depth =~ s/.*?([0-9]+).*/$1/o ) {
        $depth = 0;
    }
    if ($theFocus) {
        if ( $theDepth eq "" ) {
            $depth = $focusIndex + 3;
        }
        else {
            $depth += $focusIndex + 1;
        }
    }
    if ( $depth > 0 ) {
        my @tmp = ();
        foreach my $ref (@tree) {
            push( @tmp, $ref ) if ( $ref->{'level'} <= $depth );
        }
        @tree = @tmp;
    }

    $theParams =~ s/%PUBURL%/$pubUrl/go;
    $theParams =~ s/%ATTACHURL%/$attachUrl/go;
    $theParams =~ s/%WEB%/$installWeb/go;
    $theParams =~ s/%MAINWEB%/TWiki::Func::getMainWebname()/geo;
    $theParams =~ s/%SYSTEMWEB%/TWiki::Func::getTwikiWebname()/geo;
    my ( $showLead, $width, $height, $iconSp, $iconT, $iconI, $iconL, $iconImg )
      = split( /, */, $theParams );
    $width  = 16          unless ($width);
    $height = 16          unless ($height);
    $iconSp = "empty.gif" unless ($iconSp);
    $iconSp = fixImageTag( $iconSp, $width, $height );
    $iconT = "dot_udr.gif" unless ($iconT);
    $iconT = fixImageTag( $iconT, $width, $height );
    $iconI = "dot_ud.gif" unless ($iconI);
    $iconI = fixImageTag( $iconI, $width, $height );
    $iconL = "dot_ur.gif" unless ($iconL);
    $iconL = fixImageTag( $iconL, $width, $height );
    $iconImg = "home.gif" unless ($iconImg);
    $iconImg = fixImageTag( $iconImg, $width, $height );

    $text = "";
    my $start = 0;
    $start = 1 unless ($showLead);
    my @listIcon = ();
    for ( my $i = 0 ; $i < scalar(@tree) ; $i++ ) {
        $text .=
          '<table border="0" cellspacing="0" cellpadding="0"><tr>' . "\n";
        $level = $tree[$i]->{'level'};
        for ( my $l = $start ; $l < $level ; $l++ ) {
            if ( $l == $level - 1 ) {
                $listIcon[$l] = $iconSp;
                for ( my $x = $i + 1 ; $x < scalar(@tree) ; $x++ ) {
                    last if ( $tree[$x]->{'level'} < $level );
                    if (   $tree[$x]->{'level'} <= $level
                        && $tree[$x]->{'type'} ne " " )
                    {
                        $listIcon[$l] = $iconI;
                        last;
                    }
                }
                if ( $tree[$i]->{'type'} eq " " ) {
                    $text .= "<td valign=\"top\">$listIcon[$l]</td>\n";
                }
                elsif ( $listIcon[$l] eq $iconSp ) {
                    $text .= "<td valign=\"top\">$iconL</td>\n";
                }
                else {
                    $text .= "<td valign=\"top\">$iconT</td>\n";
                }
            }
            else {
                $text .=
                  "<td valign=\"top\">" . ( $listIcon[$l] || '' ) . "</td>\n";
            }
        }
        if ( $theType eq "icon" ) {

            # icon theme type
            if ( $tree[$i]->{'type'} eq " " ) {

                # continuation line
                $text .= "<td valign=\"top\">$iconSp</td>\n";
            }
            elsif ( $tree[$i]->{'text'} =~
                /^\s*(<b>)?\s*((icon\:)?<img[^>]+>|icon\:[^\s]+)\s*(.*)/ )
            {

                # specific icon
                $tree[$i]->{'text'} = $4;
                $tree[$i]->{'text'} = "$1 $4" if ($1);
                my $icon = $2;
                $icon =~ s/^icon\://o;
                $icon = fixImageTag( $icon, $width, $height );
                $text .= "<td valign=\"top\">$icon</td>\n";
            }
            else {

                # default icon
                $text .= "<td valign=\"top\">$iconImg</td>\n";
            }
            $text .=
"<td valign=\"top\"><nobr>&nbsp; $tree[$i]->{'text'} </nobr></td>\n";

        }
        else {

            # tree theme type
            if ( $tree[$i]->{'text'} =~
                /^\s*(<b>)?\s*((icon\:)?<img[^>]+>|icon\:[^\s]+)\s*(.*)/ )
            {

                # specific icon
                $tree[$i]->{'text'} = $4;
                $tree[$i]->{'text'} = "$1 $4" if ($1);
                my $icon = $2;
                $icon =~ s/^icon\://o;
                $icon = fixImageTag( $icon, $width, $height );
                $text .= "<td valign=\"top\">$icon</td>\n";
                $text .=
"<td valign=\"top\"><nobr>&nbsp; $tree[$i]->{'text'} </nobr></td>\n";
            }
            else {
                $text .=
"<td valign=\"top\"><nobr> $tree[$i]->{'text'} </nobr></td>\n";
            }
        }
        $text .= '</tr></table>' . "\n";
    }
    return $text;
}

# =========================
sub fixImageTag {
    my ( $theIcon, $theWidth, $theHeight ) = @_;

    if ( $theIcon !~ /^<img/i ) {
        $theIcon .= '.gif' if ( $theIcon !~ /\.(png|gif|jpeg|jpg)$/i );
        $theIcon = "$attachUrl/$theIcon" if ( $theIcon !~ /^(\/|https?\:)/ );
        $theIcon =
            "<img src=\"$theIcon\" width=\"$theWidth\" height=\"$theHeight\""
          . " alt=\"\" border=\"0\" />";
    }
    return $theIcon;
}

# =========================

1;
