# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
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
#
# As per the GPL, removal of this notice is prohibited.

package TWiki::Contrib::LdapContrib::Cache;

use strict;
use Storable qw(lock_store lock_retrieve);

use vars qw ($cache $session);

=pod

---+++ init() -> $cache

initializes the cache. 

=cut

sub init {
  return $cache if $session;
  ($session) = @_;

  # load
  unless ($cache) {
    my $cacheFile = 
      $session->{store}->getWorkArea('LdapContrib').
      '/LdapCache';
    if (-f $cacheFile)  {
      writeDebug("loading ldap cache from $cacheFile");
      $cache = lock_retrieve($cacheFile);
    } else {
      writeDebug("cache not found");
    }
  }
  my $refresh = $session->{cgiQuery}->param('refreshldap') || '';
  $refresh = $refresh eq 'on'?1:0;

  my $maxCacheHist = $TWiki::cfg{Ldap}{MaxCacheHits};
  $maxCacheHist = -1 unless defined $maxCacheHist;
  my $maxCacheAge = $TWiki::cfg{Ldap}{MaxCacheAge};
  $maxCacheAge = 600 unless defined $maxCacheAge;

  my $cacheAge = 9999999999;
  my $now = time();
  $cacheAge = $now - $cache->{lastUpdate} if $cache;

  # clear to reload it
  if (!$cache || 
    $cache->{cacheHits} == 0 || 
    $cacheAge > $maxCacheAge ||
    $refresh) {

    writeDebug("updating cache");
    $cache = {};
    $cache->{cacheHits} = $maxCacheHist;
    $cache->{lastUpdate} = $now;
  } else {
    $cache->{cacheHits}--;
  }

  writeDebug("cacheHits=".abs($cache->{cacheHits}));
  writeDebug("cacheAge=$cacheAge");

  return $cache;
}

=pod

finalize the ldap cache. this is the last action the
ldap cache does when finishing a request. it is only
performed if there was at least one call to init()
during this request.

=cut

sub finish {
  return unless $session;

  # sometimes twiki calls the finish methods in the
  # middle of destroying the twiki objects and all
  # its delegations; so don't rely on the store to
  # be still there; for example, this happens during
  # save.
  return unless $session->{store}; 

  writeDebug("writing ldap cache to file");
  #writeDebug(stringify() if $TWiki::cfg{Ldap}{Debug};

  # store it
  my $dir = $session->{store}->getWorkArea('LdapContrib');
  mkdir $dir unless -d $dir;
  my $file = $dir.'/LdapCache';
  lock_store($cache, $file);
  writeDebug("done");

  $session = undef;
}

=pod 

returns a stringified version of the cache content

=cut

sub stringify {
  use Data::Dumper;
  return Data::Dumper->Dump([$cache],['cache']);
}

sub writeDebug {
  print STDERR "Ldap::Contrib - $_[0]\n" if $TWiki::cfg{Ldap}{Debug};
}


1;
