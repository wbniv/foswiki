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
package TWiki::Plugins::WorkflowPlugin::Workflow;

use strict;

sub new {
    my ( $class, $web, $topic ) = @_;

    my ( $meta, $text ) = TWiki::Func::readTopic( $web, $topic );
    unless (
        TWiki::Func::checkAccessPermission(
            'VIEW', $TWiki::Plugins::SESSION->{user},
            $text, $topic, $web, $meta
        )
      )
    {
        return undef;
    }
    my $this = bless(
        {
            preferences => {},
            states      => {},
            transitions => []
        },
        $class
    );
    my $inBlock = 0;

    # | *Current state* | *Action* | *Next state* | *Allowed* |
    foreach ( split( /\n/, $text ) ) {
        if (
/^\s*\|[\s*]*State[\s*]*\|[\s*]*Action[\s*]*\|[\s*]*Next State[\s*]*\|[\s*]*Allowed[\s*]*\|[\s*]*Form[\s*]*\|$/i
          )
        {

            # from now on, we are in the TRANSITION table
            $inBlock = 1;
        }
        elsif (
/^\s*\|[\s*]*State[\s*]*\|[\s*]*Allow Edit[\s*]*\|[\s*]*Message[\s*]*\|$/i
          )
        {

            # from now on, we are in the STATE table
            $inBlock = 2;

        }
        elsif (/^(?:\t|   )+\*\sSet\s([A-Za-z]+)\s\=\s*(.*)$/) {

            # store preferences
            $this->{preferences}->{$1} = $2;
        }
        elsif ( $inBlock == 1 && s/^\s*\|//o ) {

            # read row in TRANSITION table
            my ( $state, $action, $next, $allowed, $form ) =
              split(/\s*\|\s*/);
            $state = _cleanField($state);
            push(
                @{ $this->{transitions} },
                {
                    state   => $state,
                    action  => $action,
                    next    => $next,
                    allowed => $allowed,
                    form    => $form
                }
            );
        }
        elsif ( $inBlock == 2 && s/^\s*\|//o ) {

            # read row in STATE table
            my ( $state, $allowedit, $message ) = split(/\s*\|\s*/);
            $state = _cleanField($state);
            $this->{defaultState} ||= $state;
            $this->{states}->{$state} = {
                name      => $state,
                allowedit => $allowedit,
                message   => $message
            };
        }
        else {
            $inBlock = 0;
        }
    }
    return $this;
}

# Get the possible actions associated with the given state
sub getActions {
    my ( $this, $currentState ) = @_;
    my @actions = ();
    foreach ( @{ $this->{transitions} } ) {
        if ( $_->{state} eq $currentState
            && _isAllowed( $_->{allowed} ) )
        {
            push( @actions, $_->{action} );
        }
    }
    return @actions;
}

# Get the next state defined for the given current state and action
# (the first 2 columns of the transition table). The returned state
# will be undef if the transition doesn't exist, or is not allowed.
sub getNextState {
    my ( $this, $currentState, $action ) = @_;
    foreach ( @{ $this->{transitions} } ) {
        if (   $_->{state} eq $currentState
            && $_->{action} eq $action
            && _isAllowed( $_->{allowed} ) )
        {
            return $_->{next};
        }
    }
    return undef;
}

# Get the form defined for the given current state and action
# (the first 2 columns of the transition table). The returned form
# will be undef if the transition doesn't exist, or is not allowed.
sub getNextForm {
    my ( $this, $currentState, $action ) = @_;

    foreach ( @{ $this->{transitions} } ) {
        if (   $_->{state} eq $currentState
            && $_->{action} eq $action
            && _isAllowed( $_->{allowed} ) )
        {
            return $_->{form};
        }
    }
    return undef;
}

# Get the defauklt state for this workflow
sub getDefaultState {
    my $this = shift;
    return $this->{defaultState};
}

# Get the message associated with the given state
sub getMessage {
    my ( $this, $state ) = @_;

    return '' unless $this->{states}->{$state};
    $this->{states}->{$state}->{message};
}

# Determine if the current user is allowed to edit a topic that is in
# the given state.
sub allowEdit {
    my ( $this, $state ) = @_;

    return 0 unless $this->{states}->{$state};
    return _isAllowed( $this->{states}->{$state}->{allowedit} );
}

# finds out if the current user is allowed to do something.
# They are allowed if their wikiname is in the
# (comma,space)-separated list $allow, or they are a member
# of a group in the list.
sub _isAllowed {
    my ($allow) = @_;

    return 1 unless ($allow);

    # Always allow members of the admin group to edit
    if ( defined &TWiki::Func::isAnAdmin ) {

        # Latest interface, post user objects
        return 1 if ( TWiki::Func::isAnAdmin() );
    }
    elsif ( ref( $TWiki::Plugins::SESSION->{user} )
        && $TWiki::Plugins::SESSION->{user}->can("isAdmin") )
    {

        # User object
        return 1 if ( $TWiki::Plugins::SESSION->{user}->isAdmin() );
    }

    return 0 if ( defined($allow) && $allow =~ /^\s*nobody\s*$/ );

    if ( ref( $TWiki::Plugins::SESSION->{user} )
        && $TWiki::Plugins::SESSION->{user}->can("isInList") )
    {
        return $TWiki::Plugins::SESSION->{user}->isInList($allow);
    }
    elsif ( defined &TWiki::Func::isGroup ) {
        my $thisUser = TWiki::Func::getWikiName();
        foreach my $allowed ( split( /\s*,\s*/, $allow ) ) {
            ( my $waste, $allowed ) =
              TWiki::Func::normalizeWebTopicName( undef, $allowed );
            if ( TWiki::Func::isGroup($allowed) ) {
                return 1 if TWiki::Func::isGroupMember( $allowed, $thisUser );
            }
            else {
                $allowed = TWiki::Func::getWikiUserName($allowed);
                $allowed =~ s/^.*\.//;    # strip web
                return 1 if $thisUser eq $allowed;
            }
        }
    }

    return 0;
}

sub _cleanField {
    my ($text) = @_;
    $text ||= '';
    $text =~ s/^\s*//go;
    $text =~ s/\s*$//go;
    $text =~ s/[^A-Za-z0-9_.]//go;    # Need do for web.topic
    return $text;
}

sub stringify {
    my $this = shift;

    my $s = "---+ Preferences\n";
    foreach ( keys %{ $this->{preferences} } ) {
        $s .= "| $_ | $this->{preferences}->{$_} |\n";
    }
    $s .= "\n---+ States\n| *State*       | *Allow Edit* | *Message* |\n";
    foreach ( values %{ $this->{states} } ) {
        $s .= "| $_->{name} | $_->{allowedit} | $_->{message} |\n";
    }

    $s .=
      "\n---+ Transitions\n| *State* | *Action* | *Next State* | *Allowed* |\n";
    foreach ( @{ $this->{transitions} } ) {
        $s .= "| $_->{state} | $_->{action} | $_->{next} |$_->{allowed} |\n";
    }
    return $s;
}

1;
