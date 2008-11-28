# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2000-2003 Peter Thoeny, peter@thoeny.com
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
# This is the default TWiki plugin. Use EmptyPlugin.pm as a template
# for your own plugins; see %SYSTEMWEB%.Plugins for details.
#
# Each plugin is a package that may contain these functions:        VERSION:
#
#   initPlugin              ( $topic, $web, $user, $installWeb )    1.000
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
# For increased performance, unused handlers are disabled. To
# enable a handler remove the leading DISABLE_ from the function
# name. Remove disabled handlers you do not need.
#
# NOTE: To interact with TWiki use the official TWiki functions 
# in the TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!


# =========================
package TWiki::Plugins::TodaysVisitorsPlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $pluginName
        $debug $doOldInclude $renderingWeb
    );

# This should always be $Rev: 6827 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 6827 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'TodaysVisitorsPlugin';  # Name of this Plugin

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Get plugin preferences
    $doOldInclude = TWiki::Func::getPreferencesFlag( "\U$pluginName\E_OLDINCLUDE" ) || "";

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag( "\U$pluginName\E_DEBUG" );

    $renderingWeb = $web;

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

    # for compatibility for earlier TWiki versions:
    if( $doOldInclude ) {
        # allow two level includes
        $_[0] =~ s/%INCLUDE:"([^%\"]*?)"%/TWiki::handleIncludeFile( $1, $_[1], $_[2], "" )/geo;
        $_[0] =~ s/%INCLUDE:"([^%\"]*?)"%/TWiki::handleIncludeFile( $1, $_[1], $_[2], "" )/geo;
    }

    # do custom extension rule, like for example:
    # $_[0] =~ s/%XYZ%/&handleXyz()/ge;
    # $_[0] =~ s/%XYZ{(.*?)}%/&handleXyz($1)/ge;

    $_[0] =~ s/%TODAYSVISITORS%/&_getTodaysVisitors/ge;
    $_[0] =~ s/%TODAYSVISITORS{(.*?)}%/&_getTodaysVisitors($1)/ge;
}

# =========================
sub startRenderingHandler
{
### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    TWiki::Func::writeDebug( "- ${pluginName}::startRenderingHandler( $_[1] )" ) if $debug;

    # This handler is called by getRenderedVersion just before the line loop

    $renderingWeb = $_[1];
}

# =========================
sub outsidePREHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    ##TWiki::Func::writeDebug( "- ${pluginName}::outsidePREHandler( $renderingWeb.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion, once per line, before any changes,
    # for lines outside <pre> and <verbatim> tags. 
    # Use it to define customized rendering rules

    # do custom extension rule, like for example:
    # $_[0] =~ s/old/new/go;

    # render deprecated *_text_* as "bold italic" text:
    $_[0] =~ s/(^|\s)\*_([^\s].*?[^\s])_\*(\s|$)/$1<strong><em>$2<\/em><\/strong>$3/go;

    # Use alternate %Web:WikiName% syntax (versus the standard Web.WikiName).
    # This is an old JosWiki render option. (Uncomment for JosWiki compatibility)
#   $_[0] =~ s/(^|\s|\()\%([^\s].*?[^\s]):([^\s].*?[^\s])\%/&TWiki::internalLink($2,$3,"$2:$3",$1,1)/geo;

    # Use "forced" non-WikiName links (i.e. %Linkname%)
    # This is an old JosWiki render option. (Uncomment for JosWiki compatibility)
#   $_[0] =~ s/(^|\s|\()\%([^\s].*?[^\s])\%/&TWiki::internalLink($web,$2,$2,$1,1)/geo;

    # Use "forced" non-WikiName links (i.e. %Web.Linkname%)
    # This is an old JosWiki render option combined with the new Web.LinkName notation
    # (Uncomment for JosWiki compatibility)
#   $_[0] =~ s/(^|\s|\()\%([a-zA-Z0-9]+)\.(.*?[^\s])\%(\s|\)|$)/&TWiki::internalLink($2,$3,$3,$1,1)/geo;

    # Use <link>....</link> links
    # This is an old JosWiki render option. (Uncomment for JosWiki compatibility)
#   $_[0] =~ s/<link>(.*?)<\/link>/&TWiki::internalLink("",$web,$1,$1,"",1)/geo;
}

# =========================
sub _getTodaysVisitors
{
    my( $theAttributes ) = @_;
    my $theHeader = TWiki::Func::extractNameValuePair( $theAttributes, "header" ) || "";
    my $theFormat = TWiki::Func::extractNameValuePair( $theAttributes, "format" ) || "\$user";
    my $theFooter = TWiki::Func::extractNameValuePair( $theAttributes, "footer" ) || "";

    my $text = "";
    my @visitorList = ();

    # calculate some time/date things
    my $yearmonth;
    my $filename;
    my $today;
    my ( $sec, $min, $hour, $mday, $mon, $year ) = localtime( time() );
    if(!defined($TWiki::cfg{LogFileName})) {
        my ($tmon) = $TWiki::isoMonth[$mon];
        $year = sprintf( "%.4u", $year + 1900 );  # Y2K fix
        $yearmonth = sprintf( "%.4u%.2u", $year, $mon+1 );
        $filename = $TWiki::logFilename;
        $today = sprintf( "%.2u ${tmon} %.2u", $mday, $year );
    } else {
        require TWiki::Time;
        $yearmonth =
          TWiki::Time::formatTime( time(), '$year$mo', 'servertime');
        $today =
          TWiki::Time::formatTime( time(), '$day $month $year', 'servertime');
        $filename = $TWiki::cfg{LogFileName};
    }

    # read the current logfile
    $filename =~ s/%DATE%/$yearmonth/go;
    my $logfile = TWiki::Func::readFile( $filename );
    
    
    my @bar = ();         # one line in logfile
    my %exclude = ();     # to avoid doubles
    
    # go through the logfile and collect visitor names
    foreach( reverse split( /\n/, $logfile ) ) {
      @bar = split( /\|/ );
      if( ( ! %exclude ) || ( ! $exclude{ $bar[2] } ) ) {
        # strip off all days not today
        next unless $today eq substr( $bar[1], 1, 11 );
        
        push @visitorList, $bar[2];
        $exclude{ $bar[2] } = "1";
      }
    }

    sub ab { $a cmp $b; };
    my @sortedList = sort ab @visitorList;
    
    # garnish the collected data
    $text = $theHeader . "\n";
    foreach my $listItem ( @sortedList ) {
      my $line = $theFormat;
      $line =~ s/\$user/$listItem/gos;
      $text .= $line;
    }
    $text .= "\n" . $theFooter;
    
    my $mixedAlpha = $TWiki::regex{mixedAlpha};
    $text =~ s/\$n\(\)/\n/gos;                    # expand "$n()" to new line
    $text =~ s/\$n([^$mixedAlpha]|$)/\n$1/gos;    # expand "$n" to new line
    $text =~ s/\$quot(\(\))?/\"/gos;              # expand double quote
    $text =~ s/\$percnt(\(\))?/\%/gos;            # expand percent
    $text =~ s/\$dollar(\(\))?/\$/gos;            # expand dollar

    return $text;
}

1;
