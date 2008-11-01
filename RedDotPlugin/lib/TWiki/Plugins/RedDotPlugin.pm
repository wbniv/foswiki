# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005-2006 Michael Daum <micha@nats.informatik.uni-hamburg.de>
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
package TWiki::Plugins::RedDotPlugin;
use strict;

###############################################################################
use vars qw(
        $baseWeb $baseTopic $user $installWeb $VERSION $RELEASE
        $styleLink $doneHeader $hasInitRedirector
	$redirectUrl $doneRedirect $query
	%TWikiCompatibility
	$NO_PREFS_IN_TOPIC $SHORTDESCRIPTION
    );


$VERSION = '$Rev$';
$RELEASE = '1.40';
$NO_PREFS_IN_TOPIC = 1;
$SHORTDESCRIPTION = 'Renders edit-links as little red dots';

use constant DEBUG => 0; # toggle me

###############################################################################
sub writeDebug {
  TWiki::Func::writeDebug("- RedDotPlugin - " . $_[0]) if DEBUG;
}

###############################################################################
sub initPlugin {
  ($baseTopic, $baseWeb, $user, $installWeb) = @_;


  my $styleUrl = "%PUBURL%\/$installWeb/RedDotPlugin/style.css";
  $styleLink = 
    '<link rel="stylesheet" href="' . 
    $styleUrl .
    '" type="text/css" media="all" />';

  TWiki::Func::registerTagHandler('REDDOT', \&renderRedDot);
    
  $doneHeader = 0;
  $hasInitRedirector = 0;
  $redirectUrl = '';
  $doneRedirect = 0;
  $query = '';
  
  return 1;
}

###############################################################################
sub commonTagsHandler {

  initRedirector();

  if (!$doneHeader && $_[0] =~ s/<head>(.*?[\r\n]+)/<head>$1$styleLink\n/) {
    $doneHeader = 1;
  }


}

