package ActionNotifyTests;
use base qw(FoswikiFnTestCase);

use strict;

use TWiki::Plugins::ActionTrackerPlugin::Action;
use TWiki::Plugins::ActionTrackerPlugin::ActionSet;
use TWiki::Plugins::ActionTrackerPlugin::ActionNotify;
use TWiki::Plugins::ActionTrackerPlugin::Format;
use TWiki::Plugins::ActionTrackerPlugin::Options;
use Time::ParseDate;
use TWiki::Attrs;
use TWiki::Store::RcsLite;

sub new {
    my $self = shift()->SUPER::new('ActionNotify', @_);
    return $self;
}

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
    $TWiki::cfg{Plugins}{ActionTrackerPlugin}{Enabled} = 1;

    # Use RcsLite so we can manually gen topic revs
    $TWiki::cfg{StoreImpl} = 'RcsLite';

    # Need this to get the actionnotify template
    foreach my $lib (@INC) {
        my $d = "$lib/../templates";
        if (-e "$d/actionnotify.tmpl") {
            $TWiki::cfg{TemplateDir} = $d;
            last;
        }
    }

    TWiki::Plugins::ActionTrackerPlugin::Action::forceTime("3 Jun 2002");

    # Actor 1 - wikiname in main, not a member of any groups
    # email: actor-1\@an-address.net
    # Should be notified with: A3 A6
    # Actor 2 - wikiname in main and member of emailgroup only
    # email: actorTwo\@another-address.net
    # Should be notified with: A3 A5 A6
    # Actor 3 - wikiname in main and member of twikigroup only
    # email: actor3\@yet-another-address.net
    # Should be notified with: A3 A4 A6
    # Actor 4 - wikiname in main and member of emailgroup and twikigroup
    # email: actorfour\@yet-another-address.net
    # Should be notified with: A3 A4 A5 A6
    # Actor 5 - wikiname in main, address in Main.WebNotify
    # email: actor5\@correct.address
    # Should be notified with: A3 A6 A7
    # Actor 6 - wikiname in main and wrong address in Main.WebNotify
    # email: actor6\@correct-address
    # Should be notified with: A3 A6 A8
    # Actor 7 - email address on action line
    # email: actor.7\@seven.net
    # Should be notified with: A3 A6
    # Actor 8 - no topic in main, address in Test.WebNotify
    # email: actor-8\@correct.address
    # Should be notified with: A3 A6 A8

    # A1 - on time - should never be notified
    # A2 - closed - should never be notified
    # A3 - open, late - notify everybody
    # A4 - notify TWikiFormGroup, Actor3,Actor4
    # A5 - notify EMailGroup, Actor2,Actor4
    # A6 - notify everyone many times
    # A7 - notify changes to Actor5
    # A8 - notify changes to Actor6, Actor8

    $this->registerUser("ActorOne", "Actor", "One", 'actor-1@an-address.net');
    $this->registerUser("ActorTwo", "Actor", "Two",
                        'actorTwo@another-address.net');
    $this->registerUser("ActorThree", "Actor", "Three",
                        'actor3@yet-another-address.net');
    $this->registerUser("ActorFour", "Actor", "Four",
                        'actorfour@yet-another-address.net');
    $this->registerUser("ActorFive", "Actor", "Five",
                        'actor5@example.com');
    $this->registerUser("ActorSix", "Actor", "Six",
                        'actor6@correct-address');

    TWiki::Func::saveTopic($this->{users_web}, "TWikiFormGroup", undef, <<'HERE');
Garbage
      * Set GROUP = ActorThree, ActorFour
More garbage
HERE
    TWiki::Func::saveTopic($this->{users_web}, "WebNotify", undef, <<HERE);
Garbage
   * $this->{users_web}.ActorFive - actor5\@correct.address
More garbage
   * $this->{users_web}.ActorSix
HERE
    TWiki::Func::saveTopic($this->{test_web}, "WebNotify", undef, <<HERE
   * $this->{users_web}.ActorEight - actor-8\@correct.address
HERE
                              );
    TWiki::Func::saveTopic($this->{users_web}, "EMailGroup", undef, <<'HERE');
   * Set GROUP = actorTwo@another-address.net,ActorFour
HERE

    TWiki::Func::saveTopic($this->{test_web}, "Topic1", undef, <<'HERE');
