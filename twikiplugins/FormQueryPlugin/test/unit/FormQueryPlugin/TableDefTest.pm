package TableDefTest;

use base qw(Unit::TestCase);
use TWiki::Plugins::FormQueryPlugin::TableDef;
use TWiki::Contrib::DBCacheContrib::Map;

sub new {
  my $self = shift()->SUPER::new(@_);
  # your state for fixture here
  return $self;
}

sub test_parse1 {
  my $this=shift;
  my $td = new TWiki::Plugins::FormQueryPlugin::TableDef( "
blah
%EDITTABLE{format=\"|text,16,none|select,1,a,b|\" header=\"|*Fld1*|*This is field 2*\"}%
junk");

  my $map = $td->loadRow("|A|B|C|","TWiki::Contrib::DBCacheContrib::Map");
  $this->assert_str_equals("A",$map->get("Fld1"));
  $this->assert_str_equals("B",$map->get("Thisisfield2"));
}

1;

