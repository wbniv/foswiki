# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2006-2008 Michael Daum http://michaeldaumconsulting.com
#
# Based on the NatSkinPlugin
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

package TWiki::Plugins::IfDefinedPlugin;

use TWiki::Attrs;
use strict;
use vars qw( 
  $VERSION $RELEASE
  $currentAction 
  $baseWeb $baseTopic
  $currentWeb $currentTopic $currentAction
  $NO_PREFS_IN_TOPIC $SHORTDESCRIPTION
);

$VERSION = '$Rev$';
$RELEASE = 'v1.02';
$NO_PREFS_IN_TOPIC = 1;
$SHORTDESCRIPTION = 'Render content conditionally';

use constant DEBUG => 0; # toggle me

###############################################################################
sub writeDebug {
  print STDERR '- IfDefinedPlugin - '.$_[0]."\n" if DEBUG;
}

###############################################################################
sub initPlugin {
  ($baseTopic, $baseWeb) = @_;

  $currentAction = undef;
  return 1;
}

###############################################################################
sub commonTagsHandler {
# $_[0]: $text, $_[1]: $topic, $_[2]: $web
  $currentWeb = $_[2];
  $currentTopic = $_[1];
  $currentAction = '';

  $_[0] =~ s/(\s*)%IFDEFINED{(.*?)}%(\s*)/&handleIfDefined($2, $1, $3)/geos;
  $_[0] =~ s/(\s*)%IFACCESS%(\s*)/&handleIfAccess(undef, $1, $2)/geos;
  $_[0] =~ s/(\s*)%IFACCESS{(.*?)}%(\s*)/&handleIfAccess($2, $1, $3)/geos;
  $_[0] =~ s/(\s*)%IFEXISTS{(.*?)}%(\s*)/&handleIfExists($2, $1, $3)/geos;
  while ($_[0] =~ s/(\s*)%IFDEFINEDTHEN{(?!.*%IFDEFINEDTHEN)(.*?)}%(.*?)%FIDEFINED%(\s*)/&handleIfDefinedThen($2, $3, $1, $4)/geos) {
    # nop
  }
}

###############################################################################
sub handleIfDefined {
  my ($args, $before, $after) = @_;

  #writeDebug("called handleIfDefined($args)");

  $args ||= '';
  my $params = new TWiki::Attrs($args);
  my $theVariable = $params->{_DEFAULT};
  my $theAction = $params->{action} || '';
  my $theThen = $params->{then};
  my $theElse = $params->{else} || '';
  my $theGlue = $params->{glue} || 'on';
  my $theAs = $params->{as};

  $theVariable = '' unless defined $theVariable;
  $theAs = '.+' unless defined $theAs;
  $theThen = $theVariable unless defined $theThen;

  &escapeParameter($theThen);
  &escapeParameter($theElse);

  return &ifDefinedImpl(
    $theVariable, $theAction, $theThen, $theElse, undef, $before, $after,
    $theGlue, $theAs);
}

###############################################################################
sub handleIfDefinedThen {
  my ($args, $text, $before, $after) = @_;

  #writeDebug("called handleIfDefinedThen($args)");

  $args ||= '';
  my $params = new TWiki::Attrs($args);
  my $theVariable = $params->{_DEFAULT};
  my $theAction = $params->{action} || '';
  my $theGlue = $params->{glue} || 'on'; 
  my $theAs = $params->{as};

  $theVariable = '' unless defined $theVariable;
  $theAs = '.+' unless defined $theAs;

  my $theThen = $text; 
  my $theElse = '';
  my $elsIfArgs = '';
  if ($text =~ /^(.*?)\s*%ELSIFDEFINED{(.*?)}%(.*)$/gos) {
    $theThen = $1;
    $elsIfArgs = $2;
    $theElse = $3;
  } elsif ($text =~ /^(.*?)\s*%ELSEDEFINED%(.*)$/gos) {
    $theThen = $1;
    $theElse = $2;
  }

  return &ifDefinedImpl(
    $theVariable, $theAction, $theThen, $theElse, $elsIfArgs, $before, $after,
    $theGlue, $theAs);
}


