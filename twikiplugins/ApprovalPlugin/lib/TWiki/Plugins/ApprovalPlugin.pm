# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2007 Andrew Jones, andrewjones86@googlemail.com
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
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

package TWiki::Plugins::ApprovalPlugin;

use strict;

use vars qw( $VERSION
             $RELEASE 
             $SHORTDESCRIPTION 
             $debug 
             $pluginName 
             $NO_PREFS_IN_TOPIC
             $defWeb
             $defTopic
             $CalledByMyself
             $globControlled
             $globCurrentState
             $globPrefs
             $globHistory
             $globTransition );

$VERSION = '$Rev: 0 (08 Jul 2007) $';
$RELEASE = 'TWiki-4.2';
$SHORTDESCRIPTION = 'Defines a set of states for one more or topics, with each state requiring approval by one or more users.';
$NO_PREFS_IN_TOPIC = 1;

$pluginName = 'ApprovalPlugin';

# =========================
sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # handles the 'APPROVAL' tag
    TWiki::Func::registerTagHandler( 'APPROVAL', \&_handleTag);

    my $prefApproval = TWiki::Func::getPreferencesValue( "APPROVALDEFINITION" ) || 0;
    if( $prefApproval ){
        _Debug("$web.$topic is under approval control");
        $globControlled = 1;
    } else {
        # not under approval control
        $globControlled = 0;
        return 1;
    }

    ($defWeb, $defTopic) = 
        TWiki::Func::normalizeWebTopicName( $web, $prefApproval );

    unless ( TWiki::Func::topicExists( $defWeb, $defTopic ) ){
        _Warn("$defWeb.$defTopic does not exist. Called by $web.$topic");
        return 1;
    }

    # get current state from topic
    _getMeta($web, $topic);

    # parse the approval definition topic
    _parseApprovalDef($defWeb, $defTopic);
    
    return 1;
}

sub _parseApprovalDef {
    my ($web, $topic) = @_;

    $globTransition = undef;

    my( undef, $text ) = TWiki::Func::readTopic( $web, $topic );

    my $inBlock = 0;
    my $defaultState;
    foreach( split( /\n/, $text ) ){
        if( /^\s*\|.*State[^|]*\|.*Action[^|]*\|.*Next State[^|]*\|.*Allowed[^|]*\|/ ){
            # in the TRANSITION table
            $inBlock = 1;
        } elsif( /^\s*\|.*State[^|]*\|.*Allow Edit[^|]*\|.*Message[^|]*\|/ ){
            # in the STATE table
            $inBlock = 2;
            
        } elsif ( /^(\s*\* Set )([A-Za-z]+)( \= *)(.*)$/ ) {
            # preference
            my $expandedPref = _expandVars( $4 );
            $globPrefs->{$2} = $expandedPref;

        } elsif( ($inBlock == 1) && s/^\s*\|//o ) {
            # read row in TRANSITION table
            my( $state, $action, $next, $allowed, $notify, $signoff ) = split( /\s*\|\s*/ );
            $state = _cleanField($state);

            if( $state eq $globCurrentState->{name} ){
                $allowed = _expandVars($allowed);
                if( $notify =~ /yes|on/i ){
                    $notify = 1;
                } else {
                    $notify = 0;
                }
                $signoff =~ s/%//;
                # Counts the amount of state reviewers for use in signoffs
		my @allowedUsers = split( /\s*,\s*/, $allowed );
                my $totalAllowed = scalar( @allowedUsers );

                $globTransition->{$action} = {
                    'next' => $next,
                    'allowed' => $allowed,
                    'notify' => $notify,
                    'signoff' => $signoff,
                    'totalallowed' => $totalAllowed
                };
            }
        } elsif( ($inBlock == 2) && s/^\s*\|//o ){
            # read row in STATE table
            my( $state, $allowedit, $message ) = split( /\s*\|\s*/ );
            $state = _cleanField($state);

            if (!defined($defaultState)) {
                $defaultState = $state;
                $globCurrentState->{name} = $state unless defined($globCurrentState->{name});
            }

            if( $state eq $globCurrentState->{name} ){
                $allowedit = _expandVars($allowedit);
                $globCurrentState->{allowedit} = $allowedit;
                $globCurrentState->{message} = $message;
            }
        } else {
            $inBlock = 0;
        }
    }
}

