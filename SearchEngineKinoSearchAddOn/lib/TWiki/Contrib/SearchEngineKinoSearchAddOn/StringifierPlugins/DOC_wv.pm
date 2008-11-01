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

package TWiki::Contrib::SearchEngineKinoSearchAddOn::StringifyPlugins::DOC_wv;
use base 'TWiki::Contrib::SearchEngineKinoSearchAddOn::StringifyBase';
use File::Temp qw/tmpnam/;

if (!defined($TWiki::cfg{SearchEngineKinoSearchAddOn}{WordIndexer}) || 
    ($TWiki::cfg{SearchEngineKinoSearchAddOn}{WordIndexer} eq 'wvHtml')) {
    # Only if wv exists, I register myself.
    if (__PACKAGE__->_programExists("wvHtml")){
        __PACKAGE__->register_handler("application/word", ".doc");
    }
}

sub stringForFile {
    my ($self, $file) = @_;
    my ($tmp_file, $tmp_dir);

    # Creates a temp file name and checks if it exists
    do {
        $tmp_file = tmpnam();
        $tmp_dir = $tmp_file;
        $tmp_dir =~ s/^(.*)\/.*$/$1/;
        $tmp_file =~ s/.*\///;
    } while (-f "$tmp_dir/$tmp_file");

    my $in;
    my $text = '';

    my $cmd = "wvHtml --targetdir=$tmp_dir '$file' $tmp_file >/dev/null 2>&1";
    $tmp_file = "$tmp_dir/$tmp_file";
    return "" if (((system($cmd)) != 0) || (!(-f $tmp_file)) || (-z $tmp_file));

    $text = TWiki::Contrib::SearchEngineKinoSearchAddOn::Stringifier->stringFor($tmp_file);

    # Deletes temp files (main html and images)
    $self->rmtree($tmp_file);

    return $text;
}

1;
