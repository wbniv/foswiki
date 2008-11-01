package TableFormatTest;

use TWiki::Plugins::FormQueryPlugin::TableFormat;
use TWiki::Contrib::DBCacheContrib::Map;
use TWiki::Contrib::DBCacheContrib::Array;
use TWiki::Func;
use base qw(Unit::TestCase);

#$TWiki::regex{mixedAlpha} = "[:alpha:]";

sub new {
  my $self = shift()->SUPER::new(@_);
  # your state for fixture here
  return $self;
}

sub set_up {
  my $this = shift;
}

sub test_1 {
  my $this = shift;

  my $attrs = new TWiki::Attrs( "header=\"|*X*|*Y*|\" format=\"|\$X|\$Y|\" sort=\"X\"" );
  my $tf = new TWiki::Plugins::FormQueryPlugin::TableFormat( $attrs );

  my $data = new TWiki::Contrib::DBCacheContrib::Array();
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=0 Y=0"));
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=0 Y=1"));
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=1 Y=0"));
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=1 Y=1"));

  my $res = $tf->formatTable($data);
  $this->assert_not_null($res);
  $this->assert($res =~ s/[\s\n\r]//g);
  $this->assert_str_equals("|*X*|*Y*||0|0||0|1||1|0||1|1|", $res);
}

sub test_1reverse {
  my $this = shift;

  my $attrs = new TWiki::Attrs( "header=\"|*X*|*Y*|\" format=\"|\$X|\$Y|\" sort=\"-X\"" );
  my $tf = new TWiki::Plugins::FormQueryPlugin::TableFormat( $attrs );

  my $data = new TWiki::Contrib::DBCacheContrib::Array();
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=0 Y=0"));
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=0 Y=1"));
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=1 Y=0"));
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=1 Y=1"));

  my $res = $tf->formatTable($data);
  $this->assert_not_null($res);
  $res =~ s/[\s\n\r]//g;
  $this->assert_str_equals("|*X*|*Y*||1|0||1|1||0|0||0|1|", $res);

}

sub test_2 {
  my $this = shift;

  my $attrs = new TWiki::Attrs( "header=\"|*X*|*Y*|\" format=\"|\$X|\$Y|\" sort=\"Y,X\"" );
  my $tf = new TWiki::Plugins::FormQueryPlugin::TableFormat( $attrs );

  my $data = new TWiki::Contrib::DBCacheContrib::Array();
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=0 Y=0"));
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=0 Y=1"));
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=1 Y=0"));
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=1 Y=1"));

  my $res = $tf->formatTable($data);
  $this->assert_not_null($res);
  $res =~ s/[\s\n\r]//g;
  $this->assert_str_equals("|*X*|*Y*||0|0||1|0||0|1||1|1|", $res);

}

sub test_2reverse {
  my $this = shift;

  my $attrs = new TWiki::Attrs( "header=\"|*X*|*Y*|\" format=\"|\$X|\$Y|\" sort=\"-Y,-X\"" );
  my $tf = new TWiki::Plugins::FormQueryPlugin::TableFormat( $attrs );

  my $data = new TWiki::Contrib::DBCacheContrib::Array();
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=0 Y=0"));
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=0 Y=1"));
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=1 Y=0"));
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=1 Y=1"));

  my $res = $tf->formatTable($data);
  $this->assert_not_null($res);
  $res =~ s/[\s\n\r]//g;
  $this->assert_str_equals("|*X*|*Y*||1|1||0|1||1|0||0|0|", $res);
}

sub test_3numeric {
  my $this = shift;

  my $attrs = new TWiki::Attrs( "header=\"|*X*|*Y*|\" format=\"|\$X|\$Y|\" sort=\"#X\"" );
  my $tf = new TWiki::Plugins::FormQueryPlugin::TableFormat( $attrs );

  my $data = new TWiki::Contrib::DBCacheContrib::Array();
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=3 Y=0"));
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=20 Y=1"));
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=110 Y=0"));
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=005 Y=1"));

  my $res = $tf->formatTable($data);
  $this->assert_not_null($res);
  $res =~ s/[\s\n\r]//g;
  $this->assert_str_equals("|*X*|*Y*||3|0||005|1||20|1||110|0|", $res);
}

sub test_4numericreverse {
  my $this = shift;

  my $attrs = new TWiki::Attrs( "header=\"|*X*|*Y*|\" format=\"|\$X|\$Y|\" sort=\"-#X\"" );
  my $tf = new TWiki::Plugins::FormQueryPlugin::TableFormat( $attrs );

  my $data = new TWiki::Contrib::DBCacheContrib::Array();
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=3 Y=0"));
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=20 Y=1"));
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=110 Y=0"));
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=005 Y=1"));

  my $res = $tf->formatTable($data);
  $this->assert_not_null($res);
  $res =~ s/[\s\n\r]//g;
  $this->assert_str_equals("|*X*|*Y*||110|0||20|1||005|1||3|0|", $res);
}

# Note done yet...
sub dont_test_5 {
  my $this = shift;

  my $attrs = new TWiki::Attrs( "header=\"|*X*|*Y*|\" format=\"|\$X|\$Y|\" sort=\"Y,X\"" );
  my $tfi = new TWiki::Plugins::FormQueryPlugin::TableFormat( $attrs );
  $tfi->addToCache("FF");
  $attrs = new TWiki::Attrs( "header=\"|*X*|*Y*|\" format=\"|\$X|\$Y|\" sort=\"X,Y\"" );
  my $tfa = new TWiki::Plugins::FormQueryPlugin::TableFormat( $attrs );
  $tfa->addToCache("GG");
  $attrs = new TWiki::Attrs( "header=\"|*T1*|*T2*|\" format=\"|\$T1[format=FF]|\$T2[format=GG]|\"" );
  my $tfo = new TWiki::Plugins::FormQueryPlugin::TableFormat( $attrs );

  my $datao = new TWiki::Contrib::DBCacheContrib::Array();
  my $submap = new TWiki::Contrib::DBCacheContrib::Map();
  $datao->add($submap);

  my $dataX = new TWiki::Contrib::DBCacheContrib::Array();
  $dataX->add(new TWiki::Contrib::DBCacheContrib::Map("X=0 Y=0"));
  $dataX->add(new TWiki::Contrib::DBCacheContrib::Map("X=0 Y=1"));
  $dataX->add(new TWiki::Contrib::DBCacheContrib::Map("X=1 Y=0"));
  $dataX->add(new TWiki::Contrib::DBCacheContrib::Map("X=1 Y=1"));
  $submap->set( "T1", $dataX );

  my $dataY = new TWiki::Contrib::DBCacheContrib::Array();
  $dataY->add(new TWiki::Contrib::DBCacheContrib::Map("X=2 Y=2"));
  $dataY->add(new TWiki::Contrib::DBCacheContrib::Map("X=2 Y=3"));
  $dataY->add(new TWiki::Contrib::DBCacheContrib::Map("X=3 Y=2"));
  $dataY->add(new TWiki::Contrib::DBCacheContrib::Map("X=3 Y=3"));
  $submap->set( "T2", $dataY );

  my $res = $tfo->formatTable($datao);
  $res =~ s/[\s\n\r]//geo;
TWiki::writeDebug("res=$res");
  $this->assert_str_equals("|*T1*|*T2*|||*X*|*Y*||0|0||1|0||0|1||1|1|||*X*|*Y*||2|2||2|3||3|2||3|3||", $res);

  # Take out the top level table
  $this->assert_not_null($res =~ s/^$TS(.*)$TE$/$1/mo);
  # Take out the first row
  $this->assert_not_null($res =~ s/^$RH$DS \*T1\* $DE$DS \*T2\* $DE<\/tr>//o);
  # And the end of the second row
  $this->assert_not_null($res =~ s/^$RS(.*)\<\/tr\>$/$1/o);
  # Split the subsidiary tables
  $this->assert_not_null($res =~ s/^$DS $TS(.*)$TE $DE$DS $TS(.*)$TE $DE$//o, $res);
  my $t1 = $1;
  my $t2 = $2;
  $this->assert_str_equals("", $res);
  $this->assert_not_null($t1 =~ s/^$RH$DS \*X\* $DE$DS \*Y\* $DE$RE//o);
  $this->assert_not_null($t1 =~ s/^$RS$DS g0g $DE$DS g0g $DE$RE//o);
  $this->assert_not_null($t1 =~ s/^$RS$DS r1r $DE$DS g0g $DE$RE//o);
  $this->assert_not_null($t1 =~ s/^$RS$DS g0g $DE$DS r1r $DE$RE//o);
  $this->assert_not_null($t1 =~ s/^$RS$DS r1r $DE$DS r1r $DE$RE//o);
  $this->assert_str_equals("", $t1);

  $this->assert_not_null($t2 =~ s/^$TS(.*)$TE$/$1/o, $res);

  $this->assert_not_null($t2 =~ s/^$RH$DS \*X\* $DE$DS \*Y\* $DE$RE//o);
  $this->assert_not_null($t2 =~ s/^$RS$DS 2 $DE$DS 2 $DE$RE//o);
  $this->assert_not_null($t2 =~ s/^$RS$DS 2 $DE$DS 3 $DE$RE//o);
  $this->assert_not_null($t2 =~ s/^$RS$DS 3 $DE$DS 2 $DE$RE//o);
  $this->assert_not_null($t2 =~ s/^$RS$DS 3 $DE$DS 3 $DE$RE//o);
  $this->assert_str_equals("", $t2);
}

1;
