#
# Copyright (C) 2002 Motorola - All rights reserved
# Copyright (C) 2004-2005 Crawford Currie http://c-dot.co.uk
#
# TWiki extension that adds tags for action tracking
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
package TWiki::Plugins::ActionTrackerPlugin;

use strict;
use Assert;
use Error qw( :try );

require TWiki::Func;
require TWiki::Plugins;

use vars qw( $VERSION $RELEASE $initialised $SHORTDESCRIPTION );

$VERSION = '$Rev: 16657 $';
$RELEASE = '21 May 2007';
$SHORTDESCRIPTION = 'Adds support for action tags in topics, and automatic notification of action statuses';
$initialised = 0;

my $doneHeader = 0;
my $actionNumber = 0;
my $defaultFormat;

# Map default options
my $options;

sub initPlugin {

    # COVERAGE OFF standard plugin code

    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( 'Version mismatch between ActionTrackerPlugin and Plugins.pm $TWiki::Plugins::VERSION. 1.026 required.' );
    }
    # COVERAGE ON

    $initialised = 0;
    $doneHeader = 0;

    TWiki::Func::registerRESTHandler( 'update', \&_updateRESTHandler );
    TWiki::Func::registerTagHandler(
        'ACTIONSEARCH', \&_handleActionSearch, 'context-free');

    return 1;
};

sub commonTagsHandler {
    my( $otext, $topic, $web, $meta ) = @_;

    return unless ( $_[0] =~ m/%ACTION.*{.*}%/o );

    return unless _lazyInit($web, $topic);

    my $debug = '';
    $debug = '_src' if DEBUG;

    TWiki::Func::addToHEAD('ACTIONTRACKERPLUGIN_CSS', <<HERE);
<link rel="stylesheet" href="$options->{CSS}" type="text/css" media="all" />
HERE
    TWiki::Func::addToHEAD('ACTIONTRACKERPLUGIN_JS', <<HERE);
<script type='text/javascript' src='%PUBURLPATH%/%SYSTEMWEB%/ActionTrackerPlugin/atp$debug.js'></script>
HERE

    # Format actions in the topic.
    # Done this way so we get tables built up by
    # collapsing successive actions.
    my $as = TWiki::Plugins::ActionTrackerPlugin::ActionSet::load(
        $web, $topic, $otext, 1);
    my $actionGroup;
    my $text = '';

    foreach my $entry (@{$as->{ACTIONS}}) {
        if (ref($entry)) {
            if (!$actionGroup) {
                $actionGroup =
                  new TWiki::Plugins::ActionTrackerPlugin::ActionSet();
            }
            $actionGroup->add($entry);
        } elsif ($entry =~ /(\S|\n\s*\n)/s) {
            if ($actionGroup) {
                $text .= $actionGroup->formatAsHTML(
                    $defaultFormat, 'name',
                    $options->{USENEWWINDOW},
                    'atpDef');
                $actionGroup = undef;
            }
            $text .= $entry;
        }
    }
    if ( $actionGroup ) {
        $text .=
          $actionGroup->formatAsHTML( $defaultFormat, 'name',
                                    $options->{USENEWWINDOW}, 'atpDef' );
    }

    $_[0] = $text;
    # COVERAGE OFF debug only
    if ( $options->{DEBUG} ) {
        $_[0] =~ s/%ACTIONNOTIFICATIONS{(.*?)}%/_handleActionNotify($web, $1)/geo;
    }
    # COVERAGE ON

}

# This handler is called by the edit script just before presenting
# the edit text in the edit box.
# We use it to populate the actionform.tmpl template, which is then
# inserted in the edit.action.tmpl as the %UNENCODED_TEXT%.
# We process the %META fields from the raw text of the topic and
# insert them as hidden fields in the form, so the topic is
# fully populated. This allows us to call either 'save' or 'preview'
# to terminate the edit, as selected by the NOPREVIEW parameter.
sub beforeEditHandler {
    #my( $text, $topic, $web, $meta ) = @_;

    if( TWiki::Func::getSkin() =~ /\baction\b/ ) {
        return _beforeActionEdit(@_);
    } else {
        return _beforeNormalEdit(@_);
    }
}

sub _beforeNormalEdit {
    #my( $text, $topic, $web, $meta ) = @_;
    # Coarse method of testing if modern action syntax is used
    my $oc = scalar( $_[0] =~ m/%ACTION{.*?}%/g );
    my $cc = scalar( $_[0] =~ m/%ENDACTION%/g );

    if ($cc < $oc) {
        return unless _lazyInit($_[2], $_[1]);

        my $as = TWiki::Plugins::ActionTrackerPlugin::ActionSet::load(
            $_[2], $_[1], $_[0], 1);
        $_[0] = $as->stringify();
    }
}

