# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.com
# Copyright (C) 2004 Kaitlin Duck Sherwood, ducky@osafoundation.org
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

# The ContributorsPlugin replaces any occurances of %CONTRIBUTORS% variable 
# with a list of all the people who have edited the page.
# %CONTRIBUTORS has optional arguments
#   web -- which WikiWeb the page is in 
#   topic -- the topic name 
#   rev -- the last revision for which we want to see contributors 
#   last -- only show the last N edits
#   format -- format string for each revision's output; can use variables
#	$author, $date, $rev, and $n (for author name, date, revision number, and newline)
#   header -- a header to put before putting each contributor line
#   nodups -- if "on", suppresses duplicate lines, otherwise does not (really only
#	useful for showing a list of the authors)
# 
# EXAMPLE:
# The following line will show all the authors (only once) who edited Main.WebHome
# between revision 1.15 and 1.25, and will have a header line that says as much.
# %CONTRIBUTORS{web="Main" page="WebHome" rev="1.25" last="10" format="   * $author" 
#	header="Authors from rev 1.15 to 1.25:$n" nodups="on"}

# With this plugin is a page TWiki.WebContributors, which is set
# up so that you can get all the contributors via a URL, e.g.
#    http://flossrecycling.com/twiki/bin/view/TWiki/WebContributors?web=Main&page=WebHome&rev=1.45
# The alert reader will wonder why the topic name is passed in with
# the variable named "page" instead of "topic".  That's because 
# if bin/view sees "topic", it will render the topic (e.g. WebHome)
# instead of rendering WebContributors with the variable of topic=WebHome.


# =========================
package TWiki::Plugins::ContributorsPlugin;    

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $pluginName
        $debug $exampleCfgVar
    );

# This should always be $Rev: 6827 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 6827 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'ContributorsPlugin';  

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.021 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPluginPreferencesFlag( "DEBUG" );

    # Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
    $exampleCfgVar = TWiki::Func::getPluginPreferencesValue( "EXAMPLE" ) || "default";

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
# commonTagsHandler receives 
# text    $_[0]
# topic    $_[1]
# web    $_[2]
sub commonTagsHandler
{
### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    &TWiki::Func::writeDebug( "- ContributorsPlugin::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    $_[0] =~ s/%CONTRIBUTORS%/&handleContributors($_[1], $_[2])/ge;
    $_[0] =~ s/%CONTRIBUTORS{(.*?)}%/&handleContributors($_[1], $_[2], $1)/ge;

}

# =========================
# handleContributors returns a formatted list of contributors (as a string).
sub handleContributors
{
    my( $theTopic, $theWeb, $args) = @_;


    my $web = &TWiki::Func::extractNameValuePair( $args, "web" ) || $theWeb;
    my $topic = &TWiki::Func::extractNameValuePair( $args, "topic" ) || $theTopic;
    $defaultFormat = "	* \$author -- Revision \$rev on date \$date \$n";
    my $format = &TWiki::Func::extractNameValuePair( $args, "format" ) || $defaultFormat;
    my $header = &TWiki::Func::extractNameValuePair( $args, "header" );
    my $noDuplicates = &TWiki::Func::extractNameValuePair( $args, "nodups" ) || "off";
    $header =~ s/\$n/\n/g;	# no obvious need to call formatContributorLine
    my $maxRevision = &TWiki::Func::extractNameValuePair( $args, "rev" ) || (&TWiki::Func::getRevisionInfo($web, $topic))[2];
    $maxRevision =~ s/^\d\.(\d*)$/$1/;
    my $last = &TWiki::Func::extractNameValuePair( $args, "last" ) || $maxRevision;
    my @contributorArray;
    my %contributorDictionary;
    
    if ($last >= $maxRevision) {
            $last = $maxRevision;
            }

    # This is a bit slow, since it reads the ,v file $maxRevision times.
    # If there someday is a way to get all the rev info at once, this should
    # take advantage of that.
    for ($revision=$maxRevision; $revision>($maxRevision-$last); $revision--) {

        my @lines;
        if( $session ) {
            @lines = $meta->getRevisionInfo();
            $lines[1] = $lines[1];
        } else {
            @lines = TWiki::Func::getRevisionInfo($web, $topic, $revision);
        }

        for ($lineIndex = 0; $lineIndex < $#lines; $lineIndex += 4) {
	    my $date = &TWiki::Func::formatTime($lines[$lineIndex+0], "http");
	    my $author = $lines[$lineIndex+1];
	    my $revisionNumber = $lines[$lineIndex+2];
	    my $comment = $lines[$lineIndex+3];		
	    $contributorLine = &formatContributorLine($web, $topic, $author, $date, $revision, $format);
            if ($noDuplicates eq "on") {
                # rock-stupid but slow way of eliminating duplicates
                $contributorDictionary{$contributorLine} = "dummuy";
                }
            else {
	        push @contributorArray, $contributorLine;
                }
	    }
        }
    if ($noDuplicates eq "on") {
        $contributorString = join("",sort(keys(%contributorDictionary)));
        }
    else {
        $contributorString = (join("", @contributorArray));
        }

    return &TWiki::Func::renderText($header.$contributorString);
    }


# =========================
# @@@ TBD: If there is a call for it, it would be easy to add $web and $topic as
# @@@      variables that could be expanded.  
sub formatContributorLine {
    my $web = shift;
    my $topic = shift;
    my $author = shift;
    my $date = shift;
    my $revisionNumber = shift;
    my $formattedString = shift;

    $viewURL = &TWiki::Func::getViewUrl($web, $topic);
    $revisionNumber = "[[$viewURL?rev=1\.$revisionNumber][1.$revisionNumber]]";
    $author = &TWiki::Func::userToWikiName($author);

    $formattedString =~ s/\$author/$author/g;
    $formattedString =~ s/\$date/$date/g;
    $formattedString =~ s/\$rev/$revisionNumber/g;
    $formattedString =~ s/\$n/\n/g;
    return $formattedString;
    }


1;
