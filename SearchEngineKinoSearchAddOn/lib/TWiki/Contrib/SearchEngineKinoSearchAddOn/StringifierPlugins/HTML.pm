# For licensing info read LICENSE file in the TWiki root.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at 
# http://www.gnu.org/copyleft/gpl.html


package TWiki::Contrib::SearchEngineKinoSearchAddOn::StringifyPlugins::HTML;
use base 'TWiki::Contrib::SearchEngineKinoSearchAddOn::StringifyBase';
use HTML::TreeBuilder;
use Encode;
use CharsetDetector;

__PACKAGE__->register_handler("text/html", ".html");

sub stringForFile {
    my ($self, $filename) = @_;
    my $tree = HTML::TreeBuilder->new;
    open(my $fh, "<", $filename) || return "";

    my $text = "";
    while (<$fh>) {
        my $aux_text = "";
        my $charset = CharsetDetector::detect1($_);
        if ($charset =~ "utf") {
            $aux_text = encode("iso-8859-15", decode("utf-8", $_));
            $aux_text = $_ unless (defined($aux_text));
        } else {
            $aux_text = $_;
        }

        $text .= $aux_text;
    }
    close($fh);

    $tree->parse($text);

    $text = "";
    for($tree->look_down(_tag => "meta")) {
        next if $_->attr("http-equiv");
        next unless $_->attr("value");

        $text .=  $_->attr("value");
        $text .=  " ";
    }
    for (@{$tree->extract_links("a")}) {

        $text .=  $_->[0];
        $text .=  " ";
    }

    $text .= $tree->as_trimmed_text;
    $text = encode("iso-8859-15", $text);

    return $text;
}

1;
