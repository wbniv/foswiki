package ActionTrackerPluginTests;
use base qw(FoswikiFnTestCase);

use strict;

use TWiki::Plugins::ActionTrackerPlugin;
use TWiki::Plugins::ActionTrackerPlugin::Action;
use TWiki::Plugins::ActionTrackerPlugin::ActionSet;
use TWiki::Plugins::ActionTrackerPlugin::Format;
use Time::ParseDate;

sub new {
  my $self = shift()->SUPER::new(@_);
  return $self;
}

my $twiki;

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    # Need this to get the actionnotify template
    $TWiki::cfg{Plugins}{ActionTrackerPlugin}{Enabled} = 1;
    foreach my $lib (@INC) {
        my $d = "$lib/../templates";
        if (-e "$d/actionnotify.tmpl") {
            $TWiki::cfg{TemplateDir} = $d;
            last;
        }
    }

    TWiki::Plugins::ActionTrackerPlugin::Action::forceTime("3 Jun 2002");

    my $meta = new TWiki::Meta($this->{twiki}, $this->{test_web}, "Topic1");
    $meta->putKeyed('FIELD', {name=>'Who', title=>'Leela', value=>'Turanaga'});
    TWiki::Func::saveTopic($this->{test_web}, "Topic1", $meta, "
%ACTION{who=$this->{users_web}.Sam,due=\"3 Jan 02\",open}% Test0: Sam_open_late");

    TWiki::Func::saveTopic($this->{test_web}, "Topic2", undef, "
%ACTION{who=Fred,due=\"2 Jan 02\",open}% Test1: Fred_open_ontime");

    TWiki::Func::saveTopic($this->{test_web}, "WebNotify", undef, "
   * $this->{users_web}.Fred - fred\@sesame.street.com
");

    TWiki::Func::saveTopic($this->{test_web}, "WebPreferences", undef, "
   * Set ACTIONTRACKERPLUGIN_HEADERCOL = green
   * Set ACTIONTRACKERPLUGIN_EXTRAS = |plaintiffs,names,16|decision,text,16|sentencing,date|sentence,select,\"life\",\"5 years\",\"community service\"|
");

    TWiki::Func::saveTopic($this->{users_web}, "Topic2", undef, "
%META:TOPICINFO{author=\"guest\" date=\"1053267450\" format=\"1.0\" version=\"1.35\"}%
%META:TOPICPARENT{name=\"WebHome\"}%
%ACTION{who=$this->{users_web}.Fred,due=\"1 Jan 02\",closed}% Main0: Fred_closed_ontime
%ACTION{who=Joe,due=\"29 Jan 2010\",open}% Main1: Joe_open_ontime
%ACTION{who=TheWholeBunch,due=\"29 Jan 2001\",open}% Main2: Joe_open_ontime
%META:FORM{name=\"ThisForm\"}%
%META:FIELD{name=\"Know.TopicClassification\" title=\"Know.TopicClassification\" value=\"Know.PublicSupported\"}%
%META:FIELD{name=\"Know.OperatingSystem\" title=\"Know.OperatingSystem\" value=\"Know.OsHPUX, Know.OsLinux\"}%
%META:FIELD{name=\"Know.OsVersion\" title=\"Know.OsVersion\" value=\"hhhhhh\"}%
");

    TWiki::Func::saveTopic($this->{users_web}, "WebNotify", undef, "
   * $this->{users_web}.Sam - sam\@sesame.street.com
");
    TWiki::Func::saveTopic($this->{users_web}, "Joe", undef, "
   * Email: joe\@sesame.street.com
");
    TWiki::Func::saveTopic($this->{users_web}, "TheWholeBunch", undef, "
   * Email: joe\@sesame.street.com
   * Email: fred\@sesame.street.com
   * Email: sam\@sesame.street.com
   * $this->{users_web}.GungaDin - gunga-din\@war_lords-home.ind
");
    TWiki::Plugins::ActionTrackerPlugin::initPlugin("Topic",$this->{test_web},"User","Blah");
}

sub testActionSearchFn {
    my $this = shift;
    my $chosen = TWiki::Plugins::ActionTrackerPlugin::_handleActionSearch(
        $twiki, new TWiki::Attrs("web=\".*\""),
        $this->{users_web}, $this->{test_topic});
    $this->assert_matches(qr/Test0:/, $chosen);
    $this->assert_matches(qr/Test1:/, $chosen);
    $this->assert_matches(qr/Main0:/, $chosen);
    $this->assert_matches(qr/Main1:/, $chosen);
    $this->assert_matches(qr/Main2:/, $chosen);

}

sub testActionSearchFnSorted {
    my $this = shift;
    my $chosen = TWiki::Plugins::ActionTrackerPlugin::_handleActionSearch(
        $twiki, new TWiki::Attrs("web=\".*\" sort=\"state,who\""),
        $this->{users_web}, $this->{test_topic});
    $this->assert_matches(qr/Test0:/, $chosen);
    $this->assert_matches(qr/Test1:/, $chosen);
    $this->assert_matches(qr/Main0:/, $chosen);
    $this->assert_matches(qr/Main1:/, $chosen);
    $this->assert_matches(qr/Main2:/, $chosen);
    $this->assert_matches(qr/Main0:.*Test1:.*Main1:.*Test0:.*Main2:/so,
                          $chosen);
}

sub test2CommonTagsHandler {
    my $this = shift;
    my $chosen = "
Before
%ACTION{who=Zero,due=\"11 jun 1993\"}% Finagle0: Zeroth action
%ACTIONSEARCH{web=\".*\"}%
%ACTION{who=One,due=\"11 jun 1993\"}% Finagle1: Oneth action
After
";
    $TWiki::Plugins::ActionTrackerPlugin::pluginInitialized = 1;
    TWiki::Plugins::ActionTrackerPlugin::commonTagsHandler(
        $chosen, "Finagle", $this->{users_web});

    $this->assert_matches(qr/Test0:/, $chosen);
    $this->assert_matches(qr/Test1:/, $chosen);
    $this->assert_matches(qr/Main0:/, $chosen);
    $this->assert_matches(qr/Main1:/, $chosen);
    $this->assert_matches(qr/Main2:/, $chosen);
    $this->assert_matches(qr/Finagle0:/, $chosen);
    $this->assert_matches(qr/Finagle1:/, $chosen);
}

# Must be first test, because we check JavaScript handling here
sub test1CommonTagsHandler {
    my $this = shift;
    my $text = <<HERE;
%ACTION{uid=\"UidOnFirst\" who=ActorOne, due=11/01/02}% __Unknown__ =status= www.twiki.org
   %ACTION{who=$this->{users_web}.ActorTwo,due=\"Mon, 11 Mar 2002\",closed}% Open <table><td>status<td>status2</table>
text %ACTION{who=$this->{users_web}.ActorThree,due=\"Sun, 11 Mar 2001\",closed}%The *world* is flat
%ACTION{who=$this->{users_web}.ActorFour,due=\"Sun, 11 Mar 2001\",open}% _Late_ the late great *date*
%ACTION{who=$this->{users_web}.ActorFiveVeryLongNameBecauseItsATest,due=\"Wed, 13 Feb 2002\",open}% <<EOF
This is an action with a lot of associated text to test
   * the VingPazingPoodleFactor,
   * Tony Blair is a brick.
   * Who should really be built
   * Into a very high wall.
EOF
%ACTION{who=ActorSix, due=\"11 2 03\",open}% Bad date
break the table here %ACTION{who=ActorSeven,due=01/01/02,open}% Create the mailer, %USERNAME%

   * A list
   * %ACTION{who=ActorEight,due=01/01/02}% Create the mailer
   * endofthelist

   * Another list
   * should generate %ACTION{who=ActorNine,due=01/01/02,closed}% Create the mailer
HERE

    TWiki::Plugins::ActionTrackerPlugin::commonTagsHandler($text, "TheTopic", "TheWeb");
}

sub anchor {
    my $tag = shift;
    return "<a name=\"$tag\"></a>";
}

sub edit {
    my $tag = shift;
    my $url = "%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/TheWeb/TheTopic?skin=action&action=$tag&t={*\\d+*}";
    return "<a href=\"$url\" onclick=\"return atp_editWindow('$url')\">edit</a>";
}

sub action {
    my ($anch, $actor, $col, $date, $txt, $state) = @_;

    my $text = "<tr valign=\"top\">".anchor($anch);
    $text .= "<td> $actor </td><td";
    $text .= " bgcolor=\"$col\"" if ($col);
    $text .= "> $date </td><td> $txt </td><td> $state </td><td> \&nbsp; </td><td> ".
      edit($anch)." </td></tr>";
    return $text;
}

sub testBeforeEditHandler {
    my $this = shift;
    my $q = new CGI({atp_action=>"AcTion0",
                     skin=>'action', atp_action=>'666'});
    $this->{twiki}->{cgiQuery} = $q;
    my $text = '%ACTION{uid="666" who=Fred,due="2 Jan 02",open}% Test1: Fred_open_ontime';
    TWiki::Plugins::ActionTrackerPlugin::beforeEditHandler($text,"Topic2",$this->{users_web},undef);
    $text = $this->assert_html_matches("<input type=\"text\" name=\"who\" value=\"$this->{users_web}\.Fred\" size=\"35\"/>", $text);
}

sub testAfterEditHandler {
    my $this = shift;
    my $q = new CGI({
        closeactioneditor=>1,
        pretext=>"%ACTION{}% Before\n",
        posttext=>"After",
        who=>"AlexanderPope",
        due=>"3 may 2009",
        state=>"closed" });
    # populate with edit fields
    $this->{twiki}->{cgiQuery} = $q;
    my $text = "%ACTION{}%";
    TWiki::Plugins::ActionTrackerPlugin::afterEditHandler($text,"Topic","Web");
    $this->assert($text =~ m/(%ACTION.*)(%ACTION.*)$/so);
    my $first = $1;
    my $second = $2;
    my $re = qr/\s+state=\"open\"\s+/;
    $this->assert_matches($re, $first); $first =~ s/$re/ /;
    $re = qr/\s+creator=\"$this->{users_web}\.WikiGuest\"\s+/o;
    $this->assert_matches($re, $first); $first =~ s/$re/ /;
    $re = qr/\s+due=\"3-Jun-2002\"\s+/;
    $this->assert_matches($re, $first); $first =~ s/$re/ /;
    $re = qr/\s+created=\"3-Jun-2002\"\s+/;
    $this->assert_matches($re, $first); $first =~ s/$re/ /;
    $re = qr/\s+who=\"$this->{users_web}.WikiGuest\"\s+/;
    $this->assert_matches($re, $first); $first =~ s/$re/ /;
}

sub testBeforeSaveHandler1 {
    my $this = shift;
    my $q = new CGI( {
        closeactioneditor=>1,
    });
    $this->{twiki}->{cgiQuery} = $q;
    my $text =
      "%META:TOPICINFO{author=\"guest\" date=\"1053267450\" format=\"1.0\" version=\"1.35\"}%
%META:TOPICPARENT{name=\"WebHome\"}%
%ACTION{}%
%META:FORM{name=\"ThisForm\"}%
%META:FIELD{name=\"Know.TopicClassification\" title=\"Know.TopicClassification\" value=\"Know.PublicSupported\"}%
%META:FIELD{name=\"Know.OperatingSystem\" title=\"Know.OperatingSystem\" value=\"Know.OsHPUX, Know.OsLinux\"}%
%META:FIELD{name=\"Know.OsVersion\" title=\"Know.OsVersion\" value=\"hhhhhh\"}%";
    
    TWiki::Plugins::ActionTrackerPlugin::beforeSaveHandler(
        $text,"Topic2",$this->{users_web});
    my $re = qr/ state=\"open\"/;
    $this->assert_matches($re, $text); $text =~ s/$re//;
    $re = qr/ creator=\"$this->{users_web}.WikiGuest\"/o;
    $this->assert_matches($re, $text); $text =~ s/$re//;
    $re = qr/ created=\"3-Jun-2002\"/o;
    $this->assert_matches($re, $text); $text =~ s/$re//;
    $re = qr/ due=\"3-Jun-2002\"/o;
    $this->assert_matches($re, $text); $text =~ s/$re//;
    $re = qr/ who=\"$this->{users_web}.WikiGuest\"/o;
    $this->assert_matches($re, $text); $text =~ s/$re//;
    $re = qr/ No description/o;
    $this->assert_matches($re, $text); $text =~ s/$re//;
    $re = qr/^%META:TOPICINFO.*$/m;
    $this->assert_matches($re, $text); $text =~ s/$re//m;
    $re = qr/^%META:TOPICPARENT.*$/m;
    $this->assert_matches($re, $text); $text =~ s/$re//m;
    $re = qr/^%META:FORM.*$/m;
    $this->assert_matches($re, $text); $text =~ s/$re//m;
    $re = qr/^%META:FIELD.*$/m;
    $this->assert_matches($re, $text); $text =~ s/$re//m;
    $re = qr/^%META:FIELD.*$/m;
    $this->assert_matches($re, $text); $text =~ s/$re//m;
    $re = qr/^%META:FIELD.*$/m;
    $this->assert_matches($re, $text); $text =~ s/$re//m;
}

sub testBeforeSaveHandler2 {
    my $this = shift;
    my $q = new CGI( {
        closeactioneditor=>0,
    } );
    $this->{twiki}->{cgiQuery} = $q;
    my $text =
      "%META:TOPICINFO{author=\"guest\" date=\"1053267450\" format=\"1.0\" version=\"1.35\"}%
%META:TOPICPARENT{name=\"WebHome\"}%
%ACTION{}% <<EOF
A Description
EOF
%META:FORM{name=\"ThisForm\"}%
%META:FIELD{name=\"Know.TopicClassification\" title=\"Know.TopicClassification\" value=\"Know.PublicSupported\"}%
%META:FIELD{name=\"Know.OperatingSystem\" title=\"Know.OperatingSystem\" value=\"Know.OsHPUX, Know.OsLinux\"}%
%META:FIELD{name=\"Know.OsVersion\" title=\"Know.OsVersion\" value=\"hhhhhh\"}%";
    
    TWiki::Plugins::ActionTrackerPlugin::beforeSaveHandler(
        $text,"Topic2",$this->{users_web});
    my $re = qr/ state=\"open\"/o;
    $this->assert_matches($re, $text); $text =~ s/$re//;
    $re = qr/ creator=\"$this->{users_web}.WikiGuest\"/o;
    $this->assert_matches($re, $text); $text =~ s/$re//;
    $re = qr/ created=\"3-Jun-2002\"/o;
    $this->assert_matches($re, $text); $text =~ s/$re//;
    $re = qr/ due=\"3-Jun-2002\"/o;
    $this->assert_matches($re, $text); $text =~ s/$re//;
    $re = qr/ who=\"$this->{users_web}.WikiGuest\"/o;
    $this->assert_matches($re, $text); $text =~ s/$re//;
}

sub test_formfield_format {
    my $this = shift;

    my $text = <<HERE;
%ACTIONSEARCH{who="$this->{users_web}.Sam" state="open" header="|Who|" format="|\$formfield(Who)|"}%
HERE
    $TWiki::Plugins::ActionTrackerPlugin::pluginInitialized = 1;
    TWiki::Plugins::ActionTrackerPlugin::commonTagsHandler(
        $text, "Finagle", $this->{test_web});
    $this->assert($text =~ /<td>Turanaga<\/td>/, $text);
}

1;
