# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005 Thomas Hartkens <thomas@hartkens.de>
# Copyright (C) 2005 Thomas Weigert <thomas.weigert@motorola.com>
# Copyright (C) 2008 Crawford Currie http://c-dot.co.uk
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
# This object represents a workflow definition. It stores the preferences
# defined in the workflow topic, together with the state and transition
# tables defined therein.
#
package TWiki::Plugins::WorkflowPlugin::ControlledTopic;

use strict;

# Constructor
sub new {
    my ( $class, $workflow, $web, $topic, $meta, $text ) = @_;
    my $this = bless(
        {
            workflow => $workflow,
            web      => $web,
            topic    => $topic,
            meta     => $meta,
            text     => $text,
            state    => $meta->get('WORKFLOW'),
            history  => $meta->get('WORKFLOWHISTORY'),
        },
        $class
    );

    return $this;
}

# Return true if debug is enabled in the workflow
sub debugging {
    my $this = shift;
    return $this->{workflow}->{preferences}->{WORKFLOWDEBUG};
}

# Get the current state of the workflow in this topic
sub getState {
    my $this = shift;
    return $this->{state}->{name} || $this->{workflow}->getDefaultState();
}

# Get the available actions from the current state
sub getActions {
    my $this = shift;
    return $this->{workflow}->getActions( $this->getState() );
}

# Set the current state in the topic
sub setState {
    my ( $this, $state, $version ) = @_;
    $this->{state}->{name} = $state;
    $this->{state}->{"LASTVERSION_$state"} = $version;
    $this->{state}->{"LASTTIME_$state"} =
      TWiki::Func::formatTime( time(), undef, 'servertime' );
    $this->{meta}->put( "WORKFLOW", $this->{state} );
}

# Get the appropriate message for the current state
sub getStateMessage {
    my $this = shift;
    return $this->{workflow}->getMessage( $this->getState() );
}

# Get the history string for the topic
sub getHistoryText {
    my $this = shift;

    return '' unless $this->{history};
    return $this->{history}->{value} || '';
}

# Return true if a new state is available using this action
sub haveNextState {
    my ( $this, $action ) = @_;
    return $this->{workflow}->getNextState( $this->getState(), $action );
}

# Return tue if this topic is editable
sub canEdit {
    my $this = shift;
    return $this->{workflow}->allowEdit( $this->getState() );
}

# Expand miscellaneous preferences defined in the workflow and topic
sub expandWorkflowPreferences {
    my $this = shift;
    my $url  = shift;
    my $key;
    foreach $key ( keys %{ $this->{workflow}->{preferences} } ) {
        if ( $key =~ /^WORKFLOW/ ) {
            $_[0] =~ s/%$key%/$this->{workflow}->{preferences}->{$key}/g;
        }
    }

    # show last version tags and last time tags
    while ( my ( $key, $val ) = each %{ $this->{state} } ) {
        $val ||= '';
        if ( $key =~ m/^LASTVERSION_/ ) {
            my $foo = CGI::a( { href => "$url?rev=$val" }, "revision $val" );
            $_[0] =~ s/%WORKFLOW$key%/$foo/g;
        }
        elsif ( $key =~ /^LASTTIME_/ ) {
            $_[0] =~ s/%WORKFLOW$key%/$val/g;
        }
    }

    # Clean down any states we have no info about
    $_[0] =~ s/%WORKFLOWLAST(TIME|VERSION)_\w+%//g unless $this->debugging();
}

# if the form employed in the state arrived after after applying $action
# is different to the form currently on the topic.
sub newForm {
    my ( $this, $action ) = @_;
    my $cs      = $this->getState();
    my $form    = $this->{workflow}->getNextForm( $cs, $action );
    my $oldForm = $this->{meta}->get('FORM');

    # If we want to have a form attached initially, we need to have
    # values in the topic, due to the TWiki form initialization
    # algorithm, or pass them here via URL parameters (take from
    # initialization topic)
    return ( $form && ( !$oldForm || $oldForm ne $form ) ) ? $form : undef;
}

# change the state of the topic, saving the updated topic
sub changeState {
    my ( $this, $action ) = @_;

    my $cs = $this->getState();
    my $state = $this->{workflow}->getNextState( $cs, $action );

    my ( $revdate, $revuser, $version, $revcmt ) =
      $this->{meta}->getRevisionInfo();

    $this->setState($state);

    my $fmt = TWiki::Func::getPreferencesValue("WORKFLOWHISTORYFORMAT")
      || '$state -- $date';
    $fmt = '$n()' . $fmt if $this->{history}->{value};
    if ( defined &TWiki::Func::decodeFormatTokens ) {
        $fmt = TWiki::Func::decodeFormatTokens($fmt);
    }
    else {
        my $mixedAlpha = $TWiki::regex{mixedAlpha};
        $fmt =~ s/\$quot/\"/go;
        $fmt =~ s/\$n/<br>/go;
        $fmt =~ s/\$n\(\)/<br>/go;
        $fmt =~ s/\$n([^$mixedAlpha]|$)/\n$1/gos;
        $fmt =~ s/\$wikiusername/TWiki::Func::getWikiUserName($revuser)/geo;
    }
    $fmt =~ s/\$state/$this->getState()/goe;
    $fmt =~ s/\$date/$this->{state}->{"LASTTIME_$state"}/geo;

    $this->{history}->{value} .= $fmt;
    $this->{meta}->put( "WORKFLOWHISTORY", $this->{history} );
    my $form = $this->{workflow}->getNextForm( $cs, $action );
    if ($form) {
        $this->{meta}->put( "FORM", { name => $form } );
    }    # else leave the existing form in place
    TWiki::Func::saveTopic(
        $this->{web}, $this->{topic}, $this->{meta},
        $this->{text}, { minor => 1 }
    );

    return undef;

}

1;
