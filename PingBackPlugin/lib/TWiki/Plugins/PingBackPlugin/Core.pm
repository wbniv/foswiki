# PingBackPlugin Core
#
# Copyright (C) 2006 MichaelDaum@WikiRing.com
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
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

package TWiki::Plugins::PingBackPlugin::Core;

# this pacakage has three duties
# - reveive pings
# - send pings
# - manage ping queues

use strict;
use vars qw($debug $pingClient);
use TWiki::Plugins::PingBackPlugin::DB qw(getPingDB);
$debug = 0; # toggle me

###############################################################################
sub writeDebug {
  #&TWiki::Func::writeDebug('- PingBackPlugin::Core - '.$_[0]) if $debug;
  print STDERR '- PingBackPlugin::Core - '.$_[0]."\n" if $debug;
}

###############################################################################
# construct a signleton pingClient
sub getPingClient {

}

###############################################################################
# receive a ping
sub handlePingbackCall {
  my ($session, $params) = @_;

  writeDebug("called handlePingbackCall");

  # check arguments
  if (@$params != 2) {
    return ('400 Bad Request', -32602, 'Wrong number of arguments');
  }

  my $source = $params->[0]->value;
  my $target = $params->[1]->value;
  my $web = $session->{webName};
  my $topic = $session->{topicName};

  # write twiki log
  $session->writeLog('PING', $web.'.'.$topic);

  writeDebug("source=$source");
  writeDebug("target=$target");

  if ($TWiki::Plugins::PingBackPlugin::enabledPingBack) {

    # queue incoming ping
    my $db = getPingDB();
    my $ping = $db->newPing(source=>$source, target=>$target);
    $ping->timeStamp();
    $ping->queue('in');

    writeDebug("done handlePingBackCall");
    return ('200 OK', 0, 'Pingback registered.');
  } else {
    # reject incoming ping
    writeDebug("resource not pingback-enabled");
    writeDebug("done handlePingBackCall");
    return ('200 OK', 33, 'resource not pingback-enabled');
  }
}

###############################################################################
# dispatch all sub commands
sub handlePingbackTag {
  my ($session, $params, $theTopic, $theWeb) = @_;

  my $action = $params->{action} || $params->{_DEFAULT} || 'ping';
  return handlePing(@_) if $action eq 'ping';
  return handleShow(@_) if $action eq 'show';
  return inlineWarning("ERROR: unknown action $action");
}

###############################################################################
# send a ping, used by the PingBackClient
sub handlePing {
  my ($session, $params, $theTopic, $theWeb) = @_;

  writeDebug("called handlePing");

  eval 'use TWiki::Plugins::PingBackPlugin::Client;';
  die $@ if $@; # never reach

  my $query = TWiki::Func::getCgiQuery();
  my $action = $query->param('pingback_action') || '';
  my $source;
  my $target;
  my $format = $params->{format} || 
    '<pre style="overflow:auto">$status: $result</pre>';

  if ($action eq 'ping') { 
    # cgi mode
    $source = $query->param('source');
    $target = $query->param('target');
  } else { 
    # tml mode
    $source = $params->{source};
    $target = $params->{target};
  }

  return '' unless $target;
  $source = &TWiki::Func::getViewUrl($theWeb, $theTopic) unless $source;

  writeDebug("source=$source");
  writeDebug("target=$target");

  
  my $client = TWiki::Plugins::PingBackPlugin::Client::getClient();
  my ($status, $result) = $client->ping($source, $target);

  my $text = expandVariables($format, 
    status=>$status,
    result=>$result,
    target=>$target,
    source=>$source,
  );


  writeDebug("done handlePing");

  return $text;
}

###############################################################################
# display pings, used in the PingManager
sub handleShow {
  my ($session, $params, $theTopic, $theWeb) = @_;

  writeDebug("called handleShow");

  my $header = $params->{header} || 
    '<span class="twikiAlert">$count</span> ping(s) found<p/>'.
    '<table class="twikiTable" width="100%">';
  my $format = $params->{format} || 
    '<tr><th>$index</th><th>$date</th></tr>'.
    '<tr><td>&nbsp;</td><td>'. '
      <table><tr><td><b>Source</b>:</td><td> $source </td></tr>'.
	'<tr><td><b>Target</b>:</td><td> $target </td></tr>'.
	'<tr><td>&nbsp;</td><td> <noautolink>"$title": $paragraph </noautolink></td></tr>'.
      '</table>'.
    '</tr>';
  my $footer = $params->{footer} || '</table>';
  my $separator = $params->{sep} || $params->{separator} || '$n';
  my $warn = $params->{warn} || 'on';
  my $reverse = $params->{reverse} || 'on';
  my $queue = $params->{queue} || 'in';
  return inlineWarning('ERROR: unknown queue '.$queue) unless $queue =~ /^(in|out|cur|trash)$/;

  my $result = '';
  my @pings;

  my $db = getPingDB();
  @pings = $db->readQueue($queue);
  @pings = reverse @pings if $reverse eq 'on';

  my $index = 0;
  foreach my $ping (@pings) {
    my $text = '';
    $index++;
    $text .= $separator if $result;
    $text .= $format;
    $text = expandVariables($text,
      date=>$ping->{date},
      source=>$ping->{source},
      target=>$ping->{target},
      extra=>$ping->{extra},
      title=>$ping->{title},
      paragraph=>$ping->{paragraph},
      'index'=>$index,
      queue=>$queue,
    );
    $result .= $text;
  }
  #writeDebug("result=$result");

  $result = $header.$separator.$result if $header;
  $result .= $separator.$footer if $footer;
  $result = expandVariables($result, queue=>$queue, count=>" $index" );

  writeDebug("done handleShow");

  return $result;
}

