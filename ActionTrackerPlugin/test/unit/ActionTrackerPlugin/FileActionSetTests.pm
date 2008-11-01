# Tests for module ActionSet.pm
package FileActionSetTests;
use base qw(TWikiFnTestCase);

use strict;

use TWiki::Plugins::ActionTrackerPlugin::Action;
use TWiki::Plugins::ActionTrackerPlugin::ActionSet;
use TWiki::Plugins::ActionTrackerPlugin::Format;
use Time::ParseDate;

sub new {
    my $self = shift()->SUPER::new('ActionTrackerPlugin', @_);
    return $self;
}

my $textonlyfmt = new TWiki::Plugins::ActionTrackerPlugin::Format(
    "Text", "\$text", "cols", "\$text", "", "");

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    $TWiki::cfg{Plugins}{ActionTrackerPlugin}{Enabled} = 1;

    TWiki::Plugins::ActionTrackerPlugin::Action::forceTime("2 Jan 2002");

    my $t2 = "$this->{test_web}2";
    TWiki::Func::createWeb($t2);
    $this->{test_web_2} = $t2;

    TWiki::Func::saveTopic($this->{test_web}, "Topic1", undef, <<HERE);
%ACTION{who=$TWiki::cfg{UsersWebName}.C,due="3 Jan 02",open}% C_open_ontime"),
HERE

    TWiki::Func::saveTopic($this->{test_web}, "Topic2", undef, <<HERE);
%ACTION{who=A,due="1 Jun 2001",open}% <<EOF
A_open_late
EOF
%ACTION{who=$this->{test_user_wikiname},due="1 Jun 2001",open}% $this->{test_user_wikiname}_open_late
HERE

    TWiki::Func::saveTopic($this->{test_web_2},
        "WebNotify", undef, <<'HERE');
   * MowGli - mowgli\@jungle.book

HERE

    TWiki::Func::saveTopic($this->{test_web_2}, "Topic2", undef, <<"HERE");
%ACTION{who=$TWiki::cfg{UsersWebName}.A,due="1 Jan 02",closed}% A_closed_ontime
%ACTION{who=Blah.B,due="29 Jan 2010",open}% B_open_ontime
HERE

    TWiki::Func::saveTopic($this->{test_web_2}, "Topic2", undef, <<"HERE");
%ACTION{who=$TWiki::cfg{UsersWebName}.A,due="1 Jan 02",closed}% A_closed_ontime
%ACTION{who=Blah.B,due="29 Jan 2010",open}% B_open_ontime
HERE

    # Create a secret topic that should *NOT* be found
    TWiki::Func::saveTopic($this->{test_web_2}, "SecretTopic", undef, <<HERE);
%ACTION{who=$TWiki::cfg{UsersWebName}.IlyaKuryakin,due="1 Jan 02",closed}% A_closed_ontime
%ACTION{who=JamesBond,due="29 Jan 2010",open}% B_open_ontime
   * Set ALLOWTOPICVIEW = $TWiki::cfg{UsersWebName}.ErnstBlofeld
HERE
}

sub tear_down {
    my $this = shift;
    $this->removeWebFixture(
        $this->{twiki}, $this->{test_web_2});
    $this->SUPER::tear_down();
}

sub testAllActionsInWebTest {
    my $this = shift;
    my $attrs = new TWiki::Attrs("topic=\".*\"", 1);
    my $actions = TWiki::Plugins::ActionTrackerPlugin::ActionSet::allActionsInWeb($this->{test_web}, $attrs, 0);
    my $fmt = $textonlyfmt;
    my $chosen = $actions->formatAsString($fmt);

    $this->assert_matches(qr/C_open_ontime/o, $chosen);
    $this->assert_matches(qr/A_open_late/o, $chosen);
    $this->assert_matches(qr/$this->{test_user_wikiname}_open_late/o, $chosen);
    $this->assert_does_not_match(qr/A_closed_ontime/o, $chosen);
    $this->assert_does_not_match(qr/B_open_ontime/o, $chosen);

    my %actionees;
    $actions->getActionees(\%actionees);
    $this->assert_not_null($actionees{"$TWiki::cfg{UsersWebName}.C"});
    delete($actionees{"$TWiki::cfg{UsersWebName}.C"});
    $this->assert_not_null($actionees{"$TWiki::cfg{UsersWebName}.A"});
    delete($actionees{"$TWiki::cfg{UsersWebName}.A"});
    $this->assert_not_null($actionees{"$TWiki::cfg{UsersWebName}.$this->{test_user_wikiname}"});
    delete($actionees{"$TWiki::cfg{UsersWebName}.$this->{test_user_wikiname}"});
    $this->assert_equals(0, scalar(keys %actionees));
}

