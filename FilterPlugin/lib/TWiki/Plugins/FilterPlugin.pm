# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2005-2008 Michael Daum http://michaeldaumconsulting.com
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
package TWiki::Plugins::FilterPlugin;
use strict;

###############################################################################
use vars qw(
        $currentWeb $currentTopic $VERSION $RELEASE
	$NO_PREFS_IN_TOPIC $SHORTDESCRIPTION
        $doneInitCore
    );

$VERSION = '$Rev$';
$RELEASE = '1.70';
$NO_PREFS_IN_TOPIC = 1;
$SHORTDESCRIPTION = 'Substitute and extract information from content by using regular expressions';

###############################################################################
sub initPlugin {
  ($currentTopic, $currentWeb) = @_;

  TWiki::Func::registerTagHandler('FORMATLIST', \&handleFormatList);
  TWiki::Func::registerTagHandler('MAKEINDEX', \&handleMakeIndex);
  TWiki::Func::registerTagHandler('SUBST', \&handleSubst);
  TWiki::Func::registerTagHandler('EXTRACT', \&handleExtract);

  $doneInitCore = 0;
  return 1;
}

###############################################################################
sub commonTagsHandler {
  while($_[0] =~ s/%STARTSUBST{(?!.*%STARTSUBST)(.*?)}%(.*?)%STOPSUBST%/&handleFilterArea($1, 1, $2)/ges) {
    # nop
  }
  while($_[0] =~ s/%STARTEXTRACT{(?!.*%STARTEXTRACT)(.*?)}%(.*?)%STOPEXTRACT%/&handleFilterArea($1, 0, $2)/ges) {
    # nop
  }
}

###############################################################################
sub initCore {

  return if $doneInitCore;
  $doneInitCore = 1;

  eval 'use TWiki::Plugins::FilterPlugin::Core;';
  die $@ if $@;

  TWiki::Plugins::FilterPlugin::Core::init($currentWeb, $currentTopic);
}

###############################################################################
sub handleFilterArea {
  initCore();
  return TWiki::Plugins::FilterPlugin::Core::handleFilterArea(@_);
}

###############################################################################
sub handleFormatList {
  initCore();
  return TWiki::Plugins::FilterPlugin::Core::handleFormatList(@_);
}

###############################################################################
sub handleMakeIndex {
  initCore();
  return TWiki::Plugins::FilterPlugin::Core::handleMakeIndex(@_);
}

###############################################################################
sub handleSubst {
  initCore();
  return TWiki::Plugins::FilterPlugin::Core::handleSubst(@_);
}

###############################################################################
sub handleExtract {
  initCore();
  return TWiki::Plugins::FilterPlugin::Core::handleExtract(@_);
}

1;
