# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006 MichaelDaum@WikiRing.com
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

package TWiki::Plugins::PingBackPlugin;

use strict;
use vars qw( $VERSION $RELEASE $NO_PREFS_IN_TOPIC $SHORTDESCRIPTION
  $currentWeb $currentTopic $currentUser $xmlRpcLink $doneHeader
  $enabledPingBack $debug $doneInit
);

$VERSION = '$Rev$';
$RELEASE = 'v0.05-alpha';
$NO_PREFS_IN_TOPIC = 1;
$SHORTDESCRIPTION = 'Pingback service for TWiki';
$debug = 0; # toggle me

use TWiki::Contrib::XmlRpcContrib;

###############################################################################
sub writeDebug {
  print STDERR "- PingBackPlugin - " . $_[0] . "\n" if $debug;
}

###############################################################################
sub initPlugin {
  ($currentTopic, $currentWeb, $currentUser) = @_;

  # check for Plugins.pm versions
  if ($TWiki::Plugins::VERSION < 1.026) {
    TWiki::Func::writeWarning( "Version mismatch between PingBackPlugin and Plugins.pm" );
    return 0;
  }
  $doneHeader = 0;
  $doneInit = 0;
  TWiki::Func::registerTagHandler('PINGBACK', \&handlePingbackTag);
  TWiki::Contrib::XmlRpcContrib::registerRPCHandler('pingback.ping', \&handlePingbackCall);

  my $xmlRpcUrl = TWiki::Func::getScriptUrl($currentWeb, $currentTopic, 'xmlrpc');
  $xmlRpcLink = "<link rel=\"pingback\" href=\"$xmlRpcUrl\" />";

  # Plugin correctly initialized
  return 1;
}

###############################################################################
sub doInit {
  return if $doneInit;
  $doneInit = 1;
  $enabledPingBack = TWiki::Func::getPreferencesFlag('ENABLEPINGBACK') || 0;
}

###############################################################################
sub isPingBackEnabled {
  doInit();
  return $enabledPingBack;
}

###############################################################################
# we can't use addToHEAD as the pingback specification to autodetect the
# server only demands the link to be within the first 5KB. So some sources
# might not detect the xmlrpc service if we add the pingback relation th the
# _end_ of the <head>...</head> section rather than to the start
sub commonTagsHandler {

  if (isPingBackEnabled()) {
    if (!$doneHeader && $_[0] =~ s/<head>(.*?[\r\n]+)/<head>$1$xmlRpcLink\n/o) {
      $doneHeader = 1;
    }
  }
  $_[0] =~ s/%(START|STOP)PINGBACK%//go;
}

###############################################################################
sub afterSaveHandler {
  ### my ( $text, $topic, $web, $error, $meta ) = @_;

  eval 'use TWiki::Plugins::PingBackPlugin::Core';
  die $@ if $@;

  return TWiki::Plugins::PingBackPlugin::Core::afterSaveHandler(@_);
}

###############################################################################
sub handlePingbackTag {

  eval 'use TWiki::Plugins::PingBackPlugin::Core';
  die $@ if $@;

  my $result = TWiki::Plugins::PingBackPlugin::Core::handlePingbackTag(@_);
  writeDebug("result=$result");
  return $result;
}

###############################################################################
sub handlePingbackCall {

  eval 'use TWiki::Plugins::PingBackPlugin::Core';
  die $@ if $@;

  return TWiki::Plugins::PingBackPlugin::Core::handlePingbackCall(@_);
}

1;
