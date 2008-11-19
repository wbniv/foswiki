# Plugin for Foswiki - The Free Open Source Wiki, http://foswiki.org/
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
use strict;

use vars qw(
  $web $usWeb $topic $user $installWeb $VERSION $RELEASE $pluginName
  $debugDefault $antialiasDefault $densityDefault $sizeDefault 
  $vectorFormatsDefault $hideAttachDefault $inlineAttachDefault $linkFilesDefault
  $engineDefault $libraryDefault $deleteAttachDefault $forceAttachAPI $forceAttachAPIDefault
  $enginePath $magickPath $toolsPath $attachPath $attachUrlPath $perlCmd $engineCmd $dotHelper
  $HASH_CODE_LENGTH 
  $antialiasCmd  
);

use Digest::MD5 qw( md5_hex );
use Storable qw(store retrieve freeze thaw);

use File::Path;
use File::Temp;
use File::Spec;
use File::Copy;   # Used for TWiki attach API bypass

#use vars qw( %TWikiCompatibility );

# This should always be $Rev: 17659 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 17659 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';


$pluginName = 'DirectedGraphPlugin'; 

$HASH_CODE_LENGTH    = 32;

#
# Documentation on the sandbox command options taken from TWiki/Sandbox.pm
#
# '%VAR%' can optionally take the form '%VAR|FLAG%', where FLAG is a
# single character flag.  Permitted flags are
#   * U untaint without further checks -- dangerous,
#   * F normalize as file name,
#   * N generalized number,
#   * S simple, short string,
#   * D rcs format date


$dotHelper = "DirectedGraphPlugin.pl";
$engineCmd = " %HELPERSCRIPT|F% %DOT|F% %WORKDIR|F% %INFILE|F% %IOSTRING|U% %ERRFILE|F% %DEBUGFILE|F%";
$antialiasCmd = "convert -density %DENSITY|N% -geometry %GEOMETRY|S% %INFILE|F% %OUTFILE|F%";

# The session variables are used to store the file names and md5hash of the input to the dot command
#   xxxHashArray{SET} - Set to 1 if the array has been initialized
#   xxxHashArray{GRNUM} - Counts the unnamed graphs for the page 
#   xxxHashArray{FORMATS}{<filename>} - contains the list of output file types for the input file
#   xxxHashArray{MD5HASH}{<filename>} - contains the hash of the input used to create the files


# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    &_writeDebug(" >>> initPlugin Entered");

    my $doInit;
    
    if ((defined $doInit) && $doInit ) { return 1; }
    $doInit = 1;

    $usWeb = $web;
    $usWeb =~ s/\//_/g;    #Convert any subweb separators to underscore

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning("Version mismatch between $pluginName and Plugins.pm");
      return 0;
    }

    if ( defined $TWiki::cfg{DataDir} ) {
        # TWiki-4 or more recent
        # path to dot, neato, twopi, circo and fdp (including trailing /)
        $enginePath = $TWiki::cfg{DirectedGraphPlugin}{enginePath};
        # path to imagemagick convert routine
        $magickPath = $TWiki::cfg{DirectedGraphPlugin}{magickPath};
        # path to imagemagick convert routine
        $toolsPath = $TWiki::cfg{DirectedGraphPlugin}{toolsPath};
        # path to store attachments - optional.  If not provided, TWiki attachment API is used
        $attachPath = $TWiki::cfg{DirectedGraphPlugin}{attachPath};
        # URL to retrieve attachments - optional.  If not provided, TWiki pub path is used.
        $attachUrlPath = $TWiki::cfg{DirectedGraphPlugin}{attachUrlPath};
        # path to imagemagick convert routine
        $perlCmd = $TWiki::cfg{DirectedGraphPlugin}{perlCmd};
    } else {
        # Cairo or earlier  MANUALLY EDIT THESE PATHS AS REQUIRED
        $enginePath = '/usr/bin/';
        $magickPath = '/usr/bin/';
        $toolsPath = '/path/to/twiki/tools/';
        $perlCmd = '/usr/bin/perl';
       }
       
    die "Path to GraphViz commands not defined. Use bin/configure or edit DirectedGraphPlugin.pm " unless $enginePath;

    # for getRegularExpression
    if ( $TWiki::Plugins::VERSION < 1.020 ) {
        eval 'use TWiki::Contrib::CairoContrib;';
    }

    # Get plugin debug flag
    $debugDefault = TWiki::Func::getPreferencesFlag("\U$pluginName\E_DEBUG");

    # Get plugin antialias default
    $antialiasDefault = TWiki::Func::getPreferencesValue("\U$pluginName\E_ANTIALIAS");

    # Get plugin density default
    $densityDefault = TWiki::Func::getPreferencesValue("\U$pluginName\E_DENSITY");

    # Get plugin size default
    $sizeDefault = TWiki::Func::getPreferencesValue("\U$pluginName\E_SIZE");

    # Get plugin vectorFormats default
    $vectorFormatsDefault = TWiki::Func::getPreferencesValue("\U$pluginName\E_VECTORFORMATS");

    # Get plugin engine default
    $engineDefault = TWiki::Func::getPreferencesValue("\U$pluginName\E_ENGINE");

    # Get plugin library default
    $libraryDefault = TWiki::Func::getPreferencesValue("\U$pluginName\E_LIBRARY");

    # Get plugin hideattachments default
    $hideAttachDefault = TWiki::Func::getPreferencesValue("\U$pluginName\E_HIDEATTACHMENTS");

    # Get the default inline  attachment default
    $inlineAttachDefault = TWiki::Func::getPreferencesValue("\U$pluginName\E_INLINEATTACHMENT");

    # Get the default link file attachment default
    $linkFilesDefault = TWiki::Func::getPreferencesValue("\U$pluginName\E_LINKATTACHMENTS");

    # Get plugin deleteattachments default
    $deleteAttachDefault = TWiki::Func::getPreferencesValue("\U$pluginName\E_DELETEATTACHMENTS");

    # Get plugin deleteattachments default
    $forceAttachAPIDefault = TWiki::Func::getPreferencesValue("\U$pluginName\E_FORCEATTACHAPI");

    # Read in the attachment information from previous runs
    #  and save it into a session variable for use by the tag handlers
    # Also clear the new attachment table that will be built from this run

    my %oldHashArray = _loadHashCodes();  # Load the -filehash file into the old hash               
    TWiki::Func::setSessionValue( 'DGP_hash', freeze \%oldHashArray);
    TWiki::Func::clearSessionValue( 'DGP_newhash');  # blank slate for new attachments
    
    # Plugin correctly initialized
    &_writeDebug("- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) initialized OK") ;

  return 1;
} ### sub initPlugin


# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead
#
    if ( ($_[1] ne $topic) || ($_[2] ne $web)) {
        &_writeDebug(" SKIPPING commonTagsHandler  web = |$web|  topic = |$topic|  $_[2] $_[1] ");
        return;
        }
    &_writeDebug("- ${pluginName}::commonTagsHandler( $_[2].$_[1] )");

    #pass everything within <dot> tags to handleDot function
    # - Returns true if any matches were found.
    
    ($_[0] =~ s/<DOT(.*?)>(.*?)<\/DOT>/&_handleDot($2,$1)/giseo) 
    
    &_writeDebug(" <<< EXIT  commonTagsHandler  ");

} ### sub commonTagsHandler