################################################################################
sub afterSaveHandler {
  my ($text, $topic, $web, $error, $meta) = @_;

  writeDebug("called afterSaveHandler($web.$topic)");

  if ($error) {
    writeDebug("bailing out afterSaveHandler ... save error");
    return;
  }

  if ($web =~ /^_/) {
    writeDebug("bailing out afterSaveHandler ... no pings for template webs");
    return;
  }

  # check if we just enabled/disabled pingback during this save; these values aren't 
  # in the preference cache yet; this SMELLs
  my $found = 0;
  my $isEnabled = 0;
  my $setRegex = TWiki::Func::getRegularExpression('setRegex');
  my $enablePingbackRegex = qr/^${setRegex}ENABLEPINGBACK\s*=\s*(on|yes|1|off|no|0)$/o;
  foreach my $line (split(/\r?\n/, $text)) {
    if ($line =~ /$enablePingbackRegex/) {
      $found = 1;
      $isEnabled = $1;
      $isEnabled =~ s/off//gi;
      $isEnabled =~ s/no//gi;
      $isEnabled = $found?1:0;
      last;
    }
  } 
  $isEnabled = $TWiki::Plugins::PingBackPlugin::enabledPingBack unless $found;
  if ($isEnabled) {
    writeDebug("generating pingbacks for $web.$topic");
  } else {
    writeDebug("bailing out afterSaveHandler ... not generating pingbacks for $web.$topic");
    return; # nop
  }

  # now do it
  my $urlHost = &TWiki::Func::getUrlHost();
  my $source = TWiki::Func::getViewUrl($web, $topic);
  my @pings;
  my $db = getPingDB();

  # get all text
  $text =~ s/.*?%STARTPINGBACK%//os;
  $text =~ s/%STOPPINGBACK%.*//os;
  $text =~ s/%META:[A-Z]+{.*}%\s*//go;
  my @fields = $meta->find('FIELD');
  foreach my $field (@fields) {
    $text .= ' ' . $field->{value};
  }

  # expand it
  $TWiki::Plugins::SESSION->enterContext('absolute_urls');
  $text = TWiki::Func::expandCommonVariables($text, $topic, $web);
  $text = TWiki::Func::renderText($text, $web);
  $TWiki::Plugins::SESSION->leaveContext('absolute_urls');
  writeDebug("text=$text");

  # analyse it
  while ($text =~ /<a\s+[^>]*?href=(?:\"|\'|&quot;)?([^\"\'\s>]+)(?:\"|\'|\s|&quot;>)?/gios) {
    my $target = $1;
    my $doPing = 0;
    $target =~ /^http/i && ($doPing = 1); # only for outgoing
    #$target =~ /^$urlHost/i && ($doPing = 0); # not for own host
    next unless $doPing;
    writeDebug("found target $target");
    my $ping = $db->newPing(source=>$source, target=>$target);
    $ping->timeStamp();
    push @pings, $ping;
  }
  $db->queuePings('out', @pings);
  writeDebug('queued '.(scalar @pings).' pings');
  writeDebug("done afterSaveHandler");
}

################################################################################
sub expandVariables {
  my ($format, %variables) = @_;

  my $text = $format;

  foreach my $key (keys %variables) {
    $text =~ s/\$$key/$variables{$key}/g;
  }
  $text =~ s/\$percnt/\%/go;
  $text =~ s/\$dollar/\$/go;
  $text =~ s/\$n/\n/go;
  $text =~ s/\\\\/\\/go;
  $text =~ s/\$nop//g;

  return $text;
}

###############################################################################
sub inlineWarning {
  return '<span class="twikiAlert">'.$_[0].'</span>';
}

1;
