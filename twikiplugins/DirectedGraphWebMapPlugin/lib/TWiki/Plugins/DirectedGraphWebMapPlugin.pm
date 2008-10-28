# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.com
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
#   earlyInitPlugin         ( )                                     1.020
#   initPlugin              ( $topic, $web, $user, $installWeb )    1.000
#   initializeUserHandler   ( $loginName, $url, $pathInfo )         1.010
#   registrationHandler     ( $web, $wikiName, $loginName )         1.010
#   beforeCommonTagsHandler ( $text, $topic, $web )                 1.024
#   commonTagsHandler       ( $text, $topic, $web )                 1.000
#   afterCommonTagsHandler  ( $text, $topic, $web )                 1.024
#   startRenderingHandler   ( $text, $web )                         1.000
#   outsidePREHandler       ( $text )                               1.000
#   insidePREHandler        ( $text )                               1.000
#   endRenderingHandler     ( $text )                               1.000
#   beforeEditHandler       ( $text, $topic, $web )                 1.010
#   afterEditHandler        ( $text, $topic, $web )                 1.010
#   beforeSaveHandler       ( $text, $topic, $web )                 1.010
#   afterSaveHandler        ( $text, $topic, $web, $errors )        1.020
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
package TWiki::Plugins::DirectedGraphWebMapPlugin;    # change the package name and $pluginName!!!

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $pluginName $debug
    );

# This should always be $Rev: 14783 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 14783 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'DirectedGraphWebMapPlugin';  # Name of this Plugin

our %webmap; # $webmap{$baseTopic}{$targetTopic} = 1 if $baseTopic links to $targetTopic.  DOES NOT CROSS WEBS
our $excludeSystem = 0;
our @systemTopics = qw(WebChanges
                       WebHome
                       WebIndex
                       WebLeftBar
                       WebNotify
                       WebPreferences
                       WebRss
                       WebSearch
                       WebSearchAdvanced
                       WebStatistics
                       WebTopicList);

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;
    my $init_ok = 1;


    # check for Plugins.pm versions
    if ($init_ok) {
        if( $TWiki::Plugins::VERSION < 1.021 ) {
            &TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
            $init_ok = 0;
        }
    }

    # check dependencies
    if ($init_ok) {
        if( $TWiki::Plugins::VERSION >= 1.025 ) {
            my @deps = (
                        { package => 'TWiki::Plugins::DirectedGraphPlugin' },
                        );
            my $err = TWiki::Func::checkDependencies( $pluginName, \@deps );
            if( $err ) {
                &TWiki::Func::writeWarning( $err );
                print STDERR $err; # print to webserver log file
                $init_ok = 0;
            }
        }
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag( "\U$pluginName\E_DEBUG" );

    # Plugin correctly initialized
    if ($debug) {
        &TWiki::Func::writeDebug("Plugins.pm version $TWiki::Plugins::VERSION");
        &TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) ".(($init_ok)?"is OK":"FAILED")  );
    }
    return $init_ok; # 1 - success; 0 - fail
}



# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

#    $debug && TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" );

    # This is the place to define customized tags and variables
    # Called by TWiki::handleCommonTags, after %INCLUDE:"..."%

    # do custom extension rule, like for example:
    $_[0] =~ s/%WEBMAP%/&handleWebMap($_[1],$_[2], "")/ge;
    $_[0] =~ s/%WEBMAP{(.*)}%/&handleWebMap($_[1],$_[2], $1)/ge;

    $_[0] =~ s/%TOPICMAP%/&handleTopicMap($_[1],$_[2], "")/ge;
    $_[0] =~ s/%TOPICMAP{(.*)}%/&handleTopicMap($_[1],$_[2], $1)/ge;
}


