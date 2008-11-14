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

package TWiki::Plugins::UserInfoPlugin::Core;
use strict;
use vars qw($debug %MON2NUM);
use Time::Local; # for timelocal

%MON2NUM = (
  Jan => 0, Feb => 1, Mar => 2, Apr => 3, May => 4, Jun => 5,
  Jul => 6, Aug => 7, Sep => 8, Oct => 9, Nov => 10, Dec => 11
);

$debug = 0; # toggle me

###############################################################################
# static
sub writeDebug {
  &TWiki::Func::writeDebug("- UserInfoPlugin - " . $_[0]) if $debug;
}


###############################################################################
sub new {
  my ($class, $id, $topic, $web) = @_;
  my $this = bless({}, $class);

  #writeDebug("building a new Core");

  # figure out where the sessions are
  $this->{sessionDir} = 
    $TWiki::cfg{TempfileDir} ||
    $TWiki::cfg{Sessions}{Dir} ||
    &TWiki::Func::getDataDir() . "/.session"; 
  if (! -e $this->{sessionDir}) {
    $this->{sessionDir} = '/tmp';
  }
  
  # init properties
  $this->{isDakar} = (defined $TWiki::RELEASE)?1:0;
  $this->{twikiGuest} = &TWiki::Func::getDefaultUserName();
  $this->{twikiGuest} = &TWiki::Func::userToWikiName($this->{twikiGuest}, 1);
  $this->{ignoreHosts} = 
    TWiki::Func::getPreferencesValue("USERINFOPLUGIN_IGNORE_HOSTS") || '';
  $this->{ignoreHosts} = join('|', split(/,\s?/, $this->{ignoreHosts}));
  my $usersString =
    TWiki::Func::getPreferencesValue("USERINFOPLUGIN_IGNORE_USERS") || '';
  my @users;
  foreach my $user (split(/,\s?/, $usersString)) {
    if ($user =~ /^(.*)\.(.*?)$/) {
      push @users, $2;
    }
  }
  $this->{ignoreUsers} = join('|', @users);

  # ignore build-in users 
  $this->{ignoreUsers} .= '|' if $this->{ignoreUsers};
  $this->{ignoreUsers} .= 
    $this->{twikiGuest} .
    '|'.'TWikiAdminGroup' .
    '|'.'UnknownUser' .
    '|'.'RegistrationAgent' .
    '|'.'ProjectContributor';

  writeDebug("ignoreHosts=$this->{ignoreHosts}");
  writeDebug("ignoreUsers=$this->{ignoreUsers}");

  return $this;
}

###############################################################################
sub handleNrUsers {
  my $this = shift;

  writeDebug("called handleNrUsers");
  return $this->{nrUsers} if defined $this->{nrUsers};

  my $users = $this->getUsers();
  $this->{nrUsers} = scalar(@$users);
 
  writeDebug("got $this->{nrUsers} nr users");
  return $this->{nrUsers};
}

###############################################################################
sub handleNrVisitors {
  my $this = shift;

  writeDebug("called handleNrVisitors");
  return $this->{nrVisitors} if defined $this->{nrVisitors};

  my ($visitors) = $this->getVisitorsFromSessionStore(undef, $this->{ignoreUsers});
  $this->{nrVisitors} = scalar @$visitors;

  writeDebug("got $this->{nrVisitors} nr visitors");
  return $this->{nrVisitors};
}

###############################################################################
sub handleNrGuests {
  my $this =  shift;

  writeDebug("called handleNrGuests");
  return $this->{nrGuests} if defined $this->{nrGuests};

  my (undef, $guests) = $this->getVisitorsFromSessionStore($this->{twikiGuest});
  $this->{nrGuests} = scalar @$guests;

  writeDebug("got $this->{nrGuests} nr guests");
  return $this->{nrGuests};
}

###############################################################################
sub handleNrLastVisitors {
  my ($this, $attributes) = @_;

  writeDebug("called handleNrLastVisitors");

  $attributes = '' unless $attributes;

  my $theDays = TWiki::Func::extractNameValuePair($attributes, "days") || 1;
  return $this->{nrLastVisitors}{$theDays} if defined $this->{nrLastVisitors}{$theDays};

  my $visitors = $this->getVisitors($theDays, undef, undef, $this->{ignoreUsers});
  $this->{nrLastVisitors}{$theDays} = scalar @$visitors;

  writeDebug("got $this->{nrLastVisitors} nr last visitors");
  return $this->{nrLastVisitors}{$theDays};
}

