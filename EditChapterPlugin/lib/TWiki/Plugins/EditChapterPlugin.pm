# Plugin for Foswiki - The Free Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008 Michael Daum http://michaeldaumconsulting.com
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

package TWiki::Plugins::EditChapterPlugin;

use strict;

use TWiki::Func;

use vars qw( 
  $VERSION $RELEASE $SHORTDESCRIPTION $NO_PREFS_IN_TOPIC
  $sharedCore $baseWeb $baseTopic $enabled $header $doneHeader
);

$VERSION = '$Rev$';
$RELEASE = '1.14';
$SHORTDESCRIPTION = 'An easy sectional edit facility';

$header = <<'HERE';
<link rel="stylesheet" href="%PUBURLPATH%/%SYSTEMWEB%/EditChapterPlugin/ecpstyles.css" type="text/css" media="all" />
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/EditChapterPlugin/ecpjavascript.js"></script>
HERE


###############################################################################
sub initPlugin {
  ($baseTopic, $baseWeb) = @_;

  $sharedCore = undef;
  $doneHeader = 0;

  TWiki::Func::registerTagHandler('EXTRACTCHAPTER', \&EXTRACTCHAPTER);

  return 1;
}

###############################################################################
sub finishHandler {
  $sharedCore = undef;
}

###############################################################################
sub initCore {

  unless ($sharedCore) {
    eval 'use TWiki::Plugins::EditChapterPlugin::Core;';
    die $@ if $@;

    $sharedCore = new TWiki::Plugins::EditChapterPlugin::Core(@_);
  }

  return $sharedCore;
}

###############################################################################
sub commonTagsHandler {
  ### my ( $text, $topic, $web, $meta ) = @_;

  unless ($doneHeader) {
    $doneHeader = 1 if ($_[0] =~ s/<head>(.*?[\r\n]+)/<head>$1$header/o);
  }

  my $context = TWiki::Func::getContext();
  return unless $context->{'view'};
  return unless $context->{'authenticated'};

  my $core = initCore($baseWeb, $baseTopic);
  $core->commonTagsHandler(@_);
}

###############################################################################
sub postRenderingHandler {
  return unless $sharedCore;
  my $translationToken = $sharedCore->{translationToken};
  $_[0] =~ s/$translationToken//go;

}

###############################################################################
sub EXTRACTCHAPTER {
  my $core = initCore($baseWeb, $baseTopic);
  return $core->handleEXTRACTCHAPTER(@_);
}

1;
