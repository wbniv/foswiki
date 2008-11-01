package FallbackPluginSuite;

use base qw(Unit::TestSuite);

sub name { 'FallbackPluginSuite' };

sub include_tests { qw(FallbackPluginTests) };

1;