# =========================
sub _handleTag {

    return _Return('This topic is not under approval control.', 1) unless $globControlled;

    my $action = $_[1]->{action} || $_[1]->{_DEFAULT};

    for( $action ){
        /pref/i and return $globPrefs->{ $_[1]->{name} } || 
            _Return("Preference '$_[1]->{name}' not found in definition topic.", 1), last;
        /message/i and return $globCurrentState->{message} ||
            'No message found for current state.', last;
        /reviewed/i and return $globCurrentState->{reviewedby} ||
            'No one has reviewed the current state.', last;
        /history/i and return $globHistory || '', last;
        /transition/i and return &_createTransitionForm( $_[3], $_[2] ), last;
        return _Return('No valid action was found in this tag.', 1);
    }
}

# creates the form to change state
sub _createTransitionForm {

    return _Return('You have already reviewed this state.')
        if( $globCurrentState->{reviewedby} && _userInList( $globCurrentState->{reviewedby} ) );

    my( $web, $topic ) = @_;
    my $user = TWiki::Func::getWikiName();

    return _Return('You must have CHANGE permission on this topic to change state.', 1)
        if(! TWiki::Func::checkAccessPermission( 'CHANGE',
                                                 $user,
                                                 undef,
                                                 $topic,
                                                 $web,
                                                 undef ) );

    my @actions;
    while( my ($action, $params) = each(%$globTransition) ) {
        if( _userInList( $params->{allowed} ) ){
            push( @actions, $action );
        } else {
            # not permitted to change state
            my $logIn = '';
            my $guest = $TWiki::cfg{DefaultUserWikiName} || 'TWikiGuest';
            #if( TWiki::Func::isGuest() ){
            if( $user eq $guest ){
                my $url = TWiki::Func::getScriptUrl( $web, $topic, 'login' );
                $logIn = "You may need to <a href='$url'>log in</a>.";
            }
            return _Return('You are not permitted to change the state on this topic.' . $logIn);
        }
    }
    
    my $numberOfActions = scalar(@actions);

    if ($numberOfActions > 0) {
        # create most the form
        my $url = TWiki::Func::getViewUrl( $web, $topic );

        my $form = "<form id='ApprovalTransition' action='$url' method='post'>"
                 . "<input type='hidden' name='APPROVALSTATE' value='$globCurrentState->{name}' />";

        if ($numberOfActions == 1) {
            # create just a button
            $form .= "<input type='hidden' name='APPROVALACTION' value='$actions[0]' />"
                   . "<input type='submit' value='$actions[0]' class='twikiSubmit' />";
        } else {
            # create drop down box and button
            my $select;
            @actions = sort( @actions );    
            foreach my $action ( @actions ) {
                $select .= "<option value='$action'> $action </option>";
            }

            $form .= "<select name='APPROVALACTION'>$select</select> "
                   . "<input type='submit' value='Change status' class='twikiSubmit' />";
        }
        $form .= '</form>';
        return $form;
    }
    
    # no actions
    return _Return('No actions can be carried out on this topic.');
}

# =========================
sub beforeCommonTagsHandler {

    return unless $globControlled;

    my $query = TWiki::Func::getCgiQuery();
    return unless ($query);

    my $qAction;
    my $qState;

    return unless( $qState = $query->param( 'APPROVALSTATE' )
               and $qAction = $query->param( 'APPROVALACTION' ) );

    # so we only do this once
    $query->{ 'APPROVALSTATE' } = undef;
    $query->{ 'APPROVALACTION' } = undef;

    return unless( $globCurrentState->{name} eq $qState );

    # user has already reviewed this state
    return if( $globCurrentState->{reviewedby} && _userInList( $globCurrentState->{reviewedby} ) );
    # user not allowed to change state
    return if ( ! _userInList( $globTransition->{$qAction}->{allowed} ) );

    _changeState( $qAction, $qState, $_[2], $_[1] );

    return;
}