###############################################################################
# TODO don't drop anchors
sub initRedirector {

  return if $hasInitRedirector;
  $hasInitRedirector = 1;

  writeDebug("called initRedirector");

  if (defined $TWiki::RELEASE) {
    return if defined TWiki::Func::getContext()->{'command_line'};
  }

  $query = TWiki::Func::getCgiQuery();
  return unless $query;

  my $theAction = getCgiAction();
  #writeDebug("theAction=$theAction");

  my $sessionKey = "REDDOT_REDIRECT_$baseWeb.$baseTopic";

  # init redirect
  if ($theAction =~ /^edit/) {
    #writeDebug("found edit");
    my $theRedirect = $query->param('redirect');
    if ($theRedirect) {
      #writeDebug("found theRedirect=$theRedirect");
      TWiki::Func::setSessionValue($sessionKey, $theRedirect);
      #writeDebug("init redirect to $theRedirect");
    }
  }

  # execute redirect
  if ($theAction =~ /^(view|save)/) {
    my $theRedirect = $query->param('redirect');
    if ($theAction =~ /^view/) {
      #writeDebug("found view");
      $theRedirect = TWiki::Func::getSessionValue($sessionKey);
      TWiki::Func::clearSessionValue($sessionKey);
    } else {
      #writeDebug("found save");
    }
    if ($theRedirect) {
      #writeDebug("found theRedirect=$theRedirect");
      my $toWeb = $baseWeb;
      my $toTopic = $theRedirect;
      my $toAnchor = '';
      if ($theRedirect =~ /^(.*)\.(.*?)$/) {
	$toWeb = $1;
	$toTopic = $2;
      } 
      if ($toTopic =~ /^(.*)(#.*?)$/) {
	$toTopic = $1;
	$toAnchor = $2;
	#writeDebug("found anchor $toAnchor");
      }
      my $tmp = TWiki::Func::getViewUrl($toWeb,$toTopic) . $toAnchor;
      if ($tmp ne TWiki::Func::getViewUrl($baseWeb,$baseTopic)) {
	$redirectUrl = $tmp; # doit in the redirectCgiQueryHandler
	#writeDebug("redirectUrl=$redirectUrl");
      } else {
	$redirectUrl = '';
      }
    }
  }
}

###############################################################################
sub postRenderingHandler {
  return if $doneRedirect || $redirectUrl eq '' || !$query;
  #writeDebug("called endRenderingHandler()");
  TWiki::Func::redirectCgiQuery($query, $redirectUrl);
}

###############################################################################
sub renderRedDot {
  my ($session, $params, $theTopic, $theWeb) = @_;

  my $theWebTopics = $params->{_DEFAULT} || "$theWeb.$theTopic";
  my $theRedirect = $params->{redirect} || "$baseWeb.$baseTopic";
  my $theText = $params->{text} || '.';
  my $theStyle = $params->{style} || '';
  my $theGrant = $params->{grant} || '.*';

  # find the first webtopic that we have access to
  my $thisWeb;
  my $thisTopic;
  my $hasEditAccess = 0;
  my $wikiName = TWiki::Func::getWikiUserName();

  foreach my $webTopic (split(/, /, $theWebTopics)) {
    #writeDebug("testing webTopic=$webTopic");

    ($thisWeb, $thisTopic) = 
      TWiki::Func::normalizeWebTopicName($baseWeb, $webTopic);

    if (TWiki::Func::topicExists($thisWeb, $thisTopic)) {
      #writeDebug("checking access on $thisWeb.$thisTopic for $wikiName");
      $hasEditAccess = TWiki::Func::checkAccessPermission("CHANGE", 
	$wikiName, undef, $thisTopic, $thisWeb);
      if ($hasEditAccess) {
	$hasEditAccess = 0 unless $wikiName =~ /$theGrant/; 
	# SMELL: use the twiki users and groups functions to check
	# if we are in theGrant
      }
      if ($hasEditAccess) {
	#writeDebug("granted");
	last;
      }
    }
  }

  if (!$hasEditAccess) {
    return '';
  }

  #writeDebug("rendering red dot on $thisWeb.$thisTopic for $wikiName");

  # red dotting
  my $whiteBoard = _getValueFromTopic($thisWeb, $thisTopic, 'WHITEBOARD') || '';
  my $result = 
    '<span class="redDot" ';
  $result .=
    '><a href="'.
    TWiki::Func::getScriptUrl($thisWeb,$thisTopic,'edit').
    '?t=' . time();
  $result .= 
    "&redirect=$theRedirect" if $theRedirect ne "$thisWeb.$thisTopic";
  $result .= 
    '&action=form' if $whiteBoard =~ /off/;
  $result .= '" ';
  $result .= "style=\"$theStyle\" " if $theStyle;
  $result .=
    "title=\"Edit&nbsp;<nop>$thisWeb.$thisTopic\" " .
    ">$theText</a></span>";

  return $result;
}

###############################################################################
# _getValue: my version to get the value of a variable in a topic
sub _getValueFromTopic {
  my ($theWeb, $theTopic, $theKey, $text) = @_;

  if (!$text) {
    my $meta;
    ($meta, $text) = TWiki::Func::readTopic($theWeb, $theTopic);
  }

  foreach my $line (split(/\n/, $text)) {
    if ($line =~ /^(?:\t|\s\s\s)+\*\sSet\s$theKey\s\=\s*(.*)/) {
      my $value = defined $1 ? $1 : "";
      return $value;
    }
  }

  return '';
}

###############################################################################
sub redirectCgiQueryHandler {
  if ($redirectUrl ne '') {
    my ($query, $url) = @_;

    my $scriptUrl = TWiki::Func::getScriptUrl('XXX', 'XXX', 'oops');
    $scriptUrl =~ s/XXX.*$//go;
    #writeDebug("scriptUrl=$scriptUrl");

    if ($url =~ /^$scriptUrl/) {
      #writeDebug("got an oops redirection to $_[1] ... suppressing ours");
    } else {
      #writeDebug("redirecting to $redirectUrl");
      print $query->redirect($redirectUrl);
      $doneRedirect = 1;
    }
  }

  return 0;
}

###############################################################################
# take the REQUEST_URI, strip off the PATH_INFO from the end, the last word
# is the action; this is done that complicated as there may be different
# paths for the same action depending on the apache configuration (rewrites, aliases)
sub getCgiAction {

  my $pathInfo = $ENV{'PATH_INFO'} || '';
  my $theAction = $ENV{'REQUEST_URI'} || '';
  if ($theAction =~ /^.*?\/([^\/]+)$pathInfo.*$/) {
    $theAction = $1;
  } else {
    $theAction = 'view';
  }
  #writeDebug("PATH_INFO=$ENV{'PATH_INFO'}");
  #writeDebug("REQUEST_URI=$ENV{'REQUEST_URI'}");
  #writeDebug("theAction=$theAction");

  return $theAction;
}

1;