###############################################################################
sub handleCurrentVisitors {
  my ($this, $attributes) = @_;

  writeDebug("called handleCurrentVisitors");
  $attributes = '' unless $attributes;

  my $theHeader = &TWiki::Func::extractNameValuePair($attributes, "header") || '';
  my $theFooter = &TWiki::Func::extractNameValuePair($attributes, "footer") || '';
  my $theFormat = &TWiki::Func::extractNameValuePair($attributes, "format") ||
    "\t* \$wikiusername";
  my $theSep = &TWiki::Func::extractNameValuePair($attributes, "sep") || '$n';
  my $theMax = &TWiki::Func::extractNameValuePair($attributes, "max") || 0;
  $theMax = 0 if $theMax eq "unlimited";
  
  # get current visitors
  my ($visitors) = $this->getVisitorsFromSessionStore(undef, $this->{ignoreUsers});
  return '' if !@$visitors;

  # get more information from the logfiles
  $visitors = join('|', @$visitors);
  $visitors = $this->getVisitors(1, undef, $visitors, $this->{ignoreUsers});

  my $result = '';
  my $isFirst = 1;
  my $n = $theMax;
  my $counter = 0;
  foreach my $visitor (sort {$a->{wikiname} cmp $b->{wikiname}} @$visitors) {
    last if --$n == 0;
    my $text = $result?$theSep:'';
    $text .= $theFormat;
    $result .= &replaceVars($text, {
      'counter'=>++$counter,
      'wikiname'=>$visitor->{wikiname}, 
      'date'=>$visitor->{sdate},
      'time'=>$visitor->{time},
      'host'=>$visitor->{host},
      'topic'=>$visitor->{topic},
    });
    #writeDebug("found visitor $visitor->{wikiname}");
  }

  if ($counter) {
    $result = $theHeader.$result.$theFooter;
    $result = &replaceVars($result, {
      'counter'=>$counter,
    });
  }
  
  return $result;
}

###############################################################################
# render list of 10 most recently registered users.
# this information is extracted from %MAINWEB%.TWikiUsers
sub handleNewUsers {
  my ($this, $attributes) = @_;

  writeDebug("called handleNewUsers");
  $attributes = '' unless $attributes;

  my $theHeader = &TWiki::Func::extractNameValuePair($attributes, "header") || '';
  my $theFooter = &TWiki::Func::extractNameValuePair($attributes, "footer") || '';
  my $theFormat = &TWiki::Func::extractNameValuePair($attributes, "format") ||
    "\t* \$date - \$wikiusername";
  my $theSep = &TWiki::Func::extractNameValuePair($attributes, "sep") || '$n';
  my $theMax = &TWiki::Func::extractNameValuePair($attributes, "max") || 10;
  $theMax = 0 if $theMax eq "unlimited";

  my $users = $this->getUsers();

  my $n = $theMax;
  my $counter = 0;
  my $result = '';
  foreach my $user (sort { $b->{date} <=> $a->{date}} @$users) {
    last if --$n == 0;
    my $text = $result?$theSep:'';
    $text .= $theFormat;
    $result .= &replaceVars($text, {
      counter=>++$counter,
      wikiname=>$user->{name}, 
      date=>$user->{sdate}  
    });
    #writeDebug("found new user $user->{name}");
  }

  if ($counter) {
    $result = $theHeader.$result.$theFooter;
    $result = &replaceVars($result, {
      'counter'=>$counter,
    });
  }

  return $result;
}

