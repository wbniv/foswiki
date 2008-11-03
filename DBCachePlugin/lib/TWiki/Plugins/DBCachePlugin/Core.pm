# Plugin for TWiki Collaboration Platform, http://TWiki.org/
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

package TWiki::Plugins::DBCachePlugin::Core;

use strict;
use vars qw( 
  $TranslationToken %webDB %webDBIsModified $wikiWordRegex $webNameRegex
  $defaultWebNameRegex $linkProtocolPattern $twikiWeb
  $baseWeb $baseTopic %MON2NUM
);

%MON2NUM = (
  Jan => 0,
  Feb => 1,
  Mar => 2,
  Apr => 3,
  May => 4,
  Jun => 5,
  Jul => 6,
  Aug => 7,
  Sep => 8,
  Oct => 9,
  Nov => 10,
  Dec => 11
);

use constant DEBUG => 0; # toggle me

use TWiki::Contrib::DBCacheContrib;
use TWiki::Contrib::DBCacheContrib::Search;
use TWiki::Plugins::DBCachePlugin::WebDB;
use TWiki::Sandbox;
use Time::Local;

$TranslationToken = "\0"; # from TWiki.pm

###############################################################################
sub writeDebug {
  #&TWiki::Func::writeDebug('- DBCachePlugin - '.$_[0]) if DEBUG;
  print STDERR "- DBCachePlugin - $_[0]\n" if DEBUG;
}

###############################################################################
sub init {
  ($baseWeb, $baseTopic) = @_;

  %webDBIsModified = ();

  my $query = TWiki::Func::getCgiQuery();
  my $doRefresh = $query->param('refresh') || '';
  if ($doRefresh eq 'on') {
    %webDB = ();
    #writeDebug("found refresh=on in urlparam");
  }

  $wikiWordRegex = 
    TWiki::Func::getRegularExpression('wikiWordRegex');
  $webNameRegex = 
    TWiki::Func::getRegularExpression('webNameRegex');
  $defaultWebNameRegex = 
    TWiki::Func::getRegularExpression('defaultWebNameRegex');
  $linkProtocolPattern = 
    TWiki::Func::getRegularExpression('linkProtocolPattern');
  $twikiWeb = TWiki::Func::getTwikiWebname();
}

###############################################################################
sub renderWikiWordHandler {
  my ($theLinkText, $hasExplicitLinkLabel, $theWeb, $theTopic) = @_;

  return undef if !defined($theWeb) and !defined($theTopic); 
    # does not work out for TWikis < 4.2

  $theWeb = TWiki::Sandbox::untaintUnchecked($theWeb);# woops why is theWeb tainted
  return if $hasExplicitLinkLabel;
  
  #writeDebug("called renderWikiWordHandler($theLinkText, $theWeb, $theTopic)");

  my $topicTitle = getTopicTitle($theWeb, $theTopic);
  #writeDebug("topicTitle=$topicTitle");

  $theLinkText = $topicTitle if $topicTitle && $topicTitle ne $theTopic;

  return $theLinkText;
}

###############################################################################
sub afterSaveHandler {
  #TODO: re-do this so it only reparses the topic that was saved

  # force reload
  my $db = getDB($baseWeb);
  #writeDebug("touching webdb for $baseWeb");
  $db->touch();
  if ($baseWeb ne $_[2]) {
    $db = getDB($_[2]); 
    #writeDebug("touching webdb for $_[2]");
    $db->touch();
  }
}

###############################################################################
sub handleTOPICTITLE {
  my ($session, $params, $theTopic, $theWeb) = @_;

  my $thisTopic = $params->{_DEFAULT} || $params->{topic} || $baseTopic;
  my $thisWeb = $params->{web} || $baseWeb;
  my $theEncoding = $params->{encode} || '';
  my $theDefault = $params->{default};

  my $topicTitle = getTopicTitle($thisWeb, $thisTopic);

  if (defined($theDefault) && $topicTitle eq $thisTopic) {
    $topicTitle = $theDefault;
  }

  return urlEncode($topicTitle) if $theEncoding eq 'url';
  return entityEncode($topicTitle) if $theEncoding eq 'entity';

  return $topicTitle;
}

###############################################################################
sub getTopicTitle {
  my ($theWeb, $theTopic) = @_;

  ($theWeb, $theTopic) = TWiki::Func::normalizeWebTopicName($theWeb, $theTopic);

  my $db = getDB($theWeb);
  return $theTopic unless $db;

  my $topicObj = $db->fastget($theTopic);
  return $theTopic unless $topicObj;

  my $topicTitle = $topicObj->fastget('topictitle');
  return $topicTitle if $topicTitle;

  return $theTopic;
}

