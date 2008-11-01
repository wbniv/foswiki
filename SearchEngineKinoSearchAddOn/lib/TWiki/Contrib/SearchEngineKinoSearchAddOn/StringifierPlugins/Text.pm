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

package TWiki::Contrib::SearchEngineKinoSearchAddOn::StringifyPlugins::Text;
use base 'TWiki::Contrib::SearchEngineKinoSearchAddOn::StringifyBase';
use Encode;
use CharsetDetector;

# Note: I need not do any register, because I am the default handler for stringification!

sub stringForFile {
    my ($self, $file) = @_;
    my $in;
    open $in, $file or return "";

    my $text = "";
    while (<$in>) {
        chomp;

        my $charset = CharsetDetector::detect1($_);
        my $aux_text = "";
        if ($charset =~ "utf") {
            $aux_text = encode("iso-8859-15", decode($charset, $_));
            $aux_text = $_ unless($aux_text);
        } else {
            $aux_text = $_;
        }
        $text .= " " . $aux_text;
    }

    close($in);

    return $text;
}
1;
