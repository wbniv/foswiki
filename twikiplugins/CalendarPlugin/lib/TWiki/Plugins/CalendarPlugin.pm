# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2001 Andrea Sterbini, a.sterbini@flashnet.it
# Christian Schultze: debugging, relative month/year, highlight today
# Akim Demaille <akim@freefriends.org>: handle date intervals.
# Copyright (C) 2002-2006 Peter Thoeny, peter@thoeny.org
#
# For licensing info read LICENSE file in the TWiki root.
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
# As per the GPL, removal of this notice is prohibited.
#
# =========================
#
# This is a plugin for showing a Month calendar with events.
#
# =========================
package TWiki::Plugins::CalendarPlugin;


# use strict;
use Time::Local;
#use Date::Calc;
#use HTML::CalendarMonthSimple;

# =========================
use vars qw( $web $topic $user $installWeb $VERSION $RELEASE $pluginName $debug
	    $libsLoaded $libsError $defaultsInitialized %defaults );
$VERSION   = '$Rev: 9189 $';
$RELEASE = 'Dakar';

#$VERSION   = '1.020'; #dab# Bug fix from TWiki:Main.MarcLangheinrich for multiday events that were not properly displayed because the first day occurred in the current month, but before the first day included in the list.
#$VERSION   = '1.019'; #dab# Added support for monthly repeaters specified as "L Fri" (last Friday in all months).
#$VERSION   = '1.018'; #dab# Added support displaying calendars for multiple months; added support for displaying events as a list
#$VERSION   = '1.017';  #dro# Added start and end date support for periodic repeaters; Added initlang patch by TWiki:Main.JensKloecker; Changed 'my' to 'local' so exceptions working again; Removed fetchxmap debug message; Fixed illegal date bug; Allowed month abbreviations in month attribute
#VERSION   = '1.016';  #dab# Added support for anniversary events; changed "our" to "my" in module to support perl versions prior to 5.6.0
#VERSION   = '1.015';  #pf# Added back support for preview showing unsaved events; Two loop fixes from DanielRohde
#VERSION   = '1.014';  #nk# Added support for start and end dates in weekly repeaters
#VERSION   = '1.013';  #mrjc# Added support for multiple sources in topic=
#VERSION   = '1.012';  #PTh# Added missing doc of gmtoffset parameter (was deleted in 1.011)
#VERSION   = '1.011';  #PTh# fix deep recursion bug; preview shows unsaved events; performance improvements
#VERSION   = '1.010';  #db# fix variable conflict in timezone code
#VERSION   = '1.009';  #db# fix to allow event topics in other webs
#VERSION   = '1.008';  #db# lang patch integrated, yearly day/mon repeaters added
#VERSION   = '1.007';  #ap# attributes for day headings
#VERSION   = '1.006';  #db# support Monthly items
#VERSION   = '1.005';  #ad# support Date intervals
#VERSION   = '1.004';  #as# only HTML::CalendarMonthSimple, ISO dates, options
#VERSION   = '1.003';  #as# now also with HTML::CalendarMonthSimple
#VERSION   = '1.002';  #cs# debug, relative month/year, highlight today
#VERSION   = '1.001';  #as# delayed load
#VERSION   = '1.000';  #as# initial release

$pluginName="CalendarPlugin";

$debug=0;


$libsLoaded = 0;
$libsError  = 0;
$defaultsInitialized = 0;
%defaults   = ();

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    $defaultsInitialized = 0;
    # return true if initialization OK
    return 1;
}

# =========================
sub initDefaults
{
    my $webColor = &TWiki::Func::getPreferencesValue('WEBBGCOLOR', $web) ||
		    'wheat' ;

    # reasonable defaults to produce a small calendar
    %defaults = (
	# normal HTML::CalendarMonthSimple options
	border				=> 1,
	width				=> 0,
	showdatenumbers			=> 0,
	showweekdayheaders		=> 0,
	weekdayheadersbig		=> undef, # the default is ok
	cellalignment			=> 'center',
	vcellalignment			=> 'center',
	header				=> undef, # the default is ok
	nowrap				=> undef, # the default is ok
	sharpborders			=> 1,
	cellheight			=> undef, # the default is ok
	cellclass			=> undef, # the default is ok
	weekdaycellclass		=> undef, # the default is ok
	weekendcellclass		=> undef, # the default is ok
	todaycellclass			=> undef, # the default is ok
	headerclass			=> undef, # the default is ok
	# colors
	bgcolor				=> 'white',
	weekdaycolor			=> undef, # the default is ok
	weekendcolor			=> 'lightgrey',
	todaycolor			=> $webColor,
	bordercolor			=> 'black',
	weekdaybordercolor		=> undef, # the default is ok
	weekendbordercolor		=> undef, # the default is ok
	todaybordercolor		=> undef, # the default is ok
	contentcolor			=> undef, # the default is ok
	weekdaycontentcolor		=> undef, # the default is ok
	weekendcontentcolor		=> undef, # the default is ok
	todaycontentcolor		=> undef, # the default is ok
	headercolor			=> $webColor,
	headercontentcolor		=> undef, # the default is ok
	weekdayheadercolor		=> undef, # the default is ok
	weekdayheadercontentcolor	=> undef, # the default is ok
	weekendheadercolor		=> undef, # the default is ok
	weekendheadercontentcolor	=> undef, # the default is ok
        weekstartsonmonday              => '0',
	# other options not belonging to HTML::CalendarMonthSimple
	daynames			=> undef, # order is: Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday
	lang			=> 'English',
	topic			=> $topic,
	web			=> $web,
	format			=> undef,
	datenumberformat	=> undef,
	todaydatenumberformat	=> undef,
	multidayformat		=> undef, # Default: display description unchanged
    );

    # now get defaults from CalendarPlugin topic
    my $v;
    foreach $option (keys %defaults) {
	# read defaults from CalendarPlugin topic
	$v = &TWiki::Func::getPreferencesValue("CALENDARPLUGIN_\U$option\E") || undef;
	$defaults{$option} = $v if defined($v);
    }
    $defaultsInitialized = 1;
}