###############################################################################
sub handleDBQUERY {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called handleDBQUERY(" . $params->stringify() . ")");

  # params
  my $theSearch = $params->{_DEFAULT} || $params->{search};
  my $thisTopic = $params->{topic} || '';
  my $thisWeb = $params->{web} || $baseWeb;
  my $theTopics = $params->{topics} || '';
  my $theFormat = $params->{format};
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $theInclude = $params->{include};
  my $theExclude = $params->{exclude};
  my $theSort = $params->{sort} || $params->{order} || 'name';
  my $theReverse = $params->{reverse} || 'off';
  my $theSep = $params->{separator};
  my $theLimit = $params->{limit} || '';
  my $theSkip = $params->{skip} || 0;
  my $theHideNull = $params->{hidenull} || 'off';
  my $theRemote = $params->remove('remote') || 'off';
  $theRemote = ($theRemote =~ /^(on|force|1|yes)$/)?1:0;
  $theRemote = ($theRemote eq 'on')?1:0;

  # normalize 
  $theSkip =~ s/[^-\d]//go;
  $theSkip = 0 if $theSkip eq '';
  $theSkip = 0 if $theSkip < 0;
  $theFormat = '$topic' unless defined $theFormat;
  $theFormat = '' if $theFormat eq 'none';
  $theSep = $params->{sep} unless defined $theSep;
  $theSep = '$n' unless defined $theSep;
  $theSep = '' if $theSep eq 'none';

  # get web and topic(s)
  my @topicNames = ();
  if ($thisTopic) {
    ($thisWeb, $thisTopic) = TWiki::Func::normalizeWebTopicName($thisWeb, $thisTopic);
    push @topicNames, $thisTopic;
  } else {
    $thisTopic = $baseTopic;
    if ($theTopics) {
      @topicNames = split(/\s*,\*/, $theTopics);
    }
  }
  my $theDB = getDB($thisWeb);


  my ($topicNames, $hits, $msg) = $theDB->dbQuery($theSearch, 
    \@topicNames, $theSort, $theReverse, $theInclude, $theExclude);

  return inlineError($msg) if $msg;

  $theLimit =~ s/[^\d]//go;
  $theLimit = scalar(@$topicNames) if $theLimit eq '';
  $theLimit += $theSkip;

  my $count = scalar(@$topicNames);
  return '' if ($count <= $theSkip) && $theHideNull eq 'on';

  # format
  my $text = '';
  if ($theFormat && $theLimit) {
    my $index = 0;
    my $isFirst = 1;
    foreach my $topicName (@$topicNames) {
      #writeDebug("topicName=$topicName");
      $index++;
      next if $index <= $theSkip;
      my $topicObj = $hits->{$topicName};
      my $topicWeb = $topicObj->fastget('web');
      my $format = '';
      $format = $theSep unless $isFirst;
      $isFirst = 0;
      $format .= $theFormat;
      $format =~ s/\$pattern\((.*?)\)/extractPattern($topicObj, $1)/geo;
      $format =~ s/\$formfield\((.*?)\)/
        my $temp = $theDB->getFormField($topicName, $1);
	$temp =~ s#\)#${TranslationToken}#g;
	$temp/geo;
      $format =~ s/\$expand\((.*?)\)/
        my $temp = $1;
        $temp = expandVariables($temp, $topicWeb, $topicName,
          topic=>$topicName, web=>$topicWeb, index=>$index, count=>$count);
        $temp = $theDB->expandPath($topicObj, $temp);
	$temp =~ s#\)#${TranslationToken}#g;
	$temp/geo;
      $format =~ s/\$formatTime\((.*?)(?:,\s*'([^']*?)')?\)/formatTime($theDB->expandPath($topicObj, $1), $2)/geo; # single quoted
      $format = expandVariables($format, $topicWeb, $topicName,
	topic=>$topicName, web=>$topicWeb, index=>$index, count=>$count);
      $format =~ s/${TranslationToken}/)/go;
      $format = TWiki::Func::expandCommonVariables($format, $topicName, $topicWeb);
      $text .= $format;

      $TWiki::Plugins::DBCachePlugin::addDependency->($topicWeb, $topicName);

      last if $index == $theLimit;
    }
  }

  if (defined $theHeader) {
    $theHeader = expandVariables($theHeader, $thisWeb, $thisTopic, count=>$count, web=>$thisWeb);
    $theHeader = TWiki::Func::expandCommonVariables($theHeader, $thisTopic, $thisWeb);
  }
  if (defined $theFooter) {
    $theFooter = expandVariables($theFooter, $thisWeb, $thisTopic, count=>$count, web=>$thisWeb);
    $theFooter = TWiki::Func::expandCommonVariables($theFooter, $thisTopic, $thisWeb);
  }

  $text = $theHeader.$text.$theFooter;

  fixInclude($session, $thisWeb, $text) if $theRemote;

  return $text;
}

###############################################################################
# finds the correct topicfunction for this object topic.
# this is constructed by checking for the existance of a topic derived from
# the type information of the objec topic.
sub findTopicMethod {
  my ($session, $theWeb, $theTopic, $theObject) = @_;

  writeDebug("called findTopicMethod($theWeb, $theTopic, $theObject)");

  return undef unless $theObject;

  my ($thisWeb, $thisObject) = &TWiki::Func::normalizeWebTopicName($theWeb, $theObject);

  writeDebug("object web=$thisWeb, topic=$thisObject");

  # get form object
  my $baseDB = getDB($thisWeb);

  writeDebug("1");

  my $topicObj = $baseDB->fastget($thisObject);
  return undef unless $topicObj;

  writeDebug("2");

  my $form = $topicObj->fastget('form');
  return undef unless $form;

  writeDebug("3");

  my $formObj = $topicObj->fastget($form);
  return undef unless $formObj;

  writeDebug("4");

  # get type information on this object
  my $topicTypes = $formObj->fastget('TopicType');
  return undef unless $topicTypes;

  writeDebug("topicTypes=$topicTypes");

  foreach my $topicType (split(/\s*,\s*/, $topicTypes)) {
    $topicType =~ s/^\s+//o;
    $topicType =~ s/\s+$//o;

    #writeDebug("1");

    # if not found in the current web, try to 
    # find it in the web where this type is implemented
    my $topicTypeObj = $baseDB->fastget($topicType);
    next unless $topicTypeObj;

    #writeDebug("2");

    $form = $topicTypeObj->fastget('form');
    next unless $form;

    #writeDebug("3");

    $formObj = $topicTypeObj->fastget($form);
    next unless $formObj;

    #writeDebug("4");

    my $targetWeb;
    my $target = $formObj->fastget('Target');
    if ($target) {
      $targetWeb = $1 if $target =~ /^(.*)[.\/](.*?)$/;
    } 
    $targetWeb = $thisWeb unless defined $targetWeb;


    #writeDebug("5");

    my $theMethod = $topicType.$theTopic;
    my $targetDB = getDB($targetWeb);
    writeDebug("checking $targetWeb.$theMethod");
    return ($targetWeb, $theMethod) if $targetDB->fastget($theMethod);

    #writeDebug("6");
  }


  #writeDebug("5");
  return undef;
}

