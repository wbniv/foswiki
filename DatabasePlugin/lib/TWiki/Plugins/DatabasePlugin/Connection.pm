# package that represents a database connection
package TWiki::Plugins::DatabasePlugin::Connection;

sub new {
    my ($class, $info) = @_;

    my $this = bless({}, $class);

    foreach my $field qw(description driver hostname database sid table
                         username password) {
        $this->{$field} = $info->{$field};
    }

    $this->{db} = undef;
    return $this;
}

sub DESTROY {
    my $this = shift;

    $this->{db}->disconnect() if $this->{db};
    $this->{db} = undef;
}

sub connect {
    my $this = shift;

    unless ($this->{db}) {
        my $sid = $this->{sid} ? ";sid=$this->{sid}" : '';

        my $db = DBI->connect(
            "DBI:$this->{driver}:database=$this->{database};host=$this->{hostname}$sid",
            $this->{username}, $this->{password},
            {PrintError=>1, RaiseError=>1});
        if (! $db ) {
            die "Can't open database specified by description '$description'";
        }

        $this->{db} = $db;
    }
}

# Go out to the specified database table and return the columns available
# in that table.
sub get_column_names {
    my $this = shift;

    my $cmd;
    if ($this->{driver} eq 'Oracle') {
        $cmd = "SELECT COLUMN_NAME FROM all_tab_columns WHERE TABLE_NAME = '$this->{table}'";
    } else {
        $cmd = "DESCRIBE $this->{table}";
    }
    my $sth = $this->{db}->prepare($cmd);
    $sth->execute;
    my @columns;
    while (my @row = $sth->fetchrow_array()) {
        push (@columns, $row[0]);
    }
    return @columns;
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
