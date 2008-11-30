# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2006 Peter Thoeny, Peter@Thoeny.org
# Copyright (C) 2002-2006 Crawford Currie, cc@c-dot.co.uk
# Copyright (C) 2008 Foswiki Contributors
#
# For licensing info read LICENSE file in the Foswiki root.
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
# As per the GPL, removal of this notice is prohibited.

package Foswiki::Plugins::FoswikiDrawPlugin;

use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $editButton
    );

# This should always be $Rev: 8154 $ so that Foswiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 8154 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

my $editmess;

sub initPlugin {
  ( $topic, $web, $user, $installWeb ) = @_;

  # check for Plugins.pm versions
  if( $Foswiki::Plugins::VERSION < 1 ) {
	Foswiki::Func::writeWarning( "Version mismatch between FoswikiDrawPlugin and Plugins.pm" );
	return 0;
  }

  # Get plugin debug flag
  $editButton = Foswiki::Func::getPreferencesValue( "FOSWIKIDRAWPLUGIN_EDIT_BUTTON" );
  $editmess = Foswiki::Func::getPreferencesValue( "FOSWIKIDRAWPLUGIN_EDIT_TEXT" ) ||
    "Edit drawing using Foswiki Draw applet (requires a Java 1.1 enabled browser)";
  $editmess =~ s/['"]/`/g;

  return 1;
}

sub handleDrawing {
  my( $attributes, $topic, $web ) = @_;
  my $nameVal = Foswiki::Func::extractNameValuePair( $attributes );
  if( ! $nameVal ) {
	$nameVal = "untitled";
  }
  $nameVal =~ s/[^A-Za-z0-9_\.\-]//go; # delete special characters

  # should really use Foswiki server-side include mechanism....
  my $mapFile = Foswiki::Func::getPubDir() . "/$web/$topic/$nameVal.map";
  my $img = "src=\"%ATTACHURLPATH%/$nameVal.gif\"";
  my $editUrl =
	Foswiki::Func::getOopsUrl($web, $topic, "foswikidraw", $nameVal);
  my $imgText = "";
  my $edittext = $editmess;
  $edittext =~ s/%F%/$nameVal/g;
  my $hover =
    "onmouseover=\"window.status='$edittext';return true;\" ".
      "onmouseout=\"window.status='';return true;\"";

  if ( -e $mapFile ) {
	my $mapname = $nameVal;
	$mapname =~ s/^.*\/([^\/]+)$/$1/;
	$img .= " usemap=\"#$mapname\"";
	my $map = Foswiki::Func::readFile($mapFile);
    # Unashamed hack to handle Web.TopicName links
    $map =~ s/href=\"((\w+)\.)?(\w+)(#\w+)?\"/&_processHref($2,$3,$4,$web)/ge;
	$map = Foswiki::Func::expandCommonVariables( $map, $topic );
	$map =~ s/%MAPNAME%/$mapname/g;
	$map =~ s/%FOSWIKIDRAW%/$editUrl/g;
	$map =~ s/%EDITTEXT%/$edittext/g;
	$map =~ s/%HOVER%/$hover/g;
	$map =~ s/[\r\n]+//g;

	# Add an edit link just above the image if required
	$imgText = "<br /><a href=\"$editUrl\" $hover>".
          "Edit</a><br />" if ( $editButton == 1 );
#	$imgText = "<br /><button onclick=\"window.location='$editUrl'\" $hover>".
#          "Edit</button><br />" if ( $editButton == 1 );
	$imgText .= "<img $img>$map";
  } else {
	# insensitive drawing; the whole image gets a rather more
	# decorative version of the edit URL
	$imgText = "<a href=\"$editUrl\" $hover>".
          "<img $img $hover alt=\"$edittext\" title=\"$edittext\" /></a>";
#	$imgText = "<br /><button onclick=\"window.location='$editUrl'\" $hover>".
#          "$edittext</button><br />" if ( $editButton == 1 );
  }
  return $imgText;
}

sub _processHref {
    my ( $web, $topic, $anchor, $defweb ) = @_;

    $web = $defweb unless ( $web );
    $anchor = "" unless $anchor;

    return "href=\"%SCRIPTURLPATH%/view%SCRIPTSUFFIX%/$web/$topic$anchor\"";
}

sub commonTagsHandler
{
  ### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead
  $_[0] =~ s/%DRAWING{(.*?)}%/&handleDrawing($1, $_[1], $_[2])/geo;
  $_[0] =~ s/%DRAWING%/&handleDrawing("untitled", $_[1], $_[2])/geo;
}

1;
