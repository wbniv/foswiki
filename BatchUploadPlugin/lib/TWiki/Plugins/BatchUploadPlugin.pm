package TWiki::Plugins::BatchUploadPlugin;

# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.com
# Copyright (C) Vito Miliano, ZacharyHamm, JohannesMartin, DiabJerius
# Copyright (C) 2004 Martin Cleaver, Martin.Cleaver@BCS.org.uk
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

# Originally by Vito Miliano EPIC Added 22 Mar 2003
# Modified by ZacharyHamm, JohannesMartin, DiabJerius
# Converted to a plugin by MartinCleaver
# Updated by ArthurClemens, MarkusUeberall

use strict;
use Archive::Zip qw(:ERROR_CODES :CONSTANTS :PKZIP_CONSTANTS);
use warnings;
use diagnostics;

use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $pluginName
  $debug $pluginEnabled $stack $stackDepth $MAX_STACK_DEPTH
  $importFileComments $fileCommentFlags
);

# This should always be $Rev: 17006 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 17006 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = '1.4';

$pluginName = 'BatchUploadPlugin';    # Name of this Plugin

BEGIN {

    # keep track of depth level of nested zips
    $stack = ();

    $stackDepth = 0;

    # maximum level of recursion of zips in zips
    $MAX_STACK_DEPTH = 30;
}

sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.024 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPluginPreferencesFlag("DEBUG");

    $pluginEnabled = TWiki::Func::getPluginPreferencesValue("ENABLED") || 0;

    $importFileComments = TWiki::Func::getPluginPreferencesFlag("IMPORTFILECOMMENTS");
    $fileCommentFlags = TWiki::Func::getPluginPreferencesFlag("FILECOMMENTFLAGS");

    # Plugin correctly initialized
    TWiki::Func::writeDebug("- ${pluginName}::initPlugin( $web.$topic ) is OK")
      if $debug;

    return 1;
}

=pod

Store callback called before the attachment is further processed.
Preliminary attempt to tackle nested zips - does not actually work yet. Each time we fall through beforeAttachmentSaveHandler to the actual attaching, other
attachments get lost.

=cut

sub beforeAttachmentSaveHandler {
    my ( $attrHashRef, $topic, $web ) = @_;

    TWiki::Func::writeDebug(
"- ${pluginName}::beforeAttachmentSaveHandler( $_[2].$_[1] - attachment: $attrHashRef->{attachment})"
    ) if $debug;

    my $cgiQuery = TWiki::Func::getCgiQuery();
    return if ( !$pluginEnabled );
    
    my $batchupload = $cgiQuery->param('batchupload') || '';
    return if ( ( $TWiki::cfg{Plugins}{BatchUploadPlugin}{usercontrol} ) 
                && ( $batchupload ne 'on' ) );
    
    my $attachmentName = $attrHashRef->{attachment};

    return if ( !isZip($attachmentName) );

    return if ( $stackDepth > $MAX_STACK_DEPTH );

    $stack->{$attachmentName} = $stackDepth;
    TWiki::Func::writeDebug(
        "$pluginName - $attachmentName has stack depth $stackDepth")
      if $debug;
    $stackDepth++;
    
    my $result = updateAttachment(
        $web, $topic, $attachmentName,
        $attrHashRef->{"tmpFilename"},
        $attrHashRef->{"comment"},
        $cgiQuery->param('hidefile') || '',
        $cgiQuery->param('createlink') || ''
    );

    if ($result) {
        if ( $stack->{$attachmentName} == 0 ) {
            TWiki::Func::writeDebug(
                "$pluginName - Result stack: " . $stack->{$attachmentName} )
              if $debug;
            my $url = TWiki::Func::getViewUrl( $web, $topic );
            print $cgiQuery->redirect($url);
            exit 0
              ; # user won't see this, but if left out the zip file will be attached, overwriting the zipped files
        }
    }

}

=pod

