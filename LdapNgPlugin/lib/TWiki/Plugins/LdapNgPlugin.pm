# Plugin for Foswiki - The Free Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006 Michael Daum http://wikiring.com
# Portions Copyright (C) 2006 Spanlink Communications
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

package TWiki::Plugins::LdapNgPlugin;

use strict;
use vars qw($VERSION $RELEASE $isInitialized $NO_PREFS_IN_TOPIC $SHORTDESCRIPTION);

$VERSION = '$Rev$';
$RELEASE = 'v2.01';
$NO_PREFS_IN_TOPIC = 1;
$SHORTDESCRIPTION = 'Query and display data from an LDAP directory';

###############################################################################
sub initPlugin { 
  $isInitialized = 0;

  TWiki::Func::registerTagHandler('LDAP', \&handleLdap);
  TWiki::Func::registerTagHandler('LDAPUSERS', \&handleLdapUsers);
  return 1; 
}

###############################################################################
sub initCore {
  return if $isInitialized;
  eval 'use TWiki::Plugins::LdapNgPlugin::Core;';
  die $@ if $@;
  $isInitialized = 1;
}

###############################################################################
sub handleLdap {
  initCore();
  return TWiki::Plugins::LdapNgPlugin::Core::handleLdap(@_);
}

###############################################################################
sub handleLdapUsers {
  initCore();
  return TWiki::Plugins::LdapNgPlugin::Core::handleLdapUsers(@_);
}

1;
