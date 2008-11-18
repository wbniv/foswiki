# Plugin for Foswiki - The Free Open Source Wiki, http://foswiki.org/
#
# Copyright (c) 2007 Michael Daum, daum@wikiring.de
# Copyright (c) 2008 StéphaneLenclud, twiki@lenclud.com
# 
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
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
# For licensing info read LICENSE file in the TWiki root.

package TWiki::Plugins::JQueryDevPlugin;
use strict;
use vars qw( 
  $VERSION $RELEASE $SHORTDESCRIPTION 
  $NO_PREFS_IN_TOPIC
  $doneInit $doneHeader $pluginName
);

$VERSION = '$Rev: 15942 (22 Jan 2008) $';
$RELEASE = 'v0.5'; 
$SHORTDESCRIPTION = 'Enable jquery 1.2.3 and jquery.ui-1.5b for TWiki';
$NO_PREFS_IN_TOPIC = 1;


# Name of this Plugin, only used in this module
$pluginName = 'JQueryDevPlugin';


###############################################################################

sub initPlugin
	{
  	my( $topic, $web, $user, $installWeb ) = @_;

  	$doneInit = 0;
  	$doneHeader = 0;
  	
  	TWiki::Func::registerTagHandler('JQSCRIPT', \&includeJQueryScript );
  	TWiki::Func::registerTagHandler('JQTHEME', \&includeJQueryTheme );
    TWiki::Func::registerTagHandler('JQIMAGESURLPATH', \&handleJQueryImagesUrlPath );
  	#TWiki::Func::registerTagHandler('CLEAR', \&handleClear );
  	
  	return 1;
	}

###############################################################################

=pod

---++ commonTagsHandler($text, $topic, $web, $included, $meta )
   * =$text= - text to be processed
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$included= - Boolean flag indicating whether the handler is invoked on an included topic
   * =$meta= - meta-data object for the topic MAY BE =undef=
This handler is called by the code that expands %<nop>TAGS% syntax in
the topic body and in form fields. It may be called many times while
a topic is being rendered.

For variables with trivial syntax it is far more efficient to use
=TWiki::Func::registerTagHandler= (see =initPlugin=).

Plugins that have to parse the entire topic content should implement
this function. Internal TWiki
variables (and any variables declared using =TWiki::Func::registerTagHandler=)
are expanded _before_, and then again _after_, this function is called
to ensure all %<nop>TAGS% are expanded.

__NOTE:__ when this handler is called, &lt;verbatim> blocks have been
removed from the text (though all other blocks such as &lt;pre> and
&lt;noautolink> are still present).

__NOTE:__ meta-data is _not_ embedded in the text passed to this
handler. Use the =$meta= object.

*Since:* $TWiki::Plugins::VERSION 1.000

=cut


sub DISABLED_commonTagsHandler
	{
  	return if $doneHeader;

	#<link rel="stylesheet" href="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/jquery-all.css" type="text/css" media="all" />  
  
	#including several themes on one page seems to break the dialogues
	#<link rel="stylesheet" href="%PUBURLPATH%/%SYSTEMWEB%/JQueryDevPlugin/themes/flora/flora.all.css" type="text/css" media="screen" title="Flora (Default)" />  	
	
	#<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryDevPlugin/jquery.debug.js"></script>
	
  	my $header = <<'HERE';
HERE

  	$doneHeader = 1 if ($_[0] =~ s/<head>(.*?[\r\n]+)/<head>$1$header\n/o);
	}
	

=pod
<link rel="stylesheet" href="%PUBURLPATH%/%SYSTEMWEB%/JQueryDevPlugin/themes/ogray/ogray.all.css" type="text/css" media="screen" title="Ogray" />  	
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryDevPlugin/jquery.js"></script>
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryDevPlugin/jquery.dimensions.js"></script>
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryDevPlugin/ui.dialog.js"></script>
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryDevPlugin/ui.mouse.js"></script>
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryDevPlugin/ui.resizable.js"></script>
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryDevPlugin/ui.draggable.js"></script>
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryDevPlugin/ui.draggable.ext.js"></script>
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryDevPlugin/ui.accordion.js"></script>
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryDevPlugin/ui.droppable.js"></script>
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryDevPlugin/ui.droppable.ext.js"></script>
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryDevPlugin/ui.selectable.js"></script>
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryDevPlugin/ui.slider.js"></script>
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryDevPlugin/ui.sortable.js"></script>
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryDevPlugin/ui.sortable.ext.js"></script>
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryDevPlugin/ui.tabs.js"></script>
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryDevPlugin/ui.tabs.ext.js"></script>
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryDevPlugin/jquery.spinner.js"></script>
=cut

	
#######################################

sub includeJQueryScript
	{
    my($session, $params, $theTopic, $theWeb) = @_;   
    my $scriptFileName=$params->{_DEFAULT};

    return "<script type=\"text/javascript\" src=\"%PUBURLPATH%/%SYSTEMWEB%/$pluginName/$scriptFileName\"></script>";
	}

#######################################

sub includeJQueryTheme
    {
    my($session, $params, $theTopic, $theWeb) = @_;   
    my $themeName=$params->{_DEFAULT};

    return "<link rel=\"stylesheet\" href=\"%PUBURLPATH%/%SYSTEMWEB%/$pluginName/themes/$themeName/$themeName.all.css\" type=\"text/css\" media=\"screen\" title=\"$themeName\" />";

    }

#######################################

sub handleJQueryImagesUrlPath
    {
    my($session, $params, $theTopic, $theWeb) = @_;   
    my $image=$params->{_DEFAULT};
    if (defined $image)
        {
        return "%PUBURLPATH%/%SYSTEMWEB%/$pluginName/i/$image";
        }
    else
        {
        return "%PUBURLPATH%/%SYSTEMWEB%/$pluginName/i";
        }
    }



	
	
1;
