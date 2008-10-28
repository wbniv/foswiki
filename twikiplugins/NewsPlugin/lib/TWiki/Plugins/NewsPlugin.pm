# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
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
# NewsPlugin, Colas Nahaboo
#
# If a topic has the %NEWS% keyword in it, on saving, this plugin
# creates a new topic of name the current topic with Headlines attached
# (i.e. FrenchNewsHeadlines from FrenchNews)
# comprised of the first 5 bulleted items, taking only the first
# line of the item and saves them as html <li>s

# history:
# 1.5: 07 Feb 2005 added "pattern" parameter
# 1.4: 20 Feb 2003 trims ending punctuation: .,:;
# 1.3: 19 Feb 2003 warning corrected
# 1.2: 14 Feb 2003 parameters
# 1.1: 23 Jan 2003 first revision

# =========================
package TWiki::Plugins::NewsPlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $debug
        $exampleCfgVar $webName $topicName
    );

# This should always be $Rev: 9189 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 9189 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';


# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;
    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning( "Version mismatch between NewsPlugin and Plugins.pm" );
        return 0;
    }
    # Plugin correctly initialized
    &TWiki::Func::writeDebug( "- TWiki::Plugins::NewsPlugin::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub beforeSaveHandler
{
## my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead
   if ( $_[0] =~ /[%]NEWS([{]([^}]*)[}])?[%]/ ) {
    # we are saving a news topic, creates headlines topic
    my $buffer = "", $occurs = 0, $options = $2;
    # optional params
    # $headlinesfilename, $count, $prefix, $suffix, $presep, $postsep, $trim;
    my $args; my $arg;
    # process options
    if ($options) {
      $args = TWiki::Func::expandCommonVariables( $options, $_[1], $_[2]);
    }
    my $headlinesfilename = &TWiki::Func::extractNameValuePair( $args, "topic" );
    if ( !$headlinesfilename ) {
      $headlinesfilename = TWiki::Func::getDataDir()."/$_[2]/$_[1]Headlines.txt";
    } elsif ( $headlinesfilename =~ /([^.]+)[.]([^.]+)/ ) {
      $headlinesfilename = TWiki::Func::getDataDir()."/$2/$1.txt";
    } else {
      $headlinesfilename = TWiki::Func::getDataDir()."/$_[2]/$headlinesfilename.txt";
    }
    my $count = &TWiki::Func::extractNameValuePair( $args, "count" );
    $count = 5 unless $count;
    my $prefix = &TWiki::Func::extractNameValuePair( $args, "prefix" );
    $prefix = "" unless $prefix;
    my $suffix = &TWiki::Func::extractNameValuePair( $args, "suffix" );
    $suffix = "" unless $suffix;		
    my $presep = &TWiki::Func::extractNameValuePair( $args, "presep" );
    $presep = "\t* " unless $presep;
    my $postsep = &TWiki::Func::extractNameValuePair( $args, "postsep" );
    $postsep = "\n" unless $postsep;
    my $trim = &TWiki::Func::extractNameValuePair( $args, "trim" );
    $trim = "yes" unless $trim;
    my $pattern = &TWiki::Func::extractNameValuePair( $args, "pattern" );
    $pattern = '(\t|   )\*\s' unless $pattern;

    $buffer .= $prefix;
    # look for each bullet list 
    foreach( split( /\n/, $_[0] ) ) {
      next unless /^${pattern}/;
      my $headline = $';
      if ( $trim eq "yes" ) {
	$headline =~ s/[.,:;]+\r?$//;
      }
      $buffer .= "$presep$headline$postsep";
      $occurs = $occurs +1;
      if ( $occurs >= $count ) {
	last;
      }
    }
    $buffer .= $suffix;
    TWiki::Func::saveFile($headlinesfilename, $buffer);
  }
}

# =========================

1;
