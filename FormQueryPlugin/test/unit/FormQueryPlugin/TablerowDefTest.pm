package TablerowDefTest;

use base qw(Unit::TestCase);
use TWiki::Plugins::FormQueryPlugin::TablerowDef;
use TWiki::Contrib::DBCacheContrib::Map;

sub new {
  my $self = shift()->SUPER::new(@_);
  # your state for fixture here
  return $self;
}

sub test_parse1 {
  my $this=shift;
  my $td = new TWiki::Plugins::FormQueryPlugin::TablerowDef( "
blah
| *Name*    | *Type* | *Size* | *Values* | *Tooltip message* |
| Fld1	    | text   | 16     |		 |		     |
| This is field 2  | text   | 16     |		 |		     |
junk");

  my $map = $td->loadRow("|A|B|C|","TWiki::Contrib::DBCacheContrib::Map");
  $this->assert_str_equals("A",$map->get("Fld1"));
  $this->assert_str_equals("B",$map->get("Thisisfield2"));
}

1;

