# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005-2006 Michael Daum <micha@nats.informatik.uni-hamburg.de>
# 
# Adapted from WordPress plugin TimeSince by
# Michael Heilemann (http://binarybonsai.com), 
# Dunstan Orchard (http://www.1976design.com/blog/archive/2004/07/23/redesign-time-presentation/),
# Nataile Downe (http://blog.natbat.co.uk/archive/2003/Jun/14/time_since)
# 
# Thanks to all of you!!!
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

package TWiki::Plugins::TimeSincePlugin::Core;

use Time::Local;
use strict;
use vars qw( @SECONDS %MON2NUM );

use constant DEBUG => 0; # toggle me

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

@SECONDS = (
  ['year',   60 * 60 * 24 * 365],
  ['month',  60 * 60 * 24 * 30],
  ['week',   60 * 60 * 24 * 7],
  ['day',    60 * 60 * 24],
  ['hour',   60 * 60],
  ['minute', 60],
  ['second', 1]
);



###############################################################################
sub writeDebug {
  print STDERR "TimeSincePlugin - $_[0]\n" if DEBUG
}


###############################################################################
sub handleTimeSince {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("handleTimeSince(" . $params->stringify() . ") called\n");

  my $theFrom = $params->{_DEFAULT} || $params->{from} || '';
  my $theTo = $params->{to} || '';
  my $theUnits = $params->{units} || 2;
  my $theSeconds = $params->{seconds} || 'off';
  my $theAbs = $params->{abs} || 'off';
  my $theNull = $params->{null} || 'about now';
  my $theFormat = $params->{format} || '$time';
  my $theNegFormat = $params->{negformat} || '$time';

  if ($theFrom eq '' && $theTo eq '') {
    # if there's no starting date then get the current revision date
    my ($meta, undef) = &TWiki::Func::readTopic($theWeb, $theTopic);
    ($theFrom) = $meta->getRevisionInfo();
    $theTo = time();
  } else {

    $theFrom =~ s/^\s*(.*)\s*$/$1/go;
    $theTo =~ s/^\s*(.*)\s*$/$1/go;

  
    # convert time to epoch seconds
    if ($theFrom ne '') {
      if ($theFrom !~ /^\d+$/) { # already epoch seconds
	eval {
	  local $SIG{'__DIE__'};
	  $theFrom = &parseTime($theFrom);
	};
	if ($@) {
	  my $message = $@;
	  $message =~ s/\sat\s.*//go;
	  return &inlineError("ERROR: can't parse from=\"$theFrom\" - $message");
	}
	return &inlineError("ERROR: can't parse from=\"$theFrom\"")
	  unless defined $theFrom;
      }
    } else {
      $theFrom = time();
    }
    if ($theTo ne '') {
      if ($theTo !~ /^\d+$/) { # already epoch seconds
	eval {
	  local $SIG{'__DIE__'};
	  $theTo = &parseTime($theTo);
	};
	if ($@) {
	  my $message = $@;
	  $message =~ s/\sat\s.*//go;
	  return &inlineError("ERROR: can't parse to=\"$theTo\" - $message");
	}
	return &inlineError("ERROR: can't parse from=\"$theTo\"")
	  unless defined $theTo;
      }
    } else {
      $theTo = time();
    }
  }

  my $since = $theTo - $theFrom;
  my $isNeg = $since < 0;
  if ($theAbs eq 'on') {
    $since = abs($since);
  }

  #writeDebug("from=$theFrom to=$theTo, since=$since, abs=$theAbs");
   
  # calculate time string
  my $unit;
  my $count;
  my $seconds;
  my $timeString = '';
  my $state = 0;

  # step one: the first chunk
  my $max = ($theSeconds eq 'on')?7:6;
  for (my $i = 0; $i < $max; $i++) {
    $unit = $SECONDS[$i][0];
    $seconds = $SECONDS[$i][1];
    $count = int(($since + 0.0) / $seconds);

    #writeDebug("$i: unit=$unit, seconds=$seconds, count=$count, since=$since");

    # finding next unit
    if ($count) {
      $timeString .= ', ' if $state > 0;
      $timeString .= ($count == 1) ? '1 '.$unit : "$count ${unit}s";
      $state++;
    } else {
      next;
    }

    $since -= ($count * $seconds);
    last if $theUnits && $state >= $theUnits;
  }
  
  if ($timeString eq '') {
    return expandVariables($theNull);
  } else {
    my $format = $isNeg?$theNegFormat:$theFormat;
    return expandVariables($format, 'time'=>$timeString);
  }
}