# =========================
sub commonTagsHandler
{
    $_[0] =~ s/%CALENDAR{(.*?)}%/&handleCalendar( $1, \$_[0], $_[1], $_[2] )/geo;
    $_[0] =~ s/%CALENDAR%/&handleCalendar(        '', \$_[0], $_[1], $_[2] )/geo;
}

# =========================
sub readTopicText
{
    my( $theWeb, $theTopic ) = @_;
    my $text = '';
    if( $TWiki::Plugins::VERSION >= 1.010 ) {
        $text = &TWiki::Func::readTopicText( $theWeb, $theTopic, '', 1 );
    } else {
        $text = &TWiki::Func::readTopic( $theWeb, $theTopic );
    }
    # return raw topic text, including meta data
    return $text;
}

# =========================
sub expandIncludedEvents
{
    my( $theAttributes, $theWeb, $theTopic, @theProcessedTopics ) = @_;

    my $webTopic = &TWiki::Func::extractNameValuePair( $theAttributes );
    if( $webTopic =~ m|^([^.]+)[\.\/](.*)$| ) {
        $theWeb = $1;
        $theTopic = $2;
    } else {
        $theTopic = $webTopic;
    }

    # prevent recursive loop
    if( ( @theProcessedTopics ) && ( grep { /^$theWeb.$theTopic$/ } @theProcessedTopics ) ) {
        # file already included
        return '';
    } else {
        # remember for next time
        push( @theProcessedTopics, "$theWeb.$theTopic" );
    }

    my $text = &readTopicText( $theWeb, $theTopic );
    $text =~ s/.*?%STARTINCLUDE%//s;
    $text =~ s/%STOPINCLUDE%.*//s;

    # recursively expand includes
    $text =~ s/%INCLUDE{(.*?)}%/&expandIncludedEvents( $1, $theWeb, $theTopic, @theProcessedTopics )/geo;
    return $text;
}

# =========================
sub fetchDays
{
    my( $pattern, $refBullets ) = @_;

    $pattern = "^\\s*\\*\\s+$pattern(\\s+X\\s+{(.+)})?\\s+-\\s+(.*)\$";
    my @res = map { join '|', ( map { $_ || '' } m/$pattern/ ) }
              grep { m/$pattern/ } @$refBullets;

    # Remove the bullets we handled, so that when several patterns
    # match a line, only the first pattern is really honored.
    @{$refBullets} = grep { !m/$pattern/ } @{ $refBullets };

    return @res;
}

# =========================
sub emptyxmap {
	use Date::Calc qw( Days_in_Month );
	($y, $m) = @_;
	for $d (1..Days_in_Month($y, $m)) {
		$ret[$d] = 1;
	}
	return @ret;
}

# =========================
sub fetchxmap {
	use Date::Calc qw( Add_Delta_Days );
	($xlist, $y, $m) = @_;
	@ret = &emptyxmap($y, $m);
	@xcepts = split ',', $xlist;
	for $xc (@xcepts) {
		if (@dparts = $xc =~ m/$full_date_rx\s*-\s*$full_date_rx/) {
			($d1, $m1, $y1, $d2, $m2, $y2) = @dparts;
			$m1 = $months{$m1};
			$m2 = $months{$m2};
			if (($m1 <= $m && $y1 <= $y) && ($m2 >= $m && $y2 >= $y)) {
				unless ($m1 == $m && $y1 == $y) {
					$m1 = $m;
					$y1 = $y;
					$d1 = 1;
				}
				do {
					$ret[$d1] = 0;
					($y1, $m1, $d1) = Add_Delta_Days($y1, $m1, $d1, 1);
				} until ($m1 != $m || ($m1 == $m2 && $d1 > $d2));
			}
		} elsif (@dparts = $xc =~ m/$full_date_rx/) {
			($d1, $m1, $y1) = @dparts;
			$m1 = $months{$m1};
			if ($m1 == $m && $y1 == $y) {
				$ret[$d1] = 0;
			}
		}
	}
	return @ret;
}

