#!/usr/bin/perl

$ENV{MOD_PERL} =~ /mod_perl/ or die "mod_perl_startup called, but mod_perl not used!";
use lib qw( /usr/lib/cgi-bin/twiki );
require 'setlib.cfg';
1;
