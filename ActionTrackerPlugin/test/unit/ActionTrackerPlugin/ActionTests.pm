# Tests for module Action.pm
package ActionTests;
use base qw( FoswikiFnTestCase );

use strict;

use TWiki::Plugins::ActionTrackerPlugin::Action;
use TWiki::Plugins::ActionTrackerPlugin::Format;
use Time::ParseDate;
use CGI;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

# Have to do this to force a read of the configuration
BEGIN {
    new TWiki();
    $TWiki::cfg{Plugins}{ActionTrackerPlugin}{Enabled} = 1;
};

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
    TWiki::Plugins::ActionTrackerPlugin::Action::forceTime("31 May 2002");
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
    TWiki::Plugins::ActionTrackerPlugin::Action::unextendTypes();
}

sub test_NewNoState {
    my $this = shift;

    # no state -> first state
    my $action = new TWiki::Plugins::ActionTrackerPlugin::Action(
        "Test","Topic",0,"", "");
    $this->assert_str_equals("open", $action->{state}, $action->stringify());
    # closed defined -> closed state
    $action = new TWiki::Plugins::ActionTrackerPlugin::Action(
        "Test","Topic",0,"closed", "");
    $this->assert_str_equals("closed", $action->{state});
    $action =
      new TWiki::Plugins::ActionTrackerPlugin::Action(
          "Test","Topic",0,"closed=10-may-05", "");
    $this->assert_str_equals("closed", $action->{state});
    $action =
      TWiki::Plugins::ActionTrackerPlugin::Action->new(
          "Test","Topic",0,"closer=Flicka", "");
    $this->assert_str_equals("open", $action->{state});
    # state def overrides closed defined
    $action =
      new TWiki::Plugins::ActionTrackerPlugin::Action(
          "Test","Topic",0,"",'closed,state="open"');
    $this->assert_str_equals("open", $action->{state});
}

sub test_NewIgnoreAttrs {
    my $this = shift;

    my $action =
      new TWiki::Plugins::ActionTrackerPlugin::Action(
          "Test","Topic2",0,
          "web=Wrong,topic=Wrong web=Right", "");
    $this->assert_str_equals("Test", $action->{web});
    $this->assert_str_equals("Topic2", $action->{topic});
}

sub test_IsLateAndDaysToGo {
    my $this = shift;

    my $action =
      new TWiki::Plugins::ActionTrackerPlugin::Action(
          "Test","Topic",0,
          'who="Who" due="2 Jun 02" open', "");
    $this->assert(!$action->isLate());
    $this->assert_num_equals(2, $action->daysToGo());
    TWiki::Plugins::ActionTrackerPlugin::Action::forceTime(
        "1 Jun 2002 23:59:59");
    $this->assert(!$action->isLate());
    $this->assert_num_equals(0, $action->daysToGo());
    TWiki::Plugins::ActionTrackerPlugin::Action::forceTime(
        "2 Jun 2002 00:00:01");
    $this->assert($action->isLate());
    $this->assert_num_equals(-1, $action->daysToGo());
    TWiki::Plugins::ActionTrackerPlugin::Action::forceTime(
        "3 Jun 2002 00:00:01");
    $this->assert($action->isLate());
    $this->assert_num_equals(-1, $action->daysToGo());
    TWiki::Plugins::ActionTrackerPlugin::Action::forceTime(
        "4 Jun 2002 00:00:01");
    $this->assert($action->isLate());
    $this->assert_num_equals(-2, $action->daysToGo());
    $action = new
      TWiki::Plugins::ActionTrackerPlugin::Action(
          "Test","Topic",0,
          'who="Who" due="2 Jun 02" closed', "");
    $this->assert(!$action->isLate());
}

sub test_Commas {
    my $this = shift;

    my $action =
      new TWiki::Plugins::ActionTrackerPlugin::Action(
          "Test", "Topic", 0,
          'who="JohnDoe, SlyStallone",due="2 Jun 02",notify="SamPeckinpah, QuentinTarantino",creator="ThomasMoore"',
          "Sod");
    $this->assert_str_equals("$this->{users_web}.JohnDoe, $this->{users_web}.SlyStallone", $action->{who});
    $this->assert_str_equals(
        "$this->{users_web}.SamPeckinpah, $this->{users_web}.QuentinTarantino", $action->{notify});
}

