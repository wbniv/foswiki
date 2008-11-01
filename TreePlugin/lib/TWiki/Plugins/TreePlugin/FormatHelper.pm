#
# Copyright (C) Slava Kozlov 2002 - All rights reserved
#
# TWiki extension TWiki::Plugins::TreePlugin::FormatHelper
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

package TWiki::Plugins::TreePlugin::FormatHelper;

use strict;

use Exporter;
use vars qw(@EXPORT);
@EXPORT = qw(&loopReplaceRefData &replaceByRefData &spaceTopic);

sub loopReplaceRefData {
    my $text = shift;
    my $ref  = shift;
    foreach (@_) {
        $text = replaceByRefData( $text, $ref, $_ );
    }
    return $text;
}

# s/\$(\w+)/$ref->data($1)/ge;

sub replaceByRefData {
    my ( $text, $ref, $label, $paramname ) = @_;
    $paramname = $label unless ($paramname);
    if ( $ref->data($paramname) ) {
        $text =~ s/\$$label/$ref->data($paramname)/ge;    # geo for cgi
    }
    return $text;
}

sub spaceTopic {
    my ($text) = @_;
    $text =~ s/([a-z]+)([A-Z0-9]+)/$1 $2/go;
    return $text;
}

1;

