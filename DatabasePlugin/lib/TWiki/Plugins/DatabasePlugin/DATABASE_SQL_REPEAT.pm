# Produce a TWiki table from the specified database using the user
# specified SQL and the user specified formatting.  Columns names are
# specified using %name% where 'name' is any column name.
package TWiki::Plugins::DatabasePlugin::DATABASE_SQL_REPEAT;

sub handle {
    my ($dbinfo, $args, $repeat_info) = @_;
    my ($tmp, @columns);

    $dbinfo->connect();

    # Get the SQL command
    $tmp = TWiki::Func::extractNameValuePair( $args, "command" );
    my $command = $tmp if( defined $tmp && $tmp ne "" );

    # Define the columns in the associated table
    $tmp = TWiki::Func::extractNameValuePair( $args, "columns" );
    if (! $tmp) {
        # If not defined, then get the list of columns the table actually
        # has.  We need to know this since all the user has specified is an
        # SQL command and we don't know what columns might exist.
        # NOTE: This assumes that the table columns are actually what is being
        # returned and not some other SQL type information that really doesn't
        # have anything to do with the specified table (db stats for example)
        @columns = $dbinfo->get_column_names();
    } else {
        @columns = split( /,\s*/, $tmp );
    }

    my $cmd = $command;
    my $sth = $dbinfo->{db}->prepare("$cmd");
    $sth->execute;

    my $line = '';
    while (my @row = $sth->fetchrow_array()) {
        # Now for each row in the database, we attempt to perform any
        # column substitution that is found in the $repeat_info
        my $repeat_info_copy = $repeat_info;
        my $index = 0;
        foreach my $fix (@row) {
            # Fix the info from the DB replacing newlines with <BR>
            $fix =~ s/\r\n/<BR \/>/g;
            $repeat_info_copy =~ s/%$columns[$index++]%/$fix/g;
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
