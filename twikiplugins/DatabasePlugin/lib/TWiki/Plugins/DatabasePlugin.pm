# See the end of this file for copyright notices.

# See the plugin topic for details.
package TWiki::Plugins::DatabasePlugin;

use DBI;
use strict;
use vars qw( $VERSION $RELEASE $dbinfo $SHORTDESCRIPTION );
use TWiki::Plugins::DatabasePlugin::Connection;

$VERSION = '$Rev: 13178 $';
$RELEASE = 'Dakar';
$SHORTDESCRIPTION = 'Provide access to data in a SQL database';

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between DatabasePlugin and Plugins.pm" );
        return 0;
    }
    return 0 unless $TWiki::cfg{Plugins}{DatabasePlugin}{ConfigSource};

    if ($TWiki::cfg{Plugins}{DatabasePlugin}{ConfigSource} eq 'Local') {
        # All DB's defined in the config
        foreach my $info (@{$TWiki::cfg{Plugins}{DatabasePlugin}{Databases}}) {
            my $dbi = new TWiki::Plugins::DatabasePlugin::Connection($info);
            $dbinfo->{$dbi->{description}} = $dbi;
        }
    } else {
        # Everything else is assumed to be the same as 'remote' Go to the
        # default database (specified in DatabasePluginConfig.pm) to obtain
        # secure information.  This is done so increase security by
        # minimizing the availability of clear text database passwords.
        my $sid = "";
        if ($TWiki::cfg{Plugins}{DatabasePlugin}{ConfigSID}) {
            $sid = ";sid=$TWiki::cfg{Plugins}{DatabasePlugin}{ConfigSID}"
        }
        my $db = DBI->connect("DBI:$TWiki::cfg{Plugins}{DatabasePlugin}{ConfigDriver}:database=$TWiki::cfg{Plugins}{DatabasePlugin}{ConfigDB};host=$TWiki::cfg{Plugins}{DatabasePlugin}{ConfigHost}$sid", $TWiki::cfg{Plugins}{DatabasePlugin}{ConfigUsername}, $TWiki::cfg{Plugins}{DatabasePlugin}{ConfigPassword}, {PrintError=>1, RaiseError=>0});
        if (! $db ) {
            die "Can't open initialization database";
        }
        my $cmd = "SELECT description,driver,db_name,db_sid,table_name,ro_username,ro_password,hostname FROM $TWiki::cfg{Plugins}{DatabasePlugin}{ConfigTable}";
        my $sth = $dbinfo->{db}->prepare($cmd);
        $sth->execute;
        # Fill hashes with the database information.
        while (my $row = $sth->fetchrow_hashref()) {
            # Compatibility
            $row->{database} ||= $row->{db_name};
            $row->{table}    ||= $row->{table_name};
            $row->{sid}      ||= $row->{db_sid};
            $row->{username} ||= $row->{ro_username};
            $row->{password} ||= $row->{ro_password};
            my $dbi = new TWiki::Plugins::DatabasePlugin::Connection($row);
            $dbinfo->{$dbi->{description}} = $dbi;
        }
    }

    return 1;
}

# Dispatch to the relevant submodule
sub _dispatch {
    my $tag = shift;
    my $result = '';

    $tag = 'TWiki::Plugins::DatabasePlugin::'.$tag;

    my $desc = TWiki::Func::extractNameValuePair(
        $_[0], 'description') || '';
    my $db = $dbinfo->{$desc};

    eval {
        die "No such DB $desc" unless $db;
        eval "use $tag";
        die $@ if $@;
        $tag .= '::handle';
        no strict 'refs';
        $result = &$tag($db, @_);
        use strict 'refs';
    };
    if ($@) {
        $result = "<span class='twikiAlert'>$@</span>";
    }
    return $result;
}

sub commonTagsHandler {
    ### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    $_[0] =~ s/%(DATABASE_TABLE){(.*)}%/_dispatch($1, $2)/eog;
    $_[0] =~ s/%(DATABASE_SQL_TABLE){(.*)}%/_dispatch($1,$2)/eog;
    $_[0] =~ s/%(DATABASE_REPEAT){(.*?)}%(.*?)%DATABASE_REPEAT%/_dispatch($1, $2, $3)/seog;
    $_[0] =~ s/%(DATABASE_SQL_REPEAT){(.*?)}%(.*?)%DATABASE_SQL_REPEAT%/_dispatch($1, $2, $3)/seog;
    $_[0] =~ s/%(DATABASE_EDIT){(.*)}%/_dispatch($1, $2)/eog;
    $_[0] =~ s/%(DATABASE_SQL){(.*)}%/_dispatch($1, $2)/eog;
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
#
