# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2006-2008 Michael Daum http://michaeldaumconsulting.com
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

package TWiki::Plugins::BreadCrumbsPlugin;

use strict;
use vars qw(
  $VERSION $RELEASE $NO_PREFS_IN_TOPIC $SHORTDESCRIPTION $doneInit
);

$VERSION = '$Rev$';
$RELEASE = 'v2.01';
$NO_PREFS_IN_TOPIC = 1;
$SHORTDESCRIPTION = 'A flexible way to display breadcrumbs navigation';

###############################################################################
sub initPlugin {

  TWiki::Func::registerTagHandler('BREADCRUMBS', \&renderBreadCrumbs);

  my $doRecordTrail = TWiki::Func::getPreferencesValue('BREADCRUMBSPLUGIN_RECORDTRAIL') || '';
  $doRecordTrail = ($doRecordTrail eq 'on')?1:0;

  if ($doRecordTrail) {
    init();
    TWiki::Plugins::BreadCrumbsPlugin::Core::recordTrail($_[1], $_[0]);
  } else {
    #print STDERR "not recording the click path trail\n";
  }

  return 1;
}

###############################################################################
sub init {
  return if $doneInit;
  $doneInit = 1;
  require TWiki::Plugins::BreadCrumbsPlugin::Core;
  TWiki::Plugins::BreadCrumbsPlugin::Core::init(@_);
}

###############################################################################
sub renderBreadCrumbs {
  init();
  return TWiki::Plugins::BreadCrumbsPlugin::Core::renderBreadCrumbs(@_);
}

1;
