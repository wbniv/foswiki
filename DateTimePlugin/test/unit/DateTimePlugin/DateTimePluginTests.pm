use strict;

package DateTimePluginTests;

use base qw( TWikiFnTestCase );

use strict;
use TWiki::UI::Save;
use Error qw( :try );
use TWiki::Plugins::DateTimePlugin;

sub new {
    my $self = shift()->SUPER::new( 'DateTimePluginFunctions', @_ );
    return $self;
}

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    # $this->{sup} = $this->{twiki}->getScriptUrl(0, 'view');
    $TWiki::cfg{AntiSpam}{RobotsAreWelcome} = 1;
    $TWiki::cfg{AllowInlineScript} = 0;
    $ENV{SCRIPT_NAME} = '';    #  required by fake sort URLs in expected text
}

# This formats the text up to immediately before <nop>s are removed, so we
# can see the nops.
sub do_testHtmlOutput {
    my ( $this, $expected, $actual, $doRender ) = @_;

    my $session   = $this->{twiki};
    my $webName   = $this->{test_web};
    my $topicName = $this->{test_topic};

    if ($doRender) {
        $actual =
          TWiki::Func::expandCommonVariables( $actual, $webName, $topicName );
        $actual =
          $session->renderer->getRenderedVersion( $actual, $webName,
            $topicName );
        $expected =
          TWiki::Func::expandCommonVariables( $expected, $webName, $topicName );
        $expected =
          $session->renderer->getRenderedVersion( $expected, $webName,
            $topicName );
    }
    $this->assert_html_equals( $expected, $actual );
}


sub doTest
{
    my ($this, $raw_text, $expected ) = @_;

    my $result =
      $this->{twiki}->handleCommonTags( $raw_text, $this->{test_web}, $this->{test_topic} );
    $this->do_testHtmlOutput( $expected, $result, 1 );

    #$raw_text =~ s/(\s)/ord($1)/ge; print $raw_text,"\n";
    #$result =~ s/(\s)/ord($1)/ge; print $result,"\n";
}

=pod

---++ Default

%DATETIME{}%

Assumes that the default format setting in configure is "$day $month $year".

=cut

sub test_Default
{    
    my $this = shift;
    $this->doTest(
<<END_RAW,
%DATETIME{}%
END_RAW
<<END_EXPECTED
%GMTIME{"\$day \$month \$year"}%
END_EXPECTED
);
}

=pod

---++ Format

%DATETIME{format="$day $month $year"}%
%DATETIME{date="2001/12/31" format="\$month"}%
%DATETIME{format="\$tz"}%

Assumes that the default format setting in configure is "$day $month $year".

=cut

sub test_Format
{    
    my $this = shift;
    $this->doTest(
<<END_RAW,
%DATETIME{format="\$day \$month \$year"}%
END_RAW
<<END_EXPECTED
%GMTIME{"\$day \$month \$year"}%
END_EXPECTED
);
    $this->doTest(
<<END_RAW,
%DATETIME{date="2001/12/31 23:59:59" format="\$month"}%
END_RAW
<<END_EXPECTED
Dec
END_EXPECTED
);
    $this->doTest(
<<END_RAW,
%DATETIME{format="\$tz"}%
END_RAW
<<END_EXPECTED
GMT
END_EXPECTED
);
    $this->doTest(
<<END_RAW,
%DATETIME{date="2001/12/31 23:59:59" format="\$mo"}%
END_RAW
<<END_EXPECTED
12
END_EXPECTED
);
}

=pod

---++ Additional formatting parameters

%DATETIME{date="2001/12/31" format="$i_month"}%

=cut

sub test_AdditionalFormatting
{    
    my $this = shift;
    $this->doTest(
<<END_RAW,
%DATETIME{date="2001/12/31 23:59:59" format="\$i_month"}%
END_RAW
<<END_EXPECTED
Dec
END_EXPECTED
);

}

=pod

---++ Date GMTIME format

%DATETIME{format="$day $month $year" date="%GMTIME{\"$day $month $year\"}%"}%

Assumes that the default format setting in configure is "$day $month $year".

=cut

sub test_Date_GMTIME
{    
    my $this = shift;
    $this->doTest(
<<END_RAW,
%DATETIME{format="\$day \$month \$year" date="%GMTIME{\"\$day \$month \$year\"}%"}%
END_RAW
<<END_EXPECTED
%GMTIME{"\$day \$month \$year"}%
END_EXPECTED
);
}

=pod

---++ Date specific

%DATETIME{format="$day $month $year" date="2 Jul 2008 - 14:15:32"}%
%DATETIME{format="$day $month $year" date="2 Jul 1971"}%

Note: does not work yet with dates before 1970!

=cut

