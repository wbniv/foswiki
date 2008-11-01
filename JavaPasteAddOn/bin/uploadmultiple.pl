#!/usr/bin/perl -wT
# TAKEN FROM http://twiki.org/p/pub/Codev/MultipleAttachmentsAtOnce/upload
# TWiki WikiClone (see TWiki.pm for $wikiversion and other info)
#
# Copyright (C) 1999-2001 Peter Thoeny, peter@thoeny.com
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

# This is a place holder for a version that allows multiple attachments 
# to be uploaded in one HTTP connection, without the use of a zip file.

use CGI::Carp qw(fatalsToBrowser);
use CGI;
use File::Copy; # FIXME remove
use lib ( '.' );
use lib ( '../lib' );
use TWiki;
# RNF Added 02 Jan 2002
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
# VBM Commented out until Archive::Tar works in strict mode.
# use Archive::Tar;
# use Compress::Zlib;

$query = new CGI;

##### for debug only: Remove next 3 comments (but redirect does not work)
#open(STDERR,'>&STDOUT'); # redirect error to browser
#$| = 1;                  # no buffering
#TWiki::writeHeader( $query );

&main();


# =========================
# code fragment to extract pixel size from images
# taken from http://www.tardis.ed.ac.uk/~ark/wwwis/
# subroutines: imgsize, gifsize, OLDgifsize, gif_blockskip,
#              NEWgifsize, jpegsize
#
# looking at the filename really sucks I should be using the first 4 bytes
# of the image. If I ever do it these are the numbers.... (from chris@w3.org)
#  PNG 89 50 4e 47
#  GIF 47 49 46 38
#  JPG ff d8 ff e0
#  XBM 23 64 65 66


# =========================
sub imgsize {
  my( $file ) = shift @_;
  my( $x, $y) = ( 0, 0 );

  if( defined( $file ) && open( STRM, "<$file" ) ) {
    binmode( STRM ); # for crappy MS OSes - Win/Dos/NT use is NOT SUPPORTED
    if( $file =~ /\.jpg$/i || $file =~ /\.jpeg$/i ) {
      ( $x, $y ) = &jpegsize( \*STRM );
    } elsif( $file =~ /\.gif$/i ) {
      ( $x, $y ) = &gifsize(\*STRM);
    }
    close( STRM );
  }
  return( $x, $y );
}


# =========================
sub gifsize
{
  my( $GIF ) = @_;
  if( 0 ) {
    return &NEWgifsize( $GIF );
  } else {
    return &OLDgifsize( $GIF );
  }
}


# =========================
sub OLDgifsize {
  my( $GIF ) = @_;
  my( $type, $a, $b, $c, $d, $s ) = ( 0, 0, 0, 0, 0, 0 );

  if( defined( $GIF )              &&
      read( $GIF, $type, 6 )       &&
      $type =~ /GIF8[7,9]a/        &&
      read( $GIF, $s, 4 ) == 4     ) {
    ( $a, $b, $c, $d ) = unpack( "C"x4, $s );
    return( $b<<8|$a, $d<<8|$c );
  }
  return( 0, 0 );
}


# =========================
# part of NEWgifsize
sub gif_blockskip {
  my ( $GIF, $skip, $type ) = @_;
  my ( $s ) = 0;
  my ( $dummy ) = '';

  read( $GIF, $dummy, $skip );       # Skip header (if any)
  while( 1 ) {
    if( eof( $GIF ) ) {
      #warn "Invalid/Corrupted GIF (at EOF in GIF $type)\n";
      return "";
    }
    read( $GIF, $s, 1 );             # Block size
    last if ord( $s ) == 0;          # Block terminator
    read( $GIF, $dummy, ord( $s ) ); # Skip data
  }
}


