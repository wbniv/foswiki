# Produce a TWiki table from the specified database using the user
# specified formatting.  Columns names are specified using %name% where
# 'name' is any column name.
package TWiki::Plugins::DatabasePlugin::DATABASE_REPEAT;

sub handle {
    my ($dbinfo, $args, $repeat_info) = @_;
    my ($tmp, @columns);

    die "No table defined in $dbinfo->{description}"
      unless $dbinfo->{table};

    $dbinfo->connect($args);

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

    my $col = join(", ", @columns);
    my $cmd = "SELECT $col FROM $dbinfo->{table}";
    my $sth = $dbinfo->{db}->prepare($cmd);
    $sth->execute;
    my $line;
    while (my @row = $sth->fetchrow_array()) {
        # Now for each row in the database, we attempt to perform any
        # column substitution that is found in the $repeat_info
        my $repeat_info_copy = $repeat_info;
        for my $index (0..$#row) {
            # Fix the info from the DB replacing newlines with <BR>
            my $fix = $row[$index] || '';
            $fix =~ s/\r\n/<BR>/g;
            $repeat_info_copy =~ s/%$columns[$index]%/$fix/g;
        }
        $line .= $repeat_info_copy;
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
