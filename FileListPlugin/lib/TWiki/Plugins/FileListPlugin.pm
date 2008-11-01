# Plugin for TWiki Collaboration Platform, http://TWiki.org/
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

package TWiki::Plugins::FileListPlugin;

use strict;
use TWiki::Plugins::FileListPlugin::FileData;

use vars qw($VERSION $RELEASE $web $topic $user $installWeb $pluginName
  $debug $renderingWeb $defaultFormat $imageFormat %listedExtensions
);

# This should always be $Rev: 15688 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 15688 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = '0.9.3';

$pluginName = 'FileListPlugin';    # Name of this Plugin

BEGIN {
    %listedExtensions = ();
}

sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    $defaultFormat = '   * [[$fileUrl][$fileName]] $fileComment';

    # Get plugin preferences
    $defaultFormat = TWiki::Func::getPreferencesValue('FORMAT')
      || TWiki::Func::getPluginPreferencesValue('FORMAT')
      || $defaultFormat;

    $defaultFormat =~ s/^[\\n]+//;    # Strip off leading \n

    $imageFormat = '<img src=\'$fileUrl\' alt=\'$fileComment\' />';

    # Get plugin preferences
    $imageFormat = TWiki::Func::getPreferencesValue('IMAGE_FORMAT')
      || TWiki::Func::getPluginPreferencesValue('IMAGE_FORMAT')
      || $imageFormat;

    $imageFormat =~ s/^[\\n]+//;      # Strip off leading \n

    # Get plugin debug flag
    $debug = TWiki::Func::getPluginPreferencesFlag("DEBUG");

    TWiki::Func::registerTagHandler( 'FILELIST', \&_handleFileList );

    # Plugin correctly initialized
    TWiki::Func::writeDebug(
        "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK")
      if $debug;

    return 1;
}

