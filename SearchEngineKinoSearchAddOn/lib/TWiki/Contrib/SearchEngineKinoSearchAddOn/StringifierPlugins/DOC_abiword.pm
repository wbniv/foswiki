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

package TWiki::Contrib::SearchEngineKinoSearchAddOn::StringifyPlugins::DOC_abiword;
use base 'TWiki::Contrib::SearchEngineKinoSearchAddOn::StringifyBase';
use File::Temp qw/tmpnam/;
use Encode;
use TWiki;

#only load abiword if the user has selected it in configure - Sven has had no success with it
if (defined($TWiki::cfg{SearchEngineKinoSearchAddOn}{WordIndexer}) && 
    ($TWiki::cfg{SearchEngineKinoSearchAddOn}{WordIndexer} eq 'abiword')) {
# Only if abiword exists, I register myself.
    if (__PACKAGE__->_programExists('abiword')){
        __PACKAGE__->register_handler("application/word", ".doc");
    }
}



sub stringForFile {
    my ($self, $file) = @_;
    my $tmp_file = tmpnam() . ".html";

    # mensagens de erro do abiword ignoradas
    my $cmd = "abiword --to=$tmp_file '$file' 2>/dev/null";
    system($cmd);

    # The I use the HTML stringifier to convert HTML to TXT
    my $text = TWiki::Contrib::SearchEngineKinoSearchAddOn::Stringifier->stringFor($tmp_file);

    unlink($tmp_file);
    $cmd = "rm -rf " . $tmp_file . "_files";
    system($cmd);

    return $text;
}

1;
