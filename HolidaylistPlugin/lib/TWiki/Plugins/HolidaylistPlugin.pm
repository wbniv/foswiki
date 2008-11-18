# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.com
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
# =========================
#
# This is an empty TWiki plugin. Use it as a template
# for your own plugins; see %SYSTEMWEB%.Plugins for details.
#
# Each plugin is a package that may contain these functions:        VERSION:
#
#   earlyInitPlugin         ( )                                     1.020
#   initPlugin              ( $topic, $web, $user, $installWeb )    1.000
#   initializeUserHandler   ( $loginName, $url, $pathInfo )         1.010
#   registrationHandler     ( $web, $wikiName, $loginName )         1.010
#   beforeCommonTagsHandler ( $text, $topic, $web )                 1.024
#   commonTagsHandler       ( $text, $topic, $web )                 1.000
#   afterCommonTagsHandler  ( $text, $topic, $web )                 1.024
#   startRenderingHandler   ( $text, $web )                         1.000
#   outsidePREHandler       ( $text )                               1.000
#   insidePREHandler        ( $text )                               1.000
#   endRenderingHandler     ( $text )                               1.000
#   beforeEditHandler       ( $text, $topic, $web )                 1.010
#   afterEditHandler        ( $text, $topic, $web )                 1.010
#   beforeSaveHandler       ( $text, $topic, $web )                 1.010
#   afterSaveHandler        ( $text, $topic, $web, $errors )        1.020
#   writeHeaderHandler      ( $query )                              1.010  Use only in one Plugin
#   redirectCgiQueryHandler ( $query, $url )                        1.010  Use only in one Plugin
#   getSessionValueHandler  ( $key )                                1.010  Use only in one Plugin
#   setSessionValueHandler  ( $key, $value )                        1.010  Use only in one Plugin
#
# initPlugin is required, all other are optional. 
# For increased performance, all handlers except initPlugin are
# disabled. To enable a handler remove the leading DISABLE_ from
# the function name. Remove disabled handlers you do not need.
#
# NOTE: To interact with TWiki use the official TWiki functions 
# in the TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!


# =========================
package TWiki::Plugins::HolidaylistPlugin;    

# =========================

use strict;
### use warnings;

use Date::Calc qw(:all);
use CGI;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $REVISION $pluginName
        $debug 
	%defaults @renderedOptions @flagOptions $refText 
	@unknownParams %options
	%table %locationtable %icontable 
	%months %daysofweek
	$months_rx $date_rx $daterange_rx $bullet_rx $bulletdate_rx $bulletdaterange_rx $dow_rx $day_rx
	$year_rx $monthyear_rx $monthyearrange_rx
	$defaultsInitialized
	$theWeb $theTopic $attributes
	$startDays
	@processedTopics
	$hlid 
	%rendererCache
    );

# This should always be $Rev: 17715 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 17715 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.


$REVISION = '1.0.27'; #dro# changed some defaults (showmonthheader, monthheaderformat, headerformat); fixed alignments (statistics, monthheader); added maxheight attribute
#$REVISION = '1.0.26'; #dro# added missing anchor in showoptions form action; added row color feature (new attributes: namecolors, rowcolors); added order feature (new attribute: order); added namepos attribute (place names left and/or right of a row)
#$REVISION = '1.0.25'; #dro# added div tag with style overflow:auto requested by Matthew Thomson; added query parameters feature (hlp_&lt;attribute&gt; in URIs); added option form feature (new attributes: showoptions, optionspos, optionsformat) requested by Matthew Thomson; improved performance; fixed minor icon related bugs;
#$REVISION = '1.0.24'; #dro# added statistics feature requested by TWiki:Main.GarySprague
#$REVISION = '1.0.23'; #kjl# fixed Item5190 - does not like whitespace after the smiley. This makes the plugin work with TWiki 4.2.0 and Wysiwyg
#$REVISION = '1.0.22'; #dro# added documentation requested by TWiki:Main.PeterThoeny; fixed typo (on=off bug)
#$REVISION = '1.021'; #dro# fixed minor HTML bug reported by TWiki:Main.JfMacaud; added month header feature (showmonthheader attribute) requested by Rikard Johansson; fixed some minor bugs (documentation, preferences handling);
#$REVISION = '1.020'; #dro# added week attribute requested by TWiki:Main.JanFilipsky; added tooltip to day headers;
#$REVISION = '1.019'; #dro# improved navigation; fixed %<nop>ICON% tag handling bug reported by TWiki:Main.UlfJastrow;
#$REVISION = '1.018'; #dro# fixed periodic event bug; added navigation feature
#$REVISION = '1.017'; #dro# fixed minor bug (periodic repeater)
#$REVISION = '1.016'; #dro# fixed some major bugs: deep recursion bug reported by TWiki:Main.ChrisHausen; exception handling bug (concerns Dakar)
#$REVISION = '1.015'; #dro# added class attribute (holidaylistPluginTable) to table tag for stylesheet support (thanx TWiki:Main.HaraldJoerg and TWiki:Main.ArthurClemens); fixed mod_perl preload bug (removed 'use warnings;') reported by TWiki:Main.KennethLavrsen
#$REVISION = '1.014'; #dro# incorporated documentation fixes by TWiki:Main.KennethLavrsen (Bugs:Item1440) 
#$REVISION = '1.013'; #dro# added Perl strict pragma; 
#$VERSION = '1.012'; #dro# added public holiday support requested by TWiki:Main.IlltudDaniel; improved documentation; improved forced link handling in alt/title attributes of img tags; fixed documentation bug reported by TWiki:Main.FranzJosefSilli
#$VERSION = '1.011'; #dro# improved performance; fixed major periodic repeater bug; added parameter check; fixed flag parameter handling; allowed language specific month and day names for entries; fixed minor repeater bugs; added new attributes: monthnames, daynames, width, unknownparamsmsg;
#$VERSION = '1.010'; #dro# added exception handling; added compatibility mode (new attributes: compatmode, compatmodeicon) with full CalendarPlugin event type support; added documentation
#$VERSION = '1.009'; #dro# fixed major bug (WikiNames and forced links in names) reported by TWiki:Main.KennethLavrsen; fixed documentation bugs; added INCLUDE expansion (for topics in topic attribute value); added name rendering
#$VERSION = '1.008'; #dro# added new attributes (nwidth,tcwidth,removeatwork,tablecaptionalign,headerformat); performance fixes; allowed digits in the month attribute
#$VERSION = '1.007'; #dro# personal icon support; new attributes (month,year); icon tooltips with dates/person/location/icon; fixed '-' bug
#$VERSION = '1.006'; #dro# added new features (location support; todaybgcolor; todayfgcolor)
#$VERSION = '1.005'; #dro# added new features (startdate support; weekendbgcolor); fixed documentation bugs
#$VERSION = '1.004'; #dro# some performance improvements; code cleanup; documentation
#$VERSION = '1.003'; #dro# fix plugin preferences handling; format column name; rename some subroutines
#$VERSION = '1.002'; #dro# renders some options; fixes: white space bug, documentation bugs; 
#$VERSION = '1.001'; #dro# complete reimplementation of HolidaylistPlugin
#$VERSION = '1.021'; #pj# initial version

