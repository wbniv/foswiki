# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (c) 2006 by Meredith Lesly, Kenneth Lavrsen
#
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

package TWiki::Plugins::SendEmailPlugin::Core;

# Always use strict to enforce variable scoping
use strict;
use TWiki::Func;
use TWiki::Plugins;

use vars qw( $debug $emailRE );

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
my $ERROR_TITLE               = ' <nop>%TWIKIWEB%.SendEmailPlugin send error ';
my $ERROR_BUTTON_LABEL        = 'Show error message';
my $ERROR_NOT_VALID_EMAIL     = '\'$EMAIL\' is not a valid e-mail address or account';
my $ERROR_EMPTY_TO_EMAIL      = 'You must pass a \'to\' e-mail address';
my $ERROR_EMPTY_FROM_EMAIL    = 'You must pass a \'from\' e-mail address';
my $ERROR_NO_FROM_PERMISSION  = 'No permission to send an e-mail from \'$EMAIL\'';
my $ERROR_NO_TO_PERMISSION    = 'No permission to send an e-mail to \'$EMAIL\'';
my $ERROR_NO_CC_PERMISSION    = 'No permission to cc an e-mail to \'$EMAIL\'';


=pod

writes a debug message if the $debug flag is set

=cut

sub writeDebug {
  TWiki::Func::writeDebug("SendEmailPlugin -- $_[0]") 
    if $debug;
}

=pod

some init steps

=cut

sub init {
  my $session = shift;
  $TWiki::Plugins::SESSION ||= $session;
  $debug = TWiki::Func::getPreferencesFlag("SENDEMAILPLUGIN_DEBUG");
  $emailRE = TWiki::Func::getRegularExpression('emailAddrRegex');
}


=pod

Invoked by bin/sendemail

=cut

