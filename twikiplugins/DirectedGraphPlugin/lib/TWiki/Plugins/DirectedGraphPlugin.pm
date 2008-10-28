# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2004-2005 Cole Beck, cole.beck@vanderbilt.edu
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
# Each plugin is a package that may contain these functions:        VERSION:
#
#   initPlugin              ( $topic, $web, $user, $installWeb )    1.000
#   commonTagsHandler       ( $text, $topic, $web )                 1.000
#
# =========================
#
# This plugin creates a png file by using the graphviz dot command.
# See http://www.graphviz.org/ for more information.
# Note that png files created with this plugin can only be deleted manually;
# it stays there even after the dot tags are removed.

package TWiki::Plugins::DirectedGraphPlugin;

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $pluginName
  $debug $exampleCfgVar $sandbox $isInitialized $antialiasDefault
  $densityDefault $sizeDefault $vectorformatsDefault $engineDefault
  $libraryDefault
);

use vars qw( %TWikiCompatibility );

# This should always be $Rev: 13028 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 13028 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

use strict;

$pluginName = 'DirectedGraphPlugin';
use Digest::MD5 qw( md5_hex );

#the MD5 and hash table are used to create a unique name for each graph
use File::Path;

my $HASH_CODE_LENGTH    = 32;
my %hashed_math_strings = ();

# path to dot, neato, twopi, circo and fdp (including trailing /)
my $enginePath = '/usr/bin/';

my $dotHelperPath = "/home/httpd/twiki/tools/DirectedGraphPlugin.pl";
my $execCmd       = "/usr/bin/perl %HELPERSCRIPT|F% %DOT|F% %WORKDIR|F% %INFILE|F% %FORMAT|S% %OUTFILE|F% %ERRFILE|F% ";

my $antialiasCmd = "/usr/bin/convert -density %DENSITY|N% -geometry %GEOMETRY|S% %INFILE|F% %OUTFILE|F%";

my $tmpFile = '/tmp/' . $pluginName . "$$";

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning("Version mismatch between $pluginName and Plugins.pm");
      return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag("\U$pluginName\E_DEBUG");

    # Get plugin antialias default
    $antialiasDefault = TWiki::Func::getPreferencesValue("\U$pluginName\E_ANTIALIAS");

    # Get plugin density default
    $densityDefault = TWiki::Func::getPreferencesValue("\U$pluginName\E_DENSITY");

    # Get plugin size default
    $sizeDefault = TWiki::Func::getPreferencesValue("\U$pluginName\E_SIZE");

    # Get plugin vectorformats default
    $vectorformatsDefault = TWiki::Func::getPreferencesValue("\U$pluginName\E_VECTORFORMATS");

    # Get plugin engine default
    $engineDefault = TWiki::Func::getPreferencesValue("\U$pluginName\E_ENGINE");

    # Get plugin library default
    $libraryDefault = TWiki::Func::getPreferencesValue("\U$pluginName\E_LIBRARY");

    # Plugin correctly initialized
    TWiki::Func::writeDebug("- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK")
      if $debug;
  return 1;
} ### sub initPlugin

sub doInit
{
  return if $isInitialized;

    unless ( defined &TWiki::Sandbox::new ) {
        eval "use TWiki::Contrib::DakarContrib;";
        $sandbox = new TWiki::Sandbox();
    } else {
        $sandbox = $TWiki::sharedSandbox;
    }

    &writeDebug("called doInit");

    # for getRegularExpression
    if ( $TWiki::Plugins::VERSION < 1.020 ) {
        eval 'use TWiki::Contrib::CairoContrib;';

        #writeDebug("reading in CairoContrib");
    }

    &writeDebug("doInit( ) is OK");
    $isInitialized = 1;

  return '';
} ### sub doInit

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug("- ${pluginName}::commonTagsHandler( $_[2].$_[1] )")
      if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    #pass everything within <dot> tags to handleDot function
    $_[0] =~ s/<DOT(.*?)>(.*?)<\/DOT>/&handleDot($2,$1)/giseo;
} ### sub commonTagsHandler

