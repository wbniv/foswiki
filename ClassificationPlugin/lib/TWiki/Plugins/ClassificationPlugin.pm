# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006-2008 Michael Daum http://michaeldaumconsulting.com
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

package TWiki::Plugins::ClassificationPlugin;
use strict;
use TWiki::Contrib::DBCacheContrib::Search;

use vars qw( 
  $VERSION $RELEASE $NO_PREFS_IN_TOPIC $SHORTDESCRIPTION
  $doneHeader $doneInit $baseTopic $baseWeb
);

$VERSION = '$Rev$';
$RELEASE = '0.60';
$NO_PREFS_IN_TOPIC = 1;
$SHORTDESCRIPTION = 'A topic classification plugin and application';

###############################################################################
sub initPlugin {
  ($baseTopic, $baseWeb) = @_;

  TWiki::Func::registerTagHandler('HIERARCHY', \&handleHIERARCHY);
  TWiki::Func::registerTagHandler('ISA', \&handleISA);
  TWiki::Func::registerTagHandler('SUBSUMES', \&handleSUBSUMES);
  TWiki::Func::registerTagHandler('CATFIELD', \&handleCATFIELD);
  TWiki::Func::registerTagHandler('TAGFIELD', \&handleTAGFIELD);
  TWiki::Func::registerTagHandler('TAGRELATEDTOPICS', \&handleTAGRELATEDTOPICS);
  TWiki::Func::registerTagHandler('CATINFO', \&handleCATINFO);
  TWiki::Func::registerTagHandler('TAGINFO', \&handleTAGINFO);
  TWiki::Func::registerTagHandler('DISTANCE', \&handleDISTANCE);
  TWiki::Func::registerTagHandler('TAGCOOCCURRENCE', \&handleTAGCOOCCURRENCE);

  TWiki::Contrib::DBCacheContrib::Search::addOperator(
    name=>'SUBSUMES', 
    prec=>4,
    arity=>2,
    exec=>\&OP_subsumes,
  );
  TWiki::Contrib::DBCacheContrib::Search::addOperator(
    name=>'ISA', 
    prec=>4,
    arity=>2,
    exec=>\&OP_isa,
  );
  TWiki::Contrib::DBCacheContrib::Search::addOperator(
    name=>'DISTANCE', 
    prec=>5,
    arity=>2,
    exec=>\&OP_distance,
  );

  $doneHeader = 0;
  $doneInit = 0;
  return 1;
}

###############################################################################
sub commonTagsHandler {

  return if $doneHeader;

  my $link = 
    '<link rel="stylesheet" '.
    'href="%PUBURL%/%SYSTEMWEB%/ClassificationPlugin/styles.css" '.
    'type="text/css" media="all" />' . "\n" .
    '<script type="text/javascript" ' .
    'src="%PUBURL%/%SYSTEMWEB%/ClassificationPlugin/classification.js">' .
    '</script>';
  
  if ($_[0] =~ s/<head>(.*?[\r\n]+)/<head>$1$link\n/o) {
    $doneHeader = 1;
  }
}

###############################################################################
sub init {
  return if $doneInit;
  $doneInit = 1;
  require TWiki::Plugins::ClassificationPlugin::Core;
  TWiki::Plugins::ClassificationPlugin::Core::init($baseWeb, $baseTopic);

#  require TWiki::Plugins::ClassificationPlugin::Access;
#  TWiki::Plugins::ClassificationPlugin::Access::init($baseWeb, $baseTopic);
}

###############################################################################
sub beforeSaveHandler {
  init();
  return TWiki::Plugins::ClassificationPlugin::Core::beforeSaveHandler(@_);
}

###############################################################################
sub afterSaveHandler {
  init();
  return TWiki::Plugins::ClassificationPlugin::Core::afterSaveHandler(@_);
}

###############################################################################
# SMELL: I'd prefer a proper finishHandler, alas it does not exist
sub modifyHeaderHandler {
  init();
  TWiki::Plugins::ClassificationPlugin::Core::finish(@_);
}

###############################################################################
sub renderFormFieldForEditHandler {
  init();
  return 
    TWiki::Plugins::ClassificationPlugin::Core::renderFormFieldForEditHandler(@_);
}

###############################################################################
# perl api
sub getHierarchy {
  init();
  return TWiki::Plugins::ClassificationPlugin::Core::getHierarchy(@_);
}

###############################################################################
sub OP_subsumes {
  init();
  return TWiki::Plugins::ClassificationPlugin::Core::OP_subsumes(@_);
}

###############################################################################
sub OP_isa {
  init();
  return TWiki::Plugins::ClassificationPlugin::Core::OP_isa(@_);
}

###############################################################################
sub OP_distance {
  init();
  return TWiki::Plugins::ClassificationPlugin::Core::OP_distance(@_);
}

###############################################################################
sub handleHIERARCHY {
  init();
  return TWiki::Plugins::ClassificationPlugin::Core::handleHIERARCHY(@_);
}

###############################################################################
sub handleISA {
  init();
  return TWiki::Plugins::ClassificationPlugin::Core::handleISA(@_);
}

###############################################################################
sub handleSUBSUMES {
  init();
  return TWiki::Plugins::ClassificationPlugin::Core::handleSUBSUMES(@_);
}

###############################################################################
sub handleCATFIELD {
  init();
  return TWiki::Plugins::ClassificationPlugin::Core::handleCATFIELD(@_);
}

###############################################################################
sub handleTAGFIELD {
  init();
  return TWiki::Plugins::ClassificationPlugin::Core::handleTAGFIELD(@_);
}

###############################################################################
sub handleTAGRELATEDTOPICS {
  init();
  return TWiki::Plugins::ClassificationPlugin::Core::handleTAGRELATEDTOPICS(@_);
}

###############################################################################
sub handleCATINFO {
  init();
  return TWiki::Plugins::ClassificationPlugin::Core::handleCATINFO(@_);
}

###############################################################################
sub handleTAGINFO {
  init();
  return TWiki::Plugins::ClassificationPlugin::Core::handleTAGINFO(@_);
}

###############################################################################
sub handleDISTANCE {
  init();
  return TWiki::Plugins::ClassificationPlugin::Core::handleDISTANCE(@_);
}

###############################################################################
sub handleTAGCOOCCURRENCE {
  init();
  return TWiki::Plugins::ClassificationPlugin::Core::handleTAGCOOCCURRENCE(@_);
}

1;