# =========================
sub _handleDot
{
    &_writeDebug(" >>> _handleDot Entered ");

    # Retrieve new attachments hash from the session variable from previous passes
    my %newHashArray = ();
    my $newHashRef =  thaw(TWiki::Func::getSessionValue('DGP_newhash'));
    if ($newHashRef) {
        %newHashArray = %{ $newHashRef };
    } else {
        &_writeDebug(" _handleDot is initializing the newHashArray");
        $newHashArray{SET} = 1;  # Tell afterCommonTagsHandler that commonTagsHandler has run.
        $newHashArray{GRNUM} = 0;  # Initialize graph count
    }

    my %oldHashArray = ();
    my $oldHashRef =  thaw(TWiki::Func::getSessionValue('DGP_hash'));
    if ($oldHashRef) {
        %oldHashArray = %{ $oldHashRef };
    } 

    my $tempdir = "";

    if ( defined $TWiki::cfg{TempfileDir} ) {
        $tempdir = $TWiki::cfg{TempfileDir};
    } else {
        $tempdir = File::Spec->tmpdir();
    }

    my $attr = $_[1] || "";  # Attributes from the <dot ...> tag
    my $desc = $_[0] || "";  # GraphViz input between the <dot> ... </dot> tags

    my $grNum = $newHashArray{GRNUM};

    my %params = TWiki::Func::extractParameters($attr);  #extract all parms into a hash array

    # parameters with defaults set in the DirectedGraphPlugin topic.
    my $antialias = $params{antialias} || $antialiasDefault;;
    my $density = $params{density} || $densityDefault;
    my $size = $params{size} || $sizeDefault;
    my $vectorFormats = $params{vectorformats} || $vectorFormatsDefault;
    my $engine = $params{engine} || $engineDefault;
    my $library = $params{library} || $libraryDefault;
    my $hideAttach = $params{hideattachments} || $hideAttachDefault ;
    my $inlineAttach = $params{inline} || $inlineAttachDefault ;
       $forceAttachAPI = $params{forceattachapi} || $forceAttachAPIDefault ;
    my $linkFiles = $params{linkfiles} || $linkFilesDefault ;

    # parameters with hardcoded defaults
    my $outFilename = $params{file} || "";
    my $doMap = $params{map} || "";
    my $dotHash = $params{dothash} || "on";

    # Global parameters only specified in the DirectedGraphPlugin topic.
    # $debugDefault          
    # $deleteAttachDefault

    # Strip all trailing white space on any parameters set by set statements - WYSIWYG seems to pad it.
    $antialias =~ s/\s+$//;
    $density =~ s/\s+$//;
    $size =~ s/\s+$//;
    $vectorFormats =~ s/\s+$//;
    $engine  =~ s/\s+$//;
    $library =~ s/\s+$//;
    $hideAttach =~ s/\s+$//;
    $inlineAttach =~ s/\s+$//;
    $deleteAttachDefault =~ s/\s+$//;
    $forceAttachAPI =~ s/\s+$//;
    
    # Make sure outFilename is clean 
    $outFilename = TWiki::Sandbox::sanitizeAttachmentName($outFilename) if ($outFilename ne "");

    # clean up parms
    if ( $antialias =~ m/off/o ) {
        $antialias = 0;
    }

    #
    ###  Validate all of the <dot ...> input parameters
    #

    unless ( $density =~ m/^\d+$/o ) {
      return "<font color=\"red\"><nop>DirectedGraph Error: density parameter should be given as a number (was: $density)</font>";
    }

    unless ( $size =~ m/^\d+x\d+$/o ) {
      return "<font color=\"red\"><nop>DirectedGraph Error: size parameter should be given in format: widthxheight (was: $size)</font>";
    }

    unless ( $engine =~ m/^(dot|neato|twopi|circo|fdp)$/o ) {
      return "<font color=\"red\"><nop>DirectedGraph Error: engine parameter must be one of the following: dot, neato, twopi, circo or fdp (was: $engine)</font>";
    }

    unless ( $dotHash =~ m/^(on|off)$/o ) {
      return "<font color=\"red\"><nop>DirectedGraph Error: dothash must be either \"off\" or \"on\" (was: $dotHash)</font>";
    }

    unless ( $hideAttach =~ m/^(on|off)$/o ) {
      return "<font color=\"red\"><nop>DirectedGraph Error: hideattachments  must be either \"off\" or \"on\" (was: $hideAttach)</font>";
    }

    unless ( $linkFiles =~ m/^(on|off)$/o ) {
      return "<font color=\"red\"><nop>DirectedGraph Error: links  must be either \"off\" or \"on\" (was: $linkFiles)</font>";
    }

    unless ( $inlineAttach =~ m/^(png|jpg)$/o ) {
      return "<font color=\"red\"><nop>DirectedGraph Error: inline  must be either \"jpg\" or \"png\" (was: $inlineAttach)</font>";
    }

    unless ( $deleteAttachDefault =~ m/^(on|off)$/o ) {
      return "<font color=\"red\"><nop>DirectedGraph Error in defaults: DELETEATTACHMENTS  must be either \"off\" or \"on\" (was: $deleteAttachDefault)</font>";
    }

    unless ( $forceAttachAPI =~ m/^(on|off)$/o ) {
      return "<font color=\"red\"><nop>DirectedGraph Error in defaults: FORCEATTACHAPI  must be either \"off\" or \"on\" (was: $forceAttachAPI)</font>";
    }

    my $hide = undef;   
    if ( $hideAttach =~ m/off/o ) {
        $hide = 0;
    } else {
        $hide = 1;
    }

    my $chkHash = undef;   
    if ( $dotHash =~ m/off/o ) {
        $chkHash = 0;
    } else {
        $chkHash = 1;
    }	

    # SMELL:  This is not safe for the Store rewrite.  
    # Need to copy library attachments to a temporary directory for access by graphViz!

    $library =~ s/\./\//;
    my $workingDir = TWiki::Func::getPubDir() . "/$library";
    unless ( -e "$workingDir" ) {
      return
"<font color=\"red\"><nop>DirectedGraph Error: library parameter should point to topic with attachments to use: <br /> <nop>Web.TopicName (was: $library)  <br /> pub dir is $workingDir </font>";
    }

    # compatibility: check for old map indicator format (map=1 without quotes)
    if ( $attr =~ m/map=1/o ) {
        $doMap = 1;
    }

    &_writeDebug(
"incoming: $desc, $attr , antialias = $antialias, density = $density, size = $size, vectorformats = $vectorFormats, engine = $engine, library = $library, doMap = $doMap, hash = $dotHash \n"
    );

    foreach my $prm (keys(%params)) {
            &_writeDebug( "PARAMETER $prm value is $params{$prm}");
   }

    # compute the MD5 hash of this string.  This used to detect
    # if any parameters or input change from run to run
    # Attachments recreated if the hash changes

    # Hash is calculated against the <dot> command parameters and input, 
    # along with any parameters that are set in the Default topic which would modify the results.
    # Parameters that are only set as part of the <dot> command do not need to be explicitly coded, 
    # as they are include in $attr.

    my $hashCode =
      md5_hex( "DOT" . $desc . $attr . $antialias . $density . $size . $vectorFormats . $engine . $library . $hideAttach . $inlineAttach );

    # If a filename is not provided, set it to a name, with incrementing number.
    if ($outFilename eq "") {   #no filename?  Create a new name
       $grNum++;          # increment graph number.  
       $outFilename = "DirectedGraphPlugin_"."$grNum";
    }
    
    # Make sure vectorFormats includes all required file types
    $vectorFormats =~ s/,/ /g ;  #Replace any comma's in the list with spaces.  
    $vectorFormats .= " ".$inlineAttach if !($vectorFormats =~ m/$inlineAttach/);  # whatever specified inline is mandatory
    $vectorFormats .= " ps" if (($antialias) && !($vectorFormats =~ m/ps/));       # postscript for antialias or as requested
    $vectorFormats .= " cmapx" if (($doMap) && !($vectorFormats =~ m/cmapx/));     # client side map
    $vectorFormats =~ s/none//g ;         # remove the "none" if set by default

    my %attachFile;  # Hash to store attachment file names - key is the file type.

    my $oldHashCode = $oldHashArray{MD5HASH}{$outFilename} || " ";  # retrieve hash code for filename

    $newHashArray{MD5HASH}{$outFilename} = $hashCode;         # hash indexed by filename
    $newHashArray{FORMATS}{$outFilename} = $vectorFormats; # output formats for eventual cleanup 

    &_writeDebug("$outFilename: oldhash = $oldHashCode  newhash = $hashCode");

    #  If the hash codes don't match, the graph needs to be recreated
    #  otherwise just use the previous graph already attached.
    #  Also check if the inline attachment is missing and recreate if needed
    #
    foreach my $key (split(" ",$vectorFormats) ) {
       if ( $key ne "none" ) {   # skip the bogus default
           $attachFile{$key} = "$outFilename.$key";
       } ### if ($key ne "none"
    } ### foreach my $key
    #
    #

    
    if ( (($oldHashCode ne $hashCode) && $chkHash ) | 
         not _attachmentExists( $web, $topic, "$outFilename.$inlineAttach" )) {

        &_writeDebug(" >>> Processing changed dot tag or missing file $outFilename.$inlineAttach <<< ");

        my $sandbox = undef;
        $sandbox = $TWiki::sharedSandbox # 4.0 - 4.1.2
            || $TWiki::sandbox; # 4.2

        my $outString = "";
        my %tempFile;

        foreach my $key (keys(%attachFile)) {
            if (!exists ($tempFile{$key})) {
                $tempFile{$key} = new File::Temp(TEMPLATE => 'DGPXXXXXXXXXX',
                         DIR => $tempdir,
	                 UNLINK => 0, #  Manually unlink later if debug not specified.
                         SUFFIX => ".$key" );
                # Don't create the GraphViz inline output if antialias is requested			 
                $outString .= "-T$key -o$tempFile{$key} " unless ($antialias && $key eq "$inlineAttach");
            } ### if (!exists ($tempFile   
        } ### foreach my $key

        # Create a new temporary file to pass to GraphViz
        my $dotFile = new File::Temp(TEMPLATE => 'DiGraphPluginXXXXXXXXXX',
                         DIR => $tempdir,
                         UNLINK => 0, # Manually unlink later if debug not specified
                         SUFFIX => '.dot');
        TWiki::Func::saveFile( "$dotFile", $desc);

        my $debugFile = "";
        if ($debugDefault) {
            $debugFile = new File::Temp(TEMPLATE => 'DiGraphPluginRunXXXXXXXXXX',
                         DIR => $tempdir,
                         UNLINK => 0, # Manually unlink later if debug not specified
                         SUFFIX => '.log');
        }                 

        #  Execute dot - generating all output into the TWiki temp directory
        my ( $output, $status ) = $sandbox->sysCommand(
                $perlCmd . $engineCmd,
                HELPERSCRIPT => $toolsPath . $dotHelper,
                DOT          => $enginePath . $engine,
                WORKDIR      => $workingDir,
                INFILE       => "$dotFile",
                IOSTRING      => $outString,
                ERRFILE      => "$dotFile" . ".err",
                DEBUGFILE    => "$debugFile"
            );
	
	if ($status) {
             $dotFile =~ tr!\\!/!;      
	     unlink $dotFile          unless $debugDefault;
              return _showError( $status, $output, "Processing $toolsPath$dotHelper - $enginePath$engine: <br />".$desc, $dotFile.".err" );
	     } ### if ($status)
        $dotFile =~ tr!\\!/!;
	unlink "$dotFile.err" unless $debugDefault;     
        unlink $dotFile unless $debugDefault;

	### SMELL: Possible improvement - let the engine create the PNG file and
	### then set the size & density below to match so the image map
	### matches correctly.

        if ($antialias) {  # Convert the postscript image to the inline format
            my ( $output, $status ) = $sandbox->sysCommand(
                $magickPath . $antialiasCmd,
                DENSITY  => $density,
                GEOMETRY => $size,
                INFILE   => "$tempFile{'ps'}",
                OUTFILE  => "$tempFile{$inlineAttach}"
            );
            &_writeDebug("dgp-antialias: output: $output \n status: $status");
            if ($status) {
              return &_showError( $status, $output, "Processing $magickPath.$antialiasCmd <br />". $desc );
            } ### if ($status)
        } ### if ($antialias)

        ### Attach all of the files to the topic.  If a hard path is specified,
        ### then use perl file I/O, otherwise use TWiki API.
	&_writeDebug( "### forceAttachAPI = |$forceAttachAPI|  attachPath = |$attachPath| ");
        #
        foreach my $key (keys(%attachFile)) {
            if (($attachPath) && !($forceAttachAPI eq "on")) {
               &_writeDebug("attaching $attachFile{$key} using direct file I/O  ");
               _make_path($topic, $web);
               umask( 002 );
               copy( "$tempFile{$key}", "$attachPath/$web/$topic/$attachFile{$key}");
            } else {
                my @stats = stat $tempFile{$key};
                my $fileSize = $stats[7];
                my $fileDate = $stats[9];
                TWiki::Func::saveAttachment(
                    $web, $topic,
                    "$attachFile{$key}",
                    {
		        file => "$tempFile{$key}",
		        filedate => $fileDate,
	                filesize => $fileSize,
                        comment => '<nop>DirectedGraphPlugin: DOT graph',
                        hide    => $hide
                    }
                );
            } # else if ($attachPath)
            $tempFile{$key} =~ tr!\\!/!;
            unlink $tempFile{$key} unless $debugDefault ;
        } ### foreach my $key (keys....

    } ### else [ if ($oldHashCode ne $hashCode) |

    $newHashArray{GRNUM} = $grNum;
    TWiki::Func::setSessionValue( 'DGP_newhash', freeze \%newHashArray);

    #  Build the path to use for attachment URL's
    #  $attachUrlPath is used only if attachments are stored in an explicit path
    #  and $attachUrlPath is provided,  and use of the API is not forced.

    my $urlPath = undef;
    if (($attachPath) && ($attachUrlPath) && !($forceAttachAPI eq "on")) {
        $urlPath = $attachUrlPath;
        } else {
        $urlPath = TWiki::Func::getPubUrlPath(); 
        }

    #  Build a manual link for each specified file type except for
    #  The "inline" file format, and any image map file
    
    my $fileLinks = "";
    if ($linkFiles) {
       $fileLinks = "<br />";
       foreach my $key (keys(%attachFile)) {
           if (($key ne $inlineAttach) && ($key ne "cmapx")) {
              $fileLinks .= "<a href=" . $urlPath . TWiki::urlEncode("/$web/$topic/$attachFile{$key}") . ">[$key]</a> ";
              } # if (($key ne
           } # foreach my $key
        } # if ($linkFiles

    if ($doMap) {
        # read and format map
        my $mapfile = TWiki::Func::readAttachment($web, $topic, "$outFilename.cmapx");
        $mapfile =~ s/(<map\ id\=\")(.*?)(\"\ name\=\")(.*?)(\">)/$1$hashCode$3$hashCode$5/go;
        $mapfile =~ s/[\n\r]/ /go;

        # place map and inline image  at the source of the <dot> tag in $Web.$Topic
        my $loc = $urlPath . "/$web/$topic";
        my $src = TWiki::urlEncode("$loc/$outFilename.$inlineAttach");
        return "<noautolink>$mapfile<img usemap=\"#$hashCode\" src=\"$src\"/></noautolink>$fileLinks";
    } else {
        # attach the inline image  at the source of the <dot> tag in $Web.$Topic
        my $loc = $urlPath . "/$web/$topic";
        my $src = TWiki::urlEncode("$loc/$outFilename.$inlineAttach");
      return "<img src=\"$src\"/>$fileLinks";
    } ### else [ if ($doMap)
} ### sub handleDot


### sub _showError
#
#   Display any GraphViz reported errors inline into the file
#   For easier debuggin of malformed <dot> tags.

sub _showError
{
    my ( $status, $output, $text, $errFile ) = @_;

    # Check error file for detailed report from graphviz binary
    if (defined $errFile && $errFile && -s $errFile)
    {
        open (ERRFILE, $errFile);
        my @errLines = <ERRFILE>;
        $text = "*DirectedGraphPlugin error:* <verbatim>" . join("", @errLines) . "</verbatim>";
        $errFile =~ tr!\\!/!;
        unlink $errFile unless $debugDefault;
    }

    my $line = 1;
    $text =~ s/\n/sprintf("\n%02d: ", $line++)/ges if ($text);
    $output .= "<pre>$text\n</pre>";
  return "<font color=\"red\"><nop>DirectedGraph Error ($status): $output</font>";
} ### sub _showError

### sub _writeDebug
#
#   Writes a common format debug message if debug is enabled

sub _writeDebug
{
    &TWiki::Func::writeDebug( "$pluginName - " . $_[0] ) if $debugDefault;
} ### SUB _writeDebug


### sub afterRenameHandler
#
#   This routine will rename or delete any workarea files.  If topic is renamed
#   to the Trash web, then the workarea files are simply removed, otherwise they
#   are renamed to the new Web and topic name.

sub afterRenameHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $oldWeb, $oldTopic, $oldAttachment, $newWeb, $newTopic, $newAttachment ) = @_;

    my $oldweb = $_[0];
    $oldweb =~ s/\//_/g;  # convert subweb separators to underscore
    my $oldtopic = $_[1];
    my $newweb = $_[3];
    $newweb =~ s/\//_/g;  # convert subweb separators to underscore
    my $newtopic = $_[4];
    my $workAreaDir = TWiki::Func::getWorkArea('DirectedGraphPlugin');
    
   &_writeDebug( "- ${pluginName}::afterRenameHandler( " .
                            "$_[0].$_[1] $_[2] -> $_[3].$_[4] $_[5] )" );

   # Find all files in the workarea directory for the old topic
   # rename them unless new web is Trash, otherwise delete them.
   # 
   # files are named any of $web_$topic_DirectedGraphPlugin_n 
   #                     or $web_$topic_<user specified name>
   #                     or $web_$topic-filehash
   #

   opendir(DIR, $workAreaDir) || die "<ERR> Can't find directory --> $workAreaDir !";
   
   my @wfiles  = grep { /^${oldweb}_${oldtopic}-/ } readdir(DIR);
   foreach my $f (@wfiles) {
      my $prefix = "${oldweb}_${oldtopic}-";
      my ($suffix) = ($f =~  "^$prefix(.*)" );
      $f = TWiki::Sandbox::untaintUnchecked($f);
      if ($newweb eq "Trash") {
         unlink "$workAreaDir/$f";
      } else {
         my $newname = "${newweb}_${newtopic}-${suffix}";
	 $newname = TWiki::Sandbox::untaintUnchecked($newname);
	 &_writeDebug(" Renaming $workAreaDir/$f to $workAreaDir/$newname ");
         rename ("$workAreaDir/$f", "$workAreaDir/$newname");
      }
  }
} ### sub afterRenameHandler

