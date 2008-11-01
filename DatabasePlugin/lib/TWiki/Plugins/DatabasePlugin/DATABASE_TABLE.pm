# Produce a TWiki table from the specified database
package TWiki::Plugins::DatabasePlugin::DATABASE_TABLE;

use TWiki::Func;

sub handle {
    my ($dbinfo, $args) = @_;
    my ($tmp, @columns, @headers);

    die "No table defined in $dbinfo->{description}"
      unless $dbinfo->{table};

    $dbinfo->connect();

    # Define the columns in the associated table
    $tmp = TWiki::Func::extractNameValuePair( $args, "columns" );
    if (! $tmp) {
        $tmp = "*";	# Default to '*' if columns not specified.
    }
    # Since columns might be '*', we need to get the column names that
    # will be returned by '*'.
    if ($tmp eq "*") {
        @columns = $dbinfo->get_column_names();
    } else {
        @columns = split( /,\s*/, $tmp );
    }

    # See if the column headers is defined.  If not, then use the column
    # names as the column headers
    $tmp = TWiki::Func::extractNameValuePair( $args, "headers" );
    if ($tmp) {
        @headers = split( /,\s*/, $tmp );
    } else {
        @headers = @columns;
    }

    # Generate table header using the table column names
    my $line = "| ";
    for my $c (@headers) {
        $line .= "*$c* | ";
    }
    $line .= "\n";
    my $col = join(", ", @columns);
    my $cmd = "SELECT $col FROM $dbinfo->{table}";
    my $sth = $dbinfo->{db}->prepare($cmd);
    $sth->execute;
    while (my @row = $sth->fetchrow_array()) {
        my $row = "| ";
        for my $c (@row) {
            $c = "" unless $c;	# prevent 'uninitialized value' warnings
            $row .= "$c | ";
        }
        $row =~ s/\r\n/<br>/g;
        $line .= "$row\n";
    }
    return $line;
}

1;
__END__
#
# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2002-2007 Tait Cyrus, tait.cyrus@usa.net
# and TWiki Contributors.
#
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