sub _beforeActionEdit {
    my( $text, $topic, $web, $meta ) = @_;

    return unless _lazyInit($web, $topic);

    my $query = TWiki::Func::getCgiQuery();

    my $uid = $query->param( 'atp_action' );
    return unless defined $uid;

    # actionform.tmpl is a sub-template inserted into the parent template
    # as %TEXT%. This is done so we can use the standard template mechanism
    # without screwing up the content of the subtemplate.
    my $tmpl = TWiki::Func::readTemplate( 'actionform',
                                          TWiki::Func::getSkin());

    my $date = TWiki::Func::formatTime( time(), undef, 'gmtime' );

    die unless ($date);

    $tmpl =~ s/%DATE%/$date/go;
    my $user = TWiki::Func::getWikiUserName();
    $tmpl =~ s/%WIKIUSERNAME%/$user/go;
    $tmpl = TWiki::Func::expandCommonVariables( $tmpl, $topic, $web );
    $tmpl = TWiki::Func::renderText( $tmpl, $web );

    # The 'command' parameter is used to signal to the afterEditHandler and
    # the beforeSaveHandler that they have to handle the fields of the
    # edit differently
    my $fields = CGI::hidden( -name=>'closeactioneditor', -value=>1 );
    $fields .= CGI::hidden( -name=>'cmd', -value=>"" );

    # write in hidden fields
    if( $meta ) {
        $meta->forEachSelectedValue( qr/FIELD/, undef, \&_hiddenMeta,
                                     { text => \$fields } );
    }

    # Find the action.
    my $as = TWiki::Plugins::ActionTrackerPlugin::ActionSet::load(
        $web, $topic, $text, 1);
    my ( $action, $pre, $post ) = $as->splitOnAction( $uid );
    my $pretext = $pre->stringify();
    my $posttext = $post->stringify();

    $fields .= CGI::hidden( -name=>'pretext', -value=>$pretext );
    $fields .= CGI::hidden( -name=>'posttext', -value=>$posttext );

    $tmpl =~ s/%UID%/$uid/go;

    my $submitCmd = "preview";
    my $submitCmdName = "Preview";
    my $submitScript = "";
    my $cancelScript = "";
    my $submitCmdOpt = "";

    if( $options->{NOPREVIEW} ) {
        $submitCmd = "save";
        $submitCmdName = "Save";
        $submitCmdOpt = "?unlock=on";
        if ( $options->{USENEWWINDOW} ) {
            # I'd like close the subwindow here, but not sure how. Like this,
            # the ONCLICK overrides the ACTION and closes the window before
            # the POST is done. All the various solutions I've found on the
            # web do something like "wait x seconds" before closing the
            # subwindow, but this seems very risky.
            #$submitScript = "onclick=\"document.form.submit();window.close();return true\"";
        }
    }
    if ( $options->{USENEWWINDOW} ) {
        $cancelScript = "onclick=\"window.close();\"";
    }

    $tmpl =~ s/%CANCELSCRIPT%/$cancelScript/go;
    $tmpl =~ s/%SUBMITSCRIPT%/$submitScript/go;
    $tmpl =~ s/%SUBMITCMDNAME%/$submitCmdName/go;
    $tmpl =~ s/%SUBMITCMDOPT%/$submitCmdOpt/go;
    $tmpl =~ s/%SUBMITCOMMAND%/$submitCmd/go;

    my $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format(
        $options->{EDITHEADER},
        $options->{EDITFORMAT},
        $options->{EDITORIENT},
        "", "" );
    my $editable = $action->formatForEdit( $fmt );
    $tmpl =~ s/%EDITFIELDS%/$editable/o;

    $tmpl =~ s/%EBH%/$options->{EDITBOXHEIGHT}/go;
    $tmpl =~ s/%EBW%/$options->{EDITBOXWIDTH}/go;

    $text = $action->{text};
    # Process the text so it's nice to edit. This gets undone in Action.pm
    # when the action is saved.
    $text =~ s/^\t/   /gos;
    $text =~ s/<br( \/)?>/\n/gios;
    $text =~ s/<p( \/)?>/\n\n/gios;

    $tmpl =~ s/%TEXT%/$text/go;
    $tmpl =~ s/%HIDDENFIELDS%/$fields/go;

    $_[0] = $tmpl;

    # Add styles and javascript for the calendar
    TWiki::Func::addToHEAD(
        'ATP_CSS',
        '<style type="text/css" media="all">@import url("%ACTIONTRACKERPLUGIN_CSS%");</style>');

    use TWiki::Contrib::JSCalendarContrib;
    if( $@ || !$TWiki::Contrib::JSCalendarContrib::VERSION ) {
        TWiki::Func::writeWarning('JSCalendarContrib not found '.$@);
    } else {
        TWiki::Contrib::JSCalendarContrib::addHEAD( 'twiki' );
    }
}

