# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2003 Othello Maurer <maurer@nats.informatik.uni-hamburg.de>
# Copyright (C) 2003-2007 Michael Daum http://michaeldaumconsulting.com
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
# =========================
package TWiki::Plugins::AliasPlugin;    # change the package name and $pluginName!!!

use strict;
use vars qw(
        $currentWeb $currentTopic $VERSION $RELEASE
        %aliasRegex %aliasValue %substHash
	$aliasWikiWordsOnly
	%seenAliasWebTopics $wordRegex $wikiWordRegex $topicRegex $webRegex
	$defaultWebNameRegex
	$foundError $isInitialized $insideAliasArea
	$TranslationToken $foundAliases
	%TWikiCompatibility $START $STOP
        $NO_PREFS_IN_TOPIC $SHORTDESCRIPTION
    );


$VERSION = '$Rev: 16746 $';
$RELEASE = '2.31';
$SHORTDESCRIPTION = 'Define aliases which will be replaced with arbitrary strings automatically';
$NO_PREFS_IN_TOPIC = 1;

$START = '(?:^|(?<=[\w\b\s\,\.\;\:\!\?\)\(]))';
$STOP = '(?:$|(?=[\w\b\s\,\.\;\:\!\?\)\(]))';
$TranslationToken= "\0\1\0";
$TWikiCompatibility{endRenderingHandler} = 1.1;
$TWikiCompatibility{outsidePREHandler} = 1.1;

use constant DEBUG => 0; # toggle me

# =========================
sub writeDebug {
  print STDERR "AliasPlugin - ".$_[0]."\n" if DEBUG;
}

# =========================
sub initPlugin {
  ($currentTopic, $currentWeb) = @_;

  # more in doInit if we actually have an alias area
  $isInitialized = 0;
  %seenAliasWebTopics = ();
  $insideAliasArea = 0;
  $foundError = 0;

  return 1;
}

# =========================
sub doInit {

  return if $isInitialized;
  $isInitialized = 1;
  writeDebug("doinit() called");

  # get plugin flags
  $aliasWikiWordsOnly = 
    TWiki::Func::getPreferencesFlag("ALIASPLUGIN_ALIAS_WIKIWORDS_ONLY") || 0;
  
  # decide on how to match alias words
  $wikiWordRegex = &TWiki::Func::getRegularExpression('wikiWordRegex');
  $topicRegex = &TWiki::Func::getRegularExpression('mixedAlphaNumRegex');
  $webRegex = &TWiki::Func::getRegularExpression('webNameRegex');
  $defaultWebNameRegex = &TWiki::Func::getRegularExpression('defaultWebNameRegex');

  if ($aliasWikiWordsOnly) {
    $wordRegex = $wikiWordRegex;
  } else {
    $wordRegex = '\w+';
  }

  # init globals
  $foundAliases = 0;
  %aliasRegex = ();
  %aliasValue = ();

  # look for aliases in Main or TWiki web
  my $web = TWiki::Func::getMainWebname();
  my $topic = 'WebAliases';
  unless (getAliases($web, $topic)) {
    $web = TWiki::Func::getTwikiWebname();
    $topic = 'WebAliases';
    getAliases($web, $topic);
  }

  # look for aliases in current web
  $web = $currentWeb;
  $topic = 'WebAliases';
  getAliases($web, $topic);
}


# =========================
sub commonTagsHandler {
  # ($text, $topic, $web, $included, $meta ) = @_;

  # order matters. example: UNALIAS -> dump all ALIAS -> add one alias
  $_[0] =~ s/%(ALIAS|ALIASES|UNALIAS)(?:{(.*)?})?%/&handleAllAliasCmds($_[2], $_[1], $1, $2)/ge;
}

# =========================
sub preRenderingHandler {

  doInit();
  return unless $foundAliases;

  writeDebug("### preRenderingHandler()");
  my $result = '';
  my $text = $_[0];
  my @areas = split(/%(START|STOP)ALIASAREA%/, $text);
  foreach my $area (@areas) {
    if ($area eq 'START') {
      $insideAliasArea = 1;
      next;
    }
    if ($area eq 'STOP' ) {
      $insideAliasArea = 0;
      next;
    }
    #writeDebug("insideAliasArea=$insideAliasArea, area='$area'");
    $area = handleAliasArea($area) if $insideAliasArea;
    $result .= $area;
  }

  $_[0] = $result;
}