# =========================
sub handleCalendar
{
    my( $attributes, $refText, $theTopic, $theWeb ) = @_;
    my $result = '';	  # This is used to accumulate the result text

    use Date::Calc qw( 
		       Add_Delta_Days 
		       Add_Delta_YM
		       Add_Delta_YMDHMS 
		       Date_to_Days 
		       Day_of_Week 
		       Days_in_Month 
		       Nth_Weekday_of_Month_Year 
		       Today 
		       Today_and_Now 
		       );

    # lazy load of needed libraries
    if (   $libsError  ) { die 'missing Date::Calc';  }
    if ( ! $libsLoaded ) {
	eval 'require HTML::CalendarMonthSimple';
	if ( defined( $HTML::CalendarMonthSimple::VERSION ) ) {
	    $libsLoaded = 1;
	} else	{
	    $libsError = 1;
	    die 'missing HTML::CalendarMonthSimple';
	}
    }
    initDefaults() unless( $defaultsInitialized );

    # read options from the %CALENDAR% tag
    my %options = %defaults;
    my $v;
    my $orgtopic = $options{topic};
    my $orgweb = $options{web};
    foreach $option (keys %options) {
	$v = &TWiki::Func::extractNameValuePair($attributes,$option) || undef;
	$options{$option} = $v if defined($v);
    }

    # get GMT offset
    my ($currentYear, $currentMonth, $currentDay, $currentHour, $currentMinute, $currentSecond) = Today_and_Now(1);
    my $gmtoff = scalar &TWiki::Func::extractNameValuePair( $attributes, 'gmtoffset' );
    if ( $gmtoff ) {
    	$gmtoff += 0;
    	($currentYear,
	 $currentMonth,
	 $currentDay,
	 $currentHour,
	 $currentMinute,
	 $currentSecond) = Add_Delta_YMDHMS($currentYear,
					    $currentMonth,
					    $currentDay,
					    $currentHour,
					    $currentMinute,
					    $currentSecond,
					    0, 0, 0, $gmtoff, 0, 0);
    }


    # read fixed months/years
    my $m = scalar &TWiki::Func::extractNameValuePair( $attributes, 'month' );
    my $y = scalar &TWiki::Func::extractNameValuePair( $attributes, 'year' );

    # Check syntax of year parameter. It can be blank (meaning the
    # current year), an absolute number, or a relative number (e.g.,
    # "+1", meaning next year).

    if (!$y || $y =~ /^[-+]?\d+$/) {
	# OK
	$y = 0 if $y eq '';	# to avoid warnings in +=
	# Add current year if year is 0 or relative
	$y += $currentYear if $y =~ /^([-+]\d+|0)$/; # must come before $m !
    } else {
	return "\n\n%<nop>CALENDAR{$attributes}% has invalid year specification.\n\n";
    }

    # Check syntax of month parameter. It can be blank (meaning the
    # current month), a month abbreviation, an absolute number, or a
    # relative number (e.g., "+1", meaning next month).

    if (!$m || $m =~ /^[-+]?\d+$/) {
	# OK - absolute or relative number
        $m = 0 if $m eq '';	# to avoid warnings in +=
	# Add current month if month is 0 or relative
        $m += $currentMonth if ($m =~ /^([-+]\d+|0)$/); 
        ($m += 12, --$y) while $m <= 0;
        ($m -= 12, ++$y) while $m > 12;
    } elsif ( $m=~ /^(\w{3})$/) {
	# Could be month abbreviation
	if (defined $months{$1}) {
	    # OK - month abbreviation
	    $m = $months{$1} 
	} else {
	    return "\n\n%<nop>CALENDAR{$attributes}% has invalid month specification.\n\n";
	}
    } else {
	return "\n\n%<nop>CALENDAR{$attributes}% has invalid month specification.\n\n";
    } 

    # read and set the desired language
    my $lang = scalar &TWiki::Func::extractNameValuePair( $attributes, 'lang' );
    $lang = $lang ? $lang : $defaults{lang};
    Date::Calc::Language(Date::Calc::Decode_Language($lang));


    local %months = (  Jan=>1, Feb=>2, Mar=>3, Apr=>4,  May=>5,  Jun=>6,
		       Jul=>7, Aug=>8, Sep=>9, Oct=>10, Nov=>11, Dec=>12);


    # Process "aslist" parameter (if set, display the calendar as a
    # list, not as a table)

    my $asList = scalar &TWiki::Func::extractNameValuePair( $attributes,
							    'aslist' );

    if ($asList) {

    # If displaying as a list, force showdatenumbers to 1 so that the
    # Plugin can format them later.  This logic seems backwards, but
    # if showdatenumber is 0, the calendar initialization code below
    # will put date numbers into the contents of each day. Then, when
    # displaying the list, every day will be included in the list
    # because the contents are not "empty." This would produce an ugly
    # list. In contrast, if HTML::CalendarSimple is told to put the
    # date numbers on the calendar, this will be done outside of the
    # content. Therefore, we can later display only those days that
    # actually have events, at the cost of formatting the date numbers
    # again.


	$options{showdatenumbers} = 1;
	if (!$options{format}) {
	    $options{format} = '$old - $description<br />$n';
	}
	if (!$options{datenumberformat}) {
	    $options{datenumberformat} = '	* $day $mon $year';
	}
    } else {
	if (!$options{format}) {
	    $options{format} = '$old<br /><small> $description </small>';
	}
	if (!$options{datenumberformat}) {
	    $options{datenumberformat} = '$day';
	}
    }

    # Default todaydatenumberformat to datenumberformat if not otherwise set

    $options{todaydatenumberformat} = $options{datenumberformat} if (! $options{todaydatenumberformat});    

    # Process "days" parameter (goes with aslist=1; specifies the
    # number of days of calendar data to list).  Default is 1.

    my $numDays = scalar &TWiki::Func::extractNameValuePair( $attributes,
							     'days' );
    $numDays = 1 if (! $numDays);

    # Process "months" parameter (goes with aslist=0; specifies the
    # number of months of calendar data to list) Default is 1.

    my $numMonths = scalar &TWiki::Func::extractNameValuePair( $attributes, 'months' );
    $numMonths = 1 if (! $numMonths);

    # Figure out last month/year to display. This calculation depends
    # upon whether we are doing a list display or calendar display.

    my $lastMonth = $m + 0;
    my $lastYear = $y + 0;
    my $listStartDay = 1; # Starting day of the month for an event list display

    if ($asList) {

	# Add the number of days past our start day. The start day is
	# today if the month being displayed is the current month. If
	# it is *not* the current month, then start with day 1 of the
	# starting month.

	if (($y != $currentYear) && ($m != $currentMonth)) {
	    $listStartDay = 1;
	} else {
	    $listStartDay = $currentDay;
	} 
	($lastYear, $lastMonth) = Add_Delta_Days($y, $m, $listStartDay,
						 $numDays - 1);
    } else {
	($lastYear, $lastMonth) = Add_Delta_YM($y, $m, 1, 0, $numMonths - 1);
    }

    # Read in the event list. For the sake of efficiency, this is done
    # before entering the loop for producing the calendar(s).

    my $text = getTopicText($theTopic, $theWeb, $refText, %options);

    # recursively expand includes
    # (don't rely on TWiki::Func::expandCommonVariables to avoid deep recursion)
    $text =~ s/%INCLUDE{(.*?)}%/&expandIncludedEvents( $1, $options{web}, $options{topic}, () )/geo;

    # Before this was modified to do multiple months, there was a
    # clause to bail out early if there were no events, simply
    # returning a "blank" calendar. However, since the plugin can now
    # do multiple calendars, the loop to do so needs to be executed
    # even if there are no events to display (so multiple blank
    # calendars can be displayed!). A small optimization is lost, but
    # the number of times people display blank calendars will
    # hopefully be small enough that this won't matter.

    # These two hashes are used to keep track of multi-day events that
    # occur over month boundaries. This is needed for processing the
    # multidayformat. The counter variable is used in the loops for
    # identifying the events by ordinal number of their occurence. The
    # counter will produce the same result each time through the loop
    # since the text is read once (above).

    my %multidayeventswithyear = ();
    my %multidayeventswithoutyear = ();
    my $multiday_counter;

    # Loop, displaying one month at a time for the number of months
    # requested.

    while (($y < $lastYear) || (($y <= $lastYear) && ($m <= $lastMonth))) {
	my $cal = new HTML::CalendarMonthSimple(month => $m, year => $y,
						today_year => $currentYear,
						today_month => $currentMonth,
						today_date => $currentDay);

	# set the day names in the desired language
	$cal->saturday(Date::Calc::Day_of_Week_to_Text(6));
	$cal->sunday(Date::Calc::Day_of_Week_to_Text(7));
	$cal->weekdays(map { Date::Calc::Day_of_Week_to_Text $_ } (1..5));

	my $p = '';
	while (($k,$v) = each %options) {
	    $p = "HTML::CalendarMonthSimple::$k";
	    $cal->$k($v) if defined(&$p);
	}

	# header color
	my $webColor = &TWiki::Func::getPreferencesValue('WEBBGCOLOR',
							 $options{web}) ||
							     'wheat' ;
	# Highlight today
	$options{todaycolor}  = $webColor;
	$options{headercolor} = $webColor;

	# set the initial day values if normal date numbers are not shown
	if ($cal->showdatenumbers == 0) {
	    for ($i=1; $i<33 ; $i++) {
		if (($cal->month == $cal->today_month())
		    && ($cal->year == $cal->today_year())
		    && ($i == $cal->today_date())) {
		    $cal->setcontent($i, &formatToday($cal, $i, %options));
		} else {
		    $cal->setcontent($i, &formatDateNumber($cal, $i, %options));
		}
	    }
	}

	# set names for days of the week
	if ($options{showweekdayheaders} && defined($options{daynames}))
	{
	    my @daynames = split( /\|/, $options{daynames} );
	    if (@daynames == 7)
	    {
		$cal->weekdays( $daynames[0], $daynames[1], $daynames[2],
				$daynames[3], $daynames[4] );
		$cal->saturday( $daynames[5] );
		$cal->sunday( $daynames[6] );
	    }
	}

	# parse events
	my @days = ();
	my ($descr, $d, $dd, $mm, $yy) =
	    ('',     '', '',  '',  '' );
	local %months = (  Jan=>1, Feb=>2, Mar=>3, Apr=>4,  May=>5,  Jun=>6,
			   Jul=>7, Aug=>8, Sep=>9, Oct=>10, Nov=>11, Dec=>12);
	local %wdays = ( Sun=>7, Mon=>1, Tue=>2, Wed=>3, Thu=>4, Fri=>5, Sat=>6);
	local $days_rx = '[0-9]?[0-9]';
	local $months_rx = join ('|', keys %months);
	local $wdays_rx = join ('|', keys %wdays);
	local $years_rx = '[12][0-9][0-9][0-9]';
	local $date_rx = "($days_rx)\\s+($months_rx)";
	local $monthly_rx = "([1-6L])\\s+($wdays_rx)";
	local $full_date_rx = "$date_rx\\s+($years_rx)";
	local $anniversary_date_rx = "A\\s+$date_rx\\s+($years_rx)";
	local $weekly_rx = "E\\s+($wdays_rx)";
	local $periodic_rx = "E([0-9]+)\\s+$full_date_rx";
	local $numdaymon_rx = "([0-9L])\\s+($wdays_rx)\\s+($months_rx)";

	# Keep only bullet lines from the text. Note that this is done
	# inside the loop because as each pattern is matched by
	# fetchDays, the matched lines are deleted from the bullet
	# list. Therefore, if multiple months are being displayed, all
	# but the first month would be blank were @bullets set up
	# outside the loop.

	my @bullets = grep { /^\s+\*/ } split( /[\n\r]+/, $text );

	# collect all date intervals with year
	@days = fetchDays( "$full_date_rx\\s+-\\s+$full_date_rx", \@bullets );
	$multidaycounter = 0;
	foreach $d (@days) {
	    my ($dd1, $mm1, $yy1, $dd2, $mm2, $yy2, $xs, $xcstr, $descr) = split( /\|/, $d);
	    $multidaycounter++; # Identify this event
	    eval {
		if (length($xcstr) > 9) {
		    @xmap = &fetchxmap($xcstr, $y, $m);
		} else {
		    @xmap = &emptyxmap($y, $m);
		}
		my $date1 = Date_to_Days ($yy1, $months{$mm1}, $dd1);
		my $date2 = Date_to_Days ($yy2, $months{$mm2}, $dd2);

		# Process events starting at the first day to be included in
		# the list, or the first day of the month, whichever is
		# appropriate 

		for my $d ((defined $listStartDay ? $listStartDay : 1) .. Days_in_Month ($y, $m)) {
		    my $date = Date_to_Days ($y, $m, $d);
		    if ($date1 <= $date && $date <= $date2 && $xmap[$d]) {
			&highlightMultiDay($cal, $d, $descr, $date1, $date2, $date,
					   defined($multidayeventswithyear{$multidaycounter}),
					   %options);
			# Mark this event as having been displayed
			$multidayeventswithyear{$multidaycounter}++;
		    }
		}
	    };
	    &TWiki::Func::writeWarning( "$pluginName: $@ " ) if $@ && $debug;
	}
	# then collect all intervals without year
	@days = fetchDays( "$date_rx\\s+-\\s+$date_rx", \@bullets );
	$multidaycounter = 0;
	foreach $d (@days) {
	    my ($dd1, $mm1, $dd2, $mm2, $xs, $xcstr, $descr) = split( /\|/, $d);
	    $multidaycounter++; # Identify this event
	    eval {
		if (length($xcstr) > 9) {
		    @xmap = &fetchxmap($xcstr, $y, $m);
		} else {
		    @xmap = &emptyxmap($y, $m);
		}
		my $date1 = Date_to_Days ($y, $months{$mm1}, $dd1);
		my $date2 = Date_to_Days ($y, $months{$mm2}, $dd2);

		# Process events starting at the first day to be included in
		# the list, or the first day of the month, whichever is
		# appropriate 

		for my $d ((defined $listStartDay ? $listStartDay : 1) .. Days_in_Month ($y, $m)) {
		    my $date = Date_to_Days ($y, $m, $d);
		    if ($date1 <= $date && $date <= $date2 && $xmap[$d]) {
			&highlightMultiDay($cal, $d, $descr, $date1, $date2, $date,
					   defined($multidayeventswithoutyear{$multidaycounter}),
					   %options);
			# Mark this event as having been displayed
			$multidayeventswithoutyear{$multidaycounter}++;
		    }
		}
	    };
	    &TWiki::Func::writeWarning( "$pluginName: $@ " ) if $@ && $debug;
	}
	# first collect all dates with year
	@days = fetchDays( "$full_date_rx", \@bullets );
	foreach $d (@days) {
	    ($dd, $mm, $yy, $xs, $xcstr, $descr) = split( /\|/, $d);
	    eval {
		if ($yy == $y && $months{$mm} == $m) {
		    &highlightDay( $cal, $dd, $descr, %options);
		}
	    };
	    &TWiki::Func::writeWarning( "$pluginName: $@ " ) if $@ && $debug;
	}
	# collect all anniversary dates
	@days = fetchDays( "$anniversary_date_rx", \@bullets );
	foreach $d (@days) {
	    ($dd, $mm, $yy, $xs, $xcstr, $descr) = split( /\|/, $d);
	    eval {
		if ($yy <= $y && $months{$mm} == $m) {

		    # Annotate anniversaries with the number of years
		    # since the original occurence. Do not annotate
		    # the first occurence (i.e., someone's birth date
		    # looks like "X's Birthday", not "X's Birthday
		    # (0)", but for subsequent years it will look like
		    # "X's Birthday (3)", meaning that they are 3
		    # years old.

		    my $elapsed = $y - $yy;
		    my $elapsed_indicator = ($elapsed > 0) 
			? " ($elapsed)"
			: '';
		    &highlightDay( $cal, $dd, $descr . $elapsed_indicator, %options);
		}
	    };
	    &TWiki::Func::writeWarning( "$pluginName: $@ " ) if $@ && $debug;
	}
	# then collect all dates without year
	@days = fetchDays( "$date_rx", \@bullets );
	foreach $d (@days) {
	    ($dd, $mm, $xs, $xcstr, $descr) = split( /\|/, $d);
	    eval {
		if (length($xcstr) > 9) {
		    @xmap = &fetchxmap($xcstr, $y, $m);
		} else {
		    @xmap = &emptyxmap($y, $m);
		}
		if ($months{$mm} == $m && $xmap[$dd]) {
		    &highlightDay( $cal, $dd, $descr, %options );
		}
	    };
	    &TWiki::Func::writeWarning( "$pluginName: $@ " ) if $@ && $debug;
	}

	# collect monthly repeaters
	@days = fetchDays( "$monthly_rx", \@bullets );
	foreach $d (@days) {
	    ($nn, $dd, $xs, $xcstr, $descr) = split( /\|/, $d);
	    eval {
		if (length($xcstr) > 9) {
		    @xmap = &fetchxmap($xcstr, $y, $m);
		} else {
		    @xmap = &emptyxmap($y, $m);
		}
		if ($nn eq 'L') {
		    $nn = 6;
		    do {
			$nn--;
			$hd = Nth_Weekday_of_Month_Year($y, $m, $wdays{$dd}, $nn);
		    } until ($hd);
		} else {
		    $hd = Nth_Weekday_of_Month_Year($y, $m, $wdays{$dd}, $nn);
		}
		if ($hd <= Days_in_Month($y, $m) && $xmap[$hd]) {
		    &highlightDay( $cal, $hd, $descr, %options );
		}
	    };
	    &TWiki::Func::writeWarning( "$pluginName: $@ " ) if $@ && $debug;
	}

	# collect weekly repeaters with start and end dates
	@days = fetchDays( "$weekly_rx\\s+$full_date_rx\\s+-\\s+$full_date_rx", \@bullets );
	foreach $d (@days) {
	    ($dd, $dd1, $mm1, $yy1, $dd2, $mm2, $yy2, $xs, $xcstr, $descr) = split( /\|/, $d);
	    eval {
		if (length($xcstr) > 9) {
		    @xmap = &fetchxmap($xcstr, $y, $m);
		} else {
		    @xmap = &emptyxmap($y, $m);
		}
		my $date1 = Date_to_Days ($yy1, $months{$mm1}, $dd1);
		my $date2 = Date_to_Days ($yy2, $months{$mm2}, $dd2);
		$hd = Nth_Weekday_of_Month_Year($y, $m, $wdays{$dd}, 1);
		do {
		    my $date = Date_to_Days ($y, $m, $hd);
		    if ($xmap[$hd] && $date1 <= $date && $date <= $date2) {
			&highlightDay( $cal, $hd, $descr, %options );
		    }
		    ($ny, $nm, $hd) = Add_Delta_Days($y, $m, $hd, 7);
		} while ($ny == $y && $nm == $m);
	    };
	    &TWiki::Func::writeWarning( "$pluginName: $@ " ) if $@ && $debug;
	}

	# collect weekly repeaters with start dates
	@days = fetchDays( "$weekly_rx\\s+$full_date_rx", \@bullets );
	foreach $d (@days) {
	    ($dd, $dd1, $mm1, $yy1, $xs, $xcstr, $descr) = split( /\|/, $d);
	    eval {
		if (length($xcstr) > 9) {
		    @xmap = &fetchxmap($xcstr, $y, $m);
		} else {
		    @xmap = &emptyxmap($y, $m);
		}
		my $date1 = Date_to_Days ($yy1, $months{$mm1}, $dd1);
		$hd = Nth_Weekday_of_Month_Year($y, $m, $wdays{$dd}, 1);
		do {
		    my $date = Date_to_Days ($y, $m, $hd);
		    if ($xmap[$hd] && $date1 <= $date) {
			&highlightDay( $cal, $hd, $descr, %options );
		    }
		    ($ny, $nm, $hd) = Add_Delta_Days($y, $m, $hd, 7);
		} while ($ny == $y && $nm == $m);
	    };
	    &TWiki::Func::writeWarning( "$pluginName: $@ " ) if $@ && $debug;
	}

	# collect weekly repeaters
	@days = fetchDays( "$weekly_rx", \@bullets );
	foreach $d (@days) {
	    ($dd, $xs, $xcstr, $descr) = split( /\|/, $d);
	    eval {
		if (length($xcstr) > 9) {
		    @xmap = &fetchxmap($xcstr, $y, $m);
		} else {
		    @xmap = &emptyxmap($y, $m);
		}
		$hd = Nth_Weekday_of_Month_Year($y, $m, $wdays{$dd}, 1);
		do {
		    if ($xmap[$hd]) {
			&highlightDay( $cal, $hd, $descr, %options );
		    }
		    ($ny, $nm, $hd) = Add_Delta_Days($y, $m, $hd, 7);
		} while ($ny == $y && $nm == $m);
	    };
	    &TWiki::Func::writeWarning( "$pluginName: $@ " ) if $@ && $debug;
	}

	# collect num-day-mon repeaters
	@days = fetchDays( "$numdaymon_rx", \@bullets );
	foreach $d (@days) {
	    ($dd, $dy, $mn, $xs, $xcstr, $descr) = split( /\|/, $d);
	    eval {
		$mn = $months{$mn};
		if (length($xcstr) > 9) {
		    @xmap = &fetchxmap($xcstr, $y, $m);
		} else {
		    @xmap = &emptyxmap($y, $m);
		}
		if ( $mn == $m ) {
		    if ($dd eq 'L') {
			$dd = 6;
			do {
			    $dd--;
			    $hd = Nth_Weekday_of_Month_Year($y, $m, $wdays{$dy}, $dd);
			} until ($hd);
		    } else {
			$hd = Nth_Weekday_of_Month_Year($y, $m, $wdays{$dy}, $dd);
		    }
		    if ($xmap[$hd]) {
			&highlightDay( $cal, $hd, $descr, %options );
		    }
		}
	    };
	    &TWiki::Func::writeWarning( "$pluginName: $@ " ) if $@ && $debug;
	}

	# collect periodic repeaters with start and end dates
	@days = fetchDays( "$periodic_rx\\s+-\\s+$full_date_rx", \@bullets );
	foreach $d (@days) {
	    my ($p, $dd1, $mm1, $yy1, $dd2, $mm2, $yy2, $xs, $xcstr, $descr) = split( /\|/, $d);
	    eval {
		if (length($xcstr) > 9) {
		    @xmap = &fetchxmap($xcstr, $y, $m);
		} else {
		    @xmap = &emptyxmap($y, $m);
		}
		$mm1= $months{$mm1};
		while (  $yy1 < $y  || ( $yy1==$y  &&  $mm1 < $m )) {
		    ($yy1, $mm1, $dd1) = Add_Delta_Days($yy1, $mm1, $dd1, $p);
		}
		my $ldate = Date_to_Days ($yy2, $months{$mm2}, $dd2);
		while ( ($yy1 == $y) && ($mm1 == $m) ) {
		    my $date = Date_to_Days($yy1, $mm1, $dd1);
		    if ($xmap[$dd1] && ($date <=$ldate)) {
			&highlightDay( $cal, $dd1, $descr, %options );
		    }
		    ($yy1, $mm1, $dd1) = Add_Delta_Days($yy1, $mm1, $dd1, $p);
		}
	    };	
	    &TWiki::Func::writeWarning( "$pluginName: $@ " ) if $@ && $debug;
	}

	# collect periodic repeaters
	@days = fetchDays( "$periodic_rx", \@bullets );
	foreach $d (@days) {
	    ($p, $dd, $mm, $yy, $xs, $xcstr, $descr) = split( /\|/, $d);
	    eval {
		if (length($xcstr) > 9) {
		    @xmap = &fetchxmap($xcstr, $y, $m);
		} else {
		    @xmap = &emptyxmap($y, $m);
		}
		$mm = $months{$mm};
		if (($mm <= $m && $yy == $y) || ($yy < $y)) {
		    while ($yy < $y || ($yy == $y && $mm < $m)) {
			($yy, $mm, $dd) = Add_Delta_Days($yy, $mm, $dd, $p);
		    }
		    while ($yy == $y && $mm == $m) {
			if ($xmap[$dd]) {
			    &highlightDay( $cal, $dd, $descr, %options );
			}
			($yy, $mm, $dd) = Add_Delta_Days($yy, $mm, $dd, $p);
		    }
		}
	    };
	    &TWiki::Func::writeWarning( "$pluginName: $@ " ) if $@ && $debug;
	}

	# collect date monthly repeaters
	@days = fetchDays( "($days_rx)", \@bullets );
	foreach $d (@days) {
	    ($dd, $xs, $xcstr, $descr) = split( /\|/, $d);
	    eval {
		if (length($xcstr) > 9) {
		    @xmap = &fetchxmap($xcstr, $y, $m);
		} else {
		    @xmap = &emptyxmap($y, $m);
		}
		if ($dd > 0 && $dd <= Days_in_Month($y, $m) && $xmap[$dd]) {
		    &highlightDay( $cal, $dd, $descr, %options );
		}
	    };
	    &TWiki::Func::writeWarning( "$pluginName: $@ " ) if $@ && $debug;
	}

	# Format the calendar as either a list or a table

	if (! $asList ) {
	    $result .= $cal->as_HTML . "\n";
	} else {
	    if (! $numDays) {
		$numDays = Days_in_Month($cal->year(), $cal->month()) - $cal->today_date() + 1;
	    }
	    my $day = $listStartDay;
	    while ($numDays > 0) {
		if ($day > Days_in_Month($cal->year(), $cal->month())) {

		    # End of month reached, reset the starting day
		    # (for the next month) and break out of the loop

		    $listStartDay = 1;
		    last;
		}
		my $content = $cal->getcontent($day);
		if ($content && ($content !~ m/^\s*$/)) {
		    # Only display those days with events
		    if (($cal->month == $cal->today_month())
			&& ($cal->year == $cal->today_year())
			&& ($day == $cal->today_date())) {
			$result .= &formatToday($cal, $day, %options);
		    } else {
			$result .= &formatDateNumber($cal, $day, %options);
		    }
		    $result .= $content;
		}
		$day++;
		$numDays--;
	    }
	}

	# Advance to next month in preparation for possibly
	# constructing another calendar

	if ($m < 12) {		# Same year
	    $m++;
	} else {		# Go to next year
	    $y++;
	    $m = 1;
	}
    }
    return $result;
}
sub getTopicText {
    my ($theTopic, $theWeb, $refText, %options) = @_;
    my $topics = $options{topic};
    my @topics = split /, */, $topics;
    my $ans = '';
    foreach my $topicpair (@topics) {
        if ($topicpair =~ m/([^\.]+)\.([^\.]+)/) {
           ($web, $topic) = ($1, $2);
        } else {
           $web = $theWeb;
           $topic = $topicpair;
        }

        if (($topic eq $theTopic) && ($web eq $theWeb)) {
            # use current text so that preview can show unsaved events
            $ans .= $$refText;
        } else {
            $ans .= readTopicText($web, $topic);
        }
    }
    return $ans;
}