# change the state
sub _changeState {

    my( $qAction, $qState, $web, $topic ) = @_;

    my ($meta, $text) = TWiki::Func::readTopic( $web, $topic );
    my $user = TWiki::Func::getWikiUserName();
    my $changedState = 0;
    
    my $notify = $globTransition->{$qAction}->{notify};
    $notify = 0 if
        $TWiki::cfg{Plugins}{$pluginName}{DisableNotify};
    my $notifyCc;

    # state
    my $minSignoff = $globTransition->{$qAction}->{signoff} / 100 * $globTransition->{$qAction}->{totalallowed}
        if $globTransition->{$qAction}->{signoff};
    $globCurrentState->{signoff} ++;

    if( $minSignoff && $globCurrentState->{signoff} < $minSignoff ){
        # dont change state, just signoff
        _Debug("Concurrent Review - Minimum required to signoff: $minSignoff | Signoff's so far: ".$globCurrentState->{signoff});

        $globCurrentState->{reviewedby}
            ? $globCurrentState->{reviewedby} .= ', ' . $user
            : $globCurrentState->{reviewedby} = $user;
    } else {
        # change state, delete signoff
        $changedState = 1;
        $globCurrentState->{name} = $globTransition->{$qAction}->{next};

        if( $notify ){
            if( $globCurrentState->{reviewedby} ){
                foreach ( split( /,/, $globCurrentState->{reviewedby} ) ) {
                    $notifyCc .= TWiki::Func::wikiToEmail( $_ ) . ', ';
                }
                $notifyCc .= TWiki::Func::wikiToEmail( $user );
            } else {
                $notifyCc = TWiki::Func::wikiToEmail( $user );
            }
        }

        delete( $globCurrentState->{reviewedby} );
        delete( $globCurrentState->{signoff} );
    }

    # save meta data, but not allowedit or message 
    my $savedState = $globCurrentState;
    delete( $savedState->{allowedit} );
    delete( $savedState->{message} );
    $meta->remove( 'APPROVAL' );
    $meta->put( 'APPROVAL', $savedState );

    # history
    my $date = TWiki::Func::formatTime( time(), undef, 'servertime' );
    my $mixedAlpha = $TWiki::regex{mixedAlpha};
    my $fmt = TWiki::Func::getPreferencesValue( "APPROVALHISTORYFORMAT" ) || '$n$state -- $date';
    $fmt =~ s/\"//go;
    $fmt =~ s/\$quot/\"/go;
    $fmt =~ s!\$n!<br />!go;
    $fmt =~ s!\$n\(\)!<br />!go;
    $fmt =~ s/\$n([^$mixedAlpha]|$)/\n$1/gos;
    $fmt =~ s/\$state/$globTransition->{$qAction}->{next}/go;
    $fmt =~ s/\$wikiusername/$user/geo;
    $fmt =~ s/\$date/$date/geo;
    $globHistory .= "\r\n" if $globHistory;
    $globHistory .= $fmt;
    $meta->remove( "APPROVALHISTORY" );
    $meta->put( 'APPROVALHISTORY', { name => 'APPROVALHISTORY', value => $globHistory } );

    # save
    $CalledByMyself = 1;
    my $saveError = TWiki::Func::saveTopic( $web, $topic, $meta, $text,
                                        { minor => 1,
                                          dontlog => 1 } );
    if( $saveError ) {
        my $url = TWiki::Func::oops( $web, $topic, "saveerr", $saveError );
        TWiki::Func::redirectCgiQuery(undef, $url);
        return 0;
    }
    # need to parse the approval again here, so we can find out
    # who needs to be notified in the next state.
    # would need to parse the approval again anyway, as the state has
    # changed and so might the permissions and actions of the current user
    _parseApprovalDef($defWeb, $defTopic);

    if( $notify && $changedState && $globTransition ){
        # load template
        my $emailOut = TWiki::Func::readTemplate( 'approvalnotify' ) || <<'HERE';
From: %EMAILFROM%
To: %EMAILTO%
Cc: %EMAILCC%
Subject: %SUBJECT%
MIME-Version: 1.0
Content-Type: text/plain

ERROR: No approvalnotify notification template installed - please inform %WIKIWEBMASTER%
HERE

        my $notifyFrom = $TWiki::cfg{WebMasterEmail} ||
            TWiki::Func::getPreferencesValue( 'WIKIWEBMASTER' ) ||
                'twikiwebmaster@example.com';
        $emailOut =~ s/%EMAILFROM%/$notifyFrom/go;

        my $notifyTo;
        my $nextApprovers;
        while( my ($action, $params) = each(%$globTransition) ) {
            my $allowedUser = $params->{allowed};
            my $mainweb = TWiki::Func::getMainWebname();
            $allowedUser =~ s/$mainweb\.//g;
            # names of users who can approve the next state
            $nextApprovers 
                ? $nextApprovers .= ', ' . $allowedUser
                : $nextApprovers = $allowedUser;

            # email addresses of users who can approve the next state
            foreach ( split( /,/, $params->{allowed} ) ) {
                my $email = TWiki::Func::wikiToEmail( $_ );
                $notifyTo .= $email . ', '
                    unless $notifyTo =~ m/$email/;
            }
        }
        if( $globPrefs->{ADDITIONALNOTIFY} ){
            # additional users to be notified on state change
            # for example: line managers, project managers, stakeholders, etc
            foreach ( split( /,/, $globPrefs->{ADDITIONALNOTIFY} ) ){
                my $email = TWiki::Func::wikiToEmail( $_ );
                $notifyCc .=  ', ' . $email
                    unless $notifyCc =~ m/$email/
                        || $notifyTo =~ m/$email/;
            }
        }
        $emailOut =~ s/%EMAILTO%/$notifyTo/go;
        $emailOut =~ s/%EMAILCC%/$notifyCc/go;

        my $notifySubject = "Change of state at %WEB%.%TOPIC%";
        $emailOut =~ s/%SUBJECT%/$notifySubject/go;

        $emailOut =~ s/%WEB%/$web/go;
        $emailOut =~ s/%TOPIC%/$topic/go;

        $emailOut =~ s/%PREVSTATE%/$qState/go;
        $emailOut =~ s/%NEXTSTATE%/$globCurrentState->{name}/go;

        $emailOut =~ s/%NEXTSTATEAPPROVERS%/$nextApprovers/go;
        $emailOut =~ s/%NEXTSTATEMESSAGE%/'$globCurrentState->{message}'/go;

        my $url = TWiki::Func::getScriptUrl( $web, $topic, 'view' );
        $emailOut =~ s/%TOPICLINK%/$url/go;

        $emailOut = TWiki::Func::expandCommonVariables( $emailOut );

        if( $TWiki::cfg{Plugins}{$pluginName}{DebugNotify} ){
            # dont send email, just output in debug
            # used for testing
            _Debug('--- Email Notification ---' . "\n" . $emailOut );
        } else {
            my $mailError = TWiki::Func::sendEmail( $emailOut );
            if( $mailError ){ 
                _Warn( $mailError );
            }
        }
    }

    # log
    $changedState
        ? _Log("State changed from $qState to $globCurrentState->{name} by $user", $web, $topic)
        : _Log("$user has reviewed the state '$qState'", $web, $topic);
}

