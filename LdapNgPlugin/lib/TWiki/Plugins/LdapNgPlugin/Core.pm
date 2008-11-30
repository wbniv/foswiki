# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
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

package TWiki::Plugins::LdapNgPlugin::Core;

use strict;
use Unicode::MapUTF8 qw(from_utf8);
use TWiki::Contrib::LdapContrib;

sub DEBUG { 0; } # toggle me

###############################################################################
sub writeDebug {
  # comment me in/out
  #&TWiki::Func::writeDebug('- LdapNgPlugin - '.$_[0]) if DEBUG;
  print STDERR 'LdapNgPlugin - '.$_[0]."\n" if DEBUG;
}

###############################################################################
sub handleLdap {
  my ($session, $params, $topic, $web) = @_;

  writeDebug("called handleLdap($web, $topic)");

  # get args
  my $theFilter = $params->{'filter'} || $params->{_DEFAULT} || '';
  my $theBase = $params->{'base'} || $TWiki::cfg{Ldap}{Base} || '';
  my $theHost = $params->{'host'} || $TWiki::cfg{Ldap}{Host} || 'localhost';
  my $thePort = $params->{'port'} || $TWiki::cfg{Ldap}{Port} || '389';
  my $theVersion = $params->{version} || $TWiki::cfg{Ldap}{Version} || 3;
  my $theSSL = $params->{ssl} || $TWiki::cfg{Ldap}{SSL} || 0;
  my $theScope = $params->{scope} || 'sub';
  my $theFormat = $params->{format} || '$dn';
  my $theHeader = $params->{header} || ''; 
  my $theFooter = $params->{footer} || '';
  my $theSep = $params->{sep} || '$n';
  my $theSort = $params->{sort} || '';
  my $theReverse = $params->{reverse} || 'off';
  my $theLimit = $params->{limit} || 0;
  my $theSkip = $params->{skip} || 0;
  my $theHideNull = $params->{hidenull} || 'off';
  my $theClear = $params->{clear} || '';

  my $query = &TWiki::Func::getCgiQuery();
  my $theRefresh = $query->param('refresh') || 0;
  $theRefresh = ($theRefresh eq 'on')?1:0;

  # fix args
  $theSkip =~ s/[^\d]//go;
  $theLimit =~ s/[^\d]//go;
  my @theSort = split(/[\s,]+/, $theSort);
  $theBase = $1.','.$TWiki::cfg{Ldap}{Base} if $theBase =~ /^\((.*)\)$/;
  #writeDebug("base=$theBase");
  writeDebug("format=$theFormat");

  # new connection
  my $ldap = new TWiki::Contrib::LdapContrib(
    $session,
    base=>$theBase,
    host=>$theHost,
    port=>$thePort,
    version=>$theVersion,
    ssl=>$theSSL,
  );

  # search 
  my $search = $ldap->search(
    filter=>$theFilter, 
    base=>$theBase, 
    scope=>$theScope, 
    limit=>($theReverse eq 'on')?0:$theLimit
  );
  unless (defined $search) {
    return &inlineError('ERROR: '.$ldap->getError());
  }

  my $count = $search->count();
  return '' if ($count <= $theSkip) && $theHideNull eq 'on';

  # format
  my $result = '';
  my @entries = $search->sorted(@theSort);
  @entries = reverse @entries if $theReverse eq 'on';
  my $index = 0;
  foreach my $entry (@entries) {
    $index++;
    next if $index <= $theSkip;
    my %data;
    $data{dn} = $entry->dn();
    $data{index} = $index;
    $data{count} = $count;
    foreach my $attr ($entry->attributes()) {
      if ($attr =~ /jpegPhoto/) { # TODO make blobs configurable 
	$data{$attr} = $ldap->cacheBlob($entry, $attr, $theRefresh);
      } else {
	$data{$attr} = $entry->get_value($attr, asref=>1);
      }
    }
    my $text = '';
    $text .= $theSep if $result;
    $text .= $theFormat;
    $text = expandVars($text, %data);
    $result .= $text;
    last if $index == $theLimit;
  }
  $ldap->disconnect();

  $theHeader = expandVars($theHeader,count=>$count) if $theHeader;
  $theFooter = expandVars($theFooter,count=>$count) if $theFooter;

  #$result = $session->UTF82SiteCharSet($result) || $result;
  $result = from_utf8(-string=>$result, -charset=>$TWiki::cfg{Site}{CharSet})
    unless $TWiki::cfg{Site}{CharSet} =~ /^utf-?8$/i;
  $result = &TWiki::Func::expandCommonVariables("$theHeader$result$theFooter", 
    $topic, $web);

  writeDebug("done handleLdap()");
  writeDebug("result=$result");

  if ($theClear) {
    $theClear =~ s/\$/\\\$/g;
    my $regex = join('|',split(/[\s,]+/,$theClear));
    $result =~ s/$regex//g;
  }

  return $result;
}