### sub _loadHashCodes    
#
#   This routine loads the hash array from the stored file in the workarea directory
#   It also will convert any older style hash files into the new single file written
#   by the Storable routines.

sub _loadHashCodes {

    my $workAreaDir = TWiki::Func::getWorkArea('DirectedGraphPlugin');

    opendir(DIR, $workAreaDir) || die "<ERR> Can't find directory --> $workAreaDir !";

    my %tempHash;
    my %typeHash;

    if (-e "$workAreaDir/${usWeb}_${topic}-filehash") {
        &_writeDebug(" loading filehash  ");
        my $hashref = retrieve("$workAreaDir/${usWeb}_${topic}-filehash");
        %tempHash = %$hashref;
        return %tempHash;
    }

    ### Temporary Code - Convert file hash codes 
    ### and delete the old files from the workarea
    ### Also insert any old format attachments into the table 
    ### for later cleanup.
    
    # Get all the attachments filenames and extract their types

    my ($met, $tex) =  TWiki::Func::readTopic( $web, $topic );
    my @attachments = $met->find( 'FILEATTACHMENT' );
        &_writeDebug(" converting old filehash  ");
        foreach my $a (@attachments) {
	    my $aname = $a->{name};
            my ($n, $t) = $aname =~ m/^(.*)\.(.*)$/; # Split file name and type
	    &_writeDebug("    - Attach = |$aname| Name = |$n| Type = |$t| ");
            $typeHash{$n} .= " ".$t;
	    my ($on) = $n =~ m/^graph([0-9a-f]{32})$/;   # old style attachment graph<hashcode>.xxx
	    if ($on) {   
	        $tempHash{MD5HASH}{$n} = $on;
		$tempHash{FORMATS}{$n} .= " ".$t;
	    } # if ($on)	
        } # foreach my $a

    # Read in all of the hash files for the generated attachments
    # and build a new format hash table.  

    my $fPrefix = $usWeb."_".$topic."_";
    my @wfiles  = grep { /^$fPrefix/ } readdir(DIR);
        &_writeDebug(" unlinking old hash files for $fPrefix");
        foreach my $f (@wfiles) {
            my $key = TWiki::readFile("$workAreaDir/$f");
            $f = TWiki::Sandbox::untaintUnchecked($f);
	    unlink "$workAreaDir/$f";              # delete the old style hash file
            &_writeDebug(" unlinking old filehash $workAreaDir/$f  ");
            $f =~ s/^${usWeb}_${topic}_(.*)/$1/g;    # recover the original attachment filename
            $tempHash{FORMATS}{$f} = $typeHash{$f};   # insert hash of types found in attachment table
	    $tempHash{MD5HASH}{$f} = $key;            # insert hash indexed by filename
	    &_writeDebug("$f = |$tempHash{MD5HASH}{$f}| types |$tempHash{FORMATS}{$f}| ");
        }

    # Write out new hashfile
    if (keys %tempHash) {
        &_writeDebug("    - Writing hashfile ");
        store \%tempHash, "$workAreaDir/${usWeb}_${topic}-filehash";
    }
    return %tempHash;

} ### sub _loadHashCodes


