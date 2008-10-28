# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005-2006 MichaelDaum@WikiRing.com
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
  $TranslationToken $debug %webDB %webDBIsModified $wikiWordRegex $webNameRegex
  $defaultWebNameRegex $linkProtocolPattern
);

use TWiki::Contrib::DBCacheContrib;
use TWiki::Contrib::DBCacheContrib::Search;
use TWiki::Plugins::DBCachePlugin::WebDB;

$TranslationToken = "\0"; # from TWiki.pm
$debug = 0; # toggle me

###############################################################################
sub writeDebug {
  #&TWiki::Func::writeDebug('- DBCachePlugin - '.$_[0]) if $debug;
  print STDERR "- DBCachePlugin - $_[0]\n" if $debug;
}

###############################################################################
sub afterSaveHandler {

  # force reload
  my $theDB = getDB($TWiki::Plugins::DBCachePlugin::currentWeb);
  #writeDebug("touching webdb for $TWiki::Plugins::DBCachePlugin::currentWeb");
  $theDB->touch();
  if ($TWiki::Plugins::DBCachePlugin::currentWeb ne $_[2]) {
    $theDB = getDB($_[2]); 
    #writeDebug("touching webdb for $_[2]");
    $theDB->touch();
  }
}

###############################################################################
sub handleDBQUERY {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called handleDBQUERY(" . $params->stringify() . ")");

  # params
  my $theSearch = $params->{_DEFAULT} || $params->{search};
  my $thisTopic = $params->{topic} || '';
  my $theTopics = $params->{topics} || '';
  my $theFormat = $params->{format} || '$topic';
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $theInclude = $params->{include};
  my $theExclude = $params->{exclude};
  my $theSort = $params->{sort} || $params->{order} || 'name';
  my $theReverse = $params->{reverse} || 'off';
  my $theSep = $params->{separator} || $params->{sep} || '$n';
  my $theLimit = $params->{limit} || '';
  my $theSkip = $params->{skip} || 0;
  my $theHideNull = $params->{hidenull} || 'off';
  my $theRemote = $params->remove('remote') || 'off';
  $theRemote = ($theRemote =~ /^(on|force|1|yes)$/)?1:0;
  $theRemote = ($theRemote eq 'on')?1:0;

  # get web and topic(s)
  my @topicNames = ();
  my $thisWeb = $params->{web} || $theWeb;
  if ($thisTopic) {
    ($thisWeb, $thisTopic) = TWiki::Func::normalizeWebTopicName($thisWeb, $thisTopic);
    push @topicNames, $thisTopic;
  } else {
    if ($theTopics) {
      @topicNames = split(/[,\s+]/, $theTopics);
    }
  }
  my $theDB = getDB($thisWeb);

  # normalize 
  $theSkip =~ s/[^-\d]//go;
  $theSkip = 0 if $theSkip eq '';
  $theSkip = 0 if $theSkip < 0;
  $theFormat = '' if $theFormat eq 'none';
  $theSep = '' if $theSep eq 'none';

  my ($topicNames, $hits, $msg) = $theDB->dbQuery($theSearch, 
    \@topicNames, $theSort, $theReverse, $theInclude, $theExclude);

  return _inlineError($msg) if $msg;

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
      $index++;
      next if $index <= $theSkip;
      my $topicObj = $hits->{$topicName};
      my $topicWeb = $topicObj->fastget('web');
      my $format = '';
      $format = $theSep unless $isFirst;
      $isFirst = 0;
      $format .= $theFormat;
      $format =~ s/\$formfield\((.*?)\)/
	my $temp = $theDB->getFormField($topicName, $1);
	$temp =~ s#\)#${TranslationToken}#g;
	$temp/geo;
      $format =~ s/\$expand\((.*?)\)/
        my $temp = $1;
        $temp = _expandVariables($temp, $topicWeb, $topicName,
          topic=>$topicName, web=>$topicWeb, index=>$index, count=>$count);
	$temp = $theDB->expandPath($topicObj, $temp);
	$temp =~ s#\)#${TranslationToken}#g;
	$temp/geo;
      $format =~ s/\$formatTime\((.*?)(?:,\s*'([^']*?)')?\)/TWiki::Func::formatTime($theDB->expandPath($topicObj, $1), $2)/geo; # single quoted
      $format = _expandVariables($format, $topicWeb, $topicName,
	topic=>$topicName, web=>$topicWeb, index=>$index, count=>$count);
      $format =~ s/${TranslationToken}/)/go;
      $format = &TWiki::Func::expandCommonVariables($format, $topicName, $topicWeb);
      $text .= $format;

      $TWiki::Plugins::DBCachePlugin::addDependency->($topicWeb, $topicName);

      last if $index == $theLimit;
    }
  }

  $theHeader = _expandVariables($theHeader, $theWeb, $theTopic, count=>$count, web=>$thisWeb) if $theHeader;
  $theFooter = _expandVariables($theFooter, $theWeb, $theTopic, count=>$count, web=>$thisWeb) if $theFooter;