sub test_MatchesOpen {
    my $this = shift;

    my $action =
      new TWiki::Plugins::ActionTrackerPlugin::Action(
          "Test", "Topic", 0,
          'who="JohnDoe,SlyStallone,'.$TWiki::cfg{DefaultUserWikiName}.'" due="2 Jun 02" state=open notify="SamPeckinpah,QuentinTarantino" created="1999-01-01" creator="ThomasMoore"',
          "A new action");

    my $attrs = new TWiki::Attrs("who=JohnDoe",1);
    $this->assert($action->matches($attrs),$attrs->stringify());
    $attrs = new TWiki::Attrs("who=$this->{users_web}.JohnDoe",1);
    $this->assert($action->matches($attrs));
    $attrs = new TWiki::Attrs("who=me",1);
    $this->assert($action->matches($attrs));
    $attrs = new TWiki::Attrs("who=JohnSmith",1);
    $this->assert(!$action->matches($attrs));
    $attrs = new TWiki::Attrs("who=$this->{users_web}.SlyStallone",1);
    $this->assert($action->matches($attrs));
    $attrs = new TWiki::Attrs("who",1);
    $this->assert(!$action->matches($attrs));

    $attrs = new TWiki::Attrs('notify="SamPeckinpah"',1);
    $this->assert($action->matches($attrs));
    $attrs = new TWiki::Attrs('notify="QuentinTarantino"',1);
    $this->assert($action->matches($attrs));
    $attrs = new TWiki::Attrs('notify="JonasSalk,QuentinTarantino"',1);
    $this->assert($action->matches($attrs));
    $attrs = new TWiki::Attrs('notify="SamBrowne,OscarWilde"',1);
    $this->assert(!$action->matches($attrs));
    $attrs = new TWiki::Attrs("notify",1); 
    $this->assert(!$action->matches($attrs));

    $attrs = new TWiki::Attrs('state="open"',1);
    $this->assert($action->matches($attrs));
    $attrs = new TWiki::Attrs("open",1);
    $this->assert($action->matches($attrs));
    $attrs = new TWiki::Attrs("openday",1);
    $this->assert(!$action->matches($attrs));
    $attrs = new TWiki::Attrs('state="(?!closed).*"',0);
    $this->assert($action->matches($attrs));

    TWiki::Plugins::ActionTrackerPlugin::Action::forceTime("4 Jun 2002");
    $attrs = new TWiki::Attrs("within='+2'",1);
    $this->assert(!$action->matches($attrs));
    $attrs = new TWiki::Attrs("within='2'",1);
    $this->assert($action->matches($attrs));
    $attrs = new TWiki::Attrs("within='+1'",1);
    $this->assert(!$action->matches($attrs));
    $attrs = new TWiki::Attrs("within='1'",1);
    $this->assert(!$action->matches($attrs));
    $attrs = new TWiki::Attrs("within='-1'",1);
    $this->assert(!$action->matches($attrs));
    $attrs = new TWiki::Attrs("within='-2'",1);
    $this->assert($action->matches($attrs));

    TWiki::Plugins::ActionTrackerPlugin::Action::forceTime("31 May 2002");
    $attrs = new TWiki::Attrs("within='+2'",1);
    $this->assert($action->matches($attrs));
    $attrs = new TWiki::Attrs("within='2'",1);
    $this->assert($action->matches($attrs));
    $attrs = new TWiki::Attrs("within='+1'",1);
    $this->assert(!$action->matches($attrs));
    $attrs = new TWiki::Attrs("within='1'",1);
    $this->assert(!$action->matches($attrs));
    $attrs = new TWiki::Attrs("within='-2'",1);
    $this->assert(!$action->matches($attrs));

    $attrs = new TWiki::Attrs("late",1);
    $this->assert(!$action->matches($attrs));

    $attrs = new TWiki::Attrs("web=Test",1);
    $this->assert($action->matches($attrs));
    $attrs = new TWiki::Attrs('web=".*t"',1);
    $this->assert($action->matches($attrs));
    $attrs = new TWiki::Attrs('web="A.*"',1);
    $this->assert(!$action->matches($attrs));

    $attrs = new TWiki::Attrs("topic=Topic",1);
    $this->assert($action->matches($attrs));
    $attrs = new TWiki::Attrs('topic=".*c"',1);
    $this->assert($action->matches($attrs));
    $attrs = new TWiki::Attrs('topic="A.*"',1);
    $this->assert(!$action->matches($attrs));

    $attrs = new TWiki::Attrs('due="2 Jun 02"',1);
    $this->assert($action->matches($attrs));
    $attrs = new TWiki::Attrs('due="3 Jun 02"',1);
    $this->assert(!$action->matches($attrs));
    $attrs = new TWiki::Attrs('due="< 3 Jun 02"',1);
    $this->assert($action->matches($attrs));
    $attrs = new TWiki::Attrs('due="> 3 Jun 02"',1);
    $this->assert(!$action->matches($attrs));
    $attrs = new TWiki::Attrs('due="> 1 Jun 02"',1);
    $this->assert($action->matches($attrs));
    $attrs = new TWiki::Attrs('due="< 1 Jun 02"',1);
    $this->assert(!$action->matches($attrs));

    $attrs = new TWiki::Attrs("creator=ThomasMoore",1);
    $this->assert($action->matches($attrs));
    $attrs = new TWiki::Attrs("creator=QuentinTarantino",1);
    $this->assert(!$action->matches($attrs));

    $attrs = new TWiki::Attrs('created="1999-01-01"',1);
    $this->assert($action->matches($attrs));
    $attrs = new TWiki::Attrs('created="2 Jun 02"',1);
    $this->assert(!$action->matches($attrs));
    $attrs = new TWiki::Attrs('created="2 Jan 1999"',1);
    $this->assert(!$action->matches($attrs));
    $attrs = new TWiki::Attrs('created="< 2 Jan 1999"',1);
    $this->assert($action->matches($attrs));
    $attrs = new TWiki::Attrs('created="> 2 Jan 1999"',1);
    $this->assert(!$action->matches($attrs));
    $attrs = new TWiki::Attrs('created=">= 1 Jan 1999"',1);
    $this->assert($action->matches($attrs));
    $attrs = new TWiki::Attrs('created="< 1 Jan 1999"',1);
    $this->assert(!$action->matches($attrs));

    $attrs = new TWiki::Attrs("closed",1);
    $this->assert(!$action->matches($attrs));
    $attrs = new TWiki::Attrs('closed="2 Jun 02"',1);
    $this->assert(!$action->matches($attrs));
    $attrs = new TWiki::Attrs('closed="1 Jan 1999"',1);
    $this->assert(!$action->matches($attrs));

    # make it late
    TWiki::Plugins::ActionTrackerPlugin::Action::forceTime("3 Jun 2002");
    $attrs = new TWiki::Attrs("late",1);
    $this->assert($action->matches($attrs));

    $attrs = new TWiki::Attrs("within=-1",1);
    $this->assert($action->matches($attrs), $action->secsToGo());
    $attrs = new TWiki::Attrs("within=+1",1);
    $this->assert(!$action->matches($attrs), $action->secsToGo());
}

sub test_MatchesClosed {
    my $this = shift;

    my $action = new TWiki::Plugins::ActionTrackerPlugin::Action(
        "Test", "Topic", 0,
        'who="JohnDoe,SlyStallone",due="2 Jun 02" closed="2 Dec 00" closer="Death" notify="SamPeckinpah,QuentinTarantino" created="1 Jan 1999" creator="ThomasMoore"',
        "A new action");
    my $attrs = new TWiki::Attrs("closed",1,1);
    $this->assert($action->matches($attrs), $action->stringify());
    $attrs = new TWiki::Attrs('closed="2 Dec 00"',1);
    $this->assert($action->matches($attrs));
    $attrs = new TWiki::Attrs('closed="> 1 Dec 00"',1);
    $this->assert($action->matches($attrs));
    $attrs = new TWiki::Attrs('closed="< 1 Dec 00"',1);
    $this->assert(!$action->matches($attrs));
    $attrs = new TWiki::Attrs('closed="2 Dec 01"',1);
    $this->assert(!$action->matches($attrs));

    $attrs = new TWiki::Attrs("closer=Death",1,1);
    $this->assert($action->matches($attrs));
    $attrs = new TWiki::Attrs("open",1);
    $this->assert(!$action->matches($attrs));
}

