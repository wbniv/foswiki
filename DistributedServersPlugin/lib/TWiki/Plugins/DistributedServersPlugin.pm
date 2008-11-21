# Copyright SvenDowideit@fosiki.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 3
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

=pod

---+ package TWiki::Plugins::DistributedServersPlugin

enable distributed servers to leverage Browser speedups from using a CDN.

=cut

package TWiki::Plugins::DistributedServersPlugin;

use strict;
require TWiki::Func;       # The plugins API
require TWiki::Plugins;    # For the API version

use vars
  qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC $pubCDNIndex);
$VERSION           = '$Rev: 767 (18 Nov 2008) $';
$RELEASE           = 'TWiki-4.2';
$SHORTDESCRIPTION  = 'CDN and loadbalancing Wiki support';
$NO_PREFS_IN_TOPIC = 1;
$pluginName        = 'DistributedServersPlugin';

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    #force all pub URL's to be absolute.
    $TWiki::cfg{PubUrlPath} = $TWiki::Plugins::SESSION->getPubUrl(1);

    return 1;
}

=pod

---++ postRenderingHandler( $text )
   * =$text= - the text that has just been rendered. May be modified in place.

because PUBURL tags are contextless, we are forced to post process the HTML
   * TODO: should really protect non-HTML src type url's from re-writing

=cut

sub postRenderingHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    #my $text = shift;

    # remove duplicated hostPath's
    my $hostUrl = TWiki::Func::getUrlHost( );
    $_[0] =~ s|($hostUrl)($hostUrl)|$1|g;

    my $pubCDNMap = $TWiki::cfg{Plugins}{DistributedServersPlugin}{CDNMap};
    #print STDERR  $TWiki::cfg{Plugins}{DistributedServersPlugin}{CDNMap};
    foreach my $from ( keys(%{$pubCDNMap}) ) {
        #print STDERR "cdn? $from";
        $_[0] =~ s|($from)|pubCDN($1)|ge;
    }
}

sub pubCDN {
    my $fromUrl = shift;
    my $pubCDNMap = $TWiki::cfg{Plugins}{DistributedServersPlugin}{CDNMap};
    my $url     = $pubCDNMap->{$fromUrl}[ $pubCDNIndex++ ];
    $pubCDNIndex = 0 if ( $pubCDNIndex >= scalar( @{ $pubCDNMap->{$fromUrl} } ) );

    return $url;
}

1;
