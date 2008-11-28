# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
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
# This is ToolTip plugin.
#


# =========================
package TWiki::Plugins::ToolTipPlugin;    # change the package name and $pluginName!!!

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $pluginName
        $debug  $DefaultReadersFormat $ToolTipID $ToolTipOpened
        $incBalloon $incCenter $incFollow
    );

# This should always be $Rev: 17559 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 17559 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = '1.4';

$pluginName = 'ToolTipPlugin';  # Name of this Plugin

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

    $DefaultReadersFormat = &TWiki::Func::getPreferencesValue ("TOOLTIPPLUGIN_READERSFORMAT") || "<li> %READERNAME% : %READERDATE%";

    # Flags to indicate that optional javascript files should be included
    # in the <script tags
    #
    $incBalloon = 0;  # Need tip_balloon.js
    $incCenter = 0;   # Need tip_centerwindow.js
    $incFollow = 0;   # Need tip_followscroll.js



    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;

    $ToolTipID=0;
    $ToolTipOpened=0;

    return 1;
}

# =========================
sub postRenderingHandler
{
	TWiki::Func::writeDebug( "- ${pluginName}::postRenderingHandler( $web.$topic )" ) if $debug;

    $_[0] =~ s/%TOOLTIP{(.*?)}%/&handleToolTip($1)/ge;
    $_[0] =~ s/%TOOLTIP%/&handleToolTip("")/ge;
    
    # this search and replace could be made more robust if this were ever called more than once
    # (more than once with the </body> tag in the text, that is)

    my $scripts = "<script type=\"text/javascript\" src=\"$TWiki::cfg{PubUrlPath}/$TWiki::cfg{SystemWebName}/$pluginName/wz_tooltip.js\"></script>\n";
    $scripts .= "<script type=\"text/javascript\" src=\"$TWiki::cfg{PubUrlPath}/$TWiki::cfg{SystemWebName}/$pluginName/tip_centerwindow.js\"></script>\n" if ($incCenter);
    $scripts .= "<script type=\"text/javascript\" src=\"$TWiki::cfg{PubUrlPath}/$TWiki::cfg{SystemWebName}/$pluginName/tip_followscroll.js\"></script>\n" if ($incFollow);
    $scripts .= "<script type=\"text/javascript\" src=\"$TWiki::cfg{PubUrlPath}/$TWiki::cfg{SystemWebName}/$pluginName/tip_balloon.js\"></script>\n" if ($incBalloon);

    $_[0] =~ s|(</body>)|$scripts$1| if ($ToolTipID);  # Insert scripts only if %TIP 
}

