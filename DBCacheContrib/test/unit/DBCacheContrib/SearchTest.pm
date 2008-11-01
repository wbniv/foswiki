package SearchTest;
use base qw(Unit::TestCase);

use TWiki::Contrib::DBCacheContrib::Map;
use TWiki::Contrib::DBCacheContrib::Search;
use TWiki::Time;

sub new {
    my $self = shift()->SUPER::new(@_);
    $self->{map} = undef;
    return $self;
}

sub set_up {
    my $this = shift;
    $this->{map} = new TWiki::Contrib::DBCacheContrib::Map("
     string = \"String\",
     number = 99,
     date = \"3 Jul 1960\"");
    # date's a sunday!
    my $mother = new TWiki::Contrib::DBCacheContrib::Map("who=Mother");
    $this->{map}->set("mother", $mother);
    my $gran = new TWiki::Contrib::DBCacheContrib::Map("who=GrandMother");
    $mother->set("mother", $gran);
}

sub tear_down {
    my $this = shift;
    $this->{map} = undef;
}

sub test_empty {
    my $this = shift;
    my $search = new TWiki::Contrib::DBCacheContrib::Search("");
    $this->assert_not_null( $search );
    $this->assert_equals(1,$search->matches($this->{map}));
}

sub test_badparse1 {
    my $this = shift;
    eval {  new TWiki::Contrib::DBCacheContrib::Search("WITHIN_DAYS"); };
    $this->assert_not_null($@,$@);
}

sub test_badparse2 {
    my $this = shift;
    eval {  new TWiki::Contrib::DBCacheContrib::Search("x WITHIN_DAYS 30"); };
    $this->assert_not_null($@,$@);
}

sub test_badparse3 {
    my $this = shift;
    eval {  new TWiki::Contrib::DBCacheContrib::Search("z WITHIN_DAYS < 3"); };
    $this->assert_not_null($@,$@);
}

sub check {
    my ( $this, $query, $expect ) = @_;
    my $search = new TWiki::Contrib::DBCacheContrib::Search($query);
    my $result = $search->matches($this->{map});
    $this->assert_equals($expect, $result,
                         $search->toString().
                           " expected $expect in ".
                             $this->{map}->toString());
}

sub test_stringops1 {
    my $this = shift;
    $this->check("string='String'",1);
}

sub test_stringops2 {
    my $this = shift;
    $this->check("string='String '",0);
}
sub test_stringops3 {
    my $this = shift;
    $this->check("string=~'String '", 0);
}

sub test_stringops4 {
    my $this = shift;
    $this->check("string='Str'", 0);
}

sub test_stringops5 {
    my $this = shift;
    $this->check("string=~'trin'", 1);
}

sub test_stringops6 {
    my $this = shift;
    $this->check("string=~' String'", 0);
}
sub test_stringops7 {
    my $this = shift;
    $this->check("string!='Str'", 1);
}

sub test_stringops8 {
    my $this = shift;
    $this->check("string!='String '", 1);
}

sub test_stringops9 {
    my $this = shift;
    $this->check("string!='String'", 0);
}

sub test_numops1 {
    my $this = shift;
    $this->check("number='99'",1);
}

sub test_numops2 {
    my $this = shift;
    $this->check("number='98'", 0);
}

sub test_numops3 {
    my $this = shift;
    $this->check("number!='99'", 0);
}

sub test_numops4 {
    my $this = shift;
    $this->check("number!='0'", 1);
}

sub test_numops5 {
    my $this = shift;
    $this->check("number<'100'", 1);
}

sub test_numops6 {
    my $this = shift;
    $this->check("number<'99'", 0);
}

sub test_numops7 {
    my $this = shift;
    $this->check("number>'98'", 1);
}

sub test_numops8 {
    my $this = shift;
    $this->check("number>'99'", 0);
}

sub test_numops9 {
    my $this = shift;
    $this->check("number<='99'", 1);
}

sub test_numops10 {
    my $this = shift;
    $this->check("number<='100'", 1);
}

sub test_numops11 {
    my $this = shift;
    $this->check("number<='98'", 0);
}

