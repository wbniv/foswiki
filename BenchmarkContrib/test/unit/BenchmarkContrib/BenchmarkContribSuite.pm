package BenchmarkContribSuite;

use base qw(Unit::TestSuite);

sub name { 'BenchmarkContribSuite' };

sub include_tests { qw(BenchmarkContribTests) };

1;
