# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2003 Richard Baar, richard.baar@centrum.cz
# Copyright (C) 2006 Kenneth Lavrsen, kenneth@lavrsen.dk
# Copyright (C) 2001-2006 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
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

=pod

---+ package RevisionLinkPlugin

RevisionLinkPlugin makes links to specified revisions and revisions
relative to current revision.

=cut

# =========================
package TWiki::Plugins::RevisionLinkPlugin;

# Always use strict to enforce variable scoping
use strict;

# $VERSION is referred to by TWiki, and is the only global variable that
# *must* exist in this package
use vars qw( $VERSION $RELEASE $debug $pluginName );
#$web $topic $user $installWeb

# This should always be $Rev: 12903 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '2.1 ($Rev: 12903 $)';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

# Name of this Plugin, only used in this module
$pluginName = 'RevisionLinkPlugin';


=pod

---++ initPlugin($topic, $web, $user, $installWeb) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin is installed in

REQUIRED

Called to initialise the plugin. If everything is OK, should return
a non-zero value. On non-fatal failure, should write a message
using TWiki::Func::writeWarning and return 0. In this case
%FAILEDPLUGINS% will indicate which plugins failed.

In the case of a catastrophic failure that will prevent the whole
installation from working safely, this handler may use 'die', which
will be trapped and reported in the browser.

You may also call =TWiki::Func::registerTagHandler= here to register
a function to handle variables that have standard TWiki syntax - for example,
=%MYTAG{"my param" myarg="My Arg"}%. You can also override internal
TWiki variable handling functions this way, though this practice is unsupported
and highly dangerous!

=cut

sub initPlugin
{
  my ( $topic, $web, $user, $installWeb ) = @_;

  # check for Plugins.pm versions
  if( $TWiki::Plugins::VERSION < 1 ) {
    &TWiki::Func::writeWarning( "Version mismatch between RevisionLinkPlugin and Plugins.pm" );
    return 0;
  }

  # Get plugin debug flag
  $debug = &TWiki::Func::getPreferencesFlag( "REVISIONLINKPLUGIN_DEBUG" );

  # Plugin correctly initialized
  &TWiki::Func::writeDebug( "- TWiki::Plugins::RevisionLinkPlugin::initPlugin( $web.$topic ) is OK" ) if $debug;
  return 1;
}

=pod

---++ commonTagsHandler($text, $topic, $web )
   * =$text= - text to be processed
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
This handler is called by the code that expands %TAGS% syntax in
the topic body and in form fields. It may be called many times while
a topic is being rendered.

Plugins that want to implement their own %TAGS% with non-trivial
additional syntax should implement this function. Internal TWiki
variables (and any variables declared using =TWiki::Func::registerTagHandler=)
are expanded _before_, and then again _after_, this function is called
to ensure all %TAGS% are expanded.

__NOTE:__ when this handler is called, &lt;verbatim> blocks have been
removed from the text (though all other HTML such as &lt;pre> blocks is
still present).

__NOTE:__ meta-data is _not_ embedded in the text passed to this
handler.

=cut

sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

  TWiki::Func::writeDebug( "- RevisionLinkPlugin::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

  # This is the place to define customized tags and variables
  # Called by sub handleCommonTags, after %INCLUDE:"..."%

  $_[0] =~ s/%REV[{\[](.*?)[}\]]%/&handleRevision($1, $_[1], $_[2])/geo;
}

