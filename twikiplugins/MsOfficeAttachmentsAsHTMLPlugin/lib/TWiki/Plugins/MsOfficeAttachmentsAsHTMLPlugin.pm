#! perl -w
# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2003 Martin@Cleaver.org
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

# NB. requires a modified version of Store.pm and Func.pm to provide this:
#   beforeAttachmentSaveHandler       ( $attachRefHash, $topic, $web ) 1.010?
# also requires Image::Magick Perl libs and imagemagick installed.
use strict;

# =========================
package TWiki::Plugins::MsOfficeAttachmentsAsHTMLPlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $pluginName
        $debug $xslDoc $replacementNote
    );

# This should always be $Rev: 6827 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 6827 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'MsOfficeAttachmentsAsHTMLPlugin';  # Name of this Plugin

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

    $replacementNote = TWiki::Func::getPreferencesValue("\U$pluginName\E_REPLACEMENTNOTE" )
          || 'This text was automatically generated from the attachment $attachment'
             ."\n".'%INCLUDE{%ATTACHURL%/$convertedAttachmentPath}%'."\n";

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub beforeAttachmentSaveHandler
{
### my ( $attachmentAttr, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead
    my $attachmentAttr = $_[0];
    my $topic = $_[1];
    my $web = $_[2];

    writeDebug( "- ${pluginName}::beforeSaveHandler( $_[2].$_[1])");
    writeDebug("attributes: $attachmentAttr");
    foreach my $attribute (keys %$attachmentAttr) {
       writeDebug("$attribute = ". $attachmentAttr->{$attribute});
    }

    my $attachmentName = $attachmentAttr->{"attachment"};
    writeDebug("Hmm. Got a $attachmentName");

    unless ($attachmentName =~ m/.doc$/) {
      writeDebug("Not converting - this is not a .doc\n");
      return;
    }
   
    writeDebug("Converting $attachmentName");
    eval {
       my $errors = convert($attachmentAttr->{"tmpFilename"}, $attachmentName);
       TWiki::Func::writeWarning("$web.$topic ".$attachmentAttr->{"user"}." ".$errors);
    };
    TWiki::Func::writeWarning("$! $@") if ($@);

    # Now, how do I give the user an error?
    
    # This handler is called by TWiki::Store::saveAttachment just before the save action.
    # New hook in TWiki::Plugins $VERSION = '1.010?'

}

sub writeDebug {
    my ($s) = @_;
    TWiki::Func::writeDebug($s); # if $debug;
}


sub convert { # to HTML
    my ($filename, $attachmentName) = @_;
    my $errors = "";

    my $subdir = "_".$pluginName;
    my $attachdir = TWiki::Func::getPubDir()."/$web/$topic/".$subdir;

    unless (-d $attachdir) {
        mkdir ($attachdir) || writeDebug("Couldn't make $attachdir");
    }

    my $convertedAttachmentFile = $attachmentName.".html";
    my $convertedAttachmentPath = $subdir."/".$convertedAttachmentFile;
    my $cmd = "/usr/bin/wvHtml --targetdir=$attachdir $filename $convertedAttachmentFile";
    writeDebug($cmd);
    my $x = `$cmd 2>&1`;
    writeDebug($x);
#    $errors .= $x;
#	return $x if ($x);
    replaceTextWithIncludeFromAttachment($attachmentName, $convertedAttachmentPath);
    writeDebug("after");
}

sub replaceTextWithIncludeFromAttachment {
    my ($attachmentName, $convertedAttachmentPath) = @_;
    my $oopsUrl = TWiki::Func::setTopicEditLock( $web, $topic, 1 ); 
    if( $oopsUrl ) { 
       my $err = "can't get lock on $web.$topic text\n";
       writeDebug($err);
       return; 
    } 
    my $text = $replacementNote; 
    $text =~ s/\$attachment/$attachmentName/;
    $text =~ s/\$convertedAttachmentPath/$convertedAttachmentPath/;


    $oopsUrl = TWiki::Func::saveTopicText( $web, $topic, $text ); # save topic text 
    TWiki::Func::setTopicEditLock( $web, $topic, 0 );             # unlock topic 
    if( $oopsUrl ) { 
       my $err = "can't unlock on $web.$topic text\n";
       writeDebug("$err - $oopsUrl");
    }
    writeDebug("Ok. writing $web.$topic\n");
    return; 
}    


# This does not work, but is left here for the curious user
sub convertToWikiTML {
    my ($filename, $xslDoc) = @_;
    my $errors = "";
    my $cmd = "/usr/bin/wvWare -x /usr/share/wv/wvXml.xml $filename > /tmp/xml"; #Unsafe
    writeDebug($cmd);
    my $x = `$cmd 2>`;
    writeDebug($x);
    $errors .= $x;
	return $x if ($x);

    my $cmd2 = "/usr/bin/xsltproc $xslDoc /tmp/xml > /tmp/xmlAsWiki.txt";
    writeDebug($cmd2);
    $x = `$cmd2 2>`;
    writeDebug($x);
	return $x if ($x);
    return $errors;
}

# =========================

1;