###############################################################################
sub handleDBCALL {
  my ($session, $params, $theTopic, $theWeb) = @_;

  my $thisTopic = $params->remove('_DEFAULT');
  return '' unless $thisTopic;

  # check if this is an object call
  my $theObject;
  if ($thisTopic =~ /^(.*)->(.*)$/) {
    $theObject = $1;
    $thisTopic = $2;
  }

  my $thisWeb;
  ($thisWeb, $thisTopic) = &TWiki::Func::normalizeWebTopicName($baseWeb, $thisTopic);

  # find the actual implementation
  if ($theObject) {
    my ($methodWeb, $methodTopic) = findTopicMethod($session, $thisWeb, $thisTopic, $theObject);
    if (defined $methodWeb) {
      #writeDebug("found impl at $methodWeb.$methodTopic");
      $params->{OBJECT} = $theObject;
      $thisWeb = $methodWeb;
      $thisTopic = $methodTopic;
    } else {
      # last resort: lookup the method in the Applications web
      #writeDebug("last resort check for Applications.$thisTopic");
      my $appDB = getDB('Applications');
      if ($appDB->fastget($thisTopic)) {
        $params->{OBJECT} = $theObject;
        $thisWeb = 'Applications';
      }
    }
  }

  $TWiki::Plugins::DBCachePlugin::addDependency->($thisWeb, $thisTopic);

  # remember args for the key before mangling the params
  my $args = $params->stringify();

  #writeDebug("called handleDBCALL()");

  my $section = $params->remove('section') || 'default';
  my $warn = $params->remove('warn') || 'on';
  $warn = ($warn eq 'on')?1:0;
  my $remote = $params->remove('remote') || 'off';
  $remote = ($remote =~ /^(on|force|1|yes)$/)?1:0;

  #writeDebug("thisWeb=$thisWeb thisTopic=$thisTopic baseWeb=$baseWeb baseTopic=$baseTopic");

  # get web and topic
  my $thisDB = getDB($thisWeb);
  my $topicObj = $thisDB->fastget($thisTopic);
  unless ($topicObj) {
    if ($warn) {
      if ($theObject) {
        return inlineError("ERROR: DBCALL can't find method <nop>$thisTopic for object $theObject");
      } else {
        return inlineError("ERROR: DBCALL can't find topic <nop>$thisTopic in <nop>$thisWeb");
      }
    } else {
      return '';
    }
  }

  # check access rights
  my $wikiName = TWiki::Func::getWikiName();
  unless (TWiki::Func::checkAccessPermission('VIEW', $wikiName, undef, $thisTopic, $thisWeb)) {
    if ($warn) {
      return inlineError("ERROR: DBCALL access to '$thisWeb.$thisTopic' denied");
    } 
    return '';
  }

  # get section
  my $sectionText = $topicObj->fastget("_section$section") if $topicObj;
  if (!$sectionText) {
    if($warn) {
      return inlineError("ERROR: DBCALL can't find section '$section' in topic '$thisWeb.$thisTopic'");
    } else {
      return '';
    }
  }

  # prevent recursive calls
  my $key = $thisWeb.'.'.$thisTopic;
  my $count = grep($key, keys %{$session->{dbcalls}});
  $key .= $args;
  if ($session->{dbcalls}->{$key} || $count > 99) {
    if($warn) {
      return inlineError("ERROR: DBCALL reached max recursion at '$thisWeb.$thisTopic'");
    }
    return '';
  }
  $session->{dbcalls}->{$key} = 1;

  # substitute variables
  $sectionText =~ s/%INCLUDINGWEB%/$theWeb/g;
  $sectionText =~ s/%INCLUDINGTOPIC%/$theTopic/g;
  foreach my $key (keys %$params) {
    $sectionText =~ s/%$key%/$params->{$key}/g;
  }

  # expand
  my $context = TWiki::Func::getContext();
  $context->{insideInclude} = 1;
  $sectionText = TWiki::Func::expandCommonVariables($sectionText, $thisTopic, $thisWeb);
  delete $context->{insideInclude};

  # fix local linx
  fixInclude($session, $thisWeb, $sectionText) if $remote;

  # cleanup
  delete $session->{dbcalls}->{$key};

  return $sectionText;
  #return "<verbatim>\n$sectionText\n</verbatim>";
}

###############################################################################
sub handleDBSTATS {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called handleDBSTATS");

  # get args
  my $theSearch = $params->{_DEFAULT} || $params->{search} || '';
  my $thisWeb = $params->{web} || $baseWeb;
  my $thisTopic = $params->{topic} || $baseTopic;
  my $thePattern = $params->{pattern} || '(\w+)';
  my $theHeader = $params->{header} || '';
  my $theFormat = $params->{format};
  my $theFooter = $params->{footer} || '';
  my $theSep = $params->{separator};
  my $theFields = $params->{fields} || $params->{field} || 'text';
  my $theSort = $params->{sort} || $params->{order} || 'alpha';
  my $theReverse = $params->{reverse} || 'off';
  my $theLimit = $params->{limit} || 0;
  my $theHideNull = $params->{hidenull} || 'off';
  $theLimit =~ s/[^\d]//go;

  $theFormat = '   * $key: $count' unless defined $theFormat;
  $theSep = $params->{sep} unless defined $theSep;
  $theSep = '$n' unless defined $theSep;

  #writeDebug("theSearch=$theSearch");
  #writeDebug("thisWeb=$thisWeb");
  #writeDebug("thePattern=$thePattern");
  #writeDebug("theHeader=$theHeader");
  #writeDebug("theFormat=$theFormat");
  #writeDebug("theFooter=$theFooter");
  #writeDebug("theSep=$theSep");
  #writeDebug("theFields=$theFields");

  # build seach object
  my $search = new TWiki::Contrib::DBCacheContrib::Search($theSearch);
  unless ($search) {
    return "ERROR: can't parse query $theSearch";
  }

  # compute statistics
  my $wikiName = TWiki::Func::getWikiName();
  my %statistics = ();
  my $theDB = getDB($thisWeb);
  my @topicNames = $theDB->getKeys();
  foreach my $topicName (@topicNames) { # loop over all topics
    my $topicObj = $theDB->fastget($topicName);
    next unless $search->matches($topicObj); # that match the query
    next unless TWiki::Func::checkAccessPermission('VIEW', 
      $wikiName, undef, $topicName, $thisWeb);

    #writeDebug("found topic $topicName");
    my $createdate = $topicObj->fastget('createdate');
    foreach my $field (split(/\s*,\s*/, $theFields)) { # loop over all fields
      my $fieldValue = $topicObj->fastget($field);
      if (!$fieldValue || ref($fieldValue)) {
	my $topicForm = $topicObj->fastget('form');
	#writeDebug("found form $topicForm");
	if ($topicForm) {
	  $topicForm = $topicObj->fastget($topicForm);
	  $fieldValue = $topicForm->fastget($field);
	}
      }
      next unless $fieldValue; # unless present
      #writeDebug("reading field $field found $fieldValue");

      while ($fieldValue =~ /$thePattern/g) { # loop over all occurrences of the pattern
	my $key1 = $1;
	my $key2 = $2 || '';
	my $key3 = $3 || '';
	my $key4 = $4 || '';
	my $key5 = $5 || '';
	my $record = $statistics{$key1};
	if ($record) {
	  $record->{count}++;
	  $record->{from} = $createdate if $record->{from} > $createdate;
	  $record->{to} = $createdate if $record->{to} < $createdate;
	  push @{$record->{topics}}, $topicName;
	} else {
	  my %record = (
	    count=>1,
	    from=>$createdate,
	    to=>$createdate,
	    keyList=>[$key1, $key2, $key3, $key4, $key5],
	    topics=>[$topicName],
	  );
	  $statistics{$key1} = \%record;
	}
        $TWiki::Plugins::DBCachePlugin::addDependency->($thisWeb, $topicName);
      }
    }
  }
  my $min = 99999999;
  my $max = 0;
  my $sum = 0;
  foreach my $key (keys %statistics) {
    my $record = $statistics{$key};
    $min = $record->{count} if $min > $record->{count};
    $max = $record->{count} if $max < $record->{count};
    $sum += $record->{count};
  }
  my $numkeys = scalar(keys %statistics);
  my $mean = 0;
  $mean = (($sum+0.0) / $numkeys) if $numkeys;
  return '' if $theHideNull eq 'on' && $numkeys == 0;

  # format output
  my $result = '';
  my @sortedKeys;
  if ($theSort =~ /^created(from)?$/) {
    @sortedKeys = sort {
      $statistics{$a}->{from} <=> $statistics{$b}->{from}
    } keys %statistics
  } elsif ($theSort eq 'createdto') {
    @sortedKeys = sort {
      $statistics{$a}->{to} <=> $statistics{$b}->{to}
    } keys %statistics
  } else {
    @sortedKeys = sort keys %statistics;
  }
  @sortedKeys = reverse @sortedKeys if $theReverse eq 'on';
  my $index = 0;
  foreach my $key (@sortedKeys) {
    $index++;
    my $record = $statistics{$key};
    my $text;
    my ($key1, $key2, $key3, $key4, $key5) =
      @{$record->{keyList}};
    $text = $theSep if $result;
    $text .= $theFormat;
    $result .= &expandVariables($text, 
      $thisWeb,
      $thisTopic,
      'web'=>$thisWeb,
      'topics'=>join(', ', @{$record->{topics}}),
      'key'=>$key,
      'key1'=>$key1,
      'key2'=>$key2,
      'key3'=>$key3,
      'key4'=>$key4,
      'key5'=>$key5,
      'count'=>$record->{count}, 
      'index'=>$index,
      'min'=>$min,
      'max'=>$max,
      'sum'=>$sum,
      'mean'=>$mean,
      'keys'=>$numkeys,
    );

    last if $theLimit && $index == $theLimit;
  }
  $theHeader = &expandVariables($theHeader, $thisWeb, $thisTopic);
  $theFooter = &expandVariables($theFooter, $thisWeb, $thisTopic);
  $result = &TWiki::Func::expandCommonVariables($theHeader.$result.$theFooter, $thisTopic, $thisWeb);

  return $result;
}

