package WebDAVPluginSuite;

use base qw(Unit::TestSuite);

sub name { 'WebDAVPlugin' };

sub include_tests {
  qw(FileSystemTests )#ServerTest)
};

1;
