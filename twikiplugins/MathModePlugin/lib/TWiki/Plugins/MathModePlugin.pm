# MathModePlugin.pm
#
# Copyright (C) 2006 MichaelDaum@WikiRing.com
# Copyright (C) 2002 Graeme Lufkin, gwl@u.washington.edu
#
# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
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
###############################################################################

package TWiki::Plugins::MathModePlugin;

use strict;
use vars qw(
  $web $topic $VERSION $RELEASE $core %TWikiCompatibility
  $NO_PREFS_IN_TOPIC $SHORTDESCRIPTION
);
$VERSION = '$Rev: 12308 $';
$RELEASE = '2.94';
$NO_PREFS_IN_TOPIC = 1;
$SHORTDESCRIPTION = 'Include <nop>LaTeX formatted math in your TWiki pages';
$TWikiCompatibility{endRenderingHandler} = 1.1;

###############################################################################
sub initPlugin {
  ($topic, $web) = @_;
	
  $core = undef;
  return 1;
}

###############################################################################
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;

  $_[0] =~ s/%\\\[(.*?)\\\]%/&handleMath($1,0)/geo;
  $_[0] =~ s/%\$(.*?)\$%/&handleMath($1,1)/geo;
  $_[0] =~ s/<latex(?: (.*?))?>(.*?)<\/latex>/&handleMath($2,2,$1)/geos;
}

###############################################################################
sub getCore {
  return $core if $core;
  
  eval 'use TWiki::Plugins::MathModePlugin::Core;';
  die $@ if $@;

  $core = new TWiki::Plugins::MathModePlugin::Core;
  return $core;
}

###############################################################################
sub handleMath { 
  return getCore()->handleMath($web, $topic, @_); 
}

###############################################################################
sub endRenderingHandler { 
  return unless $core; # no math
  $core->postRenderingHandler($web, $topic, @_)
}

###############################################################################
sub postRenderingHandler { 
  return unless $core; # no math
  $core->postRenderingHandler($web, $topic, @_)
}
	
1;
