###############################################################################
# NatSkinPlugin.pm - Plugin handler for the NatSkin.
# 
# Copyright (C) 2003-2008 MichaelDaum http://michaeldaumconsulting.com
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
###############################################################################

package TWiki::Plugins::NatSkinPlugin;
use strict;
use TWiki::Func;
use constant DEBUG => 0; # toggle me

###############################################################################
use vars qw(
        $baseWeb $baseTopic $currentWeb $currentTopic 
	$currentUser $VERSION $RELEASE $homeTopic
	$useEmailObfuscator $detectExternalLinks
	$query %seenWebComponent
	$defaultSkin $defaultVariation $defaultStyleSearchBox
	$defaultStyle $defaultStyleBorder $defaultStyleSideBar
	$defaultStyleButtons 
	%maxRevs
	$doneInitKnownStyles $doneInitSkinState
	$lastStylePath
	%knownStyles 
	%knownVariations 
	%knownBorders 
	%knownThins 
	%knownButtons 
	%skinState 
	%emailCollection $nrEmails $doneHeader
	$STARTWW $ENDWW
	$NO_PREFS_IN_TOPIC $SHORTDESCRIPTION
    );


# from Render.pm
$STARTWW = qr/^|(?<=[\s\(])/m;
$ENDWW = qr/$|(?=[\s\,\.\;\:\!\?\)])/m;

$VERSION = '$Rev$';
$RELEASE = '3.00-pre20';
$NO_PREFS_IN_TOPIC = 1;
$SHORTDESCRIPTION = 'Theming engine for NatSkin';

# TODO generalize and reduce the ammount of variables 
$defaultSkin    = 'nat';
$defaultStyle   = 'Clean';
$defaultStyleBorder = 'off';
$defaultStyleButtons = 'off';
$defaultStyleSideBar = 'left';
$defaultVariation = 'off';
$defaultStyleSearchBox = 'top';


###############################################################################
sub writeDebug {
  print STDERR "- NatSkinPlugin - " . $_[0] . "\n" if DEBUG;
}


###############################################################################
sub initPlugin {
  ($baseTopic, $baseWeb, $currentUser) = @_;

  # register tags
  TWiki::Func::registerTagHandler('SETSKINSTATE', \&renderSetSkinState);
  TWiki::Func::registerTagHandler('GETSKINSTATE', \&renderGetSkinState);
  TWiki::Func::registerTagHandler('GETSKINSTYLE', \&renderGetSkinStyle);
  TWiki::Func::registerTagHandler('WEBLINK', \&renderWebLink);
  TWiki::Func::registerTagHandler('USERACTIONS', \&renderUserActions);
  TWiki::Func::registerTagHandler('FORMBUTTON', \&renderFormButton);
  TWiki::Func::registerTagHandler('NATWEBLOGO', \&renderNatWebLogo);
  TWiki::Func::registerTagHandler('KNOWNSTYLES', \&renderKnownStyles);
  TWiki::Func::registerTagHandler('KNOWNVARIATIONS', \&renderKnownVariations);
  TWiki::Func::registerTagHandler('WEBCOMPONENT', \&renderWebComponent);
  TWiki::Func::registerTagHandler('IFSKINSTATE', \&renderIfSkinState);
  TWiki::Func::registerTagHandler('TWIKIREGISTRATION', \&renderTWikiRegistration);
  TWiki::Func::registerTagHandler('HTMLTITLE', \&renderHtmlTitle);

  # a more flexible variant
  TWiki::Func::registerTagHandler('NATFORMLIST', \&renderFormList);

  # REVISIONS, MAXREV, CURREV only worked properly for the PatternSkin :/
  TWiki::Func::registerTagHandler('NATREVISIONS', \&renderRevisions);
  TWiki::Func::registerTagHandler('PREVREV', \&renderPrevRevision);
  TWiki::Func::registerTagHandler('CURREV', \&renderCurRevision);
  TWiki::Func::registerTagHandler('NATMAXREV', \&renderMaxRevision);

  # preference values
  $detectExternalLinks = TWiki::Func::getPreferencesFlag('EXTERNALLINKS');
  $useEmailObfuscator = TWiki::Func::getPreferencesFlag('OBFUSCATEEMAIL');

  $doneHeader = 0;
  $doneInitSkinState = 0;

  # don't initialize the following two to keep them in memory using perl accelerators
  #$doneInitKnownStyles = 0;
  #$lastStylePath = '';

  %emailCollection = (); # collected email addrs
  $nrEmails = 0; # number of collected addrs
  %maxRevs = (); # cache for getMaxRevision()
  %seenWebComponent = (); # used to prevent deep recursion
  $query = TWiki::Func::getCgiQuery();

  # get name of hometopic
  $homeTopic = TWiki::Func::getPreferencesValue('HOMETOPIC') 
    || $TWiki::cfg{HomeTopicName} || 'WebHome';

  # get skin state from session
  initKnownStyles();
  initSkinState();

  if ($useEmailObfuscator) {
    my $isScripted = TWiki::Func::getContext()->{'command_line'}?1:0;
    if ($isScripted || !$query) { # are we in cgi mode?
      $useEmailObfuscator = 0; # batch mode, i.e. mailnotification
      #writeDebug("no email obfuscation: batch mode");
    } else {
      # disable during register context
      my $theContentType = $query->param('contenttype');
      my $skin = TWiki::Func::getSkin();
      if ($skinState{'action'} =~ /^(register|mailnotif|resetpasswd)/ || 
	  $skin =~ /^rss/ ||
	  $theContentType) {
	$useEmailObfuscator = 0;
      }
    }
  }
  #writeDebug("useEmailObfuscator=$useEmailObfuscator");

  writeDebug("done doInit");
  return 1;
}

###############################################################################
# commonTagsHandler:
# $_[0] - The text
# $_[1] - The topic
# $_[2] - The web
sub commonTagsHandler {
  $currentTopic = $_[1];
  $currentWeb = $_[2];

  # conditional content
  while ($_[0] =~ s/(\s*)%IFSKINSTATETHEN{(?!.*%IFSKINSTATETHEN)(.*?)}%\s*(.*?)\s*%FISKINSTATE%(\s*)/renderIfSkinStateThen($2, $3, $1, $4)/geos) {
    # nop
  }

  # spam obfuscator
  if ($useEmailObfuscator) {
    $_[0] =~ s/\[\[mailto\:([a-zA-Z0-9\-\_\.\+]+\@[a-zA-Z0-9\-\_\.]+\..+?)(?:\s+|\]\[)(.*?)\]\]/obfuscateEmailAddrs([$1], $2)/ge;
    $_[0] =~ s/$STARTWW(?:mailto\:)?([a-zA-Z0-9\-\_\.\+]+\@[a-zA-Z0-9\-\_\.]+\.[a-zA-Z0-9\-\_]+)$ENDWW/obfuscateEmailAddrs([$1])/ge;
  }
}

