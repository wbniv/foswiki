use strict;

package PodPluginTests;

use base qw(TWikiFnTestCase);

use strict;
use TWiki;
use CGI;

sub new {
   my $self = shift()->SUPER::new(@_);
   return $self;
}

# Set up the test fixture
sub set_up {
   my $this = shift;

   $this->SUPER::set_up();

   $TWiki::Plugins::SESSION = $this->{twiki};
}

sub tear_down {
   my $this = shift;

   $this->SUPER::tear_down();
}

sub test_conversion_of_head1_title {
   my $this = shift;
   my $text = '=head1 TITULO';
   TWiki::Plugins::PodPlugin::commonTagsHandler($text, $this->{test_topic}, $this->{test_web});
   $this->assert($text =~ m{<h1><a name="titulo">TITULO</a></h1>}g);
}

sub test_conversion_of_list_item {
   my $this = shift;
   my $text = <<POD;
=head1 NAME

NAME OF MODULE

=over 4

=item *

TEST ITEM

=back
POD
   TWiki::Plugins::PodPlugin::commonTagsHandler($text, $this->{test_topic}, $this->{test_web});
   $this->assert($text =~ m{<ul>\s*<li></li>\s*TEST ITEM\s*</ul>}gs);
}

sub test_link_to_other_pod {
   my $this = shift;
   my $text = <<POD;
=head1 NAME

NAME OF MODULE

=head1 SEE ALSO

L<perlfunc>

POD
   TWiki::Plugins::PodPlugin::commonTagsHandler($text, $this->{test_topic}, $this->{test_web});
   $this->assert($text =~ m{<a href="Perlfunc">the perlfunc manpage</a>}gs);
}

sub test_conversion_of_strong {
   my $this = shift;
   my $text = <<POD;
=head1 NAME

NAME OF MODULE

=head1 DESCRIPTION

B<bold text> ...

POD
   TWiki::Plugins::PodPlugin::commonTagsHandler($text, $this->{test_topic}, $this->{test_web});
   $this->assert($text =~ m{<strong>bold text</strong>}gs);
}

1;
