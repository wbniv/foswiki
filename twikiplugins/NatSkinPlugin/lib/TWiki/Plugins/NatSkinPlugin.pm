###############################################################################
# NatSkinPlugin.pm - Plugin handler for the NatSkin.
# 
# Copyright (C) 2003-2007 MichaelDaum@WikiRing.com
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

###############################################################################
use vars qw(
        $baseWeb $baseTopic $currentWeb $currentTopic 
	$currentUser $VERSION $RELEASE $debug
        $isGuest $defaultWikiUserName $isEnabled
	$useEmailObfuscator
	$query %seenWebComponent
	$defaultSkin $defaultVariation $defaultStyleSearchBox
	$defaultStyle $defaultStyleBorder $defaultStyleSideBar
	$defaultStyleButtons
	%maxRevs
	$doneInit $doneInitKnownStyles $doneInitSkinState
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

$debug = 0; # toggle me

# from Render.pm
$STARTWW = qr/^|(?<=[\s\(])/m;
$ENDWW = qr/$|(?=[\s\,\.\;\:\!\?\)])/m;

$VERSION = '$Rev$';
$RELEASE = '3.00-pre12';
$NO_PREFS_IN_TOPIC = 1;
$SHORTDESCRIPTION = 'Supplements the bare bones NatSkin theme for TWiki';

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
  #&TWiki::Func::writeDebug("- NatSkinPlugin - " . $_[0]) if $debug;
  print STDERR "DEBUG: NatSkinPlugin - " . $_[0] . "\n" if $debug;
}


###############################################################################
sub initPlugin {
  ($baseTopic, $baseWeb, $currentUser) = @_;

  # register tags
  TWiki::Func::registerTagHandler('SETSKINSTATE', \&renderSetSkinStyle);
  TWiki::Func::registerTagHandler('NATLOGINURL', \&renderLoginUrl);
  TWiki::Func::registerTagHandler('NATLOGOUTURL', \&renderLogoutUrl);
  TWiki::Func::registerTagHandler('WEBLINK', \&renderWebLink);
  TWiki::Func::registerTagHandler('USERACTIONS', \&renderUserActions);
  TWiki::Func::registerTagHandler('FORMBUTTON', \&renderFormButton);
  TWiki::Func::registerTagHandler('NATWEBLOGO', \&renderNatWebLogo);
  TWiki::Func::registerTagHandler('GETSKINSTYLE', \&renderGetSkinStyle);
  TWiki::Func::registerTagHandler('KNOWNSTYLES', \&renderKnownStyles);
  TWiki::Func::registerTagHandler('KNOWNVARIATIONS', \&renderKnownVariations);
  TWiki::Func::registerTagHandler('WEBCOMPONENT', \&renderWebComponent);
  TWiki::Func::registerTagHandler('IFSKINSTATE', \&renderIfSkinState);
  TWiki::Func::registerTagHandler('TWIKIREGISTRATION', \&renderTWikiRegistration);

  # REVISIONS, MAXREV, CURREV only worked properly for the PatternSkin :/
  TWiki::Func::registerTagHandler('NATREVISIONS', \&renderRevisions);
  TWiki::Func::registerTagHandler('PREVREV', \&getPrevRevision);
  TWiki::Func::registerTagHandler('CURREV', \&renderCurRevision);
  TWiki::Func::registerTagHandler('NATMAXREV', \&renderMaxRevision);

  $isEnabled = 1;
  $doneInit = 0;
  $doneInitSkinState = 0;
  $doneHeader = 0;

  # don't initialize the following two to keep them in memory using perl accelerators
  #$doneInitKnownStyles = 0;
  #$lastStylePath = '';

  %emailCollection = (); # collected email addrs
  $nrEmails = 0; # number of collected addrs
  %maxRevs = (); # cache for getMaxRevision()
  %seenWebComponent = (); # used to prevent deep recursion

  #writeDebug("done initPlugin at $baseWeb.$baseTopic for $currentUser");
  return 1;
}