$pluginName = 'HolidaylistPlugin';  # Name of this Plugin

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.021 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPluginPreferencesFlag( "DEBUG" );

    $defaultsInitialized = 0;

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;

    return 1;
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # This is the place to define customized tags and variables
    # Called by TWiki::handleCommonTags, after %INCLUDE:"..."%

    #### eval is bad because Dakar works with exceptions
    ####eval {
	    $_[0] =~ s/%HOLIDAYLIST%/&handleHolidaylist("", $_[0], $_[1], $_[2])/ge;
	    $_[0] =~ s/%HOLIDAYLIST{(.*?)}%/&handleHolidaylist($1, $_[0], $_[1], $_[2])/ge;
    ####};
    ####TWiki::Func::writeWarning("${pluginName}: $@") if $@;


}
# =========================
sub initDefaults() {
	my $webbgcolor = &TWiki::Func::getPreferencesValue("WEBBGCOLOR", $web) || 'white';
	%defaults = (
		days		=> 30,		# days to show
		lang		=> 'English',	# language
		tablecaption	=> '&nbsp;',	# table caption
		cellpadding     => 1,		# table cellpadding 
		cellspacing	=> 0,		# table cellspacing
		border		=> 1,		# table border
		topic		=> "$web.$topic",	# topic with calendar entries
		tableheadercolor=>  $webbgcolor,	# table header color
		tablebgcolor	=> 'white',	# table background color
		workicon => '&nbsp;',		# on work icon (old behavior: ':mad:')
		holidayicon => '8-)',		# on holiday icon
		adayofficon => ':ok:',		# a day off icon
		showweekends	=> 0,		# show weekends with month day and weekday in header and icons in cells
		name 		=> 'Name',	# first cell entry
		weekendbgcolor	=> $webbgcolor, # background color of weekend cells
		startdate	=> undef,	# start date or a day offset
		notatworkicon	=> ':-I',	# not at work icon
		todaybgcolor	=> undef,	# background color for today cells (usefull for a defined startdate)
		todayfgcolor	=> undef,	# foreground color for today cells (usefull for a dark todaybgcolor)
		month		=> undef,	# the month or a offset
		year		=> undef,	# the year or a offset
		tcwidth		=> undef,	# width of the smily cells
		nwidth		=> undef,	# width of the first column
		removeatwork	=> 0,		# removes names without calendar entries from table if set to "1"
		tablecaptionalign=> 'top',	# table caption alignment (top|bottom|left|right)
		headerformat	=> '<font size="-2">%a<br/>%e</font>',	# format of the header
		compatmode	=> 0,		# compatibility mode (allows all CalendarPlugin event types)
		compatmodeicon	=> ':-)', 	# compatibility mode icon
		daynames	=> undef,	# day names (overwrites lang attribute)
		monthnames	=> undef,	# month names (overwrites lang attribute)
		width		=> undef,	# table width
		unknownparamsmsg=> '%RED% Sorry, some parameters are unknown: %UNKNOWNPARAMSLIST% %ENDCOLOR% <br/> Allowed parameters are (see %SYSTEMWEB%.HolidaylistPlugin topic for more details): %KNOWNPARAMSLIST%',
		enablepubholidays	=> 1,		# enable public holidays
		showpubholidays	=> 0,		# show public holidays in a separate row
		pubholidayicon	=> ':-)',	# public holiday icon
		navnext => '&gt;|',		# navigation button to the next n days
		navnexthalf =>'&gt;',		# navigation button to the next n/2 days
		navnexttitle => 'Next %n day(s)',
		navnexthalftitle => 'Next %n day(s)',
		navprev => '<br/>|&lt;',		# navigation button to the last n days
		navprevhalf => '&lt;',		# navigation button to the last n/2 days
		navprevtitle => 'Previous %n day(s)',
		navprevhalftitle => 'Previous %n day(s)',
		navhome => '%d',
		navhometitle => 'Go to the start date',
		navenable => 1,
		navdays => undef,
		week => undef,
		showmonthheader => 1,
		monthheaderformat => '%b',
		showstatcol => 0,
		statcolheader => '#',
		statcolformat => '%{hh}',
		statcoltitle => '%{ll}',
		showstatrow => 0,
		statrowformat => '%{hh}',
		statrowheader => '#',
		statrowtitle => '%{ll}',
		statformat_ll => '%{ll:%LOCATION} x %LOCATION; ',
		statformat_l => '%{l:%LOCATION} x %LOCATION; ',
		statformat_ii => '%{ii:%ICON} x %ICON ; ',
		statformat_i => '%{i:%ICON} x %ICON ; ',
		statformat_0 => 0,
		statformat => undef,
		stattitle => undef,
		statheader => undef,
		showstatsum => 1,
		statformat_perc => '%3.1f%%',
		statformat_unknown => 'unknown',
		optionsformat => 'Month: %MONTHSEL, Year: %YEARSEL %BUTTON(Change)',
		showoptions => 0,
		optionspos=> 'bottom',
		rowcolors => '#ffffff,#f0f0f0',
		namecolors => undef,
		order => undef,
		namepos => 'left',
		maxheight => undef,
	);

	# reminder: don't forget change documentation (HolidaylistPlugin topic) if you add a new rendered option
	@renderedOptions = ( 'tablecaption', 'name', 'holidayicon', 'adayofficon', 'workicon', 'notatworkicon', 'compatmodeicon', 'pubholidayicon' );

	# options to turn or switch things on (1) or off (0)
	# this special handling allows 'on'/'yes';'off'/'no' values additionally to '1'/'0'
	@flagOptions = ( 'showweekends', 'removeatwork', 'compatmode', 'enablepubholidays', 'showpubholidays', 'navenable','showmonthheader','showstatcol', 'showstatrow','showstatsum','showoptions');

	%months = ( Jan=>1, Feb=>2, Mar=>3, Apr=>4, May=>5, Jun=>6, 
	            Jul=>7, Aug=>8, Sep=>9, Oct=>10, Nov=>11, Dec=>12 );

	%daysofweek = ( Mon=>1, Tue=>2, Wed=>3, Thu=>4, Fri=>5, Sat=>6, Sun=>7 );

	$hlid = 0;

	$defaultsInitialized = 1;

}