sub test_StringFormattingOpen {
    my $this = shift;

    my $action = new TWiki::Plugins::ActionTrackerPlugin::Action(
        "Test", "Topic", 0,
        'who="JohnDoe" due="2 Jun 02" state=open notify="SamPeckinpah,QuentinTarantino" created="1 Jan 1999" creator="ThomasMoore"',
        "A new action");
    my $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format(
        "|Who|Due|","|\$who|","","Who: \$who \$who","\$who,\$due");
    my $s = $fmt->formatStringTable([$action]);
    $this->assert_str_equals("Who: $this->{users_web}.JohnDoe $this->{users_web}.JohnDoe\n",$s,
                             $fmt->stringify());
    $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format(
        "","","","Due: \$due");
    # make it late
    TWiki::Plugins::ActionTrackerPlugin::Action::forceTime("3 Jun 2002");
    $s = $fmt->formatStringTable([$action]);
    $this->assert_str_equals("Due: Sun, 02 Jun 2002 (LATE)\n", $s);
    # make it ontime
    TWiki::Plugins::ActionTrackerPlugin::Action::forceTime("1 Jun 2002");
    $s = $fmt->formatStringTable([$action]);
    $this->assert_str_equals("Due: Sun, 02 Jun 2002\n", $s);
    # make it late again
    TWiki::Plugins::ActionTrackerPlugin::Action::forceTime("3 Jun 2002");
    $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format(
        "","","", "State: \$state\n");
    $s = $fmt->formatStringTable([$action]);
    $this->assert_str_equals("State: open\n\n", $s);
    $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format(
        "","", "","Notify: \$notify\n");
    $s = $fmt->formatStringTable([$action]);
    $this->assert_str_equals(
        "Notify: $this->{users_web}.SamPeckinpah, $this->{users_web}.QuentinTarantino\n\n", $s);
    $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format(
        "","", "", "\$creator");
    $s = $fmt->formatStringTable([$action]);
    $this->assert_str_equals($s, "$this->{users_web}.ThomasMoore\n");
    $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format(
        "","", "","|\$created|");
    $s = $fmt->formatStringTable([$action]);
    $this->assert_str_equals("|Fri, 01 Jan 1999|\n", $s);
    $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format(
        "","", "","|\$edit|");
    $s = $fmt->formatStringTable([$action]);
    $this->assert_str_equals("||\n", $s);
    $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format(
        "","", "","\$web.\$topic");
    $s = $fmt->formatStringTable([$action]);
    $this->assert_str_equals("Test.Topic\n", $s);
    $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format(
        "","", "", 'Text "$text"');
    $s = $fmt->formatStringTable([$action]);
    $this->assert_str_equals("Text \"A new action\"\n", $s);
    $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format(
        "","", "","|\$n\$n()\$nop()\$quot\$percnt\$dollar|");
    $s = $fmt->formatStringTable([$action]);
    $this->assert_str_equals("|\n\n\"%\$|\n", $s);
    $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format(
        "","","","Who: \$who Creator: \$creator");
    $s = $fmt->formatStringTable([$action]);
    $this->assert_str_equals(
        $s, "Who: $this->{users_web}.JohnDoe Creator: $this->{users_web}.ThomasMoore\n");
}

sub test_StringFormattingClosed {
    my $this = shift;

    my $action = new TWiki::Plugins::ActionTrackerPlugin::Action(
        "Test","Topic", 0,
        'who=JohnDoe due="2 Jun 02" closed="1-Jan-03" closer="LucBesson"',
        "A new action");
    my $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format(
        "","", "", "|\$closed|\$closer|");
    my $s = $fmt->formatStringTable([$action]);
    $this->assert_str_equals(
        $s, "|Wed, 01 Jan 2003|$this->{users_web}.LucBesson|\n");
}

sub test_VerticalOrient {
    my $this = shift;

    TWiki::Plugins::ActionTrackerPlugin::Action::forceTime("31 May 2002");
    my $action = TWiki::Plugins::ActionTrackerPlugin::Action->new(
        "Test", "Topic", 0,
        'who=JohnDoe due="2 Jun 02" state=open notify="SamPeckinpah,QuentinTarantino" created="1 Jan 1999" creator="ThomasMoore"',
        "A new action");
    my $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format(
        "|Who|Due|", "|\$who|\$due|", "rows");
    my $s = $fmt->formatHTMLTable([$action], "name", 0, 'atp');
    $s =~ s/<table class=\"atp\">//;
    $s =~ s/<\/table>//;
    $s =~ s/\n//g;
    $this->assert_str_equals("<tr><th>Who</th><td><a name=\"AcTion0\" />$this->{users_web}.JohnDoe</td></tr><tr><th>Due</th><td><span class=\"atpOpen\">Sun, 02 Jun 2002</span></td></tr>", $s);
}