###############################################################################
sub postRenderingHandler { 
  
  # detect external links
  if ($detectExternalLinks) {
    $_[0] =~ s/<a\s+([^>]*?href=(?:\"|\'|&quot;)?)([^\"\'\s>]+(?:\"|\'|\s|&quot;>)?)/'<a '.renderExternalLink($1,$2)/geoi;
    $_[0] =~ s/(<a\s+[^>]+ target="_blank" [^>]+) target="_top"/$1/go; # twiki4 adds target="_top" ... we kick it out again
  }

  # render email obfuscator
  if ($useEmailObfuscator && $nrEmails) {
    $useEmailObfuscator = 0;
    TWiki::Func::addToHEAD('EMAIL_OBFUSCATOR', renderEmailObfuscator());
    $useEmailObfuscator = 1;
  }
}

###############################################################################
# known styles are attachments found along the STYLEPATH. any *Style.css,
# *Variation.css etc files are collected hashed.
sub initKnownStyles {

  #writeDebug("called initKnownStyles");
  #writeDebug("stylePath=$stylePath, lastStylePath=$lastStylePath");

  my $twikiWeb = TWiki::Func::getTwikiWebname();
  my $stylePath = TWiki::Func::getPreferencesValue('STYLEPATH') 
    || "$twikiWeb.NatSkin";

  $stylePath =~ s/\%(SYSTEM|TWIKI)WEB\%/$twikiWeb/go;

  $lastStylePath ||= '';

  # return cached known styles if we have the same stylePath
  # as last time
  return if $doneInitKnownStyles && $stylePath eq $lastStylePath;

  $doneInitKnownStyles = 1;
  $lastStylePath = $stylePath;
  %knownStyles = ();
  %knownVariations = ();
  %knownBorders = ();
  %knownButtons = ();
  %knownThins = ();
  
  my $pubDir = TWiki::Func::getPubDir();
  foreach my $styleWebTopic (split(/[\s,]+/, $stylePath)) {
    my $styleWeb;
    my $styleTopic;
    if ($styleWebTopic =~ /^(.*)\.(.*?)$/) {
      $styleWeb = $1;
      $styleWeb =~ s/\./\//go;
      $styleTopic = $2;
    } else {
      next;
    }
    my $styleWebTopic = $styleWeb.'/'.$styleTopic;
    my $cssDir = $pubDir.'/'.$styleWebTopic;

    if (opendir(DIR, $cssDir))  {
      foreach my $fileName (readdir(DIR)) {
	if ($fileName =~ /((.*)Style\.css)$/) {
	  $knownStyles{$2} = $styleWebTopic.'/'.$1 unless $knownStyles{$2};
	} elsif ($fileName =~ /((.*)Variation\.css)$/) {
	  $knownVariations{$2} = $styleWebTopic.'/'.$1 unless $knownVariations{$2};
	} elsif ($fileName =~ /((.*)Border\.css)$/) {
	  $knownBorders{$2} = $styleWebTopic.'/'.$1 unless $knownBorders{$2};
	} elsif ($fileName =~ /((.*)Buttons\.css)$/) {
	  $knownButtons{$2} = $styleWebTopic.'/'.$1 unless $knownButtons{$2};
	} elsif ($fileName =~ /((.*)Thin\.css)$/) {
	  $knownThins{$2} = $styleWebTopic.'/'.$1 unless $knownThins{$1};
	}
      }
      closedir(DIR);
    }
  }
}

###############################################################################
sub initSkinState {

  return 1 if $doneInitSkinState;

  $doneInitSkinState = 1;
  %skinState = ();

  #writeDebug("called initSkinState");

  my $theStyle;
  my $theStyleBorder;
  my $theStyleButtons;
  my $theStyleSideBar;
  my $theStyleVariation;
  my $theStyleSearchBox;
  my $theToggleSideBar;
  my $theRaw;
  my $theSwitchStyle;
  my $theSwitchVariation;

  my $doStickyStyle = 0;
  my $doStickyBorder = 0;
  my $doStickyButtons = 0;
  my $doStickySideBar = 0;
  my $doStickySearchBox = 0;
  my $doStickyVariation = 0;
  my $found = 0;

  # get finalisations
  
  # SMELL: we only get the WebPreferences' FINALPREFERENCES here
  my $finalPreferences = TWiki::Func::getPreferencesValue("FINALPREFERENCES") || '';
  my $isFinalStyle = 0;
  my $isFinalBorder = 0;
  my $isFinalButtons = 0;
  my $isFinalSideBar = 0;
  my $isFinalVariation = 0;
  my $isFinalSearchBox = 0;
  if ($finalPreferences) {
    my @finalPreferences = split(/[\s,]+/, $finalPreferences);
    $skinState{final} = ();
    push @{$skinState{final}}, 'style' if 
      ($isFinalStyle = grep(/^SKINSTYLE$/, @finalPreferences));
    push @{$skinState{final}}, 'border' if 
      ($isFinalBorder = grep(/^STYLEBORDER$/, @finalPreferences));
    push @{$skinState{final}}, 'buttons' if 
      ($isFinalButtons = grep(/^STYLEBUTTONS$/, @finalPreferences));
    push @{$skinState{final}}, 'sidebar' if 
      ($isFinalSideBar = grep(/^STYLESIDEBAR$/, @finalPreferences));
    push @{$skinState{final}}, 'variation' if 
      ($isFinalVariation = grep(/^STYLEVARIATION$/, @finalPreferences));
    push @{$skinState{final}}, 'searchbox' if 
      ($isFinalSearchBox = grep(/^STYLESEARCHBOX$/, @finalPreferences));
    push @{$skinState{final}}, 'switches' if 
      $isFinalBorder && $isFinalSideBar && $isFinalButtons && $isFinalSearchBox;
    push @{$skinState{final}}, 'all' if 
      $isFinalStyle && $isFinalVariation && $isFinalBorder && $isFinalSideBar &&
      $isFinalButtons && $isFinalSearchBox;
  }

  # from query
  if ($query) {
    $theRaw = $query->param('raw');
    $theSwitchStyle = $query->param('switchstyle');
    $theSwitchVariation = $query->param('switchvariation');
    $theStyle = $query->param('style') || $query->param('skinstyle') || '';

    my $theReset = $query->param('resetstyle') || ''; # get back to site defaults
    my $theRefresh = $query->param('refresh') || ''; # refresh internal caches
    $theRefresh = ($theRefresh eq 'on')?1:0;
    $theReset = ($theReset eq 'on')?1:0;

    writeDebug("theReset=$theReset, theRefresh=$theRefresh");

    if ($theRefresh || $theReset || $theStyle eq 'reset') {
      # clear the style cache
      $doneInitKnownStyles = 0; 
      $lastStylePath = '';
    }

    if ($theReset || $theStyle eq 'reset') {
      writeDebug("clearing session values");
      
      $theStyle = '';
      TWiki::Func::clearSessionValue('SKINSTYLE');
      TWiki::Func::clearSessionValue('STYLEBORDER');
      TWiki::Func::clearSessionValue('STYLEBUTTONS');
      TWiki::Func::clearSessionValue('STYLESIDEBAR');
      TWiki::Func::clearSessionValue('STYLEVARIATION');
      TWiki::Func::clearSessionValue('STYLESEARCHBOX');
      my $redirectUrl = TWiki::Func::getViewUrl($baseWeb, $baseTopic);
      TWiki::Func::redirectCgiQuery($query, $redirectUrl); 
	# we need to force a new request because the session value preferences
	# are still loaded in the preferences cache; only clearing them in
	# the session object is not enough right now but will be during the next
	# request; so we redirect to the current url
      return 0;
    } else {
      $theStyleBorder = $query->param('styleborder'); 
      $theStyleButtons = $query->param('stylebuttons'); 
      $theStyleSideBar = $query->param('stylesidebar');
      $theStyleVariation = $query->param('stylevariation');
      $theStyleSearchBox = $query->param('stylesearchbox');
      $theToggleSideBar = $query->param('togglesidebar');
    }

    #writeDebug("urlparam style=$theStyle") if $theStyle;
    #writeDebug("urlparam styleborder=$theStyleBorder") if $theStyleBorder;
    #writeDebug("urlparam stylebuttons=$theStyleButtons") if $theStyleButtons;
    #writeDebug("urlparam stylesidebar=$theStyleSideBar") if $theStyleSideBar;
    #writeDebug("urlparam stylevariation=$theStyleVariation") if $theStyleVariation;
    #writeDebug("urlparam stylesearchbox=$theStyleSearchBox") if $theStyleSearchBox;
    #writeDebug("urlparam togglesidebar=$theToggleSideBar") if $theToggleSideBar;
    #writeDebug("urlparam switchvariation=$theSwitchVariation") if $theSwitchVariation;
  }

  # handle style
  my $prefStyle = TWiki::Func::getPreferencesValue('SKINSTYLE') || 
    $defaultStyle;
  $prefStyle =~ s/^\s*(.*)\s*$/$1/go;
  if ($theStyle && !$isFinalStyle) {
    $theStyle =~ s/^\s*(.*)\s*$/$1/go;
    $doStickyStyle = 1 if lc($theStyle) ne lc($prefStyle);
  } else {
    $theStyle = $prefStyle;
  }
  if ($theStyle =~ /^(off|none)$/o) {
    $theStyle = 'off';
  } else {
    $found = 0;
    foreach my $style (keys %knownStyles) {
      if ($style eq $theStyle || lc($style) eq lc($theStyle)) {
	$found = 1;
	$theStyle = $style;
	last;
      }
    }
    $theStyle = $defaultStyle unless $found;
  }
  $theStyle = $defaultStyle unless $knownStyles{$theStyle};
  $skinState{'style'} = $theStyle;
  #writeDebug("theStyle=$theStyle");

  # cycle styles
  if ($theSwitchStyle && !$isFinalStyle) {
    $theSwitchStyle = lc($theSwitchStyle);
    $doStickyStyle = 1;
    my $state = 0;
    my $firstStyle;
    my @knownStyles;
    if ($theSwitchStyle eq 'next') {
      @knownStyles = sort {$a cmp $b} keys %knownStyles #next
    } else {
      @knownStyles = sort {$b cmp $a} keys %knownStyles #prev
    }
    foreach my $style (@knownStyles) {
      $firstStyle = $style unless $firstStyle;
      if ($theStyle eq $style) {
	$state = 1;
	next;
      }
      if ($state == 1) {
	$skinState{'style'} = $style;
	$state = 2;
	last;
      }
    }
    $skinState{'style'} = $firstStyle if $state == 1;
  }

  # handle border
  my $prefStyleBorder = TWiki::Func::getPreferencesValue('STYLEBORDER') ||
    $defaultStyleBorder;

  $prefStyleBorder =~ s/^\s*(.*)\s*$/$1/go;
  if ($theStyleBorder && !$isFinalBorder) {
    $theStyleBorder =~ s/^\s*(.*)\s*$/$1/go;
    $doStickyBorder = 1 if $theStyleBorder ne $prefStyleBorder;
  } else {
    $theStyleBorder = $prefStyleBorder;
  }
  $theStyleBorder = $defaultStyleBorder 
    if $theStyleBorder !~ /^(on|off|thin)$/;
  $theStyleBorder = $defaultStyleBorder 
    if $theStyleBorder eq 'on' && !$knownBorders{$theStyle};
  $theStyleBorder = $defaultStyleBorder 
    if $theStyleBorder eq 'thin' && !$knownThins{$theStyle};
  $skinState{'border'} = $theStyleBorder;

  # handle buttons
  my $prefStyleButtons = TWiki::Func::getPreferencesValue('STYLEBUTTONS') ||
    $defaultStyleButtons;
  $prefStyleButtons =~ s/^\s*(.*)\s*$/$1/go;
  if ($theStyleButtons && !$isFinalButtons) {
    $theStyleButtons =~ s/^\s*(.*)\s*$/$1/go;
    $doStickyButtons = 1 if $theStyleButtons ne $prefStyleButtons;
  } else {
    $theStyleButtons = $prefStyleButtons;
  }
  $theStyleButtons = $defaultStyleButtons
    if $theStyleButtons !~ /^(on|off)$/;
  $theStyleButtons = $defaultStyleButtons
    if $theStyleButtons eq 'on' && !$knownButtons{$theStyle};
  $skinState{'buttons'} = $theStyleButtons;

  # handle sidebar 
  my $prefStyleSideBar = TWiki::Func::getPreferencesValue('STYLESIDEBAR') ||
    $defaultStyleSideBar;
  $prefStyleSideBar =~ s/^\s*(.*)\s*$/$1/go;
  if ($theStyleSideBar && !$isFinalSideBar) {
    $theStyleSideBar =~ s/^\s*(.*)\s*$/$1/go;
    $doStickySideBar = 1 if $theStyleSideBar ne $prefStyleSideBar;
  } else {
    $theStyleSideBar = $prefStyleSideBar;
  }
  $theStyleSideBar = $defaultStyleSideBar
    if $theStyleSideBar !~ /^(left|right|both|off)$/;
  $skinState{'sidebar'} = $theStyleSideBar;
  $theToggleSideBar = undef
    if $theToggleSideBar && $theToggleSideBar !~ /^(left|right|both|off)$/;

  # handle searchbox
  my $prefStyleSearchBox = TWiki::Func::getPreferencesValue('STYLESEARCHBOX') ||
    $defaultStyleSearchBox;
  $prefStyleSearchBox =~ s/^\s*(.*)\s*$/$1/go;
  if ($theStyleSearchBox && !$isFinalSearchBox) {
    $theStyleSearchBox =~ s/^\s*(.*)\s*$/$1/go;
    $doStickySearchBox = 1 if $theStyleSearchBox ne $prefStyleSearchBox;
  } else {
    $theStyleSearchBox = $prefStyleSearchBox;
  }
  $theStyleSearchBox = $defaultStyleSearchBox
    if $theStyleSearchBox !~ /^(top|pos1|pos2|pos3|off)$/;
  $skinState{'searchbox'} = $theStyleSearchBox;

  # handle variation 
  my $prefStyleVariation = TWiki::Func::getPreferencesValue('STYLEVARIATION') ||
    $defaultVariation;
  $prefStyleVariation =~ s/^\s*(.*)\s*$/$1/go;
  if ($theStyleVariation && !$isFinalVariation) {
    $theStyleVariation =~ s/^\s*(.*)\s*$/$1/go;
    $doStickyVariation = 1 if lc($theStyleVariation) ne lc($prefStyleVariation);
  } else {
    $theStyleVariation = $prefStyleVariation;
  }
  $found = 0;
  foreach my $variation (keys %knownVariations) {
    if ($variation eq $theStyleVariation || lc($variation) eq lc($theStyleVariation)) {
      $found = 1;
      $theStyleVariation = $variation;
      last;
    }
  }
  $theStyleVariation = $defaultVariation unless $found;
  $skinState{'variation'} = $theStyleVariation;

  # cycle styles
  if ($theSwitchVariation && !$isFinalVariation) {
    $theSwitchVariation = lc $theSwitchVariation;
    $doStickyVariation = 1;
    my $state = 0;
    my @knownVariations;
    if ($theSwitchVariation eq 'next') {
      @knownVariations = sort {$a cmp $b} keys %knownVariations #next
    } else {
      @knownVariations = sort {$b cmp $a} keys %knownVariations #prev
    }
    push @knownVariations, 'off';
    my $firstVari;
    foreach my $vari (@knownVariations) {
      $firstVari = $vari unless $firstVari;
      if ($theStyleVariation eq $vari) {
	$state = 1;
	next;
      }
      if ($state == 1) {
	$skinState{'variation'} = $vari;
	$state = 2;
	last;
      }
    }
    $skinState{'variation'} = $firstVari if $state == 1;
  }

  # store sticky state into session
  TWiki::Func::setSessionValue('SKINSTYLE', $skinState{'style'}) 
    if $doStickyStyle;
  TWiki::Func::setSessionValue('STYLEBORDER', $skinState{'border'})
    if $doStickyBorder;
  TWiki::Func::setSessionValue('STYLEBUTTONS', $skinState{'buttons'})
    if $doStickyButtons;
  TWiki::Func::setSessionValue('STYLESIDEBAR', $skinState{'sidebar'})
    if $doStickySideBar;
  TWiki::Func::setSessionValue('STYLEVARIATION', $skinState{'variation'})
    if $doStickyVariation;
  TWiki::Func::setSessionValue('STYLESEARCHBOX', $skinState{'searchbox'})
    if $doStickySearchBox;

  # misc
  $skinState{'action'} = getCgiAction();

  # temporary toggles
  $theToggleSideBar = 'off' if $theRaw && $skinState{'border'} eq 'thin';
  $theToggleSideBar = 'off' if $skinState{'action'} =~ 
    /^(edit|editsection|genpdf|manage|rdiff|changes|(.*search)|login|logon|oops)$/;

  # switch the sidebar off if we need to authenticate
  if ($skinState{'action'} ne 'publish' && # SMELL to please PublishContrib
      $TWiki::cfg{AuthScripts} =~ /\b$skinState{'action'}\b/ &&
      !TWiki::Func::getContext()->{authenticated}) {
      $theToggleSideBar = 'off';
  }

  $skinState{'sidebar'} = $theToggleSideBar 
    if $theToggleSideBar && $theToggleSideBar ne '';


  # set context
  my $context = TWiki::Func::getContext();
  foreach my $key (keys %skinState) {
    my $val = $skinState{$key};
    next unless defined($val);
    my $var = lc('natskin_'.$key.'_'.$val);
    writeDebug("setting context $var");
    $context->{$var} = 1;
  }


  # prepend style to template search path

  my $skin = $query->param('skin') || 
    TWiki::Func::getPreferencesValue( 'SKIN' ) || 'nat'; 
    # not using TWiki::Func::getSkin() to prevent 
    # getting the cover as well

  my $prefix = lc($skinState{style}).'.nat';
  $skin = "$prefix,$skin" unless $skin =~ /\b$prefix\b/;
  writeDebug("setting skin to $skin");

  # store to session and query
  $TWiki::Plugins::SESSION->{prefs}->pushPreferenceValues('SESSION', { SKIN => $skin } );      	
  $query->param('skin', $skin);
  
  return 1;
}

###############################################################################
sub renderIfSkinStateThen {
  my ($args, $text, $before, $after) = @_;

  $args ||= '';
  $before ||= '';
  $after ||= '';

  #writeDebug("called renderIfSkinStateThen($args)");


  my $theThen = $text; 
  my $theElse = '';
  my $elsIfArgs;

  if ($text =~ /^(.*?)\s*%ELSIFSKINSTATE{(.*?)}%\s*(.*)\s*$/gos) {
    $theThen = $1;
    $elsIfArgs = $2;
    $theElse = $3;
  } elsif ($text =~ /^(.*?)\s*%ELSESKINSTATE%\s*(.*)\s*$/gos) {
    $theThen = $1;
    $theElse = $2;
  }

  my %params = TWiki::Func::extractParameters($args);

  my $theStyle = $params{_DEFAULT} || $params{style};
  my $theBorder = $params{border};
  my $theButtons = $params{buttons};
  my $theSideBar = $params{sidebar};
  my $theSearchBox = $params{searchbox};
  my $theVariation = $params{variation};
  my $theAction = $params{action};
  my $theGlue = $params{glue} || 'on';
  my $theFinal = $params{final};

  if ($theGlue eq 'on') {
    $before = '';
    $after = '';
  }
  
  # SMELL get a ifSkinStateTImpl
  if ((!$theStyle || $skinState{'style'} =~ /$theStyle/) &&
      (!$theBorder || $skinState{'border'} =~ /$theBorder/) &&
      (!$theButtons || $skinState{'buttons'} =~ /$theButtons/) &&
      (!$theSideBar || $skinState{'sidebar'} =~ /$theSideBar/) &&
      (!$theSearchBox || $skinState{'searchbox'} =~ /$theSearchBox/) &&
      (!$theVariation || $skinState{'variation'} =~ /$theVariation/) &&
      (!$theAction || $skinState{'action'} =~ /$theAction/) &&
      (!$theFinal || grep(/$theFinal/, @{$skinState{'final'}}))) {
    #writeDebug("match then");
    if ($theThen =~ s/\$nop//go) {
#      $theThen = TWiki::Func::expandCommonVariables($theThen, $currentTopic, $currentWeb);
    }
    return $before.$theThen.$after if $theThen;
  } else {
    if ($elsIfArgs) {
      #writeDebug("match elsif");
      return $before."%IFSKINSTATETHEN{$elsIfArgs}%$theElse%FISKINSTATE%".$after;
    } else {
      #writeDebug("match else");
      if ($theElse =~ s/\$nop//go) {
#	$theElse = TWiki::Func::expandCommonVariables($theElse, $currentTopic, $currentWeb);
      }
      return $before.$theElse.$after if $theElse;
    }
  }

  #writeDebug("NO match");
  return $before.$after;
  
}

###############################################################################
sub renderTWikiRegistration {
  my $twikiWeb = TWiki::Func::getTwikiWebname();

  my $twikiRegistrationTopic = 
    TWiki::Func::getPreferencesValue('TWIKIREGISTRATION');
  $twikiRegistrationTopic = "$twikiWeb.TWikiRegistration" 
    unless defined $twikiRegistrationTopic;
  
  return $twikiRegistrationTopic;
}

###############################################################################
sub renderHtmlTitle {
  my ($session, $params, $theTopic, $theWeb) = @_;

  my $theSep = $params->{separator} || ' - ';
  my $theWikiToolName = $params->{wikitoolname} || 'on';
  my $theSource = $params->{source} || '%TOPICTITLE%';

  if ($theWikiToolName eq 'on') {
    $theWikiToolName = TWiki::Func::getPreferencesValue("WIKITOOLNAME") || 'TWiki';
    $theWikiToolName = $theSep.$theWikiToolName;
  } elsif ($theWikiToolName eq 'off') {
    $theWikiToolName = '';
  } else {
    $theWikiToolName = $theSep.$theWikiToolName;
  }

  my $htmlTitle = TWiki::Func::getPreferencesValue("HTMLTITLE");
  if ($htmlTitle) {
    return $htmlTitle; # deliberately not appending the WikiToolName
  }

  $theWeb =~ s/^.*[\.\/]//g;

  # the source can be a preference variable or a TWikiTag
  escapeParameter($theSource);
  $htmlTitle = TWiki::Func::expandCommonVariables($theSource, $theTopic, $theWeb);
  if ($htmlTitle && $htmlTitle ne $theSource) {
    return $htmlTitle.$theSep.$theWeb.$theWikiToolName;
  }

  # fallback
  return $theTopic.$theSep.$theWeb.$theWikiToolName;
}


###############################################################################
sub renderIfSkinState {
  my ($session, $params) = @_;

  my $theStyle = $params->{_DEFAULT} || $params->{style};
  my $theThen = $params->{then};
  my $theElse = $params->{else};
  my $theBorder = $params->{border};
  my $theButtons = $params->{buttons};
  my $theVariation = $params->{variation};
  my $theSideBar = $params->{sidebar};
  my $theSearchBox = $params->{searchbox};
  my $theAction = $params->{action};
  my $theFinal = $params->{final};

  # SMELL do a ifSkinStateImpl
  if ((!$theStyle || $skinState{'style'} =~ /$theStyle/i) &&
      (!$theVariation || $skinState{'variation'} =~ /$theVariation/i) &&
      (!$theBorder || $skinState{'border'} =~ /$theBorder/) &&
      (!$theButtons || $skinState{'buttons'} =~ /$theButtons/) &&
      (!$theSideBar || $skinState{'sidebar'} =~ /$theSideBar/) &&
      (!$theSearchBox || $skinState{'searchbox'} =~ /$theSearchBox/) &&
      (!$theAction || $skinState{'action'} =~ /$theAction/) &&
      (!$theFinal || grep(/$theFinal/, @{$skinState{'final'}}))) {

    escapeParameter($theThen);
    if ($theThen) {
      $theThen = TWiki::Func::expandCommonVariables($theThen, $baseTopic, $baseWeb);
      #writeDebug("match");
      return $theThen;
    }
  } else {
    escapeParameter($theElse);
    if ($theElse) {
      $theElse = TWiki::Func::expandCommonVariables($theElse, $baseTopic, $baseWeb);
      #writeDebug("NO match");
      return $theElse;
    }
  }

  return '';
}

###############################################################################
sub renderKnownStyles {
  return join(', ', sort {$a cmp $b} keys %knownStyles);
}

###############################################################################
sub renderKnownVariations {
  return join(', ', sort {$a cmp $b} keys %knownVariations);
}

###############################################################################
# TODO: prevent illegal skin states
sub renderSetSkinState {
  my ($session, $params) = @_;

  $skinState{'buttons'} = $params->{buttons} if $params->{buttons};
  $skinState{'sidebar'} = $params->{sidebar} if $params->{sidebar};
  $skinState{'variation'} = $params->{variation} if $params->{variation};
  $skinState{'style'} = $params->{style} if $params->{style};
  $skinState{'searchbox'} = $params->{searchbox} if $params->{searchbox};
  $skinState{'border'} = $params->{border} if $params->{border};

  return '';
}

###############################################################################
sub renderGetSkinState {

  my ($session, $params) = @_;

  my $theFormat = $params->{_DEFAULT} || 
    '$style, $variation, $sidebar, $border, $buttons, $searchbox';
  my $theLowerCase = $params->{lowercase} || 0;
  $theLowerCase = ($theLowerCase eq 'on')?1:0;

  $theFormat =~ s/\$style/$skinState{'style'}/g;
  $theFormat =~ s/\$variation/$skinState{'variation'}/g;
  $theFormat =~ s/\$border/$skinState{'border'}/g;
  $theFormat =~ s/\$buttons/$skinState{'buttons'}/g;
  $theFormat =~ s/\$searchbox/$skinState{'searchbox'}/g;
  $theFormat =~ s/\$sidebar/$skinState{'sidebar'}/g;
  $theFormat = lc($theFormat);

  return $theFormat;
}

###############################################################################
sub renderGetSkinStyle {

  my $theStyle;
  my $theVariation;
  $theStyle = $skinState{'style'} || 'off';
  return '' if $theStyle eq 'off';

  $theVariation = $skinState{'variation'} unless $skinState{'variation'} =~ /^(off|none)$/;

  # SMELL: why not use <link rel="stylesheet" href="..." type="text/css" media="all" />
  my $text = '';

  # SMELL: check if a knownStyle has been used

  $text = 
    '<link rel="stylesheet" href="%PUBURL%/'.
    $knownStyles{$theStyle}.'"  type="text/css" media="all" />'."\n";

  if ($skinState{'border'} eq 'on') {
    $text .= 
      '<link rel="stylesheet" href="%PUBURL%/'.
      $knownBorders{$theStyle}.'"  type="text/css" media="all" />'."\n";
  } elsif ($skinState{'border'} eq 'thin') {
    $text .= 
      '<link rel="stylesheet" href="%PUBURL%/'.
      $knownThins{$theStyle}.'"  type="text/css" media="all" />'."\n";
  }

  if ($skinState{'buttons'} eq 'on') {
    $text .=
      '<link rel="stylesheet" href="%PUBURL%/'.
      $knownButtons{$theStyle}.'" type="text/css" media="all" />'."\n";
  }

  $text .=
    '<link rel="stylesheet" href="%PUBURL%/'.
    $knownVariations{$theVariation}.'" type="text/css" media="all" />'."\n" if $theVariation;

  return $text;
}


###############################################################################
# renderUserActions: render the USERACTIONS variable:
# display advanced topic actions for non-guests
sub renderUserActions {
  my ($session, $params) = @_;

  my $text = '';
  my $sepString = $params->{sep} || $params->{separator} || '<span class="natSep"> | </span>';
  if (TWiki::Func::getContext()->{authenticated}) {
    $text = $params->{_DEFAULT} || $params->{format};
    $text = 
      '$user$sep$help$sep$logout$sep$print<br />'.
      '$edit$sep$attach$sep$move$sep$raw$sep$diff$sep$more'
      unless defined $text;
  } else {
    $text = $params->{guest};
    $text = '$login$sep$register$sep$print' unless defined $text;
    return '' unless $text;
  }

  my $editString = '';
  my $attachString = '';
  my $moveString = '';
  my $rawString = '';
  my $diffString = '';
  my $moreString = '';
  my $printString = '';
  my $pdfString = '';
  my $loginString = '';
  my $logoutString = '';
  my $registerString = '';
  my $userString = '';
  my $helpString = '';

  my $restrictedActions = $params->{restrictedactions};
  $restrictedActions = 'edit, attach, move' unless defined $restrictedActions;
  my %isRestrictedAction = map {$_ => 1} split(/\s*,\s*/, $restrictedActions);
  #writeDebug("restrictedActions=".join(',', sort keys %restrictedActions));
  my $gotAccess = TWiki::Func::checkAccessPermission('CHANGE',$currentUser,undef,$baseTopic, $baseWeb);
  %isRestrictedAction = () if $gotAccess;

  # get change strings (edit, attach, move)
  my $curRev = '';
  my $theRaw;
  if ($query) {
    $curRev = $query->param('rev') || '';
    $theRaw = $query->param('raw');
  }
  $curRev =~ s/r?1\.//go;
  my $maxRev = getMaxRevision();
  if ($curRev && $curRev < $maxRev) {
    $isRestrictedAction{'edit'} = 1;
    $isRestrictedAction{'attach'} = 1;
    $isRestrictedAction{'move'} = 1;
  }

    
  # edit
  if ($isRestrictedAction{'edit'}) {
    $editString = '<span class="natDisabledTopicAction">%TMPL:P{"EDIT"}%</span>';
  } else {
    my $whiteBoard = TWiki::Func::getPreferencesValue('WHITEBOARD');
    $whiteBoard = TWiki::isTrue($whiteBoard, 1); # too bad getPreferencesFlag does not have a default param
    my $editUrlParams = '';
    $editUrlParams = '&action=form' unless $whiteBoard;
    $editString = 
      '<a class="natEditTopicAction" rel="nofollow" href="'
      . TWiki::Func::getScriptUrl($baseWeb, $baseTopic, "edit") 
      . '?t=' . time() 
      . $editUrlParams
      . '" accesskey="e" title="%TMPL:P{"EDIT_HELP"}%"><span>%TMPL:P{"EDIT"}%</span></a>';
  }


  # attach
  if ($isRestrictedAction{'attach'}) {
    $attachString = '<span class="natDisabledTopicAction">%TMPL:P{"ATTACH"}%</span>';
  } else {
    $attachString =
      '<a class="natAttachTopicAction" rel="nofollow" href="'
      . TWiki::Func::getScriptUrl($baseWeb, $baseTopic, "attach") 
      . '" accesskey="a" title="%TMPL:P{"ATTACH_HELP"}%"><span>%TMPL:P{"ATTACH"}%</span></a>';
  }

  # move/rename
  if ($isRestrictedAction{'move'}) {
    $moveString = '<span class="natDisabledTopicAction">%TMPL:P{"MOVE"}%</span>';
  } else {
    $moveString =
      '<a class="natMoveTopicAction" rel="nofollow" href="'
      . TWiki::Func::getScriptUrl($baseWeb, $baseTopic, "rename", 'currentwebonly'=>'on')
      . '" accesskey="m" title="%TMPL:P{"MOVE_HELP"}%"><span>%TMPL:P{"MOVE"}%</span></a>';

  }

  # raw
  if ($isRestrictedAction{'raw'}) {
    if ($theRaw) {
      $rawString = '<span class="natDisabledTopicAction">%TMPL:P{"VIEW"}%</span>';
    } else {
      $rawString = '<span class="natDisabledTopicAction">%TMPL:P{"RAW"}%</span>';
    }
  } else {
    my $rev = getCurRevision($baseWeb, $baseTopic, $curRev);
    if ($theRaw) {
      $rawString =
        '<a class="natViewTopicAction" href="' . 
        TWiki::Func::getScriptUrl($baseWeb, $baseTopic, "view") . 
        '?rev='.$rev.'" accesskey="r" title="%TMPL:P{"VIEW_HELP"}%"><span>%TMPL:P{"VIEW"}%</span></a>';
    } else {
      $rawString =
        '<a class="natRawTopicAction" href="' .  
        TWiki::Func::getScriptUrl($baseWeb, $baseTopic, "view") .  
        '?raw=on&rev='.$rev.'" accesskey="r" title="%TMPL:P{"RAW_HELP"}%"><span>%TMPL:P{"RAW"}%</span></a>';
    }
  }
  
  # diff
  if ($isRestrictedAction{'diff'}) {
    $diffString = '<span class="natDisabledTopicAction">%TMPL:P{"DIFF"}%</span>';
  } else {
    my $diffUrl = getDiffUrl($session);
    $diffString =
        '<a class="natDiffTopicAction" rel="nofollow" href="' . 
        $diffUrl.
        '" accesskey="d" title="'.
        '%TMPL:P{"DIFF_HELP"}%"><span>%TMPL:P{"DIFF"}%</span></a>';
  }

  # more
  if ($isRestrictedAction{'more'}) {
    $moreString = '<span class="natDisabledTopicAction">%TMPL:P{"MORE"}%</span>';
  } else {
    $moreString =
        '<a class="natMoreTopicAction" rel="nofollow" href="' . 
        TWiki::Func::getScriptUrl($baseWeb, $baseTopic, "oops") . 
        '?template=oopsmore" accesskey="x" title="'.
        '%TMPL:P{"MORE_HELP"}%"><span>%TMPL:P{"MORE"}%</span></a>';
  }

  # print
  if ($isRestrictedAction{'print'}) {
    $printString = '<span class="natDisabledTopicAction">%TMPL:P{"PRINT"}%</span>';
  } else {
    $printString =
      '<a class="natPrintTopicAction" rel="nofollow" href="'.
      TWiki::Func::getScriptUrl($baseWeb, $baseTopic, 'view').
      '?cover=print.nat" accesskey="p" title="%TMPL:P{"PRINT_HELP"}%"><span>%TMPL:P{"PRINT"}%</span></a>';
  }

  # pdf
  if ($isRestrictedAction{'pdf'}) {
    $pdfString = '<span class="natDisabledTopicAction">%TMPL:P{"PDF"}%</span>';
  } else {
    $pdfString =
      '<a class="natPdfTopicAction" rel="nofollow" href="'.
      TWiki::Func::getScriptUrl($baseWeb, $baseTopic, 'genpdf').
      '?cover=print.nat&pdfstruct=webpage" accesskey="p" title="%TMPL:P{"PDF_HELP"}%"><span>%TMPL:P{"PDF"}%</span></a>';
  }

  # login
  my $loginUrl = getLoginUrl();
  if ($loginUrl) {
    if ($isRestrictedAction{'login'}) {
      $loginString = '<span class="natDisabledTopicAction">%TMPL:P{"LOG_IN"}%</span>';
    } else {
      $loginString =
        '<a class="natLoginTopicAction" rel="nofollow" href="'.
        $loginUrl.
        '" accesskey="l" title="%TMPL:P{"LOG_IN_HELP"}%"><span>%TMPL:P{"LOG_IN"}%</span></a>';
    }
  } else {
    $loginString = '';
  }

  # logout
  my $logoutUrl = getLogoutUrl();
  if ($logoutUrl) {
    if ($isRestrictedAction{'logout'}) {
      $logoutString = '<span class="natDisabledTopicAction">%TMPL:P{"LOG_OUT"}%</span>';
    } else {
      $logoutString =
        '<a class="natLogoutTopicAction" rel="nofollow" href="'.
        $logoutUrl.
        '" accesskey="l" title="%TMPL:P{"LOG_OUT_HELP"}%"><span>%TMPL:P{"LOG_OUT"}%</span></a>';
    }
  } else {
    $logoutString = '';
  }

  # registration
  my $twikiRegistrationTopic= renderTWikiRegistration();
  if ($twikiRegistrationTopic) {
    if ($isRestrictedAction{'register'}) {
      $registerString = '<span class="natDisabledTopicAction">%TMPL:P{"LOG_OUT"}%</span>';
    } else {
      $registerString =
        '<a class="natRegisterTopicAction" href="%SCRIPTURLPATH{"view"}%/'.
        $twikiRegistrationTopic.
        '" accesskey="r" title="%TMPL:P{"REGISTER_HELP"}%"><span>%TMPL:P{"REGISTER"}%</span></a>';
    }
  } else {
    $registerString = '';
  }

  # help
  if ($isRestrictedAction{'help'}) {
    $helpString = '<span class="natDisabledTopicAction">%TMPL:P{"HELP"}%</span>';
  } else {
    my $twikiWeb = TWiki::Func::getTwikiWebname();
    my $helpTopic = $params->{help} || "TWikiUsersGuide";
    my $helpWeb;
    ($helpWeb, $helpTopic) = TWiki::Func::normalizeWebTopicName($twikiWeb, $helpTopic);
    my $helpUrl = TWiki::Func::getScriptUrl($helpWeb, $helpTopic, 'view');
    $helpString = 
      '<a class="natHelpTopicAction" href="'.$helpUrl.'" title="%TMPL:P{"HELP_HELP"}%"><span>%TMPL:P{"HELP"}%</span></a>';
  }

  # user string
  my $mainWeb = TWiki::Func::getMainWebname();
  my $wikiName = TWiki::Func::getWikiName();
  if (TWiki::Func::topicExists($mainWeb,$wikiName)) {
    my $userUrl = TWiki::Func::getScriptUrl($mainWeb, $wikiName, "view");
    $userString =
      '<a class="natHomePageTopicAction" href="'.$userUrl.'" title="%TMPL:P{"GO_HOME"}%"><span>%SPACEOUT{"%WIKINAME%"}%</span></a>';
  } else {
    $userString = "<nop>$wikiName";
  }

  $text =~ s/\$edit/$editString/go;
  $text =~ s/\$attach/$attachString/go;
  $text =~ s/\$move/$moveString/go;
  $text =~ s/\$raw/$rawString/go;
  $text =~ s/\$diff/$diffString/go;
  $text =~ s/\$more/$moreString/go;
  $text =~ s/\$print/$printString/go;
  $text =~ s/\$pdf/$pdfString/go;
  $text =~ s/\$login/$loginString/go;
  $text =~ s/\$logout/$logoutString/go;
  $text =~ s/\$register/$registerString/go;
  $text =~ s/\$user/$userString/go;
  $text =~ s/\$help/$helpString/go;
  $text =~ s/\$sep/$sepString/go;

  return $text;
}

###############################################################################
# returns the login url
sub getLoginUrl {
  my $session = $TWiki::Plugins::SESSION;
  return '' unless $session;

  my $loginManager = $session->{loginManager} || # TWiki-4.2
    $session->{users}->{loginManager} || # TWiki-4.???
    $session->{client}; # TWiki-4.0
  return $loginManager->loginUrl();
}

###############################################################################
# display url to logout
sub getLogoutUrl {

  # SMELL: I'd like to do this
  # my $loginManager = $session->{users}->{loginManager};
  # return $loginManager->logoutUrl();
  #
  # but for now the "best" we can do is this:
  if ($TWiki::cfg{LoginManager} =~ /ApacheLogin/) {
    return '';
  } 
  
  return TWiki::Func::getScriptUrl($baseWeb, $baseTopic, 'view', logout=>1);
}

###############################################################################
# display url to enter topic diff/history
sub getDiffUrl {
  my $session = shift;

  my $diffTemplate = $session->inContext("HistoryPluginEnabled")?'oopshistory':'oopsrev';
  my $prevRev = getPrevRevision($baseWeb, $baseTopic);
  my $curRev = getCurRevision($baseWeb, $baseTopic);
  my $maxRev = getMaxRevision($baseWeb, $baseTopic);
  return TWiki::Func::getScriptUrl($baseWeb, $baseTopic, "oops") . 
      '?template='.$diffTemplate.
      "&param1=$prevRev&param2=$curRev&param3=$maxRev";
}


###############################################################################
sub renderWebComponent {
  my ($session, $params) = @_;

  my $theComponent = $params->{_DEFAULT};
  my $theLinePrefix = $params->{lineprefix};
  my $theWeb = $params->{web};
  my $theMultiple = $params->{multiple};

  my $name = lc $theComponent;
  $name =~ s/^currentWeb//o; # SMELL: what's this

  return '' if $skinState{$name} && $skinState{$name} eq 'off';

  my $text;
  ($text, $theWeb, $theComponent) = getWebComponent($theWeb, $theComponent, $theMultiple);

  #SL: As opposed to INCLUDE WEBCOMPONENT should render as if they were in the web they provide links to.
  #    This behavior allows for web component to be consistently rendered in foreign web using the =web= parameter. 
  #    It makes sure %WEB% is expanded to the appropriate value. 
  #    Although possible, usage of %BASEWEB% in web component topics might have undesired effect when web component is rendered from a foreign web. 
  $text = TWiki::Func::expandCommonVariables($text, $theComponent, $theWeb);

  # ignore permission warnings here ;)
  $text =~ s/No permission to read.*//g;
  $text =~ s/[\n\r]+/\n$theLinePrefix/gs if defined $theLinePrefix;

  return $text
}

###############################################################################
# search path 
# 1. search TheComponent in current web
# 2. search TWikiTheComponent in Main web
# 3. search TWikiTheComponent in TWiki web
# 4. search TheComponent in TWiki web
# (like: TheComponent = WebSideBar)
sub getWebComponent {
  my ($web, $component, $multiple) = @_;

  $web ||= $baseWeb; # Default to $baseWeb NOTE: don't use the currentWeb
  $multiple || 0;

  ($web, $component) = TWiki::Func::normalizeWebTopicName($web, $component);

  writeDebug("called getWebComponent($component)");

  # SMELL: why does preview call for components twice ???
  if ($seenWebComponent{$component} && $seenWebComponent{$component} > 2 && !$multiple) {
    return '<span class="twikiAlert">'.
      "ERROR: component '$component' already included".
      '</span>';
  }
  $seenWebComponent{$component}++;

  # get component for web
  my $text = '';
  my $meta = '';
  my $mainWeb = TWiki::Func::getMainWebname();
  my $twikiWeb = TWiki::Func::getTwikiWebname();

  my $theWeb = $web;
  my $targetWeb = $web;
  my $theComponent = $component;

  my $userName = TWiki::Func::getWikiName();

  if (TWiki::Func::topicExists($theWeb, $theComponent) &&
      TWiki::Func::checkAccessPermission('VIEW',$userName,undef,$theComponent, $theWeb)) {
    # current
    ($meta, $text) = TWiki::Func::readTopic($theWeb, $theComponent);
  } else {
    $theWeb = $mainWeb;
    $theComponent = 'TWiki'.$component;


    if (TWiki::Func::topicExists($theWeb, $theComponent) &&
        TWiki::Func::checkAccessPermission('VIEW',$userName,undef,$theComponent, $theWeb)) {
      # main
      ($meta, $text) = TWiki::Func::readTopic($theWeb, $theComponent);
    } else {
      $theWeb = $twikiWeb;
      #$theComponent = 'TWiki'.$component;

      if (TWiki::Func::topicExists($theWeb, $theComponent) &&
          TWiki::Func::checkAccessPermission('VIEW',$userName,undef,$theComponent, $theWeb)) {
	# twiki
	($meta, $text) = TWiki::Func::readTopic($theWeb, $theComponent);
      } else {
	$theWeb = $twikiWeb;
	$theComponent = $component;
	if (TWiki::Func::topicExists($theWeb, $theComponent) &&
            TWiki::Func::checkAccessPermission('VIEW',$userName,undef,$theComponent, $theWeb)) {
	  ($meta, $text) = TWiki::Func::readTopic($theWeb, $theComponent);
	} else {
	  return ''; # not found
	}
      }
    }
  }

  # extract INCLUDE area
  $text =~ s/.*?%STARTINCLUDE%//gs;
  $text =~ s/%STOPINCLUDE%.*//gs;

  #writeDebug("done getWebComponent($web.$component)");

  return ($text, $theWeb, $theComponent);
}

###############################################################################
sub renderWebLink {
  my ($session, $params) = @_;

  # get params
  my $theWeb = $params->{_DEFAULT} || $params->{web} || $baseWeb;
  my $theName = $params->{name};
  my $theMarker = $params->{marker} || 'current';

  my $defaultFormat =
    '<a class="natWebLink $marker" href="$url" title="$tooltip">$name</a>';

  my $theFormat = $params->{format} || $defaultFormat;


  my $theTooltip = $params->{tooltip} ||
    TWiki::Func::getPreferencesValue('SITEMAPUSETO', $theWeb) || '';

  my $theUrl = $params->{url} ||
    TWiki::Func::getScriptUrl($theWeb, $homeTopic, 'view');

  # unset the marker if this is not the current web 
  $theMarker = '' unless $theWeb eq $baseWeb;

  # normalize web name
  $theWeb =~ s/\//\./go;

  # get a good default name
  unless ($theName) {
    $theName = $theWeb;
    $theName = $2 if $theName =~ /^(.*)[\.](.*?)$/;
  }

  # escape some disturbing chars
  if ($theTooltip) {
    $theTooltip =~ s/"/&quot;/g;
    $theTooltip =~ s/<nop>/#nop#/g;
    $theTooltip =~ s/<[^>]*>//g;
    $theTooltip =~ s/#nop#/<nop>/g;
  }

  my $result = $theFormat;
  $result =~ s/\$default/$defaultFormat/g;
  $result =~ s/\$marker/$theMarker/g;
  $result =~ s/\$url/$theUrl/g;
  $result =~ s/\$tooltip/$theTooltip/g;
  $result =~ s/\$name/$theName/g;
  $result =~ s/\$web/$theWeb/g;
  $result =~ s/\$topic/$homeTopic/g;

  return $result;
}

###############################################################################
# render a button to add/change the form while editing
# returns 
#    * the empty string if there's no WEBFORM
#    * or "Add form" if there is no form attached to a topic yet
#    * or "Change form" otherwise
#
# there are no native means (afaik) besides the "addform" template being used
# to render the FORMFIELDS. but this is not what we need here at all. infact
# we need an empty addform.nat.tmp to switch off this feature of FORMFIELDS
sub renderFormButton {
  my ($session, $params) = @_;

  my $saveCmd = '';
  $saveCmd = $query->param('cmd') || '' if $query;
  return '' if $saveCmd eq 'repRev';

  my ($meta, $dumy) = TWiki::Func::readTopic($baseWeb, $baseTopic);
  my $formMeta = $meta->get('FORM'); 
  my $form = '';
  $form = $formMeta->{"name"} if $formMeta;

  my $action;
  my $actionText;
  if ($form) {
    $action = 'replaceform';
  } else {
    $action = 'addform';
  }
  my $actionTitle;
  if ($form) {
    $actionText = '%TMPL:P{"CHANGE_FORM"}%';
    $actionTitle = '%TMPL:P{"CHANGE_FORM_HELP"}%';
  } elsif (TWiki::Func::getPreferencesValue('WEBFORMS', $baseWeb)) {
    $actionText = '%TMPL:P{"ADD_FORM"}%';
    $actionTitle = '%TMPL:P{"ADD_FORM_HELP"}%';
  } else {
    return '';
  }
  
  my $theFormat = $params->{_DEFAULT} || $params->{format} || '$1';
  $theFormat =~ s/\$1/<a href=\"\$url\" accesskey=\"f\" title=\"$actionTitle\"><span>$actionText<\/span><\/a>/g;
  $theFormat =~ s/\$url/javascript:submitEditForm('save', '$action');/g;
  $theFormat =~ s/\$title/$actionTitle/g;
  $theFormat =~ s/\$action/$actionText/g;
  return $theFormat;
}

###############################################################################
sub obfuscateEmailAddrs {
  my ($emailAddrs, $linkText) = @_;

  $linkText = '' unless $linkText;

  #writeDebug("called obfuscateEmailAddrs(".join(", ", @$emailAddrs).", $linkText)");

  my $emailKey = '_wremoId'.$nrEmails;
  $nrEmails++;

  $emailCollection{$emailKey} = [$emailAddrs, $linkText]; 
  my $text = "<span id=\"$emailKey\">$emailKey</span>";

  #writeDebug("result: $text");
  return $text;
}

###############################################################################
sub renderEmailObfuscator {

  #writeDebug("called renderEmailObfuscator()");

  my $text = "\n".
    '<script type="text/javascript" src="%PUBURLPATH%/%TWIKIWEB%/NatSkin/obfuscator.js"></script>'."\n".
    '<script type="text/javascript">'."\n".
    "<!--\n".
    "function initEMO() {\n".
    "   var emoas = new Array();\n";
  foreach my $emailKey (sort keys %emailCollection) {
    my $emailAddrs = $emailCollection{$emailKey}->[0];
    my $linkText = $emailCollection{$emailKey}->[1];
    my $index = 0;
    foreach my $addr (@$emailAddrs) {
      next unless $addr =~ m/^([a-zA-Z0-9\-\_\.\+]+)\@([a-zA-Z0-9\-\_\.]+)\.(.+?)$/;
      my $theAccount = $1;
      my $theSubDomain = $2;
      my $theTopDomain = $3;
      $text .= "   emoas[$index] = new Array('$theSubDomain','$theAccount','$theTopDomain');\n";
      $index++
    }
    $text .= "   wremo(emoas, '$linkText', '$emailKey');\n";
    $text .= "   delete emoas; emoas = new Array();\n";
  }
  $text .= "}\n".
    "addLoadEvent(initEMO);\n".
    "//-->\n</script>\n";
  return $text;
}

###############################################################################
# returns the weblogo for the header bar.
# this will check for a couple of preferences:
#    * return %NATWEBLOGONAME% if defined
#    * return %NATWEBLOGOIMG% if defined
#    * return %WEBLOGOIMG% if defined
#    * return %WIKITOOLNAME% if defined
#    * or return 'TWiki'
#
# the *IMG cases will return a full <img src /> tag
# 
sub renderNatWebLogo {

  my $natWebLogo;

  $natWebLogo = TWiki::Func::getPreferencesValue('NATWEBLOGONAME');
  return '<span class="natWebLogo">'.$natWebLogo.'</span>' if $natWebLogo;

  $natWebLogo = TWiki::Func::getPreferencesValue('NATWEBLOGOIMG');
  return '<img class="natWebLogo" src="'.$natWebLogo.'" alt="%WEBLOGOALT%" border="0" />' 
    if $natWebLogo;

  $natWebLogo = TWiki::Func::getPreferencesValue('WEBLOGOIMG');
  return '<img class="natWebLogo" src="'.$natWebLogo.'" alt="%WEBLOGOALT%" border="0" />' 
    if $natWebLogo;

  $natWebLogo = TWiki::Func::getPreferencesValue('WIKITOOLNAME');
  return '<span class="natWebLogo">'.$natWebLogo.'</span>' if $natWebLogo;

  return 'TWiki';
}

###############################################################################
sub renderRevisions {

  #writeDebug("called renderRevisions");
  my $rev1;
  my $rev2;
  $rev1 = $query->param("rev1") if $query;
  $rev2 = $query->param("rev2") if $query;

  my $topicExists = TWiki::Func::topicExists($baseWeb, $baseTopic);
  if ($topicExists) {
    
    $rev1 = 0 unless $rev1;
    $rev2 = 0 unless $rev2;
    $rev1 =~ s/r?1\.//go;  # cut 'r' and major
    $rev2 =~ s/r?1\.//go;  # cut 'r' and major

    my $maxRev = getMaxRevision();
    $rev1 = $maxRev if $rev1 < 1;
    $rev1 = $maxRev if $rev1 > $maxRev;
    $rev2 = 1 if $rev2 < 1;
    $rev2 = $maxRev if $rev2 > $maxRev;

  } else {
    $rev1 = 1;
    $rev2 = 1;
  }

  my $revisions = '';
  my $nrrevs = $rev1 - $rev2;
  my $numberOfRevisions = $TWiki::cfg{NumberOfRevisions};

  if ($nrrevs > $numberOfRevisions) {
    $nrrevs = $numberOfRevisions;
  }

  #writeDebug("rev1=$rev1, rev2=$rev2, nrrevs=$nrrevs");

  my $j = $rev1 - $nrrevs;
  for (my $i = $rev1; $i >= $j; $i -= 1) {
    $revisions .= '&nbsp; <a href="%SCRIPTURLPATH{"view"}%'.
      '/%WEB%/%TOPIC%?rev='.$i.'">r'.$i.'</a>';
    if ($i == $j) {
      my $torev = $j - $nrrevs;
      $torev = 1 if $torev < 0;
      if ($j != $torev) {
	$revisions = $revisions.
	  '&nbsp; <a href="%SCRIPTURLPATH{"rdiff"}%'.
	  '/%WEB%/%TOPIC%?rev1='.$j.'&amp;rev2='.$torev.'">...</a>';
      }
      last;
    } else {
      $revisions .= '&nbsp; <a href="%SCRIPTURLPATH{"rdiff"}%'.
	'/%WEB%/%TOPIC%?rev1='.$i.'&amp;rev2='.($i-1).'">&gt;</a>';
    }
  }

  return $revisions;
}

###############################################################################
# reused code from the BlackListPlugin
sub renderExternalLink {
  my ($thePrefix, $theUrl) = @_;

  my $addClass = 0;
  my $text = $thePrefix.$theUrl;
  my $urlHost = TWiki::Func::getUrlHost();
  my $httpsUrlHost = $urlHost;
  $httpsUrlHost =~ s/^http:\/\//https:\/\//go;

  $theUrl =~ /^http/i && ($addClass = 1); # only for http and hhtps
  $theUrl =~ /^$urlHost/i && ($addClass = 0); # not for own host
  $theUrl =~ /^$httpsUrlHost/i && ($addClass = 0); # not for own host
  $thePrefix =~ /class="[^"]*\bnop\b/ && ($addClass = 0); # prevent adding it 
  $thePrefix =~ /class="natExternalLink"/ && ($addClass = 0); # prevent adding it twice

  if ($addClass) {
    #writeDebug("called renderExternalLink($thePrefix, $theUrl)");
    $text = "class=\"natExternalLink\" target=\"_blank\" $thePrefix$theUrl";
    #writeDebug("text=$text");
  }

  return $text;
}

###############################################################################
sub renderPrevRevision {
  return getPrevRevision($baseWeb, $baseTopic);
}

###############################################################################
sub renderCurRevision {
  return getCurRevision($baseWeb, $baseTopic, '');
}

###############################################################################
sub renderMaxRevision {
  return getMaxRevision($baseWeb, $baseTopic);
}

###############################################################################
sub getCurRevision {
  my ($thisWeb, $thisTopic, $thisRev) = @_;

  my ($date, $user, $rev);

  $rev = $query->param("rev") if $query;

  if ($rev) {
    $rev =~ s/r?1\.//go;
  } else {
    ($date, $user, $rev) = TWiki::Func::getRevisionInfo($thisWeb, $thisTopic, $thisRev);
  }

  return $rev;
}

###############################################################################
sub getPrevRevision {
  my ($thisWeb, $thisTopic) = @_;
  my $rev;
  $rev = $query->param("rev") if $query;

  my $numberOfRevisions = $TWiki::cfg{NumberOfRevisions};

  $rev = getMaxRevision($thisWeb, $thisTopic) unless $rev;
  $rev =~ s/r?1\.//go; # cut major
  if ($rev > $numberOfRevisions) {
    $rev -= $numberOfRevisions;
    $rev = 1 if $rev < 1;
  } else {
    $rev = 1;
  }

  return $rev;
}

###############################################################################
sub getMaxRevision {
  my ($thisWeb, $thisTopic) = @_;

  $thisWeb = $baseWeb unless $thisWeb;
  $thisTopic = $baseTopic unless $thisTopic;

  my $maxRev = $maxRevs{"$thisWeb.$thisTopic"};
  return $maxRev if defined $maxRev;

  $maxRev = $TWiki::Plugins::SESSION->{store}->getRevisionNumber($thisWeb, $thisTopic);
  $maxRev =~ s/r?1\.//go;  # cut 'r' and major
  $maxRevs{"$thisWeb.$thisTopic"} = $maxRev;
  return $maxRev;
}

###############################################################################
# take the REQUEST_URI, strip off the PATH_INFO from the end, the last word
# is the action; this is done that complicated as there may be different
# paths for the same action depending on the apache configuration (rewrites, aliases)
sub getCgiAction {

  my $context = TWiki::Func::getContext();

  # not all cgi actions we want to distinguish set their context
  # so only use those we are sure of
  return 'edit' if $context->{'edit'};
  return 'view' if $context->{'view'};
  return 'save' if $context->{'save'};
  # TODO: more

  # fall back to analyzing the path info
  my $pathInfo = $ENV{'PATH_INFO'} || '';
  my $theAction = $ENV{'REQUEST_URI'} || '';
  if ($theAction =~ /^.*?\/([^\/]+)$pathInfo.*$/) {
    $theAction = $1;
  } else {
    $theAction = 'view';
  }
  #writeDebug("PATH_INFO=$ENV{'PATH_INFO'}");
  #writeDebug("REQUEST_URI=$ENV{'REQUEST_URI'}");
  #writeDebug("theAction=$theAction");

  return $theAction;
}

###############################################################################
sub escapeParameter {
  return '' unless $_[0];

  $_[0] =~ s/\$percnt/%/g;
  $_[0] =~ s/\$nop//g;
  $_[0] =~ s/\\n/\n/g;
  $_[0] =~ s/\$n/\n/g;
  $_[0] =~ s/\\%/%/g;
  $_[0] =~ s/\\"/"/g;
  $_[0] =~ s/\$dollar/\$/g;
}

###############################################################################
# taken from TWiki::UI::ChangeForm and leveraged to normal formatting standards
sub renderFormList {
  my ($session, $params) = @_;

  my $theFormat = $params->{_DEFAULT} || $params->{format} 
    || '<label><input type="radio" name="formtemplate" id="formtemplateelem$index" $checked value="$name">'.
       '&nbsp;$formTopic</input></label>';

  my $theWeb = $params->{web} || $baseWeb;
  my $theTopic = $params->{topic} || $baseTopic;
  my $theSeparator = $params->{sep} || $params->{separator} || '<br />';
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $theSelected = $params->{selected} || $query->param('formtemplate');

  unless ($theSelected) {
    my ($meta) = TWiki::Func::readTopic($baseWeb, $baseTopic);
    my $form = $meta->get( 'FORM' );
    $theSelected = $form->{name} if $form;
  }
  $theSelected = 'none' unless $theSelected;

  my $legalForms = TWiki::Func::getPreferencesValue('WEBFORMS', $theWeb);
  $legalForms =~ s/^\s*//;
  $legalForms =~ s/\s*$//;
  my %forms = map {$_ => 1} split( /[,\s]+/, $legalForms );
  my @forms = sort keys %forms;
  push @forms, 'none';

  my @formList = '';
  my $index = 0;
  foreach my $form (@forms) {
      $index++;
      my $text = $theFormat;
      my $checked = '';
      $checked = 'checked' if $form eq $theSelected;
      my ($formWeb, $formTopic) = $session->normalizeWebTopicName($theWeb, $form);

      $text =~ s/\$index/$index/g;
      $text =~ s/\$checked/$checked/g;
      $text =~ s/\$name/$form/g;
      $text =~ s/\$formWeb/$formWeb/g;
      $text =~ s/\$formTopic/$formTopic/g;
      
      push @formList, $text;
  }
  my $result = $theHeader.join($theSeparator, @formList).$theFooter;
  $result =~ s/\$count/$index/g;
  $result =~ s/\$web/$theWeb/g;
  $result =~ s/\$topic/$theTopic/g;
  escapeParameter($result);
  $result = TWiki::Func::expandCommonVariables($result, $theTopic, $theWeb);

  return $result;
}

1;