# =========================
# this code by "Daniel V. Klein" <dvk@lonewolf.com>
sub NEWgifsize {
  my( $GIF ) = @_;
  my( $cmapsize, $a, $b, $c, $d, $e ) = 0;
  my( $type, $s ) = ( 0, 0 );
  my( $x, $y ) = ( 0, 0 );
  my( $dummy ) = '';

  return( $x,$y ) if( !defined $GIF );

  read( $GIF, $type, 6 );
  if( $type !~ /GIF8[7,9]a/ || read( $GIF, $s, 7 ) != 7 ) {
    #warn "Invalid/Corrupted GIF (bad header)\n";
    return( $x, $y );
  }
  ( $e ) = unpack( "x4 C", $s );
  if( $e & 0x80 ) {
    $cmapsize = 3 * 2**(($e & 0x07) + 1);
    if( !read( $GIF, $dummy, $cmapsize ) ) {
      #warn "Invalid/Corrupted GIF (global color map too small?)\n";
      return( $x, $y );
    }
  }
 FINDIMAGE:
  while( 1 ) {
    if( eof( $GIF ) ) {
      #warn "Invalid/Corrupted GIF (at EOF w/o Image Descriptors)\n";
      return( $x, $y );
    }
    read( $GIF, $s, 1 );
    ( $e ) = unpack( "C", $s );
    if( $e == 0x2c ) {           # Image Descriptor (GIF87a, GIF89a 20.c.i)
      if( read( $GIF, $s, 8 ) != 8 ) {
        #warn "Invalid/Corrupted GIF (missing image header?)\n";
        return( $x, $y );
      }
      ( $a, $b, $c, $d ) = unpack( "x4 C4", $s );
      $x = $b<<8|$a;
      $y = $d<<8|$c;
      return( $x, $y );
    }
    if( $type eq "GIF89a" ) {
      if( $e == 0x21 ) {         # Extension Introducer (GIF89a 23.c.i)
        read( $GIF, $s, 1 );
        ( $e ) = unpack( "C", $s );
        if( $e == 0xF9 ) {       # Graphic Control Extension (GIF89a 23.c.ii)
          read( $GIF, $dummy, 6 );        # Skip it
          next FINDIMAGE;       # Look again for Image Descriptor
        } elsif( $e == 0xFE ) {  # Comment Extension (GIF89a 24.c.ii)
          &gif_blockskip( $GIF, 0, "Comment" );
          next FINDIMAGE;       # Look again for Image Descriptor
        } elsif( $e == 0x01 ) {  # Plain Text Label (GIF89a 25.c.ii)
          &gif_blockskip( $GIF, 12, "text data" );
          next FINDIMAGE;       # Look again for Image Descriptor
        } elsif( $e == 0xFF ) {  # Application Extension Label (GIF89a 26.c.ii)
          &gif_blockskip( $GIF, 11, "application data" );
          next FINDIMAGE;       # Look again for Image Descriptor
        } else {
          #printf STDERR "Invalid/Corrupted GIF (Unknown extension %#x)\n", $e;
          return( $x, $y );
        }
      } else {
        #printf STDERR "Invalid/Corrupted GIF (Unknown code %#x)\n", $e;
        return( $x, $y );
      }
    } else {
      #warn "Invalid/Corrupted GIF (missing GIF87a Image Descriptor)\n";
      return( $x, $y );
    }
  }
}


# =========================
# jpegsize : gets the width and height (in pixels) of a jpeg file
# Andrew Tong, werdna@ugcs.caltech.edu           February 14, 1995
# modified slightly by alex@ed.ac.uk
sub jpegsize {
  my( $JPEG ) = @_;
  my( $done ) = 0;
  my( $c1, $c2, $ch, $s, $length, $dummy ) = ( 0, 0, 0, 0, 0, 0 );
  my( $a, $b, $c, $d );

  if( defined( $JPEG )             &&
      read( $JPEG, $c1, 1 )        &&
      read( $JPEG, $c2, 1 )        &&
      ord( $c1 ) == 0xFF           &&
      ord( $c2 ) == 0xD8           ) {
    while ( ord( $ch ) != 0xDA && !$done ) {
      # Find next marker (JPEG markers begin with 0xFF)
      # This can hang the program!!
      while( ord( $ch ) != 0xFF ) {
        return( 0, 0 ) unless read( $JPEG, $ch, 1 );
      }
      # JPEG markers can be padded with unlimited 0xFF's
      while( ord( $ch ) == 0xFF ) {
        return( 0, 0 ) unless read( $JPEG, $ch, 1 );
      }
      # Now, $ch contains the value of the marker.
      if( ( ord( $ch ) >= 0xC0 ) && ( ord( $ch ) <= 0xC3 ) ) {
        return( 0, 0 ) unless read( $JPEG, $dummy, 3 );
        return( 0, 0 ) unless read( $JPEG, $s, 4 );
        ( $a, $b, $c, $d ) = unpack( "C"x4, $s );
        return( $c<<8|$d, $a<<8|$b );
      } else {
        # We **MUST** skip variables, since FF's within variable names are
        # NOT valid JPEG markers
        return( 0, 0 ) unless read( $JPEG, $s, 2 );
        ( $c1, $c2 ) = unpack( "C"x2, $s );
        $length = $c1<<8|$c2;
        last if( !defined( $length ) || $length < 2 );
        read( $JPEG, $dummy, $length-2 );
      }
    }
  }
  return( 0, 0 );
}