sub handleTopicMap {
    my ($callingtopic, $callingweb, $args) = @_;
    my @returnlist;

    # PARAMETERS: web (optional) the web to map (default thisone)
    #             topic (optional) the topic to map (default thisone)
    #             links (optional) the number of links to display (default in Plugin page, or 2)
    #             backlinks (optional) the number of links to display (default in Plugin page, or 'links', or 1)

    my %params = TWiki::Func::extractParameters( $args );
    unless ($params{"web"} and TWiki::Func::webExists($params{"web"})) {
        $params{"web"} = $callingweb;
    }
    unless ($params{"topic"} and TWiki::Func::topicExists($params{"web"}, $params{"topic"})) {
        $params{"topic"} = $callingtopic;
    }
    unless ($params{"backlinks"}) {
        if ($params{"links"}) {
            $params{"backlinks"} = $params{"links"};
        } elsif (TWiki::Func::getPluginPreferencesValue("LINKS")) {
            $params{"backlinks"} = TWiki::Func::getPluginPreferencesValue("LINKS");
        } elsif (TWiki::Func::getPluginPreferencesValue("BACKLINKS")) {
            $params{"backlinks"} = TWiki::Func::getPluginPreferencesValue("BACKLINKS");
        } else {
            $params{"backlinks"} = 1;
        }
    }
    unless ($params{"links"}) {
        if (TWiki::Func::getPluginPreferencesValue("LINKS")) {
            $params{"links"} = TWiki::Func::getPluginPreferencesValue("LINKS");
        } else {
            $params{"links"} = 2;
        }
    }
    unless ($params{"size"}) {
        if (TWiki::Func::getPluginPreferencesValue("SIZE")) {
            $params{"size"} = TWiki::Func::getPluginPreferencesValue("SIZE");
        } else {
            $params{"size"} = "8.5,6.5";
        }
    }
    $excludeSystem = $params{"excludesystem"};

    my $rankdir = "TB";
    $rankdir = "LR" if ($params{"lr"});

    if ($debug) {
        &TWiki::Func::writeDebug("$pluginName: \$params{$_} = $params{$_}") foreach (sort keys %params);
    }

    populateWebMapArray($params{"web"});

    push @returnlist, "<dot map=1>";
    push @returnlist, "digraph webmap {";
    push @returnlist, "size=\"".$params{"size"}."\";";
    push @returnlist, "rankdir=$rankdir;";
    my $webbgcolor = TWiki::Func::getPreferencesValue( "WEBBGCOLOR", $params{"web"} );
    push @returnlist, qq(node [style=filled, color="$webbgcolor"];);
    # forward links
    push @returnlist, forwardlinks($params{"links"}, $params{"topic"});
    # back links
    push @returnlist, backlinks($params{"backlinks"}, $params{"topic"});
    push @returnlist, "}";
    push @returnlist, "</dot>";

     if ($debug) {
         return ("<verbatim>\n".join("\n", @returnlist)."\n</verbatim>");
     } else {
        return TWiki::Func::expandCommonVariables((join "\n", @returnlist), $callingtopic, $callingweb);
     }
}

sub forwardlinks {
    my $links = shift;
    my $baseTopic = shift;
    my @returnlist;

    if ($links--) {
        foreach my $targetTopic (sort keys %{$webmap{$baseTopic}}) {
            if ($webmap{$baseTopic}{$targetTopic}) {
                $webmap{$baseTopic}{$targetTopic} = 0;
                $debug && TWiki::Func::writeDebug("$baseTopic -> $targetTopic");
                push @returnlist, qq("$baseTopic" [URL="$baseTopic"];);
                push @returnlist, qq("$targetTopic" [URL="$targetTopic"];);
                push @returnlist, qq("$baseTopic" -> "$targetTopic";);
                push @returnlist, forwardlinks($links, $targetTopic);
            }
        }
    }
    return @returnlist;
}

sub backlinks {
    my $links = shift;
    my $targetTopic = shift;
    my @returnlist;

    if ($links--) {
        foreach my $baseTopic (sort keys %webmap) {
            if ($webmap{$baseTopic}{$targetTopic}) {
                $webmap{$baseTopic}{$targetTopic} = 0;
                $debug && TWiki::Func::writeDebug("$baseTopic -> $targetTopic");
                push @returnlist, qq("$baseTopic" [URL="$baseTopic"];);
                push @returnlist, qq("$targetTopic" [URL="$targetTopic"];);
                push @returnlist, qq("$baseTopic" -> "$targetTopic";);
                push @returnlist, backlinks($links, $baseTopic);
            }
        }
    }
    return @returnlist;
}


