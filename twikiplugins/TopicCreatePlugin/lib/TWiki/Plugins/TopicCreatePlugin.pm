# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005-2006 Peter Thoeny, peter@thoeny.org
#
# For licensing info read LICENSE file in the TWiki root.
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
# As per the GPL, removal of this notice is prohibited.

package TWiki::Plugins::TopicCreatePlugin;


# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $debug $doInit
    );

$VERSION = '1.000';  # 30 Apr 2005
$doInit = 0;

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning( "Version mismatch between TopicCreatePlugin and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag( "TOPICCREATEPLUGIN_DEBUG" );
#REMOVE THIS:
##$debug=1;

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::TopicCreatePlugin::initPlugin( $web.$topic ) is OK" ) if $debug;
    $doInit = 1;
    return 1;
}

# =========================
sub beforeSaveHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- TopicCreatePlugin::beforeSaveHandler( $_[2].$_[1] )" ) if $debug;

    unless( $_[0] =~ /%TOPIC(CREATE|ATTACH)\{.*?\}%/ ) {
        # nothing to do
        return;
    }

    require TWiki::Plugins::TopicCreatePlugin::Func;

    if( $doInit ) {
        $doInit = 0;
        TWiki::Plugins::TopicCreatePlugin::Func::init( $web, $topic, $user, $debug );
    }

    $_[0] =~ s/%TOPICCREATE{(.*)}%[\n\r]*/TWiki::Plugins::TopicCreatePlugin::Func::handleTopicCreate($1, $_[2], $_[1], $_[0] )/geo;

    # To be tested and documented
    # $_[0] =~ s/%TOPICPATCH{(.*)}%[\n\r]*/TWiki::Plugins::TopicCreatePlugin::Func::handleTopicPatch($1, $_[2], $_[1], $_[0] )/geo;

    if ($_[0] =~ /%TOPICATTACH/){
        my @attachMetaData = ();
        $_[0] =~ s/%TOPICATTACH{(.*)}%[\n\r]*/TWiki::Plugins::TopicCreatePlugin::Func::handleTopicAttach($1, \@attachMetaData)/geo;
        my $fileName = "";
        foreach my $fileMeta ( @attachMetaData ) {
            $fileMeta =~ m/META:FILEATTACHMENT\{name\=\"(.*?)\"/;
            $fileName = $1;
            unless ($_[0] =~ m/META:FILEATTACHMENT\{name\=\"$fileName/ ) {
                &TWiki::Func::writeDebug( "handleTopicAttach:: in unless $fileMeta") if $debug;
                $_[0] .= "\n$fileMeta";
            } else {
                &TWiki::Func::writeDebug( "handleTopicAttach:: in else $fileMeta") if $debug;
                $_[0] =~ s/(%META:FILEATTACHMENT\{name=\"$fileName.*?\}%)/$fileMeta/;
            }
        }
    }
}

1;

# EOF
