# Plugin for TWiki Collaboration Platform, http://TWiki.org/
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
    );

# This should always be $Rev: 9833 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 9833 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

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
    $_[0] =~ s|(</body>)|<script type="text/javascript" src="$TWiki::cfg{DefaultUrlHost}$TWiki::cfg{PubUrlPath}/$TWiki::cfg{SystemWebName}/$pluginName/wz_tooltip.js"></script>$1|;
}

sub handleToolTip
{
  my $attr = shift;

  my $out="";

  if ( ($attr =~ /END/) || ($attr =~ /^$/) )
  { 
    if ( $ToolTipOpened>0 ) 
    {
      $out="</A>"; 
      $ToolTipOpened-=1;
    }
    else
    {
      $ToolTipOpened=0;
    }
  }
  else
  {
    my $theText     = &TWiki::Func::extractNameValuePair( "$attr", "TEXT" )      || ""; 
    my $TextInclude = &TWiki::Func::extractNameValuePair( "$attr", "INCLUDE" )   || ""; 
    my $theURL      = &TWiki::Func::extractNameValuePair( "$attr", "URL" )       || "javascript:void(0);"; 
    my $theTARGET   = &TWiki::Func::extractNameValuePair( "$attr", "TARGET" )    || ""; 


    $attr =~ s/INCLUDE\s*=\s*\"([^\"]*)\"//g;
    $attr =~ s/URL\s*=\s*\"([^\"]*)\"//g;
    $attr =~ s/TARGET\s*=\s*\"([^\"]*)\"//g;
    $attr =~ s/TEXT\s*=\s*\"([^\"]*)\"//g;
    $attr =~ s/(\S+)\s*=\s*\"([^\"]*)\"/this.T_$1=\'$2\';/g;
   
    $attr =~ s/=\'(\d+)\'/=$1/g; # For decimal values, remove quotes

    if ( $TextInclude )
    {
     TWiki::Func::writeDebug( "topic : $TextInclude");
     $theText="Invalid topic name <b>$TextInclude</b> !";
     my( $iweb, $itopic ) = split('\.', $TextInclude);
     if ( ! $itopic ) { $itopic=$iweb; $iweb=$web; }
     if( TWiki::Func::topicExists( $iweb, $itopic ) ) 
     {
        my ( $meta, $text ) = &TWiki::Func::readTopic( $iweb, $itopic );
        $text =~ s/.*?%STARTINCLUDE%//os;
        $text =~ s/%STOPINCLUDE%.*//os;
        $theText = &TWiki::Func::expandCommonVariables($text, $itopic, $iweb);
        $theText = &TWiki::Func::renderText( $theText );
        $theText =~ s/\'//g;
        $theText =~ s/\"//g;
        $theText =~ s/\n//g;
     } 
    }

    $out = "<a border=\"0\" href=\"$theURL\" ";
    if ( $theTARGET ) 
    { 
      $out.="target=\"$theTARGET\""; 
    }
    $out.= " onmouseover=\"$attr;return escape('$theText')\">";

    $ToolTipID+=1;
    $ToolTipOpened+=1;
  }
  return ("$out");
}


1;
