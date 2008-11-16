# See bottom of file for license and copyright info
package TWiki::Plugins::FilesysVirtualPlugin

use strict;

our $VERSION = '$Rev$';
our $RELEASE = '';
our $SHORTDESCRIPTION = 'Implementation of the Filesys::Virtual protocol over a NextWiki store';

my $pluginName = 'FilesysVirtualPlugin';

sub initPlugin {
    return 1;
}

=pod

The following implementation is required if we decide to use cached permissions

use TWiki::Plugins::FilesysVirtualPlugin::Permissions;

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    my $pdb = $TWiki::cfg{Plugins}{FilesysVirtualPlugin}{PermissionsDB};

    if ($pdb) {
        eval 'use TWiki::Plugins::FilesysVirtualPlugin::Permissions';
        if ( $@ ) {
            TWiki::Func::writeWarning( $@ );
            print STDERR $@; # print to webserver log file
        } else {
            $permDB =
              new TWiki::Plugins::FilesysVirtualPlugin::Permissions( $pdb );
        }
    } else {
        my $mess =
          "{Plugins}{FilesysVirtualPlugin}{PermissionsDB} is not defined";

        TWiki::Func::writeWarning($mess);
        print STDERR "$mess\n";
        return 0;
    }

    unless( $permDB ) {
        my $mess = "$pluginName: failed to initialise";
        TWiki::Func::writeWarning( $mess );
        print STDERR "$mess\n";
        return 0;
    }

    return 1;
}

sub beforeSaveHandler {
    my ( $text, $topic, $web ) = @_;

    return unless( $permDB );

    eval {
        $permDB->processText( $web, $topic, $text );
    };

    if ( $@ ) {
        TWiki::Func::writeWarning( "$pluginName: $@" );
        print STDERR "$pluginName: $@\n";
    }
}

=cut

1;
__DATA__

Author: Crawford Currie http://c-dot.co.uk

Copyright (C) NextWiki Contributors http://nextwiki.org

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details, published at
http://www.gnu.org/copyleft/gpl.html

Do not remove this notice from this or any derivatives.
