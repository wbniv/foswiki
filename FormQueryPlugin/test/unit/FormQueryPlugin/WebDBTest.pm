use strict;
use Benchmark;

package WebDBTest;

use base qw(FoswikiFnTestCase);

use TWiki::Plugins::FormQueryPlugin;
use TWiki::Plugins::FormQueryPlugin::WebDB;
use TWiki::Func;
use Error qw(:try);

my $db;
my $truesum;

$TWiki::regex{mixedAlpha} = "[:alpha:]";

sub new {
    my $self = shift()->SUPER::new('WebDBTest', @_);
    return $self;
}

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    $TWiki::cfg{DBCacheContrib}{Archivist} =
      'TWiki::Contrib::DBCacheContrib::Archivist::Storable';
    my $dbt;
    foreach my $d (@INC) {
        if (-e "$d/../test/unit/FormQueryPlugin/testDB.dat") {
            open(DB,"<$d/../test/unit/FormQueryPlugin/testDB.dat") ||
              die "No test database";
            local $/;
            $dbt = <DB>;
            close(DB);
            foreach my $t ( split(/\<TOPIC\>/,$dbt)) {
                if ( $t =~ m/\"(.*?)\"/o ) {
                    TWiki::Func::saveTopicText($this->{test_web}, $1, $t);
                }
            }
            last;
        }
    }

    $truesum = 0;
    foreach my $t ( split(/\n/,$dbt)) {
        if ( $t =~ /\|\s*(\d+)\s*\|/o ) {
            $truesum += $1;
        }
    }

    # re-read to force preference refresh
    my $q = new CGI("");
    $q->path_info("/$this->{test_web}");
    $this->{twiki} = new TWiki(undef, $q);

    #$ TWiki::Plugins::FormQueryPlugin::WebDB::storable = 0;
    $this->{db} = new TWiki::Plugins::FormQueryPlugin::WebDB(
        $this->{test_web} );
    $this->{db}->load();
    $TWiki::Plugins::FormQueryPlugin::moan = 1;
}

sub test_badFQ {
    my $this = shift;
    my $db = $this->{db};
    my $res;
    try {
        $res = $db->formQueryOnDB(undef, "name='Dir1'");
        $this->assert(0);
    } catch Error::Simple with {
        $this->assert_str_equals("'name' not defined", shift->{-text});
    };

    try {
        $res = $db->formQueryOnDB('fred', "name='Dir1");
        $this->assert(0);
    } catch Error::Simple with {
        $this->assert_str_equals("'search' not defined, or invalid search expression: ", shift->{-text});
    };

    try {
        $res = $db->formQueryOnDB('fred',  "topic='Dir75'");
        $this->assert(0);
    } catch Error::Simple with {
        $this->assert_str_equals("No values returned", shift->{-text});
    };
}

sub test_formQuery {
    my $this = shift;
    my $db = $this->{db};
    my $res = $db->formQueryOnDB('fred',  "topic='Dir1'");
    $this->assert_str_equals("", $res);
    my $qr = $db->query('fred');
    $this->assert_equals(1, $qr->size());
    $qr = $qr->get(0);
    $qr = $qr->get("topic");
    $this->assert_str_equals("Dir1", $qr);

    # check that the subdir relation has been created
    my $dir = $db->query('fred')->get(0);
    my $subdirs = $dir->get("subdir");
    $this->assert_equals(4,$subdirs->size());
    # and that the reverse relation exists
    for (my $i = 0; $i < 4; $i++) {
        my $subdir = $subdirs->get($i);
        $this->assert_equals($dir,$subdir->get("subdir_of"));
    }
}

sub test_queryGoes {
    my $this = shift;
    my $db = $this->{db};
    my $res = $db->formQueryOnDB('fred', "topic='Dir1'");
    $this->assert_str_equals("", $res);
    try {
        $res = $db->formQueryOnDB('fred', "topic='Dir99'");
        $db->query('fred')
    } catch Error::Simple with {
        $this->assert_str_equals('No values returned', shift->{-text});
    };
}

sub noest_extractOnEmpty {
    my $this = shift;
    my $db = $this->{db};

    my $res = $db->formQueryOnDB('fred', "name='NonExistant'", "FileTable");
    $this->assert_str_equals("", $res);
}

sub test_extractRef {
    my $this = shift;
    my $db = $this->{db};
    my $res = $db->formQueryOnDB('smee', "topic='Dir1_1'", "subdir_of");
    $this->assert_str_equals("", $res);
    my $dir = $db->query('smee')->get(0);
    $this->assert_str_equals("Dir1",$dir->get("topic"));
}