sub sendEmail {
    my $session = shift;

    writeDebug("called sendEmail()");
    init($session);

    my $query = TWiki::Func::getCgiQuery();
    my $errorMessage = '';

    return finishSendEmail( $session, $ERROR_STATUS{'error'} ) 
      unless $query;

    # get TO
    my $to = $query->param('to') || $query->param('To');

    return finishSendEmail( $session, $ERROR_STATUS{'error'},
        $ERROR_EMPTY_TO_EMAIL ) unless $to;

    my @toEmails = ();
    foreach my $thisTo (split(/\s*,\s*/, $to)) {
      my $addrs;

      if ($thisTo =~ /$emailRE/) {
        # regular address
        $addrs = $thisTo;
      } else {
        # get from user info
        my $wikiName = TWiki::Func::getWikiName($thisTo);
        my @addrs = TWiki::Func::wikinameToEmails($wikiName);
        $addrs = $addrs[0] if @addrs;

        unless ($addrs) { 
          # no regular address and no address found in user info
         
          $errorMessage = $ERROR_NOT_VALID_EMAIL;
          $errorMessage =~ s/\$EMAIL/$thisTo/go;
          return finishSendEmail( $session, $ERROR_STATUS{'error'},
              $errorMessage);
        }
      }

      # validate TO
      if (!matchesPreference('ALLOW', 'MAILTO', $thisTo) || 
          matchesPreference('DENY', 'MAILTO', $thisTo)) {
        $errorMessage = $ERROR_NO_TO_PERMISSION;
        $errorMessage =~ s/\$EMAIL/$thisTo/go;
        TWiki::Func::writeWarning($errorMessage);
        return finishSendEmail( $session, $ERROR_STATUS{'error'},
          $errorMessage);
      }

      push @toEmails, $addrs;
    }
    $to = join(', ', @toEmails);
    writeDebug("to=$to");


    # get FROM
    my $from = $query->param('from') || $query->param('From');

    unless ($from) {
      # get from user settings
      my $emails = TWiki::Func::wikiToEmail();
      my @emails = split(/\s*,*\s/, $emails);
      $from = shift @emails if @emails;
    }

    unless ($from) {
      # fallback to webmaster
      $from = $TWiki::cfg{WebMasterEmail} || 
        TWiki::Func::getPreferencesValue('WIKIWEBMASTER')
    }

    # validate FROM
    return finishSendEmail( $session, $ERROR_STATUS{'error'},
        $ERROR_EMPTY_FROM_EMAIL ) unless $from;

    if (!matchesPreference('ALLOW', 'MAILFROM', $from) || 
        matchesPreference('DENY', 'MAILFROM', $from)) {
      $errorMessage = $ERROR_NO_FROM_PERMISSION;
      $errorMessage =~ s/\$EMAIL/$from/go;
      TWiki::Func::writeWarning($errorMessage);
      return finishSendEmail( $session, $ERROR_STATUS{'error'}, 
        $errorMessage);
    }

    unless ($from =~ m/$emailRE/) {
      $errorMessage = $ERROR_NOT_VALID_EMAIL;
      $errorMessage =~ s/\$EMAIL/$from/go;
      return finishSendEmail( $session, $ERROR_STATUS{'error'}, 
        $errorMessage );
    }
    writeDebug("from=$from");

    # get CC
    my $cc = $query->param('cc') || $query->param('CC') || '';

    if ($cc) {
      my @ccEmails = ();
      foreach my $thisCC (split(/\s*,\s*/, $cc)) {
        my $addrs;

        if ($thisCC =~ /$emailRE/) {
          # normal email address
          $addrs = $thisCC;
        
        } else {

          # get from user info
          my @addrs = TWiki::Func::wikinameToEmails($thisCC);
          $addrs = $addrs[0] if @addrs;

          unless ($addrs) {
            # no regular address and no address found in user info
         
            $errorMessage = $ERROR_NOT_VALID_EMAIL;
            $errorMessage =~ s/\$EMAIL/$thisCC/go;
            return finishSendEmail( $session, $ERROR_STATUS{'error'},
                $errorMessage);
          }
        }

        # validate CC
        if (!matchesPreference('ALLOW', 'MAILCC', $thisCC) || 
             matchesPreference('DENY', 'MAILCC', $thisCC)) {
          $errorMessage = $ERROR_NO_CC_PERMISSION;
          $errorMessage =~ s/\$EMAIL/$thisCC/go;
          TWiki::Func::writeWarning($errorMessage);
          return finishSendEmail( $session, $ERROR_STATUS{'error'},
            $errorMessage);
        }

        push @ccEmails, $addrs;
      }
      $cc = join(', ', @ccEmails);
      writeDebug("cc=$cc");
    }

    # get SUBJECT
    my $subject = $query->param('subject') || $query->param('Subject') || '';
    writeDebug("subject=$subject") if $subject;

    # get BODY
    my $body = $query->param('body') || $query->param('Body') || '';
    writeDebug("body=$body") if $body;

    # get template
    my $templateName = $query->param('template') || 'sendemail';
    my $template = TWiki::Func::readTemplate($templateName);
    unless ($template) {
      $template = <<'HERE';
From: %FROM%
To: %TO%
CC: %CC%
Subject: %SUBJECT%

%BODY%
HERE
    }

    # format email
    my $mail = $template;
    $mail =~ s/%FROM%/$from/go;
    $mail =~ s/%TO%/$to/go;
    $mail =~ s/%CC%/$cc/go;
    $mail =~ s/%SUBJECT%/$subject/go;
    $mail =~ s/%BODY%/$body/go;

    writeDebug("mail=\n$mail");

    # send email
    $errorMessage = TWiki::Func::sendEmail( $mail, $RETRY_COUNT );

    # finally
    my $errorStatus =
      $errorMessage ? $ERROR_STATUS{'error'} : $ERROR_STATUS{'noerror'};

    writeDebug("errorStatus=$errorStatus");
    my $redirectUrl = $query->param('redirectto');
    finishSendEmail( $session, $errorStatus, $errorMessage, $redirectUrl);
}

=pod

Checks if a given value matches a preferences pattern. The pref pattern
actually is a list of patterns. The function returns true if 
at least one of the patterns in the list matches.

=cut

sub matchesPreference {
  my ($mode, $key, $value) = @_;

  writeDebug("called matchesPreference($mode, $key, $value)");
  my $pattern;

  $pattern = TWiki::Func::getPreferencesValue(uc($mode.$key));
  $pattern = TWiki::Func::getPreferencesValue(uc('SendEmailPlugin_'.$mode.$key))
    unless defined $pattern;

  return ($mode =~ /ALLOW/i?1:0) unless $pattern;

  $pattern =~ s/^\s//o;
  $pattern =~ s/\s$//o;
  $pattern = '('.join(')|(', split(/\s*,\s*/, $pattern)).')';

  writeDebug("pattern=$pattern");

  return ($value =~ /$pattern/)?1:0;
}

