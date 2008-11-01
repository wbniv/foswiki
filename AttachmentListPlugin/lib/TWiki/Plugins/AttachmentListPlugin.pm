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

package TWiki::Plugins::AttachmentListPlugin;

use strict;
use TWiki::Func;
use TWiki::Plugins::AttachmentListPlugin::FileData;
use TWiki::Plugins::TopicDataHelperPlugin;

use vars qw($VERSION $RELEASE $pluginName
  $debug $defaultFormat $imageFormat
);

my %sortInputTable = (
    'none' => $TWiki::Plugins::TopicDataHelperPlugin::sortDirections{'NONE'},
    'ascending' =>
      $TWiki::Plugins::TopicDataHelperPlugin::sortDirections{'ASCENDING'},
    'descending' =>
      $TWiki::Plugins::TopicDataHelperPlugin::sortDirections{'DESCENDING'},
);

# This should always be $Rev: 14207 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 14207 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = '1.3';

$pluginName = 'AttachmentListPlugin';

=pod

=cut

sub initPlugin {
    my ( $inTopic, $inWeb, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    $defaultFormat = '   * [[$fileUrl][$fileName]] $fileComment';

    # Get plugin preferences
    $defaultFormat =
         TWiki::Func::getPreferencesValue('FORMAT')
      || TWiki::Func::getPluginPreferencesValue('FORMAT')
      || $defaultFormat;

    $defaultFormat =~ s/^[\\n]+//;    # Strip off leading \n

    $imageFormat = '<img src=\'$fileUrl\' alt=\'$fileComment\' />';

    # Get plugin preferences
    $imageFormat =
         TWiki::Func::getPreferencesValue('IMAGE_FORMAT')
      || TWiki::Func::getPluginPreferencesValue('IMAGE_FORMAT')
      || $imageFormat;

    $imageFormat =~ s/^[\\n]+//;      # Strip off leading \n

    # Get plugin debug flag
    $debug = TWiki::Func::getPluginPreferencesFlag("DEBUG");

    TWiki::Func::registerTagHandler( 'FILELIST', \&_handleFileList )
      ;                               #deprecated
    TWiki::Func::registerTagHandler( 'ATTACHMENTLIST', \&_handleFileList );

    # Plugin correctly initialized
    TWiki::Func::writeDebug(
        "- TWiki::Plugins::${pluginName}::initPlugin( $inWeb.$inTopic ) is OK")
      if $debug;

    return 1;
}

=pod

=cut

sub _handleFileList {
    my ( $inSession, $inParams, $inTopic, $inWeb ) = @_;

    my $webs   = $inParams->{'web'}   || $inWeb   || '';
    my $topics = $inParams->{'topic'} || $inTopic || '';
    my $excludeTopics = $inParams->{'excludetopic'} || '';
    my $excludeWebs   = $inParams->{'excludeweb'}   || '';

    # find all attachments except for excluded topics
    my $topicData =
      TWiki::Plugins::TopicDataHelperPlugin::createTopicData( $webs,
        $excludeWebs, $topics, $excludeTopics );

    # populate with attachment data
    TWiki::Plugins::TopicDataHelperPlugin::insertObjectData( $topicData,
        \&_createFileData );

    _filterTopicData( $topicData, $inParams );

    my $files =
      TWiki::Plugins::TopicDataHelperPlugin::getListOfObjectData($topicData);

    # sort
    $files = _sortFiles( $files, $inParams ) if defined $inParams->{'sort'};

    # limit files if param limit is defined
    splice @$files, $inParams->{'limit'}
      if defined $inParams->{'limit'};

    # format
    my $formatted = _formatFileData( $inSession, $files, $inParams );

    return $formatted;
}

=pod

Goes through the webs and topics in $inTopicData, finds the listed attachments for each topic and creates a FileData object.
Removes the topics keys in $inTopicData if the topic does not have META:FILEATTACHMENT data.
Assigns FileData objects to the $inTopicData hash using this structure:

%topicData = (
	Web1 => {
		Topic1 => {
			picture.jpg => FileData object 1,
			me.PNG => FileData object 2,		
			...
		},
	},
)

=pod

=cut

sub _createFileData {
    my ( $inTopicHash, $inWeb, $inTopic ) = @_;

    # define value for topic key only if topic
    # has META:FILEATTACHMENT data
    my $attachments = _getAttachmentsInTopic( $inWeb, $inTopic );

    if ( scalar @$attachments ) {
        $inTopicHash->{$inTopic} = ();

        foreach my $attachment (@$attachments) {
            my $fd =
              TWiki::Plugins::AttachmentListPlugin::FileData->new( $inWeb,
                $inTopic, $attachment );
            my $fileName = $fd->{name};
            $inTopicHash->{$inTopic}{$fileName} = \$fd;
        }
    }
    else {

        # no META:FILEATTACHMENT, so remove from hash
        delete $inTopicHash->{$inTopic};
    }
}

=pod

Filters topic data references in the $inTopicData hash.
Called function remove topic data references in the hash.

=cut

sub _filterTopicData {
    my ( $inTopicData, $inParams ) = @_;
    my %topicData = %$inTopicData;

    # ----------------------------------------------------
    # filter topics by view permission
    my $user = TWiki::Func::getWikiName();
    my $wikiUserName = TWiki::Func::userToWikiName( $user, 1 );
    TWiki::Plugins::TopicDataHelperPlugin::filterTopicDataByViewPermission(
        \%topicData, $wikiUserName );

    # ----------------------------------------------------
    # filter hidden attachments
    my $hideHidden = TWiki::Func::isTrue( $inParams->{'hide'} );
    if ($hideHidden) {
        TWiki::Plugins::TopicDataHelperPlugin::filterTopicDataByProperty(
            \%topicData, 'hidden', 1, undef, 'hidden' );
    }

    # ----------------------------------------------------
    # filter attachments by user
    if ( defined $inParams->{'user'} || defined $inParams->{'excludeuser'} ) {
        TWiki::Plugins::TopicDataHelperPlugin::filterTopicDataByProperty(
            \%topicData, 'user', 1, $inParams->{'user'},
            $inParams->{'excludeuser'} );
    }

    # ----------------------------------------------------
    # filter attachments by date range
    if ( defined $inParams->{'fromdate'} || defined $inParams->{'todate'} ) {
        TWiki::Plugins::TopicDataHelperPlugin::filterTopicDataByDateRange(
            \%topicData, $inParams->{'fromdate'},
            $inParams->{'todate'} );
    }

    # ----------------------------------------------------
    # filter included/excluded filenames
    if (   defined $inParams->{'file'}
        || defined $inParams->{'excludefile'} )
    {
        TWiki::Plugins::TopicDataHelperPlugin::filterTopicDataByProperty(
            \%topicData, 'name', 1, $inParams->{'file'},
            $inParams->{'excludefile'} );
    }
    
    # filter filenames by regular expression
    if (   defined $inParams->{'includefilepattern'}
        || defined $inParams->{'excludefilepattern'} )
    {
        TWiki::Plugins::TopicDataHelperPlugin::filterTopicDataByRegexMatch(
            \%topicData, 'name',
            $inParams->{'includefilepattern'},
            $inParams->{'excludefilepattern'}
        );
    }

    # ----------------------------------------------------
    # filter by extension
    my $extensions =
         $inParams->{'extension'}
      || $inParams->{'filter'}
      || undef;    # "abc, def" syntax. Substring match will be used
                   # param 'filter' is deprecated
    my $excludeExtensions = $inParams->{'excludeextension'} || undef;
    if ( defined $extensions || defined $excludeExtensions ) {
        TWiki::Plugins::TopicDataHelperPlugin::filterTopicDataByProperty(
            \%topicData, 'extension', 0, $extensions, $excludeExtensions );
    }

}

=pod

=cut

sub _sortFiles {
    my ( $inFiles, $inParams ) = @_;

    my $files = $inFiles;

    # get the sort key for the $inSortMode
    my $sortKey =
      &TWiki::Plugins::AttachmentListPlugin::FileData::getSortKey(
        $inParams->{'sort'} );
    my $compareMode =
      &TWiki::Plugins::AttachmentListPlugin::FileData::getCompareMode(
        $inParams->{'sort'} );

    # translate input to sort parameters
    my $sortOrderParam = $inParams->{'sortorder'} || 'none';
    my $sortOrder = $sortInputTable{$sortOrderParam}
      || $TWiki::Plugins::TopicDataHelperPlugin::sortDirections{'NONE'};

    # set default sort order for sort modes
    if ( $sortOrder ==
        $TWiki::Plugins::TopicDataHelperPlugin::sortDirections{'NONE'} )
    {
        if ( defined $sortKey && $sortKey eq 'date' ) {

            # exception for dates: newest on top
            $sortOrder = $TWiki::Plugins::TopicDataHelperPlugin::sortDirections{
                'DESCENDING'};
        }
        else {

            # otherwise sort by default ascending
            $sortOrder = $TWiki::Plugins::TopicDataHelperPlugin::sortDirections{
                'ASCENDING'};
        }
    }
    $sortOrder = -$sortOrder
      if ( $sortOrderParam eq 'reverse' );

    $files =
      TWiki::Plugins::TopicDataHelperPlugin::sortObjectData( $files, $sortOrder,
        $sortKey, $compareMode, 'name' )
      if defined $sortKey;

    return $files;
}

=pod

Returns an array of FILEATTACHMENT objects.

=cut

sub _getAttachmentsInTopic {
    my ( $inWeb, $inTopic ) = @_;

    my ( $meta, $text ) = TWiki::Func::readTopic( $inWeb, $inTopic );
    my @fileAttachmentData = $meta->find("FILEATTACHMENT");
    return \@fileAttachmentData;
}

=pod

=cut

sub _formatFileData {
    my ( $inSession, $inFiles, $inParams ) = @_;

    my @files = @$inFiles;

    # formatting parameters
    my $format    = $inParams->{'format'}    || $defaultFormat;
    my $header    = $inParams->{'header'}    || '';
    my $footer    = $inParams->{'footer'}    || '';
    my $alttext   = $inParams->{'alt'}       || '';
    my $separator = $inParams->{'separator'} || "\n";

    # store once for re-use in loop
    my $pubUrl = TWiki::Func::getUrlHost() . TWiki::Func::getPubUrlPath();

    my %listedExtensions =
      ();    # store list of extensions to be used for format substitution

    my @formattedData = ();

    foreach my $fileData (@files) {

        my $attrComment = $fileData->{attachment}->{comment} || '';
        my $attrAttr = $fileData->{attachment}->{attr};

        # keep track of listed file extensions
        my $fileExtension = $fileData->{extension};
        $fileExtension = ''
          if $fileExtension eq
              'none';    # do not use the extension placeholder for formatting
        $listedExtensions{$fileExtension} = 1
          if ($fileExtension)
          ;   # add current attachment extension for display for $fileExtensions

        my $s = "$format";

        # Go direct to file where possible, for efficiency
        # TODO: more flexible size formatting
        # also take MB into account
        my $attrSizeStr = '';
        $attrSizeStr = $fileData->{size};
        $attrSizeStr .= 'b'
          if ( $fileData->{size} > 0 && $fileData->{size} < 100 );
        $attrSizeStr = sprintf( "%1.1fK", $fileData->{size} / 1024 )
          if ( $fileData->{size} && $fileData->{size} >= 100 );

        $s =~ s/\$imgTag/$imageFormat/;    # imageFormat is a preference value

        if ( $s =~ m/imgHeight/ || $s =~ m/imgWidth/ ) {

            my ( $imgWidth, $imgHeight ) =
              _retrieveImageSize( $inSession, $fileData );
            $s =~ s/\$imgWidth/$imgWidth/g   if defined $imgWidth;
            $s =~ s/\$imgHeight/$imgHeight/g if defined $imgHeight;
        }

        $s =~ s/\$fileName/$fileData->{name}/g;
        $s =~ s/\$fileIcon/%ICON{"$fileExtension"}%/g;
        $s =~ s/\$fileSize/$attrSizeStr/g;
        $s =~ s/\$fileComment/$attrComment/g;
        $s =~ s/\$fileExtension/$fileExtension/g;
        $s =~ s/\$fileDate/_formatDate($fileData->{date})/ge;
        $s =~ s/\$fileUser/$fileData->{user}/g;

        if ( $s =~ m/\$fileActionUrl/ ) {
            my $fileActionUrl =
              TWiki::Func::getScriptUrl( $fileData->{web}, $fileData->{topic},
                "attach" )
              . "?filename=$fileData->{name}&revInfo=1";
            $s =~ s/\$fileActionUrl/$fileActionUrl/g;
        }

        if ( $s =~ m/\$viewfileUrl/ ) {
            my $attrVersion = $fileData->{attachment}->{Version} || '';
            my $viewfileUrl =
              TWiki::Func::getScriptUrl( $fileData->{web}, $fileData->{topic},
                "viewfile" )
              . "?rev=$attrVersion&filename=$fileData->{name}";
            $s =~ s/\$viewfileUrl/$viewfileUrl/g;
        }

        if ( $s =~ m/\$hidden/ ) {
            my $hiddenStr = $fileData->{hidden} ? 'hidden' : '';
            $s =~ s/\$hidden/$hiddenStr/g;
        }

        my $webEnc = $fileData->{web};
        $webEnc =~ s/([^-_.a-zA-Z0-9])/sprintf("%%%02x",ord($1))/eg;
        my $topicEnc = $fileData->{topic};
        $topicEnc =~ s/([^-_.a-zA-Z0-9])/sprintf("%%%02x",ord($1))/eg;
        my $fileEnc = $fileData->{name};
        $fileEnc =~ s/([^-_.a-zA-Z0-9])/sprintf("%%%02x",ord($1))/eg;
        my $fileUrl = "$pubUrl/$webEnc/$topicEnc/$fileEnc";

        $s =~ s/\$fileUrl/$fileUrl/g;
        $s =~ s/\$fileTopic/$fileData->{topic}/g;
        $s =~ s/\$fileWeb/$fileData->{web}/g;

        push @formattedData, $s;
    }

    my $outText = join $separator, @formattedData;

    if ( $outText eq '' ) {
        $outText = $alttext;
    }
    else {
        $header =~ s/(.+)/$1\n/;    # add newline if text
        $footer =~ s/(.+)/\n$1/;    # add newline if text
                                    # fileCount format param
        my $count = scalar @files;
        $header =~ s/\$fileCount/$count/g;
        $footer =~ s/\$fileCount/$count/g;

        # fileExtensions format param
        my @extensionsList = sort ( keys %listedExtensions );
        my $listedExtensions = join( ',', @extensionsList );
        $header =~ s/\$fileExtensions/$listedExtensions/g;
        $footer =~ s/\$fileExtensions/$listedExtensions/g;

        $outText = "$header$outText$footer";
    }
    $outText = _decodeFormatTokens($outText);
    $outText =~ s/\$br/\<br \/\>/g;
    return $outText;
}

=pod

Formats $epoch seconds to the date-time format specified in configure.

=cut

sub _formatDate {
    my ($inEpoch) = @_;

    return TWiki::Func::formatTime(
        $inEpoch,
        $TWiki::cfg{DefaultDateFormat},
        $TWiki::cfg{DisplayTimeValues}
    );
}

=pod

=cut

sub _retrieveImageSize {
    my ( $inSession, $inFileData ) = @_;

    my $imgWidth  = undef;
    my $imgHeight = undef;

    # try to read image size
    my $store = $inSession->{store};

    my $attachmentExists =
      $store->attachmentExists( $inFileData->{web}, $inFileData->{topic},
        $inFileData->{name} );
    if ($attachmentExists) {
        my $user         = TWiki::Func::getWikiName();
        my $wikiUserName = TWiki::Func::userToWikiName( $user, 1 );
        my $stream       = $store->getAttachmentStream(
            $wikiUserName,        $inFileData->{web},
            $inFileData->{topic}, $inFileData->{name}
        );
        if ($stream) {
            ( $imgWidth, $imgHeight ) =
              &_imgsize( $stream, $inFileData->{name} );
        }
    }
    return ( $imgWidth, $imgHeight );
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

=pod

=cut

sub _decodeFormatTokens {
    my $text = shift;
    return
      defined(&TWiki::Func::decodeFormatTokens)
      ? TWiki::Func::decodeFormatTokens($text)
      : _expandStandardEscapes($text);
}

=pod

For TWiki versions that do not implement TWiki::Func::decodeFormatTokens.

=cut

sub _expandStandardEscapes {
    my $text = shift;
    $text =~ s/\$n\(\)/\n/gos;    # expand '$n()' to new line
    my $alpha = TWiki::Func::getRegularExpression('mixedAlpha');
    $text =~ s/\$n([^$alpha]|$)/\n$1/gos;    # expand '$n' to new line
    $text =~ s/\$nop(\(\))?//gos;      # remove filler, useful for nested search
    $text =~ s/\$quot(\(\))?/\"/gos;   # expand double quote
    $text =~ s/\$percnt(\(\))?/\%/gos; # expand percent
    $text =~ s/\$dollar(\(\))?/\$/gos; # expand dollar
    return $text;
}

1;
