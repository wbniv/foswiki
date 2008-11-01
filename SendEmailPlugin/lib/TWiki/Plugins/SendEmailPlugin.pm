# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (c) 2006 by Meredith Lesly, Kenneth Lavrsen
#
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
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

package TWiki::Plugins::SendEmailPlugin;

use strict;
use TWiki::Func;

use vars qw( $VERSION $RELEASE );

$VERSION = '$Rev: 11069$';
$RELEASE = '1.2.2';

sub initPlugin {

  # check for Plugins.pm versions
  if ( $TWiki::Plugins::VERSION < 1.026 ) {
    TWiki::Func::writeWarning(
      "Version mismatch between SendEmailPlugin and Plugins.pm");
      return 0;
  }

  TWiki::Func::registerTagHandler( 'SENDEMAIL', \&handleSendEmailTag );

  # Plugin correctly initialized
  return 1;
}

sub handleSendEmailTag {
  require TWiki::Plugins::SendEmailPlugin::Core;
  TWiki::Plugins::SendEmailPlugin::Core::handleSendEmailTag(@_);
}


1;