###############################################################################
sub handleDBDUMP {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called handleDBDUMP");

  my $thisTopic = $params->{_DEFAULT} || $baseTopic;
  my $thisWeb = $params->{web} || $baseWeb;
  ($thisWeb, $thisTopic) = TWiki::Func::normalizeWebTopicName($thisWeb, $thisTopic);

  $TWiki::Plugins::DBCachePlugin::addDependency->($thisWeb, $thisTopic);

  my $theDB = getDB($thisWeb);

  my $topicObj = $theDB->fastget($thisTopic) || '';
  unless ($topicObj) {
    return inlineError("$thisWeb.$thisTopic not found");
  }
  my $result = "\n<noautolink>\n";
  $result .= "---++ [[$thisWeb.$thisTopic]]\n$topicObj\n";

  # read all keys
  $result .= "<table class=\"twikiTable\">\n";
  foreach my $key (sort $topicObj->getKeys()) {
    my $value = $topicObj->fastget($key);
    $result .= "<tr><th>$key</th>\n<td><verbatim>\n$value\n</verbatim></td></tr>\n";
  }
  $result .= "</table>\n";

  # read info
  my $topicInfo = $topicObj->fastget('info');
  $result .= "<p/>\n---++ Info = $topicInfo\n";
  $result .= "<table class=\"twikiTable\">\n";
  foreach my $key (sort $topicInfo->getKeys()) {
    my $value = $topicInfo->fastget($key);
    $result .= "<tr><th>$key</th><td>$value</td></tr>\n" if defined $value;
  }
  $result .= "</table>\n";

  # read form
  my $topicForm = $topicObj->fastget('form');
  if ($topicForm) {
    $result .= "<p/>\n---++ Form = $topicForm\n";
    $result .= "<table class=\"twikiTable\">\n";
    $topicForm = $topicObj->fastget($topicForm);
    foreach my $key (sort $topicForm->getKeys()) {
      my $value = $topicForm->fastget($key);
      $result .= "<tr><th>$key</th><td>$value</td>\n" if defined $value;
    }
    $result .= "</table>\n";
  }

  # read attachments
  my $attachments = $topicObj->fastget('attachments');
  if ($attachments) {
    $result .= "<p/>\n---++ Attachments = $attachments\n";
    $result .= "<table class=\"twikiTable\">\n";
    foreach my $attachment (sort $attachments->getValues()) {
      $result .= "<tr><th valign='top'>".$attachment->fastget('name')."</th>";
      $result .= '<td><table>';
      foreach my $key (sort $attachment->getKeys()) {
        next if $key eq 'name';
        my $value = $attachment->fastget($key);
        $result .= "<tr><th>$key</th><td>$value</td></tr>\n" if defined $value;
      }
      $result .= '</table></td></tr>';
    }
    $result .= "</table>\n";
  }

  # read preferences
  my $prefs = $topicObj->fastget('preferences');
  if ($prefs) {
    $result .= "<p/>\n---++ Preferences = $prefs\n";
    $result .= "<table class=\"twikiTable\">\n";
    $result .= '<tr><th>type</th><th>name</th><th>title</th><th>value</th><th>_up</th><th>_web</th></tr>'."\n";
    foreach my $pref (sort {$a->fastget('name') cmp $b->fastget('name')} $prefs->getValues()) {
      $result .= "<tr><td>".$pref->fastget('type')."</td>\n";
      $result .= "<td>".$pref->fastget('name')."</td>\n";
      $result .= "<td>".$pref->fastget('title')."</td>\n";
      $result .= "<td>".$pref->fastget('value')."</td>\n";
      $result .= "<td>".$pref->fastget('_up')."</td>\n";
      $result .= "<td>".$pref->fastget('_web')."</td>\n";
      $result .= "</tr>\n";
    }
    $result .= "</table>\n";
  }

  return $result."\n</noautolink>\n";
}

