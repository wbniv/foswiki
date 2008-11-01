package AttachmentListPluginSuite;

use base qw(Unit::TestSuite);

sub name { 'AttachmentListPluginSuite' };

sub include_tests { qw(AttachmentListPluginTests) };

# run with
# sudo -u www perl ../bin/TestRunner.pl -clean AttachmentListPlugin/AttachmentListPluginSuite.pm

1;
