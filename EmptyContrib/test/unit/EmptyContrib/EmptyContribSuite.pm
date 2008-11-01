package EmptyContribSuite;

use base qw(Unit::TestSuite);

sub name { 'EmptyContribSuite' };

sub include_tests { qw(EmptyContribTests) };

1;
