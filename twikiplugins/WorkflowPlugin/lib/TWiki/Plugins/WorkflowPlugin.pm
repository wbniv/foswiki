# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005 Thomas Hartkens <thomas@hartkens.de>
# Copyright (C) 2005 Thomas Weigert <thomas.weigert@motorola.com>
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
# 1. Create initial values based on form when attaching a form for the first time.
# 2. Allow appearance of button to be given in preference.

# =========================
package TWiki::Plugins::WorkflowPlugin;

#use strict 'vars';
use strict;

# =========================
use vars qw(
            $web $topic $user $VERSION $RELEASE $pluginName
            $debug 
            $prefWorkflow
            $prefWorkflowWeb
            $prefNeedsWorkflow
            $globWorkflow
            $globForm
            $globWebName
            $globCurrentState $globHistory
            $globWorkflowMessage $globAllowEdit $globButton
            $CalledByMyself
            %globPreferences
            $SHORTDESCRIPTION
           );

# This should always be $Rev: 0$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 0$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$SHORTDESCRIPTION = 'Supports work flows associated with topics';

$pluginName = 'WorkflowPlugin';  # Name of this Plugin

# =========================
sub initPlugin {
    ( $topic, $web ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.021 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Deprecated the plugin debug flag
    # $debug = TWiki::Func::getPluginPreferencesFlag( "DEBUG" );

    $globWebName = $web;

    my( $meta, $text ) = TWiki::Func::readTopic( $web, $topic );

    if (($prefWorkflow = TWiki::Func::getPreferencesValue( "WORKFLOW" )) &&
          &TWiki::Func::topicExists( $globWebName, $prefWorkflow)) {

      ($prefWorkflowWeb, $prefWorkflow) =
	TWiki::Func::normalizeWebTopicName($web, $prefWorkflow);

      $prefNeedsWorkflow = 1;

      $user = $TWiki::Plugins::SESSION->{user};

      $globCurrentState = getWorkflowState($meta);
      #Debug("initPlugin State in the document: '" . $globCurrentState->{name} . "'");
      ($globWorkflow, $globCurrentState, $globWorkflowMessage, $globAllowEdit, $globForm) = 
	parseWorkflow($prefWorkflowWeb, $prefWorkflow, $user, $globCurrentState);
      $globHistory = $meta->get( 'WORKFLOWHISTORY' ) || '';
      $globHistory = $globHistory->{value} if $globHistory;

#      $globButton = TWiki::Func::getPreferencesValue( "\U$pluginName\E_BUTTON" ) || '<table><tr><td><div class="twikiChangeFormButton twikiSubmit "> $button </div></td></tr></table>';
      $globButton = TWiki::Func::getPreferencesValue( "\U$pluginName\E_STYLE" ) || 'style="twikiChangeFormButton twikiSubmit"';

    } else {
        $prefNeedsWorkflow = 0;
    }

    TWiki::Func::registerTagHandler( 'WORKFLOWSTATE', \&currentState );

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}


# =========================
sub commonTagsHandler {
    ### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    if ($prefNeedsWorkflow && (my $query = TWiki::Func::getCgiQuery())) {
      my $action = $query->param( 'WORKFLOWACTION' );
      my $state = $query->param( 'WORKFLOWSTATE' );

      # find out if the user is allowed to perform the action 
      if ($action && ($state eq $globCurrentState->{name}) && defined($$globWorkflow{$action})) {
	# store new status as meta data
	changeWorkflowState($globWorkflow->{$action}, $globForm->{$action});

	# we need to parse the workflow again since the state of the document has
	# changed which will effect the actions the user can do now. 
	my $user = $TWiki::Plugins::SESSION->{user};
	($globWorkflow, $globCurrentState, $globWorkflowMessage, $globAllowEdit, $globForm) = 
	  parseWorkflow($prefWorkflowWeb, $prefWorkflow, $user, $globCurrentState);
      }

      # replace edit tag
      if ($globAllowEdit) {
	$_[0] =~ s!%WORKFLOWEDITTOPIC%!<a href=\"%EDITURL%\"><b>Edit</b></a>!g;
      } else {
	$_[0] =~ s!%WORKFLOWEDITTOPIC%! <strike>Edit<\/strike> !g;
      }


      # show all tags defined by the preferences
      foreach my $key (keys %globPreferences) {
	if ($key =~ /^WORKFLOW/) {
	  $_[0] =~ s/%$key%/$globPreferences{$key}/g;
	}
      }

      # show last version tags
      foreach my $key (keys %{$globCurrentState}) {
	if ($key =~ /^LASTVERSION_/) {
	  my $url = TWiki::Func::getScriptUrl( $web,$topic,"view" );
	  my $foo = "<a href='${url}?rev=".$globCurrentState->{$key}."'>revision ".
	    $globCurrentState->{$key}."</a>";
	  $_[0] =~ s/%WORKFLOW$key%/$foo/g;
	}
      }

      # show last time tags
      foreach my $key (keys %{$globCurrentState}) {
	if ($key =~ /^LASTTIME_/) {
	  $_[0] =~ s/%WORKFLOW$key%/$globCurrentState->{$key}/g;
	}
      }

      # display the message for current status
      $_[0] =~ s/%WORKFLOWSTATEMESSAGE%/$globWorkflowMessage/g;

      $_[0] =~ s/%WORKFLOWHISTORY%/$globHistory/g;

      #
      # Build the button to change the current status
      #
      my @actions = keys(%{$globWorkflow});
      my $NumberOfActions = scalar(@actions);
      if ($NumberOfActions > 0) {
	my $button;
	my $url = TWiki::Func::getScriptUrl( $web,$topic,"view" );

	if ($NumberOfActions == 1) {
	  $button = "<FORM METHOD=POST ACTION='$url'>".
	    "<input type='hidden' name='WORKFLOWSTATE' value='$globCurrentState->{name}'>".
	    "<input type='hidden' name='WORKFLOWACTION' value='$actions[0]'>".
	    "<input type='submit' value='$actions[0]' $globButton />".
	    "</FORM>";
	  
	} else {
	  my $select="";
	  foreach my $key (@actions) {
	    $select .= "<option value='$key'> $key </option>";
	  }
	  $button = "<FORM METHOD=POST ACTION='$url'>".
	    "<input type='hidden' name='WORKFLOWSTATE' value='$globCurrentState->{name}'>".
	      "<select name='WORKFLOWACTION'>$select</select> ".
		"<input type='submit' value='Change status' $globButton />".
		  "</FORM>";
	}

	# build the final form
	#	      my $form = '<div style="text-align:right;">'.
	#		  '<table width="100%" border="0" cellspacing="0" cellpadding="0" class="twikiChangeFormButtonHolder">'.
	#		  '<tr>'.
	#		  "<td align='right'>".$globPreferences{"TEXTBEFORECHANGEBUTTON"}." &nbsp; </td>".
	#		  '<td align="right"> '.$button .' </td></tr></table></div>';
	$_[0] =~ s/%WORKFLOWTRANSITION%/$button/g;
      }

    } else {
      $_[0] =~ s!%WORKFLOWEDITTOPIC%!<a href=\"%EDITURL%\"><b>Edit</b></a>!g;
    }

    # delete all tags which start with the word WORKFLOW
    $_[0] =~ s/%WORKFLOW([a-zA-Z_]*)%//g;

}

