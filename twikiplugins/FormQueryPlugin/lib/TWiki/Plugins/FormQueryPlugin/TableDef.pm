#
# Copyright (C) Motorola 2003 - All rights reserved
#
use strict;
use integer;

use TWiki::Attrs;

# A table definition object. This encapsulates the formatting of
# a "table" object inside a topic - or at least, mostly. The
# invoked still has to know what a table looks like at the start
# so it knows when to start loading rows.
package TWiki::Plugins::FormQueryPlugin::TableDef;

# PUBLIC
# Generate a new table def by reading topic text and extracting
# the first EDITTABLE from it.
sub new {
    my ( $class, $text ) = @_;

    my $params;
    foreach my $line ( split( /\n/, $text )) {
      if ( $line =~ m/%EDITTABLE{(.*?)}%/o ) {
	$params = $1;
	last;
      }
    }

    my $attrs = new TWiki::Attrs( $params );
    my $hdrdef = $attrs->{header};
    if ( !defined( $hdrdef ) || $hdrdef eq 'on' ) {
        return undef;
    }

    my $this = bless( {}, $class );
    foreach my $column ( split( /\|/, $hdrdef )) {
        if ( $column =~ m/\S/o ) {
            $column =~ s/\W//go;
            push( @{$this->{fields}}, $column );
        }
    }
    return $this;
}

# PUBLIC
# Load a single data row into an Map object, assuming
# that the columns are ordered the same as in the table
# definition.
sub loadRow {
    my ( $this, $line, $rowmaker ) = @_;

    my $row = $rowmaker->new();
    my $field = 0;
    $line =~ s/^\s*\|(.*)\|\s*$/$1/o;
    foreach my $val ( split( /\|/, $line )) {
        $val =~ m/^\s*(.*)\s*$/o;
        $val = $1;;
        my $fld = $this->{fields}[$field++];
        last unless ( defined( $fld ));
        $row->set( $fld, $val );
    }
    return $row;
}

1;
