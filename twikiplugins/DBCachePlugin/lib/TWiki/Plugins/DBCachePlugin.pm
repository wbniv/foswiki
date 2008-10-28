# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005-2007 Michael Daum http://wikiring.de
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

package TWiki::Plugins::DBCachePlugin;

use strict;
use vars qw( 
  $VERSION $RELEASE $SHORTDESCRIPTION $NO_PREFS_IN_TOPIC
  $currentWeb $currentTopic $currentUser $isInitialized
  $addDependency
);

$VERSION = '$Rev$';
$RELEASE = '1.61';
$NO_PREFS_IN_TOPIC = 1;
$SHORTDESCRIPTION = 'Lightweighted frontend to the DBCacheContrib';

###############################################################################
# plugin initializer
sub initPlugin {
  ($currentTopic, $currentWeb, $currentUser) = @_;

  # check for Plugins.pm versions
  if ($TWiki::Plugins::VERSION < 1.1) {
    return 0;
  }
  
  TWiki::Func::registerTagHandler('DBQUERY', \&_DBQUERY);
  TWiki::Func::registerTagHandler('DBCALL', \&_DBCALL);
  TWiki::Func::registerTagHandler('DBSTATS', \&_DBSTATS);
  TWiki::Func::registerTagHandler('DBDUMP', \&_DBDUMP); # for debugging
  TWiki::Func::registerTagHandler('DBRECURSE', \&_DBRECURSE);
  TWiki::Func::registerTagHandler('ATTACHMENTS', \&_ATTACHMENTS);

  # SMELL: remove this when TWiki::Cache got into the core
  if (defined $TWiki::Plugins::SESSION->{cache}) {
    $addDependency = \&addDependencyHandler;
  } else {
    $addDependency = \&nullHandler;
  }

  $isInitialized = 0;

  return 1;
}

###############################################################################
sub initCore {
  return if $isInitialized;
  $isInitialized = 1;

  eval 'use TWiki::Plugins::DBCachePlugin::Core;';
  die $@ if $@;

  # We don't initialize the webDB hash on every request, see getDB()!
  if (0) { # set this to 1 if you like
    #&TWiki::Plugins::DBCachePlugin::Core::DESTROY_ALL();
  } else {
    # at least check for a changed _DB file on every turn
    %TWiki::Plugins::DBCachePlugin::Core::webDBIsModified = ();
  }

  $TWiki::Plugins::DBCachePlugin::Core::wikiWordRegex = 
    TWiki::Func::getRegularExpression('wikiWordRegex');
  $TWiki::Plugins::DBCachePlugin::Core::webNameRegex = 
    TWiki::Func::getRegularExpression('webNameRegex');
  $TWiki::Plugins::DBCachePlugin::Core::defaultWebNameRegex = 
    TWiki::Func::getRegularExpression('defaultWebNameRegex');
  $TWiki::Plugins::DBCachePlugin::Core::linkProtocolPattern = 
    TWiki::Func::getRegularExpression('linkProtocolPattern');
}

###############################################################################
# twiki handlers
sub afterSaveHandler {
  initCore();
  return TWiki::Plugins::DBCachePlugin::Core::afterSaveHandler(@_);
}

###############################################################################
# tags
sub _DBQUERY {
  initCore();
  return TWiki::Plugins::DBCachePlugin::Core::handleDBQUERY(@_);
}
sub _DBCALL {
  initCore();
  return TWiki::Plugins::DBCachePlugin::Core::handleDBCALL(@_);
}
sub _DBSTATS {
  initCore();
  return TWiki::Plugins::DBCachePlugin::Core::handleDBSTATS(@_);
}
sub _DBDUMP {
  initCore();
  return TWiki::Plugins::DBCachePlugin::Core::handleDBDUMP(@_);
}
sub _ATTACHMENTS {
  initCore();
  return TWiki::Plugins::DBCachePlugin::Core::handleATTACHMENTS(@_);
}
sub _DBRECURSE {
  initCore();
  return TWiki::Plugins::DBCachePlugin::Core::handleDBRECURSE(@_);
}

###############################################################################
# perl api
sub getDB {
  initCore();
  return TWiki::Plugins::DBCachePlugin::Core::getDB(@_);
}

###############################################################################
# SMELL: remove this when TWiki::Cache got into the core
sub nullHandler { }
sub addDependencyHandler {
  return $TWiki::Plugins::SESSION->{cache}->addDependency(@_);
}

###############################################################################
1;
