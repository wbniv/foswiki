# Foswiki - The Free Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006 MichaelDaum@WikiRing.com
#
# TWiki Contributors are listed in the AUTHORS file in the root of
# this distribution. NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
# Copyright (C) 2004 Florian Weimer, Crawford Currie http://c-dot.co.uk
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
# As per the GPL, removal of this notice is prohibited.

package TWiki::Contrib::XmlRpcContrib;
use vars qw( $VERSION $RELEASE $SERVER %handler);

use strict;
$VERSION = '$Rev$';
$RELEASE = '0.03';

################################################################################
# register an implementation for a handler
sub registerRPCHandler {
  my ($methodName, $methodImpl) = @_;

  # SMELL: this may override a previous registration; must we take care?
  $handler{$methodName} = $methodImpl;
}

################################################################################
# process an xml call
sub dispatch {
  my ($session, $data) = @_;

  $TWiki::Plugins::SESSION = $session;

  _initServer();
  unless ($data) {
    my $query = $session->{cgiQuery};
    $data = $query->param('POSTDATA') || '';
  }

  $session->enterContext('xmlrpc');
  print $SERVER->dispatch($session, $data);
  $session->leaveContext('xmlrpc');
}

################################################################################
# create a singleton server object
sub _initServer {

  return if $SERVER;

  eval 'use TWiki::Contrib::XmlRpcContrib::Server;';
  die $@ if $@; # never reach

  $SERVER = TWiki::Contrib::XmlRpcContrib::Server->new(%handler);
  die "ERROR: can't construct XML-RPC Server" unless $SERVER; # never reach

  return $SERVER;
}


1;
