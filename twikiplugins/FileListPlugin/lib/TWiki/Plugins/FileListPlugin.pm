# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# v0.6 initial release - TWiki:Main.VinodKulkarni, Apr 2005
# v0.7 reworked for TWiki 4 - TWiki:Main.SopanShewale, Feb 2006
# v0.8 reworked for TWiki 4.1 and optimized - TWiki:Main.ArthurClemens, Dec 2006
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


package TWiki::Plugins::FileListPlugin;

use strict;


use vars qw($VERSION $RELEASE $web $topic $user $installWeb $pluginName
        $debug $renderingWeb $defaultFormat
    );

# This should always be $Rev: 14207 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 14207 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = '0.9';

$pluginName = 'FileListPlugin';  # Name of this Plugin


sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
		TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
		return 0;
    }

	my $notSpecifiedFormat = '   * [[$fileUrl][$fileName]] $fileComment';
	
    # Get plugin preferences
    $defaultFormat = TWiki::Func::getPreferencesValue( 'FORMAT' ) || TWiki::Func::getPluginPreferencesValue( 'FORMAT' ) || $notSpecifiedFormat;

    # Get plugin debug flag
    $debug = TWiki::Func::getPluginPreferencesFlag( "DEBUG" );

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}


sub _handleFileList 
{
	my ($args, $theWeb, $theTopic) = @_;
	my %params = TWiki::Func::extractParameters($args);
	
	my $thisWeb = $params{'web'} || $theWeb || '';
	my $thisTopic = $params{'topic'} || $theTopic || '';
	
	my $format  = $params{'format'} || $defaultFormat;
	my $header  = $params{'header'} || '';
	my $footer  = $params{'footer'} || '';
	my $alttext = $params{'alt'}    || '';
	
	my $filter = $params{"filter"}; # "abc, def" syntax. Substring match will be used
	my $hideHidden = (grep { $_ eq $params{"hide"} } ('on', 'yes', '1')) ? 1 : 0; # don't hide by default
	
	 # check if the user has permissions to view the topic
	my $user = TWiki::Func::getWikiName();
	my $wikiUserName = TWiki::Func::userToWikiName($user, 1);
	if ( ! TWiki::Func::checkAccessPermission( 'VIEW', $wikiUserName, undef, $thisTopic, $thisWeb ) ) {
		return '';
	}

	my ($meta, $text) = TWiki::Func::readTopic($thisWeb, $thisTopic);
	my $outtext=""; 

	# Make sure filter string is valid.
	if ( $filter ) {
		# Convert it into regexp to search files against.
		# "abc, bcd" => (abc)|(bcd)
		$filter =~ s/\s*([\w\._\-\+\s]*)\s*,/($1)|/g  ;
		$filter =~ s/\s*([\w\._\-\+\s]*)\s*$/($1)/;
	}
	# store once for reuse in loop
	my $pubUrl = TWiki::Func::getUrlHost() . TWiki::Func::getPubUrlPath();

	my @attachments = $meta->find( "FILEATTACHMENT" );
	
	foreach my $attachment ( @attachments ) {
		my $file=$attachment->{name};
		next if ( $filter && ! ($file =~ m/$filter/) );
		
		my $attrSize = $attachment->{size};
		my $attrUser = $attachment->{user};
		my $attrComment = $attachment->{comment};
		my $attrAttr = $attachment->{attr};

		# skip if the attachment is hidden
		next if ($attrAttr =~ /h/i && $hideHidden);
		
		# I18N: To support attachments via UTF-8 URLs to attachment
		# directories/files that use non-UTF-8 character sets, go through viewfile. 
		# If using %PUBURL%, must URL-encode explicitly to site character set.
		
		# Go direct to file where possible, for efficiency
		# TODO: more flexible size formatting
		# also take MB into account
		my $attrSizeStr;
		$attrSizeStr = $attrSize.'b' if ( $attrSize < 100 );
		$attrSizeStr = sprintf( "%1.1fK", $attrSize / 1024 ) if ( $attrSize >= 100 );
		$attrComment = $attrComment || "";
		my $s = "$format";
		$s =~ s/\$fileName/$file/g;
    
		if ( $s=~/fileIcon/ ) {
			## To find the File Extention..
			my @bits = (split(/\./, $file));
			my $ext =  lc $bits[$#bits];  
			my $fileIcon = '%ICON{"'.$ext.'"}%';
			$s =~ s/\$fileIcon/$fileIcon/g; 
		}
		$s =~ s/\$fileSize/$attrSizeStr/g; 
		$s =~ s/\$fileComment/$attrComment/g;
		if ( $s=~/fileDate/ ) {
			my $attrDate = TWiki::Time::formatTime($attachment->{"date"});
			$s =~ s/\$fileDate/$attrDate/g;
		}
		$s =~ s/\$fileUser/$attrUser/g; 
		$s =~ s/\$n/\n/g; 
		$s =~ s/\$br/\<br \/\>/g; 

		if ( $s=~/fileActionUrl/ ) {
			my $fileActionUrl = TWiki::Func::getScriptUrl($thisWeb, $thisTopic, "attach") . "?filename=$file&revInfo=1";
			$s =~ s/\$fileActionUrl/$fileActionUrl/; 
		}
	
		if ( $s=~/viewfileUrl/ ) {
			my $attrVersion=$attachment->{Version};
			my $viewfileUrl = TWiki::Func::getScriptUrl($thisWeb, $thisTopic, "viewfile") . "?rev=$attrVersion&filename=$file";
			$s =~ s/\$viewfileUrl/$viewfileUrl/; 
		}
		
		if ( $s =~ /\$hidden/ ) {
			my $hidden = ( $attrAttr =~ /h/i ) ? 'hidden' : '';
			$s =~ s/\$hidden/$hidden/g;
		}
	
		my $fileUrl = $pubUrl . "/$thisWeb/$thisTopic/$file";
		$s =~ s/\$fileUrl/$fileUrl/;
    
		$outtext .= $s . "\n";
	}
	
	if ( $outtext eq "" ) {
		$outtext = $alttext;
	} else {
		$outtext = $header . "\n" . $outtext . $footer;
	}
	
	return $outtext;
}


sub commonTagsHandler
{
	TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;
	
	# This is the place to define customized tags and variables
	# Called by TWiki::handleCommonTags, after %INCLUDE:"..."%
	
	$_[0] =~ s/%FILELIST%/&_handleFileList($defaultFormat, $web, $topic)/ge;
	$_[0] =~ s/%FILELIST{(.*?)}%/&_handleFileList($1, $web, $topic)/ge;
}

1;