###############################################################################
# commonTagsHandler:
# $_[0] - The text
# $_[1] - The topic
# $_[2] - The web
sub commonTagsHandler {
  return unless $isEnabled;
  $currentTopic = $_[1];
  $currentWeb = $_[2];

  return unless &doInit(); # delayed init not _possible_ during initPlugin

  # conditional content
  while ($_[0] =~ s/(\s*)%IFSKINSTATETHEN{(?!.*%IFSKINSTATETHEN)(.*?)}%\s*(.*?)\s*%FISKINSTATE%(\s*)/&renderIfSkinStateThen($2, $3, $1, $4)/geos) {
    # nop
  }

  # spam obfuscator
  if ($useEmailObfuscator) {
    $_[0] =~ s/\[\[mailto\:([a-zA-Z0-9\-\_\.\+]+\@[a-zA-Z0-9\-\_\.]+\..+?)(?:\s+|\]\[)(.*?)\]\]/&renderEmailAddrs([$1], $2)/ge;
    $_[0] =~ s/$STARTWW(?:mailto\:)?([a-zA-Z0-9\-\_\.\+]+\@[a-zA-Z0-9\-\_\.]+\.[a-zA-Z0-9\-\_]+)$ENDWW/&renderEmailAddrs([$1])/ge;
  }
}

