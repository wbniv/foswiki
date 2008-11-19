# Plugin for Foswiki - The Free Open Source Wiki, http://foswiki.org/
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
package TWiki::Plugins::BlogPlugin::Factory;

use strict;
use vars qw($debug);

$debug = 1; # toggle me

###############################################################################
sub new {
  my $class = shift;
  my $this = bless({}, $class);
  return $this;
}

###############################################################################
# static
sub writeDebug {
  #&TWiki::Func::writeDebug('- BlogPlugin - ' . $_[0]) if $debug;
  #print STDERR "DEBUG - BlogPlugin - $_[0]\n" if $debug;
}

###############################################################################
sub handleCreateBlog {
  my ($this, $session) = @_;

  writeDebug("called handleCreateBlog");
  $TWiki::Plugins::SESSION = $session;

  my $query = TWiki::Func::getCgiQuery();
  my $baseWeb = $query->param('baseweb') || '_BlogPlugin';
  my $webBGColor = $query->param('webbgcolor') || '#D0D0D0';
  my $tagline = $query->param('tagline') || 'A twiki blog';
  my $noSearchAll = $query->param('nosearchall') || '';
  my $newWeb = $query->param('newweb') || '';
  my $blogName = $query->param('blogname') || $newWeb;
  my $style = $query->param('style') || 'Kubrick';
  my $styleVariation = $query->param('stylevariation') || 'none';
  my $lastFmNick = $query->param('lastfmnick') || '';
  my $technoratiCode = $query->param('technoraticode') || '';
  my $googleAdsenseCode = $query->param('googleadsensecode') || '';

  my $webName = $query->param('webname') || $TWiki::cfg{'SystemWebName'};
  my $topicName = $query->param('topicname') || 'BlogFactory';

  writeDebug("baseWeb=$baseWeb");
  writeDebug("newWeb=$newWeb");
  writeDebug("tagline=$tagline");
  writeDebug("webBGColor=$webBGColor");
  writeDebug("noSearchAll=$noSearchAll");
  writeDebug("style=$style");
  writeDebug("styleVariation=$styleVariation");
  writeDebug("lastFmNick=$lastFmNick");
  writeDebug("technoratiCode=$technoratiCode");
  writeDebug("googleAdsenseCode=$googleAdsenseCode");
  writeDebug("webName=$webName");
  writeDebug("topicName=$topicName");

  my $user = $session->{user};
  writeDebug("user=$user");

  # check permission, user authorized to create webs?
  unless($session->{user}->isAdmin()) { 
    throw TWiki::OopsException(
      'accessdenied',
      def => 'topic_access',
      web => $webName,
      topic => $topicName,
      params =>
      [ 'MANAGE',
	$session->{i18n}->maketext('access not allowed on web')
      ]
    );
  }

  # check params
  unless($newWeb) {
    throw TWiki::OopsException('attention', 
      def => 'web_missing'
    );
  }
  unless (TWiki::isValidWebName($newWeb, 1)) {
    throw TWiki::OopsException('attention', 
      def =>'invalid_web_name', 
      params => $newWeb
    );
  }
  $newWeb = TWiki::Sandbox::untaintUnchecked($newWeb);
  $baseWeb = TWiki::Sandbox::untaintUnchecked($baseWeb);

  if( $session->{store}->webExists($newWeb)) {
    throw TWiki::OopsException('attention', 
      def => 'web_exists', 
      params => $newWeb 
    );
  }

  # create the blog
  my $opts = {
    WEBBGCOLOR => $webBGColor,
    SITEMAPWHAT => $tagline,
    SITEMAPUSETO => $tagline,
    NOSEARCHALL => $noSearchAll,
    SITEMAPLIST => 'on',
    SKINSTYLE => $style,
    STYLEVARIATION => $styleVariation,
    LASTFMNICK => $lastFmNick,
    TECHNORATICODE => $technoratiCode,
    GOOGLEADSENSECODE => $googleAdsenseCode,
    NATSEARCHINCLUDEWEB => $newWeb,
    WEBTOOLNAME => $blogName,
  };

  my $err = $session->{store}->createWeb($user, $newWeb, $baseWeb, $opts);
  if ($err) {
    throw TWiki::OopsException('attention', 
      def => 'web_creation_error',
      params => [ $newWeb, $err ] 
    );
  }

  # finally
  my $url = TWiki::Func::getViewUrl($webName, $topicName);
  $url .= 
    "?blogfactorymsg=Successfuly created the $newWeb!!!" .
    "&newweb=$newWeb&blogname=$blogName";
  
  TWiki::Func::redirectCgiQuery($query, $url);
  return '';
}

1;
