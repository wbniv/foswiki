# Plugin for Foswiki - The Free Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2005-2007 Michael Daum http://michaeldaumconsulting.com
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
        $VERSION $RELEASE 
	$NO_PREFS_IN_TOPIC $SHORTDESCRIPTION
    );

$VERSION = '$Rev$';
$RELEASE = '2.00';
$NO_PREFS_IN_TOPIC = 1;
$SHORTDESCRIPTION = 'Enable markup to span multiple lines';

# =========================
sub initPlugin { 
  return 1; 
}

# =========================
# This handler is inefficient. Coding tilde glue into handleCommonTags() would
# be much more efficient. We don't use the beforeCommonTagsHandler
# as we'd loose verbatim handling.
sub commonTagsHandler {
  # apply glue
  $_[0] =~ s/^#~~(.*?)$//gom;  # #~~
  $_[0] =~ s/%~~\s+([A-Z]+[{%])/%$1/gos;  # %~~
  $_[0] =~ s/\s*[\n\r]+~~~\s+/ /gos;   # ~~~
  $_[0] =~ s/\s*[\n\r]+\*~~\s+//gos;   # *~~
}

# =========================

1;