sub test_tables {
    my $this = shift;
    my $db = $this->{db};
    my $res = $db->formQueryOnDB('fred', "topic='Dir1'");
    $this->assert_str_equals("", $res);
    my $dir = $db->query('fred')->get(0);

    $res = $db->formQueryOnDB('fred', "topic='Dir1'", "DirTable");
    $this->assert_str_equals("", $res);

    my $table = $db->query('fred');
    $this->assert_equals(6, $table->size());
    my $list = "Main,TWiki,Test,Trash,_default,";
    foreach my $val ( $table->getValues()) {
        my $top = $val->get("Name");
        $list =~ s/$top,//;
        my $mummy = $val->get("_up");
        $this->assert_equals($dir, $mummy);
    }
    $this->assert_str_equals("", $list);

    if (0 && $TWiki::cfg{Plugins}{SpreadSheetPlugin}{Enabled}) {
        # This was added by Thomas, but doesn't work, and I don't understand
        # how it was ever meant to
        $res = TWiki::Plugins::FormQueryPlugin::WebDB::formQueryOnQuery(
                'joe', "\$CALC(\"\$TIME(\$T(Date))\") > \$CALC(\"\$TIME(9 Sep 2001)\")", 'fred');
        $this->assert_str_equals("", $res);
        my $qr = $db->query('joe');
        $this->assert_equals(2, $qr->size());
    }
}

sub test_sumQuery {
    my $this = shift;
    my $db = $this->{db};
    my $res=$db->formQueryOnDB('fred', "", "FileTable");
    $this->assert_str_equals("", $res);
    my $sum = TWiki::Plugins::FormQueryPlugin::WebDB::sumQuery('fred', "Size");

    $this->assert_equals($truesum, $sum);
}

sub test_tableFormat {
    my $this = shift;
    my $db = $this->{db};
    my $attrs = new TWiki::Attrs( "header=\"| *Name* | *Parent* |\" format=\"|\$topic|\$subdir_of.name|\" sort=\"topic\"" );
    my $res = TWiki::Plugins::FormQueryPlugin::WebDB::tableFormat("TF", "|\$RealName|\$Level|", $attrs);
    $this->assert_str_equals("", $res);
    $res = $db->formQueryOnDB('fred', "name='.*'");
    my $qr = $db->query('fred');
    $attrs = new TWiki::Attrs( "format=\"TF\"" );
    $res = TWiki::Plugins::FormQueryPlugin::WebDB::showQuery('fred', "TF", $attrs);
    $this->assert_str_equals("OK", $res) unless ( $res =~ /^\| \*Name/);
}

sub test_checkTableParse {
    my $this=shift;
    my $db = $this->{db};
    # Dir1_1 is formatted with \ in the table
    my $res = $db->formQueryOnDB('fred', "topic='Dir1_1'", "FileTable");
    $this->assert_str_equals("", $res);
    my $qr = $db->query('fred');
    $this->assert_equals(26, $qr->size());
}

sub test_fieldSum {
    my $this = shift;
    my $db = $this->{db};

    my $res = $db->formQueryOnDB('fred', "topic='Dir1_2'");
    $this->assert_str_equals("", $res);
    my $attrs = new TWiki::Attrs( "header=\"\" format=\"\$FileTable.Size\"" );
    $res = TWiki::Plugins::FormQueryPlugin::WebDB::tableFormat("TF", "\$FileTable.Size", $attrs);
    $this->assert_str_equals("", $res);
    my $qr = $db->query('fred');
    $attrs = new TWiki::Attrs( "format=\"TF\"" );
    $res = TWiki::Plugins::FormQueryPlugin::WebDB::showQuery('fred', "TF", $attrs);

    my $truesum = 163+709+281+691+417+987+283+466+942+686+2060+163+280+124+2597+56+729+3146+158+850+572+803+332;

    $this->assert_equals($truesum, $res);
}

sub test_more_fqp {
    my $this = shift;
    my $db = $this->{db};
    my $attrs = new TWiki::Attrs( "format=\"\$web.\$topic \" sort=\"topic\"" );
    my $showattrs = new TWiki::Attrs( "format=\"TF\"" );
    my $res = TWiki::Plugins::FormQueryPlugin::WebDB::tableFormat(
        "\$web.\$topic ", $attrs);
    $res = $db->formQueryOnDB('q2',  "DirTable.0.Date =~ '2001'");
    $this->assert_str_equals("", $res);
    my $qr = $db->query('q2');
    $this->assert_equals(3, $qr->size());
    $qr = $qr->get(0);
    $qr = $qr->get("topic");
    $this->assert_str_equals("Dir4", $qr);

    $res = $db->formQueryOnDB('q3',  "", "DirTable[?Date=~'2001']");
    $this->assert_str_equals("", $res);
    $qr = $db->query('q3');
    $this->assert_equals(11, $qr->size());

    $res = $db->formQueryOnDB('q3',  "", "DirTable");
    $this->assert_str_equals("", $res);
    $qr = $db->query('q3');
    $this->assert_equals(11, $qr->size());

    $res = $db->formQueryOnDB('q3',  "", 'form');
    $this->assert_str_equals("", $res);
    $qr = $db->query('q3');
    $this->assert_equals(11, $qr->size());
}