###############################################################################
sub handleATTACHMENTS {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called handleATTACHMENTS($theTopic, $theWeb)");
  #writeDebug("params=".$params->stringify());


  # get parameters
  my $thisTopic = $params->{_DEFAULT} || $params->{topic} || $baseTopic;
  my $thisWeb = $params->{web} || $baseWeb;
  ($thisWeb, $thisTopic) = TWiki::Func::normalizeWebTopicName($thisWeb, $thisTopic);
  $TWiki::Plugins::DBCachePlugin::addDependency->($thisWeb, $thisTopic);

  my $theNames = $params->{names} || $params->{name} || '.*';
  my $theAttr = $params->{attr} || '.*';
  my $theAutoAttached = $params->{autoattached} || 2;
  $theAutoAttached = 0 if $theAutoAttached =~ /^(no|off)$/o;
  $theAutoAttached = 1 if $theAutoAttached =~ /^(yes|on)$/o;
  $theAutoAttached = 2 if $theAutoAttached eq 'undef';
  my $theMinDate = $params->{mindate};
  $theMinDate = TWiki::Time::parseTime($theMinDate) if $theMinDate;
  my $theMaxDate = $params->{maxdate};
  $theMaxDate = TWiki::Time::parseTime($theMaxDate) if $theMaxDate;
  my $theMinSize = $params->{minsize} || 0;
  my $theMaxSize = $params->{maxsize} || 0;
  my $theUser = $params->{user} || '.*';
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $theFormat = $params->{format};
  my $theSeparator = $params->{separator};
  my $theSort = $params->{sort} || $params->{order} || 'name';
  my $theHideNull = $params->{hidenull} || 'off';
  my $theComment = $params->{comment} || '.*';

  $theFormat = '| [[$url][$name]] |  $sizeK | <nobr>$date</nobr> | $wikiuser | $comment |' 
    unless defined $theFormat;
  $theSeparator = $params->{sep} unless defined $theSeparator;
  $theSeparator = "\n" unless defined $theSeparator;

  # get topic
  my $theDB = getDB($thisWeb);
  my $topicObj = $theDB->fastget($thisTopic) || '';
  return inlineError("$thisWeb.$thisTopic not found") unless $topicObj;

  # sort attachments
  my $attachments = $topicObj->fastget('attachments');
  return '' unless $attachments;

  my @attachments;
  if ($theSort eq 'name') {
    @attachments = sort {$a->fastget('name') cmp $b->fastget('name')} 
      $attachments->getValues();
  } elsif ($theSort eq 'date') {
    @attachments = sort {$a->fastget('date') <=> $b->fastget('date')} 
      $attachments->getValues();
  } elsif ($theSort eq 'size') {
    @attachments = sort {$a->fastget('size') <=> $b->fastget('size')} 
      $attachments->getValues();
  } elsif ($theSort eq 'user') {
    @attachments = sort {$a->fastget('user') cmp $b->fastget('user')} 
      $attachments->getValues();
  }

  #writeDebug("theComment=$theComment");

  # collect result
  my @result;

  my $index = 0;
  foreach my $attachment (@attachments) {
    my $name = $attachment->fastget('name');
    #writeDebug("name=$name");
    next unless $name =~ /^($theNames)$/;

    my $attr = $attachment->fastget('attr');
    #writeDebug("attr=$attr");
    next unless $attr =~ /^($theAttr)$/;

    my $autoattached = $attachment->fastget('autoattached') || 0;
    #writeDebug("autoattached=$autoattached");
    next if $theAutoAttached == 0 && $autoattached != 0;
    next if $theAutoAttached == 1 && $autoattached != 1;

    my $date = $attachment->fastget('date');
    #writeDebug("date=$date");
    next if $theMinDate && $date < $theMinDate;
    next if $theMaxDate && $date > $theMaxDate;

    my $user = $attachment->fastget('user') || 'UnknownUser';
    if ($TWiki::Plugins::VERSION >= 1.2) {# TWiki-4.2 onwards
      $user = TWiki::Func::getWikiName($user);
    }
    #writeDebug("user=$user");
    next unless $user =~ /^($theUser)$/;
    my ($userWeb, $userTopic) = TWiki::Func::normalizeWebTopicName('', $user);

    my $size = $attachment->fastget('size');
    #writeDebug("size=$size");
    next if $theMinSize && $size < $theMinSize;
    next if $theMaxSize && $size > $theMaxSize;

    my $sizeK = sprintf("%.2f",$size/1024);
    my $sizeM = sprintf("%.2f",$sizeK/1024);

    my $path = $attachment->fastget('path');
    #writeDebug("path=$path");

    my $comment = $attachment->fastget('comment') || '';
    next unless $comment =~ /^($theComment)$/;

    my $fileType = $session->mapToIconFileName($path); # SMELL: no func api
    my $iconUrl = $session->getIconUrl(0, $fileType);
    my $icon = 
      '<img src="'.$iconUrl.'" '.
      'width="16" height="16" align="top" '.
      'alt="'.$fileType.'" '.
      'border="0" />';

    # actions
    my $webDavUrl = '%WIKIDAVPUBURL%/'.$thisWeb.'/'.$thisTopic.'/'.$name;
    my $webDavAction = 
      '<a rel="nofollow" href="'.$webDavUrl.'" '.
      'title="%MATETEXT{"edit [_1] using webdav" args="<nop>'.$name.'"}%">'.
      '%MAKETEXT{"edit"}%</a>';

    my $propsUrl = '%SCRIPTURLPATH{"attach"}%/'.$thisWeb.'/'.$thisTopic.'?filename='.$name.'&revInfo=1';
    my $propsAction =
      '<a rel="nofollow" href="'.$propsUrl.'" '.
      'title="%MAKETEXT{"manage properties of [_1]" args="<nop>'.$name.'"}%">'.
      '%MAKETEXT{"props"}%</a>';

    my $moveUrl = '%SCRIPTURLPATH{"rename"}%/'.$thisWeb.'/'.$thisTopic.'?attachment='.$name;
    my $moveAction =
      '<a rel="nofollow" href="'.$moveUrl.'" '.
      'title="%MAKETEXT{"move or delete [_1]" args="<nop>'.$name.'"}%">'.
      '%MAKETEXT{"move"}%</a>';

    my $deleteUrl = '%SCRIPTURLPATH{"rename"}%/'.$thisWeb.'/'.$thisTopic.
      '?attachment='.$name.'&newweb=Trash';
    my $deleteAction =
      '<a rel="nofollow" href="'.$deleteUrl.'" '.
      'title="%MAKETEXT{"delete [_1]" args="<nop>'.$name.'"}%">'.
      '%MAKETEXT{"delete"}%</a>';
    
    $index++;
    my $text = $theFormat;
    $text =~ s/\$date\(([^\)]+)\)/_formatTile($date, $1)/ge;
    $text = expandVariables($text, $thisWeb, $thisTopic,
      'webdav'=>$webDavAction,
      'webdavUrl'=>$webDavUrl,
      'props'=>$propsAction,
      'propsUrl'=>$propsUrl,
      'move'=>$moveAction,
      'moveUrl'=>$moveUrl,
      'delete'=>$deleteAction,
      'deleteUrl'=>$deleteUrl,
      'icon'=>$icon,
      'type'=>$fileType,
      'iconUrl'=>$iconUrl,
      'attr'=>$attr,
      'autoattached'=>$autoattached,
      'comment'=>$comment,
      'date'=>formatTime($date),
      'index'=>$index,
      'name'=>$name,
      'path'=>$path,
      'size'=>$size,
      'sizeK'=>$sizeK.'K',
      'sizeM'=>$sizeM.'M',
      'url'=>"\%PUBURL\%\/$thisWeb\/$thisTopic\/$name",
      'urlpath'=>"\%PUBURLPATH\%\/$thisWeb\/$thisTopic\/$name",
      'user'=>$userTopic,
      'wikiuser'=>"$userWeb.$userTopic",
      'web'=>$thisWeb,
      'topic'=>$thisTopic,
    );

    push @result, $text;
  }

  return '' if $theHideNull eq 'on' && $index == 0;

  $theHeader = expandVariables($theHeader, $thisWeb, $thisTopic, count=>$index);
  $theFooter = expandVariables($theFooter, $thisWeb, $thisTopic, count=>$index);

  return $theHeader.join($theSeparator,@result).$theFooter;
}