%ACTION{who="ActorOne,ActorTwo,ActorThree,ActorFour,ActorFive,ActorSix,ActorSeven,ActorEight" due="3 Jan 02" state=open}% A1: ontime
HERE
    TWiki::Func::saveTopic($this->{test_web}, "Topic2", undef, <<'HERE');
%ACTION{who="ActorOne,ActorTwo,ActorThree,ActorFour,ActorFive,ActorSix,actor.7@seven.net,ActorEight" due="2 Jan 02" state=closed}% A2: closed
HERE
    TWiki::Func::saveTopic($this->{users_web}, "Topic1", undef, <<'HERE');
%ACTION{who="ActorOne,ActorTwo,ActorThree,ActorFour,ActorFive,ActorSix,actor.7@seven.net,ActorEight,NonEntity",due="3 Jan 01",state=open}% A3: late
%ACTION{who=TWikiFormGroup,due="4 Jan 01",state=open}% A4: late 
HERE
    TWiki::Func::saveTopic($this->{users_web}, "Topic2", undef, <<'HERE');
%ACTION{who=EMailGroup,due="2001-01-05",state=open}% A5: late
%ACTION{who="ActorOne,ActorTwo,ActorThree,ActorFour,TWikiFormGroup,ActorFive,ActorSix,actor.7@seven.net,ActorEight,EMailGroup",due="6 Jan 99",open}% A6: late
HERE

    my $rcs = new TWiki::Store::RcsLite($this->{twiki}, $this->{test_web}, "ActionChanged" );
    my $t1 = Time::ParseDate::parsedate("21 Jun 2001");
    $rcs->addRevisionFromText(<<HERE, 'Initial revision', 'crawford', $t1);
%META:TOPICINFO{author="guest" date="$t1" format="1.0" version="1.1"}%
%ACTION{uid="666" who=ActorFive,due="2001-06-22",notify=$this->{users_web}.ActorFive}% A7: Date change
%ACTION{who="$this->{users_web}.ActorFour",due="2001-07-22",notify=ActorFive}% A8: Text change
%ACTION{uid=1234 who=NonEntity notify=ActorFive}% A9: No change
HERE

    my $t2 = Time::ParseDate::parsedate("21 Jun 2003");
    $rcs->addRevisionFromText(<<HERE, '*** empty log message ***', 'crawford', $t2);
%META:TOPICINFO{author="guest" date="$t2" format="1.0" version="1.2"}%
%ACTION{uid="666" who=ActorFive,due="2002-06-22",notify=$this->{users_web}.ActorFive}% A7: Date change
%ACTION{who=EMailGroup,due="5 Jan 01",state=open,notify=nobody}% No change
%ACTION{who=ActorFive,due="2002-06-22" notify=$this->{users_web}.ActorOne}% Stuck in
%ACTION{who=ActorSix,due="2001-07-22",notify="$this->{users_web}.ActorSix,$this->{users_web}.ActorEight"}% A8: Text cha
nge from original, late
%ACTION{uid=1234 who=NonEntity notify=ActorFive}% A9: No change
HERE
    @FoswikiFnTestCase::mails = ();
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
}

