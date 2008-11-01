# Plugin for mediawiki2twiki
#
# Copyright (C) 2007 Michael Daum http://wikiring.de
#
# Copy/Rename this file to YourOwnPlugin.pm and rename the package line below

package TWiki::Contrib::MediaWiki2TWikiAddOn::EmptyPlugin;
use strict;

##############################################################################
sub registerHandlers {
  my $converter = shift;

  #$converter->writeDebug("registering callbacks");

  #$converter->registerHandler('init', \&handleInit);
  #$converter->registerHandler('before', \&handleBefore);
  #$converter->registerHandler('title', \&handleTitle);
  #$converter->registerHandler('after', \&handleAfter);
  #$converter->registerHandler('final', \&handleFinal);
}

##############################################################################
# called after the converter has been constructed
sub DISABLED_handleInit {
  my $converter = shift;
}

##############################################################################
# called when the title of a mediawiki is converted to a TopicTitle for TWiki
sub DISABLED_handleTitle {
  my $converter = shift;
  my $page = shift;

  #$converter->writeDebug("called handleTitle");
  #$converter->writeDebug("before, title=$_[0]");

  # remove umlaute
  $_[0] =~ s/�/ae/go;
  $_[0] =~ s/�/oe/go;
  $_[0] =~ s/�/ue/go;
  $_[0] =~ s/�/Ae/go;
  $_[0] =~ s/�/Oe/go;
  $_[0] =~ s/�/Ue/go;
  $_[0] =~ s/�/ss/go;

  #$converter->writeDebug("after, title=$_[0]");
}

##############################################################################
# called before one page is converted
sub DISABLED_handleBefore {
  my $converter = shift;
  my $page = shift;

  #$converter->writeDebug("called handleBefore");
}

##############################################################################
# called after a page has been converted to a TWiki topic
sub DISABLED_handleAfter {
  my $converter = shift;
  my $page = shift;

  #$converter->writeDebug("called handleAfter");
}

##############################################################################
# called after all pages have been converted
sub DISABLED_handleFinal {
  my $converter = shift;

  #$converter->writeDebug("called handleFinal");
}

1;
