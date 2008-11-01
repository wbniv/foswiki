package TWiki::Plugins::ImmediateNotifyPlugin::SMTP;

use strict;
use TWiki::Net;

use vars
  qw($user $pass $server $twikiuser $web $topic $debug $warning $sendEmail);

# ========================
# initMethed - initializes a single notification method
# Parametrs $topic, $web, $user
#    $topic is the current topic
#    $web is the web in which the topic is stored
#    $user is the logged-in user
sub initMethod {
    ( $topic, $web, $twikiuser ) = @_;
    $server    = "localhost"; #TWiki::Func::getPreferencesValue("SMTPMAILHOST");
    $twikiuser = $_[2];
    $debug     = \&TWiki::Plugins::ImmediateNotifyPlugin::debug;
    $warning   = \&TWiki::Plugins::ImmediateNotifyPlugin::warning;
    $sendEmail = \&TWiki::Net::sendEmail;
    return defined($server);
}

# ========================
# handleNotify - handles notification for a single notification method
# Parameters: $users
#    $users is a hash reference of the form username->user topic text
sub handleNotify {
    my ($users)    = @_;
    my ($skin)     = TWiki::Func::getPreferencesValue("SKIN");
    my ($template) = TWiki::Func::readTemplate( 'smtp', 'immediatenotify' );
    my ($from)     = TWiki::Func::getPreferencesValue("WIKIWEBMASTER");

    $template =~ s/%EMAILFROM%/$from/go;
    $template =~ s/%WEB%/$web/go;
    $template =~ s/%TOPICNAME%/$topic/go;
    $template =~ s/%USER%/$twikiuser/go;

    $template = $TWiki::Plugins::SESSION->handleCommonTags( $template, $topic );

    foreach my $userName ( keys %$users ) {

        my ($to);

        my $user = $TWiki::Plugins::SESSION->{users}->findUser( $userName, $userName, 1 );
        if ($user) {
            foreach my $email ( $user->emails() ) {
                $to .= $email . ",";
            }
        }

        my $msg = $template;
        $msg =~ s/%EMAILTO%/$to/go;
        &$debug("- SMTP: Sending mail to $to ($userName)");

        my $twiki = new TWiki( $TWiki::cfg{DefaultUserLogin} );
        my $error = $twiki->{net}->sendEmail($msg);

    }
}

1; 