# =========================
sub addLinkToEndOfTopic
{
    my ( $text, $pathFilename, $fileName, $fileComment ) = @_;
    my $fileLink = "";
    my $imgSize = "";

    if( $fileName =~ /\.(gif|jpg|jpeg|png)$/i ) {
        # inline image
        $fileComment = $fileName if( ! $fileComment );
        my( $nx, $ny ) = &imgsize( $pathFilename );
        if( ( $nx > 0 ) && ( $ny > 0 ) ) {
            $imgSize = " width=\"$nx\" height=\"$ny\" ";
        }
        $fileLink = &TWiki::Prefs::getPreferencesValue( "ATTACHEDIMAGEFORMAT" )
                  || '   * $comment: <br />'
                   . ' <img src="%ATTACHURLPATH%/$name" alt="$name"$size />';
    } else {
        # normal attached file
        $fileLink = &TWiki::Prefs::getPreferencesValue( "ATTACHEDFILELINKFORMAT" )
                 || '   * [[%ATTACHURL%/$name][$name]]: $comment';
    }

    $fileLink =~ s/^      /\t\t/go;
    $fileLink =~ s/^   /\t/go;
    $fileLink =~ s/\$name/$fileName/g;
    $fileLink =~ s/\$comment/$fileComment/g;
    $fileLink =~ s/\$size/$imgSize/g;
    $fileLink =~ s/\\t/\t/go;
    $fileLink =~ s/\\n/\n/go;
    $fileLink =~ s/([^\n])$/$1\n/;

    return "$text$fileLink";
}

# =========================
sub handleError
{
    my( $noredirect, $message, $query, $theWeb, $theTopic, 
        $theOopsTemplate, $oopsArg1, $oopsArg2 ) = @_;
    
    if( $noredirect ) {
        $oopsArg1 = "" if( ! $oopsArg1 );
        $oopsArg2 = "" if( ! $oopsArg2 );
        &TWiki::writeHeader( $query );
        print "ERROR $theWeb.$theTopic $message $oopsArg1 $oopsArg2\n";
    } else {
	my $url = &TWiki::getOopsUrl( $theWeb, $theTopic, $theOopsTemplate, $oopsArg1, $oopsArg2 );
	TWiki::redirect( $query, $url );
    }
}


