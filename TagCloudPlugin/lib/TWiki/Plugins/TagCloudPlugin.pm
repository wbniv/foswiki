# Plugin for Foswiki - The Free Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006 Michael Daum <micha@nats.informatik.uni-hamburg.de>
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
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

package TWiki::Plugins::TagCloudPlugin;

use strict;
use vars qw(
  $VERSION $RELEASE $SHORTDESCRIPTION $NO_PREFS_IN_TOPIC 
  $isInitialized
);

$VERSION = '$Rev$';
$RELEASE = 'v1.01';
$NO_PREFS_IN_TOPIC = 1;
$SHORTDESCRIPTION = 'Renders a tag cloud given a list of terms';

###############################################################################
sub initPlugin {
  #my ($topic, $web, $user, $installWeb) = @_;

  # check for Plugins.pm versions
  if ($TWiki::Plugins::VERSION < 1.1) {
    return 0;
  }

  TWiki::Func::registerTagHandler('TAGCLOUD', \&_TAGCLOUD);
  $isInitialized = 0;

  return 1;
}

###############################################################################
sub _TAGCLOUD {
  #my($session, $params, $theTopic, $theWeb) = @_;

  unless ($isInitialized) {
    eval 'use TWiki::Plugins::TagCloudPlugin::Core;';
    die $@ if $@;
    $isInitialized = 1;
  }
  return TWiki::Plugins::TagCloudPlugin::Core::handleTagCloud(@_);
}

###############################################################################

1;
