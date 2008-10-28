#!/usr/bin/perl -w
#
# Build file for TWiki Draw Plugin
#
# Standard preamble
BEGIN {
  foreach my $pc (split(/:/, $ENV{TWIKI_LIBS})) {
    unshift @INC, $pc;
  }
}

use TWiki::Contrib::Build;

# Declare our build package
package TWikiDrawPluginBuild;

@TWikiDrawPluginBuild::ISA = ( "TWiki::Contrib::Build" );

sub new {
    my $class = shift;
    return bless( $class->SUPER::new( "TWikiDrawPlugin" ), $class );
}

# Override the build target to build the java code
sub target_build {
  my $this = shift;

  $this->SUPER::target_build();

  $this->pushd($this->{basedir}."/lib/TWiki/Plugins/TWikiDrawPlugin");
  $this->sys_action("ant -f build.xml build");
  $this->popd();
}

# Create the build object
$build = new TWikiDrawPluginBuild();

# Build the target on the command line, or the default target

$build->build($build->{target});