sub _hiddenMeta {
    my( $value, $options ) = @_;

    my $name = $options->{_key};
    ${$options->{text}} .= CGI::hidden( -name => $name, -value => $value );
    return $value;
}

# This handler is called by the preview script just before
# presenting the text.
# The skin name is passed over from the original invocation of
# edit so if the skin is "action" we know we have been editing
# an action and have to recombine fields to create the
# actual text.
# Metadata is handled by the preview script itself.
sub afterEditHandler {
    ### my ( $text, $topic, $web ) = @_;

    my $query = TWiki::Func::getCgiQuery();
    return unless ( $query->param( 'closeactioneditor' ));

    return unless _lazyInit($_[2], $_[1]);

    my $pretext = $query->param( 'pretext' ) || "";
    # Fix from RichardBaar 8/10/03 for Mozilla
    my $char = chop( $pretext );
    $pretext .= $char if ( $char ne "\n" );
    $pretext .= "\n";
    # end of fix from RichardBaar 8/10/03
    my $posttext = $query->param( 'posttext' ) || "";

    # count the previous actions so we get the right action number
    my $an = 0;
    my $tmp = "$pretext";
    while ( $tmp =~ s/%ACTION{.*?}%//o ) {
        $an++;
    }

    my $action =
      TWiki::Plugins::ActionTrackerPlugin::Action::createFromQuery(
          $_[2], $_[1], $an, $query );

    $action->populateMissingFields();

    my $text = $action->stringify();
    $text = "$pretext$text\n$posttext"; 

    # take the opportunity to fill in the missing fields in actions
    _addMissingAttributes( $text, $_[1], $_[2] );

    $_[0] = $text;
}

# Process the actions and add UIDs and other missing attributes
sub beforeSaveHandler {
    my( $text, $topic, $web ) = @_;

    return unless $text;

    return unless _lazyInit($web, $topic);

    my $query = TWiki::Func::getCgiQuery();
    return unless ( $query ); # Fix from GarethEdwards 13 Jun 2003

    if ( $query->param( 'closeactioneditor' )) {
        # this is a save from the action editor
        # Strip pre and post metadata from the text
        my $premeta = "";
        my $postmeta = "";
        my $inpost = 0;
        my $text = "";
        foreach my $line ( split( /\r?\n/, $_[0] ) ) {
            if( $line =~ /^%META:[^{]+{[^}]*}%/ ) {
                if ( $inpost) {
                    $postmeta .= "$line\n";
                } else {
                    $premeta .= "$line\n";
                }
            } else {
                $text .= "$line\n";
                $inpost = 1;
            }
        }
        # compose the text
        afterEditHandler( $text, $topic, $web );
        # reattach the metadata
        $_[0] = $premeta . $text . $postmeta;
    } else {
        # take the opportunity to fill in the missing fields in actions
        _addMissingAttributes( $_[0], $topic, $web );
    }
}

# PRIVATE Add missing attributes to all actions that don't have them
sub _addMissingAttributes {
    #my ( $text, $topic, $web ) = @_;
    my $text = "";
    my $descr;
    my $attrs;
    my $gathering;
    my $processAction = 0;
    my $an = 0;
    my %seenUID;

    my $as = TWiki::Plugins::ActionTrackerPlugin::ActionSet::load(
        $_[2], $_[1], $_[0], 1);

    foreach my $action (@{$as->{ACTIONS}}) {
        next unless ref($action);
        $action->populateMissingFields();
        if ( $seenUID{$action->{uid}} ) {
            # This can happen if there has been a careless
            # cut and paste. In this case, the first instance
            # of the action gets the old UID. This may banjax
            # change notification, but it's better than the
            # alternative!
            $action->{uid} = $action->getNewUID();
        }
        $seenUID{$action->{uid}} = 1;
    }
    $_[0] = $as->stringify();
}

