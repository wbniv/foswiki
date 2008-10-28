# TWiki RedirectPlugin
#
# Copyright (C) 2006 Motorola, thomas.weigert@motorola.com
# Copyright (C) 2006 Meredith Lesly, msnomer@spamcop.net
# Copyright (C) 2003 Steve Mokris, smokris@softpixel.com
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

# =========================
package TWiki::Plugins::RedirectPlugin;

# =========================
use vars qw( $VERSION $RELEASE $debug $pluginName );
use strict;

$VERSION    = '$Rev: 13491 $';
$RELEASE    = 'Dakar';
$pluginName = 'RedirectPlugin';

# =========================
sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.1 ) {
        TWiki::Func::writeWarning(
            "This version of $pluginName works only with TWiki 4 and greater.");
        return 0;
    }

    # this doesn't really have any meaning if we aren't being called as a CGI
    my $query = &TWiki::Func::getCgiQuery();
    return 0 unless $query;

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag("\U$pluginName\E_DEBUG");

    TWiki::Func::registerTagHandler( 'REDIRECT', \&REDIRECT );

    # Plugin correctly initialized
    &TWiki::Func::writeDebug(
        "- TWiki::Plugins::$pluginName::initPlugin( $web.$topic ) is OK")
      if $debug;
    return 1;
}

# =========================
sub REDIRECT {
    my ( $session, $params, $topic, $web ) = @_;

    my $context     = TWiki::Func::getContext();
    my $newWeb      = $web;
    my $newTopic    = '';
    my $anchor      = '';
    my $queryString = '';
    my $dest        = $params->{'newtopic'} || $params->{_DEFAULT};

    my $webNameRegex  = TWiki::Func::getRegularExpression('webNameRegex');
    my $wikiWordRegex = TWiki::Func::getRegularExpression('wikiWordRegex');
    my $anchorRegex   = TWiki::Func::getRegularExpression('anchorRegex');

    # Redirect only on view
    # Support Codev.ShorterURLs: do not redirect on edit
    if (   $dest
        && !$context->{'edit'}
        && !$context->{'save'}
        && !$context->{'preview'} )
    {

        my $query = TWiki::Func::getCgiQuery();

        my $queryString = "";
        my $param;
        foreach my $param ( $query->param ) {
            $queryString .= "&" if $queryString;
            $queryString .= "$param=" . $query->param("$param");
        }

        # do not redirect when param "redirect=no" is passed
        my $noredirect = $query->param( -name => 'noredirect' ) || '';
        return '' if $noredirect eq 'on';

        $dest = TWiki::Func::expandCommonVariables( $dest, $topic, $web );

        # redirect to URL
        if ( $dest =~ m/^http/ ) {

            return "%BR% %RED% Cannot redirect to current topic %ENDCOLOR%"
              if ( $dest eq TWiki::Func::getViewUrl( $web, $topic ) );
            TWiki::Func::redirectCgiQuery( $query, $dest );
            return '';
        }

        # else: "topic" or "web.topic" notation
        # get the components and check if the topic exists
        my $topicLocation = "";
        if ( $dest =~ /^((.*?)\.)*(.*?)(\#.*|\?.*|$)$/ ) {
            $newWeb = $2 || $web || '';
            $newTopic = $3 || '';

            # ignore anchor and params here
            $topicLocation = "$newWeb.$newTopic";
        }

        if ( !TWiki::Func::topicExists( undef, $topicLocation ) ) {
            return
"%RED% Could not redirect to topic $topicLocation (the topic does not seem to exist) %ENDCOLOR%";
        }

        if ( $dest =~ /($anchorRegex)/ ) {
            $anchor = $1;
        }

        if ( $dest =~ /(\?.*)/ ) {

            #override url params
            $queryString = $1;
        }
        
        $queryString = "?" . $queryString if $queryString;

        # topic exists
        TWiki::Func::redirectCgiQuery( $query,
            TWiki::Func::getViewUrl( $newWeb, $newTopic ) . $anchor
              . $queryString );

    }

    return '';

}

1;