sub test_HTMLFormattingOpen {
    my $this = shift;

    my $action = TWiki::Plugins::ActionTrackerPlugin::Action->new(
        "Test", "Topic", 0,
        'who=JohnDoe due="2 Jun 02" state=open notify="SamPeckinpah,QuentinTarantino, DavidLynch" created="1 Jan 1999" creator="ThomasMoore"',
        "A new action");

    my $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format("", "|\$who|");
    my $s = $fmt->formatHTMLTable([$action], "name", 0, 'atp');
    $this->assert_html_matches(
        "<td><a name=\"AcTion0\" />$this->{users_web}.JohnDoe</td>", $s);
    $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format("", "| \$due |");
    # make it late
    TWiki::Plugins::ActionTrackerPlugin::Action::forceTime("3 Jun 2002");
    $s = $fmt->formatHTMLTable([$action], "href", 0, 'atp');
    $this->assert_html_matches(
        "<td> <span class=\"atpWarn\">Sun, 02 Jun 2002</span> </td>", $s);

    # make it ontime
    TWiki::Plugins::ActionTrackerPlugin::Action::forceTime("1 Jun 2002");
    $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format(
        "", "| \$due |", "");
    $s = $fmt->formatHTMLTable([$action], "href", 0, 'atp');
    $this->assert_html_matches(
        "<td> <span class=\"atpOpen\">Sun, 02 Jun 2002</span>  </td>", $s);

    # Make it late again
    TWiki::Plugins::ActionTrackerPlugin::Action::forceTime("3 Jun 2002");
    $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format(
        "", "| \$state |", "");
    $s = $fmt->formatHTMLTable([$action], "href", 0, 'atp');
    $this->assert_html_matches("<td> open </td>", $s );

    $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format("", "| \$notify |");
    $s = $fmt->formatHTMLTable([$action], "href", 0, 'atp');
    $this->assert_html_matches(
        "<td> $this->{users_web}.SamPeckinpah, $this->{users_web}.QuentinTarantino, $this->{users_web}.DavidLynch </td>",
        $s );

    $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format("", "| \$uid |");
    $s = $fmt->formatHTMLTable([$action], "href", 0, 'atp');
    $this->assert_html_matches("<td> &nbsp; </td>", $s );

    $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format(
        "", "| \$creator |", "");
    $s = $fmt->formatHTMLTable([$action], "href", 0, 'atp');
    $this->assert_html_matches("<td> $this->{users_web}.ThomasMoore </td>", $s );

    $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format(
        "", "| \$created |", "");
    $s = $fmt->formatHTMLTable([$action], "href", 0, 'atp');
    $this->assert_html_matches("<td> Fri, 01 Jan 1999 </td>", $s );

    $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format(
        "", "| \$edit |", "");
    my $url = "$TWiki::cfg{DefaultUrlHost}$TWiki::cfg{ScriptUrlPath}/edit$TWiki::cfg{ScriptSuffix}/Test/Topic\\?skin=action%2cpattern;atp_action=AcTion0;t=";
    $s = $fmt->formatHTMLTable([$action], "href", 0 );
    $this->assert($s =~ m(<td> <a href="(.*?)">edit</a> </td>), $s);
    $this->assert($1, $s);
    $this->assert_matches(qr(^$url\d+$), $1);

    $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format(
        "", "| \$edit |", "");
    $s = $fmt->formatHTMLTable([$action], "href", 1, 'atp');
    $this->assert_not_null($s);
    $this->assert($s =~ m(<td>\s*<a (.*?)>edit</a>\s*</td>), $s);
    my $x = $1;
    $this->assert_matches(qr/href="$url\d+"/, $x);
    $this->assert_matches(qr/onclick="return atp_editWindow\('$url\d+'\)"/, $x);

    $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format(
        "", "| \$web.\$topic |", "");
    $s = $fmt->formatHTMLTable([$action], "href", 0, 'atp');
    $this->assert_not_null($s);
    $this->assert_html_matches('<td> Test.Topic </td>', $s );

    $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format(
        "", "| \$text |", "");
    $s = $fmt->formatHTMLTable([$action], "href", 0, 'XXX');
    $this->assert( $s =~ /<td> A new action <a href="$TWiki::cfg{DefaultUrlHost}$TWiki::cfg{ScriptUrlPath}\/view$TWiki::cfg{ScriptSuffix}\/Test\/Topic#AcTion0">/,
        $s );

    $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format(
        "", "| \$n\$n()\$nop()\$quot\$percnt\$dollar |", "");
    $s = $fmt->formatHTMLTable([$action], "href", 0, 'atp');
    $this->assert_html_matches("<td> <br /><br />\"%\$ </td>", $s );

    TWiki::Plugins::ActionTrackerPlugin::Action::forceTime("1 Jun 2002");
    $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format(
        "", "| \$due |", "");
    $s = $fmt->formatHTMLTable([$action], "href", 0, 'atp');
    $this->assert_html_matches(
        "<td> <span class=\"atpOpen\">Sun, 02 Jun 2002</span> </td>", $s );

    $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format(
        "", "|\$who|\$creator|", "");
    $s = $fmt->formatHTMLTable([$action], "name", 0, 'atp');
    $this->assert_html_matches(
        "<td><a name=\"AcTion0\" />$this->{users_web}.JohnDoe</td><td>$this->{users_web}.ThomasMoore</td>",
        $s);
}

sub test_HTMLFormattingClose {
    my $this = shift;

    my $action = TWiki::Plugins::ActionTrackerPlugin::Action->new(
        "Test", "Topic", 0,
        'who=JohnDoe due="2 Jun 02" closed="1-Jan-03" closer="LucBesson"',
        "A new action");
    my $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format(
        "", "|\$closed|\$closer|", "");
    my $s = $fmt->formatHTMLTable([$action], "href", 0, 'atp');
    $this->assert_html_matches(
        "<td>Wed, 01 Jan 2003</td><td>$this->{users_web}.LucBesson</td>", $s );
}

sub test_AutoPopulation {
    my $this = shift;

    my $action = new TWiki::Plugins::ActionTrackerPlugin::Action(
          "Test", "Topic", 7,
          "state=closed", "A new action");
    TWiki::Plugins::ActionTrackerPlugin::Action::forceTime("31 May 2002");
    my $tim = Time::ParseDate::parsedate("31 May 2002");
    $action->populateMissingFields();
    my $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format(
        "","","","|\$uid|\$who|");
    my $s = $fmt->formatStringTable([$action]);
    $this->assert_matches(qr/^\|\d\d\d\d\d\d\|$this->{users_web}\.$TWiki::cfg{DefaultUserWikiName}\|\n/, $s);
    $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format(
        "","","","|\$creator|\$created|");
    $s = $fmt->formatStringTable([$action]);
    $this->assert_str_equals("|$this->{users_web}.$TWiki::cfg{DefaultUserWikiName}|Fri, 31 May 2002|\n", $s);
    $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format(
        "","","","|\$closer|\$closed|");
    $s = $fmt->formatStringTable([$action]);
    $this->assert_str_equals("|$this->{users_web}.$TWiki::cfg{DefaultUserWikiName}|Fri, 31 May 2002|\n", $s);
    $action =
      new TWiki::Plugins::ActionTrackerPlugin::Action(
          "Test", "Topic", 8,
          "who=me", "action");
    $action->populateMissingFields();
    $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format(
        "","","","|\$who|\$created|");
    $s = $fmt->formatStringTable([$action]);
    $this->assert_str_equals("|$this->{users_web}.$TWiki::cfg{DefaultUserWikiName}|Fri, 31 May 2002|\n", $s);
}

