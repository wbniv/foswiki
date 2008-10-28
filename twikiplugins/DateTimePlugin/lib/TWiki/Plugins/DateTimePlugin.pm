# DateTimePlugin.pm  (based on EmptyPlugin.pm)
# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# For DateTimePlugin.pm:
# Copyright (C) 2004 Aurélio A. Heckert, aurelio@im.ufba.br
# For EmptyPlugin.pm:
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2003 Peter Thoeny, peter@thoeny.com
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
#
# Each plugin is a package that may contain these functions:        VERSION:
#
#   initPlugin              ( $topic, $web, $user, $installWeb )    1.000
#   initializeUserHandler   ( $loginName, $url, $pathInfo )         1.010
#   registrationHandler     ( $web, $wikiName, $loginName )         1.010
#   commonTagsHandler       ( $text, $topic, $web )                 1.000
#   startRenderingHandler   ( $text, $web )                         1.000
#   outsidePREHandler       ( $text )                               1.000
#   insidePREHandler        ( $text )                               1.000
#   endRenderingHandler     ( $text )                               1.000
#   beforeEditHandler       ( $text, $topic, $web )                 1.010
#   afterEditHandler        ( $text, $topic, $web )                 1.010
#   beforeSaveHandler       ( $text, $topic, $web )                 1.010
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
package TWiki::Plugins::DateTimePlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $pluginName
        $debug $exampleCfgVar
    );

# This should always be $Rev: 6827 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 6827 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'DateTimePlugin';  # Name of this Plugin
$uCasePName = uc($pluginName);   # The Uper-Case Name

# =========================

sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag( "\U$pluginName\E_DEBUG" );

    # Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
    # $exampleCfgVar = &TWiki::Func::getPreferencesValue( "EMPTYPLUGIN_EXAMPLE" ) || "default";

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
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    $_[0] =~ s/%DATETIME{(.*?)}%/&formatDateTime($1)/gseo;
}

# =========================

sub formatDateTime
{
   my ($textArgs) = @_;
   # Default month and week names array in english (compatibility):
   my @monthLongNames =
      ( 'January','February','March','April','May','June','July','August','September','October','November','December' );
   my @monthShortNames =
      ( 'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec' );
   my @weekdayLongNames =
      ( 'Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday' );
   my @weekdayShortNames =
      ( 'Sun','Mon','Tue','Wed','Thu','Fri','Sat' );
   # Internationalized month and week names, by the plugin preferences:
   my @i18n_monthLongNames =
      split( / /, TWiki::Func::getPreferencesValue($uCasePName.'_monthLongNames') );
   my @i18n_monthShortNames =
      split( / /, TWiki::Func::getPreferencesValue($uCasePName.'_monthShortNames') );
   my @i18n_weekdayLongNames =
      split( / /, TWiki::Func::getPreferencesValue($uCasePName.'_weekdayLongNames') );
   my @i18n_weekdayShortNames =
      split(/ /, TWiki::Func::getPreferencesValue($uCasePName.'_weekdayShortNames') );
   my $myGreenwich = TWiki::Func::getPreferencesValue($uCasePName.'_myGreenwich');

   # Pega o argumento _format_ inserido na váriável TWiki:
   my $format = TWiki::Func::extractNameValuePair( $textArgs );
   if ( ! $format ) {
      $format = TWiki::Func::extractNameValuePair( $textArgs, "format" );
      $format = 'não formatada $day $month, $year - $hour:$min:$sec' if ( ! $format );
   }
   #my $incYears  = TWiki::Func::extractNameValuePair( $textArgs, "incyears"  ) or 0;
   #my $incMonths = TWiki::Func::extractNameValuePair( $textArgs, "incmonths" ) or 0;
   my $incDays   = TWiki::Func::extractNameValuePair( $textArgs, "incdays"   );
   my $incHours  = TWiki::Func::extractNameValuePair( $textArgs, "inchours"  );
   my $incMins   = TWiki::Func::extractNameValuePair( $textArgs, "incmins"   );
   my $incSecs   = TWiki::Func::extractNameValuePair( $textArgs, "incsecs"   );

   $myGreewich ||= 0;
   $incDays ||= 0;
   $incHours ||= 0;
   $incMins ||= 0;
   $incSecs ||= 0;

   $incHours += $myGreenwich;
   my $inc = $incSecs + ($incMins*60) + ($incHours*60*60) + ($incDays*60*60*24);

   my ($sec, $min, $hour, $day, $month, $year, $wday, $yday) = gmtime( time() + $inc );
   $sec =  ( ($sec < 10)? '0' : '' ) . $sec;
   $min =  ( ($min < 10)? '0' : '' ) . $min;
   $hour = ( ($hour< 10)? '0' : '' ) . $hour;
   $day2 = ( ($day < 10)? '0' : '' ) . $day;
   my $mo = ( ($month < 10)? '0' : '' ) . $month;
   my $numMonth = $month;
   my $i_lmonth = $i18n_monthLongNames[ $numMonth ];
   my $i_month = $i18n_monthShortNames[ $numMonth ];
   my $lmonth = $monthLongNames[ $numMonth ];
   $month = $monthShortNames[ $numMonth ];
   my $i_lwday = $i18n_weekdayLongNames[ $wday ];
   my $i_wday = $i18n_weekdayShortNames[ $wday ];
   my $lwday = $weekdayLongNames[ $wday ];
   $wday = $weekdayShortNames[ $wday ];
   $year += 1900;
   my $ye = substr( $year, 2, 2 );
   my $century = "(Not implemented yet)";
   my $romancentury = "(Not implemented yet)";

   # Predefined formats:
   my $iso = "$year-$mo-${day2}T$hour:${min}Z";
   my $rcs = "$year/$mo/$day2 $hour:$min:$sec";

   $format =~ s/(^|[^\\])"/\\"/g;
   #my $out = eval('"'.$format.'"');
   $out = $format;
   $out =~ s/\$iso/$iso/gseo;
   $out =~ s/\$rcs/$rcs/gseo;
   $out =~ s/\$year/$year/gseo;
   $out =~ s/\$ye/$ye/gseo;
   $out =~ s/\$month/$month/gseo;
   $out =~ s/\$lmonth/$lmonth/gseo;
   $out =~ s/\$mo/$mo/gseo;
   $out =~ s/\$day2/$day2/gseo;
   $out =~ s/\$day/$day/gseo;
   $out =~ s/\$hours/$hour/gseo;
   $out =~ s/\$hour/$hour/gseo;
   $out =~ s/\$minutes/$min/gseo;
   $out =~ s/\$min/$min/gseo;
   $out =~ s/\$seconds/$sec/gseo;
   $out =~ s/\$sec/$sec/gseo;
   $out =~ s/\$wday/$wday/gseo;
   $out =~ s/\$lwday/$lwday/gseo;
   $out =~ s/\$i_month/$i_month/gseo;
   $out =~ s/\$i_lmonth/$i_lmonth/gseo;
   $out =~ s/\$i_wday/$i_wday/gseo;
   $out =~ s/\$i_lwday/$i_lwday/gseo;
   $out =~ s/\$yday/$yday/gseo;
   $out =~ s/\$century/$century/gseo;
   $out =~ s/\$romancentury/$romancentury/gseo;
   #$out =~ s/\$/$/gseo;

   return "$out";
}

# =========================

1;