sub currentState
{
  my ($session, $attributes, $topic, $web) = @_;
  my $theWeb = $attributes->{web} || $web;
  my $theTopic = $attributes->{"_DEFAULT"};
    if( ! $theTopic ) {
      $theTopic = $attributes->{topic} || $topic;
    }
  ( $theWeb, $theTopic ) = TWiki::Func::normalizeWebTopicName( $theWeb, $theTopic );

  if ( $theWeb eq $web && $theTopic eq $topic ) {
    return $globCurrentState->{name} if $globCurrentState;
    return '';
  }
  my( $meta, $text ) = TWiki::Func::readTopic( $theWeb, $theTopic );
  my $prefWorkflow;
  if ((($prefWorkflow = TWiki::Func::getPreferencesValue( "WORKFLOW" )) &&
       &TWiki::Func::topicExists( $theWeb, $prefWorkflow)) ||
      (($prefWorkflow = $meta->get('PREFERENCE', 'WORKFLOW')) && ($prefWorkflow = $prefWorkflow->{value}) &&
       &TWiki::Func::topicExists( $theWeb, $prefWorkflow))) {

    (my $prefWorkflowWeb, $prefWorkflow) =
	TWiki::Func::normalizeWebTopicName($theWeb, $prefWorkflow);

      my $globCurrentState = getWorkflowState($meta);
      (my $globWorkflow, $globCurrentState) = 
	parseWorkflow($prefWorkflowWeb, $prefWorkflow, $TWiki::Plugins::SESSION->{user}) unless $globCurrentState;
      return $globCurrentState->{name};
    }
  else {
    return '';
  }
}

