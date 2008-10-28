package TWiki::Plugins::DatabasePlugin::DATABASE_EDIT;

sub handle {
    my ($dbinfo, $args) = @_;

    my $description =
      TWiki::Func::extractNameValuePair( $args, "description" );

    my $db_driver = $dbinfo->{driver};
    my $database  = $dbinfo->{database};
    my $user		= $dbinfo->{username};
    my $password	= $dbinfo->{password};
    my $table		= $dbinfo->{table};
    my $hostname	= $dbinfo->{hostname};

    # If the user is concerned about security, make sure that a request to
    # display the main DatabasePlugin is not allowed.
    # Get plugin security flag
    my $security_on =
      TWiki::Func::getPreferencesFlag( "DATABASEPLUGIN_SECURITY" );
    if ($security_on &&
          ($DatabasePluginConfig::db_driver eq $db_driver) &&
            ($DatabasePluginConfig::db_database eq $database) &&
              ($DatabasePluginConfig::db_table eq $table)) {
        # Get plugin security flag
        return TWiki::Func::getPreferencesValue( "DATABASEPLUGIN_SECURITY_MESSAGE" );
    }

    # Define the display text
    my $display_text = TWiki::Func::extractNameValuePair( $args, "display_text" );
    if (! $display_text) {
        $display_text = "edit";
    }

    return "<a onClick=\"nw=window.open('%SCRIPTURL{DatabasePluginEdit}%?database=$database&table=$table','edit','scrollbars,resizable,location');nw.focus(); return false;\" href='#'>$display_text</a>";
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
