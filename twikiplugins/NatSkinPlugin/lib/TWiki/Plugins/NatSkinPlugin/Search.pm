###############################################################################
# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2003-2006 MichaelDaum@WikiRing.com
#
# Based on photonsearch
# Copyright (C) 2001 Esteban Manchado Velázquez, zoso@foton.es
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
package TWiki::Plugins::NatSkinPlugin::Search;

use strict;
use vars qw($isInitialized $debug $includeWeb $excludeWeb 
            $includeTopic $excludeTopic $dataDir $wikiToolName $wikiUserName
	    $sandbox  $specialCharPattern);
use URI::Escape;
use TWiki::Plugins::NatSkinPlugin;

$debug = 0; # toggle me
$specialCharPattern = qr/([^\\])([\$\@\%\&\#\'\`\/])/o;

###############################################################################
sub writeDebug {
  #&TWiki::Func::writeDebug("- NatSkinPlugin::Search - " . $_[0]) if $debug;
  print STDERR "NatSkinPlugin::Search - $_[0]\n" if $debug;
}

##############################################################################
sub doInit {
  return if $isInitialized;
  $isInitialized = 1;

  unless (defined &TWiki::Sandbox::new) {
    eval "use TWiki::Contrib::DakarContrib;";
    $sandbox = new TWiki::Sandbox();
  } else {
    $sandbox = $TWiki::sharedSandbox;
  }
  $dataDir = &TWiki::Func::getDataDir();
  $wikiToolName = &TWiki::Func::getWikiToolName() || '';
  $wikiUserName = &TWiki::Func::getWikiUserName();

  &TWiki::Plugins::NatSkinPlugin::doInit();
  #writeDebug("done init()");
}

##############################################################################
# wrapper for dakar's TWiki::UI:run interface
sub natSearchCgi {
  my $session = shift;
  $TWiki::Plugins::SESSION = $session;
  my $text = natSearch($session->{cgiQuery}, $session->{topicName}, $session->{webName});
  $session->writeCompletePage($text, 'view');
}

##############################################################################
# returns the full text of the search
sub natSearch {
  my ($query, $topic, $web) = @_;

  #writeDebug("called natSearch()");
  &doInit();

  my $theSearchString = $query->param('search') || '';
  my $theWeb = $query->param('web') || $web;
  my $theIgnoreCase = $query->param('ignorecase') || '';
  my $origSearch = $theSearchString;
  my $searchTemplate;
  my $theGlobalSearch;
  my $theContentSearch;

  # get web preferences
  $includeWeb = &TWiki::Func::getPreferencesValue('NATSEARCHINCLUDEWEB') || '';
  $excludeWeb = &TWiki::Func::getPreferencesValue('NATSEARCHEXCLUDEWEB') || '';
  $includeTopic = &TWiki::Func::getPreferencesValue('NATSEARCHINCLUDETOPIC') || '';
  $excludeTopic = &TWiki::Func::getPreferencesValue('NATSEARCHEXCLUDETOPIC') || '';
  $searchTemplate = &TWiki::Func::getPreferencesValue('NATSEARCHTEMPLATE') || '';
  $theIgnoreCase = &TWiki::Func::getPreferencesFlag('NATSEARCHIGNORECASE') unless $theIgnoreCase;
  $theGlobalSearch = &TWiki::Func::getPreferencesFlag('NATSEARCHGLOBAL') || 0;
  $theContentSearch = &TWiki::Func::getPreferencesFlag('NATSEARCHCONTENT') || 0;
  $includeWeb =~ s/^\s*(.*)\s*$/$1/o;
  $excludeWeb =~ s/^\s*(.*)\s*$/$1/o;
  $includeTopic =~ s/^\s*(.*)\s*$/$1/o;
  $excludeTopic =~ s/^\s*(.*)\s*$/$1/o;

  #writeDebug("searchTemplate name =$searchTemplate");
  if ($searchTemplate) {
    $searchTemplate = &TWiki::Func::readTemplate($searchTemplate);
  }
  unless ($searchTemplate) {
    $searchTemplate =  &TWiki::Func::readTemplate('search');
  }
  $searchTemplate =~ s/^\s*(.*)\s*$/$1/os;
  #writeDebug("searchTemplate='$searchTemplate'");
  writeDebug("search=$theSearchString");
  writeDebug("wikiUserName=$wikiUserName");
  writeDebug("theWeb=$theWeb");
  writeDebug("theIgnoreCase=$theIgnoreCase");
  writeDebug("includeWeb=$includeWeb");
  writeDebug("excludeWeb=$excludeWeb");
  writeDebug("includeTopic=$includeTopic");
  writeDebug("excludeTopic=$excludeTopic");
  
  # separate and process options
  my $options = "";
  if ($theSearchString =~ s/^(.*?)://) {
    $options = $1;
  }
  #writeDebug("options=$options");
  my $doIgnoreCase = ($options =~ /u/ || $theIgnoreCase) ? 1 : 0;

  # construct the list of webs to search in
  my @webList = ($theWeb);
  if (($options =~ /g/ || $theGlobalSearch) && !($options =~ /l/)) {
    @webList = TWiki::Func::getPublicWebList();
    @webList = grep (/^$includeWeb$/, @webList) if $includeWeb;
    @webList = grep (!/^$excludeWeb$/, @webList) if $excludeWeb;
    @webList = grep (!/^$theWeb$/, @webList);
    unshift @webList, $theWeb;
  }

  # redirect according to the look of the string
  # (1) the string starts with an uppercase letter: 
  #     (1.1) try a GO
  #     (1.2) fallback to a topic search when (1.1) fails
  #     (1.3) fallback to content search when (1.2) fails
  # (2) the string starts with a / 
  #     normal content search
  # (3) the string does not start with an upper case letter or /
  #     (3.1) try a topic search
  #     (3.2) fallback to content search
  my ($results, $nrHits);
  if ($theSearchString =~ /^[A-Z]/) {
    if ($theSearchString =~ /^(.*)\.(.*?)$/) {  # Special web.topic notation
      @webList = ($1);
      $theSearchString = $2;
    }

    # (1.1) normal Go behaviour
    foreach my $thisWeb (@webList) {
      if (&TWiki::Func::topicExists($thisWeb, $theSearchString)) {
	my $viewUrl = &TWiki::Func::getViewUrl($thisWeb, $theSearchString);
	&TWiki::Func::redirectCgiQuery($query, $viewUrl);
	#writeDebug("done");
	return '';
      } 
    }
    
    # (1.2) fallback to topic search
    ($results, $nrHits) = 
      natTopicSearch($theSearchString, \@webList, $doIgnoreCase, $wikiUserName);

    # (1.3) fallback to content search
    if ($nrHits == 0) { 
      ($results, $nrHits) = 
	natContentsSearch($theSearchString, \@webList, $doIgnoreCase, $wikiUserName);
    } 
  } 
  
  # (2) content search
  elsif ($theSearchString =~ /^\/(.+)$/ || $theContentSearch) { # Normal search
    $theSearchString = $1; 
    ($results, $nrHits) = 
      natContentsSearch($theSearchString, \@webList, $doIgnoreCase, $wikiUserName);
  }
  
  # (3)
  else { 
  
    # (3.1) topic name search
    ($results, $nrHits) = 
      natTopicSearch($theSearchString, \@webList, $doIgnoreCase, $wikiUserName);

    # (3.2) fallback to content search
    if ($nrHits == 0) { 
      ($results, $nrHits) = 
	natContentsSearch($theSearchString, \@webList, $doIgnoreCase, $wikiUserName);
    }
  }
      
  # If there is only one result, redirect to that node
  if ($nrHits == 1) {
    my $resultWeb = (keys %$results)[0];
    my $resultTopic = $results->{$resultWeb}[0];
    my $viewUrl = &TWiki::Func::getViewUrl($resultWeb, $resultTopic);
    &TWiki::Func::redirectCgiQuery($query, $viewUrl);
    #writeDebug("done");
    return '';
  }

  # Else, print them
  my $result = '';
  my ($tmplHead, $tmplSearch, $tmplTable, $tmplNumber, $tmplTail) = 
    split(/%SPLIT%/,$searchTemplate);


  #writeDebug("tmplHead='$tmplHead'");
  #writeDebug("tmplSearch='$tmplSearch'");
  #writeDebug("tmplTable='$tmplTable'");
  #writeDebug("tmplNumber='$tmplNumber'");
  #writeDebug("tmplTail='$tmplTail'");

  $tmplHead = &TWiki::Func::expandCommonVariables($tmplHead, $topic);
  $tmplHead = &TWiki::Func::renderText($tmplHead);
  $tmplHead =~ s|</*nop/*>||goi;
  $tmplHead =~ s/%TOPIC%/$topic/go;
  $tmplHead =~ s/%SEARCHSTRING%/$origSearch/go;
  $result .= $tmplHead;

  if ($nrHits) {
    $tmplNumber =~ s/%NTOPICS%/$nrHits/go;
    $tmplNumber = &TWiki::Func::expandCommonVariables($tmplNumber, $topic);
    $result .= $tmplNumber;
    $result .= _getSearchResult($tmplTable, $results, $theSearchString);
  } else {
    my $text = &TWiki::Func::expandCommonVariables('%TMPL:P{"NOTHING_FOUND"}%');
    $result .= '<div class="natSearchMessage">'.$text."</div>\n";
  }

  # get last part of full HTML page
  $tmplTail = &TWiki::Func::expandCommonVariables($tmplTail, $topic);
  $tmplTail = &TWiki::Func::renderText($tmplTail);
  $tmplTail =~ s|</*nop/*>||goi;   # remove <nop> tag
  $result .= $tmplTail;

  #writeDebug("done natSearch()");

  return $result;
}

##############################################################################
sub natTopicSearch {
  my ($theSearchString, $theWebList, $doIgnoreCase, $theUser) = @_;

  my $nrHits = 0;
  my $results = {};

  if ($debug) {
    #writeDebug("called natTopicSearch()");
    #writeDebug("doIgnoreCase=$doIgnoreCase");
    #writeDebug("theWebList=" . join(" ", @$theWebList));
  }

  if ($theSearchString eq '') {
    #writeDebug("empty search string");
    return ($results, $nrHits);
  }

  my @searchTerms = _getSearchTerms($theSearchString);

  # collect the results for each web, put them in $results->{}
  foreach my $thisWebName (@$theWebList) {
    # get all topics
    $thisWebName =~ s/\./\//go;
    my $webDir = TWiki::Sandbox::normalizeFileName("$dataDir/$thisWebName");
    opendir(DIR, $webDir) || die "can't opendir $webDir: $!";
    my @topics = map {s/\.txt$//; $_} grep {/\.txt$/} readdir(DIR);
    @topics = grep(/$includeTopic/, @topics) if $includeTopic;
    @topics = grep(!/$excludeTopic/, @topics) if $excludeTopic;
    closedir DIR;

    # filter topics
    foreach my $searchTerm (@searchTerms) {
      my $pattern = $searchTerm;
      #writeDebug("pattern=$pattern");
      eval {
	if ($pattern =~ s/^-//) {
	  if ($doIgnoreCase) {
	    @topics = grep(!/$pattern/i, @topics);
	  } else {
	    @topics = grep(!/$pattern/, @topics);
	  }
	} else {
	  if ($doIgnoreCase) {
	    @topics = grep(/$pattern/i, @topics);
	  } else {
	    @topics = grep(/$pattern/, @topics);
	  }
	}
      };
      if ($@) {
	&TWiki::Func::writeWarning("natsearch: pattern=$pattern failed to compile");
	return ({}, 0);
      }
    }

    # filter out non-viewable topics
    @topics = 
      grep {&TWiki::Func::checkAccessPermission("view", $theUser, undef, $_, $thisWebName);}
      @topics;


    if (@topics) {
      $nrHits += scalar @topics;
      $results->{$thisWebName} = [@topics] ;
      #writeDebug("in $thisWebName: found topics " . join(", ", @topics));
    } else {
      #writeDebug("nothing found in $thisWebName");
    }
  }

  #writeDebug("done natTopicSearch()");
  return ($results, $nrHits);
}

##############################################################################
sub natContentsSearch {
  my ($theSearchString, $theWebList, $doIgnoreCase, $theUser) = @_;

  if ($debug) {
    #writeDebug("called natContentsSearch()");
    #writeDebug("doIgnoreCase=$doIgnoreCase");
    #writeDebug("theWebList=" . join(" ", @$theWebList));
  }

  my $cmdTemplate = "/bin/egrep -l$doIgnoreCase %PATTERN|U% %FILES|F%";
  my $results = {};
  my $nrHits = 0;
  my @searchTerms = _getSearchTerms($theSearchString);

  if (!@searchTerms) {
    return ($results, $nrHits);
  }

  # Collect the results for each web, put them in $results->{}
  foreach my $thisWebName (@$theWebList) {

    #writeDebug("searching in $thisWebName");

    # get all topics
    $thisWebName =~ s/\./\//go;
    my $webDir = TWiki::Sandbox::normalizeFileName("$dataDir/$thisWebName");
    opendir(DIR, $webDir) || die "can't opendir $webDir: $!";
    my @bag = grep {/\.txt$/} readdir(DIR);
    @bag = grep(/$includeTopic/, @bag) if $includeTopic;
    @bag = grep(!/$excludeTopic/, @bag) if $excludeTopic;
    closedir DIR;
    chdir($webDir);

    # grep files in bag
    foreach my $searchTerm (@searchTerms) {
      next unless $searchTerm;
      #writeDebug("before bag=@bag");

      # can't modify $searchTerm directly
      my $pattern = $searchTerm;
      #writeDebug("pattern=$pattern");

      if ($pattern =~ s/^-//) {
	my @notfiles = "";
	eval {
	  my ($result, $code) = $sandbox->sysCommand($cmdTemplate,
	    PATTERN => $pattern, FILES => \@bag);
	  @notfiles = split(/\r?\n/, $result);
	};
	if ($@) {
	  &TWiki::Func::writeWarning("natsearch: pattern=$pattern files=@bag - $@");
	  return ({}, 0);
	}
	chomp(@notfiles);

	# substract notfiles from bag
	my @f = ();
	foreach my $k (@bag) {
	  push @f, $k unless grep { $k eq $_ } @notfiles;
	}
	@bag = @f;
      } else {
	eval {
	  my ($result, $code) = 
	    $sandbox->sysCommand($cmdTemplate, PATTERN => $pattern, FILES => \@bag); 
	  @bag = split(/\r?\n/, $result);
	  #writeDebug("code=$code, result=$result");
	};
	if ($@) {
	  &TWiki::Func::writeWarning("natsearch: pattern=$pattern files=@bag - $@");
	  return ({}, 0);
	}
	chomp(@bag);
      }
    }
    #writeDebug("after bag=@bag");

    # strip ".txt" extension
    @bag = map { s/\.txt$//; $_ } @bag;


    # filter out non-viewable topics
    @bag = 
      grep {&TWiki::Func::checkAccessPermission("view", $theUser, "", $_, $thisWebName);} @bag;

    if (@bag) {
      $nrHits += scalar @bag;
      $results->{$thisWebName} = [ @bag ] ;
    }
  }

  #writeDebug("done natContentsSearch()");
  return ($results, $nrHits);
}

##############################################################################
sub _getSearchResult {
  my ($theTemplate, $theResults, $theSearchString) = @_;

  my $noSpamPadding = $TWiki::cfg{AntiSpam}{EmailPadding};
  my $result = '';
      
  # get hits in all webs
  foreach my $thisWeb (sort keys %{$theResults}) {
    my ($beforeText, $repeatText, $afterText) = split(/%REPEAT%/, $theTemplate);

    # get web header
    $beforeText =~ s/%WEB%/$thisWeb/o;
    $beforeText = &TWiki::Func::expandCommonVariables($beforeText, $thisWeb);
    $afterText  = &TWiki::Func::expandCommonVariables($afterText, $thisWeb);
    $beforeText = &TWiki::Func::renderText($beforeText, $thisWeb);
    $beforeText =~ s|</*nop/*>||goi;   # remove <nop> tag
    $result .= $beforeText;

    # sort topics by modification time, reverse
    my @sortedTopics =
	  map { $_->[1] }
	    sort {$b->[0] <=> $a->[0] }
	      map { [ &getModificationTime($thisWeb, $_ ), $_ ] }
		@{$theResults->{$thisWeb}};

    # get hits in all topics
    my $index = 0;
    foreach my $thisTopic (@sortedTopics) {
      my $tempVal = $repeatText;

      # get topic information
      my ($meta, $text) = &TWiki::Func::readTopic($thisWeb, $thisTopic);
      my ($revDate, $revUser, $revNum ) = $meta->getRevisionInfo();
      $revUser = $revUser->webDotWikiName() if $revUser;
      $revUser = &TWiki::Func::userToWikiName($revUser);
      $revDate = &TWiki::Func::formatTime($revDate);
      #writeDebug("revDate=$revDate, revUser=$revUser, revNum=$revNum");

      # insert the topic information into the template
      $tempVal =~ s/%WEB%/$thisWeb/go;
      $tempVal =~ s/%TIME%/$revDate/go;
      $tempVal =~ s/%TOPICNAME%/$thisTopic/go;
      if ($revNum > 1) {
	$revNum = "r1.$revNum";
      } else {
	$revNum = '<span class="natSearchNewTopic">%TMPL:P{"NEW"}%</span>';
      } 
      $tempVal =~ s/%REVISION%/$revNum/go;
      $tempVal =~ s/%AUTHOR%/$revUser/go;

      # render twiki markup
      $tempVal = &TWiki::Func::expandCommonVariables($tempVal, $thisTopic);
      $tempVal = &TWiki::Func::renderText($tempVal);

      # remove mail trace
      $text =~ s/([A-Za-z0-9\.\+\-\_]+)\@([A-Za-z0-9\.\-]+\..+?)/$1$noSpamPadding$2/go;

      # render search hit
      my @searchTerms = _getSearchTerms($theSearchString);
      my $summary = _getTopicSummary($text, $thisTopic, $thisWeb, @searchTerms);
      
      $tempVal =~ s/%TEXTHEAD%/$summary/go;
      $tempVal =~ s|</*nop/*>||goi;   # remove <nop> tag

      # fiddle in even/odd CSS classes
      my $hitClass = ($index % 2)?'natSearchEvenHit':'natSearchOddHit';
      $index++;
      $tempVal =~ s/(class="natSearchHit)"/$1 $hitClass"/g;

      # get this hit
      $result .= $tempVal;
    }

    $afterText = &TWiki::Func::renderText($afterText, $thisWeb);
    $afterText =~ s|</*nop/*>||goi;   # remove <nop> tag
    $result .= $afterText;
  }
  return $result;
}

##############################################################################
sub _getTopicSummary {
  my ($theText, $theTopic, $theWeb, @theKeywords) = @_;

  my $htext = $theText;
  $htext =~ s/<\!\-\-.*?\-\->//gos;  # remove all HTML comments
  $htext =~ s/<\!\-\-.*$//os;        # remove cut HTML comment
  $htext =~ s/<[^>]*>//go;           # remove all HTML tags
  $htext =~ s/%WEB%/$theWeb/go;      # resolve web
  $htext =~ s/%TOPIC%/$theTopic/go;  # resolve topic
  $htext =~ s/%WIKITOOLNAME%/$wikiToolName/go; # resolve TWiki tool
  $htext =~ s/%META:.*?%//go;        # Remove meta data variables
  $htext =~ s/[\%\[\]\*\|=_]/ /go;   # remove Wiki formatting chars & defuse %VARS%
  $htext =~ s/\-\-\-+\+*/ /go;       # remove heading formatting
  $htext =~ s/\s+[\+\-]*/ /go;       # remove newlines and special chars

  # store first found word (some of them can be found in metadata instead of
  # in the text)
  my $firstfound = undef;
  my $errorFound = 0;
  foreach my $keyWord (@theKeywords) {
    eval {
      if ($htext =~ /$keyWord/i) {
	$firstfound = $keyWord;
      }
    };
    if ($@) {
      &TWiki::Func::writeWarning("natsearch: keyWord=$keyWord failed to compile");
      $errorFound = 1;
      last;
    }
    last if $firstfound;
  }
  return '' if $errorFound;

  # limit to 162 chars, according to the position of the first keyword ...
  if (defined $firstfound) {
    $htext =~ s/^.*?([a-zA-Z0-9]*.{0,81})($firstfound)(.{0,81}[a-zA-Z0-9]*).*?$/$1$2$3/gi;
  } else {
    $htext =~ s/(.{162})([a-zA-Z0-9]*)(.*?)$/$1$2/go;
  }
  $htext = substr($htext, 0, 300) . " ..."; # Limit string length

  # ... but hilight all of them
  foreach my $k (@theKeywords) {
    $htext =~ s:($k):<font color="#cc0000">$1</font>:gi;
  }

  # inline search renders text, 
  # so prevent linking of external and internal links:
  $htext =~ s/([\-\*\s])((http|ftp|gopher|news|file|https)\:)/$1<nop>$2/go;
  $htext =~ s/([\s\(])([A-Z]+[a-z0-9]*\.[A-Z]+[a-z]+[A-Z]+[a-zA-Z0-9]*)/$1<nop>$2/go;
  $htext =~ s/([\s\(])([A-Z]+[a-z]+[A-Z]+[a-zA-Z0-9]*)/$1<nop>$2/go;
  $htext =~ s/([\s\(])([A-Z]{3,})/$1<nop>$2/go;
  $htext =~ s/@([a-zA-Z0-9\-\_\.]+)/@<nop>$1/go;

  $htext = &TWiki::Func::renderText($htext, $theWeb);
  return $htext;
}

##############################################################################
sub _getSearchTerms {
  my $theSearchString = shift ;

  # Figure out search terms
  my @searchTerms = ();
  while($theSearchString =~ s/(-?)"([^"]*)"//) {
    my $flag = $1;
    my $pattern = $2;
    $pattern =~ s/$specialCharPattern/$1\\$2/go;  # escape some special chars
    push @searchTerms, $flag . $pattern;
  }
  # Escape unmatched quotes
  $theSearchString =~ s/"/\\"/;
  foreach my $pattern (split(/\s/, $theSearchString)) {
    $pattern =~ s/$specialCharPattern/$1\\$2/go;  # escape some special chars
    push @searchTerms, $pattern;
  }

  return @searchTerms;
}

##############################################################################
# own filebased checker, breaks on other storage impls, breaks before anyway
sub getModificationTime {
  my $date = 0;
  my $file = $dataDir.'/'.$_[0].'/'.$_[1].'.txt';
  if (-e $file) {
    $date = (stat $file)[9] || 600000000;
  }
  return $date;
}


1;
