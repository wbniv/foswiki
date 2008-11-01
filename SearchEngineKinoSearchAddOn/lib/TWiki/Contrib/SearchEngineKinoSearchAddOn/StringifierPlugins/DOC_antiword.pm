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

package TWiki::Contrib::SearchEngineKinoSearchAddOn::StringifyPlugins::DOC_antiword;
use base 'TWiki::Contrib::SearchEngineKinoSearchAddOn::StringifyBase';
use File::Temp qw/tmpnam/;

if (!defined($TWiki::cfg{SearchEngineKinoSearchAddOn}{WordIndexer}) || 
    ($TWiki::cfg{SearchEngineKinoSearchAddOn}{WordIndexer} eq 'antiword')) {
    # Only if antiword exists, I register myself.
    if (__PACKAGE__->_programExists("antiword")){
        __PACKAGE__->register_handler("application/word", ".doc");
    }
}

sub stringForFile {
    my ($self, $file) = @_;
    my $tmp_file = tmpnam();
    my $in;
    my $text = '';

    my $cmd = "antiword '$file' > $tmp_file 2>/dev/null";
    system($cmd);

    ###########
    # Note: This way, the encoding of the text is reworked in the text stringifier.
    # Note2: May be this is not necessary: My UnitTest says NO...
    $text = TWiki::Contrib::SearchEngineKinoSearchAddOn::Stringifier->stringFor($tmp_file);

    #open $in, $tmp_file;
    #$text = join(" ", <$in>); 
    #close($in);
    ###############

    unlink($tmp_file);
    return $text;
}

1;
