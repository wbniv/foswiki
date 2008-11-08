# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005-2006 MichaelDaum@WikiRing.com
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
package TWiki::Plugins::BlogPlugin;

use strict;
use vars qw(
  $VERSION $RELEASE $NO_PREFS_IN_TOPIC $SHORTDESCRIPTION
  $doneHeader $blogCore $blogFactory
);

use TWiki::Plugins::BlogPlugin::WebDB; # must be compiled in advance

$VERSION = '$Rev$';
$RELEASE = '0.99';
$NO_PREFS_IN_TOPIC = 1;
$SHORTDESCRIPTION = 'Basic blogging features used to implement the BlogUp <nop>TWikiApplication';

###############################################################################
sub initPlugin {

  $doneHeader = 0;
  $blogCore = undef;
  $blogFactory = undef;

  TWiki::Func::registerTagHandler('CITEBLOG', \&handleCiteBlog);
  TWiki::Func::registerTagHandler('COUNTCOMMENTS', \&handleCountComments);
  TWiki::Func::registerTagHandler('NEXTDOC', \&handleNextDoc);
  TWiki::Func::registerTagHandler('PREVDOC', \&handlePrevDoc);
  TWiki::Func::registerTagHandler('RECENTCOMMENTS', \&handleRecentComments);
  TWiki::Func::registerTagHandler('RELATEDTOPICS', \&handleRelatedTopics);
  TWiki::Func::registerRESTHandler('createblog', \&handleCreateBlog);

  return 1;
}

###############################################################################
sub handleCiteBlog { 
  newCore()->handleCiteBlog(@_);
}
sub handleCountComments { 
  newCore()->handleCountComments(@_);
}
sub handleNextDoc { 
  newCore()->handleNextDoc(@_);
}
sub handlePrevDoc { 
  newCore()->handlePrevDoc(@_);
}
sub handleRecentComments { 
  newCore()->handleRecentComments(@_);
}
sub handleRelatedTopics { 
  newCore()->handleRelatedTopics(@_);
}
sub handleCreateBlog { 
  newFactory()->handleCreateBlog(@_);
}

###############################################################################
sub newFactory {
  return $blogFactory if $blogFactory;

  eval 'use TWiki::Plugins::BlogPlugin::Factory;';
  die $@ if $@;

  $blogFactory = new TWiki::Plugins::BlogPlugin::Factory;

  return $blogFactory;
}


###############################################################################
sub newCore {
  return $blogCore if $blogCore;

  eval 'use TWiki::Plugins::BlogPlugin::Core;';
  die $@ if $@;

  $blogCore = new TWiki::Plugins::BlogPlugin::Core;

  return $blogCore;
}

###############################################################################
sub commonTagsHandler {

  if (!$doneHeader) {
    my $link = 
      '<link rel="stylesheet" '.
      'href="%PUBURL%/%SYSTEMWEB%/BlogPlugin/style.css" '.
      'type="text/css" media="all" />' . "\n" .
      '<script type="text/javascript" ' .
      'src="%PUBURL%/%SYSTEMWEB%/BlogPlugin/blogplugin.js">' .
      '</script>';
    if ($_[0] =~ s/<head>(.*?[\r\n]+)/<head>$1$link\n/o) {
      $doneHeader = 1;
    }
  }
}

###############################################################################
sub postRenderingHandler { 
  # remove leftover tags of optional plugins if they are not installed

  $_[0] =~ s/%STARTALIASAREA%//go;
  $_[0] =~ s/%STOPALIASAREA%//go;
  $_[0] =~ s/%ALIAS{.*?}%//go;
}
  

###############################################################################

1;