#
#  sub afterCommonTagsHandler
#   - Find any files or file types that are no longer needed
#     and move to Trash with a unique name.
#
sub afterCommonTagsHandler {

    if ( ($_[1] ne $topic) || ($_[2] ne $web)) {
        &_writeDebug(" SKIPPING afterCommonTagsHandler  web = |$web|  topic = |$topic|  $_[2] $_[1] ");
        return;
        }

   &_writeDebug( " >>> afterCommonTagsHandler entered ");


    my %newHash = ();
    my $newHashRef = thaw(TWiki::Func::getSessionValue('DGP_newhash')) ;

    if ($newHashRef) {   # DGP_newhash existed
        &_writeDebug("     -- newHashRef existed in session - writing out ");
        %newHash = %{ $newHashRef }; 
        my $workAreaDir = TWiki::Func::getWorkArea('DirectedGraphPlugin');
        store \%newHash, "$workAreaDir/${usWeb}_${topic}-filehash"; 

        if ($newHash{SET}) {  # dot tags have been processed
            my %oldHash = ();
            my $oldHashRef = thaw(TWiki::Func::getSessionValue('DGP_hash'))  ;
            if ($oldHashRef) {%oldHash = %{ $oldHashRef }; }

            &_writeDebug(" afterCommon - Value of SET s $newHash{SET} ");
            &_writeDebug(" delete = $deleteAttachDefault");
            &_writeDebug(" keys = ".(keys %oldHash));


            if (($deleteAttachDefault) && (keys %oldHash) ) {  # If there are any old files to deal with
                foreach my $filename (keys %{$oldHash{FORMATS}}) {       # Extract filename
		    my $oldTypes = $oldHash{FORMATS}{$filename} || "";
	            if ($debugDefault) {
                        &_writeDebug("old  $filename ... types= $oldTypes ") ;
                        &_writeDebug("new  $filename ... types= $newHash{FORMATS}{$filename} ") ;
                    } ### if ($debugDefault 
		    if ($oldTypes) {
                        foreach my $oldsuffix (split (" ",$oldTypes )) {
	                    if ( !($newHash{FORMATS}{$filename} =~ (/$oldsuffix/) )) {
	                       _deleteAttach("$filename.$oldsuffix");
	                    }   ### if (%newHash
	                } ### foreach my $olsduffix
		    } ### if ($oldTypes)	
                } ### foreach my $filename 
            } ### if (keys %{$oldHash

            # Clear the session values
            TWiki::Func::clearSessionValue('DGP_hash');
            TWiki::Func::clearSessionValue('DGP_newhash');
        } ### if ($newHash{SET}	
    } ### if ($newHashRef)

} ### sub afterCommonTagsHandler