sub highlightDay
{
	my ($c, $day, $description, %options) = @_;
	use Date::Calc qw(Add_Delta_Days
			  Day_of_Week
			  Day_of_Week_Abbreviation
			  Day_of_Week_to_Text
			  Day_of_Year
			  Month_to_Text);
	my $old = $c->getcontent($day);
	my $format = $options{format};

	$format = &formatDate($c, $format, Date_to_Days($c->year(), $c->month(), $day), '');

	$format =~ s/\$description/$description/g ;
	$format =~ s/\$web/$options{web}/g ;
	$format =~ s/\$topic/$options{topic}/g ;
	$format =~ s/\$day/$day/g ;
	$format =~ s/\$old/$old/g if defined $old;
	$format =~ s/\$installWeb/$installWeb/g ;
	$format =~ s/\$n/\n/g ;

	$c->setcontent($day,$format);
}

=pod

---++ StaticMethod formatDate ($cal, $formatString, $date) -> $value
   * =$cal= A reference to the Date::Calc calendar in use.
   * =$formatString= twiki time date format, default =$day $month $year - $hour:$min=
   * =$date= The date (Date::Calc days value) of the date to format.
             At some point we should handle times, too.
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
   | $http | full HTTP header format date/time |
   | $email | full email format date/time |
   | $rcs | full RCS format date/time |
   | $epoch | seconds since 1st January 1970 |

