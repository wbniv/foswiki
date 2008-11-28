# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2005-2008  TWiki Contributors.
# All Rights Reserved. TWiki Contributors are listed in the
# AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the TWiki root.

package TWiki::Plugins::PodPlugin;
use strict;
use TWiki::Plugins::PodPlugin::Pod2Html;

use vars qw( $web $topic $user $installWeb $SHORTDESCRIPTION $VERSION $RELEASE $pluginName $debug $do_index );

$VERSION = '$Rev: 8170 $';
$RELEASE = '0.1';
$pluginName = 'PodPlugin';
$SHORTDESCRIPTION = 'Extract Perl Old Documentation (POD) online. (Write TWiki topics in POD!!!)';

# =========================
sub initPlugin {
   ( $topic, $web, $user, $installWeb ) = @_;
   # check for Plugins.pm versions
   if( $TWiki::Plugins::VERSION < 1.026 ) {
      TWiki::Func::writeWarning( 'Version mismatch between '.$pluginName.' and Plugins.pm' );
      return 0;
   }
   $debug = TWiki::Func::getPreferencesFlag('PODPLUGIN_DEBUG');
   $do_index = TWiki::Func::getPreferencesFlag('PODPLUGIN_DO_INDEX');
   return 1;
}

# =========================
sub commonTagsHandler {
   #my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead
   # Look for =head1 in the beginning of the file
   if( $_[0] =~ /^\=head1/ ) {
      $_[0] = pod2html($_[0]);
   }
}

1;
