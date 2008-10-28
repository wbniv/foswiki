# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (c) 2006 by Meredith Lesly, Kenneth Lavrsen
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

package TWiki::Plugins::SendEmailPlugin;

# Always use strict to enforce variable scoping
use strict;
use TWiki::Func;

# $VERSION is referred to by TWiki, and is the only global variable that
# *must* exist in this package
use vars qw( $VERSION $RELEASE $debug $pluginName );
use vars qw( $successUserMessage $errorUserMessage $errorMessage $headerDone);

# This should always be $Rev: 11069$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 11069$';
$RELEASE = '1.1.3';

# Name of this Plugin, only used in this module
$pluginName = 'SendEmailPlugin';

$headerDone = 0;

my $RETRY_COUNT                  = 5;
my $ERROR_STATUS_TAG             = 'SendEmailErrorStatus';
my $ERROR_MESSAGE_TAG            = 'SendEmailErrorMessage';
my $NOTIFICATION_CSS_CLASS       = 'sendEmailPluginNotification';
my $NOTIFICATION_ERROR_CSS_CLASS = 'sendEmailPluginError';
my $NOTIFICATION_ANCHOR_NAME     = 'FormPluginNotification';
my %ERROR_STATUS                 = (
    'noerror' => 1,
    'error'   => 2,
);
my $ERROR_TITLE            = ' <nop>%SYSTEMWEB%.SendEmailPlugin send error ';
my $ERROR_BUTTON_LABEL     = 'Show error message';
my $ERROR_CONCAT           = ': ';
my $ERROR_NOT_VALID_EMAIL  = '\'$EMAIL\' is not an e-mail address';
my $ERROR_EMPTY_TO_EMAIL   = 'you must pass a \'to\' e-mail address';
my $ERROR_EMPTY_FROM_EMAIL = 'you must pass a \'from\' e-mail address';

=pod

=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    $debug = TWiki::Func::getPreferencesFlag("SENDEMAILPLUGIN_DEBUG");

    $successUserMessage =
      TWiki::Func::getPreferencesValue(
        "SENDEMAILPLUGIN_EMAIL_SENT_SUCCESS_MESSAGE")
      || '';

    $errorUserMessage =
      TWiki::Func::getPreferencesValue(
        "SENDEMAILPLUGIN_EMAIL_SENT_ERROR_MESSAGE")
      || '';

    TWiki::Func::registerTagHandler( 'SENDEMAIL', \&_handleSendEmailTag );

    # Plugin correctly initialized
    return 1;
}

=pod

Invoked by bin/sendemail

=cut

sub sendEmail {
    my $session = shift;

    my $to      = '';
    my $from    = '';
    my $cc      = '';
    my $subject = '';
    my $body    = '';

    TWiki::Func::writeDebug("sendEmail start") if $debug;

    my $query = TWiki::Func::getCgiQuery();
    return _finishSendEmail( $session, $ERROR_STATUS{'error'} ) if !$query;

    TWiki::Func::writeDebug("sendEmail query=$query") if $debug;

    $to = $query->param('to') || $query->param('To');
    TWiki::Func::writeDebug("sendEmail -- to=$to") if $to && $debug;

    my $emptyToEmailMessage = $ERROR_CONCAT . $ERROR_EMPTY_TO_EMAIL;
    return _finishSendEmail( $session, $ERROR_STATUS{'error'},
        $emptyToEmailMessage )
      if !$to;

    my $emailRE = TWiki::Func::getRegularExpression('emailAddrRegex');

    my $isToEmail = ( $to =~ m/$emailRE/ );
    my $notToEmailMessage = $ERROR_CONCAT . $ERROR_NOT_VALID_EMAIL;
    $notToEmailMessage =~ s/\$EMAIL/$to/go;
    return _finishSendEmail( $session, $ERROR_STATUS{'error'},
        $notToEmailMessage )
      if !$isToEmail;

         $from = $query->param('from')
      || $query->param('From')
      || $TWiki::cfg{WebMasterEmail}
      || TWiki::Func::getPreferencesValue('WIKIWEBMASTER');
    TWiki::Func::writeDebug("sendEmail -- from=$from") if $from && $debug;

    my $emptyFromEmailMessage = $ERROR_CONCAT . $ERROR_EMPTY_FROM_EMAIL;
    return _finishSendEmail( $session, $ERROR_STATUS{'error'},
        $emptyFromEmailMessage )
      if !$from;

    my $isFromEmail = ( $from =~ m/$emailRE/ );
    my $notFromEmailMessage = $ERROR_CONCAT . $ERROR_NOT_VALID_EMAIL;
    $notFromEmailMessage =~ s/\$EMAIL/$from/go;
    return _finishSendEmail( $session, $ERROR_STATUS{'error'},
        $notFromEmailMessage )
      if !$isFromEmail;

    my $ccParam = $query->param('cc') || $query->param('CC') || '';
    $cc = $ccParam if $ccParam;
    TWiki::Func::writeDebug("sendEmail -- cc=$cc") if $cc && $debug;
    my $subjectParam = $query->param('subject') || $query->param('Subject');
    $subject = $subjectParam if $subjectParam;
    TWiki::Func::writeDebug("sendEmail -- subject=$subject")
      if $subject && $debug;
    my $bodyParam = $query->param('body') || $query->param('Body') || '';
    $body = $bodyParam if $bodyParam;
    TWiki::Func::writeDebug("sendEmail -- body=$body") if $body && $debug;

    my $mail = <<'HERE';
From: %FROM%
To: %TO%
CC: %CC%
Subject: %SUBJECT%

%BODY%
HERE

    $mail =~ s/%FROM%/$from/go;
    $mail =~ s/%TO%/$to/go;
    $mail =~ s/%CC%/$cc/go;
    $mail =~ s/%SUBJECT%/$subject/go;
    $mail =~ s/%BODY%/$body/go;

    TWiki::Func::writeDebug("mail message=$mail") if $debug;

    my $error = TWiki::Func::sendEmail( $mail, $RETRY_COUNT );
    my $errorStatus =
      $error ? $ERROR_STATUS{'error'} : $ERROR_STATUS{'noerror'};

    TWiki::Func::writeDebug("errorStatus=$errorStatus") if $debug;

    _finishSendEmail( $session, $errorStatus, $error );
}

