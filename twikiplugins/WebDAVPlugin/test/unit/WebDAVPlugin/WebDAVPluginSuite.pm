package WebDAVPluginSuite;

use base qw(Unit::TestSuite);

sub name { 'WebDAVPlugin' };

sub include_tests {
  qw(WriteReadTest CReadTest PluginTests )#ServerTest)
};

1;