# =========================
# Perform filtered search for all actions
sub _handleActionSearch {
    my( $session, $attrs, $topic, $web ) = @_;

    return unless _lazyInit($web, $topic);

    # use default format unless overridden
    my $fmt;
    my $fmts = $attrs->remove( 'format' );
    my $hdrs = $attrs->remove( 'header' );
    my $foot = $attrs->remove( 'footer' );
    my $sep = $attrs->remove( 'separator' );
    my $orient = $attrs->remove( 'orient' );
    my $sort = $attrs->remove( 'sort' );
    if ( defined( $fmts ) || defined( $hdrs ) || defined( $orient )) {
        $fmts = $defaultFormat->getFields() unless ( defined( $fmts ));
        $hdrs = $defaultFormat->getHeaders() unless ( defined( $hdrs ));
        $orient = $defaultFormat->getOrientation() unless ( defined( $orient ));
        $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format( $hdrs, $fmts, $orient, '', '' );
    } else {
        $fmt = $defaultFormat;
    }

    my $actions = TWiki::Plugins::ActionTrackerPlugin::ActionSet::allActionsInWebs( $web, $attrs, 0 );
    $actions->sort( $sort );
    return $actions->formatAsHTML( $fmt, 'href', $options->{USENEWWINDOW},
                                   'atpSearch' );
}

# Lazy initialize of plugin 'cause of performance
sub _lazyInit {
    my ($web, $topic) = @_;

    return 1 if $initialised;

    eval {
        require TWiki::Attrs;
        require TWiki::Plugins::ActionTrackerPlugin::Options;
        require TWiki::Plugins::ActionTrackerPlugin::Action;
        require TWiki::Plugins::ActionTrackerPlugin::ActionSet;
        require TWiki::Plugins::ActionTrackerPlugin::Format;
    };
    if ($@) {
        TWiki::Func::writeWarning("ActionTrackerPlugin: init failed $@");
        return 0;
    }

    $options = TWiki::Plugins::ActionTrackerPlugin::Options::load(
        $web, $topic);

    $defaultFormat = new TWiki::Plugins::ActionTrackerPlugin::Format(
        $options->{TABLEHEADER},
        $options->{TABLEFORMAT},
        $options->{TABLEORIENT},
        $options->{TEXTFORMAT},
        $options->{NOTIFYCHANGES} );

    if( $options->{EXTRAS} ) {
        my $e = TWiki::Plugins::ActionTrackerPlugin::Action::extendTypes(
            $options->{EXTRAS} );
        # COVERAGE OFF safety net
        if ( defined( $e )) {
            TWiki::Func::writeWarning( "- TWiki::Plugins::ActionTrackerPlugin ERROR $e" );
        }
        # COVERAGE ON
    }

    $initialised = 1;

    return 1;
}

# PRIVATE return formatted actions that have changed in all webs
# Debugging only
# COVERAGE OFF debug only
sub _handleActionNotify {
    my ( $web, $expr ) = @_;

    eval 'require TWiki::Plugins::ActionTrackerPlugin::ActionNotify';
    if( $@ ) {
        TWiki::Func::writeWarning("ATP: $@");
        return;
    }

    my $text = TWiki::Plugins::ActionTrackerPlugin::ActionNotify::doNotifications( $web, $expr, 1 );

    $text =~ s/<html>/<\/pre>/gios;
    $text =~ s/<\/html>/<pre>/gios;
    $text =~ s/<\/?body>//gios;
    return "<!-- from an --> <pre>$text</pre> <!-- end from an -->";
}
# COVERAGE ON

sub _updateRESTHandler {
    my $session = shift;
    my $query = TWiki::Func::getCgiQuery();
    try {
        my $topic = $query->param('topic');
        my $web;
        ($web, $topic) = TWiki::Func::normalizeWebTopicName(undef, $topic);
        _lazyInit($web, $topic);
        _updateSingleAction(
            $web, $topic,
            $query->param('uid'),
            $query->param('field') => $query->param('value'));
        print CGI::header('text/plain', 200); # simple message
    } catch Error::Simple with {
        my $e = shift;
        print CGI::header('text/plain', 500);
        print $e->{-text};
    } catch TWiki::AccessControlException with {
        my $e = shift;
        print CGI::header('text/plain', 500);
        print $e->stringify();
    };
    return undef;
}

sub _updateSingleAction {
    my ( $web, $topic, $uid, %changes ) = @_;

    my ($meta, $text) = TWiki::Func::readTopic($web, $topic);

    my $descr;
    my $attrs;
    my $gathering;
    my $processAction = 0;
    my $an = 0;
    my %seenUID;

    my $as = TWiki::Plugins::ActionTrackerPlugin::ActionSet::load(
        $web, $topic, $text, 1);

    foreach my $action (@{$as->{ACTIONS}}) {
        if (ref($action)) {
            if ($action->{uid} == $uid) {
                foreach my $key (keys %changes) {
                    $action->{$key} = $changes{$key};
                }
            }
        }
    }
    TWiki::Func::saveTopic($web, $topic, $meta, $as->stringify(),
                           { comment => 'atp save' });
}

1;
