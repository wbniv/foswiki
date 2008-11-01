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

package TWiki::Contrib::SearchEngineKinoSearchAddOn::StringifyPlugins::XLS;
use base 'TWiki::Contrib::SearchEngineKinoSearchAddOn::StringifyBase';
__PACKAGE__->register_handler("application/excel", ".xls");

use Spreadsheet::ParseExcel;
use Encode;

sub stringForFile {
    my ($self, $file) = @_;

    my $book  = Spreadsheet::ParseExcel::Workbook->Parse($file);
    return unless $book;

    my $text = '';

    foreach my $sheet (@{$book->{Worksheet}}) {
        last if !defined $sheet->{MaxRow};
        foreach my $row ($sheet->{MinRow} .. $sheet->{MaxRow}) {
            foreach my $col ($sheet->{MinCol} .. $sheet->{MaxCol}) {
                my $cell = $sheet->{Cells}[$row][$col];
                if ($cell) {
                    my $cell_text;
                    if ($cell->{Type} eq "Numeric") {
                        $cell_text = $cell->{Val};
                    } else {
                        $cell_text = $cell->Value;
                    }
                    next if ($cell_text eq "");

                    $text .= $cell_text;
                }
                $text .= " ";
            }
            $text .= "\n";
        }
        $text .= "\n\n";
    }

    $text = encode("iso-8859-15", $text);
    return $text;
}

1;