###############################################################################
sub handleDBRECURSE {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called handleDBRECURSE(" . $params->stringify() . ")");

  my $thisTopic = $params->{_DEFAULT} || $params->{topic} || $baseTopic;
  my $thisWeb = $params->{web} || $baseWeb;

  ($thisWeb, $thisTopic) = 
    &TWiki::Func::normalizeWebTopicName($thisWeb, $thisTopic);

  $params->{format} ||= '   $indent* [[$web.$topic][$topic]]';
  $params->{single} ||= $params->{format};
  $params->{separator} ||= $params->{sep} || "\n";
  $params->{header} ||= '';
  $params->{subheader} ||= '';
  $params->{singleheader} ||= $params->{header};
  $params->{footer} ||= '';
  $params->{subfooter} ||= '';
  $params->{singlefooter} ||= $params->{footer};
  $params->{hidenull} ||= 'off';
  $params->{filter} ||= 'parent=\'$name\'';
  $params->{sort} ||= $params->{order} || 'name';
  $params->{reverse} ||= 'off';
  $params->{limit} ||= 0;
  $params->{skip} ||= 0;
  $params->{depth} ||= 0;

  $params->{format} = '' if $params->{format} eq 'none';
  $params->{single} = '' if $params->{single} eq 'none';
  $params->{header} = '' if $params->{header} eq 'none';
  $params->{footer} = '' if $params->{footer} eq 'none';
  $params->{subheader} = '' if $params->{subheader} eq 'none';
  $params->{subfooter} = '' if $params->{subfooter} eq 'none';
  $params->{singleheader} = '' if $params->{singleheader} eq 'none';
  $params->{singlefooter} = '' if $params->{singlefooter} eq 'none';
  $params->{separator} = '' if $params->{separator} eq 'none';

  # query topics
  my $theDB = getDB($thisWeb);
  $params->{_count} = 0;
  my $result = formatRecursive($theDB, $thisWeb, $thisTopic, $params);
  return '' unless $result;

  # render result
  return '' if $params->{hidenull} eq 'on' && $params->{_count} == 0;

  return 
    expandVariables(
      ($params->{_count} == 1)?$params->{singleheader}:$params->{header}, 
      $thisWeb, $thisTopic, 
      count=>$params->{_count}).
    join($params->{separator},@$result).
    expandVariables(
      ($params->{_count} == 1)?$params->{singlefooter}:$params->{footer}, 
      $thisWeb, $thisTopic, 
      count=>$params->{_count});
}

###############################################################################
sub formatRecursive {
  my ($theDB, $theWeb, $theTopic, $params, $seen, $depth, $number) = @_;

  # protection agains infinite recursion
  my %thisSeen;
  $seen ||= \%thisSeen;
  return if $seen->{$theTopic};
  $seen->{$theTopic} = 1;
  $depth ||= 0;
  $number ||= '';

  return if $params->{depth} && $depth >= $params->{depth};

  #writeDebug("called formatRecursive($theWeb, $theTopic)");
  return unless $theTopic;

  # search sub topics
  my $queryString = $params->{filter};
  $queryString =~ s/\$ref\b/$theTopic/g; # backwards compatibility
  $queryString =~ s/\$name\b/$theTopic/g;

  #writeDebug("queryString=$queryString");
  my ($topicNames, $hits, $errMsg) = $theDB->dbQuery($queryString, undef, 
    $params->{sort},
    $params->{reverse},
    $params->{include},
    $params->{exclude});
  die $errMsg if $errMsg; # never reach

  # format this round
  my @result = ();
  my $index = 0;
  my $nrTopics = scalar(@$topicNames);
  foreach my $topicName (@$topicNames) {
    next if $topicName eq $theTopic; # cycle, kind of
    $params->{_count}++;
    next if $params->{_count} <= $params->{skip};

    # format this
    my $numberString = ($number)?"$number.$index":$index;

    my $text = ($nrTopics == 1)?$params->{single}:$params->{format};
    $text = expandVariables($text, $theWeb, $theTopic,
      'web'=>$theWeb,
      'topic'=>$topicName,
      'number'=>$numberString,
      'index'=>$index,
      'count'=>$params->{_count},
    );
    $text =~ s/\$indent\((.+?)\)/$1 x $depth/ge;
    $text =~ s/\$indent/'   ' x $depth/ge;

    # from DBQUERY
    my $topicObj = $hits->{$topicName};
    $text =~ s/\$formfield\((.*?)\)/
      my $temp = $theDB->getFormField($topicName, $1);
      $temp =~ s#\)#${TranslationToken}#g;
      $temp/geo;
    $text =~ s/\$expand\((.*?)\)/
      my $temp = $theDB->expandPath($topicObj, $1);
      $temp =~ s#\)#${TranslationToken}#g;
      $temp/geo;
    $text =~ s/\$formatTime\((.*?)(?:,\s*'([^']*?)')?\)/formatTime($theDB->expandPath($topicObj, $1), $2)/geo; # single quoted

    push @result, $text;

    # recurse
    my $subResult = 
      formatRecursive($theDB, $theWeb, $topicName, $params, $seen, 
        $depth+1, $numberString);
    

    if ($subResult && @$subResult) {
      push @result, 
        expandVariables($params->{subheader}, $theWeb, $topicName, 
          'web'=>$theWeb,
          'topic'=>$topicName,
          'number'=>$numberString,
          'index'=>$index,
          'count'=>$params->{_count},
        ).
        join($params->{separator},@$subResult).
        expandVariables($params->{subfooter}, $theWeb, $topicName, 
          'web'=>$theWeb,
          'topic'=>$topicName,
          'number'=>$numberString,
          'index'=>$index,
          'count'=>$params->{_count},
        );
    }

    last if $params->{limit} && $params->{_count} >= $params->{limit};
  }

  return \@result;
}

