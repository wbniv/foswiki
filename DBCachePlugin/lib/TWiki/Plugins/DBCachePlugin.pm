# Plugin for Foswiki - The Free Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2005-2008 Michael Daum http://michaeldaumconsulting.com
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

#use Monitor;
#Monitor::MonitorMethod('TWiki::Contrib::DBCachePlugin');
#Monitor::MonitorMethod('TWiki::Contrib::DBCachePlugin::Core');
#Monitor::MonitorMethod('TWiki::Contrib::DBCachePlugin::WebDB');

use strict;
use vars qw( 
  $VERSION $RELEASE $SHORTDESCRIPTION $NO_PREFS_IN_TOPIC
  $baseWeb $baseTopic $isInitialized
  $addDependency
);

$VERSION = '$Rev$';
$RELEASE = '2.02';
$NO_PREFS_IN_TOPIC = 1;
$SHORTDESCRIPTION = 'Lightweighted frontend to the DBCacheContrib';

###############################################################################
# plugin initializer
sub initPlugin {
  ($baseTopic, $baseWeb) = @_;

  # check for Plugins.pm versions
  if ($TWiki::Plugins::VERSION < 1.1) {
    return 0;
  }
  
  TWiki::Func::registerTagHandler('DBQUERY', \&DBQUERY);
  TWiki::Func::registerTagHandler('DBCALL', \&DBCALL);
  TWiki::Func::registerTagHandler('DBSTATS', \&DBSTATS);
  TWiki::Func::registerTagHandler('DBDUMP', \&DBDUMP); # for debugging
  TWiki::Func::registerTagHandler('DBRECURSE', \&DBRECURSE);
  TWiki::Func::registerTagHandler('ATTACHMENTS', \&ATTACHMENTS);
  TWiki::Func::registerTagHandler('TOPICTITLE', \&TOPICTITLE);
  TWiki::Func::registerTagHandler('GETTOPICTITLE', \&TOPICTITLE);

  TWiki::Func::registerRESTHandler('UpdateCache', \&updateCache );

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

  TWiki::Plugins::DBCachePlugin::Core::init($baseWeb, $baseTopic);
}

###############################################################################
# REST handler to allow offline cache updates 
sub updateCache {
  my $session = shift;
  my $web = $session->{webName};

  my $db = getDB($web);
  $db->load(1) if $db;
}

###############################################################################
# after save handlers
sub afterSaveHandler {
  initCore();
  return TWiki::Plugins::DBCachePlugin::Core::afterSaveHandler(@_);
}

###############################################################################
sub renderWikiWordHandler {
  initCore();
  return TWiki::Plugins::DBCachePlugin::Core::renderWikiWordHandler(@_);
}

###############################################################################
# tags
sub DBQUERY {
  initCore();
  return TWiki::Plugins::DBCachePlugin::Core::handleDBQUERY(@_);
}
sub DBCALL {
  initCore();
  return TWiki::Plugins::DBCachePlugin::Core::handleDBCALL(@_);
}
sub DBSTATS {
  initCore();
  return TWiki::Plugins::DBCachePlugin::Core::handleDBSTATS(@_);
}
sub DBDUMP {
  initCore();
  return TWiki::Plugins::DBCachePlugin::Core::handleDBDUMP(@_);
}
sub ATTACHMENTS {
  initCore();
  return TWiki::Plugins::DBCachePlugin::Core::handleATTACHMENTS(@_);
}
sub DBRECURSE {
  initCore();
  return TWiki::Plugins::DBCachePlugin::Core::handleDBRECURSE(@_);
}
sub TOPICTITLE {
  initCore();
  return TWiki::Plugins::DBCachePlugin::Core::handleTOPICTITLE(@_);
}

###############################################################################
# perl api
sub getDB {
  initCore();
  return TWiki::Plugins::DBCachePlugin::Core::getDB(@_);
}
sub getTopicTitle {
  initCore();
  return TWiki::Plugins::DBCachePlugin::Core::getTopicTitle(@_);
}

###############################################################################
# SMELL: remove this when TWiki::Cache got into the core
sub nullHandler { }
sub addDependencyHandler {
  return $TWiki::Plugins::SESSION->{cache}->addDependency(@_);
}

###############################################################################
1;
