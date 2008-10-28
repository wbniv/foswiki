# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2002-2003 Will Norris. All Rights Reserved. (wbniv@saneasylumstudios.com)
# Copyright (C) 2005-2006 Michael Daum <micha@nats.informatik.uni-hamurg.de>
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
package TWiki::Plugins::ImageGalleryPlugin;
use strict;

# =========================
use vars qw(
        $VERSION $RELEASE $isInitialized $igpId $doneHeader
    );

$VERSION = '$Rev: 14855 $';
$RELEASE = '3.6';

# =========================
sub initPlugin {
  #my ($topic, $web, $user, $installWeb) = @_;

  if ($TWiki::Plugins::VERSION < 1) {
    &TWiki::Func::writeWarning("Version mismatch between ImageGalleryPlugin and Plugins.pm");
    return 0;
  }
  $igpId = 1;
  $doneHeader = 0;

  TWiki::Func::registerTagHandler('IMAGEGALLERY', \&renderImageGallery);
  TWiki::Func::registerTagHandler('NRIMAGES', \&renderNrImages);

  return 1;
}

# =========================
sub commonTagsHandler {

  if (!$doneHeader) {
    # add css definitions, deliberately NOT using addToHEAD()
    my $link = 
      '<link rel="stylesheet" '.
      'href="%PUBURL%/%SYSTEMWEB%/ImageGalleryPlugin/style.css" '.
      'type="text/css" media="all" />';

    if ($_[0] =~ s/<head>(.*?[\r\n]+)/<head>$1$link\n/o) {
      $doneHeader = 1;
    }
  }

}

# =========================
sub doInit {
  return if $isInitialized;
  $isInitialized = 1;

  eval 'use TWiki::Plugins::ImageGalleryPlugin::Core();';
  die $@ if $@;

  return undef;
}

# =========================
sub renderImageGallery {
  my ($session, $params, $theTopic, $theWeb) = @_;

  doInit();

  my $igp = TWiki::Plugins::ImageGalleryPlugin::Core->new($igpId++, $theTopic, $theWeb);
  return $igp->render($params);
}

# =========================
sub renderNrImages {
  my ($session, $params, $theTopic, $theWeb) = @_;

  doInit();

  my $igp = TWiki::Plugins::ImageGalleryPlugin::Core->new(undef, $theTopic, $theWeb);
  if ($igp->init($params)) {
    return scalar @{$igp->getImages()};
  } else {
    return TWiki::Plugins::ImageGalleryPlugin::Core::renderError("can't initialize");
  }
}

1;