###############################################################################
sub getDB {
  my $theWeb = shift;
  
  #writeDebug("called getDB($theWeb)");

  # We do not need to reload the cache if we run on mod_perl or speedy_cgi or
  # whatever perl accelerator that keeps our global variables and 
  # the database wasn't modified!

  $theWeb =~ s/\//\./go;

  my $isModified = 0;
  unless (defined $webDB{$theWeb}) {
    # never loaded
    $isModified = 1;
    writeDebug("fresh reload of '$theWeb' ($isModified)");
  } else {
    unless (defined $webDBIsModified{$theWeb}) {
      # never checked
      $webDBIsModified{$theWeb} = $webDB{$theWeb}->isModified();
      if (DEBUG) {
        if ($webDBIsModified{$theWeb}) {
          writeDebug("reloading modified $theWeb");
        } else {
          writeDebug("don't need to load webdb for $theWeb");
        }
      }
    }
    $isModified = $webDBIsModified{$theWeb};
  }

  if ($isModified) {
    my $impl = TWiki::Func::getPreferencesValue('WEBDB', $theWeb)
      || 'TWiki::Plugins::DBCachePlugin::WebDB';
    $impl =~ s/^\s+//go;
    $impl =~ s/\s+$//go;
    #writeDebug("loading new webdb for '$theWeb($isModified) '");
    #writeDebug("impl='$impl'");
    $webDB{$theWeb}->DESTROY() if $webDB{$theWeb};
    $webDB{$theWeb} = new $impl($theWeb);
    $webDB{$theWeb}->load();
    $webDBIsModified{$theWeb} = 0;
  }

  return $webDB{$theWeb};
}

###############################################################################
sub DESTROY_ALL {
  foreach my $web (keys %webDB) {
    #writeDebug("closing db for $web");
    $webDB{$web}->touch();
    $webDB{$web}->DESTROY();
  }
  %webDB = ();
  %webDBIsModified = ();
}


