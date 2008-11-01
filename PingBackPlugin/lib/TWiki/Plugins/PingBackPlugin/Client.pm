# Pingback Client
#
# Copyright (c) 2005 by MichaelDaum <micha@nats.informatik.uni-hamburg.de>
#
# based on Pingback Proxy Copyright (c) 2002 by Ian Hickson
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA

package TWiki::Plugins::PingBackPlugin::Client;

use strict;
use LWP::UserAgent;
use HTTP::Request;
use RPC::XML::Client;
use HTML::Entities;

use vars qw($debug $pingClient);

$debug = 0; # toggle me

################################################################################
# static
sub writeDebug {
  print STDERR "- PingBackPlugin::Client - " . $_[0] . "\n" if $debug;
}

###############################################################################
# construct a signleton pingClient
sub getClient {

  unless ($pingClient) {
    $pingClient = TWiki::Plugins::PingBackPlugin::Client->new();
    die $@ unless $pingClient; # never reach
  }

  return $pingClient;
}


################################################################################
# constructor
sub new {
  my ($class) = @_;

  my $this = {
    ua=>'', # LWP::UserAgent
  };

  return bless($this, $class);
}

################################################################################
sub getAgent {
  my $this = shift;

  return $this->{ua} if $this->{ua};

  $this->{ua} = LWP::UserAgent->new();
  $this->{ua}->agent("TWiki Pingback Client");
  $this->{ua}->timeout(5);
  $this->{ua}->env_proxy();
  #writeDebug("new agent=" . $this->{ua}->agent());

  return $this->{ua};
}

################################################################################
# get target page
sub fetchPage {
  my ($this, $source, $target) = @_;

  #writeDebug("called fetchPage($source, $target)");

  my $ua = $this->getAgent();
  my $request = HTTP::Request->new('GET' => $target);
  $request->referer($source);
  return $ua->request($request);
}

################################################################################
# detect a pingback server 
# source : the source of a possible ping
# target  : the ping target
# returns the xmlrpc server that is will take the ping or undef if there's no
# such service for the target
sub detectServer {
  my ($this, $source, $target) = @_;
  
  writeDebug("called detectServer($source, $target)");

  # get target page
  my $page = $this->fetchPage($source, $target);
  if ($page->is_error) {
    writeDebug("got an error");
    return undef;
  }
  my $content = $page->content;
  #writeDebug("content=$content");

  my $server;
  # check http header
  if (my @servers = $page->header('X-Pingback')) {
    $server = $servers[0];
    writeDebug("found server=$server in X-Pingback");
  } 
  
  # check html header
  elsif ($content =~ m/<link\s+rel=\"pingback\"\s+href=\"([^\"]+)\"\s*\/?>/os ||
      $content =~ m/<link\s+href=\"([^\"]+)\"\s+rel=\"pingback\"\s*\/?>/os) {
    $server = decode_entities($1);
    writeDebug("found server=$server in html header");
  } 
  
  # not found
  else {
    writeDebug("No pingback server found");
  }

  return $server;
}

################################################################################
# send a pingback to a server
# - source : the citing instance
# - target : the cited instance
# - server : the xmlrpc server (optional)
# returns ($status, $result) where
# - status : the http status code
# - result : is a plain text (error) message 
sub ping {
  my ($this, $source, $target, $server) = @_;

  # detect client
  unless ($server) {
    $server = $this->detectServer($source, $target);
    unless ($server) {
      # no server
      return ('501 Not Implemented', "Target has no pingback server");
    }
  }

  # do an xmlrpc call
  my $client = RPC::XML::Client->new($server);
  my $response = $client->send_request('pingback.ping', $source, $target);

  my $status = '';
  my $result = '';

  if (not ref $response) {
    $status = 502;
    $result = "Bad Gateway (not a valid XML-RPC response) from '$server':\n$response\n";
  } elsif ($response->is_fault) {
    my $value = $response->value;
    $status = $value->{faultCode};
    $result = $value->{faultString};
  } else {
    $status = 202;
    $result = "Accepted. Got a responce from '$server':\n" . $response->as_string . "\n";
  }

  return ($status, $result);
}



################################################################################
1;