###############################################################################
sub parseTime {
    my $date = shift;

    #writeDebug("parseTime($date)");

    my $isGmt = ($date =~ /GMT$/i)?1:0;

    # NOTE: This routine *will break* if input is not one of below formats!
    
    # FIXME - why aren't ifs around pattern match rather than $5 etc
    # try "31 Dec 2001 - 23:59:11"  (TWiki date)
    if ($date =~ /([0-9]+)\s+([A-Za-z]+)\s+([0-9]+)[\s\-]+([0-9]+)\:([0-9]+)(?:\:([0-9]+))?/) {
        my $year = $3;
        my $seconds = $6 || 0;
        #$year -= 1900 if( $year > 1900 );
        # The ($2) will look up the constant so named
        return timegm( $seconds, $5, $4, $1, $MON2NUM{$2}, $year ) if $isGmt;
        return timelocal( $seconds, $5, $4, $1, $MON2NUM{$2}, $year );
    }

    # try "31 Dec 2001"
    if ($date =~ /([0-9]+)\s+([A-Za-z]+)\s+([0-9]+)/) {
        my $year = $3;
        #$year -= 1900 if( $year > 1900 );
        # The ($2) will look up the constant so named
        return timegm( 0, 0, 0, $1, $MON2NUM{$2}, $year ) if $isGmt;
        return timelocal( 0, 0, 0, $1, $MON2NUM{$2}, $year );
    }

    # try "2001/12/31 23:59:59" or "2001.12.31.23.59.59" (RCS date)
    if ($date =~ /([0-9]+)[\.\/\-]([0-9]+)[\.\/\-]([0-9]+)[\.\s\-]+([0-9]+)[\.\:]([0-9]+)[\.\:]([0-9]+)/) {
        my $year = $1;
        #$year -= 1900 if( $year > 1900 );
        return timegm( $6, $5, $4, $3, $2-1, $year ) if $isGmt;
        return timelocal( $6, $5, $4, $3, $2-1, $year );
    }

    # try "2001/12/31 23:59" or "2001.12.31.23.59" (RCS short date)
    if ($date =~ /([0-9]+)[\.\/\-]([0-9]+)[\.\/\-]([0-9]+)[\.\s\-]+([0-9]+)[\.\:]([0-9]+)/) {
        my $year = $1;
        #$year -= 1900 if( $year > 1900 );
        return timegm( 0, $5, $4, $3, $2-1, $year ) if $isGmt;
        return timelocal( 0, $5, $4, $3, $2-1, $year );
    }

    # try "2001/12/31"
    if ($date =~ /([0-9]+)[\.\/\-]([0-9]+)[\.\/\-]([0-9]+)/) {
        my $year = $1;
        #$year -= 1900 if( $year > 1900 );
        return timegm( 0, 0, 0, $3, $2-1, $year ) if $isGmt;
        return timelocal( 0, 0, 0, $3, $2-1, $year );
    }

    # try "2001-12-31T23:59:59Z" or "2001-12-31T23:59:59+01:00" (ISO date)
    # FIXME: Calc local to zulu time "2001-12-31T23:59:59+01:00"
    if ($date =~ /([0-9]+)\-([0-9]+)\-([0-9]+)T([0-9]+)\:([0-9]+)\:([0-9]+)/ ) {
        my $year = $1;
        #$year -= 1900 if( $year > 1900 );
        return timegm( $6, $5, $4, $3, $2-1, $year ) if $isGmt;
        return timelocal( $6, $5, $4, $3, $2-1, $year );
    }

    # try "2001-12-31T23:59Z" or "2001-12-31T23:59+01:00" (ISO short date)
    # FIXME: Calc local to zulu time "2001-12-31T23:59+01:00"
    if ($date =~ /([0-9]+)\-([0-9]+)\-([0-9]+)T([0-9]+)\:([0-9]+)/ ) {
        my $year = $1;
        #$year -= 1900 if( $year > 1900 );
        return timegm( 0, $5, $4, $3, $2-1, $year ) if $isGmt;
        return timelocal( 0, $5, $4, $3, $2-1, $year );
    }

    # give up, return start of epoch (01 Jan 1970 GMT)
    return undef;
}

###############################################################################
sub inlineError {
  return '<span class="twikiAlert">' . $_[0] . '</span>' ;
}

###############################################################################
sub expandVariables {
  my ($theFormat, %params) = @_;

  return '' unless $theFormat;
  
  foreach my $key (keys %params) {
    $theFormat =~ s/\$$key/$params{$key}/g;
  }
  $theFormat =~ s/\$percnt/\%/go;
  $theFormat =~ s/\$t\b/\t/go;
  $theFormat =~ s/\$nop//g;
  $theFormat =~ s/\$n/\n/go;
  $theFormat =~ s/\$dollar/\$/go;

  return $theFormat;
}

###############################################################################
1;

