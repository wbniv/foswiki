package IrcPluginSuite;

use base qw(Unit::TestSuite);

sub name { 'IrcPluginSuite' };

sub include_tests { qw(IrcPluginTests) };

1;
