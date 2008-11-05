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

# TODO
# 1. Create initial values based on form when attaching a form for
#    the first time.
# 2. Allow appearance of button to be given in preference.

# =========================
package TWiki::Plugins::WorkflowPlugin;

#use strict 'vars';
use strict;

use Error ':try';

use TWiki::Plugins::WorkflowPlugin::Workflow;
use TWiki::Plugins::WorkflowPlugin::ControlledTopic;

our $VERSION          = '$Rev: 0$';
our $RELEASE          = '5 Nov 2008';
our $SHORTDESCRIPTION = 'Supports work flows associated with topics';
our $pluginName       = 'WorkflowPlugin';
our $TOPIC;

sub initPlugin {
    my ( $topic, $web ) = @_;

    $TOPIC = undef;

    TWiki::Func::registerRESTHandler( 'changeState', \&_changeState );

    TWiki::Func::registerTagHandler( 'WORKFLOWSTATE', \&_WORKFLOWSTATE );
    TWiki::Func::registerTagHandler( 'WORKFLOWEDITTOPIC',
        \&_WORKFLOWEDITTOPIC );
    TWiki::Func::registerTagHandler( 'WORKFLOWSTATEMESSAGE',
        \&_WORKFLOWSTATEMESSAGE );
    TWiki::Func::registerTagHandler( 'WORKFLOWHISTORY', \&_WORKFLOWHISTORY );
    TWiki::Func::registerTagHandler( 'WORKFLOWTRANSITION',
        \&_WORKFLOWTRANSITION );

    return 1;
}

# Tag handler
sub _initTOPIC {
    my ( $web, $topic ) = @_;

    return $TOPIC if $TOPIC;

    my ( $meta, $text ) = TWiki::Func::readTopic( $web, $topic );

    TWiki::Func::pushTopicContext( $web, $topic );
    my $workflowName = TWiki::Func::getPreferencesValue("WORKFLOW");
    TWiki::Func::popTopicContext( $web, $topic );

    if ($workflowName) {

        ( my $wfWeb, $workflowName ) =
          TWiki::Func::normalizeWebTopicName( $web, $workflowName );
        my $workflow =
          new TWiki::Plugins::WorkflowPlugin::Workflow( $wfWeb, $workflowName );

        if ($workflow) {
            $TOPIC =
              new TWiki::Plugins::WorkflowPlugin::ControlledTopic( $workflow,
                $web, $topic, $meta, $text );
        }
    }
    return $TOPIC;
}

# Tag handler
sub _WORKFLOWEDITTOPIC {
    my ( $session, $attributes, $topic, $web ) = @_;

    _initTOPIC( $web, $topic );

    # replace edit tag
    if ( $TOPIC->canEdit() ) {
        return CGI::a( { href => "%EDITURL%" }, CGI::strong("Edit") );
    }
    else {
        return CGI::strike("Edit");
    }
}

# Tag handler
sub _WORKFLOWSTATEMESSAGE {
    my ( $session, $attributes, $topic, $web ) = @_;
    _initTOPIC( $web, $topic );
    return $TOPIC->getStateMessage();
}

# Tag handler
sub _WORKFLOWHISTORY {
    my ( $session, $attributes, $topic, $web ) = @_;
    _initTOPIC( $web, $topic );
    return $TOPIC->getHistoryText();
}

# Tag handler
sub _WORKFLOWTRANSITION {
    my ( $session, $attributes, $topic, $web ) = @_;

    _initTOPIC( $web, $topic );
    return undef unless $TOPIC;

    #
    # Build the button to change the current status
    #
    my @actions         = $TOPIC->getActions();
    my $numberOfActions = scalar(@actions);
    my $cs              = $TOPIC->getState();

    unless ($numberOfActions) {
        return CGI::span( { class => 'twikiAlert' },
            "NO AVAILABLE ACTIONS in state $cs" )
          if $TOPIC->debugging();
        return '';
    }

    my @fields = (
        CGI::hidden( 'WORKFLOWSTATE', $cs ),
        CGI::hidden( 'topic',         "$web.$topic" )
    );

    my $buttonClass =
      TWiki::Func::getPreferencesValue("\U$pluginName\E_CSSCLASS")
      || 'twikiChangeFormButton twikiSubmit"';

    if ( $numberOfActions == 1 ) {
        push( @fields, CGI::hidden( 'WORKFLOWACTION', $actions[0] ) );
        push(
            @fields,
            CGI::submit(
                -class => $buttonClass,
                -value => $actions[0]
            )
        );
    }
    else {
        push(
            @fields,
            CGI::popup_menu(
                -name   => 'WORKFLOWACTION',
                -values => \@actions
            )
        );
        push(
            @fields,
            CGI::submit(
                -class => $buttonClass,
                -value => 'Change status'
            )
        );
    }
    my $url = TWiki::Func::getScriptUrl( $pluginName, 'changeState', 'rest' );
    return
        CGI::start_form( -method => 'POST', -action => $url )
      . join( '', @fields )
      . CGI::end_form();
}

