use strict;

package RenderTableDataPluginTests;

use base qw( FoswikiFnTestCase! );

use strict;
use TWiki::UI::Save;
use Error qw( :try );
use TWiki::Plugins::RenderTableDataPlugin;

sub new {
    my $self = shift()->SUPER::new( 'RenderTableDataPluginFunctions', @_ );
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
    }
    $this->assert_html_equals( $expected, $actual );
}

sub createTestTable {
    return <<END;
<verbatim>
| *No* | *Text*    |
| -1   | Do not    |
| -10  | read this |
</verbatim>

But we read this table:
| *Text* | *Number* | *Date*      | *Hidden* |
| ABC    | 123      | 30 Dec 2006 | 4        |
| DEF    | 456      | 01 Jan 2007 | 3        |
| GHI    | 789      | 01 Apr 2005 | 2        |
| JKL    | 999      | 31 Mar 2005 | 1        |

We do not read tables after the first one...
%TABLE{id="last"}%
| *No* | *Text*    |
| -1   | Do not    |
| -10  | read "this" |
| xxx | |

END
}

sub doTest
{
    my ($this, $raw_text, $expected ) = @_;
    $this->setupTestTopic();
    my $result =
      $this->{twiki}->handleCommonTags( $raw_text, $this->{test_web}, $this->{test_topic} );
    $this->assert_str_equals( $expected, $result, 0 );

    #$raw_text =~ s/(\s)/ord($1)/ge; print $raw_text,"\n";
    #$result =~ s/(\s)/ord($1)/ge; print $result,"\n";
}

sub setupTestTopic
{
    my $this = shift;
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web}, $this->{test_topic}, createTestTable());
}

=pod

Col 1
%TABLEDATA{cols="1" format="   * $C1$n()" }%

=cut

sub test_Cols1
{    
    my $this = shift;
    $this->doTest(
<<END_RAW,
%TABLEDATA{cols="1" format="   * \$C1\$n()" }%
END_RAW
<<END_EXPECTED . "\n"
   * *Text*
   * ABC
   * DEF
   * GHI
   * JKL
END_EXPECTED
);
}

=pod

cols="1..2"
%TABLEDATA{cols="1..2" format="   * $C1 $C2$n()" }%

=cut

sub test_Cols1To2
{    
    my $this = shift;
    $this->doTest(
<<END_RAW,
%TABLEDATA{cols="1..2" format="   * \$C1 \$C2\$n()" }%
END_RAW
<<END_EXPECTED . "\n"
   * *Text* *Number*
   * ABC 123
   * DEF 456
   * GHI 789
   * JKL 999
END_EXPECTED
);
}

=pod

Only column 2

%TABLEDATA{cols="2" format="   * $C2$n()" }%

=cut

sub test_Cols2
{    
    my $this = shift;
    $this->doTest(
<<END_RAW,
%TABLEDATA{cols="2" format="   * \$C2\$n()" }%
END_RAW
<<END_EXPECTED . "\n"
   * *Number*
   * 123
   * 456
   * 789
   * 999
END_EXPECTED
);
}

=pod

---+++ cols=2..2

%TABLEDATA{cols="2..2" format="   * $C2$n()" }%

=cut

sub test_Cols2To2
{    
    my $this = shift;
    $this->doTest(
<<END_RAW,
%TABLEDATA{cols="2..2" format="   * \$C2\$n()" }%
END_RAW
<<END_EXPECTED . "\n"
   * *Number*
   * 123
   * 456
   * 789
   * 999
END_EXPECTED
);
}

=pod

---+++ cols=2..

Columns 2 and higher

%TABLEDATA{cols="2.." format="   * $C2 $C3$n()" }%

=cut

sub test_Cols2AndHigher
{    
    my $this = shift;
    $this->doTest(
<<END_RAW,
%TABLEDATA{cols="2.." format="   * \$C2 \$C3\$n()" }%
END_RAW
<<END_EXPECTED . "\n"
   * *Number* *Date*
   * 123 30 Dec 2006
   * 456 01 Jan 2007
   * 789 01 Apr 2005
   * 999 31 Mar 2005
END_EXPECTED
);
}