### sub _deleteAttach
#
#   Handles moving unneeded attachments to the Trash web with a new name which includes
#   the Web name and Topic name.  On older versions of TWiki, it simply deleted the files
#   with perl's unlink.  Also use unlink if direct file I/O requested.

sub _deleteAttach {

    my $fn = TWiki::Sandbox::normalizeFileName($_[0]);

    if (_attachmentExists( $web, $topic, $fn )) {

        if (($attachPath) && !($forceAttachAPI eq "on")) {    # Direct file I/O requested
	     unlink "$attachPath/$web/$topic/$fn";
             &_writeDebug(" ### Unlinked $attachPath/$web/$topic/$fn ");

        } else {    # TWiki attach API used
            # If the TrashAttachment topic is missing, create it.
            if (!TWiki::Func::topicExists( $TWiki::cfg{TrashWebName}, 'TrashAttachment' ) ) {
                &_writeDebug(" ### Creating missing TrashAttachment topic ");
                my $text = "---+ %MAKETEXT{\"Placeholder for trashed attachments\"}%\n";
                TWiki::Func::saveTopic( "$TWiki::cfg{TrashWebName}", "TrashAttachment", undef, $text, undef );
                } # if (! TWiki::Func::topicExists
         
            &_writeDebug(" >>> Trashing $web . $topic . $fn");
 
            my $i = 0;
            my $of = $fn;
            while (TWiki::Func::attachmentExists( $TWiki::cfg{TrashWebName}, 'TrashAttachment', "$web.$topic.$of" )) {
                &_writeDebug(" ------ duplicate in trash  $of");
                $i++;
                $of .= "$i";
            } # while (TWiki::Func

            TWiki::Func::moveAttachment( $web ,
                $topic,
                $fn,
                $TWiki::cfg{TrashWebName},
                'TrashAttachment', 
	        "$web.$topic.$of" ); 
        } # else if ($attachPath)   
    } # _attachmentExists    
} ### sub _deleteFile

#
#  _make_path 
#    For direct file i/o, make sure the target directory exists
#    returns the target directory for the attachments.
#
sub _make_path {
    my ( $topic, $web ) = @_;

    my @webs = split('/',$web);   # Split web in case subwebs are present
    my $dir = TWiki::Func::getPubDir();

    foreach my $val (@webs) {     # Process each subweb in the web path
        $dir .= '/'.$val;
        if( ! -e $dir ) {
            umask( 002 );
            mkdir( $dir, 0775 );
        }  # if (! -e $dir
    } # foreach

    # If the top level "pub/$web/$topic" directory doesn't exist, create
    # it.
    $dir .= '/'.$topic;
    if( ! -e "$dir" ) {
        umask( 002 );
        mkdir( $dir, 0775 );
    }
    # Return the complete path to target directory
    return ($dir);
} ### sub _make_path


#
# _attachmentExists
#    Check if attachment exists - use TWiki API or direct file I/O
#
sub _attachmentExists {
   my ( $web, $topic, $fn ) = @_;

   if (($attachPath) && !($forceAttachAPI eq "on")) {
      return ( -e "$attachPath/$web/$topic/$fn" )
      } else {
      return TWiki::Func::attachmentExists( $web, $topic, $fn )
      }
}

1;