# =========================
# Check edit permissions for topics under control
sub beforeEditHandler {
    _checkEdit();
}

sub beforeSaveHandler {
    return 1 if $CalledByMyself;
    _checkEdit();
}

sub beforeAttachmentSaveHandler {
    _checkEdit();
}

sub _checkEdit {

    return unless $globControlled;

    if( ! _userInList( $globCurrentState->{allowedit}, 1 ) ){
        throw TWiki::OopsException( 'accessdenied',
                                    def => 'topic_access',
                                    web => $_[2],
                                    topic => $_[1],
                                    params => [ 'Edit topic', 'The %SYSTEMWEB%.ApprovalPlugin controls this topic. You are not permitted to edit this topic' ] );
    }
}

# =========================
sub _getMeta {
    my ($web, $topic) = @_;

    my( $meta, undef ) = TWiki::Func::readTopic( $web, $topic );
    $globCurrentState = $meta->get('APPROVAL');
    $globHistory = $meta->get('APPROVALHISTORY') || '';
    $globHistory = $globHistory->{value} if $globHistory;

    return;
}

# =========================
sub _cleanField {
    my( $text ) = @_;
    $text = "" if( ! $text );
    $text =~ s/^\s*//go;
    $text =~ s/\s*$//go;
    $text =~ s/[^A-Za-z0-9_\.]//go; # Need do for web.topic
    return $text;
}