Checks if a file is a zip file.
Returns true if the file has a zip extension, false if not.

=cut

sub isZip {
    my ($fileName) = @_;
    return $fileName =~ m/.zip$/;
}

=pod

Return: 1 if successful, 0 if not successful.

=cut

sub updateAttachment {

    my (
        $webName,
        $topic,
        $originalZipName,
        $zipArchive,    # cgi name
        $fileComment,
        $hideFlag,
        $linkFlag
    ) = @_;

    my ( $zip, %processedFiles, $tempDir );

    $zip =
      openZipSanityCheck( $zipArchive, $webName, $topic, $originalZipName );
    unless ( ref $zip ) {
        die "Problem with " . $zip;
    }

    # Create temp directory to unzip files into
    # the unzipped files will be attached afterwards
    my $workArea = TWiki::Func::getWorkArea($pluginName);

    # Temp file in workarea
    $tempDir = $workArea . '/' . int( rand(1000000000) );

    mkdir($tempDir);

    # Change to the new directory: on some systems with some versions of
    # Archive::Zip extractMemberWithoutPaths() ignores the path given to it and
    # tries to just write the file to the current directory.
    chdir($tempDir);
      
    TWiki::Func::writeDebug("$pluginName - Created temp dir $tempDir")
      if $debug;

    %processedFiles = doUnzip( $tempDir, $zip );

    # Loop through processed files.
    foreach my $fileNameKey ( sort keys %processedFiles ) {
        my $fileName = $processedFiles{$fileNameKey}->{name};
        my $tmpFilename = $fileNameKey;

        my ( $fileSize, $fileUser, $fileDate, $fileVersion ) = "";

        # get file size
        my @stats = stat $tmpFilename;
        $fileSize = $stats[7];

        # use current time for upload
        $fileDate = time();

        # use the upload form values only if these settings have not been specified in the zip file comment
        my $hideFile = $processedFiles{$fileNameKey}->{hide} || $hideFlag;
        my $linkFile = $processedFiles{$fileNameKey}->{createlink} || $linkFlag;

        # attachment inherits the zip file comment; if none given, the the upload form comment is used
        # (last resort is a hardcoded, non-localized comment)
        my $tmpFileComment = $processedFiles{$fileNameKey}->{comment};
        $tmpFileComment = $fileComment unless $tmpFileComment;
        $tmpFileComment = "Extracted from $originalZipName" unless $tmpFileComment;

        TWiki::Func::writeDebug(
"$pluginName - Trying to attach: fileName=$fileName, fileSize=$fileSize, fileDate=$fileDate, fileComment=$tmpFileComment, tmpFilename=$tmpFilename"
        ) if $debug;

        TWiki::Func::saveAttachment(
            $webName, $topic,
            my $result = $fileName,
            {
                file       => $fileName,
                filepath   => $tmpFilename,
                hide       => $hideFile,
                createlink => $linkFile,
                filesize   => $fileSize,
                filedate   => $fileDate,
                comment    => $tmpFileComment
            }
        );

        if ( $result eq $fileName ) {
            TWiki::Func::writeDebug("$pluginName - Attaching $fileName went OK")
              if $debug;
        }
        else {
            TWiki::Func::writeDebug(
                "$pluginName - An error occurred while attaching $fileName")
              if $debug;
            die "An error occurred while attaching $fileName";
        }

        # remove temp file
        unlink($tmpFilename);
    }

    # remove temp dir
    rmdir($tempDir);

    return 1;
}

=pod

changed to work around a race condition where a symlink could be made in the 
temp directory pointing to a file writable by the CGI and then a zip uploaded 
with that filename, also solves the problem if two people are uploading zips 
with some identical filenames.
=cut