# =========================
sub beforeEditHandler {
    ### my ( $text, $topic, $web, $meta ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::beforeEditHandler( $_[2].$_[1] )" ) if $debug;

    return unless $prefNeedsWorkflow;

    # This handler is called by the edit script just before presenting the edit text
    # in the edit box. Use it to process the text before editing.

    if (! $globAllowEdit) {
      throw TWiki::OopsException( 'accessdenied',
				  def => 'topic_access',
				  web => $_[2],
				  topic => $_[1],
				  params => [ 'Edit topic', 'You are not permitted to edit this topic' ] );
      return 0;
    }
}

# =========================
sub beforeSaveHandler {
    ### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::beforeSaveHandler( $_[2].$_[1] )" ) if $debug;

    return unless $prefNeedsWorkflow;

    # This handler is called by TWiki::Store::saveTopic just before the save action.

    if (! $globAllowEdit && ! $CalledByMyself) {
      throw TWiki::OopsException( 'accessdenied',
				  def => 'topic_access',
				  web => $_[2],
				  topic => $_[1],
				  params => [ 'Save topic', 'You are not permitted to edit this topic' ] );
      return 0;
    }
}

# =========================

sub changeWorkflowState {
    my ($state, $form) = @_;

    my ($meta, $text) = TWiki::Func::readTopic( $web, $topic );
    $text = TWiki::Func::expandVariablesOnTopicCreation( $text ); #TW: really needed?
    my ($revdate, $revuser, $version, $revcmt) =  $meta->getRevisionInfo();

    #Debug("changeWorkflowState from $globCurrentState->{name} to $state");

    $globCurrentState->{name}=$state;
    $globCurrentState->{"LASTVERSION_$state"}="$version";
    $globCurrentState->{"LASTTIME_$state"} =
      TWiki::Func::formatTime( time(), undef, 'servertime' );

    $meta->remove( "WORKFLOW" );
    $meta->put( "WORKFLOW", $globCurrentState);

    my $mixedAlpha = $TWiki::regex{mixedAlpha};
    my $fmt = TWiki::Func::getPreferencesValue( "WORKFLOWHISTORYFORMAT" ) || '$state -- $date';
    $fmt =~ s/\"//go;
    $fmt =~ s/\$quot/\"/go;
    $fmt =~ s/\$n/<br>/go;
    $fmt =~ s/\$n\(\)/<br>/go;
    $fmt =~ s/\$n([^$mixedAlpha]|$)/\n$1/gos;
    $fmt =~ s/\$state/$globCurrentState->{name}/go;
    $fmt =~ s/\$wikiusername/$revuser->webDotWikiName()/geo;
    $fmt =~ s/\$date/$globCurrentState->{"LASTTIME_$state"}/geo;
    $globHistory .= "\r\n" if $globHistory;
    $globHistory .= $fmt;
    $meta->remove( "WORKFLOWHISTORY" );
    $meta->put( "WORKFLOWHISTORY", { value => $globHistory } );

    my $oldForm = $meta->get( 'FORM' );

    my $unlock=1;
    my $dontNotify=1;
    $CalledByMyself=1;
    my $error = TWiki::Func::saveTopic( $web, $topic, $meta, $text,
                                        { minor => $dontNotify } );
    if( $error ) {
        my $url = TWiki::Func::oops( $web, $topic, "saveerr", $error );
        TWiki::Func::redirectCgiQuery(undef, $url);
        return 0;
    }

    # If we want to have a form attached initially, we need to have
    # values in the topic, due to the TWiki form initialization
    # algorithm, or pass them here via URL parameters (take from
    # initialization topic)
    if ( $form && !($oldForm && $oldForm eq $form)) {
        my $url = TWiki::Func::getScriptUrl( $web, $topic, 'edit' );
        $url .= "?formtemplate=$form";
        TWiki::Func::redirectCgiQuery(undef, $url);
        return 0;
    }

}

sub getWorkflowState {
    my $meta = shift;
    return $meta->get('WORKFLOW');
}

sub Debug {
    my $text = shift;
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}: $text" );
}