###############################################################################
# from TWiki::_INCLUDE
sub fixInclude {
  my $session = shift;
  my $thisWeb = shift;
  # $text next

  my $removed = {};

  # Must handle explicit [[]] before noautolink
  # '[[TopicName]]' to '[[Web.TopicName][TopicName]]'
  $_[0] =~ s/\[\[([^\]]+)\]\]/&fixIncludeLink($thisWeb, $1)/geo;
  # '[[TopicName][...]]' to '[[Web.TopicName][...]]'
  $_[0] =~ s/\[\[([^\]]+)\]\[([^\]]+)\]\]/&fixIncludeLink($thisWeb, $1, $2)/geo;

  $_[0] = $session->{renderer}->takeOutBlocks($_[0], 'noautolink', $removed);

  # 'TopicName' to 'Web.TopicName'
  $_[0] =~ s/(^|[\s(])($webNameRegex\.$wikiWordRegex)/$1$TranslationToken$2/go;
  $_[0] =~ s/(^|[\s(])($wikiWordRegex)/$1\[\[$thisWeb\.$2\]\[$2\]\]/go;
  $_[0] =~ s/(^|[\s(])$TranslationToken/$1/go;

  $session->{renderer}->putBackBlocks( \$_[0], $removed, 'noautolink');
}

###############################################################################
# from TWiki::fixIncludeLink
sub fixIncludeLink {
  my( $theWeb, $theLink, $theLabel ) = @_;

  # [[...][...]] link
  if($theLink =~ /^($webNameRegex\.|$defaultWebNameRegex\.|$linkProtocolPattern\:|\/)/o) {
    if ( $theLabel ) {
      return "[[$theLink][$theLabel]]";
    } else {
      return "[[$theLink]]";
    }
  } elsif ( $theLabel ) {
    return "[[$theWeb.$theLink][$theLabel]]";
  } else {
    return "[[$theWeb.$theLink][$theLink]]";
  }
}

###############################################################################
sub expandVariables {
  my ($theFormat, $web, $topic, %params) = @_;

  return '' unless $theFormat;
  
  foreach my $key (keys %params) {
    if($theFormat =~ s/\$$key\b/$params{$key}/g) {
      #writeDebug("expanding $key->$params{$key}");
    }
  }
  $theFormat =~ s/\$percnt/\%/go;
  $theFormat =~ s/\$nop//g;
  $theFormat =~ s/\$n/\n/go;
  $theFormat =~ s/\$flatten\((.*?)\)/&flatten($1)/ges;
  $theFormat =~ s/\$rss\((.*?)\)/&rss($1, $web, $topic)/ges;
  $theFormat =~ s/\$encode\((.*?)\)/&entityEncode($1)/ges;
  $theFormat =~ s/\$trunc\((.*?),\s*(\d+)\)/substr($1,0,$2)/ges;
  $theFormat =~ s/\$t\b/\t/go;
  $theFormat =~ s/\$dollar/\$/go;

  return $theFormat;
}

###############################################################################
# our own time format parser
sub parseTime {
  my $date = shift;

  my $sec = 0; my $min = 0; my $hour = 0; my $day = 1; my $mon = 0; my $year = 0;

  # "31 Dec 2003 - 23:59", "31-Dec-2003 - 23:59", "31 Dec 2003 - 23:59 - any suffix"
  if($date =~ m|([0-9]{1,2})[-\s/]+([A-Z][a-z][a-z])[-\s/]+([0-9]{4})[-\s/]+([0-9]{1,2}):([0-9]{1,2})|) {
    $day = $1;
    $mon = $MON2NUM{$2} || 0;
    $year = $3 - 1900;
    $hour = $4;
    $min = $5;
  }

  # "31 Dec 2003", "31 Dec 03", "31-Dec-2003", "31/Dec/2003"
  elsif($date =~ m|([0-9]{1,2})[-\s/]+([A-Z][a-z][a-z])[-\s/]+([0-9]{2,4})|) {
    $day = $1;
    $mon = $MON2NUM{$2} || 0;
    $year = $3;
    $year += 100 if $year < 80; # "05"   --> "105" (leave "99" as is)
    $year -= 1900 if $year >= 1900; # "2005" --> "105"
  }

  # "2003/12/31 23:59:59", "2003-12-31-23-59-59", "2003.12.31.23.59.59"
  elsif($date =~ m|([0-9]{4})[-/\.]([0-9]{1,2})[-/\.]([0-9]{1,2})[-/\.\,\s]+([0-9]{1,2})[-\:/\.]([0-9]{1,2})[-\:/\.]([0-9]{1,2})|) {
    $year = $1 - 1900;
    $mon = $2 - 1;
    $day = $3;
    $hour = $4;
    $min = $5;
    $sec = $6;
  }

  # "2003/12/31 23:59", "2003-12-31-23-59", "2003.12.31.23.59"
  elsif($date =~ m|([0-9]{4})[-/\.]([0-9]{1,2})[-/\.]([0-9]{1,2})[-/\.\,\s]+([0-9]{1,2})[-\:/\.]([0-9]{1,2})|) {
    $year = $1 - 1900;
    $mon = $2 - 1;
    $day = $3;
    $hour = $4;
    $min = $5;
  }

  # "2003/12/31", "2003-12-31"
  elsif( $date =~ m|([0-9]{4})[-/]([0-9]{1,2})[-/]([0-9]{1,2})| ) {
    $year = $1 - 1900;
    $mon = $2 - 1;
    $day = $3;
  }

  # "31.12.2001"
  elsif( $date =~ m|([0-9]{1,2})\.([0-9]{1,2})\.([0-9]{4})|) {
    $day = $1;
    $mon = $2 - 1;
    $year = $3 - 1900;
  }

  # "12/31/2003", "12/31/03", "12-31-2003"
  # (shh, don't tell anyone that we support ambiguous American dates, my boss asked me to)
  elsif( $date =~ m|([0-9]{1,2})[-/]([0-9]{1,2})[-/]([0-9]{2,4})| ) {
    $year = $3;
    $mon = $1 - 1;
    $day = $2;
    $year += 100 if $year < 80; # "05"   --> "105" (leave "99" as is)
    $year -= 1900 if  $year >= 1900; # "2005" --> "105"
  }

  else {
    print STDERR "WARNING: unsupported date format '$date'\n";
    return 0;
  }

  return timegm($sec, $min, $hour, $day, $mon, $year) if $date =~ /gmt/i;
  return timelocal($sec, $min, $hour, $day, $mon, $year);
}

###############################################################################
# fault tolerant wrapper
sub formatTime {
  my ($time, $format) = @_;

  $time ||= 0;

  unless ($time =~ /^\d+$/) {
    $time = parseTime($time);
  }

  return TWiki::Func::formatTime($time, $format)
}


###############################################################################
# used to encode rss feeds
sub rss {
  my ($text, $web, $topic) = @_;

  $text = "\n<noautolink>\n$text\n</noautolink>\n";
  $text = TWiki::Func::expandCommonVariables($text, $topic, $web);
  $text = TWiki::Func::renderText($text);
  $text =~ s/\b(onmouseover|onmouseout|style)=".*?"//go; # TODO filter out more not validating attributes
  $text =~ s/<nop>//go;
  $text =~ s/[\n\r]+/ /go;
  $text =~ s/\n*<\/?noautolink>\n*//go;
  $text =~ s/([[\x01-\x09\x0b\x0c\x0e-\x1f"%&'*<=>@[_\|])/'&#'.ord($1).';'/ge;
  $text =~ s/^\s*(.*?)\s*$/$1/gos;

  return $text;
}

###############################################################################
sub entityEncode {
  my $text = shift;

  $text =~ s/([[\x01-\x09\x0b\x0c\x0e-\x1f"%&'*<=>@[_\|])/'&#'.ord($1).';'/ge;

  return $text;
}

###############################################################################
sub entityDecode {
  my $text = shift;

  $text =~ s/&#(\d+);/chr($1)/ge;
  return $text;
}

###############################################################################
sub urlEncode {
  my $text = shift;

  $text =~ s/([^0-9a-zA-Z-_.:~!*'\/%])/'%'.sprintf('%02x',ord($1))/ge;

  return $text;
}

###############################################################################
sub urlDecode {
  my $text = shift;

  $text =~ s/%([\da-f]{2})/chr(hex($1))/gei;

  return $text;
}

###############################################################################
sub flatten {
  my $text = shift;

  $text =~ s/&lt;/</g;
  $text =~ s/&gt;/>/g;

  $text =~ s/\<[^\>]+\/?\>//g;
  $text =~ s/<\!\-\-.*?\-\->//gs;
  $text =~ s/\&[a-z]+;/ /g;
  $text =~ s/[ \t]+/ /gs;
  $text =~ s/%//gs;
  $text =~ s/_[^_]+_/ /gs;
  $text =~ s/\&[a-z]+;/ /g;
  $text =~ s/\&#[0-9]+;/ /g;
  $text =~ s/[\r\n\|]+/ /gm;
  $text =~ s/\[\[//go;
  $text =~ s/\]\]//go;
  $text =~ s/\]\[//go;
  $text =~ s/([[\x01-\x09\x0b\x0c\x0e-\x1f"%&'*<=>@[_\|])/'&#'.ord($1).';'/ge;
  $text =~ s/(https?)/<nop>$1/go;
  $text =~ s/\b($wikiWordRegex)\b/<nop>$1/g;

  return $text;
}

###############################################################################
sub extractPattern {
  my ($topicObj, $pattern) = @_;

  my $text = $topicObj->fastget('text') || '';
  my $result = '';
  while ($text =~ /$pattern/gs) {
    $result .= ($1 || '');
  }
  
  return $result;
}


###############################################################################
sub inlineError {
  return "<div class=\"twikiAlert\">$_[0]</div>";
}


###############################################################################
1;