=pod

---+++ rows=1
Only row 1

%TABLEDATA{rows="1" format="   * $C1 $C2 $C3$n()" }%

=cut

sub test_Rows1
{    
    my $this = shift;
    $this->doTest(
<<END_RAW,
%TABLEDATA{rows="1" format="   * \$C1 \$C2 \$C3\$n()" }%
END_RAW
<<END_EXPECTED . "\n"
   * *Text* *Number* *Date*
END_EXPECTED
);
}

=pod

---+++ rows=2
Only row 2

%TABLEDATA{rows="2" format="   * $C1 $C2 $C3$n()" }%

=cut

sub test_Rows2
{    
    my $this = shift;
    $this->doTest(
<<END_RAW,
%TABLEDATA{rows="2" format="   * \$C1 \$C2 \$C3\$n()" }%
END_RAW
<<END_EXPECTED . "\n"
   * ABC 123 30 Dec 2006
END_EXPECTED
);
}

=pod

---+++ rows=2..3
Rows 2 and 3

%TABLEDATA{rows="2..3" format="   * $C1 $C2 $C3$n()" }%

=cut

sub test_Rows2To3
{    
    my $this = shift;
    $this->doTest(
<<END_RAW,
%TABLEDATA{rows="2..3" format="   * \$C1 \$C2 \$C3\$n()" }%
END_RAW
<<END_EXPECTED . "\n"
   * ABC 123 30 Dec 2006
   * DEF 456 01 Jan 2007
END_EXPECTED
);
}

=pod

---+++ rows=2..
Rows 2 and higher

%TABLEDATA{rows="2.." format="   * $C1 $C2 $C3$n()" }%

=cut

sub test_Rows2AndHigher
{    
    my $this = shift;
    $this->doTest(
<<END_RAW,
%TABLEDATA{rows="2.." format="   * \$C1 \$C2 \$C3\$n()" }%
END_RAW
<<END_EXPECTED . "\n"
   * ABC 123 30 Dec 2006
   * DEF 456 01 Jan 2007
   * GHI 789 01 Apr 2005
   * JKL 999 31 Mar 2005
END_EXPECTED
);
}

=pod

---+++ rows=3..3

Only row 3

%TABLEDATA{rows="3..3" format="   * $C1 $C2 $C3$n()" }%

=cut

sub test_Rows3To3
{    
    my $this = shift;
    $this->doTest(
<<END_RAW,
%TABLEDATA{rows="3..3" format="   * \$C1 \$C2 \$C3\$n()" }%
END_RAW
<<END_EXPECTED . "\n"
   * DEF 456 01 Jan 2007
END_EXPECTED
);
}

=pod

---+++ cols=2 rows=2

One cell at (2,2)

%TABLEDATA{cols="2" rows="2" format="   * $C2$n()" }%

=cut

sub test_Cols2Rows2
{    
    my $this = shift;
    $this->doTest(
<<END_RAW,
%TABLEDATA{cols="2" rows="2" format="   * \$C2\$n()" }%
END_RAW
<<END_EXPECTED . "\n"
   * 123
END_EXPECTED
);
}

=pod

---+++ Wrapping ranges (negative show) - start negative range

Should display the last 2 rows.

%TABLEDATA{show="-2.." format="   * $C1 $C2 $C3$n()" }%

=cut

sub test_WrapRowsMinus2
{    
    my $this = shift;
    $this->doTest(
<<END_RAW,
%TABLEDATA{show="-2.." format="   * \$C1 \$C2 \$C3\$n()" }%
END_RAW
<<END_EXPECTED . "\n"
   * GHI 789 01 Apr 2005
   * JKL 999 31 Mar 2005
END_EXPECTED
);
}

=pod

---+++ Wrapping ranges (negative show) - end negative range

Should display the first 4 rows.

%TABLEDATA{show="..-2" format="   * $C1 $C2 $C3$n()" }%

=cut

