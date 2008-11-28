# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2003 Peter Thoeny, peter@thoeny.com
# Copyright (C) 2003      Nathan Ollerenshaw, chrome@stupendous.net
# Copyright (C) 2006      Sven Dowideit, SvenDowideit@WikiRing.com
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


# =========================
package TWiki::Plugins::LocalTimePlugin;
use Date::Handler;
use strict;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $pluginName
        $debug $exampleCfgVar $timezone
    );

# This should always be $Rev: 11113 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 11113 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'LocalTimePlugin';  # Name of this Plugin

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning( "Version mismatch between LocalTimePlugin and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag( "LOCALTIMEPLUGIN_DEBUG" );

    # Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
    $timezone = &TWiki::Func::getPreferencesValue( "LOCALTIMEPLUGIN_TIMEZONE" ) || "Asia/Tokyo";

    TWiki::Func::registerTagHandler( 'LOCALTIME', \&handleLocalTime );

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

#    $_[0] =~ s/%LOCALTIME%/&handleLocalTime($timezone)/geo;
#    $_[0] =~ s/%LOCALTIME{(.*?)}%/&handleLocalTime($1)/geo;
}
# =========================

sub handleLocalTime {
    my($session, $params, $theTopic, $theWeb) = @_;

    my $tz = $params->{_DEFAULT} || $timezone;
    my $formatString = $params->{format};
    my $fromtopic = $params->{fromtopic};
    my $specifieddateGMT = $params->{dateGMT};

    if (defined($fromtopic)) {
        #TODO: normalise topic
        my( $web, $topic ) = $session->normalizeWebTopicName( $theWeb, $fromtopic );
        my $zone = $session->{prefs}->getTopicPreferencesValue('TIMEZONE', $web, $topic);
        $tz = $zone if defined($zone);
    }

    my $date;
    if (defined ($specifieddateGMT)) {
        $date = new Date::Handler({ date => TWiki::Time::parseTime($specifieddateGMT), time_zone => $tz });
    } else {
        $date = new Date::Handler({ date => time, time_zone => $tz });
    }
    

#swiped from TWiki::Time::formatTime
#SMELL: should combine this code into TWiki::Time, or abstract out and reuse..
    my $value = '';
    $formatString ||= '$wday, $day $month $year, $hour:$min:$sec ($tz)';
#    my $outputTimeZone ||= $TWiki::cfg{DisplayTimeValues};

    #standard twiki date time formats
    if( $formatString =~ /rcs/i ) {
        # RCS format, example: "2001/12/31 23:59:59"
        $formatString = '$year/$mo/$day $hour:$min:$sec';
    } elsif ( $formatString =~ /http|email/i ) {
        # HTTP header format, e.g. "Thu, 23 Jul 1998 07:21:56 EST"
 	    # - based on RFC 2616/1123 and HTTP::Date; also used
        # by TWiki::Net for Date header in emails.
        $formatString = '$wday, $day $month $year $hour:$min:$sec $tz';
    } elsif ( $formatString =~ /iso/i ) {
        # ISO Format, see spec at http://www.w3.org/TR/NOTE-datetime
        # e.g. "2002-12-31T19:30:12Z"
        $formatString = '$year-$mo-$dayT$hour:$min:$sec';
    }

    my $wday = $date->WeekDay();

    $value = $formatString;
    $value =~ s/\$seco?n?d?s?/sprintf('%.2u',$date->Sec())/gei;
    $value =~ s/\$minu?t?e?s?/sprintf('%.2u',$date->Min())/gei;
    $value =~ s/\$hour?s?/sprintf('%.2u',$date->Hour())/gei;
    $value =~ s/\$day/sprintf('%.2u',$date->Day())/gei;
    $value =~ s/\$wday/$TWiki::Time::WEEKDAY[$date->WeekDay()]/gi;
    $value =~ s/\$dow/$date->WeekDay()/gei;
    $value =~ s/\$week/TWiki::Time::_weekNumber($date->Day(),$date->Month()-1,$date->Year(),$date->WeekDay())/egi;
    $value =~ s/\$mont?h?/$TWiki::Time::ISOMONTH[$date->Month()-1]/gi;
    $value =~ s/\$mo/sprintf('%.2u',$date->Month())/gei;
    $value =~ s/\$year?/sprintf('%.4u',$date->Year())/gei;
    $value =~ s/\$ye/sprintf('%.2u',$date->Year()%100)/gei;
    $value =~ s/\$epoch/$date->Epoch()/gei;
    $value =~ s/\$tz/$date->TimeZone()/gei;

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

1;