###############################################################################
sub handleLdapUsers {
  my ($session, $params, $topic, $web) = @_;

  writeDebug("called handleLdapUsers($web, $topic)");

  my $ldap = TWiki::Contrib::LdapContrib::getLdapContrib($session);
  my $theHeader = $params->{header} || ''; 
  my $theFormat = $params->{format} || '   1 $displayName';
  my $theFooter = $params->{footer} || '';
  my $theSep = $params->{sep} || '$n';
  my $theLimit = $params->{limit} || 0;
  my $theSkip = $params->{skip} || 0;
  my $theInclude = $params->{include};
  my $theExclude = $params->{exclude};
  my $theHideUnknownUsers = $params->{hideunknown} || 'on';
  $theHideUnknownUsers = ($theHideUnknownUsers eq 'on')?1:0;

  my $mainWeb = TWiki::Func::getMainWebname();
  my $wikiNames = $ldap->getAllWikiNames();
  my $result = '';
  $theSkip =~ s/[^\d]//go;
  $theLimit =~ s/[^\d]//go;

  my $index = 0;
  foreach my $wikiName (sort @$wikiNames) {
    next if $theExclude && $wikiName =~ /$theExclude/;
    next if $theInclude && $wikiName !~ /$theInclude/;
    $index++;
    next if $index <= $theSkip;
    my $loginName = $ldap->getLoginOfWikiName($wikiName);
    my $emailAddrs = $ldap->getEmails($loginName);
    my $displayName;
    if (TWiki::Func::topicExists($mainWeb, $wikiName)) {
      $displayName = "[[$mainWeb.$wikiName][$wikiName]]";
    } else {
      next if $theHideUnknownUsers;
      $displayName ="<nop>$wikiName";
    }
    my $line;
    $line = $theSep if $result;
    $line .= $theFormat;
    $line = expandVars($line,
      index=>$index,
      wikiName=>$wikiName,
      displayName=>$displayName,
      loginName=>$loginName,
      emails=>$emailAddrs);
    $result .= $line;
    last if $index == $theLimit;
  }

  return expandVars($theHeader).$result.expandVars($theFooter);
}

###############################################################################
sub inlineError {
  return "<div class=\"foswikiAlert\">$_[0]</div>";
}

###############################################################################
sub expandVars {
  my ($format, %data) = @_;

  #writeDebug("called expandVars($format, '".join(',',keys %data).")");

  foreach my $key (keys %data) {
    my $value = $data{$key};
    next unless $value;
    $value = join(', ', sort @$value) if ref($data{$key}) eq 'ARRAY';

    # Format list values using the '$' delimiter in multiple lines; see rfc4517
    $value =~ s/([^\\])\$/$1<br \/>/go; 
    $value =~ s/\\\$/\$/go;
    $value =~ s/\\\\/\\/go;

    $format =~ s/\$$key\b/$value/gi;
    #writeDebug("$key=$value");
  }

  $format =~ s/\n/<br \/>/go; # multi-line values, e.g. for postalAddress

  $format =~ s/\$nop//go;
  $format =~ s/\$n/\n/go;
  $format =~ s/\$quot/\"/go;
  $format =~ s/\$percnt/\%/go;
  $format =~ s/\$dollar/\$/go;

  #writeDebug("done expandVars()");
  return $format;
}

1;
