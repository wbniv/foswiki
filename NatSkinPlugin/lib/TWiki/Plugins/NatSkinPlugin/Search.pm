###############################################################################
# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2003-2008 MichaelDaum http://michaeldaumconsulting.com
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
use TWiki::Plugins::NatSkinPlugin;
use constant DEBUG => 0; # toggle me

###############################################################################
sub writeDebug {
  DEBUG && print STDERR "NatSkinPlugin::Search - $_[0]\n";
}

##############################################################################
# wrapper for dakar's TWiki::UI:run interface
sub searchCgi {
  my $session = shift;

  $TWiki::Plugins::SESSION = $session;
  my $searcher = new TWiki::Plugins::NatSkinPlugin::Search($session);
  my $text = $searcher->search();

  $session->writeCompletePage($text, 'view');
}

##############################################################################
sub new {
  my $class = shift;
  my $session = shift;

  my $sandbox;
  unless (defined &TWiki::Sandbox::new) {
    writeDebug("this is this");
    eval "use TWiki::Contrib::DakarContrib;";
    $sandbox = new TWiki::Sandbox();
  } else {
    $sandbox = $TWiki::sharedSandbox # 4.0 - 4.1.2
      || $TWiki::sandbox; # 4.2
  }

  my $this = {
    session => $session,
    dataDir => TWiki::Func::getDataDir(),
    userName => TWiki::Func::getWikiName(),
    homeTopic => $TWiki::Plugins::NatSkinPlugin::homeTopic,
    sandbox => $sandbox,
    includeWeb => TWiki::Func::getPreferencesValue('NATSEARCHINCLUDEWEB') || '',
    excludeWeb => TWiki::Func::getPreferencesValue('NATSEARCHEXCLUDEWEB') || '',
    includeTopic => TWiki::Func::getPreferencesValue('NATSEARCHINCLUDETOPIC') || '',
    excludeTopic => TWiki::Func::getPreferencesValue('NATSEARCHEXCLUDETOPIC') || '',
    searchTemplate => TWiki::Func::getPreferencesValue('NATSEARCHTEMPLATE') || '',
    ignoreCase => TWiki::Func::getPreferencesValue('NATSEARCHIGNORECASE'),
    limit => TWiki::Func::getPreferencesFlag('NATSEARCHLIMIT') || 0,
    globalSearch => TWiki::Func::getPreferencesFlag('NATSEARCHGLOBAL'),
    keywordSearch => TWiki::Func::getPreferencesFlag('NATSEARCHKEYWORDS'),
    egrepCmd=> $TWiki::cfg{NatSearch}{EgrepCmd} || '/bin/egrep',
    @_
  };
  $this->{includeWeb} =~ s/^\s*(.*)\s*$/$1/o;
  $this->{excludeWeb} =~ s/^\s*(.*)\s*$/$1/o;
  $this->{includeTopic} =~ s/^\s*(.*)\s*$/$1/o;
  $this->{excludeTopic} =~ s/^\s*(.*)\s*$/$1/o;

  $this->{ignoreCase} = 1 unless defined $this->{ignoreCase};
  $this->{ignoreCase} = ($this->{ignoreCase} =~ /1|on|yes/)?1:0;
  $this->{modificationTime} = ();

  writeDebug("ignoreCase=$this->{ignoreCase}");

  return bless ($this, $class);
}

