# tests of actionset when action fields have been extended
package ExtendedActionSetTests;
use base qw( FoswikiTestCase );

use strict;

use TWiki::Plugins::ActionTrackerPlugin::Action;
use TWiki::Plugins::ActionTrackerPlugin::ActionSet;
use TWiki::Plugins::ActionTrackerPlugin::Format;
use Time::ParseDate;

my $actions;

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    # Build the fixture
    TWiki::Plugins::ActionTrackerPlugin::Action::forceTime("2 Jan 2002");
    TWiki::Plugins::ActionTrackerPlugin::Action::extendTypes("|ap,text,12|");
    $actions = new TWiki::Plugins::ActionTrackerPlugin::ActionSet();
    my $action = new TWiki::Plugins::ActionTrackerPlugin::Action(
        "Test", "Topic", 0,
        "who=A,due=1-Jan-02,open",
        "Test_Main_A_open_late");
    $actions->add($action);
    $action = new TWiki::Plugins::ActionTrackerPlugin::Action(
        "Test", "Topic", 1,
        "ap=1 who=Main.A,due=1-Jan-02,closed=1-dec-01",
        "Test_Main_A_closed_ontime");
    $actions->add($action);
    $action = new TWiki::Plugins::ActionTrackerPlugin::Action(
        "Test", "Topic", 2,
        "ap=2 who=Blah.B,due=\"29 Jan 2010\",open",
        "Test_Blah_B_open_ontime");
    $actions->add($action);
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
    TWiki::Plugins::ActionTrackerPlugin::Action::unextendTypes();
}

sub testSort {
    my $this = shift;
    $actions->sort("\$ap,\$due");
    my $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format("|AP|","|\$ap|","","\$ap");
    my $s = $actions->formatAsString($fmt);
    $this->assert_str_equals("1\n2\n\n", $s);
}

1;
