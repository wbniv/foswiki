use strict;

package SemiAutomaticTestCaseTests;

use base qw(FoswikiFnTestCase);

use strict;
use Foswiki;
use Foswiki::UI::View;
use Error qw( :try );

sub list_tests {
    my ($this, $suite) = @_;
    my @set = $this->SUPER::list_tests(@_);

    my $wiki = new Foswiki();
    unless( $wiki->{store}->webExists('TestCases')) {
        print STDERR "Cannot run semi-automatic test cases; TestCases web not found";
        return;
    }
    eval "use Foswiki::Plugins::TestFixturePlugin";
    if ($@) {
        print STDERR "Cannot run semi-automatic test cases; could not find TestFixturePlugin";
        $wiki->finish();
        return;
    }
    foreach my $case ($wiki->{store}->getTopicNames('TestCases')) {
        next unless $case =~ /^TestCaseAuto/;
        my $test = 'SemiAutomaticTestCaseTests::test_'.$case;
        no strict 'refs';
        *$test = sub { shift->run_testcase($case) };
        use strict 'refs';
        push(@set, $test);
    }
    $wiki->finish();
    return @set;
}

sub run_testcase {
    my ( $this, $testcase ) = @_;
    my $query = new Unit::Request({
        test=>'compare',
        debugenableplugins=>'TestFixturePlugin,InterwikiPlugin',
        skin=>'pattern'});
    $query->path_info( "/TestCases/$testcase" );
    $Foswiki::cfg{Plugins}{TestFixturePlugin}{Enabled} = 1;
    $Foswiki::cfg{Plugins}{TestFixturePlugin}{Module} = 'Foswiki::Plugins::TestFixturePlugin';
    my $wiki = new Foswiki( $this->{test_user_login}, $query );
    $wiki->{store}->saveTopic(
        $wiki->{user}, $this->{users_web}, 'ProjectContributor', 'none');
    my ($text, $result) = $this->capture( \&Foswiki::UI::View::view, $wiki);
    unless( $text =~ m#<font color="green">ALL TESTS PASSED</font># ) {
        open(F,">${testcase}_run.html");
        print F $text;
        close F;
        $query->delete('test');
        ($text, $result) = $this->capture( \&Foswiki::UI::View::view, $wiki);
        open(F,">${testcase}.html");
        print F $text;
        close F;
        $this->assert(0, "$testcase FAILED - output in ${testcase}.html and ${testcase}_run.html");
    }
    $wiki->finish();
}

sub test_suppresswarning {
}

1;