#
# return a hash table representing the actions alowed by
# the current user. The hash-key is the possible action
# while the value is the next state.
#
sub parseWorkflow {
    my ($WorkflowWeb, $WorkflowTopic, $User, $CurrentState) = @_;
    my %workflow = ();
    my %workflowForm = ();
    my $WorkflowMessage = "";
    my $AllowEdit = 0;

    # take care that $CurrentState is a HASH table
    $CurrentState = {} unless defined($CurrentState);

    # the default state is the first row in the state table
    my $defaultState;
    my $CurrentStateIsValid = 0;

    # Read topic that defines the statemachine
    if( TWiki::Func::topicExists( $WorkflowWeb, $WorkflowTopic ) ) {
        my( $meta, $text ) = TWiki::Func::readTopic( $WorkflowWeb, $WorkflowTopic );

        my $inBlock = 0;
        # | *Current state* | *Action* | *Next state* | *Allowed* |
        foreach( split( /\n/, $text ) ) {
            if ( /^\s*\|.*State[^|]*\|.*Action[^|]*\|.*Next State[^|]*\|.*Allowed[^|]*\|/ ) {
                # from now on, we are in the TRANSITION table
                $inBlock = 1;
            } elsif ( /^\s*\|.*State[^|]*\|.*Allow Edit[^|]*\|.*Message[^|]*\|/ ) {
                # from now on, we are in the STATE table
                $inBlock = 2;

            } elsif ( /^(\t+\*\sSet\s)([A-Za-z]+)(\s\=\s*)(.*)$/ ) {
                # store preferences
                $globPreferences{$2}=$4;
            } elsif( ($inBlock == 1) && s/^\s*\|//o ) {
                # read row in TRANSITION table
                my( $state, $action, $next, $allowed, $form ) = split( /\s*\|\s*/ );
                $state = _cleanField($state);
                if (UserIsAllowed($User, $allowed) && ($state eq $CurrentState->{name})) { 
                    # store the transition in user's workflow 
                    $workflow{$action} = $next;
                    $workflowForm{$action} = $form;
                }

            } elsif( ($inBlock == 2) && s/^\s*\|//o ) {
                # read row in STATE table
                my( $state, $allowedit, $message ) = split( /\s*\|\s*/ );
                $state = _cleanField($state);
                #Debug("STATE: '$state', $allowedit, $message  CurrentState: '$CurrentState->{name}'");

                # the first state in the table defines the default state
                if (!defined($defaultState)) {
                    $defaultState=$state;
                    $CurrentState->{name} = $state unless defined($CurrentState->{name});
                }
                if ($state eq $CurrentState->{name}) {
                    $CurrentStateIsValid=1;
                    $WorkflowMessage=$message;
                    if (UserIsAllowed($User, $allowedit)) { 
                        $AllowEdit = 1;
                    }
                }
            } else {
                $inBlock = 0;
            }
        }

        # we need to treat the case that the workflow states have changed and that the 
        # status written in the document is not valid anymore. In this case we go back to 
        # the default status!
        if (!$CurrentStateIsValid && defined($defaultState)) {
            $CurrentState->{name}=$defaultState;
            return parseWorkflow($WorkflowWeb, $WorkflowTopic, $User, $CurrentState);
        }
    } else {
        # FIXME - do what if there is an error?
    }

    return ( \%workflow, $CurrentState, $WorkflowMessage, $AllowEdit, \%workflowForm );
}

# finds out if the user $User is allowed to do something
sub UserIsAllowed {
    my ($User, $allow) = @_;

    # Always allow members of the admin group to edit
    if ( $User->isAdmin() ) {
      return 1;
    }

    if ( defined( $allow ) && $allow ) {
      return 0 if $allow =~ /^\s*nobody\s*$/;
      return $User->isInList( $allow );
    }

    # user IS allowed!
    return 1;

}

sub _cleanField {
    my( $text ) = @_;
    $text = "" if( ! $text );
    $text =~ s/^\s*//go;
    $text =~ s/\s*$//go;
    $text =~ s/[^A-Za-z0-9_\.]//go; # Need do for web.topic
    return $text;
}

sub getWebTopicName {
    my( $theWebName, $theTopicName ) = @_;
    $theTopicName =~ s/%USERSWEB%/$theWebName/go;
    $theTopicName =~ s/%SYSTEMWEB%/$theWebName/go;
    if( $theTopicName =~ /[\.]/ ) {
        $theWebName = "";  # to suppress warning
    } else {
        $theTopicName = "$theWebName\.$theTopicName";
    }
    return $theTopicName;
}

1;