=pod

=cut

sub _handleSendEmailTag {
    my ( $session, $params, $topic, $web ) = @_;

    _addHeader();

    my $query = TWiki::Func::getCgiQuery();
    return '' if !$query;

    my $errorStatus = $query->param($ERROR_STATUS_TAG);

    TWiki::Func::writeDebug("_handleSendEmailTag; errorStatus=$errorStatus")
      if $errorStatus && $debug;

    return '' if !defined $errorStatus;

    my $feedbackSuccess = $params->{'feedbackSuccess'} || $successUserMessage;
    $feedbackSuccess =~ s/^\s*(.*?)\s*$/$1/go;    # remove surrounding spaces
    my $feedbackError = $params->{'feedbackError'} || $errorUserMessage;

    my $userMessage =
      ( $errorStatus == $ERROR_STATUS{'error'} )
      ? $feedbackError
      : $feedbackSuccess;
    $userMessage =~ s/^\s*(.*?)\s*$/$1/go;        # remove surrounding spaces
    my $errorMessage = $query->param($ERROR_MESSAGE_TAG) || '';

    return _wrapHtmlNotificationContainer( $userMessage, $errorStatus,
        $errorMessage, $topic, $web );
}

=pod

=cut

sub _finishSendEmail {
    my ( $session, $errorStatus, $error ) = @_;

    my $web   = $session->{webName};
    my $topic = $session->{topicName};

    my $query = TWiki::Func::getCgiQuery();

    TWiki::Func::writeDebug("_finishSendEmail errorStatus=$errorStatus;")
      if $errorStatus && $debug;
    TWiki::Func::writeDebug("_finishSendEmail errorMessage=$errorMessage;")
      if $errorMessage && $debug;

    $query->param( -name => $ERROR_STATUS_TAG, -value => $errorStatus )
      if $query;
    my $errorMessage = $error || '';
    $query->param( -name => $ERROR_MESSAGE_TAG, -value => $errorMessage )
      if $query;

    TWiki::Func::redirectCgiQuery( undef,
        TWiki::Func::getScriptUrl( $web, $topic, 'view' ), 1 );

    # would pass '#'=>$NOTIFICATION_ANCHOR_NAME but the anchor removes
    # the ERROR_STATUS_TAG param
}

=pod

=cut

sub _addHeader {

    return if $headerDone;

    my $header = <<'EOF';
<style type="text/css" media="all">
@import url("%PUBURL%/%SYSTEMWEB%/SendEmailPlugin/sendemailplugin.css");
</style>
EOF
    TWiki::Func::addToHEAD( 'SENDEMAILPLUGIN', $header );
    $headerDone = 1;
}

=pod

=cut

sub _wrapHtmlNotificationContainer {
    my ( $text, $errorStatus, $errorMessage, $topic, $web ) = @_;

    my $cssClass = $NOTIFICATION_CSS_CLASS;
    $cssClass .= ' ' . $NOTIFICATION_ERROR_CSS_CLASS
      if ( $errorStatus == $ERROR_STATUS{'error'} );

    my $message = $text;
    if ( $errorMessage && length $errorMessage < 256 ) {
        $message .= $errorMessage;
    }
    if ( $errorMessage && length $errorMessage > 256 ) {
        my $oopsUrl = TWiki::Func::getOopsUrl( $web, $topic, 'oopsgeneric' );
        $errorMessage = '<verbatim>' . $errorMessage . '</verbatim>';
        my $errorForm = <<'HERE';
<form enctype="application/x-www-form-urlencoded" name="mailerrorfeedbackform" action="%OOPSURL%" method="POST">
<input type="hidden" name="template" value="oopsgeneric" />
<input type="hidden" name="param1" value="%ERRORTITLE%" />
<input type="hidden" name="param2" value="%ERRORMESSAGE%" />
<input type="hidden" name="param3" value="" />
<input type="hidden" name="param4" value="" />
<input type="submit" class="twikiButton" value="%ERRORBUTTON%"  />
</form>
HERE
        $errorForm =~ s/%OOPSURL%/$oopsUrl/go;
        $errorForm =~ s/%ERRORTITLE%/$ERROR_TITLE/go;
        $errorForm =~ s/%ERRORMESSAGE%/$errorMessage/go;
        $errorForm =~ s/%ERRORBUTTON%/$ERROR_BUTTON_LABEL/go;
        $message .= ' ' . $errorForm;
    }

    return "#$NOTIFICATION_ANCHOR_NAME\n"
      . '<div class="'
      . $cssClass . '">'
      . $message
      . '</div>';
}

1;
