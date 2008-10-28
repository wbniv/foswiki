                         ###### ALBUM OF SNAPS PLGUIN #########
                         #####################################

#################################################################################################
# CONTRIBUTED TO TWIKI WORLD BY   Naval Bhandari and Ashish Khurange
# Date of Completion : 02/11/2004
# Version number     : 1.000
# Email id           : naval@it.iitb.ac.in  , ashishk@it.iitb.ac.in
# Web Site           : http://www.it.iitb.ac.in/~naval    ,   http://www.it.iitb.ac.in/~ashishk

#################################################################################################
#
# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
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
#
# This is an empty TWiki plugin. Use it as a template
# for your own plugins; see TWiki.TWikiPlugins for details.
#
# Each plugin is a package that may contain these functions:        VERSION:
#
#   initPlugin              ( $topic, $web, $user, $installWeb )    1.000
#   initializeUserHandler   ( $loginName, $url, $pathInfo )         1.010
#   registrationHandler     ( $web, $wikiName, $loginName )         1.010
#   commonTagsHandler       ( $text, $topic, $web )                 1.000
#   startRenderingHandler   ( $text, $web )                         1.000
#   outsidePREHandler       ( $text )                               1.000
#   insidePREHandler        ( $text )                               1.000
#   endRenderingHandler     ( $text )                               1.000
#   beforeEditHandler       ( $text, $topic, $web )                 1.010
#   afterEditHandler        ( $text, $topic, $web )                 1.010
#   beforeSaveHandler       ( $text, $topic, $web )                 1.010
#   writeHeaderHandler      ( $query )                              1.010  Use only in one Plugin
#   redirectCgiQueryHandler ( $query, $url )                        1.010  Use only in one Plugin
#   getSessionValueHandler  ( $key )                                1.010  Use only in one Plugin
#   setSessionValueHandler  ( $key, $value )                        1.010  Use only in one Plugin
#
# initPlugin is required, all other are optional. 
# For increased performance, all handlers except initPlugin are
# disabled. To enable a handler remove the leading DISABLE_ from
# the function name. Remove disabled handlers you do not need.
#
# NOTE: To interact with TWiki use the official TWiki functions 
# in the TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!


   # =========================
# SPECIFYING THE NAME OF PACKAGE

   package TWiki::Plugins::AlbumOfSnapsPlugin;    

# =========================
#Following are the  plugin specific variable

  use vars qw( 
                $web $topic $user $installWeb $VERSION $RELEASE $debug @dir_array_list @filename_array $first $last $name @counter_array $imagedir $filename $dirname $menu $width $height $script $str  $zip_files $test $scriptpath $pagepath
    );

# Following variable contains the version of our plugin 
# This should always be $Rev: 6827 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 6827 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';


# Default debug option
  $debug = 1;

# Following variable will contanthe list of all the album directories
  @dir_array_list = ("");

# Following variable will contain the list of files in that particular directory
  @filename_array = ("");

# Following vairabl will contain the number of times image is seen
  @counter_array = ("");

#  $width;
#  $height;