# =========================
sub main
{
    my $thePathInfo = $query->path_info(); 
    my $theRemoteUser = $query->remote_user();
    my $theTopic = $query->param( 'topic' );
    my $theUrl = $query->url;
    my $doChangeProperties = $query->param( 'changeproperties' );
    my $hideFile = $query->param( 'hidefile' ) || "";
    my $noredirect = $query->param( 'noredirect' ) || "";
    
    ( $topic, $webName, $dummy, $userName ) = 
	&TWiki::initialize( $thePathInfo, $theRemoteUser, $theTopic, $theUrl, $query );
    $dummy = "";  # to suppress warning

    my $wikiUserName = &TWiki::userToWikiName( $userName );

    if( ! &TWiki::Store::webExists( $webName ) ) {
        handleError( $noredirect, "Missing Web", $query, $webName, $topic, "oopsnoweb" );
        return;
    }

    my( $mirrorSiteName, $mirrorViewURL ) = &TWiki::readOnlyMirrorWeb( $webName );
    if( $mirrorSiteName ) {
        handleError( $noredirect, "This is a readonly mirror", 
               $query, $webName, $topic, "oopsmirror", $mirrorSiteName, $mirrorViewURL );
        return;
    }

    # check access permission
    if( ! &TWiki::Access::checkAccessPermission( "change", $wikiUserName, "", $topic, $webName ) ) {
        handleError( $noredirect, "No change permission", $query, $webName, $topic, "oopsaccesschange" );
        return;
    }
    
    my $filePath = $query->param( 'filepath' ) || "";    
    my $fileName = $query->param( 'filename' ) || "";
    if ( $filePath && ! $fileName ) {
        $filePath =~ m|([^/\\]*$)|;
        $fileName = $1;
    }
    my $tmpFilename = $query->tmpFileName( $filePath ) || "";
    my $fileComment = $query->param( 'filecomment' ) || "";
    my $createLink = $query->param( 'createlink' ) || "";
    
    # RNF Added 29 Dec 2001
    my $archivefile = $query->param( 'archivefile' ) || "";

    # JET need to change windows path to unix path
    $tmpFilename =~ s@\\@/@go;
    $tmpFilename =~ /(.*)/;
    $tmpFilename = $1;
    #&TWiki::writeDebug( "upload: tmpFilename $tmpFilename" );
    
    # RNF Added 29 Dec 2001
    my %processedFiles;
    if (($archivefile) && ($fileName =~ /\.zip/)) { %processedFiles = doUnzip($tmpFilename); }
    else { $processedFiles{$tmpFilename} = "$fileName|$fileComment"; }
    
    my $fileNameKey; my @tmpProc;
    foreach $fileNameKey (keys %processedFiles) { # RNF Loop through processed files.
      @tmpProc = split /\|/, $processedFiles{$fileNameKey};
      $fileName = $tmpProc[0]; $fileName =~ /^(.*?)$/goi; $fileName = $1;
      $fileComment = $tmpProc[1];
      $tmpFilename = $fileNameKey;
    
      my( $fileSize, $fileUser, $fileDate, $fileVersion ) = "";

      if( ! $doChangeProperties ) {
	# check if file exists and has non zero size
	my $size = -s $tmpFilename;
	if( ! -e $tmpFilename || ! $size ) {
	    handleError( $noredirect, "File missing or zero size", 
	           $query, $webName, $topic, "oopsupload", $fileName );
	    return;
	}
	
	# Update
	my $text1 = "";
	my $saveCmd = "";
	my $doNotLogChanges = 1;
	my $doUnlock = 1;
	my $dontNotify = "";
	my $error = &TWiki::Store::saveAttachment( $webName, $topic, $text1, $saveCmd,
                                                   $fileName, $doNotLogChanges, $doUnlock, 
						   $dontNotify, $fileComment, $tmpFilename );

	if ( $error ) {
	    handleError( $noredirect, "Save attachment error", $query, $webName, $topic,
	           "oopssaveerr", $error );
	    return;
	}

        if( $TWiki::doLogTopicUpload ) {
	    # write log entry
	    &TWiki::Store::writeLog( "upload", "$webName.$topic", $fileName );
	    #FIXE also do log for change property?
	}
	
	unlink $tmpFilename;
      }
      
    } # RNF End loop.
    
    foreach $fileNameKey (keys %processedFiles) { # RNF Loop through processed files again.
      @tmpProc = split /\|/, $processedFiles{$fileNameKey};
      $fileName = $tmpProc[0]; $fileName =~ /^(.*?)$/goi; $fileName = $1;
      $fileComment = $tmpProc[1];
      
      # update topic
      my( $meta, $text ) = &TWiki::Store::readTopic( $webName, $topic );
      
      if( $doChangeProperties ) {      
          TWiki::Attach::updateProperties( $fileName, $hideFile, $fileComment, $meta );
      } else {
          $fileVersion = TWiki::Store::getRevisionNumber( $webName, $topic, $fileName );
	  $fileName = "$TWiki::pubDir/$webName/$topic/" . $fileName;
          
          # get user name
          $fileUser = $userName;
          
          # get time stamp and file size of uploaded file:
          my( $tmp1,$tmp2,$tmp3,$tmp4,$tmp5,$tmp6,$tmp7,$tmp9,
              $mtime,$tmp11,$tmp12,$tmp13 ) = "";
            ( $tmp1,$tmp2,$tmp3,$tmp4,$tmp5,$tmp6,$tmp7,$fileSize,$tmp9,
              $mtime,$tmp11,$tmp12,$tmp13 ) = stat $fileName;
          $fileDate = $mtime;
	  
	  $fileName =~ s/^.*\///goi;
      
          TWiki::Attach::updateAttachment( 
                  $fileVersion, $fileName, $filePath, $fileSize,
                  $fileDate, $fileUser, $fileComment, $hideFile, $meta );
      }
        
        if( $createLink ) {
          my $filePath = &TWiki::Store::getFileName( $webName, $topic, $fileName );
          $text = addLinkToEndOfTopic( $text, $filePath, $fileName, $fileComment );
        }
        
        my $error = &TWiki::Store::saveTopic( $webName, $topic, $text, $meta );
          
      } # RNF End loop.
      
      if( $error ) {
      	handleError( $noredirect, "Save topic error", $query, $webName, $topic,
                     "oopssaveerr", $error );
      } else {
          # and finally display topic
          if( $noredirect ) {
              &TWiki::writeHeader( $query );
              my $message = ( $doChangeProperties ) ? "properties changed" : "$fileName uploaded";
              print( "OK $message\n" );
          } else {
              TWiki::redirect( $query, &TWiki::getViewUrl( "", $topic ) );
          }
      }
}

