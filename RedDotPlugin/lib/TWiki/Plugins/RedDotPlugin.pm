# Plugin for Foswiki - The Free Open Source Wiki, http://foswiki.org/
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
        $baseWeb $baseTopic $user $VERSION $RELEASE
        $header $doneHeader $currentAction
	%TWikiCompatibility $counter
	$NO_PREFS_IN_TOPIC $SHORTDESCRIPTION
    );


$VERSION = '$Rev$';
$RELEASE = '1.41';
$NO_PREFS_IN_TOPIC = 1;
$SHORTDESCRIPTION = 'Renders edit-links as little red dots';

use constant DEBUG => 0; # toggle me

$header = <<'HERE';
<link rel="stylesheet" href="%PUBURLPATH%/%SYSTEMWEB%/RedDotPlugin/style.css" type="text/css" media="all" />
HERE

###############################################################################
sub writeDebug {
  #TWiki::Func::writeDebug("- RedDotPlugin - " . $_[0]) if DEBUG;
  print STDERR "- RedDotPlugin - " . $_[0] . "\n" if DEBUG;
}

###############################################################################
sub initPlugin {
  ($baseTopic, $baseWeb, $user) = @_;


  TWiki::Func::registerTagHandler('REDDOT', \&renderRedDot);
    
  $doneHeader = 0;
  $counter = 0;
  $baseWeb =~ s/\//\./go;
  $currentAction = '';

  return 1;
}

###############################################################################
sub commonTagsHandler {

  return if $doneHeader;
  $doneHeader = 1 if $_[0] =~ s/<head>(.*?[\r\n]+)/<head>$1$header/o;
}

###############################################################################
sub renderRedDot {
  my ($session, $params, $theTopic, $theWeb) = @_;

  writeDebug("called renderRedDot($theWeb, $theTopic), parms=".$params->stringify);

  my $theAction = getRequestAction();
  return '' unless $theAction =~ /^view/; 

  my $theWebTopics = $params->{_DEFAULT} || "$theWeb.$theTopic";
  my $theRedirect = $params->{redirect};
  my $theText = $params->{text} || '.';
  my $theStyle = $params->{style} || '';
  my $theGrant = $params->{grant} || '.*';

  my $query = TWiki::Func::getCgiQuery();
  unless ($theRedirect) {
    my $queryString = $query->query_string;
    $theRedirect = TWiki::Func::getScriptUrl($baseWeb, $baseTopic).
      '?'.$queryString.
      "#reddot$counter";
  }

  # find the first webtopic that we have access to
  my $thisWeb;
  my $thisTopic;
  my $hasEditAccess = 0;
  my $wikiName = TWiki::Func::getWikiName();

  foreach my $webTopic (split(/\s*,\s*/, $theWebTopics)) {
    #writeDebug("testing webTopic=$webTopic");

    ($thisWeb, $thisTopic) = 
      TWiki::Func::normalizeWebTopicName($baseWeb, $webTopic);
    $thisWeb =~ s/\//\./go;

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
  my $whiteBoard = '';#_getValueFromTopic($thisWeb, $thisTopic, 'WHITEBOARD') || '';
  my $result = 
    '<span class="redDot" ';
  $result .=
    '><a name="reddot'.($counter++).'" '.
    'href="'.
    TWiki::Func::getScriptUrl($thisWeb,$thisTopic,'edit', 't'=>time());
  $result .= 
    "&redirectto=".urlEncode($theRedirect) if $theRedirect ne "$thisWeb.$thisTopic";
  $result .= 
    '&action=form' if $whiteBoard =~ /off/;
  $result .= '" ';
  $result .= "style=\"$theStyle\" " if $theStyle;
  $result .=
    "title=\"Edit&nbsp;<nop>$thisWeb.$thisTopic\" " .
    ">$theText</a></span>";

  writeDebug("done renderRedDot");

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
sub urlEncode {
  my $text = shift;

  $text =~ s/([^0-9a-zA-Z-_.:~!*'()\/%])/'%'.sprintf('%02x',ord($1))/ge;

  return $text;
}

###############################################################################
# take the REQUEST_URI, strip off the PATH_INFO from the end, the last word
# is the action; this is done that complicated as there may be different
# paths for the same action depending on the apache configuration (rewrites, aliases)
sub getRequestAction {

  return $currentAction if $currentAction;

  my $request = TWiki::Func::getCgiQuery();

  if (defined($request->action)) {
    $currentAction = $request->action();
  } else {
    my $context = TWiki::Func::getContext();

    # not all cgi actions we want to distinguish set their context
    # so only use those we are sure of
    return 'edit' if $context->{'edit'};
    return 'view' if $context->{'view'};
    return 'save' if $context->{'save'};
    # TODO: more

    # fall back to analyzing the path info
    my $pathInfo = $ENV{'PATH_INFO'} || '';
    $currentAction = $ENV{'REQUEST_URI'} || '';
    if ($currentAction =~ /^.*?\/([^\/]+)$pathInfo.*$/) {
      $currentAction = $1;
    } else {
      $currentAction = 'view';
    }
    #writeDebug("PATH_INFO=$ENV{'PATH_INFO'}");
    #writeDebug("REQUEST_URI=$ENV{'REQUEST_URI'}");
    #writeDebug("currentAction=$currentAction");

  }

  return $currentAction;
}

1;
