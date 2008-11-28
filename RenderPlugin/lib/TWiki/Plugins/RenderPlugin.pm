# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/

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

package TWiki::Plugins::RenderPlugin;

require TWiki::Func;
use strict;

use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $NO_PREFS_IN_TOPIC );

$VERSION = '$Rev$';
$RELEASE = '0.1';

$SHORTDESCRIPTION = 'Render <nop>TWikiApplications asynchronously';
$NO_PREFS_IN_TOPIC = 1;

use constant DEBUG => 0; # toggle me

###############################################################################
sub writeDebug {
  print STDERR '- RenderPlugin - '.$_[0]."\n" if DEBUG;
}


###############################################################################
sub initPlugin {
  my ($topic, $web, $user, $installWeb) = @_;

  TWiki::Func::registerRESTHandler('tag', \&restTag);
  TWiki::Func::registerRESTHandler('expand', \&restExpand);
  TWiki::Func::registerRESTHandler('render', \&restRender);

  return 1;
}

###############################################################################
sub restRender {
  my ($session, $subject, $verb) = @_;

  my $query = TWiki::Func::getCgiQuery();
  my $theTopic = $query->param('topic') || $session->{topicName};
  my $theWeb = $query->param('web') || $session->{webName};
  my ($web, $topic) = TWiki::Func::normalizeWebTopicName($theWeb, $theTopic);

  return TWiki::Func::renderText(restExpand($session, $subject, $verb), $web);
}

###############################################################################
sub restExpand {
  my ($session, $subject, $verb) = @_;

  # get params
  my $query = TWiki::Func::getCgiQuery();
  my $theText = $query->param('text') || '';

  return ' ' unless $theText; # must return at least on char as we get a
                              # premature end of script otherwise
                              
  my $theTopic = $query->param('topic') || $session->{topicName};
  my $theWeb = $query->param('web') || $session->{webName};
  my ($web, $topic) = TWiki::Func::normalizeWebTopicName($theWeb, $theTopic);

  # and render it
  return TWiki::Func::expandCommonVariables($theText, $topic, $web) || ' ';
}

###############################################################################
sub restTag {
  my ($session, $subject, $verb) = @_;

  # get params
  my $query = TWiki::Func::getCgiQuery();
  my $theTag = $query->param('name') || 'INCLUDE';
  my $theDefault = $query->param('param') || '';
  my $theRender = $query->param('render') || 0;

  $theRender = ($theRender =~ /^\s*(1|on|yes|true)\s*$/) ? 1:0;

  my $theTopic = $query->param('topic') || $session->{topicName};
  my $theWeb = $query->param('web') || $session->{webName};
  my ($web, $topic) = TWiki::Func::normalizeWebTopicName($theWeb, $theTopic);

  # construct parameters for tag
  my $params = $theDefault?'"'.$theDefault.'"':'';
  my %params = $query->Vars();
  foreach my $key (keys %params) {
    next if $key =~ /^(name|param|topic|XForms:Model)$/;
    $params .= ' '.$key.'="'.$params{$key}.'" ';
  }

  # create TML expression
  my $tml = '%'.$theTag;
  $tml .= '{'.$params.'}' if $params;
  $tml .= '%';

  #writeDebug("tml=$tml");

  # and render it
  my $result = TWiki::Func::expandCommonVariables($tml, $topic, $web) || ' ';
  if ($theRender) {
    $result = TWiki::Func::renderText($result, $web);
  }

  #writeDebug("result=$result");

  return $result;
}

1;
