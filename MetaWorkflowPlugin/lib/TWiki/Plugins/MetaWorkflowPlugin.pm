# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2007 Andrew Jones, andrewjones86@googlemail.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the TWiki root.

package TWiki::Plugins::MetaWorkflowPlugin;
use strict;
use vars qw(    $VERSION
                $RELEASE
                $NO_PREFS_IN_TOPIC
                $SHORTDESCRIPTION
                $pluginName
                );

$VERSION = '$Rev: 9813$';
$RELEASE = 'Dakar';
$NO_PREFS_IN_TOPIC = 1;
$SHORTDESCRIPTION = 'Defines a workflow based on updated meta data (such as form fields, or meta data from another plugin)';
$pluginName = 'MetaWorkflowPlugin';

# =========================
sub initPlugin {
    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # plugin correctly initialized
    return 1;
}

sub commonTagsHandler {

    return unless $_[0] =~ m/%METAWORKFLOWCURRENT%/g;
        
    _Debug("Syntax found. Handling tag...");

    $_[0] =~ s/%METAWORKFLOWCURRENT%/_handleTag($_[1], $_[2]);/ge;
    $_[0] =~ s/%METAWORKFLOW{.*}%//g;
}

# =========================
sub _handleTag {
    my( $theTopic, $theWeb ) = @_;

    # look for METAWORKFLOWDEFINITION setting
    my $defTopic = '';
    ($theWeb, $theTopic) = TWiki::Func::normalizeWebTopicName($theWeb, $defTopic)
        if $defTopic = TWiki::Func::getPreferencesValue("METAWORKFLOWDEFINITION");

    return _returnError("Topic [[$theWeb.$theTopic]] does not exist. Check your METAWORKFLOWDEFINITION setting.")
        unless TWiki::Func::topicExists($theWeb, $theTopic);

    my (undef, $text) = TWiki::Func::readTopic($theWeb, $theTopic);

    if($text =~ m/%METAWORKFLOW{(.*)}%\n/g){
        # in definition table
        my %params = TWiki::Func::extractParameters($1);

        while($text =~ m/\G\|(.*)\|(.*)\|(.*)\|\n?/gc){ # each row in table
            my ($webTopic, $value, $message) = ($1, $2, $3);

            _Debug("Definition Table: |$webTopic|$value|$message|");

            $value =~ s/^ //g;
            $value =~ s/ $//g;
            $message =~ s/^ //g;
            $message =~ s/ $//g;

            $webTopic =~ s/ //g;
            next if $webTopic =~ m/\*.*\*/; # table header
            return $message if lc$webTopic eq 'final';
            my ($web, $topic) = TWiki::Func::normalizeWebTopicName($theWeb, $webTopic);

            return _returnError("Topic [[$web.$topic]] does not exist. Check your %<nop>METAWORKFLOW{...}% table.")
                unless TWiki::Func::topicExists($web, $topic);

            # get meta data     
            my ($meta, undef) = TWiki::Func::readTopic($web, $topic);
            my $att = $meta->get($params{type}, $params{name});
            my $key = $params{key} || 'name';

            return $message if (lc$att->{$key} ne lc$value); # workflow has not moved to the next row
        }
    } else {
        return _returnError("%<nop>METAWORKFLOW{...}% variable not found in [[$theWeb.$theTopic]]");
    }

    # goes all the way through table without match or FINAL 
    _Debug("No match or FINAL in table. Returned nothing.");
    return '';
}

# =========================
sub _returnError {
    my $text = shift;

    _Debug($text);

    my $warn = TWiki::Func::getPreferencesValue("METAWORKFLOWWARNING");
    return if lc$warn eq 'off';

    return "<span class='foswikiAlert'>${pluginName} error: $text</span>";
}

sub _Debug {
    my $text = shift;

    my $debug = $TWiki::cfg{Plugins}{$pluginName}{Debug} || 0;

    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}: $text" ) if $debug;
}

1;
