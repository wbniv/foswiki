#!/usr/bin/perl -w
BEGIN {
  foreach my $pc (split(/:/, $ENV{FOSWIKI_LIBS})) {
    unshift @INC, $pc;
  }
}

use TWiki::Contrib::Build;

package DBCacheBuild;

@DBCacheBuild::ISA = ( "TWiki::Contrib::Build" );

sub new {
  my $class = shift;
  return bless( $class->SUPER::new( "LdapContrib" ), $class );
}

$build = new DBCacheBuild();

$build->build($build->{target});
