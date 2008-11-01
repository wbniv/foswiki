# Plugin for TWiki Collaboration Platform, http://TWiki.org/
# Copyright SvenDowideit@fosiki.com
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

package TWiki::Plugins::GetAWebPlugin;

# Always use strict to enforce variable scoping
use warnings;
use strict;

require TWiki::Func;    # The plugins API
require TWiki::Plugins; # For the API version
use Archive::Tar;

use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC );

$VERSION = '$Rev$';
$RELEASE = 'TWiki-4.2';
$SHORTDESCRIPTION = 'Create a zipped copy of a whole Web for backup or offline reading ';
$NO_PREFS_IN_TOPIC = 1;
$pluginName = 'GetAWebPlugin';

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    TWiki::Func::registerRESTHandler('getaweb', \&getaweb);
    return 1;
}


sub getaweb {
    my ($session) = @_;
   
    my $query = TWiki::Func::getCgiQuery();
    my $error = '';
    my $webName;
    if ($query->path_info() =~ /^.*\/([^\/]*)\.(tar)$/x) {
        $webName = $1;
    } 
    my $outputType = 'application/x-tar';
    my $saveasweb = $query->param('saveasweb' ) || $webName;
    
    $error .= qq{web "$webName" doesn't exist (or you lack permission to see it)<br/>} unless TWiki::Func::webExists( $webName );
    
    # TODO: use oops stuff
    if ( $error ne '' ) 
    {
        print "Content-type: text/html\n\n";
        print $error;
        return;
    }
        
    
    my $tar = Archive::Tar->new() or die $!;
    foreach my $topicName (TWiki::Func::getTopicList($webName))
    {
        #export topic
        my $rawTopic = TWiki::Func::readTopicText( $webName, $topicName);
        next if (!TWiki::Func::checkAccessPermission( 'VIEW', TWiki::Func::getWikiName(), $rawTopic, $topicName, $webName));
        $tar->add_data( "data/$saveasweb/$topicName.txt", $rawTopic );  # or die ???
        #TODO: ,v file (get store obj, then look at its innards :( )
        my $handler = $session->{store}->_getHandler($webName, $topicName);
        $handler->init();
        if (-e $handler->{rcsFile}) {
	    local( $/, *FH ) ;
	    open( FH, '<', $handler->{rcsFile} ) or die $!;
	    my $contents = <FH>;
            $tar->add_data( "data/$saveasweb/$topicName.txt,v", $contents );  # or die ???
        }
        #attachments
        my( $meta, $text ) = TWiki::Func::readTopic($webName, $topicName);
        my @attachments = $meta->find( 'FILEATTACHMENT' );
        foreach my $a ( @attachments ) {
#            try {
                my $data = TWiki::Func::readAttachment($webName, $topicName, $a->{name} );
                $tar->add_data( "pub/$saveasweb/".$a->{name}, $data );  # or die ???
#            } catch TWiki::AccessControlException with {
#            };
            #TODO: ,v file
            my $handler = $session->{store}->_getHandler($webName, $topicName, $a->{name});
            $handler->init();
            if (-e $handler->{rcsFile}) {
                local( $/, *FH ) ;
                open( FH, '<', $handler->{rcsFile} ) or die $!;
                my $contents = <FH>;
                $tar->add_data( "pub/$saveasweb/$topicName/".$a->{name}.",v", $contents );  # or die ???
            }
        }
    }

    # sets response header
    print $query->header(-type=>$outputType, -expire=>'now');
    my $io = IO::Handle->new() or die $!;
    $io->fdopen(fileno(STDOUT), "w") or die $!;
    $tar->write( $io ) or die $!;
    $io->close();
   
   return;
}

1;