sub test_A_AddressExpansion {
    my $this = shift;
    my %ma = (
        $this->{users_web}.'.BonzoClown' => 'bonzo@circus.com',
        $this->{users_web}.'.BimboChimp' => 'bimbo@zoo.org',
        $this->{users_web}.'.PaxoHen' => 'chicken@farm.net'
       );
    my $who =
      TWiki::Plugins::ActionTrackerPlugin::ActionNotify::_getMailAddress('a@b.c',\%ma);
    $this->assert_str_equals( 'a@b.c', $who);

    $who =
      TWiki::Plugins::ActionTrackerPlugin::ActionNotify::_getMailAddress("$this->{users_web}.BimboChimp",\%ma);
    $this->assert_str_equals( 'bimbo@zoo.org', $who);

    $who =
      TWiki::Plugins::ActionTrackerPlugin::ActionNotify::_getMailAddress("BimboChimp",\%ma);
    $this->assert_str_equals( 'bimbo@zoo.org', $who);

    $who =
      TWiki::Plugins::ActionTrackerPlugin::ActionNotify::_getMailAddress("PaxoHen,BimboChimp , BonzoClown",\%ma);
    $this->assert_str_equals( 'chicken@farm.net,bimbo@zoo.org,bonzo@circus.com', $who);

    $who = TWiki::Plugins::ActionTrackerPlugin::ActionNotify::_getMailAddress("ActorOne",\%ma);
    $this->assert_str_equals( 'actor-1@an-address.net', $who);

    $who = TWiki::Plugins::ActionTrackerPlugin::ActionNotify::_getMailAddress("EMailGroup",\%ma);
    $this->assert_str_equals( "actorTwo\@another-address.net,actorfour\@yet-another-address.net", $who);
    $who = TWiki::Plugins::ActionTrackerPlugin::ActionNotify::_getMailAddress("TWikiFormGroup",\%ma);
    $this->assert_str_equals( "actor3\@yet-another-address.net,actorfour\@yet-another-address.net", $who);

    $who = TWiki::Plugins::ActionTrackerPlugin::ActionNotify::_getMailAddress("ActorFive",\%ma);
    $this->assert_str_equals('actor5@example.com', $who);
    $who = TWiki::Plugins::ActionTrackerPlugin::ActionNotify::_getMailAddress("ActorEight",\%ma);
    $this->assert_null($who);
    TWiki::Plugins::ActionTrackerPlugin::ActionNotify::_loadWebNotify($this->{users_web},\%ma);
    $who = TWiki::Plugins::ActionTrackerPlugin::ActionNotify::_getMailAddress("ActorFive",\%ma);
    $this->assert_str_equals( "actor5\@example.com", $who);
    TWiki::Plugins::ActionTrackerPlugin::ActionNotify::_loadWebNotify($this->{test_web},\%ma);
    $who = TWiki::Plugins::ActionTrackerPlugin::ActionNotify::_getMailAddress("ActorEight",\%ma);
    $this->assert_str_equals( "actor-8\@correct.address", $who);
}

sub test_B_NotifyLate {
    my $this = shift;
    my $html;

    TWiki::Plugins::ActionTrackerPlugin::Action::forceTime("2 Jan 2002");
    TWiki::Plugins::ActionTrackerPlugin::ActionNotify::doNotifications($this->{twiki}->{webName}, "web='($this->{test_web}|$this->{users_web})' late" );
    if(scalar(@FoswikiFnTestCase::mails!= 8)) {
        my $mess = scalar(@FoswikiFnTestCase::mails)." mails received";
        while ( $html = shift(@FoswikiFnTestCase::mails)) {
            $html =~ m/^(To: .*)$/m;
            $mess .= "$1\n";
        }
        $this->assert(0, $mess);
    }

    my $ok = "";
    while ( $html = shift(@FoswikiFnTestCase::mails)) {
        $this->assert_does_not_match(qr/A[12]:/, $html, $html);
        if ($html =~ /To: actor-1\@an-address\.net/) {
            $this->assert_matches(qr/A3:/,$html, $html);
            $this->assert_does_not_match(qr/A4:/,$html, $html);
            $this->assert_does_not_match(qr/A5:/,$html, $html);
            $this->assert_matches(qr/A6:/,$html, $html);
            $this->assert_does_not_match(qr/A7:/,$html, $html);
            $this->assert_does_not_match(qr/A8:/,$html, $html);
            $ok .= "A";
        } elsif ($html =~ /To: actorTwo\@another-address\.net/) {
            $this->assert_matches(qr/A3:/,$html, $html);
            $this->assert_does_not_match(qr/A4:/,$html, $html);
            $this->assert_matches(qr/A5:/,$html, $html);
            $this->assert_matches(qr/A6:/,$html, $html);
            $this->assert_does_not_match(qr/A7:/,$html, $html);
            $this->assert_does_not_match(qr/A8:/,$html, $html);
            $ok .= "B";
        } elsif ($html =~ /To: actor3\@yet-another-address\.net/) {
            $this->assert_matches(qr/A3:/,$html, $html);
            $this->assert_matches(qr/A4:/,$html, $html);
            $this->assert_does_not_match(qr/A5:/,$html, $html);
            $this->assert_matches(qr/A6:/,$html, $html);
            $this->assert_does_not_match(qr/A7:/,$html, $html);
            $this->assert_does_not_match(qr/A8:/,$html, $html);
            $ok .= "C";
        } elsif ($html =~ /To: actorfour\@yet-another-address\.net/) {
            $this->assert_matches(qr/A3:/,$html, $html);
            $this->assert_matches(qr/A4:/,$html, $html);
            $this->assert_matches(qr/A5:/,$html, $html);
            $this->assert_matches(qr/A6:/,$html, $html);
            $this->assert_does_not_match(qr/A7:/,$html, $html);
            $this->assert_does_not_match(qr/A8:/,$html, $html);
            $ok .= "D";
        } elsif ($html =~ /To: actor5\@example.com/) {
            $this->assert_matches(qr/A3:/,$html, $html);
            $this->assert_does_not_match(qr/A4:/,$html, $html);
            $this->assert_does_not_match(qr/A5:/,$html, $html);
            $this->assert_matches(qr/A6:/,$html, $html);
            $this->assert_does_not_match(qr/A7:/,$html, $html);
            $this->assert_does_not_match(qr/A8:/,$html, $html);
            $ok .= "E";
        } elsif ($html =~ /To: actor6\@correct-address/) {
            $this->assert_matches(qr/A3:/,$html, $html);
            $this->assert_does_not_match(qr/A4:/,$html, $html);
            $this->assert_does_not_match(qr/A5:/,$html, $html);
            $this->assert_matches(qr/A6:/,$html, $html);
            $this->assert_does_not_match(qr/A7:/,$html, $html);
            $this->assert_matches(qr/A8:/,$html, $html);
            $ok .= "F";
        } elsif ($html =~ /To: actor\.7\@seven\.net/) {
            $this->assert_matches(qr/A3:/,$html, $html);
            $this->assert_does_not_match(qr/A4:/,$html, $html);
            $this->assert_does_not_match(qr/A5:/,$html, $html);
            $this->assert_matches(qr/A6:/,$html, $html);
            $this->assert_does_not_match(qr/A7:/,$html, $html);
            $this->assert_does_not_match(qr/A8:/,$html, $html);
            $ok .= "G";
        } elsif ($html =~ /To: actor-8\@correct\.address/) {
            $this->assert_matches(qr/A3:/,$html, $html);
            $this->assert_does_not_match(qr/A4:/,$html, $html);
            $this->assert_does_not_match(qr/A5:/,$html, $html);
            $this->assert_matches(qr/A6:/,$html, $html);
            $this->assert_does_not_match(qr/A7:/,$html, $html);
            $this->assert_does_not_match(qr/A8:/,$html, $html);
            $ok .= "H";
        } else {
            $this->assert(0, $html);
        }
    }
    $this->assert_num_equals(8, length($ok));
    $this->assert_matches(qr/A/, $ok);
    $this->assert_matches(qr/B/, $ok);
    $this->assert_matches(qr/C/, $ok);
    $this->assert_matches(qr/D/, $ok);
    $this->assert_matches(qr/E/, $ok);
    $this->assert_matches(qr/F/, $ok);
    $this->assert_matches(qr/G/, $ok);
    $this->assert_matches(qr/H/, $ok);
}