sub handleToolTip
{
  my $attr = shift;

  my $out="";
  if ( ($attr =~ /END/) || ($attr =~ /^$/) )
  { 
    if ( $ToolTipOpened>0 ) 
    {
      $out="</a>"; 
      $ToolTipOpened-=1;
    }
    else
    {
      $ToolTipOpened=0;
    }
  }
  else
  {
    TWiki::Func::writeDebug( "TOOLTIP - BEFORE : $attr") if $debug;

    # WikiWords that are unresolved create a <span> ... </span> containing double-quotes
    # And resolved WikiWords create <a ...> tags containing double-quotes.  
    # Both of these are automatically inserted by TWiki rendering and break the TEXT=" " string

    $attr =~ s/<span\s+(.*?)<\/span>/&fixupSpan($1)/ge;   # Fixup any double-quotes found within <span> tags
    $attr =~ s/<a\s+([^>]+)>/&fixupUrl($1)/ge;            # Fixup any double-quotes found within <a> tags

    my $theText     = &TWiki::Func::extractNameValuePair( "$attr", "TEXT" )      || ""; 
    my $TextInclude = &TWiki::Func::extractNameValuePair( "$attr", "INCLUDE" )   || ""; 
    my $theURL      = &TWiki::Func::extractNameValuePair( "$attr", "URL" )       || "javascript:void(0);"; 
    my $theTARGET   = &TWiki::Func::extractNameValuePair( "$attr", "TARGET" )    || ""; 


    $attr =~ s/INCLUDE\s*=\s*\"([^\"]*)\"//g;   # remove INCLUDE from attributes
    $attr =~ s/URL\s*=\s*\"([^\"]*)\"//g;       # remove URL from attributes
    $attr =~ s/TARGET\s*=\s*\"([^\"]*)\"//g;    # remove TARGET from attributes
    $attr =~ s/TEXT\s*=\s*\"([^\"]*)\"//g;      # remove TEXT from attributes
    $attr =~ s/(\S+)\s*=\s*\"([^\"]*)\"/$1, \'$2\',/g;   # Convert each parameter to Tip format "ATTR, VALUE"
    $attr =~ s/\s+$//;                           # Strip any trailing spaces
    $attr =~ s/, \'(\d+)\',/, $1,/g;             # Strip quotes from decimal parameters
    chop($attr) if (substr($attr,-1) eq ",");    # and any trailing comma
    TWiki::Func::writeDebug( "TOOLTIP - AFTER : $attr") if $debug;

    # Add a defautl BALLOONIMGPATH if BALLON is true and path is not provided
    #
    if ( $attr =~ m/BALLOON, '[Tt][Rr][Uu][Ee]'/o ) {
       $attr .= ", BALLOONIMGPATH,  '$TWiki::cfg{PubUrlPath}/$TWiki::cfg{SystemWebName}/$pluginName/'" if (!($attr =~ m/BALLOONIMGPATH,/o));
       $incBalloon = 1;
       }

    $incCenter = 1 if ( $attr =~ m/CENTERWINDOW, '[Tt][Rr][Uu][Ee]'/o ) ;
    $incFollow = 1 if ( $attr =~ m/FOLLOWSCROLL, '[Tt][Rr][Uu][Ee]'/o ) ;
       
   
    if ( $TextInclude )
    {
     TWiki::Func::writeDebug( "topic : $TextInclude") if $debug;
     $theText="Invalid topic name <b>$TextInclude</b> !";
     my( $iweb, $itopic ) = split('\.', $TextInclude);
     if ( ! $itopic ) { $itopic=$iweb; $iweb=$web; }
     if( TWiki::Func::topicExists( $iweb, $itopic ) ) 
     {
         $theText="<b> Denied: view of topic <nop>$params->{INCLUDE} not permitted</b>  !";
         my ( $meta, $text ) = &TWiki::Func::readTopic( $iweb, $itopic );

         if (TWiki::Func::checkAccessPermission(
             'VIEW', TWiki::Func::getWikiName(), $text, $itopic, $iweb, $meta)) {

            $text =~ s/.*?%STARTINCLUDE%//os;
            $text =~ s/%STOPINCLUDE%.*//os;
            $theText = &TWiki::Func::expandCommonVariables($text, $itopic, $iweb);
            $theText = &TWiki::Func::renderText( $theText );
            $theText =~ s/\'//g;
            $theText =~ s/\"//g;
            $theText =~ s/\n//g;
         }
     } 
    }

    $out = "<a border=\"0\" href=\"$theURL\" ";
    if ( $theTARGET ) 
    { 
      $out.="target=\"$theTARGET\""; 
    }

    $out.= " onmouseover=\"Tip('$theText', $attr)\" onmouseout=\"UnTip()\">";

    $ToolTipID+=1;
    $ToolTipOpened+=1;
  }
  return ("$out");
}

#
## Quote any double-quotes found between <a> and </a> tags
#
sub fixupUrl 
{
    my $url = shift;
    TWiki::Func::writeDebug( "TOOLTIP-URL $url") if $debug;
    $url =~ s/\"/\&quot\;/g;
    return ("<a $url>");
}

# 
## Quote any double-quotes found between <span> </span> tags
#
sub fixupSpan 
{
    my $span = shift;
    TWiki::Func::writeDebug( "TOOLTIP-SPAN $span") if $debug;
    $span =~ s/\"/\&quot\;/g;
    return ("<span $span</span>");
}
1;