Note that this description (and some of the code) is taken from the
TWiki function formatTime. Ideally, we would be able to use that
function, but that function deals with time in seconds from the epoch
and this plugin uses a different notion of time.

=cut

sub formatDate
{
    my ($cal, $formatString, $date) = @_;
    use Date::Calc qw(Add_Delta_Days
		      Day_of_Week
		      Day_of_Week_Abbreviation
		      Day_of_Week_to_Text
		      Day_of_Year
		      Month_to_Text);

    &TWiki::Func::writeDebug("formatDate: $formatString, $date") if $debug;
    my $outputTimeZone = 'gmtime'; # FIXME: Should be configurable
    my $value = '';	# Return value for the function
    my ($year, $mon, $day) = Add_Delta_Days(1, 1, 1, $date - 1);
    my ($sec, $min, $hour) = ('00', '00', '00'); # in the future, we might add times
    my $monthAbbr = sprintf '%0.3s', Month_to_Text($mon);
    my $monthName = Month_to_Text($mon);

    # Set a value for seconds since the epoch
    my $epochSeconds = timegm($sec, $min, $hour, $day, $mon-1, $year);

    # Set format to empty string if undefined to avoid possible warnings
    $formatString ||= '';

    # Unfortunately, there is a disconnect between the TWiki
    # formatTime() function and Date::Calc when it comes to the day of
    # the week. formatTime() numbers from Sun=0 to Sat=6, whereas
    # Date::Calc numbers from Mon=1 to Sun=7. So, the Date::Calc value
    # is mapped to the formatTime() value here in setting up the $wdayName
    # variable.

    my $wday = (1, 2, 3, 4, 5, 6, 0)[&Day_of_Week($year, $mon, $day) - 1];
    my $wdayAbbr = Day_of_Week_Abbreviation(Day_of_Week($year, $mon, $day));
    my $weekday = Day_of_Week_to_Text(Day_of_Week($year, $mon, $day));
    my $yearday = Day_of_Year($year, $mon, $day);

    #standard twiki date time formats

    # RCS format, example: "2001/12/31 23:59:59"
    $formatString =~ s/\$rcs/\$year\/\$mo\/\$day \$hour:\$min:\$sec/gi;

    # HTTP header format, e.g. "Thu, 23 Jul 1998 07:21:56 EST"
    # - based on RFC 2616/1123 and HTTP::Date; also used
    # by TWiki::Net for Date header in emails.
    $formatString =~ s/\$(http|email)/\$wday, \$day \$month \$year \$hour:\$min:\$sec \$tz/gi;

    # ISO Format, see spec at http://www.w3.org/TR/NOTE-datetime
    # e.g. "2002-12-31T19:30Z"
    my $tzd = '';
    if( $outputTimeZone eq 'gmtime' ) {
	$tzd = 'Z';
    } else {
	#TODO:            $formatString = $formatString.  # TZD  = time zone designator (Z or +hh:mm or -hh:mm) 
    }
    $formatString =~ s/\$iso/\$year-\$mo-\$dayT\$hour:\$min$tzd/gi;

    # The matching algorithms here are the same as those in
    # TWiki::Time::formatTime()

    $value = $formatString;
    $value =~ s/\$seco?n?d?s?/sprintf('%.2u',$sec)/gei;
    $value =~ s/\$minu?t?e?s?/sprintf('%.2u',$min)/gei;
    $value =~ s/\$hour?s?/sprintf('%.2u',$hour)/gei;
    $value =~ s/\$day/sprintf('%.2u',$day)/gei;
    $value =~ s/\$wday/$wdayAbbr/gi;
    $value =~ s/\$dow/$wday/gi;
    $value =~ s/\$week/_weekNumber($day,$mon-1,$year,$wday)/egi;
    $value =~ s/\$mont?h?/$monthAbbr/gi;
    $value =~ s/\$mo/sprintf('%.2u',$mon)/gei;
    $value =~ s/\$year?/sprintf('%.4u',$year)/gei;
    $value =~ s/\$ye/sprintf('%.2u',$year%100)/gei;
    $value =~ s/\$epoch/$epochSeconds/gi;

    # SMELL: how do we get the different timezone strings (and when
    # we add usertime, then what?)
    my $tz_str = ( $outputTimeZone eq 'servertime' ) ? 'Local' : 'GMT';
    $value =~ s/\$tz/$tz_str/geoi;

    # We add processing of a newline indicator
    $value =~ s/\$n/\n/g ;
    return $value;
}

