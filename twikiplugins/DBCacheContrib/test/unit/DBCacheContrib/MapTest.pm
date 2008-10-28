package MapTest;

use TWiki::Contrib::DBCacheContrib::Map;
use TWiki::Contrib::DBCacheContrib::Search;
use base qw(Unit::TestCase);

sub new {
    my $self = shift()->SUPER::new(@_);
    # your state for fixture here
    return $self;
}

sub test_parse1 {
    my $this = shift;
    my $attrs = new TWiki::Contrib::DBCacheContrib::Map( "a = one bit=\"two\" c" );
    $this->assert_not_null($attrs);
    $this->assert_str_equals("one", $attrs->get("a"));
    $this->assert_str_equals("two", $attrs->get("bit"));
    $this->assert_str_equals("on", $attrs->get("c"));
}

sub test_parse2 {
    my $this = shift;
    my $attrs = new TWiki::Contrib::DBCacheContrib::Map( "aname = one,b = \"two\",c" );
    $this->assert_not_null($attrs);
    $this->assert_str_equals("one", $attrs->get("aname"));
    $this->assert_str_equals("two", $attrs->get("b"));
    $this->assert_str_equals("on", $attrs->get("c"));
}

sub test_parse3 {
    my $this = shift;
    my $attrs = new TWiki::Contrib::DBCacheContrib::Map( "x.y=one" );
    $this->assert_not_null($attrs);
    $this->assert_str_equals("one", $attrs->get("x.y"));
}

sub test_parse4 {
    my $this = shift;
    my $attrs;
    eval { new TWiki::Contrib::DBCacheContrib::Map( "topic=MacroReqDetails area = \"Signal Integrity\" status=\"Assigned\" release=\"2003.06|All product=\"Fsim\"" ); };

    $this->assert_not_null($@);
}

sub test_remove {
    my $this = shift;
    my $attrs = new TWiki::Contrib::DBCacheContrib::Map( "a = one bit=\"two\" c" );
    $this->assert_not_null($attrs);
    $this->assert_str_equals("one", $attrs->remove("a"));
    $this->assert_str_equals("two", $attrs->remove("bit"));
    $this->assert_str_equals("on", $attrs->remove("c"));
    $this->assert_null($attrs->get("a"));
    $this->assert_null($attrs->get("bit"));
    $this->assert_null($attrs->get("c"));
}

sub test_multipleDefs1 {
    my $this = shift;
    my $attrs = new TWiki::Contrib::DBCacheContrib::Map( "a = one a=\"two\"" );
    $this->assert_not_null($attrs);
    $this->assert_str_equals("two", $attrs->get("a"));
}

sub testMultipleDefs2 {
    my $this = shift;
    my $attrs = new TWiki::Contrib::DBCacheContrib::Map( "a=\"two\" a" );
    $this->assert_not_null($attrs);
    $this->assert_str_equals("on", $attrs->remove("a"));
}

sub testMultipleDefs3 {
    my $this = shift;
    my $attrs = new TWiki::Contrib::DBCacheContrib::Map( "a=two a" );
    $this->assert_not_null($attrs);
    $this->assert_str_equals("on", $attrs->remove("a"));
}

sub testMultipleDefs4 {
    my $this = shift;
    my $attrs = new TWiki::Contrib::DBCacheContrib::Map( "a a = one" );
    $this->assert_not_null($attrs);
    $this->assert_str_equals("one", $attrs->remove("a"));
}

# Where did this come from? Undocumented "feature"
#sub testStringOnOwn {
#  my $this = shift;
#  my $attrs = new TWiki::Contrib::DBCacheContrib::Map( "\"able cain\" a=\"no\"" );
#  $this->assert_not_null($attrs);
#  $this->assert_str_equals("able cain", $attrs->get("\$1"));
#  $this->assert_str_equals("no", $attrs->remove("a"));
#}

sub test_big {
    my $this = shift;
    my $n = 0;
    my $str = "";
    while ( $n < 1000 ) {
        $str .= ",a$n=b$n";
        $n++;
    }
    my $attrs = new TWiki::Contrib::DBCacheContrib::Map( $str );
}

sub test_set {
    my $this = shift;
    my $attrs = new TWiki::Contrib::DBCacheContrib::Map( "\"able cain\" a=\"no\"" );
    $attrs->set( "2", "two" );
    $this->assert_equals(3, $attrs->size());
    $this->assert_str_equals("able cain", $attrs->remove("\$1"));
    $this->assert_str_equals("no", $attrs->remove("a"));
    $this->assert_str_equals("two", $attrs->remove("2"));
    $this->assert_equals(0, $attrs->size());
}

sub test_kandv {
    my $this = shift;
    my $attrs = new TWiki::Contrib::DBCacheContrib::Map( "a=A b=B c=C d=D" );
    $this->assert_equals(4, $attrs->size());
    my $tst = "abcd";
    foreach my $val ($attrs->getKeys()) {
        $tst =~ s/$val//;
    }
    $this->assert_equals("", $tst);
    $tst = "ABCD";
    foreach my $val ($attrs->getValues()) {
        $tst =~ s/$val//;
    }
    $this->assert_equals("", $tst);
}

sub test_search {
    my $this = shift;
    my $attrs = new TWiki::Contrib::DBCacheContrib::Map();
    $attrs->set("a", new TWiki::Contrib::DBCacheContrib::Map("f=A"));
    $attrs->set("b", new TWiki::Contrib::DBCacheContrib::Map("f=B"));
    $attrs->set("c", new TWiki::Contrib::DBCacheContrib::Map("f=C"));
    $attrs->set("d", new TWiki::Contrib::DBCacheContrib::Map("f=D"));
    $this->assert_equals(4, $attrs->size());
    my $search = new TWiki::Contrib::DBCacheContrib::Search("f=~'(B|C)'");
    my $res = $attrs->search($search);
    my $tst = "BC";
    foreach my $e ($res->getValues()) {
        my $v = $e->get("f");
        $tst =~ s/$v//;
    }
    $this->assert_str_equals("", $tst);
}

sub test_get {
    my $this = shift;
    my $a = new TWiki::Contrib::DBCacheContrib::Map("name=a");
    my $b = new TWiki::Contrib::DBCacheContrib::Map("name=b");
    my $c = new TWiki::Contrib::DBCacheContrib::Map("name=c");

    $a->set("b", $b);
    $a->set("c", $c);
    $a->set("ref", "b");
    $b->set("a", $a);
    $b->set("c", $c);
    $b->set("ref", "c");
    $c->set("a", $a);
    $c->set("b", $b);
    $c->set("ref", "a");

    $this->assert_str_equals("a", $a->get("name", $a));
    $this->assert_str_equals("a", $a->get(".name", $a));
    $this->assert_str_equals("a", $a->get("[name]", $a));
    $this->assert_str_equals("b", $a->get("b.name", $a));
    $this->assert_str_equals("b", $a->get("b[name]", $a));
    $this->assert_str_equals("c", $a->get("[c].name", $a));
    $this->assert_str_equals("c", $a->get("[c][name]", $a));
    $this->assert_str_equals("a", $a->get("[c.ref].name", $a));
}

1;
