package Foswiki::Plugins::DatabasePlugin::DATABASE_SQL;

use Foswiki::Func;

sub handle {
    my ( $dbinfo, $args ) = @_;

    $dbinfo->connect();

    my $result = '';
    my $sql    = Foswiki::Func::extractNameValuePair( $args, "sql" );
    my $sth    = $dbinfo->{db}->prepare($sql);
    $sth->execute;
    my $format = Foswiki::Func::extractNameValuePair( $args, "format" );
    if ($format) {
        my $headers = Foswiki::Func::extractNameValuePair( $args, "header" );
        my $separator =
          Foswiki::Func::extractNameValuePair( $args, "separator" )
          || "\n";
        while ( my $res = $sth->fetchrow_hashref() ) {
            my $row = $format;

            # reverse sort so we handle longer keys first
            foreach my $k ( reverse sort keys %$res ) {
                $row =~ s/\$$k/$res->{$k}/g;
            }
            $result .= $row . $separator;
        }
        $result =~ s/\$n\(\)/\n/gos;
        $result =~ s/\$n([^A-Za-z]|$)/\n$1/gos;
        $result =~ s/\$nop(\(\))?//gos;
        $result =~ s/\$quot(\(\))?/\"/gos;
        $result =~ s/\$percnt(\(\))?/\%/gos;
        $result =~ s/\$dollar(\(\))?/\$/gos;
        $result = $headers . $separator . $result if $headers;
    }
    return $result;
}

1;
__END__
#
# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2007 TWiki Contributors.
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