sub _weekNumber {
    my( $day, $mon, $year, $wday ) = @_;

    # calculate the calendar week (ISO 8601)
    my $nextThursday = timegm(0, 0, 0, $day, $mon, $year) +
      (3 - ($wday + 6) % 7) * 24 * 60 * 60; # nearest thursday
    my $firstFourth = timegm(0, 0, 0, 4, 0, $year); # january, 4th
    return sprintf('%.0f', ($nextThursday - $firstFourth) / ( 7 * 86400 )) + 1;
}

sub formatDateNumber
{
    my ($cal, $day, %options) = @_;
    my $format = $options{datenumberformat};
    use Date::Calc qw( 
		       check_date
		       Date_to_Days 
		       );


    if (check_date($cal->year(), $cal->month(), $day)) {
	return &formatDate($cal, $format, Date_to_Days($cal->year(), $cal->month(), $day));
    } else {
	return "";
    }
}

sub formatToday
{
    my ($cal, $day, %options) = @_;
    my $format = $options{todaydatenumberformat};
    use Date::Calc qw( 
		       Date_to_Days 
		       );
    
    return formatDate($cal, $format, Date_to_Days($cal->year(), $cal->month(), $day));
}

=pod

---++ StaticMethod highlightMultiDay ($cal, $d, $description, $first, $last, $today, $seen, %options) -> $value
   * =$cal= is the current calendar
   * =$d= is the day (within the calendar/month) to highlight
   * =$description= is the description of the event
   * =$first= is the Date::Calc day value of the first day of the event
   * =$last= is the Date::Calc day value of the last day of the event
   * =$today= is the Date::Calc day value of the day being highlighted
   * =$seen= is non-zero (true) if this event has been already been indicated in this calendar
   * =%options= is a set of plugin options