sub test_ToString {
    my $this = shift;

    my $action = TWiki::Plugins::ActionTrackerPlugin::Action->new(
        "Test", "Topic", 5, "due=\"2 Jun 02\" state=closed", "A new action");
    TWiki::Plugins::ActionTrackerPlugin::Action::forceTime("30 Sep 2001");
    $action->populateMissingFields();
    my $s = $action->stringify();
    $s =~ s/ uid="\d+"//o;
    $s =~ s/ created="2001-09-30"//o;
    $s =~ s/ creator="$this->{users_web}\.$TWiki::cfg{DefaultUserWikiName}"//o;
    $s =~ s/ who="$this->{users_web}\.$TWiki::cfg{DefaultUserWikiName}"//o;
    $s =~ s/ due="2002-06-02"//o;
    $s =~ s/ closed="2001-09-30"//o;
    $s =~ s/ closer="$this->{users_web}\.$TWiki::cfg{DefaultUserWikiName}"//o;
    $s =~ s/ state="closed"//o;
    $this->assert_str_equals("%ACTION{ }% A new action %ENDACTION%", $s);

    $action = TWiki::Plugins::ActionTrackerPlugin::Action->new(
        "Test", "Topic", 9,
        "due=\"2 Jun 06\" state=open",
        "Another new action<br/>EOF");
    $action->populateMissingFields();
    $s = $action->stringify();
    $this->assert_matches(qr/% <<EOFF\nAnother new action\nEOF\nEOFF$/, $s);
}