sub test_WrapRowsToMinus2
{    
    my $this = shift;
    $this->doTest(
<<END_RAW,
%TABLEDATA{show="..-2" format="   * \$C1 \$C2 \$C3\$n()" }%
END_RAW
<<END_EXPECTED . "\n"
   * *Text* *Number* *Date*
   * ABC 123 30 Dec 2006
   * DEF 456 01 Jan 2007
   * GHI 789 01 Apr 2005
END_EXPECTED
);
}

=pod

---++ Out of range

%TABLEDATA{ rows="30.." format="   * $C1 $C2 $C3$n()" }%
%TABLEDATA{ rows="25..30" format="   * $C1 $C2 $C3$n()" }%
%TABLEDATA{ show="30.." format="   * $C1 $C2 $C3$n()" }%
%TABLEDATA{ show="25..30" format="   * $C1 $C2 $C3$n()" }%

=cut

sub test_OutOfRange
{    
    my $this = shift;
    $this->doTest(
<<END_RAW,
%TABLEDATA{ rows="30.." format="   * \$C1 \$C2 \$C3\$n()" }%
END_RAW
<<END_EXPECTED . "\n"
END_EXPECTED
);

    $this->doTest(
<<END_RAW,
%TABLEDATA{ rows="25..30" format="   * \$C1 \$C2 \$C3\$n()" }%
END_RAW
<<END_EXPECTED . "\n"
END_EXPECTED
);

    $this->doTest(
<<END_RAW,
%TABLEDATA{ show="30.." format="   * \$C1 \$C2 \$C3\$n()" }%
END_RAW
<<END_EXPECTED . "\n"
END_EXPECTED
);

    $this->doTest(
<<END_RAW,
%TABLEDATA{ show="25..30" format="   * \$C1 \$C2 \$C3\$n()" }%
END_RAW
<<END_EXPECTED . "\n"
END_EXPECTED
);
}

=pod

---+++ Sort column 1 (text)

%TABLEDATA{ rows="2.." sortcolumn="1" format="   * $C1 $C2 $C3$n()" }%

=cut

sub test_SortColumn1
{    
    my $this = shift;
    $this->doTest(
<<END_RAW,
%TABLEDATA{ rows="2.." sortcolumn="1" format="   * \$C1 \$C2 \$C3\$n()" }%
END_RAW
<<END_EXPECTED . "\n"
   * ABC 123 30 Dec 2006
   * DEF 456 01 Jan 2007
   * GHI 789 01 Apr 2005
   * JKL 999 31 Mar 2005
END_EXPECTED
);
}

=pod

---+++ Sort column 1 (text, descending)

%TABLEDATA{ rows="2.." sortcolumn="1" sortdirection="descending" format="   * $C1 $C2 $C3$n()" }%

=cut

sub test_SortColumn1Descending
{    
    my $this = shift;
    $this->doTest(
<<END_RAW,
%TABLEDATA{ rows="2.." sortcolumn="1" sortdirection="descending" format="   * \$C1 \$C2 \$C3\$n()" }%
END_RAW
<<END_EXPECTED . "\n"
   * JKL 999 31 Mar 2005
   * GHI 789 01 Apr 2005
   * DEF 456 01 Jan 2007
   * ABC 123 30 Dec 2006
END_EXPECTED
);
}

=pod

---+++ Sort column 2 (number)

%TABLEDATA{ rows="2.." sortcolumn="2" format="   * $C1 $C2 $C3$n()" }%

=cut

sub test_SortColumn2Number
{    
    my $this = shift;
    $this->doTest(
<<END_RAW,
%TABLEDATA{ rows="2.." sortcolumn="2" format="   * \$C1 \$C2 \$C3\$n()" }%
END_RAW
<<END_EXPECTED . "\n"
   * ABC 123 30 Dec 2006
   * DEF 456 01 Jan 2007
   * GHI 789 01 Apr 2005
   * JKL 999 31 Mar 2005
END_EXPECTED
);
}

=pod

---+++ Sort column 2 (number, descending)

