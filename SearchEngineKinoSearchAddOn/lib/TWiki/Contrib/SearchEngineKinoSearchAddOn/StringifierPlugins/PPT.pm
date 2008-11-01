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


package TWiki::Contrib::SearchEngineKinoSearchAddOn::StringifyPlugins::PPT;
use base 'TWiki::Contrib::SearchEngineKinoSearchAddOn::StringifyBase';
use TWiki::Contrib::SearchEngineKinoSearchAddOn::Stringifier;
use File::Temp qw/tmpnam/;

# Only if ppthtml exists, I register myself.
if (__PACKAGE__->_programExists("ppthtml")){
    __PACKAGE__->register_handler("text/ppt", ".ppt");
}

sub stringForFile {
    my ($self, $filename) = @_;
    my $tmp_file = tmpnam();
    
    # First I convert PPT to HTML
    my $cmd = "ppthtml '$filename' > $tmp_file 2>/dev/null";
    return "" unless ((system($cmd) == 0) && (-f $tmp_file));

    # Then I use the HTML stringifier to convert HTML to TXT
    my $text = TWiki::Contrib::SearchEngineKinoSearchAddOn::Stringifier->stringFor($tmp_file);

    unlink($tmp_file);

    return $text;
}

1;
