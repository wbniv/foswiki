# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Time

Time handling functions.

API version $Date$ (revision $Rev$)

*Since* _date_ indicates where functions or parameters have been added since
the baseline of the API (TWiki release 4.2.3). The _date_ indicates the
earliest date of a Foswiki release that will support that function or
parameter.

*Deprecated* _date_ indicates where a function or parameters has been
[[http://en.wikipedia.org/wiki/Deprecation][deprecated]]. Deprecated
functions will still work, though they should
_not_ be called in new plugins and should be replaced in older plugins
as soon as possible. Deprecated parameters are simply ignored in Foswiki
releases after _date_.

*Until* _date_ indicates where a function or parameter has been removed.
The _date_ indicates the latest date at which Foswiki releases still supported
the function or parameter.

=cut

# THIS PACKAGE IS PART OF THE PUBLISHED API USED BY EXTENSION AUTHORS.
# DO NOT CHANGE THE EXISTING APIS (well thought out extensions are OK)
# AND ENSURE ALL POD DOCUMENTATION IS COMPLETE AND ACCURATE.

package Foswiki::Time;

use strict;

require Foswiki;

our $VERSION = '$Rev$'; # Subversion rev number

# Constants
use vars qw( @ISOMONTH @WEEKDAY @MONTHLENS %MON2NUM );

@ISOMONTH = (
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
);

# SMELL: does not account for leap years
@MONTHLENS = ( 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 );

@WEEKDAY = ( 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun' );

%MON2NUM = (
    jan => 0,
    feb => 1,
    mar => 2,
    apr => 3,
    may => 4,
    jun => 5,
    jul => 6,
    aug => 7,
    sep => 8,
    oct => 9,
    nov => 10,
    dec => 11
);

=begin TML

---++ StaticMethod parseTime( $szDate, $defaultLocal ) -> $iSecs

Convert string date/time string to seconds since epoch (1970-01-01T00:00:00Z).
   * =$sDate= - date/time string

Handles the following formats:

Default Foswiki format
   * 31 Dec 2001 - 23:59

Foswiki format without time (defaults to 00:00)
   * 31 Dec 2001

Date separated by '/', '.' or '-', time with '.' or ':'
Date and time separated by ' ', '.' and/or '-'
   * 2001/12/31 23:59:59
   * 2001.12.31.23.59.59
   * 2001/12/31 23:59
   * 2001.12.31.23.59
   * 2001-12-31 23:59
   * 2001-12-31 - 23:59

ISO format
   * 2001-12-31T23:59:59
ISO dates may have a timezone specifier, either Z or a signed difference
in hh:mm format. For example:
   * 2001-12-31T23:59:59+01:00
   * 2001-12-31T23:59Z
The default timezone is Z, unless $defaultLocal is true in which case
the local timezone will be assumed.

If the date format was not recognised, will return 0.

=cut

sub parseTime {
    my ( $date, $defaultLocal ) = @_;

    require Time::Local;

    # NOTE: This routine *will break* if input is not one of below formats!
    my $tzadj = 0;    # Zulu
    if ($defaultLocal) {

        # Local time at midnight on the epoch gives us minus the
        # local difference. e.g. CST is GMT + 1, so midnight Jan 1 1970 CST
        # is -01:00Z
        $tzadj = -Time::Local::timelocal( 0, 0, 0, 1, 0, 70 );
    }

    # try "31 Dec 2001 - 23:59"  (Foswiki date)
    # or "31 Dec 2001"
    if ( $date =~ /(\d+)\s+([a-z]{3})\s+(\d+)(?:[-\s]+(\d+):(\d+))?/i ) {
        my $year = $3;
        $year -= 1900 if ( $year > 1900 );
        return Time::Local::timegm( 0, $5 || 0, $4 || 0, $1, $MON2NUM{ lc($2) },
            $year ) - $tzadj;
    }

    # try "2001/12/31 23:59:59" or "2001.12.31.23.59.59" (RCS date)
    # or "2001-12-31 23:59:59" or "2001-12-31 - 23:59:59"
    if (
        $date =~ m!(\d+)[./\-](\d+)[./\-](\d+)[.\s\-]+(\d+)[.:](\d+)[.:](\d+)! )
    {
        my $year = $1;
        $year -= 1900 if ( $year > 1900 );
        return Time::Local::timegm( $6, $5, $4, $3, $2 - 1, $year ) - $tzadj;
    }

    # try "2001/12/31 23:59" or "2001.12.31.23.59" (RCS short date)
    # or "2001-12-31 23:59" or "2001-12-31 - 23:59"
    if ( $date =~ m!(\d+)[./\-](\d+)[./\-](\d+)[.\s\-]+(\d+)[.:](\d+)! ) {
        my $year = $1;
        $year -= 1900 if ( $year > 1900 );
        return Time::Local::timegm( 0, $5, $4, $3, $2 - 1, $year ) - $tzadj;
    }

    # ISO date
    if ( $date =~
/(\d\d\d\d)(?:-(\d\d)(?:-(\d\d))?)?(?:T(\d\d)(?::(\d\d)(?::(\d\d(?:\.\d+)?))?)?)?(Z|[-+]\d\d(?::\d\d)?)?/
      )
    {
        my ( $Y, $M, $D, $h, $m, $s, $tz ) =
          ( $1, $2 || 1, $3 || 1, $4 || 0, $5 || 0, $6 || 0, $7 || '' );
        $M--;
        $Y -= 1900 if ( $Y > 1900 );
        if ( $tz eq 'Z' ) {
            $tzadj = 0;    # Zulu
        }
        elsif ( $tz =~ /([-+])(\d\d)(?::(\d\d))?/ ) {
            $tzadj = ( $1 || '' ) . ( ( ( $2 * 60 ) + ( $3 || 0 ) ) * 60 );
            $tzadj -= 0;
        }
        return Time::Local::timegm( $s, $m, $h, $D, $M, $Y ) - $tzadj;
    }

    # give up, return start of epoch (01 Jan 1970 GMT)
    return 0;
}

=begin TML

---++ StaticMethod formatTime ($epochSeconds, $formatString, $outputTimeZone) -> $value

   * =$epochSeconds= epochSecs GMT
   * =$formatString= twiki time date format, default =$day $month $year - $hour:$min=
   * =$outputTimeZone= timezone to display, =gmtime= or =servertime=, default is whatever is set in $Foswiki::cfg{DisplayTimeValues}
=$formatString= supports:
   | $seconds | secs |
   | $minutes | mins |
   | $hours | hours |
   | $day | date |
   | $wday | weekday name |
   | $dow | day number (0 = Sunday) |
   | $week | week number |
   | $month | month name |
   | $mo | month number |
   | $year | 4-digit year |
   | $ye | 2-digit year |
   | $http | ful HTTP header format date/time |
   | $email | full email format date/time |
   | $rcs | full RCS format date/time |
   | $epoch | seconds since 1st January 1970 |

=cut

# previous known as Foswiki::formatTime

sub formatTime {
    my ( $epochSeconds, $formatString, $outputTimeZone ) = @_;
    my $value = $epochSeconds;

    # use default Foswiki format "31 Dec 1999 - 23:59" unless specified
    $formatString   ||= $Foswiki::cfg{DefaultDateFormat} . ' - $hour:$min';
    $outputTimeZone ||= $Foswiki::cfg{DisplayTimeValues};

    if ( $formatString =~ /http|email/i ) {
        $outputTimeZone = 'gmtime';
    }

    my ( $sec, $min, $hour, $day, $mon, $year, $wday, $tz_str );
    if ( $outputTimeZone eq 'servertime' ) {
        ( $sec, $min, $hour, $day, $mon, $year, $wday ) =
          localtime($epochSeconds);
        $tz_str = 'Local';
    }
    else {
        ( $sec, $min, $hour, $day, $mon, $year, $wday ) = gmtime($epochSeconds);
        $tz_str = 'GMT';
    }

    #standard twiki date time formats
    if ( $formatString =~ /rcs/i ) {

        # RCS format, example: "2001/12/31 23:59:59"
        $formatString = '$year/$mo/$day $hour:$min:$sec';
    }
    elsif ( $formatString =~ /http|email/i ) {

        # HTTP and email header format, e.g. "Thu, 23 Jul 1998 07:21:56 EST"
        # RFC 822/2616/1123
        $formatString = '$wday, $day $month $year $hour:$min:$sec $tz';
    }
    elsif ( $formatString =~ /iso/i ) {

        # ISO Format, see spec at http://www.w3.org/TR/NOTE-datetime
        # e.g. "2002-12-31T19:30:12Z"
        $formatString = '$year-$mo-$dayT$hour:$min:$sec';
        if ( $outputTimeZone eq 'gmtime' ) {
            $formatString = $formatString . 'Z';
        }
        else {

            #TODO:            $formatString = $formatString.
            # TZD  = time zone designator (Z or +hh:mm or -hh:mm)
        }
    }

    $value = $formatString;
    $value =~ s/\$seco?n?d?s?/sprintf('%.2u',$sec)/gei;
    $value =~ s/\$minu?t?e?s?/sprintf('%.2u',$min)/gei;
    $value =~ s/\$hour?s?/sprintf('%.2u',$hour)/gei;
    $value =~ s/\$day/sprintf('%.2u',$day)/gei;
    $value =~ s/\$wday/$WEEKDAY[$wday]/gi;
    $value =~ s/\$dow/$wday/gi;
    $value =~ s/\$week/_weekNumber($day,$mon,$year,$wday)/egi;
    $value =~ s/\$mont?h?/$ISOMONTH[$mon]/gi;
    $value =~ s/\$mo/sprintf('%.2u',$mon+1)/gei;
    $value =~ s/\$year?/sprintf('%.4u',$year+1900)/gei;
    $value =~ s/\$ye/sprintf('%.2u',$year%100)/gei;
    $value =~ s/\$epoch/$epochSeconds/gi;

    # SMELL: how do we get the different timezone strings (and when
    # we add usertime, then what?)
    $value =~ s/\$tz/$tz_str/geoi;

    return $value;
}

sub _weekNumber {
    my ( $day, $mon, $year, $wday ) = @_;

    require Time::Local;

    # calculate the calendar week (ISO 8601)
    my $nextThursday =
      Time::Local::timegm( 0, 0, 0, $day, $mon, $year ) +
      ( 3 - ( $wday + 6 ) % 7 ) * 24 * 60 * 60;    # nearest thursday
    my $firstFourth =
      Time::Local::timegm( 0, 0, 0, 4, 0, $year );    # january, 4th
    return
      sprintf( '%.0f', ( $nextThursday - $firstFourth ) / ( 7 * 86400 ) ) + 1;
}

=begin TML

---++ StaticMethod formatDelta( $s ) -> $string

Format a time in seconds as a string. For example,
"1 day, 3 hours, 2 minutes, 6 seconds"

=cut

sub formatDelta {
    my $secs     = shift;
    my $language = shift;

    my $rem = $secs % ( 60 * 60 * 24 );
    my $days = ( $secs - $rem ) / ( 60 * 60 * 24 );
    $secs = $rem;

    $rem = $secs % ( 60 * 60 );
    my $hours = ( $secs - $rem ) / ( 60 * 60 );
    $secs = $rem;

    $rem = $secs % 60;
    my $mins = ( $secs - $rem ) / 60;
    $secs = $rem;

    my $str = '';

    if ($language) {

        #format as in user's language
        if ($days) {
            $str .= $language->maketext( '[*,_1,day] ', $days );
        }
        if ($hours) {
            $str .= $language->maketext( '[*,_1,hour] ', $hours );
        }
        if ($mins) {
            $str .= $language->maketext( '[*,_1,minute] ', $mins );
        }
        if ($secs) {
            $str .= $language->maketext( '[*,_1,second] ', $secs );
        }
    }
    else {

        #original code, harcoded English (BAD)
        if ($days) {
            $str .= $days . ' day' . ( $days > 1 ? 's ' : ' ' );
        }
        if ($hours) {
            $str .= $hours . ' hour' . ( $hours > 1 ? 's ' : ' ' );
        }
        if ($mins) {
            $str .= $mins . ' minute' . ( $mins > 1 ? 's ' : ' ' );
        }
        if ($secs) {
            $str .= $secs . ' second' . ( $secs > 1 ? 's ' : ' ' );
        }
    }
    $str =~ s/\s+$//;
    return $str;
}

=begin TML

---++ StaticMethod parseInterval( $szInterval ) -> [$iSecs, $iSecs]

Convert string representing a time interval to a pair of integers
representing the amount of seconds since epoch for the start and end
extremes of the time interval.

   * =$szInterval= - time interval string

in yacc syntax, grammar and actions:
<verbatim>
interval ::= date                 { $$.start = fillStart($1); $$.end = fillEnd($1); }
         | date '/' date          { $$.start = fillStart($1); $$.end = fillEnd($3); }
         | 'P' duration '/' date  { $$.start = fillEnd($4)-$2; $$.end = fillEnd($4); }
         | date '/' 'P' duration  { $$.start = fillStart($1); $$.end = fillStart($1)+$4; }
         ;
</verbatim>
an =interval= may be followed by a timezone specification string (this is not supported yet).

=duration= has the form (regular expression):
<verbatim>
   P(<number><nameOfDuration>)+
</verbatim>

nameOfDuration may be one of:
   * y(year), m(month), w(week), d(day), h(hour), M(minute), S(second)

=date= follows ISO8601 and must include hyphens.  (any amount of trailing
       elements may be omitted and will be filled in differently on the
       differents ends of the interval as to include the longest possible
       interval):

   * 2001-01-01T00:00:00
   * 2001-12-31T23:59:59

timezone is optional. Default is local time.

If the format is not recognised, will return empty interval [0,0].

=cut

# TODO: timezone testing, especially on non valid strings

sub parseInterval {
    my ($interval) = @_;
    my @lt    = localtime();
    my $today = sprintf( '%04d-%02d-%02d', $lt[5] + 1900, $lt[4] + 1, $lt[3] );
    my $now   = $today . sprintf( 'T%02d:%02d:%02d', $lt[2], $lt[1], $lt[0] );

    # replace $now and $today shortcuts
    $interval =~ s/\$today/$today/g;
    $interval =~ s/\$now/$now/g;

    # if $theDate does not contain a '/': force it to do so.
    $interval = $interval . '/' . $interval
      unless ( $interval =~ /\// );

    my ($first, $last) = split( /\//, $interval, 2 );
    my ( $start, $end );

    # first translate dates into seconds from epoch,
    # in the second loop we will examine interval durations.

    if ( $first !~ /^P/ ) {
        # complete with parts from "-01-01T00:00:00"
        if ( length($first) < length('0000-01-01T00:00:00')) {
            $first .= substr( '0000-01-01T00:00:00', length( $first ) );
        }
        $start = parseTime( $first, 1 );
    }

    if ($last !~ /^P/) {
        # complete with parts from "-12-31T23:59:60"
        # check last day of month
        # TODO: do we do leap years?
        if ( length( $last ) == 7 ) {
            my $month = substr( $last, 5 );
            $last .= '-'.$MONTHLENS[ $month - 1 ];
        }
        if ( length($last) < length('0000-12-31T23:59:59')) {
            $last .= substr( '0000-12-31T23:59:59', length( $last ) );
        }
        $end = parseTime( $last, 1 );
    }

    if (!defined($start)) {
        $start = ($end || 0) - _parseDuration( $first );
    }
    if (!defined($end)) {
        $end = $start + _parseDuration( $last );
    }
    return ( $start || 0, $end || 0);
}

sub _parseDuration {
    my $s = shift;
    my $d = 0;
    $s =~ s/(\d+)y/$d += $1 * 31556925;''/gei;    # tropical year
    $s =~ s/(\d+)m/$d += $1 * 2592000; ''/ge;     # 1m = 30 days
    $s =~ s/(\d+)w/$d += $1 * 604800;  ''/gei;    # 1w = 7 days
    $s =~ s/(\d+)d/$d += $1 * 86400;   ''/gei;    # 1d = 24 hours
    $s =~ s/(\d+)h/$d += $1 * 3600;    ''/gei;    # 1 hour = 60 mins
    $s =~ s/(\d+)M/$d += $1 * 60;      ''/ge;     # note: m != M
    $s =~ s/(\d+)S/$d += $1 * 1;       ''/gei;
    return $d;
}

1;
__DATA__
# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008 Foswiki Contributors. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 2002 John Talintyre, john.talintyre@btinternet.com
# Copyright (C) 2002-2007 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
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
#
# As per the GPL, removal of this notice is prohibited.