sub test_numops12 {
    my $this = shift;
    $this->check("number>='98'", 1);
}

sub test_numops13 {
    my $this = shift;
    $this->check("number>='99'", 1);
}

sub test_numops14 {
    my $this = shift;
    $this->check("number>='100'", 0);
}

sub test_dateops1 {
    my $this = shift;
    $this->check("date IS_DATE '3 jul 1960'", 1);
}

sub test_dateops2 {
    my $this = shift;
    $this->check("date IS_DATE '3-JUL-1960'", 1);
}

sub test_dateops3 {
    my $this = shift;
    $this->check("date IS_DATE '4-JUL-1960'", 0);
}

sub test_dateops4 {
    my $this = shift;
    $this->check("date EARLIER_THAN '4-JUL-1960'",1);
}

sub test_dateops5 {
    my $this = shift;
    $this->check("date EARLIER_THAN '3-JUL-1960'", 0);
}

sub test_dateops6 {
    my $this = shift;
    $this->check("date EARLIER_THAN '2-JUL-1960'", 0);
}

sub test_dateops7 {
    my $this = shift;
    $this->check("date LATER_THAN '2-Jul-1960'", 1);
}

sub test_dateops8 {
    my $this = shift;
    $this->check("date LATER_THAN '3 jul 1960'", 0);
}

sub test_dateops9 {
    my $this = shift;
    $this->check("date LATER_THAN '4 jul 1960'", 0);
}

sub test_dateops10 {
    my $this = shift;
    TWiki::Contrib::DBCacheContrib::Search::forceTime("30 jun 1960");#thursday
    $this->check("date WITHIN_DAYS '4'", 1);
}

sub test_dateops11 {
    my $this = shift;
    TWiki::Contrib::DBCacheContrib::Search::forceTime("30 jun 1960");#thursday
    $this->check("date WITHIN_DAYS '3'", 1);
}

sub test_dateops12 {
    my $this = shift;
    TWiki::Contrib::DBCacheContrib::Search::forceTime("30 jun 1960");#thursday
    $this->check("date WITHIN_DAYS '2'", 1); # th & fri
}

sub test_dateops13 {
    my $this = shift;
    TWiki::Contrib::DBCacheContrib::Search::forceTime("30 jun 1960");#thursday
    $this->check("date WITHIN_DAYS '1'", 0);
}

sub test_dateops14 {
    my $this = shift;
    TWiki::Contrib::DBCacheContrib::Search::forceTime("30 jun 1960");#thursday
    $this->check("date WITHIN_DAYS '0'", 0);
}

sub test_dateops15 {
    my $this = shift;
    my $nows = time();
    my $now = TWiki::Time::formatTime($nows, "\$email", "gmtime");
    TWiki::Contrib::DBCacheContrib::Search::forceTime($now);
    my $then = TWiki::Time::formatTime($nows-2*24*60*60, "\$email", "gmtime");
    $this->{map}->set("date", $then);
    $this->check("date LATER_THAN 'now - 3 days'", 1);
    $this->check("date LATER_THAN '-3 days'", 1);
    $this->check("date LATER_THAN 'now - 1 days'", 0);
    $this->{map}->set("date", $nows-2*24*60*60);
    $this->check("'now - 3 days' EARLIER_THAN date", 1);
    $this->check("'now - 1 days' LATER_THAN date", 1);
}

sub test_dateops16 {
    my $this = shift;
    TWiki::Contrib::DBCacheContrib::Search::forceTime("3 jul 1960");
}

sub test_dateops17 {
    my $this = shift;
    TWiki::Contrib::DBCacheContrib::Search::forceTime("3 jul 1960");
    $this->check("date WITHIN_DAYS '2'", 1);
}

sub test_dateops18 {
    my $this = shift;
    TWiki::Contrib::DBCacheContrib::Search::forceTime("3 jul 1960");
    $this->check("date WITHIN_DAYS '1'", 1);
}

