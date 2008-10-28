# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005 Michael Daum <micha@nats.informatik.uni-hamburg.de>
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
package TWiki::Plugins::GluePlugin;
use strict;

# =========================
use vars qw(
        $VERSION $RELEASE $web $topic $doExpandCommonVariables
	$NO_PREFS_IN_TOPIC $SHORTDESCRIPTION
    );

$VERSION = '$Rev$';
$RELEASE = '1.52';
$NO_PREFS_IN_TOPIC = 1;
$SHORTDESCRIPTION = 'Enable <nop>TWikiML to span multiple lines';

# =========================
sub initPlugin { 
  ( $topic, $web) = @_;

  $doExpandCommonVariables = 1;

  return 1; 
}

# =========================
sub writeDebug {
  #&TWiki::Func::writeDebug("GluePlugin - $_[0]");
}

# =========================
# This handler is inefficient. Coding tilde glue into handleCommonTags() would
# be much more efficient. We don't use the beforeCommonTagsHandler
# as we'd loose verbatim handling.
sub commonTagsHandler {

  my $found = 0;

  # apply glue
  $found = 1 if $_[0] =~ s/%~~\s+([A-Z]+{)/%$1/gos;  # %~~
  $found = 1 if $_[0] =~ s/\s*[\n\r]+~~~\s+/ /gos;   # ~~~
  $found = 1 if $_[0] =~ s/\s*[\n\r]+\*~~\s+//gos;   # *~~
  
  if ($found && $doExpandCommonVariables) {
    # call again to assure expand internal tags get expanded
    $doExpandCommonVariables = 0;
    $_[0] = &TWiki::Func::expandCommonVariables($_[0], $topic, $web);
    $doExpandCommonVariables = 1;
  }
}

# =========================

1;
