# See bottom of file for copyright
package TWiki::Plugins::EditRowPlugin::TableCell;

use strict;
use Assert;

use TWiki::Func;

# Default format if no other format is defined for a cell
my $defCol ||= { type => 'text', size => 20, values => [] };

sub new {
    my ($class, $row, $text, $number) = @_;
    my $this = bless({}, $class);
    $this->{row} = $row;
    $this->{number} = $number;
    $text =~ s/^(\s*)//;
    $this->{precruft} = $1 || '';
    $text =~ s/(\s*)$//;
    $this->{postcruft} = $1 || '';
    if ($text =~ s/^\*(.*)\*$/$1/) {
        $this->{precruft} .= '*';
        $this->{postcruft} = '*'.$this->{postcruft};
        $this->{isHeader} = 1;
    }
    $this->{text} = $text;
    return $this;
}

sub finish {
    my $this = shift;
    $this->{row} = undef;
}

sub stringify {
    my $this = shift;

    return $this->{precruft}.$this->{text}.$this->{postcruft};
}

# Row index offset by size in the columnn definition
sub rowIndex {
    my ($this, $colDef) = @_;
    if ($this->{row}->{index}) {
        my $i = $this->{row}->{index} || 0;
        $i += $colDef->{size} - 1 if ($colDef->{size} =~ /^\d+$/);
        $this->{text} = $i;
    } else {
        $this->{text} = '';
    }
}

sub getCellName {
    my $this = shift;
    return 'erp_cell_'.$this->{row}->{table}->getNumber().'_'.
      $this->{row}->{number}.'_'.$this->{number};
}

# Get the HTML for the cell
sub _getCell {
    my ($this, $isHeader) = @_;
    my $text = $this->{text};
    $text = '-' unless defined $text;
    if ($isHeader) {
        $text = CGI::span(
            {
                class => 'erpSort',
                onclick => 'javascript: return sortTable(this, false, '.
                  $this->{row}->{table}->getHeaderRows().','.
                    $this->{row}->{table}->getFooterRows().')',
            }, $text);
    }
    return $this->{precruft}.$text.$this->{postcruft};
}

sub renderForDisplay {
    my ($this, $colDefs, $isHeader) = @_;
    my $colDef = $colDefs->[$this->{number} - 1] || $defCol;

    if (!$this->{isHeader} && !$this->{isFooter} &&
          $colDef->{type} eq 'row') {
        $this->{text} = $this->rowIndex( $colDef );
    }
    return $this->_getCell($isHeader);
}

sub renderForEdit {
    my ($this, $colDefs, $isHeader) = @_;
    my $colDef = $colDefs->[$this->{number} - 1] || $defCol;

    my $expandedValue = TWiki::Func::expandCommonVariables(
        $this->{text} || '');
    $expandedValue =~ s/^\s*(.*?)\s*$/$1/;

    my $text = '';
    my $cellName = $this->getCellName();

    if( $colDef->{type} eq 'select' ) {

        $text = "<select name='$cellName' size='$colDef->{size}'>";
        foreach my $option ( @{$colDef->{values}} ) {
            my $expandedOption =
              TWiki::Func::expandCommonVariables($option);
            $expandedOption =~ s/^\s*(.*?)\s*$/$1/;
            my %opts;
            if ($expandedOption eq $expandedValue) {
                $opts{selected} = 'selected';
            }
            $text .= CGI::option(\%opts, $option);
        }
        $text .= "</select>";

    } elsif ($colDef->{type} =~ /^(checkbox|radio)/) {

        my %attrs;
        my @defaults;
        my @options;
        $expandedValue = ",$expandedValue,";

        my $i = 0;
        foreach my $option (@{$colDef->{values}}) {
            push(@options, $option);
            my $expandedOption =
              TWiki::Func::expandCommonVariables($option);
            $expandedOption =~ s/^\s*(.*?)\s*$/$1/;
            $expandedOption =~ s/(\W)/\\$1/g;
            $attrs{$option}{label} = $expandedOption;
            if ($colDef->{type} eq 'checkbox') {
                $attrs{$option}{class} = 'twikiEditFormCheckboxField';
            } else {
                $attrs{$option}{class} =
                  'twikiRadioButton twikiEditFormRadioField';
            }

            if ($expandedValue =~ /,\s*$expandedOption\s*,/) {
                $attrs{$option}{checked} = 'checked';
                push( @defaults, $option );
            }
        }
        if ($colDef->{type} eq 'checkbox') {
            $text = CGI::checkbox_group(
                -name => $cellName,
                -values => \@options,
                -defaults => \@defaults,
                -columns => $colDef->{size},
                -attributes => \%attrs );

        } else {
            $text = CGI::radio_group(
                -name => $cellName,
                -values => \@options,
                -default => $defaults[0],
                -columns => $colDef->{size},
                -attributes => \%attrs );
        }

    } elsif( $colDef->{type} eq 'row' ) {

        $text = $isHeader ? '' : $this->rowIndex($colDef);

    } elsif( $colDef->{type} eq 'textarea' ) {

        my ($rows, $cols) = split( /x/i, $colDef->{size} );
        $rows =~ s/[^\d]//;
        $cols =~ s/[^\d]//;
        $rows = 3 if $rows < 1;
        $cols = 30 if $cols < 1;

        $text = CGI::textarea(
            -rows => $rows,
            -columns => $cols,
            -name => $cellName,
            -default => $this->{text});

    } elsif( $colDef->{type} eq 'date' ) {

        eval 'use TWiki::Contrib::JSCalendarContrib';

        if ($@) {
            # Calendars not available
            $text = CGI::textfield(-name => $cellName, -size => 10);
        } else {
            $text = TWiki::Contrib::JSCalendarContrib::renderDateForEdit(
                $cellName, $this->{text}, $colDef->{values}->[1]);
        }

    } elsif( $colDef->{type} eq 'label' ) {

        $text = $this->{text};

    } else { #  if( $colDef->{type} =~ /^text.*$/)

        my $val = $this->{text};
        $text = CGI::textfield({
            name => $cellName,
            size => $colDef->{size},
            value => $val });

    }
    return $this->{precruft}.TWiki::Plugins::EditRowPlugin::defend($text)
      .$this->{postcruft};
}

1;
__END__

Author: Crawford Currie http://c-dot.co.uk

Copyright (C) 2007 WindRiver Inc. and TWiki Contributors.
All Rights Reserved. TWiki Contributors are listed in the
AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

Do not remove this copyright notice.

This is an object that represents a single cell in a table.

=pod

---++ new(\$row, $cno)
Constructor
   * \$row - pointer to the row
   * $cno - what cell number this is (start at 1)

---++ finish()
Must be called to dispose of the object. This method disconnects internal pointers that would
otherwise make a Table and its rows and cells self-referential.

---++ stringify()
Generate a TML representation of the cell

---++ renderForEdit() -> $text
Render the cell for editing. Standard TML is used to construct the table.

---++ renderForDisplay() -> $text
Render the cell for display. Standard TML is used to construct the table.

=cut