sub test_dateops19 {
    my $this = shift;
    TWiki::Contrib::DBCacheContrib::Search::forceTime("3 jul 1960");
    $this->check("date WITHIN_DAYS '0'", 1);
}

sub test_dateops20 {
    my $this = shift;
    TWiki::Contrib::DBCacheContrib::Search::forceTime("4 jul 1960");
    $this->check("date WITHIN_DAYS '2'", 0);
}

sub test_dateops21 {
    my $this = shift;
    TWiki::Contrib::DBCacheContrib::Search::forceTime("4 jul 1960");
    $this->check("date WITHIN_DAYS '1'", 0);
}

sub test_dateops22 {
    my $this = shift;
    TWiki::Contrib::DBCacheContrib::Search::forceTime("4 jul 1960");
    $this->check("date WITHIN_DAYS '0'", 0);
}

sub test_not1 {
    my $this = shift;
    $this->check("!number='99'",0);
}

sub test_not2 {
    my $this = shift;
    $this->check("!number='98'", 1);
}

sub test_not3 {
    my $this = shift;
    $this->check("number!='98'", 1);
}

sub test_not4 {
    my $this = shift;
    $this->check("!!number='99'", 1);
}


sub test_and1 {
    my $this = shift;
    $this->check("number='99' AND string='String'",1);
}

sub test_and2 {
    my $this = shift;
    $this->check("number='98' AND string='String'", 0);
}

sub test_and3 {
    my $this = shift;
    $this->check("number='99' AND string='Sring'", 0);
}

sub test_and4 {
    my $this = shift;
    $this->check("number='99' AND string='String' AND date IS_DATE '3 jul 1960'", 1);
}

sub test_or1 {
    my $this = shift;
    $this->check("number='99' OR string='Spring'",1);
}

sub test_or2 {
    my $this = shift;
    $this->check("number='99' OR string='Spring'",1);
}

sub test_or3 {
    my $this = shift;
    $this->check("number='98' OR string='String'", 1);
}

sub test_or4 {
    my $this = shift;
    $this->check("number='98' OR string='Spring'", 0);
}

sub conjoin {
    my ( $this, $last, $A, $B, $a, $b, $c, $r ) = @_;

    my $ae = "number='" . ( $a ? "99" : "98" ) . "'";
    my $be = "string='" . ( $b ? "String" : "Spring" ) . "'";
    my $ce = "date EARLIER_THAN '" . ( $c ? "4-jul-1960" : "3-jul-1960" ) . "'";
    my $expr;
    if ( $last ) {
        $expr = "$ae $A ( $be $B $ce )";
    } else {
        $expr = "( $ae $A $be ) $B $ce";
    }
    $this->check($expr,$r);
}

sub test_brackets {
    my $this = shift;
    for (my $a = 0; $a < 2; $a++) {
        for (my $b = 0; $b < 2; $b++) {
            for (my $c = 0; $c < 2; $c++) {
                $this->conjoin(1,"AND","OR", $a, $b, $c, $a && ($b || $c));
                $this->conjoin(1,"OR","AND", $a, $b, $c, $a || ($b && $c));
                $this->conjoin(0,"AND","OR",$a, $b, $c, ($a && $b) || $c);
                $this->conjoin(0,"OR","AND",$a, $b, $c, ($a || $b) && $c);
            }
        }
    }
}

sub test_node1 {
    my $this = shift;
    $this->check("mother.who='Mother'",1);
}

sub test_node2 {
    my $this = shift;
    $this->check("mother.who!='Mother'",0);
}

sub test_node3 {
    my $this = shift;
    $this->check("mother.mother.who='GrandMother'",1);
}

sub test_caseops1 {
    my $this = shift;
    $this->check("string='String'",1);
}

sub test_caseops2 {
    my $this = shift;
    $this->check("string='string '",0);
}

sub test_caseops3 {
    my $this = shift;
    $this->check("string=lc 'string '",0);
}

sub test_caseops4 {
    my $this = shift;
    $this->check("uc string=uc 'string '",0);
}

sub test_caseops5 {
    my $this = shift;
    $this->check("uc(string)=uc 'string '",0);
}

1;
