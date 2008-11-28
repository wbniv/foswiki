# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# (c) 2006 Motorola, thomas.weigert@motorola.com
# (c) 2006 TWiki:Main.ClausLanghans
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the TWiki root.

# TODO:
# 1. Move setup of %config into initPlugin

=pod

---+ package ExcelImportExportPlugin

This plugin supports the export and import of tables and topics between
TWiki and Excel.

It is based on the ExcelImportExportAddOn by Claus Langhans.

=cut

package TWiki::Plugins::ExcelImportExportPlugin;

use strict;
use TWiki;
use TWiki::Func;
use TWiki::Render;
use TWiki::Meta;

use vars qw( $VERSION $RELEASE $debug $pluginName );

$VERSION = '$Rev: 0$';

$RELEASE = 'Dakar';

$pluginName = 'ExcelImportExportPlugin';

=pod

---++ initPlugin($topic, $web, $user, $installWeb) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin is installed in

=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.1 ) {
        TWiki::Func::writeWarning(
            "This plugin works only for TWiki4 and later.");
        return 0;
    }

    TWiki::Func::registerTagHandler( 'EXCEL2TABLE', \&excel2table,
        'context-free' );
    TWiki::Func::registerTagHandler( 'TABLE2EXCEL', \&table2excel,
        'context-free' );
    TWiki::Func::registerTagHandler( 'UPLOADEXCEL2TABLE', \&uploadexcel2table,
        'context-free' );

    # Plugin correctly initialized

    return 1;
}

sub excel2table {
    eval 'use TWiki::Plugins::ExcelImportExportPlugin::Import';
    die $@ if $@;
    return TWiki::Plugins::ExcelImportExportPlugin::Import::excel2table(@_);
}

sub uploadexcel2table {
    my ( $session, $params, $topic, $webName ) = @_;

    # The template defining the table schema
    my $template = $params->{template} || '';

    # The topic at which we will put the table data
    my $uploadtopic = $params->{"_DEFAULT"} || $params->{topic} || $topic;

    return
"<form name=\"main\" enctype=\"multipart/form-data\" action=\"%SCRIPTURLPATH{\"uploadexcel\"}%/%WEB%/%TOPIC%\" method=\"post\"><input class=\"twikiInputField\" type=\"file\" name=\"filepath\" value=\"%FILEPATH%\" size=\"30\" /><input type=\"hidden\" value=\"$template\" name=\"template\" /><input type=\"hidden\" value=\"$uploadtopic\" name=\"uploadtopic\" /><input type=\"hidden\" name=\"filename\" value=\"%FILENAME%\" /> &nbsp; <input type=\"submit\" value=\"Upload excel\" /></form>";

}

sub table2excel {
    my ( $session, $params, $topic, $webName ) = @_;
    my $filename = $params->{file} || $topic;
    my $uploadtopic = $params->{"_DEFAULT"} || $params->{topic} || $topic;
    my $mapping     = $params->{map}        || '';
    my $template    = $params->{template}   || '';

## SMELL: Parameter "topic" seems to serve no function
    return
"<form action=\"%SCRIPTURLPATH{\"table2excel\"}%/%WEB%/%TOPIC%\"><input type=\"hidden\" value=\"$template\" name=\"template\" /><input type=\"hidden\" value=\"$uploadtopic\" name=\"uploadtopic\" /><input type=\"hidden\" value=\"$filename\" name=\"file\" /><input type=\"hidden\" value=\"$mapping\" name=\"map\" /><input type=\"submit\" value=\"Export table\" />
</form>";

}

1;
