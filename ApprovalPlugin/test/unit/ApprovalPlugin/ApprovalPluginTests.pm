use strict;

package ApprovalPluginTests;

use base qw(TWikiFnTestCase);

use strict;

use Unit::Request;
use Unit::Response;
use TWiki;
use TWiki::Func;

use TWiki::Plugins::ApprovalPlugin;

use CGI;

my $twiki;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

# Set up the test fixture
sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    $TWiki::Plugins::SESSION = $twiki;
}

sub tear_down {
    my $this = shift;
    
    eval { $twiki->finish() };
    
    $this->SUPER::tear_down();
}

# Just tests a simple function while I learn how to write tests
sub test_returnHtml {
    my $this = shift;
    
    my $text = "an error";
    my $html = TWiki::Plugins::ApprovalPlugin::_Return($text);
    $this->assert_html_equals("<span class=\"ApprovalPluginMessage \"> %TWIKIWEB%.ApprovalPlugin - $text</span>", $html, "message");
}

sub test_returnError {
    my $this = shift;
    
    my $text = "an error";
    my $html = TWiki::Plugins::ApprovalPlugin::_Return($text, 1);
    $this->assert_html_equals("<span class=\"ApprovalPluginMessage twikiAlert\"> %TWIKIWEB%.ApprovalPlugin - $text</span>", $html, "message");
}

# how can i pretend to be a user...?
sub test_isValidUser {
    my $this = shift;
    #print $this->{twiki}->{user};
    #print TWiki::Func::getWikiUserName();
}

1;