sub doUnzip {

    my ( $tempDir, $zip ) = @_;

    my ( @memberNames, $fileName, $fileComment, $hideFile, $linkFile, $member, $buffer, %good, $zipRet );

    @memberNames = $zip->memberNames();

    foreach $fileName ( sort @memberNames ) {
        $member = $zip->memberNamed($fileName);
        next if $member->isDirectory();

        $fileName =~ /\/?(.*\/)?(.+)/;
        $fileName = $2;

        # Make filename safe:
        my $origFileName = $fileName;

        # Protect against evil filenames - especially for out temp file.
        $fileName =~ /\.*([ \w_.\-]+)$/go;
        $fileName = $1;

        # Change spaces to underscore
        $fileName =~ s/ /_/go;

        # Remove problematic chars
        $fileName =~ s/$TWiki::cfg{NameFilter}//goi;

        # Append .txt to files like we do to normal attachments
        $fileName =~ s/$TWiki::cfg{UploadFilter}/$1\.txt/goi;

        $hideFile = undef;
        $linkFile = undef;
        if ( $importFileComments || $fileCommentFlags ) {
            # determine file comment
            # search comment for prefixes "-/+L", "-/+H" ((don't) insert link/hide attachment)
            # NB we don't allow whitespace between flags, only last setting of each flag type counts
            $fileComment = $member->fileComment();
            if ($fileCommentFlags && ($fileComment =~ /^\s*([+-][hl])+(\s.+|$)/i)) {
                $fileComment =~ s/^\s+//;
                while ($fileComment =~ /^([+-][hl])(.*)$/i) {
                    my $options = $1;
                    $fileComment = $2;

                    my $opval = substr($options, 0, 1);
		    $opval =~ tr/+-/10/;

                    my $opkey = uc(substr($options, 1, 1));
                    if ($opkey eq "H") {
                        $hideFile = $opval;
                    } else {
                        $linkFile = $opval;
                    }
                }
                $fileComment =~ s/^\s+//;
            }
            if ( !$importFileComments ) {
                $fileComment = undef;
            }
	    
        }

        if ( $debug && ( $fileName ne $origFileName ) ) {
            TWiki::Func::writeDebug(
                "$pluginName - Renamed file $origFileName to $fileName");
        }

        $zipRet =
          $zip->extractMemberWithoutPaths( $member, "$tempDir/$fileName" );
        if ( $zipRet == AZ_OK ) {
            $good{"$tempDir/$fileName"} = {
                name       => $fileName,
                comment    => $fileComment,
                hide       => $hideFile,
                createlink => $linkFile
            };
        }
        else {

            # FIXME: oops here
            TWiki::Func::writeDebug(
"$pluginName - Something went wrong with uploading of zip file $fileName: $zipRet"
            ) if $debug;
        }
    }

    return %good;
}

=pod

Open a zip and perform a sanity check on it.
Returns the opened zip object (to be passed to doUnzip) on success,
a string saying the reason for failure.

=cut

sub openZipSanityCheck {

    my ( $archive, $webName, $topic, $realname ) = @_;
    my ( $lowerCase, $noSpaces, $noredirect ) = ( 0, 0, 0 );
    my $zip = Archive::Zip->new();
    my ( @memberNames, $fileName, $member, %dupCheck, $sizeLimit );

    if ( $zip->read($archive) != AZ_OK ) {
        return "Zip read error or not a zip file. " . $archive;
    }

    # Scan for duplicates
    @memberNames = $zip->memberNames();

    foreach $fileName (@memberNames) {
        $member = $zip->memberNamed($fileName);
        next if $member->isDirectory();

        $fileName =~ /\/?(.*\/)?(.+)/;
        $fileName = $2;

        if ($lowerCase) { $fileName = lc($fileName); }
        unless ($noSpaces) { $fileName =~ s/\s/_/go; }

        $fileName =~ s/$TWiki::cfg{UploadFilter}/$1\.txt/goi;

        if ( defined $dupCheck{"$fileName"} ) {
            return "Duplicate file in archive " . $fileName . " in " . $archive;
        }
        else {
            $dupCheck{"$fileName"} = $fileName;
        }
    }
    return $zip;
}

1;