sub _expandVars {
    my( $text ) = @_;
    $text =~ m/%.*%/
        ? return TWiki::Func::expandCommonVariables( $text )
        : return $text;

}
# =========================
# is user admin?
sub _isAdmin {
    if ( $TWiki::Plugins::VERSION > 1.11 ) {
        # 1.12 and over
        return TWiki::Func::isAnAdmin();
    } else {
        my $user = $TWiki::Plugins::SESSION->{user};
        return $user->isAdmin();
    }
}

# checks if user is in list
sub _userInList {
    my( $list, $allowAdmin ) = @_;

    return 1 unless $list;

    if( $allowAdmin ){
        return 1 if _isAdmin();
    }

    if ( $TWiki::Plugins::VERSION > 1.11 ) {
        # loop though list, check if group or user, if group find out if allowed. if user, check if its signed in user. else return 0
        foreach ( split( /,/, $list ) ) {
            if ( TWiki::Func::isGroup( $_ ) ) {
                $_ =~ s/ //;
                return 1 if TWiki::Func::isGroupMember( $_ );
            } else {
                my $user = TWiki::Func::getWikiName();
                return 1 if (  $_ =~ m/$user/ );
            }
        }
        return 0;
    } else {
        my $user = $TWiki::Plugins::SESSION->{user};
        return $user->isInList( $list );
    }
}

# =========================
sub _Return {
    my( $text, $error ) = @_;

    my $out = '<span class="ApprovalPluginMessage ';
    $out .= 'twikiAlert' if $error;
    $out .= '">';
    $out .= " %SYSTEMWEB%.$pluginName - $text";
    $out .= '</span>';

    return $out;
}

sub _Debug {
    my $text = shift;
    my $debug = $TWiki::cfg{Plugins}{$pluginName}{Debug} || 0;
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}: $text" ) if $debug;
}

sub _Warn {
    my $text = shift;
    TWiki::Func::writeWarning( "- TWiki::Plugins::${pluginName}: $text" );
}

# logs actions in the standard twiki log
sub _Log {
    my ( $text, $web, $topic ) = @_;

    my $logAction = $TWiki::cfg{Plugins}{$pluginName}{Log} || 1;

    if ($logAction) {
        $TWiki::Plugins::SESSION
        ? $TWiki::Plugins::SESSION->writeLog( "approval", "$web.$topic",
        $text )
        : TWiki::Store::writeLog( "approval", "$web.$topic", $text );
        TWiki::Store::writeLog( "approval", "$web.$topic", $text );
    }

    _Debug($text);
}

1;