## DISABLED
#  $text = &TWiki::Func::expandCommonVariables("$theHeader$text$theFooter", 
#    $theTopic, $theWeb);
##
  $text = $theHeader.$text.$theFooter;

  _fixInclude($session, $thisWeb, $text) if $theRemote;

  return $text;
}

###############################################################################
sub handleDBCALL {
  my ($session, $params, $theTopic, $theWeb) = @_;

  my $thisTopic = $params->remove('_DEFAULT');
  return '' unless $thisTopic;
  my $thisWeb;
  ($thisWeb, $thisTopic) = &TWiki::Func::normalizeWebTopicName($theWeb, $thisTopic);

  $TWiki::Plugins::DBCachePlugin::addDependency->($thisWeb, $thisTopic);

  # remember args for the key before mangling the params
  my $args = $params->stringify();

  #writeDebug("called handleDBCALL()");

  my $section = $params->remove('section') || 'default';
  my $warn = $params->remove('warn') || 'on';
  $warn = ($warn eq 'on')?1:0;
  my $remote = $params->remove('remote') || 'off';
  $remote = ($remote =~ /^(on|force|1|yes)$/)?1:0;

  #writeDebug("thisWeb=$thisWeb thisTopic=$thisTopic theWeb=$theWeb theTopic=$theTopic");

  # get web and topic
  my $thisDB = getDB($thisWeb);
  my $topicObj = $thisDB->fastget($thisTopic);
  unless ($topicObj) {
    if ($warn) {
      return _inlineError("ERROR: DBCALL can't find topic <nop>$thisTopic in <nop>$thisWeb");
    } else {
      return '';
    }
  }

  # check access rights
  my $wikiUserName = TWiki::Func::getWikiUserName();
  unless (TWiki::Func::checkAccessPermission('VIEW', $wikiUserName, undef, $thisTopic, $thisWeb)) {
    if ($warn) {
      return _inlineError("ERROR: DBCALL access to '$thisWeb.$thisTopic' denied");
    } 
    return '';
  }


  # get section
  my $sectionText = $topicObj->fastget("_section$section") if $topicObj;
  if (!$sectionText) {
    if($warn) {
      return _inlineError("ERROR: DBCALL can't find section '$section' in topic '$thisWeb.$thisTopic'");
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
      return _inlineError("ERROR: DBCALL reached max recursion at '$thisWeb.$thisTopic'");
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
  $sectionText = TWiki::Func::expandCommonVariables($sectionText, $thisTopic, $thisWeb);

  # fix local linx
  _fixInclude($session, $thisWeb, $sectionText) if $remote;

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
  my $thisWeb = $params->{web} || $theWeb;
  my $thePattern = $params->{pattern} || '(\w+)';
  my $theHeader = $params->{header} || '';
  my $theFormat = $params->{format} || '   * $key: $count';
  my $theFooter = $params->{footer} || '';
  my $theSep = $params->{separator} || $params->{sep} || '$n';
  my $theFields = $params->{fields} || $params->{field} || 'text';
  my $theSort = $params->{sort} || $params->{order} || 'alpha';
  my $theReverse = $params->{reverse} || 'off';
  my $theLimit = $params->{limit} || 0;
  my $theHideNull = $params->{hidenull} || 'off';
  $theLimit =~ s/[^\d]//go;

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
  my $wikiUserName = TWiki::Func::getWikiUserName();
  my %statistics = ();
  my $theDB = getDB($thisWeb);
  my @topicNames = $theDB->getKeys();
  foreach my $topicName (@topicNames) { # loop over all topics
    my $topicObj = $theDB->fastget($topicName);
    next unless $search->matches($topicObj); # that match the query
    next unless TWiki::Func::checkAccessPermission('VIEW', 
      $wikiUserName, undef, $topicName, $thisWeb);

    #writeDebug("found topic $topicName");
    my $createdate = $topicObj->fastget('createdate');
    foreach my $field (split(/,\s/, $theFields)) { # loop over all fields
      my $fieldValue = $topicObj->fastget($field);
      unless ($fieldValue) {
	my $topicForm = $topicObj->fastget('form');
	#writeDebug("found form $topicForm");
	if ($topicForm) {
	  $topicForm = $topicObj->fastget($topicForm);
	  $fieldValue = $topicForm->fastget($field);
	}
      }
      next unless $fieldValue; # unless present
      #writeDebug("reading field $field");

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
    $result .= &_expandVariables($text, 
      $thisWeb,
      $theTopic,
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
  $theHeader = &_expandVariables($theHeader, $thisWeb, $theTopic);
  $theFooter = &_expandVariables($theFooter, $thisWeb, $theTopic);
  $result = &TWiki::Func::expandCommonVariables($theHeader.$result.$theFooter, $theTopic, $thisWeb);

  return $result;
}

###############################################################################
sub handleDBDUMP {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called handleDBDUMP");

  my $thisTopic = $params->{_DEFAULT} || $theTopic;
  my $thisWeb = $params->{web} || $theWeb;
  ($thisWeb, $thisTopic) = TWiki::Func::normalizeWebTopicName($thisWeb, $thisTopic);

  $TWiki::Plugins::DBCachePlugin::addDependency->($thisWeb, $thisTopic);

  my $theDB = getDB($thisWeb);

  my $topicObj = $theDB->fastget($thisTopic) || '';
  unless ($topicObj) {
    return _inlineError("$thisWeb.$thisTopic not found");
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
    $result .= "<tr><th>$key</th><td>$value</td></tr>\n" if $value;
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
      $result .= "<tr><th>$key</th><td>$value</td>\n" if $value;
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
        $result .= "<tr><th>$key</th><td>$value</td></tr>\n" if $value;
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

  # get parameters
  my $thisTopic = $params->{_DEFAULT} || $params->{topic} || $theTopic;
  my $thisWeb = $params->{web} || $theWeb;
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
  my $theFormat = $params->{format} || '| [[$url][$name]] |  $sizeK | <nobr>$date</nobr> | $wikiuser | $comment |';
  my $theSeparator = $params->{separator} || $params->{sep} || "\n";
  my $theSort = $params->{sort} || $params->{order} || 'name';
  my $theHideNull = $params->{hidenull} || 'off';
  my $theComment = $params->{comment} = '.*';

  # get topic
  my $theDB = getDB($thisWeb);
  my $topicObj = $theDB->fastget($thisTopic) || '';
  return _inlineError("$thisWeb.$thisTopic not found") unless $topicObj;

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

  writeDebug("called handleATTACHMENTS($thisWeb, $thisTopic)");


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

    my $user = $attachment->fastget('user');
    if (defined(&TWiki::Users::getWikiName)) {# TWiki-4.2 onwards
      my $session = $TWiki::Plugins::SESSION;
      $user = $session->{users}->getWikiName($user);
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
    $text =~ s/\$date\(([^\)]+)\)/TWiki::Func::formatTime($date, $1)/ge;
    $text = _expandVariables($text, $thisWeb, $thisTopic,
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
      'date'=>TWiki::Func::formatTime($date),
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

  $theHeader = _expandVariables($theHeader, $thisWeb, $thisTopic, count=>$index);
  $theFooter = _expandVariables($theFooter, $thisWeb, $thisTopic, count=>$index);

  return $theHeader.join($theSeparator,@result).$theFooter;
}

###############################################################################
sub handleDBRECURSE {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called handleDBRECURSE(" . $params->stringify() . ")");

  $theTopic = $params->{_DEFAULT} || $params->{topic} || $theTopic;
  $theWeb = $params->{web} || $theWeb;
  ($theWeb, $theTopic) = &TWiki::Func::normalizeWebTopicName($theWeb, $theTopic);

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
  my $theDB = getDB($theWeb);
  $params->{_count} = 0;
  my $result = _formatRecursive($theDB, $theWeb, $theTopic, $params);
  return '' unless $result;

  # render result
  return '' if $params->{hidenull} eq 'on' && $params->{_count} == 0;

  return 
    _expandVariables(
      ($params->{_count} == 1)?$params->{singleheader}:$params->{header}, 
      $theWeb, $theTopic, 
      count=>$params->{_count}).
    join($params->{separator},@$result).
    _expandVariables(
      ($params->{_count} == 1)?$params->{singlefooter}:$params->{footer}, 
      $theWeb, $theTopic, 
      count=>$params->{_count});
}

###############################################################################
sub _formatRecursive {
  my ($theDB, $theWeb, $theTopic, $params, $seen, $depth, $number) = @_;

  # protection agains infinite recursion
  my %thisSeen;
  $seen ||= \%thisSeen;
  return if $seen->{$theTopic};
  $seen->{$theTopic} = 1;
  $depth ||= 0;
  $number ||= '';

  return if $params->{depth} && $depth >= $params->{depth};

  #writeDebug("called _formatRecursive($theWeb, $theTopic)");
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
    $text = _expandVariables($text, $theWeb, $theTopic,
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
    $text =~ s/\$formatTime\((.*?)(?:,\s*'([^']*?)')?\)/TWiki::Func::formatTime($theDB->expandPath($topicObj, $1), $2)/geo; # single quoted

    push @result, $text;

    # recurse
    my $subResult = 
      _formatRecursive($theDB, $theWeb, $topicName, $params, $seen, 
        $depth+1, $numberString);
    

    if ($subResult && @$subResult) {
      push @result, 
        _expandVariables($params->{subheader}, $theWeb, $topicName, 
          'web'=>$theWeb,
          'topic'=>$topicName,
          'number'=>$numberString,
          'index'=>$index,
          'count'=>$params->{_count},
        ).
        join($params->{separator},@$subResult).
        _expandVariables($params->{subfooter}, $theWeb, $topicName, 
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
  my $isModified = 0;
  unless (defined $webDB{$theWeb}) {
    # never loaded
    $isModified = 1;
    writeDebug("fresh reload of $theWeb");
  } else {
    unless (defined $webDBIsModified{$theWeb}) {
      # never checked
      $webDBIsModified{$theWeb} = $webDB{$theWeb}->isModified();
      if ($debug) {
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
    #writeDebug("loading new webdb for '$theWeb'");
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
sub _fixInclude {
  my $session = shift;
  my $thisWeb = shift;
  # $text next

  my $removed = {};

  # Must handle explicit [[]] before noautolink
  # '[[TopicName]]' to '[[Web.TopicName][TopicName]]'
  $_[0] =~ s/\[\[([^\]]+)\]\]/&_fixIncludeLink($thisWeb, $1)/geo;
  # '[[TopicName][...]]' to '[[Web.TopicName][...]]'
  $_[0] =~ s/\[\[([^\]]+)\]\[([^\]]+)\]\]/&_fixIncludeLink($thisWeb, $1, $2)/geo;

  $_[0] = $session->{renderer}->takeOutBlocks($_[0], 'noautolink', $removed);

  # 'TopicName' to 'Web.TopicName'
  $_[0] =~ s/(^|[\s(])($webNameRegex\.$wikiWordRegex)/$1$TranslationToken$2/go;
  $_[0] =~ s/(^|[\s(])($wikiWordRegex)/$1\[\[$thisWeb\.$2\]\[$2\]\]/go;
  $_[0] =~ s/(^|[\s(])$TranslationToken/$1/go;

  $session->{renderer}->putBackBlocks( \$_[0], $removed, 'noautolink');
}

###############################################################################
# from TWiki::_fixIncludeLink
sub _fixIncludeLink {
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
sub _expandVariables {
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
  $theFormat =~ s/\$flatten\((.*?)\)/&_flatten($1)/ges;
  $theFormat =~ s/\$encode\((.*?)\)/&_encode($1, $web, $topic)/ges;
  $theFormat =~ s/\$trunc\((.*?),\s*(\d+)\)/substr($1,0,$2)/ges;
  $theFormat =~ s/\$t\b/\t/go;
  $theFormat =~ s/\$dollar/\$/go;

  return $theFormat;
}

###############################################################################
# for rss
sub _encode {
  my ($text, $web, $topic) = @_;

  $text = "\n<noautolink>\n$text\n</noautolink>\n";
  $text = &TWiki::Func::expandCommonVariables($text, $topic, $web);
  $text = &TWiki::Func::renderText($text);
  $text =~ s/\b(onmouseover|onmouseout|style)=".*?"//go; # TODO filter out more not validating attributes
  $text =~ s/<nop>//go;
  $text =~ s/[\n\r]+/ /go;
  $text =~ s/\n*<\/?noautolink>\n*//go;
  $text =~ s/([[\x01-\x09\x0b\x0c\x0e-\x1f"%&'*<=>@[_\|])/'&#'.ord($1).';'/ge;
  $text =~ s/^\s*(.*?)\s*$/$1/gos;

  return $text;
}

###############################################################################
sub _flatten {
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
sub _inlineError {
  return "<div class=\"twikiAlert\">$_[0]</div>";
}


###############################################################################
1;