%TABLEDATA{ rows="2.." sortcolumn="2" sortdirection="descending" format="   * $C1 $C2 $C3$n()" }%

=cut

sub test_SortColumn2NumberDescending
{    
    my $this = shift;
    $this->doTest(
<<END_RAW,
%TABLEDATA{ rows="2.." sortcolumn="2" sortdirection="descending" format="   * \$C1 \$C2 \$C3\$n()" }%
END_RAW
<<END_EXPECTED . "\n"
   * JKL 999 31 Mar 2005
   * GHI 789 01 Apr 2005
   * DEF 456 01 Jan 2007
   * ABC 123 30 Dec 2006
END_EXPECTED
);
}

=pod

---+++ Sort column 3 (date)

%TABLEDATA{ rows="2.." sortcolumn="3" format="   * $C1 $C2 $C3$n()" }%

=cut

sub test_SortColumn3Date
{    
    my $this = shift;
    $this->doTest(
<<END_RAW,
%TABLEDATA{ rows="2.." sortcolumn="3" format="   * \$C1 \$C2 \$C3\$n()" }%
END_RAW
<<END_EXPECTED . "\n"
   * JKL 999 31 Mar 2005
   * GHI 789 01 Apr 2005
   * ABC 123 30 Dec 2006
   * DEF 456 01 Jan 2007
END_EXPECTED
);
}

=pod

---+++ Sort column 3 (date, descending)

%TABLEDATA{ rows="2.." sortcolumn="3" sortdirection="descending" format="   * $C1 $C2 $C3$n()" }%

=cut

sub test_SortColumn3DateDescending
{    
    my $this = shift;
    $this->doTest(
<<END_RAW,
%TABLEDATA{ rows="2.." sortcolumn="3" sortdirection="descending" format="   * \$C1 \$C2 \$C3\$n()" }%
END_RAW
<<END_EXPECTED . "\n"
   * DEF 456 01 Jan 2007
   * ABC 123 30 Dec 2006
   * GHI 789 01 Apr 2005
   * JKL 999 31 Mar 2005
END_EXPECTED
);
}

=pod

---+++ Sort column 4 ('hidden' column)

The order of the table column cells is reversed on purpose.

%TABLEDATA{ rows="2.." sortcolumn="4" format="   * $C1 $C2 $C3 $C4$n()" }%

=cut

sub test_SortColumn4Hidden
{    
    my $this = shift;
    $this->doTest(
<<END_RAW,
%TABLEDATA{ rows="2.." sortcolumn="4" format="   * \$C1 \$C2 \$C3 \$C4\$n()" }%
END_RAW
<<END_EXPECTED . "\n"
   * JKL 999 31 Mar 2005 1
   * GHI 789 01 Apr 2005 2
   * DEF 456 01 Jan 2007 3
   * ABC 123 30 Dec 2006 4
END_EXPECTED
);
}

=pod

---+++ Sort column 4 ('hidden' column, descending)

The order of the table column cells is reversed on purpose.

%TABLEDATA{ rows="2.." sortcolumn="4" sortdirection="descending" format="   * $C1 $C2 $C3 $C4$n()" }%

=cut

sub test_SortColumn4HiddenDescending
{    
    my $this = shift;
    $this->doTest(
<<END_RAW,
%TABLEDATA{ rows="2.." sortcolumn="4" sortdirection="descending" format="   * \$C1 \$C2 \$C3 \$C4\$n()" }%
END_RAW
<<END_EXPECTED . "\n"
   * ABC 123 30 Dec 2006 4
   * DEF 456 01 Jan 2007 3
   * GHI 789 01 Apr 2005 2
   * JKL 999 31 Mar 2005 1
END_EXPECTED
);
}

=pod

---++ Show (limit results) - No sorting

Should display 2 rows (4 and 5) only.

%TABLEDATA{format="   * $C1 $C2 $C3$n()" show="4.." }%

=cut