##############################################################################
# returns the full text of the search
sub search {
  my $this = shift;

  writeDebug("called search()");

  $TWiki::Plugins::SESSION = $this->{session};
  my $query = TWiki::Func::getCgiQuery();
  my $topic = $this->{session}->{topicName};
  my $web = $this->{session}->{webName};

  my $theSearchString = $query->param('search') || '';
  my $theWeb = $query->param('web') || $web;
  my $theSearchBox = $query->param('searchbox') || 'on';
  my $theLimit = $query->param('limit');
  my $origSearch = $theSearchString;
  my $searchTemplate;

  if (defined($theLimit)) {
    $this->{limit} = 0 if $theLimit eq 'all';
    $theLimit =~ s/[^\d]//g;
    $this->{limit} = $theLimit;
  }
  $this->{limit} = 0 unless $this->{limit};
  writeDebug("limit=$this->{limit}");

  writeDebug("theWeb=$theWeb");
  $searchTemplate = $this->{searchTemplate} || 'search';
  $searchTemplate = TWiki::Func::readTemplate($searchTemplate);
  $searchTemplate =~ s/^\s*(.*)\s*$/$1/os;
  
  # separate and process options
  my $options = "";
  $options = $1 if $theSearchString =~ s/^(.*?)://;
  writeDebug("options=$options");

  # check for topic actions
  if ($options =~ /^e(dit)?$/) {
    my ($editWeb, $editTopic) = TWiki::Func::normalizeWebTopicName($web, $theSearchString);
    if (TWiki::Func::webExists($editWeb)) {
      my $editUrl = TWiki::Func::getScriptUrl($editWeb, $editTopic, 'edit', 't', time());
      TWiki::Func::redirectCgiQuery($query, $editUrl);
      return '';
    }
  }
  if ($options =~ /^n(ew)?$/) {
    my ($editWeb, $editTopic) = TWiki::Func::normalizeWebTopicName($web, $theSearchString);
    if (TWiki::Func::webExists($editWeb)) {
      my $editUrl = TWiki::Func::getScriptUrl($editWeb, $editTopic, 'edit', 'onlynewtopic', 'on', 't', time());
      TWiki::Func::redirectCgiQuery($query, $editUrl);
      return '';
    }
  }
  $this->{keywordSearch} = ($options =~ /k/ || $this->{keywordSearch}) ? 1 : 0;

  # construct the list of webs to search in
  $this->{globalSearch} = 1 if $theWeb eq 'all';
  writeDebug("globalSearch=$this->{globalSearch}");
  my @webList;
  if (($options =~ /g/ || $this->{globalSearch}) && $options !~ /l/) {
    writeDebug("getting public weblist ");
    @webList = TWiki::Func::getPublicWebList();
    @webList = grep (/^$this->{includeWeb}$/, @webList) if $this->{includeWeb};
    @webList = grep (!/^$this->{excludeWeb}$/, @webList) if $this->{excludeWeb};
    @webList = grep (!/$TWiki::cfg{TrashWebName}/, @webList);
  }
  unshift(@webList, $web) unless grep (/^$web$/, @webList);
  writeDebug("webList=@webList");

  # (1) If the string starts with an uppercase letter, try a jump
  # (2) do a topic search; if there's only one match then go there
  # (3) merge a content search into the results of the topic search

  my $nrHits = 0;
  my %results = ();

  # allow quotes in search strings
  $theSearchString =~ s/\$quote/"/go;

  # upper case

  if ($theSearchString =~ /^[A-Z]/) {
    if ($theSearchString =~ /^(.*)\.(.*?)$/) {  # Special web.topic notation
      @webList = ($1);
      $theSearchString = $2;
    }
    # (1) try a jump
    writeDebug("(1) try a jump");
    foreach my $thisWeb (@webList) {
      if (TWiki::Func::topicExists($thisWeb, $theSearchString)) {
	my $viewUrl = TWiki::Func::getViewUrl($thisWeb, $theSearchString);
	writeDebug("(1) jump");
	TWiki::Func::redirectCgiQuery($query, $viewUrl);
	return '';
      } 
    }

    # (2) to topic search
    writeDebug("(2.1) topic search");
    $this->topicSearch($theSearchString, \@webList, \%results);
    foreach my $topics (values %results) {
      $nrHits += scalar(keys %$topics);
    }
    writeDebug("found $nrHits hits");

    # If there is only one result, redirect to that node
    if ($nrHits == 1) {
      my $resultWeb = (keys %results)[0];
      my $resultTopic = (keys %{$results{$resultWeb}})[0];
      my $viewUrl = TWiki::Func::getViewUrl($resultWeb, $resultTopic);
      writeDebug("(2) jump");
      TWiki::Func::redirectCgiQuery($query, $viewUrl);
      return '';
    }
    # (3) add content search
    writeDebug("(3.1) content search");
    $this->contentSearch($theSearchString, \@webList, \%results);
  } 
  
  # lowercase
  else {

    # (2) to topic search
    writeDebug("(2.2) topic search");
    $this->topicSearch($theSearchString, \@webList, \%results);

    # (3) add content search
    writeDebug("(3.2) content search");
    $this->contentSearch($theSearchString, \@webList, \%results);
  }

  # count hits (again)
  $nrHits = 0;
  foreach my $topics (values %results) {
    $nrHits += scalar(keys %$topics);
  }
  writeDebug("found $nrHits hits");

  # print them
  my $result = '';
  my ($tmplHead, $tmplSearch, $tmplTable, $tmplNumber, $tmplTail) = 
    split(/%SPLIT%/,$searchTemplate);

  #writeDebug("tmplHead='$tmplHead'");
  #writeDebug("tmplSearch='$tmplSearch'");
  #writeDebug("tmplTable='$tmplTable'");
  #writeDebug("tmplNumber='$tmplNumber'");
  #writeDebug("tmplTail='$tmplTail'");

  $tmplHead = TWiki::Func::expandCommonVariables($tmplHead, $topic, $web);
  $tmplHead = TWiki::Func::renderText($tmplHead);
  $tmplHead =~ s|</*nop/*>||goi;
  $tmplHead =~ s/%TOPIC%/$topic/go;
  $tmplHead =~ s/%SEARCHSTRING%/$origSearch/go;
  $result .= $tmplHead;

  if ($nrHits) {
    $tmplNumber =~ s/%NTOPICS%/$nrHits/go;
    $tmplNumber .= $tmplSearch if $theSearchBox eq 'on';
    $tmplNumber = TWiki::Func::expandCommonVariables($tmplNumber, $topic, $web);
    $tmplNumber = TWiki::Func::renderText($tmplNumber);
    $result .= $tmplNumber;
    $result .= $this->formatSearchResult($tmplTable, \%results, $theSearchString);
  } else {
    my $text;
    if (TWiki::isValidTopicName($theSearchString)) { # SMELL
      $text = TWiki::Plugins::NatSkinPlugin::getWebComponent('WebNothingFound', $web);
    } else {
      $text = '<div class="natSearch twikiAlert">%TMPL:P{"NOTHING_FOUND"}%</div>';
    }
    $text .= $tmplSearch if $theSearchBox eq 'on';
    $text = TWiki::Func::expandCommonVariables($text, $theSearchString, $web);
    $result .= TWiki::Func::renderText($text);
  }

  # get last part of full HTML page
  $tmplTail = TWiki::Func::expandCommonVariables($tmplTail, $topic, $web);
  $tmplTail = TWiki::Func::renderText($tmplTail);
  $tmplTail =~ s|</*nop/*>||goi;   # remove <nop> tag
  $result .= $tmplTail;

  writeDebug("done search()");

  return $result;
}

##############################################################################
sub topicSearch {
  my ($this, $theSearchString, $theWebList, $results) = @_;

  writeDebug("called topicSearch()");
  DEBUG && writeDebug("theWebList=" . join(" ", @$theWebList));

  if ($theSearchString eq '') {
    #writeDebug("empty search string");
    return;
  }

  my @searchTerms = parseQuery($theSearchString);

  # collect the results for each web, put them into $results
  foreach my $thisWebName (@$theWebList) {
    # get all topics
    $thisWebName =~ s/\./\//go;
    my $webDir = TWiki::Sandbox::normalizeFileName("$this->{dataDir}/$thisWebName");
    unless (-d $webDir) {
      #writeDebug("no such directory");
      return;
    }
    opendir(DIR, $webDir) || die "can't opendir $webDir: $!";
    my @topics = map {s/\.txt$//; $_} grep {/\.txt$/} readdir(DIR);
    @topics = grep(/$this->{includeTopic}/, @topics) if $this->{includeTopic};
    @topics = grep(!/$this->{excludeTopic}/, @topics) if $this->{excludeTopic};
    closedir DIR;

    # filter topics
    foreach my $searchTerm (@searchTerms) {
      my $pattern = $searchTerm;
      #writeDebug("pattern=$pattern");
      eval {
	if ($pattern =~ s/^-//) {
	  if ($this->{ignoreCase}) {
	    @topics = grep(!/$pattern/i, @topics);
	  } else {
	    @topics = grep(!/$pattern/, @topics);
	  }
	} else {
	  if ($this->{ignoreCase}) {
	    @topics = grep(/$pattern/i, @topics);
	  } else {
	    @topics = grep(/$pattern/, @topics);
	  }
	}
      };
      if ($@) {
	TWiki::Func::writeWarning("natsearch: pattern=$pattern failed to compile");
	return;
      }
    }

    # filter out non-viewable topics
    @topics = 
      grep {TWiki::Func::checkAccessPermission("view", $this->{userName}, undef, $_, $thisWebName);}
      @topics;

    foreach my $topic (@topics) {
      $results->{$thisWebName}{$topic} = 1;
    }
  }

  writeDebug("done topicSearch()");
}

##############################################################################
sub contentSearch {
  my ($this, $theSearchString, $theWebList, $results) = @_;

  writeDebug("called contentSearch()");

  my $ignoreCaseFlag = $this->{ignoreCase}?'i':'';
  my $keywordSearchFlag = $this->{keywordSearch}?'w':'';
  my $cmdTemplate = "$this->{egrepCmd} -Hl$ignoreCaseFlag -- %PATTERN|U% %FILES|F%";
  my @searchTerms = parseQuery($theSearchString);
  return unless @searchTerms;

  writeDebug("cmdTemplate=$cmdTemplate");

  # Collect the results for each web, put them into $results
  foreach my $thisWebName (@$theWebList) {

    writeDebug("searching in $thisWebName");

    # get all topics
    $thisWebName =~ s/\./\//go;
    my $webDir = TWiki::Sandbox::normalizeFileName("$this->{dataDir}/$thisWebName");
    unless (-d $webDir) {
      writeDebug("no such directory");
      return;
    }
    opendir(DIR, $webDir) || die "can't opendir $webDir: $!";
    my @bag = grep {/\.txt$/} readdir(DIR);
    @bag = grep(/$this->{includeTopic}/, @bag) if $this->{includeTopic};
    @bag = grep(!/$this->{excludeTopic}/, @bag) if $this->{excludeTopic};
    closedir DIR;
    chdir($webDir);

    # grep files in bag
    foreach my $searchTerm (@searchTerms) {
      next unless $searchTerm;

      # can't modify $searchTerm directly
      my $pattern = $searchTerm;
      writeDebug("pattern=$pattern");
      #writeDebug("bag=".@bag);

      if ($pattern =~ s/^-//) {
	my @notfiles = "";
	eval {
	  my ($result, $code) = $this->{sandbox}->sysCommand($cmdTemplate,
	    PATTERN => $pattern, FILES => \@bag);
	  writeDebug("code=$code, result=$result");
	  @notfiles = split(/\r?\n/, $result);
	};
	if ($@) {
	  TWiki::Func::writeWarning("natsearch: pattern=$pattern files=@bag - $@");
	  return;
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
	    $this->{sandbox}->sysCommand($cmdTemplate, PATTERN => $pattern, FILES => \@bag); 
	  #writeDebug("code=$code, result=$result");
	  @bag = split(/\r?\n/, $result);
	};
	if ($@) {
	  TWiki::Func::writeWarning("natsearch: pattern=$pattern files=@bag - $@");
	  return;
	}
	chomp(@bag);
      }
    }
    #writeDebug("after bag=".@bag);

    # strip ".txt" extension
    @bag = map { s/\.txt$//; $_ } @bag;


    # filter out non-viewable topics
    @bag = 
      grep {TWiki::Func::checkAccessPermission("view", $this->{userName}, "", $_, $thisWebName);} @bag;

    foreach my $topic (@bag) {
      $results->{$thisWebName}{$topic} = 1;
    }
  }

  writeDebug("done contentSearch()");
}

##############################################################################
sub formatSearchResult {
  my ($this, $theTemplate, $theResults, $theSearchString) = @_;

  my $noSpamPadding = $TWiki::cfg{AntiSpam}{EmailPadding};
  my $result = '';

  # collect hit set
  my %webResults = ();
  my %modificationTime = ();
  foreach my $thisWeb (keys %{$theResults}) {

    # sort topics by modification time, reverse
    foreach my $thisTopic (keys %{$theResults->{$thisWeb}}) {
      $modificationTime{"$thisWeb.$thisTopic"} = 
        $this->getModificationTime($thisWeb, $thisTopic);
    }
    my @sortedTopics =
      sort {$modificationTime{"$thisWeb.$b"} <=> $modificationTime{"$thisWeb.$a"}}
          keys %{$theResults->{$thisWeb}};

    my $length = scalar(@sortedTopics);
    splice(@sortedTopics, $this->{limit}, $length) if $this->{limit} && $length > $this->{limit};
    foreach my $thisTopic (@sortedTopics) {
      $webResults{"$thisWeb.$thisTopic"} = [$thisWeb, $thisTopic];
    }
  }

  # sort over all webs
  my @sortedTopics =
    sort {$modificationTime{$b} <=> $modificationTime{$a}}
        keys %webResults;

  #writeDebug("sortedTopics=@sortedTopics");
      
  # format hits
  my $index = 0;
  foreach my $thisWebTopic (@sortedTopics) {
    my ($thisWeb, $thisTopic) = @{$webResults{$thisWebTopic}};
    #writeDebug("thisWeb=$thisWeb, thisTopic=$thisTopic");
    my ($beforeText, $repeatText, $afterText) = split(/%REPEAT%/, $theTemplate);

    # get web header
    $beforeText =~ s/%WEB%/$thisWeb/o;
    $beforeText = TWiki::Func::expandCommonVariables($beforeText, $this->{homeTopic}, $thisWeb);
    $afterText  = TWiki::Func::expandCommonVariables($afterText, $this->{homeTopic}, $thisWeb);
    $beforeText = TWiki::Func::renderText($beforeText, $thisWeb);
    $beforeText =~ s|</*nop/*>||goi;   # remove <nop> tag
    $result .= $beforeText;


    # get topic information
    my ($meta, $text) = TWiki::Func::readTopic($thisWeb, $thisTopic);
    my ($revDate, $revUser, $revNum ) = $meta->getRevisionInfo();
    $revDate = TWiki::Func::formatTime($revDate);
    $revUser ||= 'UnknownUser';
    $revUser = TWiki::Func::getWikiUserName($revUser);

    # insert the topic information into the template
    my $tempVal = $repeatText;
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
    $tempVal = TWiki::Func::expandCommonVariables($tempVal, $thisTopic, $thisWeb);
    $tempVal = TWiki::Func::renderText($tempVal);

    # remove mail trace
    $text =~ s/([A-Za-z0-9\.\+\-\_]+)\@([A-Za-z0-9\.\-]+\..+?)/$1$noSpamPadding$2/go;

    # render search hit
    my $summary = $this->makeTopicSummary($text, $thisTopic, $thisWeb, $theSearchString);
    
    $tempVal =~ s/%TEXTHEAD%/$summary/go;
    $tempVal =~ s|</*nop/*>||goi;   # remove <nop> tag

    # fiddle in even/odd CSS classes
    my $hitClass = ($index % 2)?'natSearchEvenHit':'natSearchOddHit';
    $index++;
    $tempVal =~ s/(class="natSearchHit)"/$1 $hitClass"/g;

    # get this hit
    $result .= $tempVal;

    $afterText = TWiki::Func::renderText($afterText, $thisWeb);
    $afterText =~ s|</*nop/*>||goi;   # remove <nop> tag
    $result .= $afterText;
  }
  return $result;
}

##############################################################################
sub makeTopicSummary {
  my ($this, $theText, $theTopic, $theWeb, $theSearchString) = @_;

  my @searchTerms = parseQuery($theSearchString);
  my $wikiToolName = TWiki::Func::getWikiToolName() || '';
  my $linkProtocolPattern = TWiki::Func::getRegularExpression('linkProtocolPattern');

  #writeDebug("before, text=$theText");

  # remove glue
  $theText =~ s/%~~\s+([A-Z]+{)/%$1/gos;  # %~~
  $theText =~ s/\s*[\n\r]+~~~\s+/ /gos;   # ~~~
  $theText =~ s/\s*[\n\r]+\*~~\s+//gos;   # *~~

  $theText =~ s/\[\[$linkProtocolPattern\:([^\s<>"]+[^\s*.,!?;:)<|])\s+(.*?)\]\]/$3/g;
  $theText =~ s/\[\[([^\]]*\]\[)(.*?)\]\]/$2/g;
  $theText =~ s/<\!\-\-.*?\-\->//gos;  # remove all HTML comments
  $theText =~ s/<\!\-\-.*$//os;        # remove cut HTML comment
  $theText =~ s/<[^>]*>//go;           # remove all HTML tags
  $theText =~ s/%WEB%/$theWeb/go;      # resolve web
  $theText =~ s/%TOPIC%/$theTopic/go;  # resolve topic
  $theText =~ s/%WIKITOOLNAME%/$wikiToolName/go; # resolve TWiki tool
  $theText =~ s/%META:.*?%//go;        # Remove meta data variables
  $theText =~ s/[\%\[\]\*\|=_]/ /go;   # remove Wiki formatting chars & defuse %VARS%
  $theText =~ s/\-\-\-+\+*/ /go;       # remove heading formatting
  $theText =~ s/\s+[\+\-]*/ /go;       # remove newlines and special chars

  # store first found word (some of them can be found in metadata instead of
  # in the text)
  my $firstfound = undef;
  my $errorFound = 0;
  foreach my $pattern (@searchTerms) {
    $pattern = '\b'.$pattern.'\b' if $this->{keywordSearch};
    eval {
      if ($this->{ignoreCase}) {
        $firstfound = $pattern if $theText =~ /$pattern/i;
      } else {
        $firstfound = $pattern if $theText =~ /$pattern/;
      }
    };
    if ($@) {
      TWiki::Func::writeWarning("natsearch: pattern=$pattern failed to compile");
      $errorFound = 1;
      last;
    }
    last if $firstfound;
  }
  return '' if $errorFound;

  # limit to 162 chars, according to the position of the first keyword ...
  if (defined $firstfound) {
    if ($this->{ignoreCase}) {
      $theText =~ s/^.*?([a-zA-Z0-9]*.{0,120})($firstfound)(.{0,120}[a-zA-Z0-9]*).*?$/$1$2$3/gi;
    } else {
      $theText =~ s/^.*?([a-zA-Z0-9]*.{0,120})($firstfound)(.{0,120}[a-zA-Z0-9]*).*?$/$1$2$3/gi;
    }
  } else {
    $theText =~ s/(.{240})([a-zA-Z0-9]*)(.*?)$/$1$2/go;
  }
  $theText = substr($theText, 0, 500); # Limit string length

  # ... but hilight all of them
  foreach my $term (@searchTerms) {
    $term = '\b'.$term.'\b' if $this->{keywordSearch};
    if ($this->{ignoreCase}) {
      $theText =~ s:($term):<span class="twikiAlert">$1</span>:gi;
    } else {
      $theText =~ s:($term):<span class="twikiAlert">$1</span>:g;
    }
  }

  # inline search renders text, 
  # so prevent linking of external and internal links:
  $theText =~ s/([\-\*\s])((http|ftp|gopher|news|file|https)\:)/$1<nop>$2/go;
  $theText =~ s/([\s\(])([A-Z]+[a-z0-9]*\.[A-Z]+[a-z]+[A-Z]+[a-zA-Z0-9]*)/$1<nop>$2/go;
  $theText =~ s/([\s\(])([A-Z]+[a-z]+[A-Z]+[a-zA-Z0-9]*)/$1<nop>$2/go;
  $theText =~ s/([\s\(])([A-Z]{3,})/$1<nop>$2/go;
  $theText =~ s/@([a-zA-Z0-9\-\_\.]+)/@<nop>$1/go;

  #writeDebug("after, text=$theText");
  return $theText;
}

##############################################################################
sub parseQuery {
  my $theSearchString = shift ;

  #writeDebug("called parseQuery($theSearchString)");
  my $specialCharPattern = qr/([^\\])([\$\@\%\&\#\'\`\/])/o;

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
  #writeDebug("search terms: ".join(',', @searchTerms));

  return @searchTerms;
}

##############################################################################
# own filebased checker, breaks on other storage impls, breaks before anyway
sub getModificationTime {
  my ($this, $web, $topic) = @_;

  $web =~ s/\./\//go;

  my $date = $this->{modificationTime}{$web.$topic};
  return $date if defined $date;

  $date = 0;
  my $file = $this->{dataDir}.'/'.$web.'/'.$topic.'.txt';
  if (-e $file) {
    $date = (stat $file)[9] || 600000000;
  }

  $this->{modificationTime}{$web.$topic} = $date;
  return $date;
}

1;