=pod

=cut

sub handleSendEmailTag {
    my ( $session, $params, $topic, $web ) = @_;

    init();
    addHeader();

    my $query = TWiki::Func::getCgiQuery();
    return '' if !$query;

    my $errorStatus = $query->param($ERROR_STATUS_TAG);

    writeDebug("handleSendEmailTag; errorStatus=$errorStatus")
      if $errorStatus;

    return '' if !defined $errorStatus;

    my $feedbackSuccess = $params->{'feedbackSuccess'};

    unless (defined $feedbackSuccess) {
      $feedbackSuccess =
        TWiki::Func::getPreferencesValue(
          "SENDEMAILPLUGIN_EMAIL_SENT_SUCCESS_MESSAGE")
        || '';
    }
    $feedbackSuccess =~ s/^\s*(.*?)\s*$/$1/go;    # remove surrounding spaces

    my $feedbackError = $params->{'feedbackError'};
    unless (defined $feedbackError) {
      $feedbackError =
        TWiki::Func::getPreferencesValue(
          "SENDEMAILPLUGIN_EMAIL_SENT_ERROR_MESSAGE")
        || '';
    }

    my $userMessage =
      ( $errorStatus == $ERROR_STATUS{'error'} )
      ? $feedbackError
      : $feedbackSuccess;
    $userMessage =~ s/^\s*(.*?)\s*$/$1/go;        # remove surrounding spaces
    my $errorMessage = $query->param($ERROR_MESSAGE_TAG) || '';

    return wrapHtmlNotificationContainer( $userMessage, $errorStatus,
        $errorMessage, $topic, $web );
}

=pod

=cut

sub finishSendEmail {
    my ( $session, $errorStatus, $errorMessage, $redirectUrl ) = @_;

    my $query = TWiki::Func::getCgiQuery();

    writeDebug("_finishSendEmail errorStatus=$errorStatus;")
      if $errorStatus;

    $query->param( -name => $ERROR_STATUS_TAG, -value => $errorStatus )
      if $query;

    $errorMessage ||= '';
    writeDebug("_finishSendEmail errorMessage=$errorMessage;")
      if $errorMessage;

    $query->param( -name => $ERROR_MESSAGE_TAG, -value => $errorMessage )
      if $query;

    my $web   = $session->{webName};
    my $topic = $session->{topicName};
    my $origUrl = TWiki::Func::getScriptUrl($web, $topic, 'view');

    $query->param( -name => 'origurl', -value => $origUrl);

    my $section = $query->param(
      ($errorStatus == $ERROR_STATUS{'error'})?'errorsection':'successsection');

    $query->param( -name => 'section', -value => $section) 
      if $section;
      
    $redirectUrl ||= $origUrl;
    TWiki::Func::redirectCgiQuery( undef, $redirectUrl, 1 );

    # would pass '#'=>$NOTIFICATION_ANCHOR_NAME but the anchor removes
    # the ERROR_STATUS_TAG param
}

=pod

=cut

sub addHeader {

    my $header = <<'EOF';
<style type="text/css" media="all">
@import url("%PUBURL%/%TWIKIWEB%/SendEmailPlugin/sendemailplugin.css");
</style>
EOF
    TWiki::Func::addToHEAD( 'SENDEMAILPLUGIN', $header );
}

=pod

=cut

sub wrapHtmlNotificationContainer {
    my ( $text, $errorStatus, $errorMessage, $topic, $web ) = @_;

    my $cssClass = $NOTIFICATION_CSS_CLASS;
    $cssClass .= ' ' . $NOTIFICATION_ERROR_CSS_CLASS
      if ( $errorStatus == $ERROR_STATUS{'error'} );

    my $message = $text;

    if ( $errorMessage ) {
      if ( length $errorMessage < 256 ) {
          $message .= ' '.$errorMessage;
      } else {
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
    }

    return "#$NOTIFICATION_ANCHOR_NAME\n"
      . '<div class="'
      . $cssClass . '">'
      . $message
      . '</div>';
}


1;