sub test_Show4ToEnd
{    
    my $this = shift;
    $this->doTest(
<<END_RAW,
%TABLEDATA{format="   * \$C1 \$C2 \$C3\$n()" show="4.." }%
END_RAW
<<END_EXPECTED . "\n"
   * GHI 789 01 Apr 2005
   * JKL 999 31 Mar 2005
END_EXPECTED
);
}

=pod

---+++ After sorting (sortcolumn="4")

Should display 2 rows (4 and 5) only.

%TABLEDATA{sortcolumn="4" format="   * $C1 $C2 $C3$n()" show="4.." }%

=cut

sub test_Show4ToEndSorted4
{    
    my $this = shift;
    $this->doTest(
<<END_RAW,
%TABLEDATA{sortcolumn="4" format="   * \$C1 \$C2 \$C3\$n()" show="4.." }%
END_RAW
<<END_EXPECTED . "\n"
   * DEF 456 01 Jan 2007
   * ABC 123 30 Dec 2006
END_EXPECTED
);
}

=pod

---+++ After sorting descending (sortcolumn="4")

%TABLEDATA{sortcolumn="4" sortdirection="descending" format="   * $C1 $C2 $C3$n()" show="4.." }%

=cut

sub test_Show4ToEndSorted4Descending
{    
    my $this = shift;
    $this->doTest(
<<END_RAW,
%TABLEDATA{sortcolumn="4" sortdirection="descending" format="   * \$C1 \$C2 \$C3\$n()" show="4.." }%
END_RAW
<<END_EXPECTED . "\n"
   * JKL 999 31 Mar 2005
   * *Text* *Number* *Date*
END_EXPECTED
);
}

=pod

---+++ Combining rows and show

%TABLEDATA{rows="2.." format="   * $C1 $C2 $C3$n()" show="3.." }%

=cut

sub test_CombineRowsAndShow
{    
    my $this = shift;
    $this->doTest(
<<END_RAW,
%TABLEDATA{rows="2.." format="   * \$C1 \$C2 \$C3\$n()" show="3.." }%
END_RAW
<<END_EXPECTED . "\n"
   * GHI 789 01 Apr 2005
   * JKL 999 31 Mar 2005
END_EXPECTED
);
}

=pod

---+++ Combining rows and show, sorted descending

%TABLEDATA{rows="2.." sortdirection="descending" format="   * $C1 $C2 $C3$n()" show="3.." }%

=cut

sub test_CombineRowsAndShowSortDescending
{    
    my $this = shift;
    $this->doTest(
<<END_RAW,
%TABLEDATA{rows="2.." sortdirection="descending" format="   * \$C1 \$C2 \$C3\$n()" show="3.." }%
END_RAW
<<END_EXPECTED . "\n"
   * DEF 456 01 Jan 2007
   * ABC 123 30 Dec 2006
END_EXPECTED
);
}

=pod

---+++ separator

%TABLEDATA{cols="2..2" separator="," }%

=cut

sub test_Separator
{    
    my $this = shift;
    $this->doTest(
<<END_RAW,
%TABLEDATA{cols="2..2" separator="," }%
END_RAW
<<END_EXPECTED
*Number*,123,456,789,999
END_EXPECTED
);
}

=pod

---+++ id

%TABLEDATA{id="last" rows="2" cols="1" }%

=cut

sub test_Id
{    
    my $this = shift;
    $this->doTest(
<<END_RAW,
%TABLEDATA{id="last" rows="2" cols="1" }%
END_RAW
<<END_EXPECTED
-1
END_EXPECTED
);
}

=pod

---+++ preservespaces

%TABLEDATA{id="last" rows="2" cols="1" preservespaces="on"}%

=cut

sub test_PreserveSpaces
{    
    my $this = shift;
    $this->doTest(
<<END_RAW,
%TABLEDATA{id="last" rows="2" cols="1" preservespaces="on"}%
END_RAW
<<END_EXPECTED
 -1   
END_EXPECTED
);
}


=pod

---+++ escapequotes (default)

%TABLEDATA{id="last" rows="3" cols="2"}%

=cut

