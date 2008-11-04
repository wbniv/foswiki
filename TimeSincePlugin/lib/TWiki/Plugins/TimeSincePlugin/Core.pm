# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005-2008 Michael Daum http://michaeldaumconsulting.com
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

use DateTime;
use strict;

use constant DEBUG => 0; # toggle me

our %MON2NUM = (
  Jan => 1,
  Feb => 2,
  Mar => 3,
  Apr => 4,
  May => 5,
  Jun => 6,
  Jul => 7,
  Aug => 8,
  Sep => 9,
  Oct => 10,
  Nov => 11,
  Dec => 12
);

###############################################################################
sub writeDebug {
  print STDERR "TimeSincePlugin - $_[0]\n" if DEBUG
}


###############################################################################
sub handleTimeSince {
  my ($session, $params, $theTopic, $theWeb) = @_;

  writeDebug("handleTimeSince(" . $params->stringify() . ") called");

  my $theFrom = $params->{_DEFAULT} || $params->{from} || '';
  my $theTo = $params->{to} || '';
  my $theUnits = $params->{units} || 2;

  my $theSeconds = $params->{seconds} || 'off';
  my $theMinutes = $params->{minutes} || 'on';
  my $theHours = $params->{hours} || 'on';
  my $theDays = $params->{days} || 'on';
  my $theWeeks = $params->{weeks} || 'on';
  my $theMonths = $params->{months} || 'on';
  my $theYears = $params->{years} || 'on';

  my $theAbs = $params->{abs} || 'off';
  my $theNull = $params->{null} || 'about now';
  my $theFormat = $params->{format} || '$time';
  my $theNegFormat = $params->{negformat} || '- $time';

  if ($theFrom eq '' && $theTo eq '') {
    # if there's no starting date then get the current revision date
    my ($meta, undef) = &TWiki::Func::readTopic($theWeb, $theTopic);
    my ($epoch) = $meta->getRevisionInfo();
    $theFrom = DateTime->from_epoch(epoch=>$epoch);
    $theTo = parseTime();
  } else {

    $theFrom =~ s/^\s*(.*)\s*$/$1/go;
    $theTo =~ s/^\s*(.*)\s*$/$1/go;

  
    # convert time to DateTime object
    if ($theFrom ne '') {
      if ($theFrom =~ /^\d+$/) { # already epoch seconds
        $theFrom = DateTime->from_epoch(epoch=>$theFrom);
      } else {
	eval {
	  local $SIG{'__DIE__'};
	  $theFrom = parseTime($theFrom);
	};
	if ($@) {
	  my $message = $@;
	  $message =~ s/\scallback\s.*$//gs;
	  return &inlineError("ERROR: can't parse from=\"$theFrom\" - $message");
	}
	return &inlineError("ERROR: can't parse from=\"$theFrom\"")
	  unless defined $theFrom;
      }
    } else {
      $theFrom = parseTime();
    }
    if ($theTo ne '') {
      if ($theTo =~ /^\d+$/) { # already epoch seconds
        $theTo = DateTime->from_epoch(epoch=>$theTo);
      } else {
	eval {
	  local $SIG{'__DIE__'};
	  $theTo = parseTime($theTo);
	};
	if ($@) {
	  my $message = $@;
	  $message =~ s/\scallback\s.*$//gs;
	  return &inlineError("ERROR: can't parse to=\"$theTo\" - $message");
	}
	return &inlineError("ERROR: can't parse from=\"$theTo\"")
	  unless defined $theTo;
      }
    } else {
      $theTo = parseTime();
    }
  }

  writeDebug("theFrom=$theFrom, theTo=$theTo");

  my $since = $theTo - $theFrom;
  my $isNeg = $since->is_negative;
  $since = $since->inverse if $isNeg;

  # calculate time string
  my $timeString = '';
  my $unit;

  my @units = ();
  my $last;
  foreach my $unit (qw(years months weeks days hours minutes seconds)) {
    next if $theSeconds eq 'off' && $unit eq 'seconds';
    next if $theMinutes eq 'off' && $unit eq 'minutes';
    next if $theHours eq 'off' && $unit eq 'hours';
    next if $theDays eq 'off' && $unit eq 'days';
    next if $theWeeks eq 'off' && $unit eq 'weeks';
    next if $theMonths eq 'off' && $unit eq 'months';
    next if $theYears eq 'off' && $unit eq 'years';
    push @units, $unit;
    $last = $unit;
  }

  my @raw = $since->in_units(@units);

  my $index = 0;
  foreach my $unit (@units) {

    my $count = shift @raw;
    if ($count) {
      if ($index > 0) {
        $timeString .= ($unit eq $last)?' and ':', ';
      }
      $unit =~ s/s$//go if $count == 1;
      $timeString .= "$count $unit";
      $index++;
      last if $index >= $theUnits;
    } 
    writeDebug("unit=$unit, count=$count, timestring=$timeString");
  };

  writeDebug("timeString=$timeString");

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


    # about now
    return DateTime->from_epoch(
      epoch=>time(), 
      time_zone=>'local') unless $date;

    #writeDebug("parseTime($date)");

    my $tz = ($date =~ /GMT$/i)?'GMT':'floating';

    #writeDebug("tz=$tz");

    # NOTE: This routine *will break* if input is not one of below formats!
    
    # FIXME - why aren't ifs around pattern match rather than $5 etc
    # try "31 Dec 2001 - 23:59:11"  (TWiki date)
    if ($date =~ /(\d+)\s+([A-Za-z]+)\s+(\d\d\d\d)[\s\-]+(\d+)\:(\d+)(?:\:(\d+))?/) {
        my $year = $3;
        my $seconds = $6 || 0;
        #$year -= 1900 if( $year > 1900 );
        # The ($2) will look up the constant so named
        #writeDebug("case 1");
        return DateTime->new(
          second=> $seconds, 
          minute=> $5, 
          hour=>$4, 
          day=>$1, 
          month=>$MON2NUM{$2}, 
          year=>$year,
          time_zone=>$tz
        ) 
    }

    # try "31 Dec 2001"
    if ($date =~ /(\d+)\s+([A-Za-z]+)\s+(\d\d\d\d)/) {
        my $year = $3;
        #$year -= 1900 if( $year > 1900 );
        # The ($2) will look up the constant so named
        #writeDebug("case 2");
        return DateTime->new( 
          second=>0, 
          minute=>0,
          hour=>0, 
          day=>$1, 
          month=>$MON2NUM{$2}, 
          year=>$year,
          time_zone=>$tz
        );
    }

    # try "2001/12/31 23:59:59" or "2001.12.31.23.59.59" (RCS date)
    if ($date =~ /(\d\d\d\d)[\.\/\-](\d+)[\.\/\-](\d+)[\.\s\-]+(\d+)[\.\:](\d+)[\.\:](\d+)/) {
        my $year = $1;
        #$year -= 1900 if( $year > 1900 );
        #writeDebug("case 3");
        return DateTime->new( 
          second=>$6, 
          minute=>$5, 
          hour=>$4, 
          day=>$3, 
          month=>$2, 
          year=>$year,
          time_zone=>$tz
        );
    }

    # try "2001/12/31 23:59" or "2001.12.31.23.59" (RCS short date)
    if ($date =~ /(\d\d\d\d)[\.\/\-](\d+)[\.\/\-](\d+)[\.\s\-]+(\d+)[\.\:](\d+)/) {
        my $year = $1;
        #$year -= 1900 if( $year > 1900 );
        #writeDebug("case 4");
        return DateTime->new( 
          second=>0, 
          minute=>$5, 
          hour=>$4, 
          day=>$3, 
          month=>$2, 
          year=>$year,
          time_zone=>$tz
        );
    }

    # try "2001/12/31"
    if ($date =~ /(\d\d\d\d)[\.\/\-](\d+)[\.\/\-](\d+)/) {
        my $year = $1;
        #$year -= 1900 if( $year > 1900 );
        #writeDebug("case 5");
        return DateTime->new( 
          second=>0, 
          minute=>0, 
          hour=>0, 
          day=>$3, 
          month=>$2, 
          year=>$year,
          time_zone=>$tz
        );
    }

    # try "12/31/2001"
    if ($date =~ /(\d+)[\.\/\-](\d+)[\.\/\-](\d\d\d\d)/) {
        my $month = $1;
        my $day = $2;
        my $year = $3;
        if ($day > 12) {
          my $tmp = $month;
          $month = $day;
          $day = $tmp;
        }
        #$year -= 1900 if( $year > 1900 );
        #writeDebug("case 6");
        return DateTime->new( 
          second=>0, 
          minute=>0, 
          hour=>0, 
          day=>$3, 
          month=>$2, 
          year=>$year,
          time_zone=>$tz
        );
    }


    # ISO date
    if ($date =~ /(\d\d\d\d)(?:-(\d\d)(?:-(\d\d))?)?(?:T(\d\d)(?::(\d\d)(?::(\d\d(?:\.\d+)?))?)?)?(Z|[-+]\d\d(?::\d\d)?)?/ ) {
      my ($Y, $M, $D, $h, $m, $s, $myTz) =
        ($1, $2||1, $3||1, $4||0, $5||0, $6||0, $7||'');
      $M--;
      $Y -= 1900 if( $Y > 1900 );
      $tz = $myTz if defined $myTz;
      #writeDebug("case 7");
      return DateTime->new(
        second=>$s, 
        minute=>$m, 
        hour=>$h, 
        day=>$D, 
        month=>$M, 
        year=>$Y,
        time_zone=>$tz,
      );
    }

    # try "2001-12-31T23:59Z" or "2001-12-31T23:59+01:00" (ISO short date)
    # FIXME: Calc local to zulu time "2001-12-31T23:59+01:00"
    if ($date =~ /(\d+)\-(\d+)\-(\d+)T(\d+)\:(\d+)/ ) {
        my $year = $1;
        #$year -= 1900 if( $year > 1900 );
        #writeDebug("case 8");
        return DateTime->new( 
          second=>0, 
          minute=>$5, 
          hour=>$4, 
          day=>$3, 
          month=>$2, 
          year=>$year,
          time_zone=>$tz,
        );
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