sub handleWebMap {
#    $debug && TWiki::Func::writeDebug("- ${pluginName}::handleWebMap(@_)");

    my ($callingtopic, $callingweb, $args) = @_;
    my @returnlist;

    # PARAMETERS web (optional) the web to map
    my %params = TWiki::Func::extractParameters( $args );
    unless ($params{"web"} and TWiki::Func::webExists($params{"web"})) {
        $params{"web"} = $callingweb;
    }
    unless ($params{"size"}) {
        if (TWiki::Func::getPluginPreferencesValue("SIZE")) {
            $params{"size"} = TWiki::Func::getPluginPreferencesValue("SIZE");
        } else {
            $params{"size"} = "8.5,6.5";
        }
    }
    $excludeSystem = $params{"excludesystem"};
    my $rankdir = "TB";
    $rankdir = "LR" if ($params{"lr"});

    populateWebMapArray($params{"web"});

    push @returnlist, "<dot map=1>";
    push @returnlist, "digraph webmap {";
    push @returnlist, "size=\"".$params{"size"}."\";";
    push @returnlist, "rankdir=$rankdir;";
    my $webbgcolor = TWiki::Func::getPreferencesValue( "WEBBGCOLOR", $params{"web"} );
    push @returnlist, qq(node [style=filled, color="$webbgcolor"];);
    foreach my $baseTopic (sort keys %webmap) {
        my $url = TWiki::Func::getViewUrl($params{'web'},$baseTopic);
        push @returnlist, qq("$baseTopic" [URL="$url"];) unless (grep /^$baseTopic$/, @systemTopics);
        foreach my $targetTopic (sort keys %{$webmap{$baseTopic}}) {
            push @returnlist, qq("$baseTopic" -> "$targetTopic";) if ($webmap{$baseTopic}{$targetTopic});
        }
    }
    push @returnlist, "}";
    push @returnlist, "</dot>";

     if ($debug) {
         return ("<verbatim>\n".join("\n", @returnlist)."\n</verbatim>");
     } else {
        return TWiki::Func::expandCommonVariables((join "\n", @returnlist), $callingtopic, $callingweb);
     }
}


sub populateWebMapArray {
    my $web = $_[0];
    my @topicList = TWiki::Func::getTopicList($web);

    my $urlhost = TWiki::Func::getUrlHost();
    my $viewurl = TWiki::Func::getViewUrl($web,"TOPIC");
    $viewurl =~ s/^$urlhost//;
    $viewurl =~ s:/TOPIC$::;
    my $href = qr(<a[^>]+href\s*=\s*"($urlhost)?$viewurl/(\w+)"[^>]*>);

    foreach my $baseTopic (@topicList) {
        $debug && TWiki::Func::writeDebug("${pluginName}: Scanning $web.$baseTopic");

        my $baseTopicText = TWiki::Func::readTopicText($web, $baseTopic, "", 1);

        # expand WEB and TOPIC variables
        $baseTopicText =~ s/%(HOME|NOTIFY|WEBPREFS|WIKIPREFS|WIKIUSERS)?TOPIC%/TWiki::Func::expandCommonVariables($&, $baseTopic, $web)/ge;
        $baseTopicText =~ s/%USERSWEB%/TWiki::Func::getMainWebname()/ge; # faster than expandCommonVariables
        $baseTopicText =~ s/%SYSTEMWEB%/TWiki::Func::getTwikiWebname()/ge;
        # skip meta
        $baseTopicText =~ s/%META[^%]+%//g;
#         # throw away text part of forced links
#         $baseTopicText =~ s/\[\[([^\]]*)(\]\[)?([^\]]*)\]\]/$1/g;
        # Throw away %WEBMAP% to prevent recursive rendering
        $baseTopicText =~ s/%WEBMAP%//g;
        $baseTopicText =~ s/%WEBMAP{.*}%//g;

        # ... in fact, throw away ALL remaining variables
        $baseTopicText =~ s/%[^%]+%//g;

        my $renderedTopic = TWiki::Func::renderText($baseTopicText, $web);
        my @links = $renderedTopic =~ /$href/g;
        while (@links) {
            shift @links; # throw away the hostname
            my $targetTopic = shift @links;
            $debug && TWiki::Func::writeDebug("$baseTopic -> $targetTopic");
            if ($excludeSystem) {
                if ((grep /^$baseTopic$/, @systemTopics) or (grep /^$targetTopic$/, @systemTopics)) {
                    next;
                }
            }
            $webmap{$baseTopic}{$targetTopic} = 1;
        }
    }
    foreach my $topic (@topicList) {
        # ensure that every topic has an entry in the array -- linking to itself (which we should ignore later)
        $webmap{$topic}{$topic} = 0;
    }

}


### DO NOT REMOVE THIS 1;
1;