# =========================
sub handleDot
{
    my $errMsg = &doInit();
  return $errMsg if $errMsg;

    my $attr = $_[1] || "";
    my $desc = $_[0] || "";

    my $antialias = TWiki::Func::extractNameValuePair( "$attr", "antialias" )
      || $antialiasDefault;
    my $density = TWiki::Func::extractNameValuePair( "$attr", "density" )
      || $densityDefault;
    my $size = TWiki::Func::extractNameValuePair( "$attr", "size" )
      || $sizeDefault;
    my $vectorformats = TWiki::Func::extractNameValuePair( "$attr", "vectorformats" )
      || $vectorformatsDefault;
    my $engine = TWiki::Func::extractNameValuePair( "$attr", "engine" )
      || $engineDefault;
    my $library = TWiki::Func::extractNameValuePair( "$attr", "library" )
      || $libraryDefault;
    my $doMap = TWiki::Func::extractNameValuePair( "$attr", "map" ) || "";

    # clean up parms
    if ( $antialias =~ m/off/o ) {
        $antialias = 0;
    }

    unless ( $density =~ m/^\d+$/o ) {
      return
"<font color=\"red\"><nop>DirectedGraph Error: density parameter should be given as a number (was: $density)</font>";
    }
    unless ( $size =~ m/^\d+x\d+$/o ) {
      return
"<font color=\"red\"><nop>DirectedGraph Error: size parameter should be given in format: widthxheight (was: $size)</font>";
    }

    unless ( $engine =~ m/^(dot|neato|twopi|circo|fdp)$/o ) {
      return
"<font color=\"red\"><nop>DirectedGraph Error: engine parameter should be one of the following: dot, neato, twopi, circo or fdp (was: $engine)</font>";
    }

    $library =~ s/\./\//;
    my $workingDir = TWiki::Func::getPubDir() . "/$library";
    unless ( -e "$workingDir" ) {
      return
"<font color=\"red\"><nop>DirectedGraph Error: library parameter should point to topic with attachments to use: <nop>Web.TopicName (was: $library)</font>";
    }

    # compatibility: check for old map indicator format (map=1)
    if ( $attr =~ m/map=1/o ) {
        $doMap = 1;
    }

    &writeDebug(
"incoming: $desc, $attr , antialias = $antialias, density = $density, size = $size, vectorformats = $vectorformats, engine = $engine, library = $library, doMap = $doMap \n"
    );

    # Create topic directory "pub/$web/$topic" if needed
    my $dir = TWiki::Func::getPubDir() . "/$web/$topic";
    unless ( -e "$dir" ) {
        umask(002);
        mkpath( $dir, 0, 0755 )
          or return "<noc>DirectedGraph Error: *folder $dir could not be created*";
    }

    # compute the MD5 hash of this string
    my $hash_code =
      md5_hex( "DOT" . $desc . $antialias . $density . $size . $vectorformats . $engine . $library . $doMap );

    # store the string in a hash table, indexed by the MD5 hash
    $hashed_math_strings{"$hash_code"} = $_[0];

    # run the "dot" command to create a png file with the directed graph
    my $image    = "${dir}/graph${hash_code}.png";
    my $psImage  = "${dir}/graph${hash_code}.ps";
    my $svgImage = "${dir}/graph${hash_code}.svg";
    my $cmapx    = "${dir}/graph${hash_code}.map";

    # don't do anything if a png of this graph were already created
    if ( open TMP, "$image" ) {
        close TMP;
    }

    # else create the graph
    else {

        # output graph description into the file "foo.dot"
        open OUTFILE, ">$tmpFile"
          or return "<font color=\"red\"><nop>DirectedGraph Error: could not create file $tmpFile</font>";
        print OUTFILE $desc;
        close OUTFILE;

        unless ($antialias) {
            writeDebug("same procedure as EVERY year ..");
            my ( $output, $status ) = $sandbox->sysCommand(
                $execCmd,
                HELPERSCRIPT => $dotHelperPath,
                DOT          => $enginePath . $engine,
                WORKDIR      => $workingDir,
                INFILE       => $tmpFile,
                FORMAT       => 'png',
                OUTFILE      => $image,
                ERRFILE      => $tmpFile . ".err"
            );
            &writeDebug("dgp-png: output: $output \n status: $status");
            if ($status) {

                # errors existed so remove created files
                unlink $image            unless $debug;
                unlink $tmpFile          unless $debug;
              return showError( $status, $output, $hashed_math_strings{"$hash_code"}, $tmpFile.".err" );
            } ### if ($status)
            unlink $tmpFile . ".err" unless $debug;
        } ### unless ($antialias)

        # run the "dot" command to create a map file with
        # a clientside map for the directed graph
        if ($doMap) {
            writeDebug("writing mapfile");
            my ( $output, $status ) = $sandbox->sysCommand(
                $execCmd,
                HELPERSCRIPT => $dotHelperPath,
                DOT          => $enginePath . $engine,
                WORKDIR      => $workingDir,
                INFILE       => $tmpFile,
                FORMAT       => 'cmapx',
                OUTFILE      => $cmapx,
                ERRFILE      => $tmpFile . ".err"
            );
            &writeDebug("dgp-png: output: $output \n status: $status");
            if ($status) {

                # errors existed so remove created files
                unlink $cmapx            unless $debug;
                unlink $tmpFile          unless $debug;
              return showError( $status, $output, $hashed_math_strings{"$hash_code"}, $tmpFile.".err" );
            } ### if ($status)
            unlink $tmpFile . ".err" unless $debug;
        } ### if ($doMap)

        if ( $vectorformats =~ m/svg/o ) {
            writeDebug("creating svg version ..");
            my ( $output, $status ) = $sandbox->sysCommand(
                $execCmd,
                HELPERSCRIPT => $dotHelperPath,
                DOT          => $enginePath . $engine,
                WORKDIR      => $workingDir,
                INFILE       => $tmpFile,
                FORMAT       => 'svg',
                OUTFILE      => $svgImage,
                ERRFILE      => $tmpFile . ".err"
            );
            &writeDebug("dgp-png: output: $output \n status: $status");
            if ($status) {

                # errors existed so remove created files
                unlink $svgImage         unless $debug;
                unlink $tmpFile          unless $debug;
              return showError( $status, $output, $hashed_math_strings{"$hash_code"}, $tmpFile.".err" );
            } ### if ($status)
            unlink $tmpFile . ".err" unless $debug;
        } ### if ( $vectorformats =~...

        if ( $antialias || ( $vectorformats =~ m/ps/o ) ) {
            writeDebug("creating ps version ..");
            my ( $output, $status ) = $sandbox->sysCommand(
                $execCmd,
                HELPERSCRIPT => $dotHelperPath,
                DOT          => $enginePath . $engine,
                WORKDIR      => $workingDir,
                INFILE       => $tmpFile,
                FORMAT       => 'ps',
                OUTFILE      => $psImage,
                ERRFILE      => $tmpFile . ".err"
            );
            &writeDebug("dgp-png: output: $output \n status: $status");
            if ($status) {

                # errors existed so remove created files
                unlink $psImage          unless $debug;
                unlink $tmpFile          unless $debug;
              return showError( $status, $output, $hashed_math_strings{"$hash_code"}, $tmpFile.".err" );
            } ### if ($status)
            unlink $tmpFile . ".err" unless $debug;
        } ### if ( $antialias || ( $vectorformats...

        if ($antialias) {

            my ( $output, $status ) = $sandbox->sysCommand(
                $antialiasCmd,
                DENSITY  => $density,
                GEOMETRY => $size,
                INFILE   => $psImage,
                OUTFILE  => $image
            );
            &writeDebug("dgp-png: output: $output \n status: $status");
            if ($status) {

                # errors existed so remove created files
                unlink $image            unless $debug;
                unlink $psImage          unless $debug;
                unlink $tmpFile          unless $debug;
              return &showError( $status, $output, $hashed_math_strings{"$hash_code"} );
            } ### if ($status)
        } ### if ($antialias)

        # were done with the ps file for antialiasing, and if it's not
        # wanted - unlink it
        unless ( $vectorformats =~ m/ps/o ) {
            unlink $psImage unless $debug;
        }

        # Attach the created files to the topic, but hide them pr. default.
        TWiki::Func::saveAttachment(
            $web, $topic,
            "graph$hash_code.png",
            {
                comment => '<nop>DirectedGraphPlugin: DOT graph',
                hide    => 1
            }
        );

        if ($doMap) {
            TWiki::Func::saveAttachment(
                $web, $topic,
                "graph$hash_code.map",
                {
                    comment => '<nop>DirectedGraphPlugin: DOT graph',
                    hide    => 1
                }
            );
        } ### if ($doMap)

        if ( $vectorformats =~ m/svg/o ) {
            TWiki::Func::saveAttachment(
                $web, $topic,
                "graph$hash_code.svg",
                {
                    comment => '<nop>DirectedGraphPlugin: DOT graph',
                    hide    => 1
                }
            );
        } ### if ( $vectorformats =~...

        if ( $vectorformats =~ m/ps/o ) {
            TWiki::Func::saveAttachment(
                $web, $topic,
                "graph$hash_code.ps",
                {
                    comment => '<nop>DirectedGraphPlugin: DOT graph',
                    hide    => 1
                }
            );
        } ### if ( $vectorformats =~...

        # delete the temp file
        unlink $tmpFile unless $debug;
    } ### else [ if ( open TMP, "$image")

    if ($doMap) {

        # read and format map
        my $mapfile = TWiki::Func::readFile($cmapx);
        $mapfile =~ s/(<map\ id\=\")(.*?)(\"\ name\=\")(.*?)(\">)/$1$hash_code$3$hash_code$5/go;
        $mapfile =~ s/[\n\r]/ /go;

        # place map and "foo.png" at the source of the <dot> tag in $Web.$Topic
        my $loc = TWiki::Func::getPubUrlPath() . "/$web/$topic";
        my $src = TWiki::urlEncode("$loc/graph$hash_code.png");
      return "$mapfile<img usemap=\"#$hash_code\" src=\"$src\"/>";
    } else {

        # attach "foo.png" at the source of the <dot> tag in $Web.$Topic
        my $loc = TWiki::Func::getPubUrlPath() . "/$web/$topic";
        my $src = TWiki::urlEncode("$loc/graph$hash_code.png");
      return "<img src=\"$src\"/>";
    } ### else [ if ($doMap)
} ### sub handleDot

# =========================
sub showError
{
    my ( $status, $output, $text, $errFile ) = @_;

    # Check error file for detailed report from graphviz binary
    if (defined $errFile && $errFile && -s $errFile)
    {
        open (ERRFILE, $errFile);
        my @errLines = <ERRFILE>;
        $text = "*DirectedGraphPlugin error:* <verbatim>" . join("", @errLines) . "</verbatim>";
        unlink $errFile unless $debug;
    }

    my $line = 1;
    $text =~ s/\n/sprintf("\n%02d: ", $line++)/ges if ($text);
    $output .= "<pre>$text\n</pre>";
  return "<font color=\"red\"><nop>DirectedGraph Error ($status): $output</font>";
} ### sub showError

sub writeDebug
{
    &TWiki::Func::writeDebug( "$pluginName - " . $_[0] ) if $debug;
}

1;