# Use this once Archive::Tar works. See below.
sub doArchive
{
    my $archive = shift;
    my (%files, $isCompressed, $gz, $zip);
    
    $zip = Archive::Zip->new();
    $gz = gzopen($archive, "rb"); if($gz) { $isCompressed = 1; } else { $isCompressed = 0; }
    
    if($zip->read($archive) == AZ_OK) { %files = doUnzip($archive, $web, $topic); }
    if(Archive::Tar->read($archive, $isCompressed)) { %files = doUntar($archive, $isCompressed); }
    
    return %files;
}

# This would work, except that Archive::Tar b0rks when run in strict mode.
# So it'll have to wait until that's fixed, I guess.
sub doUntar
{
    my ($archive, $comp) = @_;
    my $tar = Archive::Tar->new();
    my $tmpDir = $archive; $tmpDir =~ s/(.*)\/.+/$1/;
    my (@memberNames, $mName, $member, $buffer, $comment, %good);
    
    die $! if (! $tar->read($archive, $comp));
    
    @memberNames = $tar->list_files();
    foreach $mName (@memberNames) {
     $buffer = $tar->get_content($mName);
     $mName =~ /\/?(.*\/)?(.+)/; $mName = $2;
     
     if($mName) {
      open(F, ">$tmpDir/$mName") or next;
      print F $buffer;
      close(F);
      $good{"$tmpDir/$mName"} = "$mName|";
     }
   }
   
   return %good;
}
    

sub doUnzip
{
    my $archive = shift;
    my $zip = Archive::Zip->new();
    my $tmpDir = $archive; $tmpDir =~ s/(.*)\/.+/$1/;
    my (@memberNames, $mName, $member, $buffer, $comment, %good);
    
    die $! if $zip->read("$archive") != AZ_OK;
    
    @memberNames = $zip->memberNames();
    foreach $mName (@memberNames) {
      $buffer = $zip->contents($mName);
      $member = $zip->memberNamed($mName);
      $comment = substr($member->fileComment(), 0, 50);
      $mName =~ /\/?(.*\/)?(.+)/; $mName = $2;
      
      if($mName) {
        open(F, ">$tmpDir/$mName") or next;
        print F $buffer;
        close(F);
	$good{"$tmpDir/$mName"} = "$mName|$comment";
      }
    }
    
    return %good;
}

# EOF