# =========================
sub initRegexs {
	# some regular expressions:
	$months_rx = join('|', map(quotemeta($_), keys(%months)));
	$dow_rx = join('|', map(quotemeta($_), keys(%daysofweek)));
	$year_rx = "[12][0-9]{3}";
	$monthyear_rx = "($months_rx)\\s+$year_rx";
	$monthyearrange_rx = "$monthyear_rx\\s+\\-\\s+$monthyear_rx";
	$day_rx = "[0-3]?[0-9](\.|th)?";
	$date_rx = "$day_rx\\s+($months_rx)\\s+$year_rx";
	$daterange_rx = "$date_rx\\s*-\\s*$date_rx";
	$bullet_rx = "^\\s+\\*\\s*";
	$bulletdate_rx = "$bullet_rx$date_rx\\s*-";
	$bulletdaterange_rx = "$bulletdate_rx\\s*$date_rx\\s*-";
}
# =========================
sub initOptions() {
	my ($attributes) = @_;

	my %params = &TWiki::Func::extractParameters($attributes);

	my @allOptions = keys %defaults;

	# Check attributes:
	@unknownParams= ( );
	foreach my $option (keys %params) {
		push (@unknownParams, $option) unless grep(/^\Q$option\E$/, @allOptions);
	}
	return 0 if $#unknownParams != -1; 

	my $cgi = TWiki::Func::getCgiQuery();

	# Setup options (attributes>plugin preferences>defaults):
	%options= ();
	foreach my $option (@allOptions) {
		my $v = $cgi->param("hlp_${option}_$hlid") ;
		if (!defined $v) { $v = (!defined $cgi->param("hlp_id")) || ($cgi->param("hlp_id") eq $hlid) ? $cgi->param("hlp_${option}") : undef; }
		$v = $params{$option} unless defined $v;
		if (defined $v) {
			if (grep /^\Q$option\E$/, @flagOptions) {
				$options{$option} = ($v!~/^(0|false|no|off)$/i);
			} else {
				$options{$option} = $v;
			}
		} else {
			if (grep /^\Q$option\E$/, @flagOptions) {
				$v = TWiki::Func::getPreferencesFlag("\U${pluginName}_$option\E") || undef;
			} else {
				$v = TWiki::Func::getPreferencesValue("\U${pluginName}_$option\E") || undef;
			}
			$v = undef if (defined $v) && ($v eq "");
			$options{$option}=(defined $v)? $v : $defaults{$option};
		}

	}
	# Render some options:
	foreach my $option (@renderedOptions) {
		if ($options{$option} !~ /^(\s|\&nbsp\;)*$/) {
		 	$options{$option}=_renderText($options{$option}, $web);
		}
	}

	Date::Calc::Language(Date::Calc::Decode_Language($options{lang}));

	# Setup language specific month and day names:
	for (my $i=1; $i < 13; $i++) {
		if ($i < 8) {
			my $dt = Day_of_Week_to_Text($i);
			$daysofweek{$dt} = $i;
			$daysofweek{Day_of_Week_Abbreviation($i)} = $i;
			$daysofweek{substr($dt, 0, 2)} = $i;
		}
		my $mt = Month_to_Text($i);
		$months{$mt} = $i;
		$months{substr($mt,0,3)} = $i;
	}

	# Setup user defined daynames:
	if ((defined $options{daynames}) && (defined $defaults{daynames}) && ($options{daynames} ne $defaults{daynames})) {
		my @dn = split /\s*\|\s*/, $options{daynames};
		if ($#dn == 6) {
			for (my $i=1; $i<8; $i++) {
				$daysofweek{$dn[$i-1]}=$i;
			}
		}
	}
	# Setup user defined monthnames:
	if ((defined $options{monthnames}) && (defined $defaults{monthnames}) && ($options{monthnames} ne $defaults{monthnames})) {
		my @mn = split /\s*\|\s*/, $options{monthnames};
		if ($#mn == 11) {
			for (my $i=1; $i<13; $i++) {
				$months{$mn[$i-1]} = $i;
			}	
		}
	}

	# Setup statcol(format|title) and statrow(format|title) defaults
	if ($options{showweekends}) {
		$options{statcolformat}='%{h}' if $options{statcolformat} eq $defaults{statcolformat};
		$options{statcoltitle}='%{l}' if $options{statcoltitle} eq $defaults{statcoltitle};
		$options{statrowformat}='%{h}' if $options{statrowformat} eq $defaults{statrowformat};
		$options{statrowtitle}='%{l}' if $options{statrowtitle} eq $defaults{statrowtitle};
	}

	@processedTopics = ( );
	return 1;

}
# =========================
sub handleHolidaylist() {
	($attributes, $refText, $theTopic, $theWeb) = @_;

	local(%options, @unknownParams);
	local(%table, %locationtable, %icontable);

	# order of &init... calls is important

	&initDefaults() unless $defaultsInitialized;

	$hlid++;

	return &createUnknownParamsMessage() unless &initOptions($attributes);

	&initRegexs(); 

	return &renderHolidaylist(&handlePublicHolidays(&fetchHolidaylist(&getTopicText())));
}
# =========================
sub createUnknownParamsMessage {
	my $msg;
	$msg = TWiki::Func::getPreferencesValue("UNKNOWNPARAMSMSG") || undef;
	$msg = $defaults{unknownparamsmsg} unless defined $msg;
	$msg =~ s/\%UNKNOWNPARAMSLIST\%/join(', ', sort @unknownParams)/eg;
	$msg =~ s/\%KNOWNPARAMSLIST\%/join(', ', sort keys %defaults)/eg;
	return $msg;
}
# =========================
sub getStartDate() {
	my ($yy,$mm,$dd) = Today();

	# handle startdate (absolute or offset)
	if (defined $options{startdate}) {
		my $sd = $options{startdate};
		$sd =~ s/^\s*(.*?)\s*$/$1/; # cut whitespaces
		if ($sd =~ /^$date_rx$/) {
			my ($d,$m,$y);
			($d,$m,$y) = split(/\s+/, $sd);
			($dd, $mm, $yy) = ($d, $months{$m},$y) if check_date($y, $months{$m},$d);
		} elsif ($sd =~ /^([\+\-]?\d+)$/) {
			($yy, $mm, $dd) = Add_Delta_Days($yy, $mm, $dd, $1);
		}
	} 
	# handle year (absolute or offset)
	if (defined $options{year}) {
		my $year = $options{year};
		if ($year =~ /^(\d{4})$/) {
			$yy=$year;
		} elsif ($year =~ /^([\+\-]?\d+)$/) {
			($yy,$mm,$dd) = Add_Delta_YM($yy,$mm,$dd, $1, 0);
		} 
	}
	# handle month (absolute or offset)
	if (defined $options{month}) {
		my $month = $options{month};
		my $matched = 1;
		if ($month=~/^($months_rx)$/) {
			$mm=$months{$1};
		} elsif ($month=~/^([\+\-]\d+)$/) {
			($yy,$mm,$dd) = Add_Delta_YM($yy,$mm,$dd, 0, $1);
		} elsif (($month=~/^\d?\d$/)&&($month>0)&&($month<13)) {
			$mm=$month;
		} else {
			$matched = 0;
		}
		if ($matched) {
			$dd=1;
			$options{days}=Days_in_Month($yy, $mm);
		}
	}
	# handle week (absolute or offset) 
	if (defined $options{week}) {
		my $week = $options{week};
		my $matched = 0;
		if (($week =~ /^\d+$/)&&($week>0)&&($week<=Weeks_in_Year($yy))) {
			$matched = 1;
		} elsif ($week =~ /^[\+\-]\d+$/) {
			$matched = 1;
			($yy,$mm,$dd) = Add_Delta_Days($yy,$mm,$dd, 7 * $week);
			$week = Week_of_Year($yy,$mm,$dd);
		}
		($yy,$mm,$dd) = Monday_of_Week($week, $yy) if ($matched);
	}
	# handle paging:
	my $cgi=TWiki::Func::getCgiQuery();
	if (defined $cgi->param('hlppage'.$hlid)) {
		if ($cgi->param('hlppage'.$hlid) =~ m/^([\+\-]?[\d\.]+)$/) {
			my $hlppage = $1; 
			my $days = int( (defined $options{'navdays'}?$options{'navdays'}:$options{'days'}) * $hlppage );
			($yy,$mm,$dd) = Add_Delta_Days($yy,$mm,$dd, $days);
		}
	}

	return ($dd,$mm,$yy);
}
# =========================
sub getDays {
	my ($date,$ldom) = @_;
	my $days = undef;

	$date=~s/^\s*//;
	$date=~s/\s*$//;

	my ($yy,$mm,$dd);
	if ($date =~ /^$date_rx$/) {
		($dd,$mm,$yy) = split /\s+/, $date;
		$mm = $months{$mm};
	} elsif ($date =~ /^$monthyear_rx$/) {
		($mm, $yy) = split /\s+/, $date;
		$mm = $months{$mm};
		$dd = $ldom? Days_in_Month($yy, $mm) : 1;
	} else {
		return undef;
	}
	$dd=~/(\d+)/;
	$dd=$1;
	$days = check_date($yy,$mm,$dd) ? Date_to_Days($yy,$mm,$dd) : undef;

	return $days;

}
# =========================
sub getTableRefs {
	my ($person) = @_;
	# cut whitespaces
	$person=~s/\s+$//;

	my $ptableref = $table{$person};
	my $ltableref = $locationtable{$person};
	my $itableref = $icontable{$person};

	if (!defined $ptableref) {
		$ptableref=[];
		$table{$person}=$ptableref;
		$ltableref=[];
		$locationtable{$person}=$ltableref;
		$itableref=[];
		$icontable{$person}=$itableref;
	}

	return ($ptableref, $ltableref, $itableref);
	
}
# =========================
sub handleDateRange {
	my ($person, $start, $end, $descr, $location, $icon, $excref) = @_;

	my ($ptableref,$ltableref,$itableref) = &getTableRefs($person);

	my  $date = $startDays;
	for (my $i=0; ($i < $options{days}) && (($date+$i)<=$end); $i++) {
		next if $$excref[$i];
		if (($date+$i)>=$start) {
			$$ltableref[$i]{descr}=$descr;
			$$ltableref[$i]{location}=$location;
			if (defined $icon) {
				$$ptableref[$i]=4;
				$$itableref[$i]=$icon;
			} elsif (defined $location) {
				$$ptableref[$i]=3;
			} else {
				$$ptableref[$i]= ($start!=$end) ? 1 : 2;
			}
		}
	}
}
# =========================
sub fetchHolidaylist {
	my ($text) = @_;
	%table = ( );
	%locationtable = ( );
	%icontable = ( );

	my ($dd,$mm,$yy) = &getStartDate();

	$startDays = Date_to_Days($yy,$mm,$dd);
	
	my ($eyy, $emm, $edd) = Add_Delta_Days($yy,$mm,$dd,$options{days});
	my ($endDays) = Date_to_Days($eyy,$emm,$edd); 
	
	my ($line, $descr);
	foreach $line (grep(/$bullet_rx/, split(/\r?\n/, $text))) {
		my ($person, $start, $end, $location, $icon);

		$line =~ s/\s+$//;
		$line =~ s/$bullet_rx//g; 

		$descr = $line;

		&replaceSpecialDateNotations($line) if $options{compatmode}; 

		my $excref = &fetchExceptions($line, $startDays, $endDays);

		if ( ($line =~ m/^$daterange_rx/) || ($line =~ m/^$monthyearrange_rx/) ) {
			my ($sdate, $edate);
			($sdate,$edate,$person,$location,$icon) = split /\s+\-\s+/, $line, 5;
			($start, $end ) = ( &getDays($sdate, 0), &getDays($edate, 1) );
			next unless (defined $start) && (defined $end);

			&handleDateRange($person, $start, $end, $descr, $location, $icon, $excref); 

		} elsif ( ($line =~ m/^$date_rx/) || ($line =~ m/^$monthyear_rx/) ) {
			my $date;
			($date, $person, $location, $icon) = split /\s+\-\s+/, $line, 4;
			($start, $end) = ( &getDays($date,0), &getDays($date,1) );
			next unless (defined $start) && (defined $end);

			&handleDateRange($person, $start, $end, $descr, $location, $icon, $excref);
		} elsif ($options{compatmode}) {
			&handleCalendarEvents($line, $descr, $yy,$mm,$dd, $startDays, $endDays, $excref);
		}

	}
	return (\%table, \%locationtable, \%icontable);
}
# =========================
sub handlePublicHolidays {
	my ($tableRef, $locationTableRef, $iconTableRef) = @_;
	if ($options{enablepubholidays}) {
		my $all = '!!__@ALL__!!';
		$$tableRef{$all} = [ ];
		$$locationTableRef{$all} = [ ];
		$$iconTableRef{$all} = [ ];
		my ($aptableref,$altableref,$aitableref) = ( $$tableRef{$all}, $$locationTableRef{$all}, $$iconTableRef{$all});
		for my $person ( keys %{$tableRef} ) {
			if (($person ne $all) && ($person =~ /\@all/i) ) {
				my ($ptableref,$ltableref,$itableref) = 
					( $$tableRef{$person}, $$locationTableRef{$person}, $$iconTableRef{$person});
				for ( my $i=0; $i<$options{days}; $i++) {
					if (defined $$ptableref[$i]) {
						$$aptableref[$i] = 6;
						$$altableref[$i] = (defined $$ltableref[$i]) ? $$ltableref[$i] : $$ptableref[$i];
						$$aitableref[$i] = $$itableref[$i];
					}
				}
			}
		}	
	}
	return ($tableRef, $locationTableRef, $iconTableRef);
}
# =========================
sub replaceSpecialDateNotations {
	# replace special (business) notations:
	### DDD Wn yyyy
	### DDD Week n yyyy
	$_[0] =~s /($dow_rx)\s+W(eek)?\s*([0-9]?[0-9])\s+($year_rx)/getFullDateFromBusinessDate($1,$3,$4)/egi;
	### Wn yyyy
	### Week n yyyy
	$_[0] =~s /W(eek)?\s*([0-9]?[0-9])\s+($year_rx)/getFullDateFromBusinessDate('Mon',$2,$3)/egi;
}
# =========================
sub fetchExceptions {
	my ($line, $startDays, $endDays) = @_;

	my @exceptions = ( );

	$_[0] =~s /X\s+{\s*([^}]+)\s*}// || return \@exceptions;
	my $ex=$1;


	for my $x ( split /\s*\,\s*/, $ex ) {
		my ($start, $end) = (undef, undef);
		if (($x =~ m/^$daterange_rx$/)||($x =~ m/^$monthyearrange_rx/)) {
			my ($sdate,$edate) = split /\s*\-\s*/, $x;
			$start = &getDays($sdate,0);
			$end = &getDays($edate,1);

		} elsif (($x =~ m/^$date_rx/)||($x =~ m/^$monthyear_rx/)) {
			$start = &getDays($x,0);
			$end = &getDays($x, 1);
		}
		next unless defined $start && ($start <= $endDays);
		next unless defined $end &&   ($end >= $startDays);

		for (my $i=0; ($i<$options{days})&&(($startDays+$i)<=$end); $i++) {
			$exceptions[$i] = 1 if ( (($startDays+$i)>=$start) && (($startDays+$i)<=$end) );
		}
	}

	return \@exceptions;
}
# =========================
sub getFullDateFromBusinessDate {
	my($t_dow, $week, $year) = @_;
	my ($ret);
	my ($y1,$m1,$d1);
	if (check_business_date($year, $week, $daysofweek{$t_dow})) {
		($y1, $m1, $d1) = Business_to_Standard($year,$week,$daysofweek{$t_dow});
		$ret = "$d1 ".Month_to_Text($m1)." $y1";
	}
	return $ret;
}
# =========================
sub handleCalendarEvents {
	my ($line, $descr, $yy,$mm,$dd, $startDays, $endDays, $excref) = @_;
	my ($strdate, $person, $location, $icon);

	if  ($line =~ m/^A\s+$date_rx/) {
		### Yearly: A dd MMM yyyy
		($strdate, $person, $location, $icon) = split /\s+\-\s+/, $line, 4;
		my ($ptableref,$ltableref,$itableref) = &getTableRefs($person);
		$strdate=~s/^A\s+//;
		my ($dd1, $mm1, $yy1) = split /\s+/, $strdate;
		$mm1 = $months{$mm1};

		return unless check_date($yy1, $mm1, $dd1);

		for (my $i=0; $i < $options{days}; $i++) {
			next if $$excref[$i];
			my ($y,$m,$d) = Add_Delta_Days($yy,$mm,$dd,$i);
			
			if (($mm1==$m) && ($dd1==$d)) {
				$$ptableref[$i] = 5;
				$$ltableref[$i]{descr} = $descr . ' ('.($y-$yy1).')';
				$$ltableref[$i]{location} = $location;
				$$itableref[$i] = $icon;
			}
		}
	} elsif ($line =~ m/^$day_rx\s+($months_rx)/) {
		### Interval: dd MMM
		($strdate, $person, $location, $icon) = split /\s+\-\s+/, $line, 4;
		my ($ptableref,$ltableref,$itableref) = &getTableRefs($person);
		my ($dd1, $mm1) = split /\s+/, $strdate;
		$mm1 = $months{$mm1};
		return if $dd1>31;

		for (my $i=0; $i < $options{days}; $i++) {
			next if $$excref[$i];
			my ($y,$m,$d) = Add_Delta_Days($yy,$mm,$dd,$i);
			if (($m==$mm1)&&($d==$dd1)) {
				$$ptableref[$i] = 5;
				$$ltableref[$i]{descr} = $descr;
				$$ltableref[$i]{location} = $location;
				$$itableref[$i] = $icon;
			}
		}
	} elsif ($line =~ m/^[0-9L](\.|th)?\s+($dow_rx)(\s+($months_rx))?/) {
		### Interval: w DDD MMM 
		### Interval: L DDD MMM 
		### Monthly: w DDD
		### Monthly: L DDD

		($strdate, $person, $location, $icon) = split /\s+\-\s+/, $line, 4;
		my ($ptableref,$ltableref,$itableref) = &getTableRefs($person);
		my ($n1,$dow1,$mm1) = split /\s+/, $strdate;
		$dow1 = $daysofweek{$dow1};
		$mm1 = $months{$mm1} if defined $mm1;

		for (my $i=0; $i < $options{days}; $i++) {
			next if $$excref[$i];
			my ($y,$m,$d) = Add_Delta_Days($yy,$mm,$dd,$i);
			if ((! defined $mm1) || ($m == $mm1)) {
				my ($yy2,$mm2,$dd2);
				if ($n1 eq 'L') {
					$n1 = 6;
					do {
						$n1--;
						($yy2, $mm2, $dd2)=Nth_Weekday_of_Month_Year($y, $m, $dow1, $n1); 
					} until ($yy2);
				} else {
					eval { # may fail with a illegal factor
						($yy2, $mm2, $dd2) = Nth_Weekday_of_Month_Year($y, $m, $dow1, $n1);
					};
					next if $@;
				}

				if (($dd2)&&($dd2==$d)) {
					$$ptableref[$i] = 5;
					$$ltableref[$i]{descr} = $descr;
					$$ltableref[$i]{location} = $location;
					$$itableref[$i] = $icon;
				}
			}
		}
	} elsif ($line =~ m/^$day_rx\s+\-/) {
		### Monthly: dd
		($strdate, $person, $location, $icon) = split /\s+\-\s+/, $line, 4;
		my ($ptableref,$ltableref,$itableref) = &getTableRefs($person);
		return if $strdate > 31;
		for (my $i=0; $i < $options{days}; $i++) {
			next if $$excref[$i];
			my ($y,$m,$d) = Add_Delta_Days($yy,$mm,$dd,$i);
			if ($strdate == $d) {
				$$ptableref[$i] = 5;
				$$ltableref[$i]{descr} = $descr;
				$$ltableref[$i]{location} = $location;
				$$itableref[$i] = $icon;
			}
		}
	} elsif ($line =~ m/^E\s+($dow_rx)/) {
		### Monthly: E DDD dd MMM yyy - dd MMM yyyy
		### Monthly: E DDD dd MMM yyy
		### Monthly: E DDD

		my $strdate2 = undef;
		if ($line =~ m/^E\s+($dow_rx)\s+$daterange_rx/) {
			($strdate, $strdate2, $person, $location, $icon) = split /\s+\-\s+/, $line, 5;
		} else {
			($strdate, $person, $location, $icon) = split /\s+\-\s+/, $line, 4;
		}
		my ($ptableref,$ltableref,$itableref) = &getTableRefs($person);	

		$strdate=~s/^E\s+//;
		my ($dow1) = split /\s+/, $strdate;
		$dow1=$daysofweek{$dow1};

		$strdate=~s/^\S+\s*//;

		my ($start, $end) = (undef, undef);
		if ((defined $strdate)&&($strdate ne "")) {
			$start = &getDays($strdate);
			return unless defined $start;
		}

		if (defined $strdate2) {
			$end = &getDays($strdate2);
			return unless defined $end;
		}

		return if (defined $start) && ($start > $endDays);
		return if (defined $end) && ($end < $startDays);

		for (my $i=0; $i < $options{days}; $i++) {
			next if $$excref[$i];
			my ($y,$m,$d) = Add_Delta_Days($yy,$mm,$dd,$i);
			my $date = Date_to_Days($y,$m,$d);
			my $dow = Day_of_Week($y, $m, $d);
			if ( ($dow==$dow1)
			    && ( (!defined $start) || ($date>=$start) )
			    && ( (!defined $end)   || ($date<=$end) )
			   ) {
				$$ptableref[$i] = 5;
				$$ltableref[$i]{descr} = $descr;
				$$ltableref[$i]{location} = $location;
				$$itableref[$i] = $icon;
			}
		}

	} elsif ($line =~ m/^E\d+\s+$date_rx/) {
		### Periodic: En dd MMM yyyy - dd MMM yyyy
		### Periodic: En dd MMM yyyy
		my $strdate2 = undef;
		if ($line =~ m/^E\d+\s+$daterange_rx/) {
			($strdate, $strdate2, $person, $location, $icon) = split /\s+\-\s+/, $line, 5;
		} else {
			($strdate, $person, $location, $icon) = split /\s+\-\s+/, $line, 4;
		}
		my ($ptableref,$ltableref,$itableref) = &getTableRefs($person);

		$strdate=~s/^E//;
		my ($n1) = split /\s+/, $strdate;

		return unless $n1 > 0;

		$strdate=~s/^\d+\s+//;

		my ($start, $end) = (undef, undef);
		my ($dd1, $mm1, $yy1) = split /\s+/, $strdate;
		$mm1 = $months{$mm1};

		$start = &getDays($strdate);
		return unless defined $start;

		$end = &getDays($strdate2) if defined $strdate2;
		return if (defined $strdate2)&&(!defined $end);

		return if (defined $start) && ($start > $endDays);
		return if (defined $end) && ($end < $startDays);

		if ( $start < $startDays ) {
			($yy1, $mm1, $dd1) = Add_Delta_Days($yy1, $mm1, $dd1, 
			### $n1 * int( (abs($startDays-$start)/$n1) + ($startDays-$start!=0?1:0) ) );
				$n1 * int( (abs($startDays-$start)/$n1) + ((abs($startDays-$start) % $n1)!=0?1:0) ) );
			$start = Date_to_Days($yy1, $mm1, $dd1);
		}

		# start at first occurence and increment by repeating count ($n1)
		for (my $i=(abs($startDays-$start) % $n1); (($i < $options{days})&&((!defined $end) || ( ($startDays+$i) <= $end)) ); $i+=$n1) {
			next if $$excref[$i];
			if (($startDays+$i) >= $start) {
				$$ptableref[$i] = 5;
				$$ltableref[$i]{descr} = $descr;
				$$ltableref[$i]{location} = $location;
				$$itableref[$i] = $icon;
			}
		} # for
	} # if

} # sub handleCalendarEvents
# =========================
sub mystrftime($$$$) {
	my ($yy,$mm,$dd,$format) = @_;
	my $text = defined $format ? $format : $options{headerformat};

	my $dow = Day_of_Week($yy,$mm,$dd);
	my $t_dow =  undef;
	if (defined $options{daynames}) {
		my @dn = split  /\|/, $options{daynames};
		$t_dow = $dn[$dow-1] if $#dn == 6;
	}
	$t_dow = Day_of_Week_to_Text($dow) unless defined $t_dow;

	my $t_mm = undef;; 
	if (defined $options{monthnames}) {
		my @mn = split /\|/, $options{monthnames};
		$t_mm = $mn[$mm-1] if $#mn == 11;
	}
	$t_mm = Month_to_Text($mm) unless defined $t_mm;

	my $doy = Day_of_Year($yy,$mm,$dd);
	my $wn = Week_Number($yy,$mm,$dd);
	my $t_wn = $wn<10?"0$wn":$wn;

	my $y = substr("$yy",-2,2);

	my %tmap = (
			'%a'	=> substr($t_dow, 0, 2), '%A'	=> $t_dow,
			'%b'	=> substr($t_mm,0,3), '%B'	=> $t_mm,
			'%c'	=> Date_to_Text_Long($yy,$mm,$dd), '%C'	=> This_Year(),
			'%d'	=> $dd<10?"0$dd":$dd, '%D' => "$mm/$dd/$yy",
			'%e'	=> $dd,
			'%F'	=> "$yy-$mm-$dd",
			'%g'	=> $y, '%G' => $yy,
			'%h'	=> substr($t_mm,0,3),
			'%j'	=> ($doy<100)? (($doy<10)?"00$doy":"0$doy") : $doy,
			'%m'	=> ($mm<10)?"0$mm":$mm,
			'%n'	=> '<br/>',
			'%t'	=> "<code>\t</code>",
			'%u'	=> $dow, '%U' => $t_wn,
			'%V'	=> $t_wn,
			'%w'	=> $dow-1, '%W'	=> $t_wn,
			'%x'	=> Date_to_Text($yy,$mm,$dd),
			'%y'	=> $y,	'%Y' => $yy,
			'%%'	=> '%'
		);
	
	# replace all known conversion specifiers:
	$text =~ s/(%[a-z\%\+]?)/(defined $tmap{$1})?$tmap{$1}:$1/ieg;

	return $text;
}
# =========================
sub renderHolidaylist() {
	my ($tableRef, $locationTableRef, $iconTableRef) = @_;
	my $text = "";

	my ($ty,$tm,$td) = Today();
	my $today = Date_to_Days($ty,$tm,$td);


	my $optionrow = $options{showoptions}?renderOptions() : '';

	# create table header:
	
	$text .=  $optionrow if ($options{optionspos}=~/^(top|both)$/i);
	$text .= '<noautolink>'.CGI::a({-name=>'hlpid'.$hlid},"");
	$text .= CGI::start_table({-class=>'holidaylistPluginTable', -border=>$options{border}, -cellpadding=>$options{cellpadding},
					-cellspacing=>$options{cellspacing}, -bgcolor=>$options{tablebgcolor}, -width=>$options{width}});

	$text .= CGI::caption({-align=>$options{tablecaptionalign}}, $options{tablecaption});

	my $header = "";
	my $namecell = "";
	$namecell .= CGI::th({-align=>'left',-width=>$options{nwidth}, -rowspan=>($options{showmonthheader}?2:1) },
			$options{name}.($options{'navenable'}?&renderNav(-1).&renderNav(0).&renderNav(1):''));

	my ($dd,$mm,$yy) = getStartDate();
	
	# render month header:
	my $monthheader = "";
	if ($options{showmonthheader}) {
		my $restdays = $options{days};
		my ($yy1,$mm1,$dd1) = ($yy, $mm, $dd);
		while ($restdays > 0) {
			my $daysdiff = Days_in_Month($yy1,$mm1) - $dd1 + 1;
			$daysdiff = $restdays if ($restdays-$daysdiff<0);
			$monthheader .= CGI::th({-colspan=>$daysdiff, -align=>'center', -title=> Month_to_Text($mm1).' '.$yy1}, &mystrftime($yy1,$mm1,$dd1,$options{monthheaderformat}));
			($yy1,$mm1,$dd1) = Add_Delta_Days($yy1,$mm1,$dd1, $daysdiff);
			$restdays -= $daysdiff;
		}
		if ($options{showstatcol}) {
			foreach my $h (split(/\|/,getStatOption('statheader','statcolheader'))) {
				$monthheader .= CGI::th({-valign=>'bottom', -align=>'center', rowspan=>2, -bgcolor=>$options{tableheadercolor}}, $h);
			}
		}
	}

	# render header:

	for (my $i=0; $i< $options{days}; $i++) {
		my ($yy1,$mm1,$dd1) = Add_Delta_Days($yy, $mm, $dd, $i);
		my $dow = Day_of_Week($yy1,$mm1,$dd1);
		my $date = Date_to_Days($yy1, $mm1, $dd1);

		my $bgcolor = $options{tableheadercolor};
		$bgcolor=$options{weekendbgcolor} unless $dow < 6;
		$bgcolor=$options{todaybgcolor} if (defined $options{todaybgcolor})&&($today == $date);
		
		my %params = ( -align=>'center', -bgcolor=>$bgcolor, -title=>Date_to_Text_Long($yy1,$mm1,$dd1) );
		$params{-width}=$options{tcwidth} if ((defined $options{tcwidth})&&(($dow<6)||$options{showweekends}));
		$params{-style}='color:'.$options{todayfgcolor} if ($today==$date)&&(defined $options{todayfgcolor});
		$header .= CGI::th(\%params, (($dow < 6)|| $options{showweekends}) ? &mystrftime($yy1,$mm1,$dd1) : '&nbsp;');
	}
	if ((!$options{showmonthheader}) && $options{showstatcol}) {
		foreach my $h (split(/\|/,getStatOption('statheader','statcolheader'))) {
			$header.=CGI::th({-valign=>'bottom',-align=>'center',-bgcolor=>$options{tableheadercolor}}, $h);
		}
	
	}
	$text .= CGI::Tr({-bgcolor=>$options{tableheadercolor}}, ($options{namepos}=~/^(left|both)$/i?$namecell:'').$monthheader.($options{namepos}=~/^(right|both)$/i?$namecell:'')).CGI::Tr($header) if $options{showmonthheader};
	$text .= CGI::Tr({-bgcolor=>$options{tableheadercolor}}, ($options{namepos}=~/^(left|both)$/i?$namecell:'').$header.($options{namepos}=~/^(right|both)$/i?$namecell:'')) unless $options{showmonthheader};

	# create table with names and dates:

	my %iconstates = ( 0 => $options{workicon},
                           1 => $options{holidayicon},
			   2 => $options{adayofficon},
			   3 => $options{notatworkicon},
			   4 => $options{notatworkicon},
			   5 => $options{compatmodeicon},
			   6 => $options{pubholidayicon}
			);

	my @rowcolors = defined $options{rowcolors} ? split(/[\,\|\;\:]/, $options{rowcolors}) : ( $options{tablebgcolor} );
	my %namecolors = %{ _getNameColors() };

	my %sumstatistics;
	my %rowstatistics;
	foreach my $person ( @{_reorderPersons($tableRef)} ) {
		my $ptableref=$$tableRef{$person};
		my $ltableref=$$locationTableRef{$person};
		my $itableref=$$iconTableRef{$person};

		my $aptableref=$$tableRef{'!!__@ALL__!!'};
		my $altableref=$$locationTableRef{'!!__@ALL__!!'};
		my $aitableref=$$iconTableRef{'!!__@ALL__!!'};


		# ignore entries with @all
		next if $options{enablepubholidays} && (!$options{showpubholidays}) && ($person =~ /\@all/i);
		next if $person eq '!!__@ALL__!!';

		# ignore table rows without an entry if removeatwork == 1
		next if $options{removeatwork} && !grep(/[^0]+/, join('', map( $_ || 0, @{$ptableref})));


		my %statistics;

		my $rowcolor = shift @rowcolors;
		push @rowcolors, $rowcolor;
		$rowcolor = $namecolors{$person} if defined $namecolors{$person};

		$person =~ s/\@all//ig if $options{enablepubholidays};

		my $tr = "";
		my $pcell = CGI::th({-align=>'left'},'<noautolink>'._renderText($person,$web).'</noautolink>');
		$tr .= $pcell if $options{namepos}=~/^(left|both)$/i;

		for (my $i=0; $i<$options{days}; $i++) {
			my ($yy1, $mm1, $dd1) = Add_Delta_Days($yy, $mm, $dd, $i);
			my $dow = Day_of_Week($yy1, $mm1, $dd1);

			my $bgcolor = $rowcolor;
			$bgcolor = $options{weekendbgcolor} unless $dow < 6;
			$bgcolor = $options{todaybgcolor} if (defined $options{todaybgcolor}) && ($today == Date_to_Days($yy1, $mm1, $dd1));

			my $td = "";

			if ($options{enablepubholidays} && defined $$aptableref[$i] && $$aptableref[$i]>0) {
				$statistics{pubholidays}++;
				$rowstatistics{$i}{pubholidays}++;
				$sumstatistics{pubholidays}++;
			}
			if ((defined $$ptableref[$i] && $$ptableref[$i]>0) 
					|| ( $options{enablepubholidays} && defined $$aptableref[$i] && $$aptableref[$i]>0)) {
				$statistics{holidays}++;
				$statistics{icons}{$$itableref[$i]}++ if defined $$itableref[$i]; 
				$statistics{icons}{$options{statformat_unknown}}++ if ! defined $$itableref[$i]; 
				$statistics{locations}{$$ltableref[$i]{location}}++ if defined $$ltableref[$i]{location};
				$statistics{locations}{$options{statformat_unknown}}++ if ! defined $$ltableref[$i]{location};
				$rowstatistics{$i}{holidays}++;
				$rowstatistics{$i}{icons}{$$itableref[$i]}++ if defined $$itableref[$i]; 
				$rowstatistics{$i}{icons}{$options{statformat_unknown}}++ if ! defined $$itableref[$i]; 
				$rowstatistics{$i}{locations}{$$ltableref[$i]{location}}++ if defined $$ltableref[$i]{location};
				$rowstatistics{$i}{locations}{$options{statformat_unknown}}++ if ! defined $$ltableref[$i]{location};
				$sumstatistics{holidays}++;
				$sumstatistics{icons}{$$itableref[$i]}++ if defined $$itableref[$i]; 
				$sumstatistics{icons}{$options{statformat_unknown}}++ if ! defined $$itableref[$i]; 
				$sumstatistics{locations}{$$ltableref[$i]{location}}++ if defined $$ltableref[$i]{location};
				$sumstatistics{locations}{$options{statformat_unknown}}++ if !defined $$ltableref[$i]{location};
				
			} else {
				$statistics{work}++;
				$rowstatistics{$i}{work}++;
				$sumstatistics{work}++;
			}
			$statistics{days}++;
			$statistics{'days-w'}++ if $dow < 6;
			$rowstatistics{$i}{days}=1;
			$rowstatistics{$i}{'days-w'}=1;
			$sumstatistics{days}++;
			$sumstatistics{'days-w'}++ if $dow < 6;


                        if (($dow < 6)||$options{showweekends}) { 
				my $icon= $iconstates{ defined $$ptableref[$i]?$$ptableref[$i]:0};
				if ($dow<6 && $options{enablepubholidays} && defined $$aptableref[$i] && $$aptableref[$i]>0) {
					$statistics{'pubholidays-w'}++;
					$rowstatistics{$i}{'pubholidays-w'}++;
					$sumstatistics{'pubholidays-w'}++;
				}
			

				# overwrite personal holidays with public holidays:
				if ($options{enablepubholidays} && defined $$aptableref[$i]) {
					$icon = $iconstates{$$aptableref[$i]};
					$$itableref[$i]=$$aitableref[$i];
					$$ltableref[$i]=$$altableref[$i];
				}


				if ($dow < 6 && defined $$ptableref[$i] && $$ptableref[$i]>0 && ( (!defined $$aptableref[$i]) || ($$aptableref[$i]<=0))) {
					$statistics{'holidays-w'}++;
					$statistics{'icons-w'}{(defined $$itableref[$i]?$$itableref[$i]:$icon)}++;
					$statistics{'locations-w'}{$$ltableref[$i]{location}}++ if defined $$ltableref[$i]{location};
					$statistics{'locations-w'}{$options{statformat_unknown}}++ if ! defined $$ltableref[$i]{location};
					$rowstatistics{$i}{'holidays-w'}++;
					$rowstatistics{$i}{'icons-w'}{(defined $$itableref[$i]?$$itableref[$i]:$icon)}++;
					$rowstatistics{$i}{'locations-w'}{$$ltableref[$i]{location}}++ if defined $$ltableref[$i]{location};
					$rowstatistics{$i}{'locations-w'}{$options{statformat_unknown}}++ if ! defined $$ltableref[$i]{location};
					$sumstatistics{'holidays-w'}++;
					$sumstatistics{'icons-w'}{(defined $$itableref[$i]?$$itableref[$i]:$icon)}++;
					$sumstatistics{'locations-w'}{$$ltableref[$i]{location}}++ if defined $$ltableref[$i]{location};
					$sumstatistics{'locations-w'}{$options{statformat_unknown}}++ if ! defined $$ltableref[$i]{location};
				} else {
					$statistics{'work-w'}++;
					$rowstatistics{$i}{'work-w'}++;
					$sumstatistics{'work-w'}++;
				}


				if (defined $$itableref[$i]) {
					$icon = $$itableref[$i];
					$icon = _renderText($icon, $web) if $icon !~ /^(\s|\&nbsp\;)*$/;
				}

				# could fail if HTML::Entities is not installed:
				eval { 
					require HTML::Entities;
					my $location = $$ltableref[$i]{descr} if defined $ltableref;
					if (defined $location) {
						$location =~ s/\@all//ig if $options{enablepubholidays}; # remove @all

						$location=substTitle($location);
						$location=&HTML::Entities::encode_entities($location); # quote special characters like "<>

						$icon=~s/<img /<img alt="$location" /is unless $icon=~s/(<img[^>]+alt=")[^">]+("[^>]*>)/$1$location$2/is;
						$icon=~s/<img /<img title="$location" /is unless $icon=~s/(<img[^>]+title=")[^">]+("[^>]*>)/$1$location$2/is;
					}
				};
				$td.= $icon;
			} else {
				$td.= '&nbsp;';
			}
			$tr .= CGI::td({-align=>'center', -bgcolor=>$bgcolor, -title=>substTitle($person .' / '.Date_to_Text_Long($yy1,$mm1,$dd1)) }, $td);
		}
		$tr .= renderStatisticsCol(\%statistics) if ($options{showstatcol});
		$tr .= $pcell if $options{namepos}=~/^(right|both)$/i;
		$text .= CGI::Tr({-bgcolor=>$rowcolor}, $tr);
	}
	$text .= renderStatisticsRow(\%rowstatistics, \%sumstatistics) if ($options{showstatrow});
	$text .= renderStatisticsSumRow(\%sumstatistics) if ($options{showstatcol}&&(!$options{showstatrow})&&($options{showstatsum}));
	$text .= CGI::end_table();
	$text .=  $optionrow if ($options{optionspos}=~/^(bottom|both)$/i);
	$text .= '</noautolink>';

	$text = CGI::div({-class=>'holidayListPluginDiv',-style=>'overflow:auto;'.(defined $options{maxheight}?"max-height:$options{maxheight}":"")},$text);

	return $text;
}
# =========================
sub _int {
	return $_[0]=~/(\d+)/ ? $1 : 0;
}
# =========================
sub _reorderPersons {
	my ($tableRef) = @_;
	my @persons = ();
	if (defined $options{order}) {
		if ($options{order} =~ /\[:nextfirst:\]/i) {
			@persons = sort { join('', map( $_ || 0, @{$$tableRef{$b}})) cmp join('',map($_ || 0, @{$$tableRef{$a}})) }  keys %{$tableRef};
		} elsif ($options{order} =~/\[:ralpha:\]/) {
			@persons = sort { $b cmp $a } keys %{$tableRef};
		} elsif ($options{order} =~/\[:num:\]/) {
			@persons = sort { _int($a) <=> _int($b) }  keys %{$tableRef};
		} elsif ($options{order} =~/\[:rnum:\]/) {
			@persons = sort { _int($b) <=> _int($a) }  keys %{$tableRef};
		} else {
			@persons = split(/\s*[\,\;\|]\s*/, $options{order}); 
			if ($options{order}=~/\[:rest:\]/i) {
				my @rest = ();
				foreach my $p (sort keys %{$tableRef}) {
					push @rest, $p unless grep(/^\Q$p\E$/,@persons);
				}
				my $order = $options{order};
				$order =~ s/\[:rest:\]/join(',', @rest)/eig;
				@persons = split(/\s*[\,\;\|]\s*/, $order); 
			}
		}
	} else {
		@persons = sort keys %{$tableRef};
	}
	return \@persons;

}
# =========================
sub _getNameColors {
	my %colors =  ( );
	return \%colors unless defined $options{namecolors};
	foreach my $entry (split(/\s*[\,\|\;]\s*/, $options{namecolors})) {
		my ($name,$color) = split(/\:/,$entry);
		$colors{$name}=$color;
	}
	return \%colors;
}
# =========================
sub substTitle {
	my ($title) =  @_;

	$title =~ s/<!--.*?-->//g; # remove HTML comments
	$title =~ s/ - <img[^>]+>//ig; # throw image address away
	$title =~ s/<\/?\S+[^>]*>//g;

	$title =~s /&nbsp;/ /g;
	$title =~ s/\%(\w+[^\%]+?)\%//g; # delete Vars
	$title =~ s/\[\[[^\]]+\]\[([^\]]+)\]\]/$1/g; # replace forced link with comment
	$title =~ s/\[\[([^\]]+)\]\]/$1/g; # replace forced link with comment
	$title =~ s/\[\[/!\[\[/g; # quote forced links - !!!unused
	$title =~ s/[A-Z][a-z0-9]+[\.\/]([A-Z])/$1/g; # delete Web names
	##$title =~ s/([A-Z][a-z]+\w*[A-Z][a-z0-9]+)/$1/g; # quote WikiNames
	return $title;
}
# =========================
sub substStatisticsVars {
	my ($textformat, $titleformat, $statisticsref ) = @_;
	return (_substStatisticsVars($textformat, $statisticsref), substTitle(_substStatisticsVars($titleformat,$statisticsref)));
}

# =========================
sub _substStatisticsVars {
	my ($textformat, $statisticsref) = @_;

	my $text = $textformat;


	$statisticsref = { } unless defined $statisticsref;

	my %statistics = %{$statisticsref};

	if ($textformat=~/\%{ll:?}/i) {
		my $t="";
		foreach my $location (sort keys %{$statistics{'locations-w'}}) {
			my $f=$options{statformat_ll};
			$f=~s/\%LOCATION/$location/g;
			$t.=$f;
		}
		$text=~s/\%{ll:?}/$t/g;
	}
	if ($textformat=~/\%{l}/i) {
		my $t="";
		foreach my $location (sort keys %{$statistics{'locations'}}) {
			my $f=$options{statformat_l};
			$f=~s/\%LOCATION/$location/g;
			$t.=$f;
		}
		$text=~s/\%{l:?}/$t/g;
	}
	if ($textformat=~/\%{ii:?}/i) {
		my $t="";
		foreach my $icon (keys %{$statistics{'icons-w'}}) {
			my $f=$options{statformat_ii};
			$f=~s/\%ICON/$icon/g;
			$t.=$f;
		}
		$text=~s/\%{ii:?}/$t/g;
	}
	if ($textformat=~/\%{i:?}/i) {
		my $t="";
		foreach my $icon (keys %{$statistics{'icons-w'}}) {
			my $f=$options{statformat_i};
			$f=~s/\%ICON/$icon/g;
			$t.=$f;
		}
		$text=~s/\%{i:?}/$t/g;
	}
	sub _vz {
		return defined $_[0]?$_[0]:defined $options{statformat_0}?$options{statformat_0}:0;
	};
	$text=~s/\%{i:([^}]+)}/_vz($statistics{icons}{$1})/egi;
	$text=~s/\%{ii:([^}]+)}/_vz($statistics{'icons-w'}{$1})/egi;
	$text=~s/\%{l:([^}]+)}/_vz($statistics{locations}{$1})/egi;
	$text=~s/\%{ll:([^}]+)}/_vz($statistics{'locations-w'}{$1})/egi;

	$text=~s/\%hh/_vz($statistics{'holidays-w'})/egi;
	$text=~s/\%h/_vz($statistics{holidays})/egi;
	$text=~s/\%{h:?}/_vz($statistics{holidays})/egi;
	$text=~s/\%{hh:?}/_vz($statistics{'holidays-w'})/egi;

	$text=~s/\%pp/_vz($statistics{'pubholidays-w'})/egi;
	$text=~s/\%p/_vz($statistics{pubholidays})/egi;
	$text=~s/\%{p:?}/_vz($statistics{pubholidays})/egi;
	$text=~s/\%{pp:?}/_vz($statistics{'pubholidays-w'})/egi;

	$text=~s/\%ww/_vz($statistics{'work-w'})/egi;
	$text=~s/\%w/_vz($statistics{work})/egi;
	$text=~s/\%{w:?}/_vz($statistics{work})/egi;
	$text=~s/\%{ww:?}/_vz($statistics{'work-w'})/egi;

	$text=~s/\%dd/_vz($statistics{'days-w'})/egi;
	$text=~s/\%d/_vz($statistics{days})/egi;
	$text=~s/\%{d:?}/_vz($statistics{days})/egi;
	$text=~s/\%{dd:?}/_vz($statistics{'days-w'})/egi;


	# percentages:
	sub _dz {
		return defined $_[0]?$_[0]:0;
	};
	sub _perc {
		return _dz($_[1])==0 ? "n.d." : sprintf($options{statformat_perc},(_dz($_[0]) * 100 / _dz($_[1])));
	}
	# locations to days:
	$text=~s/\%{ld:([^}]+)}/_perc($statistics{locations}{$1}, $statistics{days})/egi;
	$text=~s/\%{ldd:([^}]+)}/_perc($statistics{locations}{$1}, $statistics{'days-w'})/egi;
	$text=~s/\%{lld:([^}]+)}/_perc($statistics{locations}{$1}, $statistics{days})/egi;
	$text=~s/\%{lldd:([^}]+)}/_perc($statistics{locations}{$1}, $statistics{'days-w'})/egi;

	# locations to holidays:
	$text=~s/\%{lh:([^}]+)}/_perc($statistics{locations}{$1}, $statistics{holidays})/egi;
	$text=~s/\%{lhh:([^}]+)}/_perc($statistics{locations}{$1}, $statistics{'holidays-w'})/egi;
	$text=~s/\%{llh:([^}]+)}/_perc($statistics{locations}{$1}, $statistics{holidays})/egi;
	$text=~s/\%{llhh:([^}]+)}/_perc($statistics{locations}{$1}, $statistics{'holidays-w'})/egi;

	# icons to days:
	$text=~s/\%{id:([^}]+)}/_perc($statistics{icons}{$1}, $statistics{days})/egi;
	$text=~s/\%{idd:([^}]+)}/_perc($statistics{icons}{$1}, $statistics{'days-w'})/egi;
	$text=~s/\%{iid:([^}]+)}/_perc($statistics{icons}{$1}, $statistics{days})/egi;
	$text=~s/\%{iidd:([^}]+)}/_perc($statistics{icons}{$1}, $statistics{'days-w'})/egi;

	# icons to holidays:
	$text=~s/\%{ih:([^}]+)}/_perc($statistics{icons}{$1}, $statistics{holidays})/egi;
	$text=~s/\%{ihh:([^}]+)}/_perc($statistics{icons}{$1}, $statistics{'holidays-w'})/egi;
	$text=~s/\%{iih:([^}]+)}/_perc($statistics{icons}{$1}, $statistics{holidays})/egi;
	$text=~s/\%{iihh:([^}]+)}/_perc($statistics{icons}{$1}, $statistics{'holidays-w'})/egi;

	# holidays to days:
	$text=~s/\%{hd:?}/_perc($statistics{holidays},$statistics{days})/egi;
	$text=~s/\%{hdd:?}/_perc($statistics{holidays},$statistics{'days-w'})/egi;
	$text=~s/\%{hhd:?}/_perc($statistics{'holidays-w'}, $statistics{days})/egi;
	$text=~s/\%{hhdd:?}/_perc($statistics{'holidays-w'}, $statistics{'days-w'})/egi;

	# public holidays to days:
	$text=~s/\%{pd:?}/_perc($statistics{pubholidays},$statistics{days})/egi;
	$text=~s/\%{pdd:?}/_perc($statistics{pubholidays},$statistics{'days-w'})/egi;
	$text=~s/\%{ppd:?}/_perc($statistics{'pubholidays-w'}, $statistics{days})/egi;
	$text=~s/\%{ppdd:?}/_perc($statistics{'pubholidays-w'}, $statistics{'days-w'})/egi;

	# working days to days:
	$text=~s/\%{wd:?}/_perc($statistics{work}, $statistics{days})/egi;
	$text=~s/\%{wdd:?}/_perc($statistics{work}, $statistics{'days-w'})/egi;
	$text=~s/\%{wwd:?}/_perc($statistics{'work-w'}, $statistics{days})/egi;
	$text=~s/\%{wwdd:?}/_perc($statistics{'work-w'}, $statistics{'days-w'})/egi;
	
	return $text;
}
# =========================
sub getStatOption {
	return (defined $options{$_[0]}) ? $options{$_[0]} : $options{$_[1]};
}
# =========================
sub renderStatisticsSumRow {
	my ($sumstatisticsref) = @_;
	my $cgi=TWiki::Func::getCgiQuery();
	my $text = "";
	my $row="";
	my @stattitles=split(/\|/,getStatOption('stattitle','statcoltitle'));
	foreach my $statcol (split(/\|/,getStatOption('statformat','statcolformat'))) {
		my $stattitle = shift @stattitles;
		$stattitle = getStatOption('stattitle','statcoltitle') unless defined $stattitle;
		my ($txt,$t) = substStatisticsVars($statcol, $stattitle, $sumstatisticsref);
		$row.=$cgi->th({-valign=>"top", -title=>$t}, $txt);
	}
	$row.=$cgi->th('&nbsp;') if $options{namepos}=~/^(right|both)$/i;
	my $colspan=$options{days};
	$colspan++ if $options{namepos}=~/^(left|both)$/i;
	$text.= $cgi->Tr({-bgcolor=>$options{tableheadercolor}},$cgi->th({-colspan=>$colspan,-align=>'right'},'&nbsp;').$row);

	return $text;
}
# =========================
sub renderStatisticsRow {
	my ($statisticsref, $sumstatisticsref) = @_;
	my $cgi=TWiki::Func::getCgiQuery();
	my $text = "";
	my ($dd,$mm,$yy) = getStartDate();

	my ($ty,$tm,$td) = Today();
	my $today = Date_to_Days($ty,$tm,$td);

	my $statrowformat = getStatOption('statformat','statrowformat');
	my $statrowtitle  = getStatOption('stattitle', 'statrowtitle');
	my $statrowheader = getStatOption('statheader','statrowheader');

	my @rowformats = split(/\|/, $statrowformat);
	my @rowheaders = split(/\|/, $statrowheader);
	my @rowtitles = split(/\|/, $statrowtitle);
	my $showsums=0;
	foreach my $rowformat (@rowformats) {
		my $rowheader = shift(@rowheaders);
		my $rowtitle  = shift(@rowtitles);
		$rowheader = $statrowheader unless defined $rowheader;
		$rowtitle = $statrowtitle unless defined $rowtitle;
		my $row = "";
		for (my $i=0; $i<$options{days}; $i++) {
			my ($yy1,$mm1,$dd1) = Add_Delta_Days($yy,$mm,$dd,$i);
			my $dow = Day_of_Week($yy1,$mm1,$dd1);
			my $date = Date_to_Days($yy1,$mm1,$dd1);
			my ($text,$title) = substStatisticsVars($rowformat, $rowtitle, $$statisticsref{$i});
			
			my $style="";
			$style.="color:$options{todayfgcolor};" if (defined $options{todayfgcolor}) && ($date == $today);
			$style.="background-color:$options{todaybgcolor};" if (defined $options{todaybgcolor}) && ($date == $today);
			if (($dow<6)||($options{showweekends})) {
				$row.=$cgi->th({-style=>$style,-title=>$title, -align=>'center'},$text);
			} else {
				$row.=$cgi->th({-style=>$style,-title=>$title},'&nbsp;');
			}
		}

		if ((!$showsums)&&($options{showstatcol})) {
			$showsums=1;
			my @rowspanf = split(/\|/,$statrowformat);
			my $rowspan=$#rowspanf + 1;
			if ($options{showstatsum}) {
				my @stattitles=split(/\|/,getStatOption('stattitle','statcoltitle'));
				foreach my $statcol (split(/\|/,getStatOption('statformat','statcolformat'))) {
					my $stattitle = shift @stattitles;
					$stattitle = getStatOption('stattitle','statcoltitle') unless defined $stattitle;
					my ($txt,$t) = substStatisticsVars($statcol, $stattitle, $sumstatisticsref);
					$row.=$cgi->th({-valign=>"top", -rowspan=>$rowspan, -title=>$t}, $txt);
				}
			} else {
				my @colspanf = split(/\|/,getStatOption('statformat','statcolformat'));
				my $colspan = $#colspanf + 1;
				$row.=$cgi->th({-rowspan=>$rowspan, -colspan=>$colspan},'&nbsp;');
			}
		}
		
		$text.=$cgi->Tr({-bgcolor=>$options{tableheadercolor}}, 
				 ( $options{namepos}=~/^(left|both)$/i ? $cgi->th({-align=>"right"},$rowheader) : '')
				.$row
				.( $options{namepos}=~/^(right|both)$/i ? $cgi->th({-align=>'left'},$rowheader) : ''));
	}

	return $text;
}
# =========================
sub renderStatisticsCol {
	my ($statisticsref) = @_;
	my $text="";
	my $cgi=TWiki::Func::getCgiQuery();

	my @statcoltitles = split(/\|/, getStatOption('stattitle','statcoltitle'));
	foreach my $statcol (split /\|/, getStatOption('statformat','statcolformat')) {
		my $statcoltitle = shift(@statcoltitles);
		$statcoltitle=getStatOption('stattitle','statcoltitle') unless defined $statcoltitle;
		($statcol,$statcoltitle)=substStatisticsVars($statcol,$statcoltitle,$statisticsref);
		$text.=$cgi->th({-bgcolor=>$options{tableheadercolor}, -class=>"hlpStatisticsColumn", -title=>$statcoltitle, -align=>'right'}, $statcol);
	}
	return $text;
}