sub test_calc {
    my $this = shift;
    my $db = $this->{db};

    my $res = $db->formQueryOnDB('q3', "", "DirTable");
    $this->assert_str_equals("", $res);
    my $qr = $db->query('q3');
    $this->assert_equals(11, $qr->size());

    my $attrs = new TWiki::Attrs( "format=\"|[[\$_up.web.\$_up.topic]]|\$Name|\$Date|\" sort=\"Name\"" );
    $res = TWiki::Plugins::FormQueryPlugin::WebDB::toTable('q3', "|[[\$_up.web.\$_up.topic]]|\$Name|\$Date|\" sort=\"Name\"", $attrs, "WebHome", "Test", "WikiGuest", "TWiki");
    $this->assert_str_equals("", $res);
    #  $res = TWiki::Plugins::FormQueryPlugin::_handleCalcTable("SHOWCALC", "\$ROW()");
    $res = TWiki::Plugins::SpreadSheetPlugin::Calc::doCalc("\$ROW()");
    $this->assert_str_equals("11", $res);
    #  $res = TWiki::Plugins::FormQueryPlugin::_handleCalcTable("SHOWCALC", "\$T(R1:C1)");
    $res = TWiki::Plugins::SpreadSheetPlugin::Calc::doCalc("\$T(R1:C1)");
    $this->assert_str_equals("[[$this->{test_web}.Dir1]]", $res);

    $res = $db->formQueryOnDB('q3', "", "form");
    $this->assert_str_equals("", $res);
    $qr = $db->query('q3');
    $this->assert_equals(11, $qr->size());

    $attrs = new TWiki::Attrs( "format=\"|[[\$_up.web.\$_up.name]]|\$Level|\$RealName|\"" );
    $res = TWiki::Plugins::FormQueryPlugin::WebDB::toTable('q3', "\"|[[\$_up.web.\$_up.name]]|\$Level|\$RealName|\"", $attrs, "WebHome", "Test", "WikiGuest", "TWiki");
    $this->assert_str_equals("", $res);
    #  $res = TWiki::Plugins::FormQueryPlugin::_handleCalcTable("SHOWCALC", "\$ROW()");
    # How on earth is this supposed to work? It depends on having parsed the
    # table from the topic. I have to assume it's a broken test.
    ##$res = TWiki::Plugins::SpreadSheetPlugin::Calc::doCalc("\$ROW()");
    #$this->assert_str_equals("11", $res);
    #  $res = TWiki::Plugins::FormQueryPlugin::_handleCalcTable("SHOWCALC", "\$SUM(R1:C2..R\$ROW():C2)");
    #$res = TWiki::Plugins::SpreadSheetPlugin::Calc::doCalc("\$SUM(R1:C2..R\$ROW():C2)");
    #$this->assert_str_equals("17", $res);

    ##  $res = TWiki::Plugins::FormQueryPlugin::_handleShowQuery("SHOWQUERY", "query=\"q3\" format=\"|%CALC{\\\"\$dollarROW()\\\"}\$percnt()|[[\$_up.web.\$_up.name]]|\$Level|\$RealName|\"" );
    #$attrs = new TWiki::Attrs( "format=\"|%CALC{\\\"\$dollarROW()\\\"}\$percnt()|[[\$_up.web.\$_up.name]]|\$Level|\$RealName|\"" );
    #$res = TWiki::Plugins::FormQueryPlugin::WebDB::showQuery('q3', "\"|%CALC{\\\"\$dollarROW()\\\"}\$percnt()|[[\$_up.web.\$_up.name]]|\$Level|\$RealName|\"", $attrs, "Test", $this->{test_web}, $this->{twiki}->{user});
    #print $res;
    #print TWiki::Func::getRenderedVersion($res);
    #$this->assert_str_equals(542, length($res));
}

my $bmdb;

sub bmFn {
    $bmdb->formQueryOnDB("FORMQUERY", "q1", "name='Dir\\d_\\d'", "FileTable");
    TWiki::Plugins::FormQueryPlugin::WebDB::formQueryOnQuery("q2", "Type='text'", "q1");
}

sub dont_test_benchmarkFormQuery {
    my $this = shift;
    my $db = $this->{db};

    $bmdb = $db;
    my $t = Benchmark::timeit(1000,'&bmFn()');
    print STDERR "\n>>> 1000 queries took ",$t->timestr(),"\n";
}

1;
