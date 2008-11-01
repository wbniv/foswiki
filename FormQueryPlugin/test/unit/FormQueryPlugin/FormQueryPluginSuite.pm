package FormQueryPluginSuite;

use base qw(Unit::TestSuite);

sub name { 'FormQueryPlugin' };

sub include_tests {
  qw(RelationTest TableDefTest TablerowDefTest TableFormatTest WebDBTest)
};

1;
