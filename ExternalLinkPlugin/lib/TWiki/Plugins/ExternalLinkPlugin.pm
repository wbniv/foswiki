# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2005 Aurélio A Heckert <aurium@gmail.com>,
#                    Nelson Ferraz <nferraz@gmail.com>,
#                    Antonio Terceiro <asaterceiro@inf.ufrgs.br>
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

package TWiki::Plugins::ExternalLinkPlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $pluginName
        $debug $externalLinkMark $protocolsPattern
    );

$VERSION = '1.001';

$pluginName = 'ExternalLinkPlugin';  # Name of this Plugin

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.021 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPluginPreferencesFlag( "DEBUG" );

    # Get plugin preferences, the variable defined by:          * Set MARK = ...
    $externalLinkMark = TWiki::Func::getPluginPreferencesValue( "MARK" ) || "(external link)";

    $protocolsPattern = TWiki::Func::getRegularExpression('linkProtocolPattern');

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # This is the place to define customized tags and variables
    # Called by TWiki::handleCommonTags, after %INCLUDE:"..."%

    # do custom extension rule, like for example:
    $_[0] =~ s!(\[\[($protocolsPattern://[^]]+?)\]\[[^]]+?\]\]([&]nbsp;)?)! handleExternalLink($1, $2) !ge;
}

sub handleExternalLink {
  my ( $wholeLink, $url ) = @_;

  my $scriptUrl = TWiki::Func::getUrlHost() . TWiki::Func::getScriptUrlPath();
  my $pubUrl = TWiki::Func::getUrlHost() . TWiki::Func::getPubUrlPath();

  if (($url =~ /^$scriptUrl/) || ($url =~ /^$pubUrl/ ) || ($wholeLink =~ /[&]nbsp;$/)) {
    return $wholeLink;
  } else {
    $wholeLink . '&nbsp;' . $externalLinkMark;
  }

}

# =========================

1;

