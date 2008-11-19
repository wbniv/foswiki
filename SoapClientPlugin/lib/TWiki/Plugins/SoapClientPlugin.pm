# Plugin for Foswiki - The Free Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2003 Peter Thoeny, peter@thoeny.com
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
# =========================
#
# This is an empty TWiki plugin. Use it as a template
# for your own plugins; see %SYSTEMWEB%.Plugins for details.
#
# Each plugin is a package that may contain these functions:        VERSION:
#
#   initPlugin              ( $topic, $web, $user, $installWeb )    1.000
#   initializeUserHandler   ( $loginName, $url, $pathInfo )         1.010
#   registrationHandler     ( $web, $wikiName, $loginName )         1.010
#   commonTagsHandler       ( $text, $topic, $web )                 1.000
#   startRenderingHandler   ( $text, $web )                         1.000
#   outsidePREHandler       ( $text )                               1.000
#   insidePREHandler        ( $text )                               1.000
#   endRenderingHandler     ( $text )                               1.000
#   beforeEditHandler       ( $text, $topic, $web )                 1.010
#   afterEditHandler        ( $text, $topic, $web )                 1.010
#   beforeSaveHandler       ( $text, $topic, $web )                 1.010
#   writeHeaderHandler      ( $query )                              1.010  Use only in one Plugin
#   redirectCgiQueryHandler ( $query, $url )                        1.010  Use only in one Plugin
#   getSessionValueHandler  ( $key )                                1.010  Use only in one Plugin
#   setSessionValueHandler  ( $key, $value )                        1.010  Use only in one Plugin
#
# initPlugin is required, all other are optional. 
# For increased performance, all handlers except initPlugin are
# disabled. To enable a handler remove the leading DISABLE_ from
# the function name. Remove disabled handlers you do not need.
#
# NOTE: To interact with TWiki use the official TWiki functions 
# in the TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!


# =========================
package TWiki::Plugins::SoapClientPlugin;    # change the package name and $pluginName!!!

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $pluginName
        $debug $exampleCfgVar
    );

# This should always be $Rev: 11144 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 11144 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'SoapClientPlugin';  # Name of this Plugin

use SOAP::Lite;
#eval { require SOAP::Lite }
#return "<font color=red>SamplePlugin: error loading needed modules ($@)</font>" if $@;

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag( "\U$pluginName\E_DEBUG" );

    # Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
    $exampleCfgVar = &TWiki::Func::getPreferencesValue( "EMPTYPLUGIN_EXAMPLE" ) || "default";

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub doSoapRequest
{
    my $service= TWiki::Func::extractNameValuePair( $_[0], "service");
    my $call_with_params= TWiki::Func::extractNameValuePair( $_[0], "call");
    my $format= TWiki::Func::extractNameValuePair( $_[0], "format");
    my $text = "";

#       my $service = SOAP::Lite
#         -> service($service);
#         -> service('http://gforge.org/soap/SoapAPI.php?wsdl');
#       @results = @{$service->getPublicProjectNames()};

#$call="getPublicProjectNames";
#$service= "http://gforge.org/soap/SoapAPI.php";

    my $call = $call_with_params;
    $call =~ /(.*)[(](.*)[)]/ ;
    $call = $1;
    my $params = $2;

#    try {
        my $method = SOAP::Data->name($call)
                         ->attr({xmlns => $service});

        my @parameters = split( /,/, $params);
        my $res = SOAP::Lite
          -> service($service."?wsdl")
          -> proxy($service)
          -> call($method => @parameters);


        $text = $text."{$params}";
        foreach $result (@parameters) {
                $text = $text."($result);";
        }

        if (ref $res->result eq "SCALAR") {
            $text = $text. "scalar\n";
        } elsif (ref $res->result eq "ARRAY") {
            @results = @{$res->result};
            foreach $result (@results) {
                my $tmp = $format;
                $tmp =~ s/\$list_element/$result/geo;
                $text = $text.$tmp;
            }
        } elsif (ref $res->result eq "HASH") {
            # split up the format, finding all the $field() bits, and then use them in the HASH
            $text = $format;
            my $mmm = "v";
            $text =~ s/\$struct\(([^)]*)\)/getHash($res->result, $1)/ge;
        } else {
            $text = $test. "mmm".ref $res->result ."\n";
        }
#    } catch Error::Simple with {
#        #TODO: some sort of error response
#        my $e = shift;
#        $text = 'Error during SOAP operation: '.$e;
#    }

    $text =~ s/\$n/\n/g;

    return $text;
}

# =========================
sub getHash
{
        return $_[0]->{$_[1]};
}


# =========================
sub startRenderingHandler
{
### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    TWiki::Func::writeDebug( "- ${pluginName}::startRenderingHandler( $_[1] )" ) if $debug;

    # This handler is called by getRenderedVersion just before the line loop

    # do custom extension rule, like for example:
    # $_[0] =~ s/old/new/g;

    $_[0] =~ s/%SOAP{(.*?)}%/doSoapRequest($1)/geo;
}


# =========================

1;