The multidayformat option allows the description of each day of a
multiday event to be displayed differently.  This could be used to
visually or textually annotate the description to indicate
continuance from or to other days.

The option consists of a comma separated list of formats for each
type of day in a multiday event:

first, middle, last, middle-unseen, last-unseen

Where:

   * _first_ is the format used when the first day of the event is
    displayed
   * _middle_ is the format used when the day being displayed is not the
    first or last day
   * _last_ is the format used when the last day of the event is
    displayed
   * _middle-unseen_ is the format used when the day being displayed is
    not the first or last day of the event, but the preceding days of
    the event have not been displayed. For example, if an event runs
    from 29 Apr to 2 May and a May calendar is being displayed, then
    this format would be used for 1 May.
   * _last-unseen_ is the format used when the day being displayed is the
    last day of the event, but the preceding days of the event have not
    been displayed. For example, if an event runs from 29 Apr to 1 May
    and a May calendar is being displayed, then this format would be
    used for 1 May. Note that in the previous example (event from 29 Apr
    to 2 May), this format would *not* be used for a May calendar
    because the event was "seen" on 1 May; so, the _last_ format would
    be used for 2 May.

Missing formats will be filled in as follows:

   * _middle_ will be set to _first_
   * _last_ will be set to _middle_
   * _middle-unseen_ will be set to _middle_
   * _last-unseen_ will be set to _last_

