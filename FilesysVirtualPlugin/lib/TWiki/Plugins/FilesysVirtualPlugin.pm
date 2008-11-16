# See bottom of file for license and copyright info
package TWiki::Plugins::FilesysVirtualPlugin

use strict;

use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION );

$VERSION = '$Rev$';
$RELEASE = '';
$SHORTDESCRIPTION = 'Implementation of the Filesys::Virtual protocol over a NextWiki store';

sub initPlugin {
    return 1;
}

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