###############################################################################
sub postRenderingHandler { 
  return unless $isEnabled;
  
  # detect external links
  $_[0] =~ s/<a\s+([^>]*?href=(?:\"|\'|&quot;)?)([^\"\'\s>]+(?:\"|\'|\s|&quot;>)?)/'<a '.renderExternalLink($1,$2)/geoi;
  $_[0] =~ s/(<a\s+[^>]+ target="_blank" [^>]+) target="_top"/$1/go; # twiki4 adds target="_top" ... we kick it out again

  # render email obfuscator
  if ($useEmailObfuscator && $nrEmails) {
    $useEmailObfuscator = 0;
    &TWiki::Func::addToHEAD('EMAIL_OBFUSCATOR', &renderEmailObfuscator());
    $useEmailObfuscator = 1;
  }

  # remove leftover tags of supported plugins if they are not installed
  # so that they are remove from the NatSkin templates

  $_[0] =~ s/%STARTALIASAREA%//go;
  $_[0] =~ s/%STOPALIASAREA%//go;
  $_[0] =~ s/%ALIAS{.*?}%//go;
  $_[0] =~ s/%REDDOT{.*?}%//go;
}

###############################################################################
# returns 1 on success, 0 if this plugin is disabled
sub doInit {

  return 1 if $doneInit;
  $doneInit = 1;

  # check skin
  my $skin = TWiki::Func::getSkin();

  # clear NatSkinPlugin traces from session
  unless ($skin =~ /\b(nat|plain|rss|rssatom|atom)\b/) {
    &TWiki::Func::clearSessionValue('SKINSTYLE');
    &TWiki::Func::clearSessionValue('STYLEBORDER');
    &TWiki::Func::clearSessionValue('STYLEBUTTONS');
    &TWiki::Func::clearSessionValue('STYLESIDEBAR');
    &TWiki::Func::clearSessionValue('STYLEVARIATION');
    &TWiki::Func::clearSessionValue('STYLESEARCHBOX');

    #TWiki::Func::writeWarning("NatSkinPlugin used with skin $skin");
    $isEnabled = 0; # disable the plugin if it is used with a foreign skin, i.e. kupu
    return 0;
  } else {
    $isEnabled = 1;
  }

  #writeDebug("called doInit");
  $query = &TWiki::Func::getCgiQuery();

  # get skin state from session
  &initKnownStyles();
  &initSkinState();

  $defaultWikiUserName = &TWiki::Func::getDefaultUserName();
  $defaultWikiUserName = &TWiki::Func::userToWikiName($defaultWikiUserName, 1);
  my $wikiUserName = &TWiki::Func::userToWikiName($currentUser, 1);

  $isGuest = ($wikiUserName eq $defaultWikiUserName)?1:0;
  #writeDebug("defaultWikiUserName=$defaultWikiUserName, wikiUserName=$wikiUserName, isGuest=$isGuest");

  my $isScripted = &TWiki::Func::getContext()->{'command_line'}?1:0;

  $useEmailObfuscator = &TWiki::Func::getPreferencesFlag('OBFUSCATEEMAIL');
  if ($useEmailObfuscator) {
    if ($isScripted || !$query) { # are we in cgi mode?
      $useEmailObfuscator = 0; # batch mode, i.e. mailnotification
      #writeDebug("no email obfuscation: batch mode");
    } else {
      # disable during register context
      my $theSkin = $query->param('skin') || TWiki::Func::getSkin();
      my $theContentType = $query->param('contenttype');
      if ($skinState{'action'} =~ /^(register|mailnotif|resetpasswd)/ || 
	  $theSkin =~ /^rss/ ||
	  $theContentType) {
	$useEmailObfuscator = 0;
      }
    }
  }
  #writeDebug("useEmailObfuscator=$useEmailObfuscator");

  #writeDebug("done doInit");
  return 1;
}

###############################################################################
# known styles are attachments found along the STYLEPATH. any *Style.css,
# *Variation.css etc files are collected hashed.
sub initKnownStyles {

  #writeDebug("called initKnownStyles");
  #writeDebug("stylePath=$stylePath, lastStylePath=$lastStylePath");

  my $twikiWeb = &TWiki::Func::getTwikiWebname();
  my $stylePath = &TWiki::Func::getPreferencesValue('STYLEPATH') 
    || "$twikiWeb.NatSkin";
  
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
  
  my $pubDir = &TWiki::Func::getPubDir();
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

  return if $doneInitSkinState;

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
  my $theReset;
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
    $theReset = $query->param('resetstyle');
    $theStyle = $query->param('style') || $query->param('skinstyle') || '';
    if ($theReset || $theStyle eq 'reset') {
      #writeDebug("clearing session values");
      
      # clear the style cache
      $doneInitKnownStyles = 0; 
      $lastStylePath = '';

      $theStyle = '';
      &TWiki::Func::clearSessionValue('SKINSTYLE');
      &TWiki::Func::clearSessionValue('STYLEBORDER');
      &TWiki::Func::clearSessionValue('STYLEBUTTONS');
      &TWiki::Func::clearSessionValue('STYLESIDEBAR');
      &TWiki::Func::clearSessionValue('STYLEVARIATION');
      &TWiki::Func::clearSessionValue('STYLESEARCHBOX');
      my $redirectUrl = TWiki::Func::getViewUrl($baseWeb, $baseTopic);
      TWiki::Func::redirectCgiQuery($query, $redirectUrl); 
	# we need to force a new request because the session value preferences
	# are still loaded in the preferences cache; only clearing them in
	# the session object is not enough right now but will be during the next
	# request; so we redirect to the current url
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
  my $prefStyle = &TWiki::Func::getPreferencesValue('SKINSTYLE') || 
    $defaultStyle;
  $prefStyle =~ s/^\s*(.*)\s*$/$1/go;
  if ($theStyle && !$isFinalStyle) {
    $theStyle =~ s/^\s*(.*)\s*$/$1/go;
    $doStickyStyle = 1 if $theStyle ne $prefStyle;
  } else {
    $theStyle = $prefStyle;
  }
  if ($theStyle =~ /^(off|none)$/o) {
    $theStyle = 'off';
  } else {
    $found = 0;
    foreach my $style (keys %knownStyles) {
      if ($style eq $theStyle || lc $style eq lc $theStyle) {
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
    $theSwitchStyle = lc $theSwitchStyle;
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
  my $prefStyleBorder = &TWiki::Func::getPreferencesValue('STYLEBORDER') ||
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
  my $prefStyleButtons = &TWiki::Func::getPreferencesValue('STYLEBUTTONS') ||
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
  my $prefStyleSideBar = &TWiki::Func::getPreferencesValue('STYLESIDEBAR') ||
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
  my $prefStyleSearchBox = &TWiki::Func::getPreferencesValue('STYLESEARCHBOX') ||
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
  my $prefStyleVariation = &TWiki::Func::getPreferencesValue('STYLEVARIATION') ||
    $defaultVariation;
  $prefStyleVariation =~ s/^\s*(.*)\s*$/$1/go;
  if ($theStyleVariation && !$isFinalVariation) {
    $theStyleVariation =~ s/^\s*(.*)\s*$/$1/go;
    $doStickyVariation = 1 if $theStyleVariation ne $prefStyleVariation;
  } else {
    $theStyleVariation = $prefStyleVariation;
  }
  $found = 0;
  foreach my $variation (keys %knownVariations) {
    if ($variation eq $theStyleVariation || lc $variation eq lc $theStyleVariation) {
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
  &TWiki::Func::setSessionValue('SKINSTYLE', $skinState{'style'}) 
    if $doStickyStyle;
  &TWiki::Func::setSessionValue('STYLEBORDER', $skinState{'border'})
    if $doStickyBorder;
  &TWiki::Func::setSessionValue('STYLEBUTTONS', $skinState{'buttons'})
    if $doStickyButtons;
  &TWiki::Func::setSessionValue('STYLESIDEBAR', $skinState{'sidebar'})
    if $doStickySideBar;
  &TWiki::Func::setSessionValue('STYLEVARIATION', $skinState{'variation'})
    if $doStickyVariation;
  &TWiki::Func::setSessionValue('STYLESEARCHBOX', $skinState{'searchbox'})
    if $doStickySearchBox;

  # misc
  $skinState{'action'} = getCgiAction();

  # temporary toggles
  $theToggleSideBar = 'off' if $theRaw && $skinState{'border'} eq 'thin';
  $theToggleSideBar = 'off' if 
    $skinState{'action'} =~ /^(edit|editsection|manage|rdiff|natsearch|changes|search)$/;
  $theToggleSideBar = 'off' if $skinState{'action'} =~ /^(login|logon|oops)$/;

  # switch the sidebar off if we need to authenticate
  if ($skinState{'action'} ne 'publish' && # SMELL to please PublishContrib
      $TWiki::cfg{AuthScripts} =~ /\b$skinState{'action'}\b/ &&
      !&TWiki::Func::getContext()->{authenticated}) {
      $theToggleSideBar = 'off';
  }

  $skinState{'sidebar'} = $theToggleSideBar 
    if $theToggleSideBar && $theToggleSideBar ne '';
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
      $theThen = TWiki::Func::expandCommonVariables($theThen, $currentTopic, $currentWeb);
    }
    return $before.$theThen.$after if $theThen;
  } else {
    if ($elsIfArgs) {
      #writeDebug("match elsif");
      return $before."%IFSKINSTATETHEN{$elsIfArgs}%$theElse%FISKINSTATE%".$after;
    } else {
      #writeDebug("match else");
      if ($theElse =~ s/\$nop//go) {
	$theElse = TWiki::Func::expandCommonVariables($theElse, $currentTopic, $currentWeb);
      }
      return $before.$theElse.$after if $theElse;
    }
  }

  #writeDebug("NO match");
  return $before.$after;
  
}

###############################################################################
sub renderTWikiRegistration {
  my $twikiWeb = &TWiki::Func::getTwikiWebname();

  my $twikiRegistrationTopic = 
    TWiki::Func::getPreferencesValue('TWIKIREGISTRATION') || 
    "$twikiWeb.TWikiRegistration";
  
  return $twikiRegistrationTopic;
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
  if ((!$theStyle || $skinState{'style'} =~ /$theStyle/) &&
      (!$theBorder || $skinState{'border'} =~ /$theBorder/) &&
      (!$theButtons || $skinState{'buttons'} =~ /$theButtons/) &&
      (!$theSideBar || $skinState{'sidebar'} =~ /$theSideBar/) &&
      (!$theSearchBox || $skinState{'searchbox'} =~ /$theSearchBox/) &&
      (!$theVariation || $skinState{'variation'} =~ /$theVariation/) &&
      (!$theAction || $skinState{'action'} =~ /$theAction/) &&
      (!$theFinal || grep(/$theFinal/, @{$skinState{'final'}}))) {

    &escapeParameter($theThen);
    #writeDebug("match");
    return $theThen if $theThen;
  } else {
    &escapeParameter($theElse);
    #writeDebug("NO match");
    return $theElse if $theElse;
  }

  return '';
}

###############################################################################
sub renderKnownStyles {
  doInit();
  return join(', ', sort {$a cmp $b} keys %knownStyles);
}

###############################################################################
sub renderKnownVariations {
  doInit();
  return join(', ', sort {$a cmp $b} keys %knownVariations);
}

###############################################################################
# TODO: prevent illegal skin states
sub renderSetSkinStyle {
  my ($session, $params) = @_;

  &doInit(); 

  $skinState{'buttons'} = $params->{buttons} if $params->{buttons};
  $skinState{'sidebar'} = $params->{sidebar} if $params->{sidebar};
  $skinState{'variation'} = $params->{variation} if $params->{variation};
  $skinState{'style'} = $params->{style} if $params->{style};
  $skinState{'searchbox'} = $params->{searchbox} if $params->{searchbox};
  $skinState{'border'} = $params->{border} if $params->{border};

  return '';
}

###############################################################################
sub renderGetSkinStyle {

  doInit();

  my $theStyle;
  my $theVariation;
  $theStyle = $skinState{'style'};
  return '' if $theStyle eq 'off';

  $theVariation = $skinState{'variation'} unless $skinState{'variation'} =~ /^(off|none)$/;

  # SMELL: why not use <link rel="stylesheet" href="..." type="text/css" media="all" />
  my $text = '';

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

  &doInit(); 

  my $text = '';
  my $sepString = $params->{sep} || $params->{separator} || '<span class="natSep">|</span>';
  if ($isGuest) {
    $text = $params->{guest} || '$login$sep$register$sep$print';
    return '' unless $text;
  } else {
    $text = $params->{_DEFAULT} || $params->{format} || 
    '$user$sep$logout$sep$print<br />'.
    '$edit$sep$attach$sep$move$sep$raw$sep$diff$sep$more';
  }

  my $editString = '';
  my $attachString = '';
  my $moveString = '';
  my $rawString = '';
  my $diffString = '';
  my $moreString = '';
  my $printString = '';
  my $loginString = '';
  my $logoutString = '';
  my $registerString = '';
  my $userString = '';

  # get change strings (edit, attach, move)
  my $curRev = '';
  my $theRaw;
  if ($query) {
    $curRev = $query->param('rev') || '';
    $theRaw = $query->param('raw');
  }
  $curRev =~ s/r?1\.//go;
  my $maxRev = &getMaxRevision();
  if ($curRev && $curRev < $maxRev) {
    $editString = '<strike>%TMPL:P{"EDIT"}%</strike>';
    $attachString = '<strike>%TMPL:P{"ATTACH"}%</strike>';
    $moveString = '<strike>%TMPL:P{"MOVE"}%</strike>';
  } else {
    my $whiteBoard = TWiki::Func::getPreferencesValue('WHITEBOARD');
    $whiteBoard = TWiki::isTrue($whiteBoard, 1); # too bad getPreferencesFlag does not have a default param
    my $editUrlParams = '';
    my $useWysiwyg = TWiki::Func::getPreferencesFlag('USEWYSIWYG');
    if (defined $TWiki::cfg{Plugins}{WysiwygPlugin} &&
	$TWiki::cfg{Plugins}{WysiwygPlugin}{Enabled} && $useWysiwyg) {
      $editUrlParams = '&skin=kupu';
    }  else {
      $editUrlParams = '&action=form' unless $whiteBoard;
    }
    $editString = 
      '<a rel="nofollow" href="'
      . &TWiki::Func::getScriptUrl($baseWeb, $baseTopic, "edit") 
      . '?t=' . time() 
      . $editUrlParams
      . '" accesskey="e" title="%TMPL:P{"EDIT_HELP"}%">%TMPL:P{"EDIT"}%</a>';
    $attachString =
      '<a rel="nofollow" href="'
      . &TWiki::Func::getScriptUrl($baseWeb, $baseTopic, "attach") 
      . '" accesskey="a" title="%TMPL:P{"ATTACH_HELP"}%">%TMPL:P{"ATTACH"}%</a>';
    $moveString =
      '<a rel="nofollow" href="'
      . &TWiki::Func::getScriptUrl($baseWeb, $baseTopic, "rename")
      . '" accesskey="m" title="%TMPL:P{"MOVE_HELP"}%">%TMPL:P{"MOVE"}%</a>';

  }

  # get string for raw/view action
  my $rev = &getCurRevision($baseWeb, $baseTopic, $curRev);
  if ($theRaw) {
    $rawString =
      '<a href="' . 
      &TWiki::Func::getScriptUrl($baseWeb, $baseTopic, "view") . 
      '?rev='.$rev.'" accesskey="r" title="%TMPL:P{"VIEW_HELP"}%">%TMPL:P{"VIEW"}%</a>';
  } else {
    $rawString =
      '<a href="' .  
      &TWiki::Func::getScriptUrl($baseWeb, $baseTopic, "view") .  
      '?raw=on&rev='.$rev.'" accesskey="r" title="%TMPL:P{"RAW_HELP"}%">%TMPL:P{"RAW"}%</a>';
  }
  
  # get strings for diff, print, more, login, register
  $diffString =
      '<a rel="nofollow" href="' . 
      &TWiki::Func::getScriptUrl($baseWeb, $baseTopic, "oops") . 
      '?template=oopsrev&param1=%PREVREV%&param2=%CURREV%&param3=%NATMAXREV%" accesskey="d" title="'.
      '%TMPL:P{"DIFF_HELP"}%">%TMPL:P{"DIFF"}%</a>';

  $moreString =
      '<a rel="nofollow" href="' . 
      &TWiki::Func::getScriptUrl($baseWeb, $baseTopic, "oops") . 
      '?template=oopsmore" accesskey="x" title="'.
      '%TMPL:P{"MORE_HELP"}%">%TMPL:P{"MORE"}%</a>';

  $printString =
    '<a rel="nofollow" href="'.
    &TWiki::Func::getScriptUrl($baseWeb, $baseTopic, 'view').
    '?skin=print.nat" accesskey="p" title="%MAKETEXT{"Print this page"}%">%MAKETEXT{"Print"}%</a>';

  $loginString =
    '<a rel="nofollow" href="'.
    renderLoginUrl().
    '" accesskey="l" title="%MAKETEXT{"Login to [_1]" args="<nop>%WIKITOOLNAME%"}%">%TMPL:P{"LOG_IN"}%</a>';

  $logoutString =
    '<a rel="nofollow" href="'.
    renderLogoutUrl().
    '" accesskey="l" title="%MAKETEXT{"Logout of [_1]" args="<nop>%WIKITOOLNAME%"}%">%TMPL:P{"LOG_OUT"}%</a>';

  $registerString =
    '<a href="%SCRIPTURLPATH{"view"}%/%TWIKIREGISTRATION%" '.
    'accesskey="r" title="%MAKETEXT{"Register on [_1]" args="<nop>%WIKITOOLNAME%"}%">%MAKETEXT{"Register"}%</a>';

  $userString =
    '[[%WIKIUSERNAME%][%SPACEOUT{"%WIKINAME%"}%]]';

  $text =~ s/\$edit/$editString/go;
  $text =~ s/\$attach/$attachString/go;
  $text =~ s/\$move/$moveString/go;
  $text =~ s/\$raw/$rawString/go;
  $text =~ s/\$diff/$diffString/go;
  $text =~ s/\$more/$moreString/go;
  $text =~ s/\$print/$printString/go;
  $text =~ s/\$login/$loginString/go;
  $text =~ s/\$logout/$logoutString/go;
  $text =~ s/\$register/$registerString/go;
  $text =~ s/\$user/$userString/go;
  $text =~ s/\$sep/$sepString/go;

  return $text;
}

###############################################################################
sub renderWebComponent {
  my ($session, $params) = @_;

  doInit();
  my $theComponent = $params->{_DEFAULT};
  my $lineprefix = $params->{lineprefix};
  my $web = $params->{web};
  $web=$baseWeb unless defined($web); #Default to $baseWeb NOTE: don't use the currentWeb
  my $multiple = $params->{multiple};
  $multiple=0 unless defined($multiple);  

  my $name = lc $theComponent;
  $name =~ s/^currentWeb//o;

  return '' if $skinState{$name} && $skinState{$name} eq 'off';

  my $text = getWebComponent($theComponent, $web, $multiple);
  if (defined $lineprefix)  
    {
    $text =~ s/[\n\r]+/\n$lineprefix/gs;
    }

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
  my $component = shift;
  my $web = shift;
  my $multiple = shift;

  #writeDebug("called getWebComponent($component)");

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
  my $mainWeb = &TWiki::Func::getMainWebname();
  my $twikiWeb = &TWiki::Func::getTwikiWebname();

  my $theWeb = $web;
  my $targetWeb = $web;

  my $theComponent = $component;
  if (&TWiki::Func::topicExists($theWeb, $theComponent) &&
      &TWiki::Func::checkAccessPermission('VIEW',$currentUser,undef,$theComponent, $theWeb)) {
    # current
    ($meta, $text) = &TWiki::Func::readTopic($theWeb, $theComponent);
  } else {
    $theWeb = $mainWeb;
    $theComponent = 'TWiki'.$component;
    if (&TWiki::Func::topicExists($theWeb, $theComponent) &&
        &TWiki::Func::checkAccessPermission('VIEW',$currentUser,undef,$theComponent, $theWeb)) {
      # main
      ($meta, $text) = &TWiki::Func::readTopic($theWeb, $theComponent);
    } else {
      $theWeb = $twikiWeb;
      #$theComponent = 'TWiki'.$component;
      if (&TWiki::Func::topicExists($theWeb, $theComponent) &&
          &TWiki::Func::checkAccessPermission('VIEW',$currentUser,undef,$theComponent, $theWeb)) {
	# twiki
	($meta, $text) = &TWiki::Func::readTopic($theWeb, $theComponent);
      } else {
	$theWeb = $twikiWeb;
	$theComponent = $component;
	if (&TWiki::Func::topicExists($theWeb, $theComponent) &&
            &TWiki::Func::checkAccessPermission('VIEW',$currentUser,undef,$theComponent, $theWeb)) {
	  ($meta, $text) = &TWiki::Func::readTopic($theWeb, $theComponent);
	} else {
	  return ''; # not found
	}
      }
    }
  }

  # extract INCLUDE area
  if ($text =~ /%STARTINCLUDE%(.*?)%STOPINCLUDE%/gs) {
    $text = $1;
  }
  #$text =~ s/^\s*//o;
  #$text =~ s/\s*$//o;
  #SL: As opposed to INCLUDE WEBCOMPONENT should render as if they were in the web they provide links to.
  #    This behavior allows for web component to be consistently rendered in foreign web using the =web= parameter. 
  #    It makes sure %WEB% is expanded to the appropriate value. 
  #    Although possible, usage of %BASEWEB% in web component topics might have undesired effect when web component is rendered from a foreign web. 
  $text = &TWiki::Func::expandCommonVariables($text, $component, $targetWeb);

  # ignore permission warnings here ;)
  $text =~ s/No permission to read.*//g;

  #writeDebug("done getWebComponent($component)");

  return $text;
}

###############################################################################
sub renderWebLink {
  my ($session, $params) = @_;

  my $theWeb = $params->{_DEFAULT} || $params->{web} || $baseWeb;
  my $theName = $params->{name} || $theWeb;

  my $result = 
    '<span class="natWebLink"><a href="%SCRIPTURLPATH{"view"}%/'.
    $theWeb.'/WebHome"';

  my $popup = TWiki::Func::getPreferencesValue('SITEMAPUSETO', $theWeb) || '';
  
  if ($popup) {
    $popup =~ s/"/&quot;/g;
    $popup =~ s/<nop>/#nop#/g;
    $popup =~ s/<[^>]*>//g;
    $popup =~ s/#nop#/<nop>/g;
    $result .= " title=\"$popup\"";
  }

  $result .= ">$theName</a></span>";

  return $result;
}

###############################################################################
# returns the login url
sub renderLoginUrl {

  my $logonCgi = 'natlogon';
  if ($TWiki::cfg{LoginManager} =~ /TemplateLogin/) {
    $logonCgi = 'login';
  } elsif ($TWiki::cfg{LoginManager} =~ /ApacheLogin/) {
    $logonCgi = 'viewauth';
  }

  return &TWiki::Func::getScriptUrl($baseWeb, $baseTopic, $logonCgi);
}

###############################################################################
# display url to logout
sub renderLogoutUrl {

  my $logoutCgi = 'natlogon';
  if ($TWiki::cfg{LoginManager} =~ /TemplateLogin/) {
    $logoutCgi = 'view';
  } elsif ($TWiki::cfg{LoginManager} =~ /ApacheLogin/) {
    return ''; # cant logout
  }
  my $logoutWeb = &TWiki::Func::getMainWebname(); 
  my $logoutTopic = 'WebHome';
  if (&TWiki::Func::checkAccessPermission('VIEW', $defaultWikiUserName, undef, 
    $baseTopic, $baseWeb)) {
    $logoutWeb = $baseWeb;
    $logoutTopic = $baseTopic;
  }
  my $logoutScriptUrl = &TWiki::Func::getScriptUrl($logoutWeb, $logoutTopic, $logoutCgi);

  if ($logoutCgi eq 'natlogon') {
    return $logoutScriptUrl
      . '?web='. $logoutWeb 
      . '&amp;topic='.$logoutTopic 
      . '&amp;username='.$defaultWikiUserName;
  } else {
    return $logoutScriptUrl.'?logout=1';
  }
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

  doInit();

  my $saveCmd = '';
  $saveCmd = $query->param('cmd') || '' if $query;
  return '' if $saveCmd eq 'repRev';

  my ($meta, $dumy) = &TWiki::Func::readTopic($baseWeb, $baseTopic);
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
  } elsif (&TWiki::Func::getPreferencesValue('WEBFORMS', $baseWeb)) {
    $actionText = '%TMPL:P{"ADD_FORM"}%';
    $actionTitle = '%TMPL:P{"ADD_FORM_HELP"}%';
  } else {
    return '';
  }
  
  my $theFormat = $params->{_DEFAULT} || $params->{formant};
  $theFormat =~ s/\$1/<a href=\"javascript:submitEditForm('save', '$action');\" accesskey=\"f\" title=\"$actionTitle\">$actionText<\/a>/g;
  $theFormat =~ s/\$url/javascript:submitEditForm('save', '$action');/g;
  $theFormat =~ s/\$action/$actionText/g;
  return $theFormat;
}

###############################################################################
sub renderEmailAddrs {
  my ($emailAddrs, $linkText) = @_;

  $linkText = '' unless $linkText;

  #writeDebug("called renderEmailAddrs(".join(", ", @$emailAddrs).", $linkText)");

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
    '<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/NatSkin/obfuscator.js"></script>'."\n".
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
  doInit();

  my $rev1;
  my $rev2;
  $rev1 = $query->param("rev1") if $query;
  $rev2 = $query->param("rev2") if $query;

  my $topicExists = &TWiki::Func::topicExists($baseWeb, $baseTopic);
  if ($topicExists) {
    
    $rev1 = 0 unless $rev1;
    $rev2 = 0 unless $rev2;
    $rev1 =~ s/r?1\.//go;  # cut 'r' and major
    $rev2 =~ s/r?1\.//go;  # cut 'r' and major

    my $maxRev = &getMaxRevision();
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
  my $urlHost = &TWiki::Func::getUrlHost();
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
sub renderCurRevision {
  doInit();
  return getCurRevision($baseWeb, $baseTopic, '');
}

###############################################################################
sub renderMaxRevision {
  doInit();
  return getMaxRevision($baseWeb, $baseTopic);
}

###############################################################################
sub getCurRevision {
  my ($thisWeb, $thisTopic, $thisRev) = @_;

  my $rev;
  $rev = $query->param("rev") if $query;
  if ($rev) {
    $rev =~ s/r?1\.//go;
    return $rev;
  }


  my ($date, $user);

  ($date, $user, $rev) = &TWiki::Func::getRevisionInfo($thisWeb, $thisTopic, $thisRev);

  return $rev;
}

###############################################################################
sub getPrevRevision {
  doInit();

  my $rev;
  $rev = $query->param("rev") if $query;

  my $numberOfRevisions = $TWiki::cfg{NumberOfRevisions};

  $rev = &getMaxRevision() unless $rev;
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

  $_[0] =~ s/\\n/\n/g;
  $_[0] =~ s/\$n/\n/g;
  $_[0] =~ s/\\%/%/g;
  $_[0] =~ s/\$nop//g;
  $_[0] =~ s/\$percnt/%/g;
  $_[0] =~ s/\$dollar/\$/g;
}

1;

