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
# for your own plugins; see %SYSTEMWEB%.Plugins for details.
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
package TWiki::Plugins::CounterPlugin;    # change the package name and $pluginName!!!

# =========================
#This is plugin specific variable
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $debug 
    );

# This should always be $Rev: 7918 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 7918 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$debug = 1;

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning( "Version mismatch between CounterPlugin and Plugins.pm" );
        return 0;
    }
   	
    # Plugin correctly initialized
    &TWiki::Func::writeDebug( "- TWiki::Plugins:CounterPlugin::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub commonTagsHandler
{
    $_[0] =~ s/%COUNTER_PLUGIN%/_handleTag( )/geo;	
}

#-------------------------------------------------------------------------------------------------

sub _handleTag()
{
	# increment the counter and throw up the page with this count
	my $FileLocation = &TWiki::Func::getWorkArea( 'CounterPlugin' );
	my $DataFile = 'visitor_count.txt';
	my $CounterFile = "$FileLocation/$DataFile";
    	&TWiki::Func::writeDebug( "- TWiki::Plugins:CounterPlugin::FileLocation is $FileLocation" );
	
	if ( open(FILE , '<', $CounterFile) )
	{
	    &TWiki::Func::writeDebug("Opened $DataFile file successfully");
	    $Count = <FILE>;
	    close FILE;
	}
	else
	{
	    # File doesn't exist
	    $Count = 0;
	}
	
	open(FILE, '>', $CounterFile) || die "Can't open $DataFile file";
	++$Count;
	print FILE $Count;
	close FILE;
	
	return $Count;
}

1;
