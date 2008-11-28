# DateTimePlugin.pm
# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# For DateTimePlugin.pm:
# Copyright (C) 2004 Aurélio A. Heckert, aurelio@im.ufba.br
# Copyright (C) 2008 Arthur Clemens, arthur@visiblearea.com
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

package TWiki::Plugins::DateTimePlugin;

use strict;

use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $pluginName
  $debug
  @monthsLong @monthsShort @weekdaysLong @weekdaysShort
  @i18n_monthsLong @i18n_monthsShort @i18n_weekdaysLong
  @i18n_weekdaysShort $timezoneOffset
  %fullMonth2IsoMonth $monthLongNamesReStr
);

# This should always be $Rev: 16465 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 16465 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = '1.0';

$pluginName = 'DateTimePlugin';    # Name of this Plugin

sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag
    $debug = $TWiki::cfg{DateTimePlugin}{Debug};

    TWiki::Func::registerTagHandler( 'DATETIME', \&_formatDateTime );

    _initDateStrings();

    # Plugin correctly initialized
    TWiki::Func::writeDebug(
        "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK")
      if $debug;

    return 1;
}

sub _initDateStrings {

    # Default month and week names array in english (compatibility):
    @monthsLong = (
        'January',   'February', 'March',    'April',
        'May',       'June',     'July',     'August',
        'September', 'October',  'November', 'December'
    );
    @monthsShort = (
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    );
    @weekdaysLong = (
        'Sunday',   'Monday', 'Tuesday', 'Wednesday',
        'Thursday', 'Friday', 'Saturday'
    );
    @weekdaysShort = ( 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat' );

    my $upperCasePluginName = uc($pluginName);

    my $language = TWiki::Func::getPreferencesValue("LANGUAGE") || 'en';

    my $configMonthsLong =
      $TWiki::cfg{DateTimePlugin}{Dates}{MonthsLong}{"$language"};
    @i18n_monthsLong =
      $configMonthsLong ? split( / /, $configMonthsLong ) : @monthsLong;

    my $configMonthsShort =
      $TWiki::cfg{DateTimePlugin}{Dates}{MonthsShort}{"$language"};
    @i18n_monthsShort =
      $configMonthsShort ? split( / /, $configMonthsShort ) : @monthsShort;

    my $configWeekdaysLong =
      $TWiki::cfg{DateTimePlugin}{Dates}{WeekdaysLong}{"$language"};
    @i18n_weekdaysLong =
      $configWeekdaysLong ? split( / /, $configWeekdaysLong ) : @weekdaysLong;

    my $configWeekdaysShort =
      $TWiki::cfg{DateTimePlugin}{Dates}{WeekdaysShort}{"$language"};
    @i18n_weekdaysShort =
      $configWeekdaysShort
      ? split( / /, $configWeekdaysShort )
      : @weekdaysShort;

    $timezoneOffset = $TWiki::cfg{DateTimePlugin}{TimezoneOffset};

    # all long month names as one 'or' string to be used in regexes
    $monthLongNamesReStr = join( '|', @monthsLong );

    # create a mapping between long and short month names
    {
        my $count = 0;
        %fullMonth2IsoMonth =
          map { $_ => $monthsShort[ $count++ ] } @monthsLong;
    }
}

sub _formatDateTime {
    my ( $session, $params, $inTopic, $inWeb ) = @_;

    my $format = $params->{"format"}
      || $params->{_DEFAULT}
      || $TWiki::cfg{DefaultDateFormat}
      || '$day $month $year - $hours:$minutes:$seconds';

    my $incDays  = $params->{"incdays"};
    my $incHours = $params->{"inchours"};
    my $incMins  = $params->{"incminutes"} || $params->{"incmins"};
    my $incSecs  = $params->{"incseconds"} || $params->{"incsecs"};

    $timezoneOffset ||= 0;
    $incDays        ||= 0;
    $incHours       ||= 0;
    $incMins        ||= 0;
    $incSecs        ||= 0;

    my $inc =
      $incSecs +
      ( $incMins * 60 ) +
      ( $incHours * 60 * 60 ) +
      ( $incDays * 60 * 60 * 24 );

    my $secondsSince1970 = time();
    my $dateStr          = $params->{"date"};

    if ( defined $dateStr ) {

        # try to match long month names
        $dateStr =~ s/($monthLongNamesReStr)/$fullMonth2IsoMonth{$1}/g;
        $secondsSince1970 = TWiki::Time::parseTime($dateStr);
    }
    else {

        # use international time offset only when we are using the current time
        $incHours += $timezoneOffset;
    }

    my $tmpTimeFormat =
"\$seconds,\$minutes,\$hours,\$day,\$wday,\$dow,\$week,\$month,\$mo,\$year,\$ye,\$tz";
    my $timeString =
      TWiki::Time::formatTime( $secondsSince1970 + $inc, $tmpTimeFormat, 1 );
    my @timeValues = split( ",", $timeString );

    my $seconds = $timeValues[0];
    my $minutes = $timeValues[1];
    my $hours   = $timeValues[2];
    my $day     = $timeValues[3];
    my $wday    = $timeValues[4];
    my $dow     = $timeValues[5];
    my $week    = $timeValues[6];
    my $month   = $timeValues[7];
    my $mo      = $timeValues[8];
    my $year    = $timeValues[9];
    my $ye      = $timeValues[10];
    my $tz      = $timeValues[11];

    my $monthIndex = $mo - 1;
    my $i_lmonth   = $i18n_monthsLong[$monthIndex];
    my $i_month    = $i18n_monthsShort[$monthIndex];
    my $lmonth     = $monthsLong[$monthIndex];
    my $i_lwday    = $i18n_weekdaysLong[$dow];
    my $i_wday     = $i18n_weekdaysShort[$dow];
    my $lwday      = $weekdaysLong[$dow];

    # Predefined formats:
    my $iso  = "$year-$mo-${day}T$hours:${minutes}Z";
    my $rcs  = "$year/$mo/$day $hours:$minutes:$seconds";
    my $http = "$wday, $day $month $year $hours:$minutes:$seconds $tz";

    my $out = $format;

    $out =~ s/\$year/$year/gseo;
    $out =~ s/\$ye/$ye/gseo;
    $out =~ s/\$month/$month/gseo;
    $out =~ s/\$lmonth/$lmonth/gseo;
    $out =~ s/\$mo/$mo/gseo;
    $out =~
      s/\$day2/$day/gseo;   # actually this is identical; kept for compatibility
    $out =~ s/\$day/$day/gseo;
    $out =~ s/\$hours/$hours/gseo;
    $out =~ s/\$hour/$hours/gseo;
    $out =~ s/\$minutes/$minutes/gseo;
    $out =~ s/\$min/$minutes/gseo;
    $out =~ s/\$seconds/$seconds/gseo;
    $out =~ s/\$sec/$seconds/gseo;
    $out =~ s/\$dow/$dow/gseo;
    $out =~ s/\$wday/$wday/gseo;
    $out =~ s/\$lwday/$lwday/gseo;
    $out =~ s/\$week/$week/gseo;

    $out =~ s/\$i_month/$i_month/gseo;
    $out =~ s/\$i_lmonth/$i_lmonth/gseo;
    $out =~ s/\$i_wday/$i_wday/gseo;
    $out =~ s/\$i_lwday/$i_lwday/gseo;

    $out =~ s/\$epoch/$secondsSince1970/gseo;
    $out =~ s/\$iso/$iso/gseo;
    $out =~ s/\$rcs/$rcs/gseo;
    $out =~ s/\$http/$http/gseo;
    $out =~ s/\$tz/$tz/gseo;

    return $out;
}

1;