sub test_C_ChangedSince {
    my $this = shift;
    TWiki::Plugins::ActionTrackerPlugin::Action::forceTime("2 Jan 2002");
    TWiki::Plugins::ActionTrackerPlugin::ActionNotify::doNotifications(
        $this->{twiki}->{webName}, 'changedsince="1 dec 2001" web="'.$this->{test_web}.'"' );
    my $saw = "";
    my $html;

    if (scalar(@FoswikiFnTestCase::mails)!= 1) {
        my $mess = $this->{twiki}->{webName}.' '.
          scalar(@FoswikiFnTestCase::mails)." mails received, expected 1";
        while ( $html = shift(@FoswikiFnTestCase::mails)) {
            $html =~ m/^(To: .*)$/m;
            $mess .= "$1\n";
            $html =~ m/(Attribute .*)$/m;
            $mess .= "$1\n";
        }
        $this->assert(0, "$mess\n");
    }
    while( $html = shift(@FoswikiFnTestCase::mails) ) {
        my $re = qr/^From: /m;
        $this->assert_matches($re, $html);
        $re = qr/^Subject: .*Changes to actions /m;
        $this->assert_matches($re, $html);
        if ($html=~ /To: actor5\@example.com/) {
            $re = qr/Changes to actions since 01 Dec 2001 - 00:00/;
            $this->assert_matches($re, $html);
            $re = qr/Attribute "due" changed, was "Fri, 22 Jun 2001 \(LATE\)", now "Sat, 22 Jun 2002"/;
            $this->assert_matches($re, $html);
            $saw .= "A";
        } else {
            $this->assert(0, "Not good $html");
        }
    }
    $this->assert_num_equals(1, length($saw));
    $this->assert_matches(qr/A/, $saw);

}

1;