sub testAllActionsInWebMain {
    my $this = shift;
    my $attrs = new TWiki::Attrs();
    my $actions = TWiki::Plugins::ActionTrackerPlugin::ActionSet::allActionsInWeb($this->{test_web_2}, $attrs, 0);
    my $fmt = $textonlyfmt;
    my $chosen = $actions->formatAsString( $fmt );
    $this->assert_does_not_match(qr/C_open_ontime/o, $chosen);
    $this->assert_does_not_match(qr/A_open_late/o, $chosen);
    $this->assert_does_not_match(qr/$this->{test_user_wikiname}_open_late/o, $chosen);
    $this->assert_matches(qr/A_closed_ontime/o, $chosen);
    $this->assert_matches(qr/B_open_ontime/o, $chosen);

    my %actionees;
    $actions->getActionees(\%actionees);
    $this->assert_not_null($actionees{"$TWiki::cfg{UsersWebName}.A"});
    delete($actionees{"$TWiki::cfg{UsersWebName}.A"});
    $this->assert_not_null($actionees{"Blah.B"});
    delete($actionees{"Blah.B"});
    # If the perms checks are working, Bond and Kuryakin should be excluded
    $this->assert_equals(0, scalar(keys %actionees));
}

sub testOpenActions {
    my $this = shift;
    my $attrs = new TWiki::Attrs("open",1);
    my $actions = TWiki::Plugins::ActionTrackerPlugin::ActionSet::allActionsInWeb($this->{test_web}, $attrs, 0 );
    my $fmt = $textonlyfmt;
    my $chosen = $actions->formatAsString($fmt);
    $this->assert_not_null($chosen);
    $this->assert_matches(qr/C_open_ontime/o, $chosen);
    $this->assert_matches(qr/A_open_late/o, $chosen);
    $this->assert_matches(qr/$this->{test_user_wikiname}_open_late/o, $chosen);
    $this->assert_does_not_match(qr/A_closed_ontime/o, $chosen);
    $this->assert_does_not_match(qr/B_open_ontime/o, $chosen);
    my %actionees;
    $actions->getActionees(\%actionees);
    $this->assert_not_null($actionees{"$TWiki::cfg{UsersWebName}.A"});
    delete($actionees{"$TWiki::cfg{UsersWebName}.A"});
    $this->assert_not_null($actionees{"$TWiki::cfg{UsersWebName}.C"});
    delete($actionees{"$TWiki::cfg{UsersWebName}.C"});
    $this->assert_not_null($actionees{"$TWiki::cfg{UsersWebName}.$this->{test_user_wikiname}"});
    delete($actionees{"$TWiki::cfg{UsersWebName}.$this->{test_user_wikiname}"});
    $this->assert_equals(0, scalar(keys %actionees));
}

sub testLateActions {
    my $this = shift;
    my $attrs = new TWiki::Attrs("late",1);
    my $actions = TWiki::Plugins::ActionTrackerPlugin::ActionSet::allActionsInWeb($this->{test_web}, $attrs, 0 );
    my $fmt = $textonlyfmt;
    my $chosen = $actions->formatAsString($fmt);

    $this->assert_does_not_match(qr/C_open_ontime/o, $chosen);
    $this->assert_matches(qr/A_open_late/o, $chosen);
    $this->assert_matches(qr/$this->{test_user_wikiname}_open_late/o, $chosen);
    $this->assert_does_not_match(qr/A_closed_ontime/o, $chosen);
    $this->assert_does_not_match(qr/B_open_ontime/o, $chosen);
    my %actionees;
    $actions->getActionees(\%actionees);
    $this->assert_not_null($actionees{"$TWiki::cfg{UsersWebName}.A"});
    delete($actionees{"$TWiki::cfg{UsersWebName}.A"});
    $this->assert_not_null($actionees{"$TWiki::cfg{UsersWebName}.$this->{test_user_wikiname}"});
    delete($actionees{"$TWiki::cfg{UsersWebName}.$this->{test_user_wikiname}"});
    $this->assert_equals(0, scalar(keys %actionees));
}

sub testMyActions {
    my $this = shift;
    my $attrs = new TWiki::Attrs("who=$this->{test_user_wikiname}", 1);
    my $actions = TWiki::Plugins::ActionTrackerPlugin::ActionSet::allActionsInWeb($this->{test_web}, $attrs, 0);
    my $fmt = $textonlyfmt;
    my $chosen = $actions->formatAsString($fmt);
    $this->assert_not_null($chosen);
    $this->assert_does_not_match(qr/C_open_ontime/o, $chosen);
    $this->assert_does_not_match(qr/A_open_late/o, $chosen);
    $this->assert_does_not_match(qr/A_closed_ontime/o, $chosen);
    $this->assert_does_not_match(qr/B_open_ontime/o, $chosen);
    $this->assert_matches(qr/$this->{test_user_wikiname}_open_late/o, $chosen);
    my %actionees;
    $actions->getActionees(\%actionees);
    $this->assert_not_null($actionees{"$TWiki::cfg{UsersWebName}.$this->{test_user_wikiname}"});
    delete($actionees{"$TWiki::cfg{UsersWebName}.$this->{test_user_wikiname}"});
    $this->assert_equals(0, scalar(keys %actionees));
}

1;
