# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006 Michael Daum http://wikiring.com
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

package TWiki::Plugins::MediaWikiTablePlugin;

use strict;
use vars qw(
  $VERSION $RELEASE $NO_PREFS_IN_TOPIC $SHORTDESCRIPTION
  $doneHeader $isInitialized
);

$VERSION = '$Rev$';
$RELEASE = 'v1.01';
$NO_PREFS_IN_TOPIC = 1;
$SHORTDESCRIPTION = 'Format tables the <nop>MediaWiki way';

###############################################################################
sub initPlugin { 
  $isInitialized = 0;
  $doneHeader = 0;
  return 1; 
}

###############################################################################
sub commonTagsHandler {
# text, topic, web
  handleMWTable($_[2], $_[1], $_[0]) if $_[0] =~ /(^|[\n\r])\s*{\|/;

  return if $doneHeader;
  my $link = 
    '<link rel="stylesheet" '.
    'href="%PUBURL%/%SYSTEMWEB%/MediaWikiTablePlugin/style.css" '.
    'type="text/css" media="all" />';
  if ($_[0] =~ s/<head>(.*?[\r\n]+)/<head>$1$link\n/o) {
    $doneHeader = 1;
  }
}

###############################################################################
sub handleMWTable {
  unless ($isInitialized) {
    eval 'use TWiki::Plugins::MediaWikiTablePlugin::Core;';
    die $@ if $@;
    $isInitialized = 1;
  }
  return TWiki::Plugins::MediaWikiTablePlugin::Core::handleMWTable(@_);
}

1;
