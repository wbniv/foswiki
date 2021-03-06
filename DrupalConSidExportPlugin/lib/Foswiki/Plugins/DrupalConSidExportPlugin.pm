# Copyright (C) 2007 Impressive-media.de
# Author Eugen Mayer
# www.i:mpressive-media.de
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

package Foswiki::Plugins::DrupalConSidExportPlugin;

use strict;

use Assert;
use HTTP::Cookies::Find;
use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC );

$VERSION = '$Rev: 12445$';

$RELEASE = 'Dakar';

$SHORTDESCRIPTION = 'Saves the current PHPsid generated by drupal and makes it available';
$NO_PREFS_IN_TOPIC = 1;

$pluginName = 'DrupalConSidExportPlugin';

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $Foswiki::Plugins::VERSION < 1.026 ) {
        Foswiku::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    $debug = $Foswiki::cfg{Plugins}{PHPsidPlugin}{Debug} || 0;

    Foswiki::Func::registerTagHandler( 'DRUPALSID', \&_DRUPALSID );
    return 1;
}

sub _DRUPALSID {
    my($this, $params, $theTopic, $theWeb) = @_;
    	my $twiki = $this->{twiki};
 	my $query = Foswiki::Func::getCgiQuery();	
	my $sid = "";
	my $drupalSessionHash = $Foswiki::cfg{Plugins}{Drupal}{SessionHash};

	foreach my $name ($query->cookie()) {
		if($name eq $drupalSessionHash)
		{
			$sid = $query->cookie('-name'=>$name);
		}
 	}
	
	return $sid;
}
1;
