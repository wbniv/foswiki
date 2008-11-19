#!/usr/bin/perl
#
# Static HTML -> TML converter
#
# cd to the tools directory to run it

BEGIN { do '../bin/setlib.cfg'; }

use Foswiki::Plugins::WysiwygPlugin::HTML2TML;

use Foswiki::Plugins::WysiwygPlugin::TML2HTML;
my $html2tml = new Foswiki::Plugins::WysiwygPlugin::HTML2TML();
undef $/;
my $html = <>;
my $tml = $html2tml->convert( $html, { very_clean=>1 } );
print $tml;