###############################################################################
sub handleLastVisitors {
  my ($this, $attributes) = @_;

  writeDebug("called handleLastVisitors");
  $attributes = '' unless $attributes;

  my $theHeader = &TWiki::Func::extractNameValuePair($attributes, "header") || '';
  my $theFooter = &TWiki::Func::extractNameValuePair($attributes, "footer") || '';
  my $theFormat = TWiki::Func::extractNameValuePair($attributes, "format" ) ||
    "\t* \$date - \$wikiusername";
  my $theSep = TWiki::Func::extractNameValuePair($attributes, "sep" ) || '$n';
  my $theMax = TWiki::Func::extractNameValuePair($attributes, "max") || 0;
  $theMax = 0 if $theMax eq 'unlimited';
  my $theDays = TWiki::Func::extractNameValuePair($attributes, "days") || 1;

  my $visitors = $this->getVisitors($theDays, $theMax, undef, $this->{ignoreUsers});

  # garnish the collected data
  my $result = '';
  my $counter = 0;
  foreach my $visitor (sort {$b->{date} <=> $a->{date}} @$visitors) {
    my $text = $result?$theSep:'';
    $text .= $theFormat;
    $result .= &replaceVars($text, {
      'counter'=>++$counter,
      'wikiname'=>$visitor->{wikiname}, 
      'date'=>$visitor->{sdate},
      'time'=>$visitor->{time},
      'host'=>$visitor->{host},
      'topic'=>$visitor->{topic},
    });
    #writeDebug("found last visitor $visitor->{wikiname}");
  }

  if ($counter) {
    $result = $theHeader.$result.$theFooter;
    $result = &replaceVars($result, {
      'counter'=>$counter,
    });
  }

  return $result;
}

###############################################################################
# TODO: add a cache 
#
# get list of users that still have a session object
# this is the number of session objects
sub getVisitorsFromSessionStore {
  my ($this, $includeNames, $excludeNames) = @_;

  writeDebug("getVisitorsFromSessionStore()");
  writeDebug("includeNames=$includeNames") if $includeNames;
  writeDebug("excludeNames=$excludeNames") if $excludeNames;

  # get session directory

  # get wikinames of current visitors
  my %users = ();
  my %guests = ();
  my @sessionFiles = reverse glob $this->{sessionDir}.'/cgisess_*';
  foreach my $sessionFile (@sessionFiles) {

    #writeDebug("reading $sessionFile");
  
    my $dump = &TWiki::Func::readFile($sessionFile);
    next unless $dump;

    my $wikiName = $this->{twikiGuest};
    if ($dump =~ /['"]?AUTHUSER['"]? => ["'](.*?)["']/) {
      $wikiName = $1;
    }
    #writeDebug("wikiName=$wikiName");

    my $host;
    if ($dump =~ /["']?_SESSION_REMOTE_ADDR["']? => ['"](.*?)['"]/) {
      $host = $1;
    }

    if ($host) {
      #writeDebug("host=$host");
      next if $host =~ /$this->{ignoreHosts}/;
      $guests{$host} = 1 if $wikiName eq $this->{twikiGuest};
    }

    next if $users{$wikiName};
    next if $excludeNames && $wikiName =~ /$excludeNames/;
    next if $includeNames && $wikiName !~ /$includeNames/;
    #writeDebug("found $wikiName");
    $users{$wikiName} = 1;
  }

  my @users = keys %users;
  my @guests = keys %guests;

  return (\@users, \@guests);
}

###############################################################################
# extracts all users from Main.TWikiUsers
sub getUsers {
  my $this = shift;

  #writeDebug("called getUsers");
  return $this->{users} if defined $this->{users};
  
  my $wikiUsersTopicname = ($this->{isDakar})?$TWiki::cfg{UsersTopicName}:$TWiki::wikiUsersTopicname;
  my $mainWeb = &TWiki::Func::getMainWebname();

  my (undef, $topicText) = &TWiki::Func::readTopic($mainWeb, $wikiUsersTopicname);
  my @users;
  foreach my $line ( split( /\n/, $topicText) ) {
    #writeDebug("line=$line");
    next unless $line =~ m/[\t|(?: {3})]\*\s([A-Z][a-zA-Z0-9]+)\s\-\s(?:(.*)\s\-\s)?(.*)/;
    my $name = $1;
    my $date = $3;
    #writeDebug("name=$name");
    next if $name =~ /$this->{ignoreUsers}/;
    my %user = (
      'sdate' => $date,
      'date' => parseDate($date),
      'name' => $name
    );
    push @users, \%user;
  }

  $this->{users} = \@users;

  return $this->{users};
}