sub test_FindByUID {
    my $this = shift;

    my $text = "
%ACTION{uid=AaAa who=One,due=\"30 May 2002\"}% AOne
%ACTION{uid=BbBb who=Two,due=\"30 May 2002\"}% ATwo\r
%ACTION{who=Three,due=\"30 May 2002\",uid=\"Flib\"}% AThree %ENDACTION%
%ACTION{uid=DdDd who=Four,due=\"30 May 2002\"}% <<EOF
AFour
EOF";
    use TWiki::Plugins::ActionTrackerPlugin::ActionSet;
    my $as = TWiki::Plugins::ActionTrackerPlugin::ActionSet::load(
        "Test", "Topic", $text, 1);

    my ( $action, $pre, $post ) = $as->splitOnAction( "AaAa" );
    $this->assert_str_equals($action->{text}, "AOne");
    $this->assert_str_equals("\n", $pre->stringify());
    $this->assert_str_equals('%ACTION{ due="2002-05-30" state="open" uid="BbBb" who="TemporaryActionTestsUsersWeb.Two" }% ATwo %ENDACTION%%ACTION{ due="2002-05-30" state="open" uid="Flib" who="TemporaryActionTestsUsersWeb.Three" }% AThree %ENDACTION%
%ACTION{ due="2002-05-30" state="open" uid="DdDd" who="TemporaryActionTestsUsersWeb.Four" }% AFour %ENDACTION%', $post->stringify());

    ( $action, $pre, $post ) = $as->splitOnAction( "BbBb" );
    $this->assert_str_equals($action->{text}, "ATwo");
    $this->assert_str_equals('
%ACTION{ due="2002-05-30" state="open" uid="AaAa" who="TemporaryActionTestsUsersWeb.One" }% AOne %ENDACTION%', $pre->stringify());
    $this->assert_str_equals('%ACTION{ due="2002-05-30" state="open" uid="Flib" who="TemporaryActionTestsUsersWeb.Three" }% AThree %ENDACTION%
%ACTION{ due="2002-05-30" state="open" uid="DdDd" who="TemporaryActionTestsUsersWeb.Four" }% AFour %ENDACTION%',
                            $post->stringify());
    ( $action, $pre, $post ) = $as->splitOnAction( "Flib" );

    $this->assert_str_equals('AThree', $action->{text});
    $this->assert_str_equals('
%ACTION{ due="2002-05-30" state="open" uid="AaAa" who="TemporaryActionTestsUsersWeb.One" }% AOne %ENDACTION%%ACTION{ due="2002-05-30" state="open" uid="BbBb" who="TemporaryActionTestsUsersWeb.Two" }% ATwo %ENDACTION%',
                             $pre->stringify());
    $this->assert_str_equals('
%ACTION{ due="2002-05-30" state="open" uid="DdDd" who="TemporaryActionTestsUsersWeb.Four" }% AFour %ENDACTION%',
                             $post->stringify());

    ( $action, $pre, $post ) = $as->splitOnAction( "DdDd" );
    $this->assert_str_equals($action->{text}, "AFour");
    $this->assert_str_equals('
%ACTION{ due="2002-05-30" state="open" uid="AaAa" who="TemporaryActionTestsUsersWeb.One" }% AOne %ENDACTION%%ACTION{ due="2002-05-30" state="open" uid="BbBb" who="TemporaryActionTestsUsersWeb.Two" }% ATwo %ENDACTION%%ACTION{ due="2002-05-30" state="open" uid="Flib" who="TemporaryActionTestsUsersWeb.Three" }% AThree %ENDACTION%
',
                             $pre->stringify());
    $this->assert_str_equals("", $post->stringify());

    ( $action, $pre, $post ) = $as->splitOnAction( "NotThere" );
    $this->assert_null($action);
    $this->assert_str_equals($as->stringify(),
                             $pre->stringify());
    $this->assert_str_equals("", $post->stringify());
}

sub test_FindChanges {
    my $this = shift;

    my $oaction = TWiki::Plugins::ActionTrackerPlugin::Action->new(
        "Test", "Topic", 0,
        "who=JohnDoe due=\"2 Jun 02\" state=open notify=\"SamPeckinpah,QuentinTarantino\" created=\"1 Jan 1999\"",
        "A new action");

    my $naction = TWiki::Plugins::ActionTrackerPlugin::Action->new( "Test", "Topic", 0, "who=JaneDoe due=\"2 Jun 09\" state=closed notify=\"SamPeckinpah,QuentinTarantino\" creator=\"ThomasMoore\"", "A new action<p>with more text");

    my $s = "|\$who|\$due|\$state|\$creator|\$created|\$text|";
    my $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format(
        $s,$s,"cols",$s,"\$who,\$due,\$state,\$created,\$creator,\$text");
    my %not = ();
    $naction->findChanges($oaction, $fmt, \%not);
    my $text = $not{"$this->{users_web}.SamPeckinpah"}{text};
    $this->assert_matches(
        qr/\|$this->{users_web}.JaneDoe\|Tue, 2 Jun 2009\|closed\|$this->{users_web}.ThomasMoore\|/,
        $text);
    $this->assert_matches(qr/\|A new action<p>with more text\|/, $text);
    $this->assert_matches(
        qr/Attribute \"state\" changed, was \"open\", now \"closed\"/, $text);
    $this->assert_matches(
        qr/Attribute \"due\" changed, was \"Sun, 2 Jun 2002\", now \"Tue, 2 Jun 2009\"/,
        $text);
    $this->assert_matches(
        qr/Attribute \"text\" changed, was \"A new action\", now \"A new action<p>with more text\"/,
        $text);
    $this->assert_matches(
        qr/Attribute \"created\" was \"Fri, 1 Jan 1999\" now removed/,
        $text);
    $this->assert_matches(
        qr/Attribute \"creator\" added with value \"$this->{users_web}.ThomasMoore\"/,
        $text);

    $text = $not{"$this->{users_web}.QuentinTarantino"}{html};
    my $jane = $fmt->formatHTMLTable([$naction],"href",0, 'atpChanges');
    $this->assert_html_matches($jane, $text);
    $this->assert_html_matches(
        "<tr class=\"atpChanges\"><td class=\"atpChanges\">who</td><td class=\"atpChanges\">$this->{users_web}.JohnDoe</td><td class=\"atpChanges\">$this->{users_web}.JaneDoe</td></tr>",
        $text);
    $this->assert_html_matches(
        "<tr class=\"atpChanges\"><td class=\"atpChanges\">due</td><td class=\"atpChanges\"><span class=\"atpOpen\">Sun, 02 Jun 2002</span></td><td class=\"atpChanges\"><span class=\"atpClosed\">Tue, 02 Jun 2009</span></td></tr>",
        $text);
    $this->assert_html_matches(
        "<tr class=\"atpChanges\"><td class=\"atpChanges\">state</td><td class=\"atpChanges\">open</td><td class=\"atpChanges\">closed</td></tr>",
        $text);
    $this->assert_html_matches(
        "<tr class=\"atpChanges\"><td class=\"atpChanges\">created</td><td class=\"atpChanges\">Fri, 01 Jan 1999</td><td class=\"atpChanges\"> *removed* </td></tr>",
        $text);
    $this->assert_html_matches(
        "<tr class=\"atpChanges\"><td class=\"atpChanges\">creator</td><td class=\"atpChanges\"> *missing* </td><td class=\"atpChanges\">$this->{users_web}.ThomasMoore</td></tr>",
        $text);
    $this->assert_html_matches(
        "<tr class=\"atpChanges\"><td class=\"atpChanges\">text</td><td class=\"atpChanges\">A new action</td><td class=\"atpChanges\">A new action<p>with more text</td></tr>",
        $text);
}

sub test_XtendTypes {
    my $this = shift;

    my $s = TWiki::Plugins::ActionTrackerPlugin::Action::extendTypes(
        "| plaintiffs,names,16| decision, text, 16|sentencing,date|sentence,select,17,life,\"5 years\",\"community service\"|");
    $this->assert(!defined($s), $s);

    my $action = TWiki::Plugins::ActionTrackerPlugin::Action->new(
        "Test", "Topic", 0,
        'who=JohnDoe due="2002-06-02" state=open,plaintiffs="fred.bloggs@limp.net,JoeShmoe",decision="cut off their heads" sentencing=2-mar-2006 sentence="5 years"',
                                                                   "A court action");

    $s = $action->stringify();
    $s =~ s/ who="$this->{users_web}.JohnDoe"//o;
    $s =~ s/ A court action//o;
    $s =~ s/ state="open"//o;
    $s =~ s/ due="2002-06-02"//o; 
    $s =~ s/ plaintiffs="fred.bloggs\@limp.net, $this->{users_web}.JoeShmoe"//o;
    $s =~ s/ decision="cut off their heads"//o;
    $s =~ s/ who="$this->{users_web}\.$TWiki::cfg{DefaultUserWikiName}"//o;
    $s =~ s/ sentencing="2006-03-02"//o;
    $s =~ s/ sentence="5 years"//o;
    $this->assert_str_equals("%ACTION{ }% %ENDACTION%", $s);

    my $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format(
        "", "|\$plaintiffs|","","\$plaintiffs");
    $s = $fmt->formatStringTable([$action]);
    $this->assert_str_equals("fred.bloggs\@limp.net, $this->{users_web}.JoeShmoe\n", $s);
    $s = $fmt->formatHTMLTable([$action], "href", 0, 'atp');
    $this->assert_matches(
        qr/<td>fred.bloggs\@limp.net, $this->{users_web}.JoeShmoe<\/td>/, $s );

    $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format(
        "", "|\$decision|","","\$decision");
    $s = $fmt->formatStringTable([$action]);
    $this->assert_str_equals("cut off their heads\n", $s);
    $s = $fmt->formatHTMLTable([$action], "href", 0, 'atp');
    $this->assert_matches(qr/<td>cut off their heads<\/td>/, $s );

    $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format(
        "", "|\$sentence|","","\$sentence");
    $s = $fmt->formatStringTable([$action]);
    $this->assert_str_equals("5 years\n", $s);
    $s = $fmt->formatHTMLTable([$action], "href", 0, 'atp');
    $this->assert_matches(qr/<td>5 years<\/td>/, $s );

    $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format(
        "", "","","\$sentencing");
    $s = $fmt->formatStringTable([$action]);
    $this->assert_str_equals("Thu, 02 Mar 2006\n", $s);

    my $attrs = TWiki::Attrs->new("sentence=\"5 years\"");
    $this->assert($action->matches($attrs));
    $attrs = TWiki::Attrs->new("sentence=\"life\"");
    $this->assert(!$action->matches($attrs));
    $attrs = TWiki::Attrs->new("sentence=\"\\d+ years\"");
    $this->assert($action->matches($attrs));

    $s = TWiki::Plugins::ActionTrackerPlugin::Action::extendTypes(
        "|state,select,17,life,\"5 years\",\"community service\"|");
    $this->assert(!defined($s),$s);
    TWiki::Plugins::ActionTrackerPlugin::Action::unextendTypes();
    $s = TWiki::Plugins::ActionTrackerPlugin::Action::extendTypes(
        "|who,text,17|");
    $this->assert_str_equals(
        'Attempt to redefine attribute \'who\' in EXTRAS',$s);
    $s = TWiki::Plugins::ActionTrackerPlugin::Action::extendTypes("|fleegle|");
    $this->assert_str_equals("Bad EXTRAS definition 'fleegle' in EXTRAS",$s );
    TWiki::Plugins::ActionTrackerPlugin::Action::unextendTypes();
}

sub test_CreateFromQuery {
    my $this = shift;

    my $query = new CGI ("");
    $query->param( changedsince => "1 May 2003");
    $query->param( closed       => "2 May 2003");
    $query->param( closer       => "Closer");
    $query->param( created      => "3 May 2003");
    $query->param( creator      => "Creator");
    $query->param( dollar       => 1);
    $query->param( due          => "4 May 2003");
    $query->param( edit         => 1);
    $query->param( format       => 1);
    $query->param( header       => 1);
    $query->param( late         => 1);
    $query->param( n            => 1);
    $query->param( nop          => 1);
    $query->param( notify       => "Notifyee");
    $query->param( percnt       => 1);
    $query->param( quot         => 1);
    $query->param( sort         => 1);
    $query->param( state        => "open" );
    $query->param( text         => "Text");
    $query->param( topic        => "BadTopic");
    $query->param( uid          => "UID");
    $query->param( web          => "BadWeb");
    $query->param( who          => "Who");
    $query->param( within       => 2);
    $query->param( ACTION_NUMBER=> -99);
    my $action =
      TWiki::Plugins::ActionTrackerPlugin::Action::createFromQuery(
          "Web","Topic",10,$query);
    my $chosen = $action->stringify();
    $chosen =~ s/ state="open"//o;
    $chosen =~ s/ creator="$this->{users_web}.Creator"//o;
    $chosen =~ s/ notify="$this->{users_web}\.Notifyee"//o;
    $chosen =~ s/ closer="$this->{users_web}\.Closer"//o;
    $chosen =~ s/ due="4-May-2003"//o;
    $chosen =~ s/ closed="2-May-2003"//o;
    $chosen =~ s/ who="$this->{users_web}\.Who"//o;
    $chosen =~ s/ created="2003-05-01"//o;
    $chosen =~ s/ uid="UID"//o;
    $this->assert_matches(qr/^%ACTION{\s*}% Text %ENDACTION%$/, $chosen, );
}

sub test_FormatForEditHidden {
    my $this = shift;

    my $action =
      new TWiki::Plugins::ActionTrackerPlugin::Action(
          "Web", "Topic", 9,
          'state="open" creator="$this->{users_web}.Creator" notify="$this->{users_web}.Notifyee" closer="$this->{users_web}.Closer" due="4-May-2003" closed="2-May-2003" who="$this->{users_web}.Who" created="3-May-2003" uid="UID"',
          "Text");
    my $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format( "|Who|", "|\$who|", "cols","","");
    my $s = $action->formatForEdit($fmt);
    # only the who field should be a text; the rest should be hiddens
    $s =~ s(<input (.*?name="state".*?)/>)();
    $this->assert_matches(qr/type="hidden"/,$1);
    $this->assert_matches(qr/value="open"/, $1);
    $s =~ s(<input (.*?name="creator".*?)/>)();
    $this->assert_matches(qr/type="hidden"/, $1);
    $this->assert_matches(qr/value="$this->{users_web}\.Creator"/, $1);
    $s =~ s(<input (.*?name="notify".*?)/>)();
    $this->assert_matches(qr/type="hidden"/, $1);
    $this->assert_matches(qr/value="$this->{users_web}\.Notifyee"/, $1);
    $s =~ s(<input (.*?name="closer".*?)/>)();
    $this->assert_matches(qr/type="hidden"/, $1);
    $this->assert_matches(qr/value="$this->{users_web}\.Closer"/, $1);
    $s =~ s(<input (.*?name="due".*?)/>)();
    $this->assert_matches(qr/type="hidden"/, $1);
    $this->assert_matches(qr/value="Sun, 4 May 2003"/, $1);
    $s =~ s(<input (.*?name="closed".*?)/>)();
    $this->assert_matches(qr/type="hidden"/, $1);
    $this->assert_matches(qr/value="Fri, 2 May 2003"/, $1);
    $s =~ s(<input (.*?name="created".*?)/>)();
    $this->assert_matches(qr/type="hidden"/, $1);
    $this->assert_matches(qr/value="Sat, 3 May 2003"/, $1);
    $s =~ s(<input (.*?name="uid".*?)/>)();
    $this->assert_matches(qr/type="hidden"/, $1);
    $this->assert_matches(qr/value="UID"/, $1);
    $this->assert_does_not_match(qr/name="text"/, $s);
    $this->assert_does_not_match(qr/type="hidden"/, $s);
}

sub test_FormatForEdit {
    my $this = shift;

    my $action =
      new TWiki::Plugins::ActionTrackerPlugin::Action(
          "Web", "Topic", 9,
          "state=\"open\" creator=\"$this->{users_web}.Creator\" notify=\"$this->{users_web}.Notifyee\" closer=\"$this->{users_web}.Closer\" due=\"4-May-2003\" closed=\"2-May-2003\" who=\"$this->{users_web}.Who\" created=\"3-May-2003\" uid=\"UID\"",
          "Text");
    my $expand = "closed|creator|closer|created|due|notify|uid|who";
    my $noexpand =
      "changedsince|dollar|edit|format|header|late|n|nop|percnt|quot|sort|text|topic|web|within|ACTION_NUMBER";
    my $all = "|state|$expand|$noexpand|";
    my $bods = $all;
    $bods =~ s/(\w+)/\$$1/go;

    my $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format(
        $all, $bods, "","");
    my $s = $action->formatForEdit($fmt);
    foreach my $n (split(/\|/,$noexpand)) {
        $this->assert($s =~ s/<th>$n<\/th>//, "$n in $s");
        $n = "\\\$" if ( $n eq "dollar" );
        $n = "<br />" if ( $n eq "n" );
        $n = "" if ( $n eq "nop" );
        $n = "%" if ( $n eq "percnt" );
        $n = "\"" if ( $n eq "quot" );
        $this->assert($s =~ s/<td class="atpEdit">$n<\/td>//s, $n.' in '.$s);
    }
    $this->assert($s =~ s/<th>state<\/th>//, $s);
    foreach my $n (split(/\|/,$expand)) {
        $this->assert($s =~ s(<th>$n<\/th>)(), $n);
        require TWiki::Contrib::JSCalendarContrib;
        if (!$@ && ($n eq "closed" || $n eq "due" || $n eq "created")) {
            $this->assert(
                $s =~ s(<td class="atpEdit"><input (.*?name="$n".*?)/><input (.*?)/></td>)(),$n.' in '.$s);
            my($pr, $b, $img ) = ($1, $2, $3);
            $this->assert($pr =~ s/type="text"//);
            $this->assert($pr =~ s/name="$n"//);
            $this->assert($pr =~ s/value=".*?"//);
            $this->assert($pr =~ s/size=".*?"//);
            $this->assert_matches(qr/\s*id="date_$n"\s*$/, $pr);
            $this->assert($b =~ s/onclick="return showCalendar\(.*\)"//,$b);
            $this->assert_matches(qr/^\s*type="image".*$/, $b);
        } else {
            $this->assert($s =~ s(<td class="atpEdit"><input (.*?)/></td>)());
            my $d = $1;
            $this->assert($d =~ s/type="text"//);
            $this->assert($d =~ s/name="$n"//);
            $this->assert($d =~ s/value=".*?"//);
            $this->assert_matches(qr/^\s*size="\d+"\s*$/, $d);
        }
    }
    $this->assert($s =~ s/^\s*<table class="atpEdit">//);
    $this->assert($s =~ s/\s*<tr><\/tr>//, $s);
    $this->assert($s =~ s/\s*<tr>//);
    $this->assert($s =~ s/\s*<td class="atpEdit">//);
    $this->assert($s =~ s/\s*<select (.*?name="state".*?)>//);
    $this->assert_matches(qr/size="1"/,$1);
    $this->assert($s =~ s/<option (.*?value="open".*?)>open<\/option>//);
    $this->assert_matches(qr/selected="selected"/,$1);
    $this->assert($s =~ s/<option value="closed">closed<\/option>//);
    $this->assert($s =~ s/\s*<\/select>\s*<\/td>//, $s);
    $this->assert($s =~ s/\s*<\/tr>\s*<\/table>//, $s);
    $this->assert_matches(qr/^\s*$/, $s);

    $action =
      new TWiki::Plugins::ActionTrackerPlugin::Action(
          "Web", "Topic", 9,
          "state=\"open\" due=\"4-May-2001\"", "Test");
    TWiki::Plugins::ActionTrackerPlugin::Action::forceTime("31 May 2002");
    $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format( "|Due|", "|\$due|", "","");
    $s = $action->formatForEdit($fmt);
    $s =~ /value=\"(.*?)\"/;
    $this->assert_str_equals($1, "Fri, 04 May 2001");
}

sub test_ExtendStates {
    my $this = shift;

    my $s = TWiki::Plugins::ActionTrackerPlugin::Action::extendTypes("|state,select,17,life,\"5 years\",\"community service\"|");
    $this->assert(!defined($s));
    my $action =
      new TWiki::Plugins::ActionTrackerPlugin::Action("Web", "Topic", 10,
                                                      "state=\"5 years\"", "Text");
    my $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format( "|State|", "|\$state|", "","");
    $s = $action->formatForEdit($fmt);
    $s =~ s((<option value="life">life</option>))();
    $this->assert($1);
    $s =~ s(<option (.*?)>5 years</option>)();
    $this->assert_matches(qr/selected="selected"/, $1);
    $this->assert_matches(qr/value="5 years"/,$1);
    $s =~ s(<option (.*?)>community service</option>)();
    $this->assert_matches(qr/value="community service"/, $1);
    $s =~ s(<select (.*?)>\s*</select>)();
    $this->assert_matches(qr/name="state"/, $1, $s);
    $this->assert_matches(qr/size="17"/, $1);
    $s =~ s/<\/?table.*?>//gio;
    $s =~ s/<\/?tr.*?>//gio;
    $s =~ s/<\/?t[hd].*?>//gio;
    $s =~ s/<input type=\"hidden\".*?\/>//gio;
    $s =~ s/\s+//go;
    $this->assert_str_equals("State", $s);
    TWiki::Plugins::ActionTrackerPlugin::Action::unextendTypes();
}

# Test for empty due
sub test_4373 {
    my $this = shift;

    my $action =
      new TWiki::Plugins::ActionTrackerPlugin::Action(
          "Test", "Topic", 0,
          'who="SlyStallone" state=open ',
          "A new action");

    my $attrs = new TWiki::Attrs("who=$this->{users_web}.SlyStallone",1);
    $this->assert($action->matches($attrs));
    $attrs = new TWiki::Attrs('state="open"',1);
    $this->assert($action->matches($attrs));

    $attrs = new TWiki::Attrs("late",1);
    $this->assert($action->matches($attrs));

    $attrs = new TWiki::Attrs("within='+1'",1);
    $this->assert(!$action->matches($attrs));
    $attrs = new TWiki::Attrs("within='1'",1);
    $this->assert($action->matches($attrs));

    TWiki::Plugins::ActionTrackerPlugin::Action::forceTime("31 May 2002");
    $attrs = new TWiki::Attrs('due="31 May 02"',1);
    $this->assert($action->matches($attrs));
}

1;