###############################################################################
sub ifDefinedImpl {
  my ($theVariable, $theAction, $theThen, $theElse, $theElsIfArgs, $before, $after, $theGlue, $theAs) = @_;

  #writeDebug("called ifDefinedImpl()");
  #writeDebug("theVariable='$theVariable'");
  #writeDebug("theAction='$theAction'");
  #writeDebug("theThen='$theThen'");
  #writeDebug("theElse='$theElse'");
  #writeDebug("theElsIfArgs='$theElsIfArgs'") if $theElsIfArgs;
  #writeDebug("theAs='$theAs'");
  
  $before = '' if ($theGlue eq 'on') || !$before;
  $after = '' if ($theGlue eq 'on') || !$after;

  if(&escapeParameter($theVariable)) {
    $theVariable = TWiki::Func::expandCommonVariables($theVariable, $currentTopic, $currentWeb);
  }
  if(&escapeParameter($theAs)) {
    $theAs = TWiki::Func::expandCommonVariables($theAs, $currentTopic, $currentWeb);
  }

  unless (defined $currentAction) {
    $currentAction = getRequestAction();
  }

  if (!$theAction || $currentAction =~ /$theAction/) {
    if ($theVariable =~ /^%([A-Za-z][A-Za-z0-9_]*)%$/) {
      $theVariable = '';
    }
    if ($theVariable =~ /^($theAs)$/s) {
      if ($theThen =~ s/\$nop//go) {
	$theThen = TWiki::Func::expandCommonVariables($theThen, $currentTopic, $currentWeb);
      }
      $theThen =~ s/\$(test|variable)/$theVariable/g;
      $theThen =~ s/\$value/$theAs/g;
      return $before.$theThen.$after;
    }
  }
  
  return $before."%IFDEFINEDTHEN{$theElsIfArgs}%$theElse%FIDEFINED%".$after if $theElsIfArgs;

  if ($theElse =~ s/\$nop//go) {
    $theElse = TWiki::Func::expandCommonVariables($theElse, $currentTopic, $currentWeb);
  }

  $theElse =~ s/\$test/$theVariable/g;
  $theElse =~ s/\$value/$theAs/g;
  return $before.$theElse.$after; # variable is empty
}

###############################################################################
sub handleIfExists {
  my ($args, $before, $after) = @_;

  $args ||= '';
  my $params = new TWiki::Attrs($args);
  my $theGlue = $params->{glue} || 'on';
  my $theWebTopic = $params->{_DEFAULT} || $params->{topic} || "$currentWeb.$currentTopic";
  my $theThen = $params->{then};
  my $theElse = $params->{else};
  
  $theThen = 1 unless defined $theThen;
  $theElse = 0 unless defined $theElse;

  my ($thisWeb, $thisTopic) = TWiki::Func::normalizeWebTopicName($currentWeb, $theWebTopic);
  my $doesExist = TWiki::Func::topicExists($thisWeb, $thisTopic);
  my $result = ($doesExist)?$theThen:$theElse;

  $result = TWiki::Func::expandCommonVariables($result, $currentTopic, $currentWeb)  
    if &escapeParameter($result, web=>$thisWeb, topic=>$thisTopic);

  $before = '' if ($theGlue eq 'on') || !$before;
  $after = '' if ($theGlue eq 'on') || !$after;

  return $before.$result.$after;
}

###############################################################################
sub handleIfAccess {
  my ($args, $before, $after) = @_;

  #writeDebug("called handleIfAccess($args)");
  $args ||= '';
  my $params = new TWiki::Attrs($args);
  my $theWebTopic = $params->{_DEFAULT} || $params->{topic} || $currentTopic;
  my $theType = $params->{type} || 'view';
  my $theUser = $params->{user} || TWiki::Func::getWikiName();
  my $theThen = $params->{then};
  my $theElse = $params->{else};
  my $theGlue = $params->{glue} || 'on';

  $theThen = 1 unless defined $theThen;
  $theElse = 0 unless defined $theElse;

  $theType = 'change' if $theType =~ /^edit$/i;

  my ($thisWeb, $thisTopic) = TWiki::Func::normalizeWebTopicName($currentWeb, $theWebTopic);
  my $hasAccess = TWiki::Func::checkAccessPermission($theType, $theUser, undef, $thisTopic, $thisWeb);

  #writeDebug("hasAccess=$hasAccess");
  #writeDebug("theUser=$theUser hasAccess=$hasAccess thisWeb=$thisWeb thisTopic=$thisTopic");

  my $result = ($hasAccess)?$theThen:$theElse;

  $result = TWiki::Func::expandCommonVariables($result, $currentTopic, $currentWeb) 
    if &escapeParameter($result, web=>$thisWeb, topic=>$thisTopic);

  #writeDebug("result=$result");

  $before = '' if ($theGlue eq 'on') || !$before;
  $after = '' if ($theGlue eq 'on') || !$after;

  return $before.$result.$after;
}

###############################################################################
sub escapeParameter {
  my (undef, %params) = @_;
  return 0 unless $_[0];

  my $found = 0;
  foreach my $key (keys %params) {
    if ($_[0] =~ s/\$$key\b/$params{$key}/g) {
      $found = 1;
      print STDERR "found key=$key, value=$params{$key}\n";
    }
  }

  $found = 1 if $_[0] =~ s/\$percnt/%/g;
  $found = 1 if $_[0] =~ s/\$nop//g;
  $found = 1 if $_[0] =~ s/\\n/\n/g;
  $found = 1 if $_[0] =~ s/\$n/\n/g;
  $found = 1 if $_[0] =~ s/\\%/%/g;
  $found = 1 if $_[0] =~ s/\$dollar/\$/g;

  return $found;
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

###############################################################################
1;