# Tag handler
sub _WORKFLOWSTATE {
    my ( $session, $attributes, $topic, $web ) = @_;

    _initTOPIC( $web, $topic );
    my $theWeb = $attributes->{web} || $web;
    my $theTopic = $attributes->{"_DEFAULT"};
    if ( !$theTopic ) {
        $theTopic = $attributes->{topic} || $topic;
    }
    ( $theWeb, $theTopic ) =
      TWiki::Func::normalizeWebTopicName( $theWeb, $theTopic );

    if ( $theWeb eq $web && $theTopic eq $topic ) {
        return $TOPIC->getState() if $TOPIC;
        return '';
    }

    # Different topic
    my $loadTopicState = 0;
    my ( $meta, $text ) = TWiki::Func::readTopic( $theWeb, $theTopic );

    # SMELL: surely this should be the WORKFLOW in the target topic?
    my $prefWorkflow = TWiki::Func::getPreferencesValue("WORKFLOW");
    if ( $prefWorkflow && TWiki::Func::topicExists( $theWeb, $prefWorkflow ) ) {
        $loadTopicState = 1;
    }
    else {
        $prefWorkflow = $meta->get( 'PREFERENCE', 'WORKFLOW' );
        if ($prefWorkflow) {
            $prefWorkflow = $prefWorkflow->{value};
            if ( TWiki::Func::topicExists( $theWeb, $prefWorkflow ) ) {
                $loadTopicState = 1;
            }
        }
    }
    if ($loadTopicState) {
        ( my $prefWorkflowWeb, $prefWorkflow ) =
          TWiki::Func::normalizeWebTopicName( $theWeb, $prefWorkflow );

        my $TOPIC_STATE = $meta->get('WORKFLOW');
        unless ($TOPIC_STATE) {
            $TOPIC_STATE = { name => $TOPIC->getDefaultState() };
        }
        return $TOPIC_STATE->{name};
    }
    else {
        return '';
    }
}

# Used to trap an edit and check that it is permitted by the workflow
sub beforeEditHandler {
    my ( $text, $topic, $web, $meta ) = @_;

    _initTOPIC( $web, $topic );
    return unless $TOPIC;

    if ( !$TOPIC->canEdit() ) {
        throw TWiki::OopsException(
            'accessdenied',
            def   => 'topic_access',
            web   => $_[2],
            topic => $_[1],
            params =>
              [ 'Edit topic', 'You are not permitted to edit this topic' ]
        );
        return 0;
    }
}

# Handle actions. REST handler, on changeState action.
sub _changeState {
    my ($session) = @_;

    my $query = TWiki::Func::getCgiQuery();
    return unless $query;

    my $web   = $session->{webName};
    my $topic = $session->{topicName};
    die unless $web && $topic;

    my $url;
    if ( !$web || !$topic || !_initTOPIC( $web, $topic ) ) {
        $url = TWiki::Func::getScriptUrl(
            $web, $topic, 'oops',
            template => "oopssaveerr",
            param1   => "Could not initialise workflow for "
              . ( $web   || '' ) . '.'
              . ( $topic || '' )
        );
    }
    else {
        my $action = $query->param('WORKFLOWACTION');
        my $state  = $query->param('WORKFLOWSTATE');
        die "BAD STATE $action $state!=", $TOPIC->getState()
          unless $action
              && $state
              && $state eq $TOPIC->getState()
              && $TOPIC->haveNextState($action);

        my $newForm = $TOPIC->newForm($action);

        try {
            $TOPIC->changeState($action);
            if ($newForm) {

                # If there is a form with the new state, and it's not the same
                # form as previously, we need to kick into edit mode to support
                # form field changes.
                $url = TWiki::Func::getScriptUrl( $web, $topic, 'edit' );
            }
            else {
                $url = TWiki::Func::getScriptUrl( $web, $topic, 'view' );
            }
        }
        catch Error::Simple with {
            my $error = shift;
            $url = TWiki::Func::getScriptUrl(
                $web, $topic, 'oops',
                template => "oopssaveerr",
                param1   => $error
            );
        };
    }
    TWiki::Func::redirectCgiQuery( undef, $url );
    return undef;
}

# Mop up other WORKFLOW tags without individual handlers
sub commonTagsHandler {
    my ( $text, $topic, $web ) = @_;
    _initTOPIC( $web, $topic );
    return unless $TOPIC;

    # show all tags defined by the preferences
    my $url = TWiki::Func::getScriptUrl( $web, $topic, "view" );
    $TOPIC->expandWorkflowPreferences( $url, $_[0] );

    unless ( $TOPIC->debugging() ) {

        # Clean up unexpanded variables
        $_[0] =~ s/%WORKFLOW[A-Z_]*%//g;
    }
}

# Check the the workflow permits a save operation.
sub beforeSaveHandler {
    my ( $text, $topic, $web ) = @_;

    _initTOPIC( $web, $topic );
    return unless $TOPIC;

    # This handler is called by TWiki::Store::saveTopic just before
    # the save action.

    if ( !$TOPIC->canEdit() ) {
        throw TWiki::OopsException(
            'accessdenied',
            def   => 'topic_access',
            web   => $_[2],
            topic => $_[1],
            params =>
              [ 'Save topic', 'You are not permitted to save this topic' ]
        );
        return 0;
    }
}

1;