# =========================
sub renderNav {
	my ($nextp) = @_;
	my $nav = "";

	my $cgi = &TWiki::Func::getCgiQuery();
	my $newcgi = new CGI($cgi);
	my $newhalfcgi = new CGI($cgi);

	my $days = (defined $options{'navdays'})?$options{'navdays'}:$options{'days'};

	my $qphlppage = $cgi->param('hlppage'.$hlid);
	$qphlppage = "0" unless defined $qphlppage;
	$qphlppage =~ m/^([\+\-]?[\d\.]+)$/;
	my $hlppage = $1;
	$hlppage = 0 unless defined $hlppage;

	$hlppage += $nextp;
	my $halfpage = 0;
	$halfpage= $hlppage - 0.5 if $nextp==1;
	$halfpage= $hlppage + 0.5 if $nextp==-1;

	if (($nextp==0)||($hlppage == 0)) {
		$newcgi->delete('hlppage'.$hlid);
	} else {
		$newcgi->param(-name=>'hlppage'.$hlid,-value=>$hlppage);
	}
	if (($nextp==0)||($halfpage == 0)) {
		$newhalfcgi->delete('hlppage'.$hlid);
	} else {
		$newhalfcgi->param(-name=>'hlppage'.$hlid,-value=>$halfpage);
	}

	$newcgi->delete('contenttype');
	$newhalfcgi->delete('contenttype');

	my $href = $newcgi->self_url();
	$href=~s/\#.*$//;
	$href.="#hlpid$hlid";

	my $halfhref = $newhalfcgi->self_url();
	$halfhref=~s/\#.$//;	
	$halfhref.="#hlpid$hlid";

	my $title = $options{'navhometitle'};
	my $d = int($days*($hlppage-$nextp));
	if ($d==0) {
		$d='';
	} else {
		$d='+'.$d if ($d>0);
	}

	$title = $options{'navnexttitle'} if $nextp==1;
	$title = $options{'navprevtitle'} if $nextp==-1;
	$title=~s/%n/$days/g;
	$title=~s/%d/$d/eg;

	my $halftitle = "";
	$halftitle = $options{'navnexthalftitle'} if $nextp==1;
	$halftitle = $options{'navprevhalftitle'} if $nextp==-1;
	my $halfdays = int($days/2);
	$halftitle=~s/%n/$halfdays/g;
	$halftitle=~s/%d/$d/eg;

	my $text = $options{'navhome'};
	$text = $options{'navnext'} if $nextp==1;
	$text = $options{'navprev'} if $nextp==-1;
	$text=~s/%n/$days/g;
	$text=~s/%d/$d/eg;

	my $halftext = "";
	$halftext = $options{'navnexthalf'} if $nextp==1;
	$halftext = $options{'navprevhalf'} if $nextp==-1;


	$nav.=$cgi->a({-href=>$halfhref,-title=>$halftitle}, $halftext) if ($nextp==1);
	$nav.=$cgi->a({-href=>$href,-title=>$title}, $text);
	$nav.=$cgi->a({-href=>$halfhref,-title=>$halftitle}, $halftext) if ($nextp==-1);


	return $nav;
}
### dro: following code is derived from TWiki:Plugins.CalendarPlugin:
# =========================
sub getTopicText() {

	my ($web, $topic);

	my $topics = $options{topic};
	my @topics = split /,\s*/, $topics;

	my $text = "";
	foreach my $topicpair (@topics) {
		if ($topicpair =~ m/([^\.]+)\.([^\.]+)/) {
			($web, $topic) = ($1, $2);
		} else {
			$web = $theWeb;
			$topic = $topicpair;
		}

		# ignore processed topics;
		grep( /^\Q$web.$topic\E$/, @processedTopics ) && next;

		push(@processedTopics, "$web.$topic");

		if (($topic eq $theTopic) && ($web eq $theWeb)) {
			# use current text so that preview can show unsaved events
			$text .= $refText;
		} else {
			$text .= &readTopicText($web, $topic);
		}
	}

	$text =~ s/%INCLUDE{(.*?)}%/&expandIncludedEvents($1, \@processedTopics)/geo;
	$text =~s/\%HOLIDAYLIST({(.*?)})?%//sg;
	$text = TWiki::Func::expandCommonVariables($text,$web,$topic);
	
	return $text;
	
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
	my( $theAttributes, $theProcessedTopicsRef ) = @_;

	my ($theWeb, $theTopic) = ($web, $topic);

	my $webTopic = &TWiki::Func::extractNameValuePair( $theAttributes );
	if( $webTopic =~ /^([^\.]+)[\.\/](.*)$/ ) {
		$theWeb = $1;
		$theTopic = $2;
	} else {
		$theTopic = $webTopic;
	}

	# prevent recursive loop
	grep (/^\Q$theWeb.$theTopic\E$/, @{$theProcessedTopicsRef}) and return "";

	push( @{$theProcessedTopicsRef}, "$theWeb.$theTopic" );

	my $text = &readTopicText( $theWeb, $theTopic );

	$text =~ s/.*?%STARTINCLUDE%//s;
	$text =~ s/%STOPINCLUDE%.*//s;

	# recursively expand includes
	$text =~ s/%INCLUDE{(.*?)}%/&expandIncludedEvents( $1, $theProcessedTopicsRef )/geo;

	return $text;
}
# =========================
sub renderOptions {
	my $text = $options{optionsformat};
	my $navdays = $options{navdays};
	$navdays = $options{days} unless defined $navdays;

	my ($dd,$mm,$yy) = getStartDate();
	my $week = Week_of_Year($yy,$mm,$dd);
	my $wiy = Weeks_in_Year($yy);
	
	while ($text=~/\%(STARTDATE|WEEK|MONTH|YEAR)OFFS(\(([^\)]*)\))?/) {
		my $what=$1;
		my ($a,$b,$s) = _getOptionRange($3,'-3:+3');
		my @vals = ('');
		for (my $offs=$a; $offs!=$b+$s; $offs+=$s) {
			push @vals,($offs>=0?'+':'').$offs;
		}
		$text =~ s/\%\Q$what\EOFFS(\([^\)]*\))?/CGI::popup_menu(-title=>"\L$what\E offset",-name=>"hlp_\L$what\E_$hlid",-values=>\@vals, -default=>$options{lc($what)})/e;
	}
	while ($text=~/\%(WEEK|MONTH|YEAR)SEL(\(([^\)]*)\))?/) {
		my ($what,$range)=($1,$3);
		my $default ="";
		$default = ($yy-3).':'.($yy+3) if $what eq 'YEAR';
		$default = '1:12' if $what eq 'MONTH';
		$default = "1:$wiy" if $what eq 'WEEK';
		my ($a,$b,$s) = _getOptionRange($range,$default);

		my @vals = ('');
		for (my $offs=$a; $offs!=$b+$s; $offs+=$s) {
			push @vals, $offs;
		}

		$text =~ s/\%\Q$what\ESEL(\([^\)]*\))?/CGI::popup_menu(-title=>"\L$what\E",-name=>"hlp_\L$what\E_$hlid",-values=>\@vals, -default=>$options{lc($what)})/e;
	}
	while ($text=~/\%(STARTDATE|WEEK|MONTH|YEAR)(\(([^\)]*)\))?/) {
		my ($what,$default)=($1,$3);
		$default = $options{lc($what)} unless defined $default;
		$text =~ s/\%\Q$what\E(\([^\)]*\))?/CGI::textfield(-title=>"\L$what\E",-name=>"hlp_\L$what\E_$hlid",-default=>$default)/e;
	}


	$text=~s/%BUTTON(\(([^\)]*)\))?/CGI::submit(-name=>'hlp_change_'.$hlid,-value=>(defined $2?$2:'Change'))/eg;
	
	$text = CGI::start_form(-action=>"#hlpid$hlid",-method=>'get'). $text . CGI::end_form();
	return $text;
}
sub _getOptionRange {
	my ($range,$default) = @_;
	$range=$default if !defined $range;
	my ($a,$b,$s) = split(/:/,$range);
	$s=1 unless defined $s;
	$b=$a unless defined $b;

	# avoid endless loops:
	$s=1 if (abs($a-$b) % abs($s)) != 0;
	
	# change sign of steps:
	$s=$a>$b?-abs($s):abs($s);

	# avoid large ranges:
	$b=$a+(100*$s) if (abs($a-$b)/abs($s))>100;
	
	return ($a,$b,$s);
}
sub _renderText {
	my ($text, $web) = @_;
	my $ret = $text;
	if (defined $rendererCache{$web}{$text}) {
		$ret = $rendererCache{$web}{$text};
	} else {
		$ret = TWiki::Func::renderText($text, $web);
		$rendererCache{$web}{$text}=$ret;
	}
	return $ret;
}

1;
