# Produce a TWiki table using a user specified SQL command.  Since we don't
# know what columns will be returned, we assume the user will define these
# using the 'columns' argument
package TWiki::Plugins::DatabasePlugin::DATABASE_SQL_TABLE;

sub handle {
    my ($dbinfo, $args) = @_;

    $dbinfo->connect();

    # Since we don't know what columns will be returned by the users SQL
    # statement, we just need to know what headers to put onto of each of
    # teh columns.
    my $tmp = TWiki::Func::extractNameValuePair( $args, "headers" );
    my @headers;
    if( defined $tmp && $tmp ne "" ) {
        @headers = split( /,\s*/, $tmp ) if( $tmp );
    } else {
        return "Required option 'headers' not found";
    }

    # Get the SQL command
    $tmp = TWiki::Func::extractNameValuePair( $args, "command" );
    my $command = $tmp if( defined $tmp && $tmp ne "" );

    my $cmd = "$command";
    my $sth = $dbinfo->{db}->prepare($cmd);
    $sth->execute;
    # Generate table header using the 'headers' values for column names
    my $line = "| ";
    for my $c (@headers) {
        $line .= "*$c* | ";
    }
    $line .= "\n";
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