sub test_Date_Specific
{    
    my $this = shift;
    $this->doTest(
<<END_RAW,
%DATETIME{format="\$day \$month \$year" date="2 Jul 2008 - 14:15:32"}%
END_RAW
<<END_EXPECTED
02 Jul 2008
END_EXPECTED
);
    $this->doTest(
<<END_RAW,
%DATETIME{format="\$day \$month \$year" date="2 Jul 1969"}%
END_RAW
<<END_EXPECTED
02 Jul 1969
END_EXPECTED
);
}

=pod

---++ Input date format

Note: does not work yet with dates before 1970!

=cut

sub test_Date_InDateFormat
{    
    my $this = shift;
    $this->doTest(
<<END_RAW,
%DATETIME{format="\$day \$month \$year - \$hours:\$minutes" date="31 Dec 2001"}%
END_RAW
<<END_EXPECTED
31 Dec 2001 - 00:00
END_EXPECTED
);
$this->doTest(
<<END_RAW,
%DATETIME{format="\$day \$month \$year - \$hours:\$minutes" date="31 Dec 2001 - 23:59"}%
END_RAW
<<END_EXPECTED
31 Dec 2001 - 23:59
END_EXPECTED
);
    $this->doTest(
<<END_RAW,
%DATETIME{format="\$day \$month \$year - \$hours:\$minutes" date="2001/12/31 23:59:59"}%
END_RAW
<<END_EXPECTED
31 Dec 2001 - 23:59
END_EXPECTED
);
    $this->doTest(
<<END_RAW,
%DATETIME{format="\$day \$month \$year - \$hours:\$minutes" date="2001.12.31.23.59.59"}%
END_RAW
<<END_EXPECTED
31 Dec 2001 - 23:59
END_EXPECTED
);
    $this->doTest(
<<END_RAW,
%DATETIME{format="\$day \$month \$year - \$hours:\$minutes" date="2001/12/31 23:59"}%
END_RAW
<<END_EXPECTED
31 Dec 2001 - 23:59
END_EXPECTED
);
    $this->doTest(
<<END_RAW,
%DATETIME{format="\$day \$month \$year - \$hours:\$minutes" date="2001.12.31.23.59"}%
END_RAW
<<END_EXPECTED
31 Dec 2001 - 23:59
END_EXPECTED
);
    $this->doTest(
<<END_RAW,
%DATETIME{format="\$day \$month \$year - \$hours:\$minutes" date="2001-12-31 23:59"}%
END_RAW
<<END_EXPECTED
31 Dec 2001 - 23:59
END_EXPECTED
);
    $this->doTest(
<<END_RAW,
%DATETIME{format="\$day \$month \$year - \$hours:\$minutes" date="2001-12-31 - 23:59"}%
END_RAW
<<END_EXPECTED
31 Dec 2001 - 23:59
END_EXPECTED
);
    $this->doTest(
<<END_RAW,
%DATETIME{format="\$day \$month \$year - \$hours:\$minutes" date="2001-12-31T23:59:59"}%
END_RAW
<<END_EXPECTED
31 Dec 2001 - 23:59
END_EXPECTED
);
    $this->doTest(
<<END_RAW,
%DATETIME{format="\$day \$month \$year - \$hours:\$minutes" date="2001-12-31T23:59:59+01:00"}%
END_RAW
<<END_EXPECTED
31 Dec 2001 - 22:59
END_EXPECTED
);
    $this->doTest(
<<END_RAW,
%DATETIME{format="\$day \$month \$year - \$hours:\$minutes" date="2001-12-31T23:59Z"}%
END_RAW
<<END_EXPECTED
31 Dec 2001 - 23:59
END_EXPECTED
);
}

=pod

---++ Date relative

%DATETIME{date="31 Dec 2001" incdays="1"}%
%DATETIME{date="31 Dec 2001 - 07:00" format="$hours" inchours="-1"}%
%DATETIME{date="31 Dec 2001" format="$minutes" incminutes="15"}%
%DATETIME{date="31 Dec 2001" format="$seconds" incseconds="20"}%

Note: does not work yet with dates before 1970!

=cut

sub test_Date_Relative
{    
    my $this = shift;
    $this->doTest(
<<END_RAW,
%DATETIME{date="31 Dec 2001" incdays="1"}%
END_RAW
<<END_EXPECTED
01 Jan 2002
END_EXPECTED
);
    $this->doTest(
<<END_RAW,
%DATETIME{date="31 Dec 2001 - 07:00" format="\$hours" inchours="-1"}%
END_RAW
<<END_EXPECTED
06
END_EXPECTED
);
    $this->doTest(
<<END_RAW,
%DATETIME{date="31 Dec 2001" format="\$minutes" incminutes="15"}%
END_RAW
<<END_EXPECTED
15
END_EXPECTED
);
    $this->doTest(
<<END_RAW,
%DATETIME{date="31 Dec 2001" format="\$seconds" incseconds="20"}%
END_RAW
<<END_EXPECTED
20
END_EXPECTED
);
}

# test language
# timezone

1;