Missing formats are different from empty formats. For example,

multidayformat="$description (until $last($day $month)),,"

specifies an empty format for _middle_ and _last_. The result of this
is that only the first day will be shown. Note that since an
unspecified _middle-unseen_ is set from the (empty) _middle_ format,
an event that begins prior to the calendar being displayed but ending
in the current calendar will not be displayed. In contrast,
multidayformat="$description" will simply display the description for
each day of the event; all days (within the scope of the calendar)
will be displayed.

The default format is to simply display the description of the event.

=cut

sub highlightMultiDay
{
    my ($cal, $d, $description, $first, $last, $today, $seen, %options) = @_;
    my $format = '$description';
    my $fmt = $options{multidayformat};
    my @fmts;


    if (!$fmt || ($fmt =~ m/^\s*$/)) {
	# If no special format set, just use the default format (the description)
	$fmts[0] = $fmts[1] = $fmts[2] = $fmts[3] = $fmts[4] = $format;
    } else {
	@fmts = split /,\s*/, $fmt, 5; # Get the individual format variants
	for (my $i = 0; $i < $#fmts; $i++) {
	    $fmts[$i] =~ s/\$comma/,/g;
	    $fmts[$i] =~ s/\$percnt/%/g;
	}
	#
	# fill in the missing formats:
	#
	if ($#fmts < 1) {
	    $fmts[1] = $fmts[0]; # Set middle from first
	}
	if ($#fmts < 2) {
	    $fmts[2] = $fmts[1]; # Set last from middle
	}
	if ($#fmts < 3) {
	    $fmts[3] = $fmts[1]; # Set middle-unseen from middle
	}
	if ($#fmts < 4) {
	    $fmts[4] = $fmts[2]; # Set last-unseen from last
	}
    }

    # Annotate the description for a multiday event. An interval that
    # is only one day (i.e., $date1 and $date2 are equal) is not
    # marked as a multiday event. For an actual multiday event, the
    # description is modified according to the formats supplied for a
    # first, middle, or last day of the event.

    if ($first == $last) {
	# Skip annotation, not really a multi-day event.
    } elsif ($today == $first) {
	# This is the first day of the event
	$format = $fmts[0];
    } elsif ($today == $last) {
	if (!$seen) {
	    $format = $fmts[4];
	} else {
	    $format = $fmts[2];
	}
    } else {
	# This is a day in the middle of the event
	if (!$seen) {
	    $format = $fmts[3];
	} else {
	    $format = $fmts[1];
	}
    }

    # Substitute date/time information for the first and last dates,
    # if specified in the format.

    $format =~ s/\$first\(([^)]*)\)/&formatDate($cal, $1, $first)/gei;
    $format =~ s/\$last\(([^)]*)\)/&formatDate($cal, $1, $last)/gei;

    # Finally, plug in the event description

    $format =~ s/\$description/$description/;

    # If the format ends up non-blank, highlight the day.

    if ($format && ($format !~ m/^\s*$/)) {
	&highlightDay($cal, $d, $format, %options);
    }
}

1;