sub test_EscapeQuotesDefault
{    
    my $this = shift;
    $this->doTest(
<<END_RAW,
%TABLEDATA{id="last" rows="3" cols="2" }%
END_RAW
<<END_EXPECTED
read \\"this\\"
END_EXPECTED
);
}

=pod

---+++ escapequotes (default)

%TABLEDATA{id="last" rows="3" cols="2" escapequotes="off"}%

=cut

sub test_EscapeQuotesOff
{    
    my $this = shift;
    $this->doTest(
<<END_RAW,
%TABLEDATA{id="last" rows="3" cols="2" escapequotes="off"}%
END_RAW
<<END_EXPECTED
read "this"
END_EXPECTED
);
}

=pod

---+++ beforetext

%TABLEDATA{id="last" rows="2" cols="2" beforetext="Results:$n()"}%

=cut

sub test_BeforeText
{    
    my $this = shift;
    $this->doTest(
<<END_RAW,
%TABLEDATA{id="last" rows="2" cols="2" beforetext="Results:\$n()"}%
END_RAW
<<END_EXPECTED
Results:
Do not
END_EXPECTED
);
}

=pod

---+++ aftertext

%TABLEDATA{id="last" rows="2" cols="2" aftertext="For more information see..."}%

=cut

sub test_AfterText
{    
    my $this = shift;
    $this->doTest(
<<END_RAW,
%TABLEDATA{id="last" rows="2" cols="2" aftertext="\$n()For more information see..."}%
END_RAW
<<END_EXPECTED
Do not
For more information see...
END_EXPECTED
);
}

=pod

---+++ limit

%TABLEDATA{id="last" rows="2" cols="2" format="$C2(2)"}%

=cut

sub test_Limit2
{    
    my $this = shift;
    $this->doTest(
<<END_RAW,
%TABLEDATA{id="last" rows="2" cols="2" format="\$C2(2)"}%
END_RAW
<<END_EXPECTED
Do
END_EXPECTED
);
}

=pod

---+++ limit with placeholder

%TABLEDATA{id="last" rows="2" cols="2" format="$C2(2)"}%

=cut

sub test_Limit2Placeholder
{    
    my $this = shift;
    $this->doTest(
<<END_RAW,
%TABLEDATA{id="last" rows="2" cols="2" format="\$C2(2,...)"}%
END_RAW
<<END_EXPECTED
Do...
END_EXPECTED
);
}

=pod

---+++ if: cell isempty

%TABLEDATA{id="last" rows="4" format="$C2(\"isempty\" then=\"empty\" else=\"not empty\")"}%

%TABLEDATA{id="last" rows="4" format="$C1(\"isempty\" then=\"empty\" else=\"not empty\")"}%

=cut

sub test_CellIsEmpty
{    
    my $this = shift;
    $this->doTest(
<<END_RAW,
%TABLEDATA{id="last" rows="4" format="\$C2(\\"isempty\\" then=\\"empty\\" else=\\"not empty\\")"}%
END_RAW
<<END_EXPECTED
empty
END_EXPECTED
);
    $this->doTest(
<<END_RAW,
%TABLEDATA{id="last" rows="4" format="\$C1(\\"isempty\\" then=\\"empty\\" else=\\"not empty\\")"}%
END_RAW
<<END_EXPECTED
not empty
END_EXPECTED
);
}

=pod

---+++ if: cell value

%TABLEDATA{id="last" rows="4" format="$C1(\"='xxx'\" then=\"true\" else=\"not true\")"}%

=cut

sub test_CellValue
{    
    my $this = shift;
    $this->doTest(
<<END_RAW,
%TABLEDATA{id="last" rows="4" format="\$C1(\\"='xxx'\\" then=\\"true\\" else=\\"false\\")"}%
END_RAW
<<END_EXPECTED
true
END_EXPECTED
);
    $this->doTest(
<<END_RAW,
%TABLEDATA{id="last" rows="4" format="\$C1(\\"='yyy'\\" then=\\"true\\" else=\\"false\\")"}%
END_RAW
<<END_EXPECTED
false
END_EXPECTED
);
}

1;