# =========================
sub postRenderingHandler {
  $_[0] =~ s/%(START|STOP)ALIASAREA%//go;
}

# =========================
sub handleAllAliasCmds {
  my ($web, $topic, $name, $args) = @_;

  #writeDebug("handleAllAliasCmds($name)");
  doInit(); # delayed initialization

  return handleAlias($web, $topic, $args) if $name eq 'ALIAS';
  return handleAliases($web, $topic, $args) if $name eq 'ALIASES';
  return handleUnAlias($web, $topic, $args) if $name eq 'UNALIAS';
  return '<font color=\"red\">Error: never reach ...</font>';
}

# =========================
sub handleAliases {
  my ($web, $topic, $args) = @_;

  $args ||= '';
  #writeDebug("handleAliases($args) called");

  require TWiki::Attrs;
  my $params = new TWiki::Attrs($args);
  my $theTopic = $params->{_DEFAULT} || $params->{topic};
  my $theRegex = $params->{regex} || 'off';

  if ($theTopic) {
    unless (getAliases($currentWeb, $theTopic)) {
      $foundError = 1;
      return '<font color="red">' .
	    'Error in %<nop>ALIASES%: no alias definitions found</font>';
    }
  }

  my $text = "<noautolink>\n";
  if ($theRegex eq 'on') {
    $text .= "| *Name* | *Regex* | *Value* |\n";
    foreach my $key (sort keys %aliasRegex) {
      my $regexText = $aliasRegex{$key};
      $regexText =~ s/([\x01-\x09\x0b\x0c\x0e-\x1f<>"&])/'&#'.ord($1).';'/ge;
      $regexText =~ s/\|/&#124;/go;
      $text .= "| <nop>$key | $regexText | $aliasValue{$key} |\n";
    }
  } else {
    $text .= "| *Name* | *Value* |\n";
    foreach my $key (sort keys %aliasRegex) {
      $text .= "| <nop>$key | $aliasValue{$key} |\n";
    }
  }
  $text .= "</noautolink>\n";
  
  return $text;
}

# =========================
sub handleAlias {
  my ($web, $topic, $args) = @_;

  #writeDebug("handleAlias() called");

  require TWiki::Attrs;
  my $params = new TWiki::Attrs($args);
  my $theKey = $params->{_DEFAULT} || $params->{name};
  my $theValue = $params->{value};
  my $theRegex = $params->{regex} || '';

  if ($theKey && $theValue) {
    $theRegex =~ s/\$start/$START/go;
    $theRegex =~ s/\$stop/$STOP/go;
    addAliasPattern($theKey, $theValue, $theRegex);
    #writeDebug("handleAlias(): added alias '$theKey' -> '$theValue')");
    return "";
  }

  $foundError = 1;
  return '<font color="red">Error in %<nop>ALIAS%: need a =name= and a =value= </font>';
}

# =========================
sub handleUnAlias {
  my ($web, $topic, $args) = @_;

  #writeDebug("handleUnAlias() called");

  if ($args) {
    require TWiki::Attrs;
    my $params = new TWiki::Attrs($args);
    my $theKey = $params->{_DEFAULT} || $params->{name};
    if ($theKey) {
      delete $aliasRegex{$theKey};
      delete $aliasValue{$theKey};
      return '';
    }

    $foundError = 1;
    return '<font color="red">Error in %<nop>UNALIAS%: don\'t know what to unalias</font>';
  } 

  $foundAliases = 0;
  %aliasRegex = ();
  %aliasValue = ();

  return '';
}

# =========================
sub addAliasPattern {
  my ($key, $value, $regex) = @_;

  $regex ||= '';

  #writeDebug("called addAliasPattern($key, $value, $regex)");

  if ($regex) {
    $aliasRegex{$key} = $regex;
    $aliasValue{$key} = $value;
  } else {
    $key =~ s/([\\\(\)\.\$])/\\$1/go;
    $value = &getConvenientAlias($key, $value);
    $aliasRegex{$key} = '\b'.$key.'\b';
    $aliasValue{$key} = $value;
  }
  $foundAliases = 1;

  #writeDebug("aliasRegex{$key}=$aliasRegex{$key} aliasValue{$key}=$aliasValue{$key}");
}

# =========================
sub getAliases {
  my ($web, $topic) = @_;

  $topic ||= 'WebAliases';
  $web ||= $currentWeb;
  ($web, $topic) = TWiki::Func::normalizeWebTopicName($web, $topic);

  # have we alread red these aliaes
  return if defined $seenAliasWebTopics{"$web.$topic"};
  $seenAliasWebTopics{"$web.$topic"} = 1;

  #writeDebug("getAliases($web, $topic)");

  # parse the plugin preferences lines
  unless (TWiki::Func::topicExists($web, $topic)) {
    return 0;
  }

  my $prefText = TWiki::Func::readTopicText($web, $topic);

  foreach my $line (split /\n/, $prefText) {
    if ($line =~ /^(?:\t| {3})+\* (?:\<nop\>)?($wordRegex): +(.*)$/) {
      my $key = $1;
      my $value = $2;
      $value =~ s/\s+$//go;
      addAliasPattern($key, $value);
    }
  }
  # handle our ALIAS commands
  commonTagsHandler($prefText);

  return 1;
}

# =========================
sub getConvenientAlias {
  my ($key, $value) = @_;

  #writeDebug("getConvenientAlias($key, $value) called");

  # convenience for wiki-links
  if ($value =~ /^($webRegex\.|$defaultWebNameRegex\.|#)$topicRegex/) {
    $value = "\[\[$value\]\[$key\]\]";
  }

  #writeDebug("returns '$value'");

  return $value;
}

# =========================
sub handleAliasArea {
  my $text = shift;
  return '' unless $text;

  my @aliasKeys = keys %aliasRegex;
  if ($foundError) {
    #writeDebug("found error");
    return $text;
  }
  if (!@aliasKeys) {
    #writeDebug("no alias keys");
    return $text;
  }

  writeDebug("handleAliasArea()");

  my $result = '';

  $text =~ s/<nop>/NOPTOKEN/g;
#  foreach my $line (split(/\n/, $text)) {

    # escape html tags
    while ($text =~ /([^<]*)((?:<[^>]*>)*|<)/go) {
      
      my $substr = $1;
      my $tail = $2;

      #writeDebug("html: substr='$substr', tail='$tail'\n");
      
      # escape twiki tags
      if ($substr) {
	while ($substr =~ /([^%]*)(((%[A-Z][a-zA-Z_0-9]+({[^}]+})?%)*)|%)/go) {
	
	  my $substr = $1;
	  my $tail = $2;

	  #writeDebug("twiki tags: substr='$substr', tail='$tail'\n");
	  
	  # escape twiki links
	  if ($substr) {
	    while ($substr =~ /([^\[]*)((?:\[[^\]]*\])*|\[)/go) {

	      my $substr = $1;
	      my $tail = $2;

	      #writeDebug("twiki links: substr='$substr', tail='$tail'\n");

	      # do the substitution
	      if ($substr) {
		%substHash = ();
		my $counter = 0;
		foreach my $key (@aliasKeys) {
		  $substr =~ s/$aliasRegex{$key}/&_doSetSubst(\$counter, $key)/gme;
		}
		if ($counter) {
		  if (DEBUG) {
		    $substr =~ s/$TranslationToken(\d+)$TranslationToken/&_doPutSubst($1)/gme;
		  } else {
		    $substr =~ s/$TranslationToken(\d+)$TranslationToken/$substHash{$1}/gm;
		  }
		}
		$result .= $substr;
	      }
	      $result .= $tail if $tail;
	    }
	  }
	  $result .= $tail if $tail;
	}
      }
      $result .= $tail if $tail;
    }
#  }
  $result =~ s/NOPTOKEN/<nop>/g;

  #writeDebug("result is '$result'");
  return $result;
}

# =========================
sub _doSetSubst {
  my ($counter, $key) = @_;
  
  $$counter++;
  $substHash{$$counter} = $aliasValue{$key};
  #writeDebug("set counter=$$counter for $key=$aliasValue{$key}");

  return $TranslationToken."$$counter".$TranslationToken; 
}
# =========================
sub _doPutSubst {
  my $counter = shift;

  if (defined $substHash{$counter}) {
    #writeDebug("put counter=$counter for $substHash{$counter}");
    return $substHash{$counter};
  } else {
    #writeDebug("oops, got no value for counter=$counter");
    return 'ERROR ERROR'; # never reach
  }
}

1;