sub handleRevision {
  my ( $text, $topic, $web ) = @_;

  my %params = extendedExtractParameters($text);

  #return "D:" . $params{'_DEFAULT'} . " R:" . $params{'rev'} . " T:" . $params{'topic'};

  my $tmpWeb = $params{'web'} || $web;
  my $rev = $params{'rev'} || '';
  my $format = $params{'format'} || '';
  my $emptyAttr = $params{'_DEFAULT'} || '';

  my $tmpTopic = $topic;

  if ( $emptyAttr ne '' ) {
    if ( $rev eq '' ) {
      $rev = $emptyAttr;
    }
    else {
      $tmpTopic = $emptyAttr;
    }
  }

  my $targetTopic = $params{'topic'} || $tmpTopic;

  if ( $rev < 0 ) {
    my $maxRev = (TWiki::Func::getRevisionInfo( $tmpWeb, $targetTopic ))[2];
    #If Cairo we need to strip 1.
    $maxRev =~ s/1\.(.*)/$1/;
    $rev = $maxRev + $rev;
    if ( $rev < 1 ) { $rev = 1; }
  }
  
  my ( $revDate, $revUser, $tmpRev, $revComment ) = TWiki::Func::getRevisionInfo( $tmpWeb, $targetTopic, $rev);
  #If Cairo and we stripped the "1." we put it back
  if ( $TWiki::Plugins::VERSION < 1.1 && index( $rev, "." ) < 0 ) {
    $rev = "1.$rev";
  }

  if ( $format eq "" ) {
    $format = "!$targetTopic($rev)!"
  }
  else {
    if ( $format =~ /!(.*?)!/ eq "" ) {
      $format = "!$format!";
    }
    $format =~ s/\$topic/$targetTopic/geo;
    $format =~ s/\$web/$tmpWeb/geo;
    $format =~ s/\$rev/$rev/geo;
    $format =~ s/\$date/$revDate/geo;
    $format =~ s/\$user/$revUser/geo;
    $format =~ s/\$comment/$revComment/geo;
  }

  $format =~ s/!(.*?)!/[[%SCRIPTURL%\/view\/$tmpWeb\/$targetTopic\?rev=$rev][$1]]/g;
  return $format;
}

=pod

---++ extendedExtractParameters($string) -> %parameters

Extract all parameters from a variable string and returns a hash of parameters

   * =$string= - Attribute string from a TWiki Variable.
   
return: =%parameters=  Hash containing all parameters. The nameless parameter is stored in key =_DEFAULT=

extendedExtractParameters is an extended version of TWiki::Func::extractParameters
which is capable of understanding both " and ' round strings and the default value at any
position. Dakar has the code in TWiki::Attrs::new but this will not work in Cairo and is not
part of published API. So the code below is actually a short version of Dakar's TWiki::Attrs::new
with $friendly true.

=cut

sub extendedExtractParameters {
    my ( $string ) = @_;
    my %parameters;

    return 0 unless defined( $string );
    
    #First we substitute " and ' escaped with \ with \ord-value
    $string =~ s/\\(["'])/"\0".sprintf("%.2u", ord($1))/ge;

    while ( $string =~ m/\S/s ) {
        # name="value" pairs
        if ( $string =~ s/^[\s,]*(\w+)\s*=\s*\"(.*?)\"//is ) {
            $parameters{$1} = $2; 
        }
        # simple double-quoted value with no name, sets the default
        elsif ( $string =~ s/^[\s,]*\"(.*?)\"//os ) {
            $parameters{'_DEFAULT'} = $1
              unless defined( $parameters{'_DEFAULT'} );
        }
        else {
            # name='value' pairs
            if ( $string =~ s/^[\s,]*(\w+)\s*=\s*'(.*?)'//is ) {
                $parameters{$1} = $2;
            }
            # simple single-quoted value with no name, sets the default
            elsif ( $string =~ s/^[\s,]*'(.*?)'//os ) {
                $parameters{'_DEFAULT'} = $1
                  unless defined( $parameters{'_DEFAULT'} );
            }
            # simple name with no value (boolean, or _DEFAULT)
            elsif ( $string =~ s/^[\s,]*([a-z]\w*)\b//s ) {
                my $key = $1;
                $parameters{$key} = 1;
            }
            # otherwise the whole string - without padding - is the default
            else {
                if( $string =~ m/^\s*(.*?)\s*$/s &&
                      !defined($parameters{'_DEFAULT'})) {
                    $parameters{'_DEFAULT'} = $1;
                }
                last;
            }
        }
    }

    # Put back the escaped ' and "
    foreach my $key ( keys %parameters ) {
        $parameters{$key} =~ s/\0(\d\d)/chr($1)/ge;  # escapes
    }
    
    return %parameters;
}

1;
