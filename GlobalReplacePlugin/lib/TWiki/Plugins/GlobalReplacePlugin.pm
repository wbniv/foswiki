# Plugin for Foswiki - The Free Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2004-2006 Peter Thoeny, peter@thoeny.org
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
# This is an empty TWiki plugin. Use it as a template
# for your own plugins; see %SYSTEMWEB%.Plugins for details.
#
# Each plugin is a package that contains the subs:
#
#   initPlugin           ( $topic, $web, $user, $installWeb )
#   commonTagsHandler    ( $text, $topic, $web )
#   startRenderingHandler( $text, $web )
#   outsidePREHandler    ( $text )
#   insidePREHandler     ( $text )
#   endRenderingHandler  ( $text )
#
# initPlugin is required, all other are optional.
# For increased performance, all handlers except initPlugin are
# disabled. To enable a handler remove the leading DISABLE_ from
# the function name.
#
# NOTE: To interact with TWiki use the official TWiki functions
# in the &TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!


# =========================
package TWiki::Plugins::GlobalReplacePlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $debug
    );

# This should always be $Rev: 15564 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 15564 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';


# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning( "Version mismatch between GlobalReplacePlugin and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag( "GLOBALREPLACEPLUGIN_DEBUG" );

    # Plugin correctly initialized
    &TWiki::Func::writeDebug( "- TWiki::Plugins::GlobalReplacePlugin::initPlugin( $web.$topic ) is OK" ) if $debug;

    return 1;
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    &TWiki::Func::writeDebug( "- GlobalReplacePlugin::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    # do custom extension rule, like for example:
    # $_[0] =~ s/%XYZ%/&handleXyz()/geo;
    # $_[0] =~ s/%XYZ{(.*?)}%/&handleXyz($1)/geo;

    if( $_[0] =~ /%GLOBALREPLACE{/ ) {
        $_[0] =~ s/%GLOBALREPLACE{(.*?)}%/handleGlobalReplace($1)/geo;
    }

}

# =========================
sub handleGlobalReplace
{
    my ( $theArgs ) = @_;

    # parameter func can be: search, replace
    my $func = TWiki::Func::extractNameValuePair( $theArgs, "func" ) ||
        return "%RED%Invalid page access.%ENDCOLOR% Please go to " .
               "GlobalSearchAndReplace to start your operation.";
    my $param = TWiki::Func::extractNameValuePair( $theArgs, "param" ) || "";
    my $replaceSearchString = handleDecode(TWiki::Func::extractNameValuePair( $theArgs, "rSearchString" )) || "";
    my $replaceString = handleDecode(TWiki::Func::extractNameValuePair( $theArgs, "rString" )) || "";
    my $caseSensitive = TWiki::Func::extractNameValuePair( $theArgs, "caseSensitive" ) || "yes";

    #saved for Rob Hoffman's regular expression flag
    #$token = quotemeta( $token ) unless( $theRegex );

    my $text = "";
    my $aWeb = "";
    my $aTopic = "";
    my $topicText = "";

    # Only certain people can commit a global search and replace
    # untaint $user to get rid of the Insecure Dependency
    my $_user = "";
    if ( $user =~ /([\w]+)/ ) {
        $_user = $1;
    } else {
        return "Invalid User";
    }

    my $prefsWeb   = &TWiki::Func::expandCommonVariables( "%SYSTEMWEB%", "Main" );
    my $prefsTopic = &TWiki::Func::expandCommonVariables( "%WIKIPREFSTOPIC%", "Main" );
    my $access = &TWiki::Func::checkAccessPermission("change",
                                                     &TWiki::Func::userToWikiName($_user),
                                                     "", $prefsTopic, $prefsWeb );

    &TWiki::Func::writeDebug( "- GlobalReplacePlugin::handleGlobalReplace( " .
                              "$func, $param, $replaceSearchString, " .
                              "$replaceString, $caseSensitive )" ) if $debug ;

    if ( $func =~ /check/i ) {
        return "installed";

    } elsif ( $func =~ /search/i ) {

        $param =~ /(.*)\.(.*)/;
        $aWeb = $1;
        $aTopic = $2;
        return "| [[$param][$aTopic]] | %RED% No =Replace Search String= " .
               " entered. %ENDCOLOR% ||\n"
            unless ( $replaceSearchString );

        my $before = "";
        my $after = "";

        return "| [[$param][$aTopic]] | %RED% Topic does not exist %ENDCOLOR% ||\n"
            unless ( &TWiki::Func::topicExists( $aWeb, $aTopic ) );
        $topicText = &TWiki::Func::readTopicText( $aWeb, $aTopic );

        my $count = 0;
        my $hit;
        my $replace;
        my $position = 0;
        my $lasPos = 0;
        my $first = "";
        my $second = "";
        my $third = "";
        my $fourth = "";
        # save a copy so that the capture can be reset for each match
        my $orgReplaceString = $replaceString;

        while (1) {
            # reseting variables that allow the user to capture
            $first = "";
            $second = "";
            $third = "";
            $fourth = "";
            $replaceString = $orgReplaceString;

            # Make sure to grab a little before and after the hit
            # Try to grab the whole word instead of breaking it.

            if ( $caseSensitive =~ /yes/i ) {
                last unless $topicText =~ m/((?:^|\s|[a-zA-Z0-9\.]*).{0,40}?)($replaceSearchString)(.{0,40}[a-zA-Z0-9\.]*)/gs;
                $before = $1;
                $hit = $2;
                $first = $3 || "";
                $second = $4 || "";
                $third = $5 || "";
                $fourth = $6 || "";
                $after = $+;
            } else {
                last unless $topicText =~ m/((?:^|\s|[a-zA-Z0-9\.]*).{0,40}?)($replaceSearchString)(.{0,40}[a-zA-Z0-9\.]*)/gis;
                $before = $1;
                $hit = $2;
                $first = $3 || "";
                $second = $4 || "";
                $third = $5 || "";
                $fourth = $6 || "";
                $after = $+;
            }

            $replaceString =~ s/\$1/$first/gos;
            $replaceString =~ s/\$2/$second/gos;
            $replaceString =~ s/\$3/$third/gos;
            $replaceString =~ s/\$4/$fourth/gos;
            $replaceString =~ s/\$topic/$topic/gos;

            # reposition cursor in case there is a hit in the after
            # In resulting hits in after, will not have much in the leading before text.
            $lastPos = $position;
            $position = (pos $topicText) - (length $after);

            last if ( $lastPos == $position );

            pos $topicText = $position;

            # Encode with %(H|R)COLOR% Tags to highlight the hits and replace text
            $hit = "$before%HCOLOR%$hit%ENDCOLOR%$after";
            $hit = escapeSpecialChars($hit);
            $replace = "$before%RCOLOR%$replaceString%ENDCOLOR%$after";
            $replace = escapeSpecialChars($replace);

            $text .= "|  <input type=\"checkbox\" name=\"SEARCH_"
                  . "$aWeb" . "_" . $aTopic . "_" . ++$count . "\">";
            $text .= "  | <tt>$hit</tt> "
                   . " | <tt>$replace</tt> |\n";

        }

        my $temp = "";
        $temp = "<font size=\"-1\">- $count hits</font>" if( $count > 1 );

        my( $lock, $tmp1, $tmp2 ) = &TWiki::Func::checkTopicEditLock( $aWeb, $aTopic );
        $tmp1 = ""; $tmp2 = ""; # suppress warnings
        if( $lock ) {
            $lock = "%RED%(LOCKED)%ENDCOLOR%";
        } else {
            $lock = "";
        }

        $text = "| [[$param][$aTopic]] $temp $lock |||\n" . $text if ( $text );

    } elsif ( $func =~ /replace/i ) {

        return "You are currently logged in as " . &TWiki::Func::userToWikiName($_user)
               . ". %RED%Only Members of the Main." . $TWiki::superAdminGroup . " may save the changes "
               . "of a Global Search And Replace. %ENDCOLOR%"
            unless ($access);

        return "%RED% No =Replace Search String= " .
               " entered %ENDCOLOR% Back to GlobalSearchAndReplace.\n"
            unless ( $replaceSearchString );

        # reactivation tabs, carriage returns and newlines
        # for some reason, somewhere in the processing it became a string rather
        # what the \t, \n, \r should represent
        $replaceString =~ s/\\t/chr(9)/eg; # tab
        $replaceString =~ s/\\n/chr(10)/eg; # new line
        $replaceString =~ s/\\r/chr(13)/eg; # carriage return

        # getting checkbox parameters
        my $cgi = &TWiki::Func::getCgiQuery();
        if (! $cgi ) {
            return "";
        }

        # parsing checkbox parameters
        my @topicList = map { s/^SEARCH_//o; $_ }
                        grep { /^SEARCH/ }
                        $cgi->param;

        # maintaining a list of unique topic names
        my %topicHash = map { m/(.*?)_(.*)_.*/; "$1.$2" => 1} @topicList;

        my $count = 0; # counter for the number of replacements possible
        my $replaced = 0; # counter for the number of actual replacements done
        my $displayTopicText = "";
        foreach my $key ( sort keys %topicHash ) {
            $key =~ /(.*)\.(.*)/;
            $aWeb = $1;
            $aTopic = $2;

            $topicText = &TWiki::Func::readTopicText( $aWeb, $aTopic );

            # reset counters
            $count = 1;
            $replaced = 0;
            if ( $caseSensitive =~ /yes/i ) {
                $topicText =~ s/($replaceSearchString)/doReplace( $1, $2, $3, $4, $5,
                                                                   $replaceString,
                                                                   \$count, \@topicList,
                                                                   $aTopic, \$replaced )/geos;

            } else {
                $topicText =~ s/($replaceSearchString)/doReplace( $1, $2, $3, $4, $5,
                                                                   $replaceString,
                                                                   \$count, \@topicList,
                                                                   $aTopic, \$replaced )/igeos;
            }
            $displayTopicText = escapeSpecialChars( $topicText );
            $text .= "| [[$key][$aTopic]] | $replaced";
            $text .= "<br />DEBUG MESSAGE:<br /><tt>$displayTopicText</tt>" if $debug;
            $text .= " |\n";

            # Save changes to text here
            &TWiki::Func::writeDebug( "GlobalReplacePlugin::saving") if ( $debug );
            TWiki::Func::saveTopicText( $aWeb, $aTopic, $topicText );
        }
        if ( $text ) {
            $text = "| *Topic* | *Number of Replacements* |\n" . $text;
        } else {
            $text = "No Replacements done. Back to GlobalSearchAndReplace, "
                  . "GlobalReplacePlugin";
        }
    }

    return $text;
}

# =========================
sub doReplace
{
    my ( $hit, $first, $second, $third, $fourth, $replace, $count, $topicList, $topic, $replaced ) = @_;

    my ( $flag ) = grep { /.*\_$topic\_$$count/ } @$topicList;
    &TWiki::Func::writeDebug( "- GlobalReplacePlugin::doReplace($hit, $replace, "
                              . $$count . ", $topic, $flag, )" ) if $debug;
    $first = "" unless ($first);
    $second = "" unless ($second);
    $third = "" unless ($third);
    $fourth = "" unless ($fourth);

    $replace =~ s/\$1/$first/gos;
    $replace =~ s/\$2/$second/gos;
    $replace =~ s/\$3/$third/gos;
    $replace =~ s/\$4/$fourth/gos;
    $replace =~ s/\$topic/$topic/gos;

    ++$$count;
    if ( $flag ) {
        ++$$replaced;
        return $replace;
    } else {
        return $hit;
    }

    # should not get to here

    return $hit;
}

# =========================
sub escapeSpecialChars
{
    my ( $string ) = @_;

    $string =~ s/\&/&amp;/go;
    $string =~ s/\</&lt;/go;
    $string =~ s/\>/&gt;/go;
    $string =~ s/\=/&#61;/go;
    $string =~ s/\_/&#95;/go;
    # Highlight the hit and replace strings w/ color
    $string =~ s/\%HCOLOR\%/<font color=\"#FF0000\"><b>/go;
    $string =~ s/\%RCOLOR\%/<font color=\"#FF6600\"><b>/go;
    $string =~ s/\%ENDCOLOR\%/<\/b><\/font>/go;
    $string =~ s/\%/&#37;/go;
    $string =~ s/\*/&#42;/go;
    $string =~ s/\:/&#58;/go;
    $string =~ s/\\/&#92;/go;
    $string =~ s/\[/&#91;/go;
    $string =~ s/\]/&#93;/go;
    $string =~ s/\|/&#124;/go;
    $string =~ s/([\s\(])([A-Z])/$1<nop>$2/go; # defuse WikiWord links
    $string =~ s/\t/        /go;
    $string =~ s/  /&nbsp; /go;
    $string =~ s/[\n\r]+/<br \/>/gos;

    return $string;
}

# =========================
sub handleDecode
{
    my( $theStr ) = @_;

    # entity decode - Cairo: &#34;, Dakar: &#034;
    $theStr =~ s/\&\#34;/\"/g;
    $theStr =~ s/\&\#034;/\"/g;
    $theStr =~ s/\&\#37;/\%/g;
    $theStr =~ s/\&\#037;/\%/g;
    $theStr =~ s/\&\#38;/\&/g;
    $theStr =~ s/\&\#038;/\&/g;
    $theStr =~ s/\&\#39;/\'/g;
    $theStr =~ s/\&\#039;/\'/g;
    $theStr =~ s/\&\#42;/\*/g;
    $theStr =~ s/\&\#042;/\*/g;
    $theStr =~ s/\&\#60;/\</g;
    $theStr =~ s/\&\#060;/\</g;
    $theStr =~ s/\&\#61;/\=/g;
    $theStr =~ s/\&\#061;/\=/g;
    $theStr =~ s/\&\#62;/\>/g;
    $theStr =~ s/\&\#062;/\>/g;
    $theStr =~ s/\&\#91;/\[/g;
    $theStr =~ s/\&\#091;/\[/g;
    $theStr =~ s/\&\#93;/\]/g;
    $theStr =~ s/\&\#093;/\]/g;
    $theStr =~ s/\&\#95;/\_/g;
    $theStr =~ s/\&\#095;/\_/g;
    $theStr =~ s/\&\#124;/\|/g;

    return $theStr;
}

1;
