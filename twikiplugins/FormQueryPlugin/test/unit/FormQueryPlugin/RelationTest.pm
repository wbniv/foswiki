package RelationTest;

use TWiki::Contrib::DBCacheContrib::Map;
use TWiki::Plugins::FormQueryPlugin::Relation;

use base qw(Unit::TestCase);

sub new {
  my $self = shift()->SUPER::new(@_);
  return $self;
}

sub test_mkrel {
  my $this = shift;

  my $rel = new TWiki::Plugins::FormQueryPlugin::Relation("Son%Ax%B is Father%A");
  $this->assert_str_equals("is", $rel->parentToChild());
  $this->assert_str_equals("is_of", $rel->childToParent());
  $this->assert_str_equals("Father2", $rel->apply("Son2x3"));
  $this->assert_str_equals("FatherFleegle", $rel->apply("SonFleeglex3"));
}

sub test_kids {
  my $this = shift;

  my $rel = new TWiki::Plugins::FormQueryPlugin::Relation("Daughter%Aof%B Mummy Mother%B");
  $this->assert_equals("Mother5", $rel->apply("Daughter2of5"));
  my $known = new TWiki::Contrib::DBCacheContrib::Map("Daughter1of5,Daughter2of5,Daughter99of5");
  my $newKid = $rel->nextChild("Mother5", $known);
  $this->assert_str_equals("Daughter\nof5", $newKid);
}

1;