#============================================================================================== =========================
# Following is the first subroutine called in our plugin .
  sub initPlugin
  {

  # Getting the various information regarding environment i.e. topic name ,web name , user name 
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions which is the Plugin which load all other plugins.

    if( $TWiki::Plugins::VERSION < 1 ) 
        {
           &TWiki::Func::writeWarning( "Version mismatch between AlbumOfSnapsPlugin and Plugins.pm" );
           return 0;
        }
   
     # Getting the path of current topic.
      $pagepath = &TWiki::Func::getViewUrl($web,$topic);
   	
    $debug= &TWiki::Func::getPreferencesFlag("ALBUMOFSNAPSPLUGIN_DEBUG");    
    # Plugin correctly initialized
    &TWiki::Func::writeDebug( "- TWiki::Plugins:AlbumOfSnapsPlugin::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
   }

# ==============================================================================================================
# AFTER initPlugin sub routine  , Following sub routine is scalled
  sub commonTagsHandler
   {

    # Replace the plugin tag with the return string of the handleTag Function
    $_[0] =~ s/%ALBUMOFSNAPS_PLUGIN%/&_handleTag( )/geo;	
    $_[0] =~ s/%ALBUMOFSNAPS_PLUGIN{(.*?)}%/&_handleTag( $1 )/geo;	

  }

# This function returns the output of the plugin at the poine where the tag is specified
sub _handleTag()
{
	my ( $attributes ) = @_;
        
        # Retrieving the values of the parameters specified in the tag or assigning defalut values.
      
	$topic = scalar &TWiki::Func::extractNameValuePair( $attributes, "topic" ) || $TWiki::topicName;
	$web   = scalar &TWiki::Func::extractNameValuePair( $attributes, "web" ) || $TWiki::webName;

        # $name variable will contain the url path of   topic where the Album directories are stored.
	$name = &TWiki::Func::getPubUrlPath() . "/$web/$topic/"; 

        # $script variabe will contain the url of our script.
 	$script= &TWiki::Func::getScriptUrl()."AlbumOfSnapsScript";

        # $abspath will contain the absolute path of the directory where the Album directories are stored
	$abspath = &TWiki::Func::getPubDir() . "/$web/$topic/"; 
    
        # $menu will containthe path where various images/backgrounds used inplugin are stored
	$menu= &TWiki::Func::getScriptUrlPath( ); 
	$menu=~s/\/[^\/]*$//;
	$menu=$menu."/lib/TWiki/Plugins/AlbumOfSnapsPluginImages";
	chdir($abspath);
	$imagedir=$name;
        
        # Following function will contain the code for extracting the directories from zip file and rename them
	update_file_list();

        # Following functionwill display various Album directories
	show_dir();
	return $str;
}

# This function will check various directories and files present in the topic directory. and do the required modifications if contents are changed.

sub update_file_list ()
{
	extract_from_archive();		# extract the archive files.

	foreach $dirname (`find -type d -maxdepth 1`)	# get names of all the directories.
     	  {
		chop ($dirname);
		if ($dirname ne ".")
		{
			push (@dir_array_list, substr($dirname, 2));
           	}
	  }
}

# Following function extract the image directory from compressed file and rename it with the proper notation.

sub extract_from_archive()
{                                    
	my $archive_file;
	my @archive_array=("");
	
	open (OUTFILE, ">archive_files");
                                                                                                                            
	foreach $archive_file (`find -name \"*.tgz\" -maxdepth 1`)	# get all .tgz files.
	{
		@dir = `find -type d`;

		if (@dir == 1)
		{
			$number = 0;
			$album = "Album";
		}

		else
		{
			$name = `ls -td */ | head -n 1`;
			($album, $number, $string) = split (/_/, $name);
			$number = $number + 1;
			$album = "Album";
		}

		$tmp = substr($archive_file, 2);
		chop ($tmp);
		print OUTFILE "tar -xzvf ".$tmp.";\n";

		($final) = split (/.tgz/, $tmp);
		$next = $album."_".$number."_".$final;	# create next directory name.
	
		print OUTFILE "mv ".$final." ".$next.";\n";
		print OUTFILE "touch ".$next.";\n";
		print OUTFILE "rm ".$archive_file.";\n";
	}
     
	foreach $archive_file (`find -name \"*.tar\" -maxdepth 1`)	# get all .tar file.
	{
		@dir = `find -type d`;

		if (@dir == 1)
		{
			$number = 0;
			$album = "Album";
		}

		else
		{
			$name = `ls -td */ | head -n 1`;
			($album, $number, $string) = split (/_/, $name);
			$number = $number + 1;
			$album = "Album";
		}

		$tmp = substr($archive_file, 2);
		chop ($tmp);
		print OUTFILE "tar -xvf ".$tmp.";\n";

		($final) = split (/.tar/, $tmp);
		$next = $album."_".$number."_".$final;
	
		print OUTFILE "mv ".$final." ".$next.";\n";
		print OUTFILE "touch ".$next.";\n";
		print OUTFILE "rm ".$archive_file.";\n";
	}

	foreach $archive_file (`find -name \"*.zip\" -maxdepth 1`)	# get all .zip file.
	{
		@dir = `find -type d`;

		if (@dir == 1)
		{
			$number = 0;
			$album = "Album";
		}

		else
		{
			$name = `ls -td */ | head -n 1`;
			($album, $number, $string) = split (/_/, $name);
			$number = $number + 1;
			$album = "Album";
		}

		$tmp = substr($archive_file, 2);
		chop ($tmp);
		print OUTFILE "unzip ".$tmp.";\n";

		($final) = split (/.zip/, $tmp);
		$next = $album."_".$number."_".$final;
	
		print OUTFILE "mv ".$final." ".$next.";\n";
		print OUTFILE "touch ".$next.";\n";
		print OUTFILE "rm ".$archive_file.";\n";
	}

	close (OUTFILE);
                                                                                                               
	`chmod u+x archive_files`;
	`./archive_files`;
	`chmod 777 * `; 
	`rm archive_files`;
                                                                                                                  
}


# Following functiondisplays various album directories present in topic directory.

sub show_dir()
{
	$first = 1 ;
	$last = @dir_array_list;
	$str=$str."<html><body background=\"$menu/marb157.jpg\" ><h1><center> Album Of Snaps </center></h1> <center><table  border=\"0\" cellpadding=\"20\" cellspacing=\"0\" >
	<tr background=\"$menu/marb157.jpg\">
	<center>";

#*************************
	for ($i=$first; $i<$last; $i++)
	{
		if ($i%5 == 0)
		{
			$str=$str."</tr><tr>";
		}
		$str=$str."<td>$dir_array_list[$i] <a href=\"$script?prev=$pagepath;script=$script;abspath=$abspath;menu=$menu;relurl=$imagedir;dir=$dir_array_list[$i]\"><img src=\"$menu/album.gif \" width=100 height=100 alt=\"$dir_array_list[$i]\" / ><br>$dir_array_list[$i] </a> </td>\n";
	}
	
#***********************************888
	$str=$str."</table></center></body></html>";
	
}

1;