###############################################################################
# TODO: cache up to the max seen days and extract a list matching the 
# include/excludeNames pattern afterwards
sub getVisitors {
  my ($this, $theDays, $theMax, $includeNames, $excludeNames) = @_;

  $theMax = 0 unless $theMax;

  writeDebug("getVisitors()");
  writeDebug("theDays=$theDays") if $theDays;
  #writeDebug("theMax=$theMax") if $theMax;
  #writeDebug("includeNames=$includeNames") if $includeNames;
  #writeDebug("excludeNames=$excludeNames") if $excludeNames;
  my $mainWeb = &TWiki::Func::getMainWebname();

  # get the logfile mask
  my $logFileGlob;
  if ($this->{isDakar}) {
    $logFileGlob = $TWiki::cfg{LogFileName};
  } else {
    $logFileGlob = $TWiki::logFilename;
  }
  $logFileGlob =~ s/%DATE%/*/go;
  
  # go through the logfiles and collect visitor data
  my $isDone = 0;
  my $days = 0;
  my $n = $theMax;
  my $currentDate = '';
  my @logFiles = reverse glob $logFileGlob;
  my @lastVisitors = ();
  my %seen = ();
  foreach my $logFilename (@logFiles) {
    #writeDebug("reading $logFilename");

    # read one logfile
    my $fileContents = TWiki::Func::readFile($logFilename);
    
    # analysis
    my $nrVisitors = 0;
    foreach my $line (reverse split(/\n/, $fileContents)) {
      my @fields = split(/\|/, $line);
      if (!$fields[2]) {
	#writeDebug("Hm, line '$line' has no wikiName");
	next;
      }

      # date
      my $date = substr($fields[1], 1, 11);
      $date =~ s/^\s+//g;
      $date =~ s/\s+$//g;
      if ($currentDate ne $date) {
	$currentDate = $date;
	$days++;
      }
      #writeDebug("date=$date, currentDate=$currentDate, days=$days");

      # termination criteria
      if (--$n == 0 || ($theDays && $days > $theDays)) {
	$isDone = 1;
	last;
      }

      # wikiname
      my $wikiName = $fields[2];
      $wikiName =~ s/^\s+//g;
      $wikiName =~ s/\s+$//g;
      next unless $wikiName;
      next if $wikiName =~ /^TWiki/o; # exclude default user

      $wikiName =~ s/^.*?\.(.*)$/$1/g;
      
      next if $excludeNames && $wikiName =~ /$excludeNames/;
      next if $includeNames && $wikiName !~ /$includeNames/;
      next if $seen{"$wikiName"};

      # check back
      next unless TWiki::Func::topicExists($mainWeb, $wikiName);

      # host
      my $host = $fields[6];
      $host =~ s/^\s+//g;
      $host =~ s/\s+$//g;
      next if $host =~ /$this->{ignoreHosts}/;

      # topic
      my $thisTopic = $fields[4];
      $thisTopic =~ s/^\s+//g;
      $thisTopic =~ s/\s+$//g;

      # date, time
      my $time = substr($fields[1], 15, 5);
      my $timeMark = 
	$days * 24 +
	substr($fields[1], 15, 2) * 60 + 
	substr($fields[1], 18, 2);

      # create visitor struct
      my $visitor = {
	'wikiname'=>$wikiName,
	'sdate'=>$date,
	'date'=>parseDate($date),
	'time'=>$time,
	'host'=>$host,
	'topic'=>$thisTopic,
      };
      #writeDebug("found visitor $wikiName in the logs");

      # store
      push @lastVisitors, $visitor;
      $seen{"$wikiName"} = 1;
      $nrVisitors++;
    }
    #writeDebug("found $nrVisitors visitors in file $logFilename");

    last if $isDone;
  }

  return \@lastVisitors;
}

###############################################################################
# static
sub replaceVars {
  my ($format, $data) = @_;

  #writeDebug("replaceVars($format, data)");

  if (defined $data) {
    if (defined $data->{wikiname}) {
      $data->{username} = &TWiki::Func::wikiToUserName($data->{wikiname});
      $data->{wikiusername} = &TWiki::Func::userToWikiName($data->{wikiname});
    }

    foreach my $key (keys %$data) {
      $format =~ s/\$$key/$data->{$key}/g;
    }
  }

  $format =~ s/\$n/\n/go;
  $format =~ s/\$quot/\"/go;
  $format =~ s/\$percnt/\%/go;
  $format =~ s/\$dollar/\$/go;
  $format =~ s/\\/\//go;

  #writeDebug("returns '$format'");

  return $format;
}

###############################################################################
# static
# parse dates of the format "31 Dec 2001"
sub parseDate {

  if ($_[0] =~ /([0-9]+)\s+([A-Za-z]+)\s+([0-9]+)/) {
    return timelocal( 0, 0, 0, $1, $MON2NUM{$2}, $3 );
  }

  return 0; # never reach
}

###############################################################################
1;
