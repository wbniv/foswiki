package PodPluginSuite;

use base qw(Unit::TestSuite);

sub name { 'PodPluginSuite' };

sub include_tests { qw(PodPluginTests) };

1;