sub _handleFileList {
    my ( $session, $params, $theTopic, $theWeb ) = @_;

    my $web   = $params->{'web'}   || $theWeb   || '';
    my $topic = $params->{'topic'} || $theTopic || '';

    # check if the user has permissions to view the topic
    my $user = TWiki::Func::getWikiName();
    my $wikiUserName = TWiki::Func::userToWikiName( $user, 1 );
    if (
        !TWiki::Func::checkAccessPermission(
            'VIEW', $wikiUserName, undef, $topic, $web
        )
      )
    {
        return '';
    }

    my $outtext = "";

    my $format    = $params->{'format'}    || $defaultFormat;
    my $header    = $params->{'header'}    || '';
    my $footer    = $params->{'footer'}    || '';
    my $alttext   = $params->{'alt'}       || '';
    my $fileCount = $params->{'fileCount'} || '';
    my $separator = $params->{'separator'} || '';

    # filters
    my $limit                  = $params->{'limit'};
    my $excludeTopics          = $params->{'excludetopic'} || '';
    my $excludeWebs            = $params->{'excludeweb'} || '';
    my $excludeFiles           = $params->{'excludefile'} || '';
    my $excludeExtensionsParam = $params->{'excludeextension'} || '';
    my $extensionsParam        = $params->{"extension"}
      || $params->{"filter"};  # "abc, def" syntax. Substring match will be used
                               # param filter is deprecated
    my %extensions        = makeHashFromString( lc $extensionsParam );
    my %excludeExtensions = makeHashFromString( lc $excludeExtensionsParam );

    my $hideHidden = '';
    if ( defined $params->{"hide"} ) {
        $hideHidden =
          ( grep { $_ eq $params->{"hide"} } ( 'on', 'yes', '1' ) )
          ? 1
          : 0;                 # don't hide by default
    }

    my %hiddenFiles = makeHashFromString($excludeFiles);

    my @files =
      createAttachmentList( $topic, $web, $excludeTopics, $excludeWebs );

    # store once for re-use in loop
    my $pubUrl = TWiki::Func::getUrlHost() . TWiki::Func::getPubUrlPath();

    my $count = 0;
    foreach my $fileData (@files) {

        last if ( defined $limit && $count >= $limit );

        my $attachmentTopic    = $fileData->{'topic'};
        my $attachmentTopicWeb = $fileData->{'web'};
        my $attachment         = $fileData->{'attachment'};

        # do not show file if user has no permission to view this topic
        next
          if (
            !TWiki::Func::checkAccessPermission(
                'VIEW', $wikiUserName,
                undef,  $attachmentTopic,
                $attachmentTopicWeb
            )
          );

        my $filename = $attachment->{name};

        my $fileExtension = getFileExtension($filename);

        if (   ( keys %extensions && !$extensions{$fileExtension} )
            || ( $excludeExtensions{$fileExtension} ) )
        {
            next;
        }
        next if ( $hiddenFiles{$filename} );

        my $attrSize    = $attachment->{size};
        my $attrUser    = $attachment->{user};
        my $attrComment = $attachment->{comment};
        my $attrAttr    = $attachment->{attr};

        # skip if the attachment is hidden
        next if ( $attrAttr =~ /h/i && $hideHidden );

        # ------- END OF FILTERS -------

        $listedExtensions{$fileExtension} = 1 if ( $fileExtension ne '' );

     # I18N: To support attachments via UTF-8 URLs to attachment
     # directories/files that use non-UTF-8 character sets, go through viewfile.
     # If using %PUBURL%, must URL-encode explicitly to site character set.

        # Go direct to file where possible, for efficiency
        # TODO: more flexible size formatting
        # also take MB into account
        my $attrSizeStr;
        $attrSizeStr = $attrSize . 'b' if ( $attrSize < 100 );
        $attrSizeStr = sprintf( "%1.1fK", $attrSize / 1024 )
          if ( $attrSize >= 100 );
        $attrComment = $attrComment || "";
        my $s = "$format";

        if ( $s =~ /imgTag/ ) {
            $s =~ s/\$imgTag/$imageFormat/;
        }

        if ( $s =~ /imgHeight/ || $s =~ /imgWidth/ ) {

            # try to read image size
            my $store = $session->{store};

            my $attachmentExists =
              $store->attachmentExists( $attachmentTopicWeb, $attachmentTopic,
                $filename );
            my ( $nx, $ny ) = ( '', '' );
            if ($attachmentExists) {
                my $stream =
                  $store->getAttachmentStream( $wikiUserName,
                    $attachmentTopicWeb, $attachmentTopic, $filename );
                if ($stream) {
                    ( $nx, $ny ) = &_imgsize( $stream, $filename );
                }
            }
            $s =~ s/\$imgWidth/$nx/g;
            $s =~ s/\$imgHeight/$ny/g;
        }

        $s =~ s/\$fileName/$filename/g;

        if ( $s =~ /fileIcon/ ) {
            ## To find the File Extention..
            my @bits     = ( split( /\./, $filename ) );
            my $ext      = lc $bits[$#bits];
            my $fileIcon = '%ICON{"' . $ext . '"}%';
            $s =~ s/\$fileIcon/$fileIcon/g;
        }
        $s =~ s/\$fileSize/$attrSizeStr/g;
        $s =~ s/\$fileComment/$attrComment/g;
        if ( $s =~ /fileDate/ ) {
            my $attrDate = TWiki::Time::formatTime( $attachment->{"date"} );
            $s =~ s/\$fileDate/$attrDate/g;
        }
        $s =~ s/\$fileUser/$attrUser/g;

        #replace stubs
        $s =~ s/\$n/\n/g;
        $s =~ s/\$br/\<br \/\>/g;

        if ( $s =~ /fileActionUrl/ ) {
            my $fileActionUrl =
              TWiki::Func::getScriptUrl( $attachmentTopicWeb, $attachmentTopic,
                "attach" )
              . "?filename=$filename&revInfo=1";
            $s =~ s/\$fileActionUrl/$fileActionUrl/g;
        }

        if ( $s =~ /viewfileUrl/ ) {
            my $attrVersion = $attachment->{Version};
            my $viewfileUrl =
              TWiki::Func::getScriptUrl( $attachmentTopicWeb, $attachmentTopic,
                "viewfile" )
              . "?rev=$attrVersion&filename=$filename";
            $s =~ s/\$viewfileUrl/$viewfileUrl/g;
        }

        if ( $s =~ /\$hidden/ ) {
            my $hidden = ( $attrAttr =~ /h/i ) ? 'hidden' : '';
            $s =~ s/\$hidden/$hidden/g;
        }

        my $fileUrl =
          $pubUrl . "/$attachmentTopicWeb/$attachmentTopic/$filename";

        $s =~ s/\$fileUrl/$fileUrl/g;

        my $sep = $separator || "\n";
        $outtext .= $s . $sep;

        $count++;
    }

    # remove last separator
    $outtext =~ s/$separator$//g;

    if ( $outtext eq "" ) {
        $outtext = $alttext;
    }
    else {
        $outtext = $header . "\n" . $outtext . $footer;
    }

    # format parameters

    # fileCount format param
    $outtext =~ s/\$fileCount/$count/g;

    # fileExtensions format param
    my @extensionsList = sort ( keys %listedExtensions );
    my $listedExtensions = join( ',', @extensionsList );
    $outtext =~ s/\$fileExtensions/$listedExtensions/g;

    return $outtext;
}

sub getFileExtension {
    my ($filename) = @_;

    my $extension = $filename;
    $extension =~ s/^.*?\.(.*?)$/$1/g;
    return lc $extension;
}

=pod

Goes through the topics in $topicString, f.e. '%TOPIC%, WebHome'
or all topics in case of a wildcard '*'.

Returns a list of FileData objects.

=cut

sub createAttachmentList {
    my ( $topicString, $webString, $excludeTopicsString, $excludeWebssString ) =
      @_;

    my @files         = ();
    my %excludeTopics = makeHashFromString($excludeTopicsString);
    my %excludeWebs   = makeHashFromString($excludeWebssString);

    my @webs   = ();
    my @topics = ();
    if ( $webString eq '*' ) {
        @webs = TWiki::Func::getListOfWebs();
    }
    else {
        @webs = split( /[\s,]+/, $webString );
    }
    foreach my $web (@webs) {
        next if ( $excludeWebs{$web} );
        my @topics = ();
        if ( $topicString eq '*' ) {
            @topics = TWiki::Func::getTopicList($web);
        }
        else {
            @topics = split( /[\s,]+/, $topicString );
        }

        foreach my $attachmentTopic (@topics) {
            next if ( $excludeTopics{$attachmentTopic} );
            my @topicFiles =
              createAttachmentListForTopic( $attachmentTopic, $web );
            foreach my $attachment (@topicFiles) {
                my $fd = TWiki::Plugins::FileListPlugin::FileData->new(
                    $attachmentTopic, $web, $attachment );
                push @files, $fd;
            }
        }
    }
    return @files;
}

sub createAttachmentListForTopic {
    my ( $topic, $web ) = @_;

    my ( $meta, $text ) = TWiki::Func::readTopic( $web, $topic );
    return $meta->find("FILEATTACHMENT");
}

sub makeHashFromString {
    my ($text) = @_;

    my %hash = ();

    return %hash if !defined $text || !$text;

    my $re = '\b[\w\._\-\+\s]*\b';
    my @elems = split( /\s*($re)\s*/, $text );
    foreach (@elems) {
        $hash{$_} = 1;
    }
    return %hash;

}

=pod

Image calculation code copied from Attach.pm

code fragment to extract pixel size from images
taken from http://www.tardis.ed.ac.uk/~ark/wwwis/
subroutines: _imgsize, _gifsize, _OLDgifsize, _gif_blockskip,
             _NEWgifsize, _jpegsize

=cut

sub _imgsize {
    my ( $file, $att ) = @_;
    my ( $x, $y ) = ( 0, 0 );

    if ( defined($file) ) {
        binmode($file);    # For Windows
        my $s;
        return ( 0, 0 ) unless ( read( $file, $s, 4 ) == 4 );
        seek( $file, 0, 0 );
        if ( $s eq 'GIF8' ) {

            #  GIF 47 49 46 38
            ( $x, $y ) = _gifsize($file);
        }
        else {
            my ( $a, $b, $c, $d ) = unpack( 'C4', $s );
            if (   $a == 0x89
                && $b == 0x50
                && $c == 0x4E
                && $d == 0x47 )
            {

                #  PNG 89 50 4e 47
                ( $x, $y ) = _pngsize($file);
            }
            elsif ($a == 0xFF
                && $b == 0xD8
                && $c == 0xFF
                && $d == 0xE0 )
            {

                #  JPG ff d8 ff e0
                ( $x, $y ) = _jpegsize($file);
            }
        }
        close($file);
    }
    return ( $x, $y );
}

sub _gifsize {
    my ($GIF) = @_;
    if (0) {
        return &_NEWgifsize($GIF);
    }
    else {
        return &_OLDgifsize($GIF);
    }
}

sub _OLDgifsize {
    my ($GIF) = @_;
    my ( $type, $a, $b, $c, $d, $s ) = ( 0, 0, 0, 0, 0, 0 );

    if (   defined($GIF)
        && read( $GIF, $type, 6 )
        && $type =~ /GIF8[7,9]a/
        && read( $GIF, $s, 4 ) == 4 )
    {
        ( $a, $b, $c, $d ) = unpack( 'C' x 4, $s );
        return ( $b << 8 | $a, $d << 8 | $c );
    }
    return ( 0, 0 );
}

# part of _NEWgifsize
sub _gif_blockskip {
    my ( $GIF, $skip, $type ) = @_;
    my ($s)     = 0;
    my ($dummy) = '';

    read( $GIF, $dummy, $skip );    # Skip header (if any)
    while (1) {
        if ( eof($GIF) ) {

            #warn "Invalid/Corrupted GIF (at EOF in GIF $type)\n";
            return '';
        }
        read( $GIF, $s, 1 );        # Block size
        last if ord($s) == 0;       # Block terminator
        read( $GIF, $dummy, ord($s) );    # Skip data
    }
}

# this code by "Daniel V. Klein" <dvk@lonewolf.com>
sub _NEWgifsize {
    my ($GIF) = @_;
    my ( $cmapsize, $a, $b, $c, $d, $e ) = 0;
    my ( $type, $s ) = ( 0, 0 );
    my ( $x,    $y ) = ( 0, 0 );
    my ($dummy) = '';

    return ( $x, $y ) if ( !defined $GIF );

    read( $GIF, $type, 6 );
    if ( $type !~ /GIF8[7,9]a/ || read( $GIF, $s, 7 ) != 7 ) {

        #warn "Invalid/Corrupted GIF (bad header)\n";
        return ( $x, $y );
    }
    ($e) = unpack( "x4 C", $s );
    if ( $e & 0x80 ) {
        $cmapsize = 3 * 2**( ( $e & 0x07 ) + 1 );
        if ( !read( $GIF, $dummy, $cmapsize ) ) {

            #warn "Invalid/Corrupted GIF (global color map too small?)\n";
            return ( $x, $y );
        }
    }
  FINDIMAGE:
    while (1) {
        if ( eof($GIF) ) {

            #warn "Invalid/Corrupted GIF (at EOF w/o Image Descriptors)\n";
            return ( $x, $y );
        }
        read( $GIF, $s, 1 );
        ($e) = unpack( 'C', $s );
        if ( $e == 0x2c ) {    # Image Descriptor (GIF87a, GIF89a 20.c.i)
            if ( read( $GIF, $s, 8 ) != 8 ) {

                #warn "Invalid/Corrupted GIF (missing image header?)\n";
                return ( $x, $y );
            }
            ( $a, $b, $c, $d ) = unpack( "x4 C4", $s );
            $x = $b << 8 | $a;
            $y = $d << 8 | $c;
            return ( $x, $y );
        }
        if ( $type eq 'GIF89a' ) {
            if ( $e == 0x21 ) {    # Extension Introducer (GIF89a 23.c.i)
                read( $GIF, $s, 1 );
                ($e) = unpack( 'C', $s );
                if ( $e == 0xF9 ) { # Graphic Control Extension (GIF89a 23.c.ii)
                    read( $GIF, $dummy, 6 );    # Skip it
                    next FINDIMAGE;    # Look again for Image Descriptor
                }
                elsif ( $e == 0xFE ) {    # Comment Extension (GIF89a 24.c.ii)
                    &_gif_blockskip( $GIF, 0, 'Comment' );
                    next FINDIMAGE;       # Look again for Image Descriptor
                }
                elsif ( $e == 0x01 ) {    # Plain Text Label (GIF89a 25.c.ii)
                    &_gif_blockskip( $GIF, 12, 'text data' );
                    next FINDIMAGE;       # Look again for Image Descriptor
                }
                elsif ( $e == 0xFF )
                {    # Application Extension Label (GIF89a 26.c.ii)
                    &_gif_blockskip( $GIF, 11, 'application data' );
                    next FINDIMAGE;    # Look again for Image Descriptor
                }
                else {

           #printf STDERR "Invalid/Corrupted GIF (Unknown extension %#x)\n", $e;
                    return ( $x, $y );
                }
            }
            else {

                #printf STDERR "Invalid/Corrupted GIF (Unknown code %#x)\n", $e;
                return ( $x, $y );
            }
        }
        else {

            #warn "Invalid/Corrupted GIF (missing GIF87a Image Descriptor)\n";
            return ( $x, $y );
        }
    }
}

# _jpegsize : gets the width and height (in pixels) of a jpeg file
# Andrew Tong, werdna@ugcs.caltech.edu           February 14, 1995
# modified slightly by alex@ed.ac.uk
sub _jpegsize {
    my ($JPEG) = @_;
    my ($done) = 0;
    my ( $c1, $c2, $ch, $s, $length, $dummy ) = ( 0, 0, 0, 0, 0, 0 );
    my ( $a, $b, $c, $d );

    if (   defined($JPEG)
        && read( $JPEG, $c1, 1 )
        && read( $JPEG, $c2, 1 )
        && ord($c1) == 0xFF
        && ord($c2) == 0xD8 )
    {
        while ( ord($ch) != 0xDA && !$done ) {

            # Find next marker (JPEG markers begin with 0xFF)
            # This can hang the program!!
            while ( ord($ch) != 0xFF ) {
                return ( 0, 0 ) unless read( $JPEG, $ch, 1 );
            }

            # JPEG markers can be padded with unlimited 0xFF's
            while ( ord($ch) == 0xFF ) {
                return ( 0, 0 ) unless read( $JPEG, $ch, 1 );
            }

            # Now, $ch contains the value of the marker.
            if ( ( ord($ch) >= 0xC0 ) && ( ord($ch) <= 0xC3 ) ) {
                return ( 0, 0 ) unless read( $JPEG, $dummy, 3 );
                return ( 0, 0 ) unless read( $JPEG, $s,     4 );
                ( $a, $b, $c, $d ) = unpack( 'C' x 4, $s );
                return ( $c << 8 | $d, $a << 8 | $b );
            }
            else {

                # We **MUST** skip variables, since FF's within variable
                # names are NOT valid JPEG markers
                return ( 0, 0 ) unless read( $JPEG, $s, 2 );
                ( $c1, $c2 ) = unpack( 'C' x 2, $s );
                $length = $c1 << 8 | $c2;
                last if ( !defined($length) || $length < 2 );
                read( $JPEG, $dummy, $length - 2 );
            }
        }
    }
    return ( 0, 0 );
}

#  _pngsize : gets the width & height (in pixels) of a png file
#  source: http://www.la-grange.net/2000/05/04-png.html
sub _pngsize {
    my ($PNG)  = @_;
    my ($head) = '';
    my ( $a, $b, $c, $d, $e, $f, $g, $h ) = 0;
    if (   defined($PNG)
        && read( $PNG, $head, 8 ) == 8
        && $head eq "\x89\x50\x4e\x47\x0d\x0a\x1a\x0a"
        && read( $PNG, $head, 4 ) == 4
        && read( $PNG, $head, 4 ) == 4
        && $head eq 'IHDR'
        && read( $PNG, $head, 8 ) == 8 )
    {
        ( $a, $b, $c, $d, $e, $f, $g, $h ) = unpack( 'C' x 8, $head );
        return (
            $a << 24 | $b << 16 | $c << 8 | $d,
            $e << 24 | $f << 16 | $g << 8 | $h
        );
    }
    return ( 0, 0 );
}

1;
