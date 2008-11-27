################################
# FoswikiBot Log Module        #
################################

package BotModules::FoswikiBotLog;
use vars qw(@ISA);
use Date::Format;
use LWP::Simple;
@ISA = qw(BotModules);
1;

sub RegisterConfig {
    my $self = shift;
    $self->SUPER::RegisterConfig(@_);
    $self->registerVariables(
      # [ name, save?, settable?, value ]
        #['logChan', 1, 1, '#twiki'],
        ['logLink', 1, 1, 'http://koala.ilog.fr/twikiirc/bin/irclogger_log/'],
        #['logLinks', 1, 1, {} ],
        ['logDateFmt', 1, 1, '%Y-%m-%d,%a'],
	['logjump', 1, 1, 1],
	#['homeLink', 1, 1, 'TWiki:TWiki/TWikiBotDev'],
    );
}

sub Help {
    my $self = shift;
    my ($event) = @_;
    return {
        '' => 'This is the FoswikiBot logging module. It provides commands to work with [LOGGER].',
        'logtime' => 'Requests that the bot provide a link to the current line of the [LOGGER] logs. It has one optional parameter, the channel name.',
    };
}

sub Told {
    my $self = shift;
    my ($event, $message) = @_;
    if ($message =~ /^\s*logtime\s*$/osi) {
        $self->say($event, &logTime($self, $event, $event->{'channel'}));
    } elsif ($message =~ /^\s*logtime\s*([^\s]+)\s*$/osi) {
        $self->say($event, &logTime($self, $event, $1));
    } else {
        return $self->SUPER::Told(@_);
    }
    return 0; # we've dealt with it, no need to do anything else.
}

sub Baffled {
    my $self = shift;
    my ($event, $message) = @_;
    if ($message =~ /^\s*logtime\s*/osi) {
    	$self->say($event, 'The \'logtime\' command only accepts one parameter, the channel name.');
    } else {
        return $self->SUPER::Baffled(@_);
    }
    return 0;
}

sub logTime {
    my ($self, $event, $channel) = @_;
    $channel =~ s/#//;

    if ( $channel eq '' ) { return 'No channel specified, try: logtime <channel>'; }
    #if ( not defined $self->{'logLinks'}->{$channel} ) { return "I don\'t have a log link for $channel"; }

    my @gmt = gmtime();
    my $logDate = strftime($self->{'logDateFmt'}, @gmt);
    my $ret  = $self->{'logLink'}.$channel;
       $ret .= "?date=$logDate";
    $self->debug("== $ret");
    
    my $content = get $ret;
    if (defined $content) {
        if ($content =~ m/^Cannot list channel/ ) { return "I can\'t find any logs for channel #$channel"; }
        my $sel = $content;
	$sel =~ s/.*\?date=$logDate&sel=([0-9l#]+)'/\1/s;
	$sel =~ s/([0-9l#]+).*/\1/s;
	if ( "$sel" ne "<html" ) { $ret .= "&sel=$sel"; }
    } else {
        $ret = "I'm unable to load the current log: $ret";
    }
    if ($event->{'channel'} ne "#$channel") { $ret .= " (channel #$channel)" }
    return $ret;
}

