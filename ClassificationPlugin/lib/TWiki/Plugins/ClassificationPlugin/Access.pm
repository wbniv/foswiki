# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006-2007 Michael Daum http://michaeldaumconsulting.com
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

package TWiki::Plugins::ClassificationPlugin::Access;

use strict;
use TWiki::Plugins::ClassificationPlugin;

use constant  DEBUG => 1; # toggle m

use constant NO_CATACL => 0;
use constant DENY_ALLOW => 1;
use constant ALLOW_DENY => 2;

use base 'TWiki::Access';

###############################################################################
# static
sub writeDebug {
  #&TWiki::Func::writeDebug('- ClassificationPlugin - '.$_[0]) if DEBUG;
  print STDERR '- ClassificationPlugin::Access - '.$_[0]."\n" if DEBUG;
}

###############################################################################
# static
sub init {

  writeDebug("called init");

  # create a derived Access object
  my $session = $TWiki::Plugins::SESSION;
  my $access = new TWiki::Plugins::ClassificationPlugin::Access($session);

  # and plug it in
  $session->{security} = $access;
}

###############################################################################
sub new {
  my ($class, $session) = @_;

  my $this = bless($class->SUPER::new($session), $class);

  return $this;
}

###############################################################################
sub checkAccessPermission {
  my $this = shift;
  my ($mode, $user, $text, $meta, $topic, $web) = @_;

  $topic ||= '';
  writeDebug("called checkAccessPermission() for $web.$topic for $user");

  # get checking order of access control
  my $aclOrder = $this->{_aclOrderOfWeb}{$web};

  unless (defined $aclOrder) {
    my $aclOrderString = 
      TWiki::Func::getPreferencesValue('CLASSIFICATIONPLUGIN_ACL', $web);

    $aclOrder = NO_CATACL; # no category-based acl by default

    if ($aclOrderString) {
      $aclOrder = ALLOW_DENY 
        if $aclOrderString =~ /^\s*ALLOW\s*,\s*DENY\s*$/oi;
      $aclOrder = DENY_ALLOW 
        if $aclOrderString =~ /^(\s*DENY\s*,\s*ALLOW\s*)|(\s*on\s*)$/oi;
    }

    # put into cache
    $this->{_aclOrderOfWeb}{$web} = $aclOrder;
  }

  # first do the SUPER check
  my $allowed = $this->SUPER::checkAccessPermission(@_) || 0;

  # we are finished under certain conditions
  return $allowed if $aclOrder == NO_CATACL;
  return 1 if $allowed && $aclOrder == ALLOW_DENY;
  return 0 if !$allowed && $aclOrder == DENY_ALLOW;


  # now do the check
  my $hierarchy = TWiki::Plugins::ClassificationPlugin::getHierarchy($web);
  my $catAllow = $hierarchy->checkAccessPermission($mode, $user, $topic, $aclOrder);

  return $catAllow if defined $catAllow;
  return $allowed;
}

1;
