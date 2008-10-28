#!/usr/bin/perl
use strict;

# PRE-COMMIT HOOK for TWiki Subversion
#
# The pre-commit hook tests that the item(s) listed in the checkin
# exist(s) in Bugs web, and is(are) in a state to receive checkins.
#
# STDERR ends up on the users' terminal

my $REPOS = $ARGV[0];
my $TXN = $ARGV[1];
my $BRANCH = $ARGV[2];

my $logmsg = `/usr/bin/svnlook log -t $TXN $REPOS`;

sub fail {
    my $message = shift;
    print STDERR <<EOF;
--------------------------------------------------------------
Illegal checkin to $REPOS:
$logmsg
$message
Log message must start with one or more names of Item
topics in the Bugs web
eg. Item12345: Item12346: example commit log
The topics *must* exist.
--------------------------------------------------------------
EOF
    exit 1;
}

fail("$BRANCH is disabled for checkins") if $BRANCH =~ /^(TWikiRelease04x00|DEVELOP)$/;

# See if this checkin is changing our branch
my $paths = `/usr/bin/svnlook changed -t $TXN $REPOS`;
exit 0 unless( $paths =~ m#\stwiki/branches/$BRANCH/#s );

local $/ = undef;
fail("No Bug item in log message")
  unless( $logmsg =~ /^Item[0-9]*:/ );

my @items;
$logmsg =~ s/\b(Item\d+):/push(@items, $1); '';/gem;
foreach my $item ( @items ) {
    fail "Bug item $item does not exist"
      unless( -f "data/Bugs/$item.txt" );
    open(F, "<data/Bugs/$item.txt") || die "Cannot open $item";
    my $text = <F>;
    my $state = "Closed";
    if( $text =~ /^%META:FIELD{name="CurrentState".*value="(.*?)"/m ) {
        $state = $1;
    }
    close(F);
    if( $state =~ /^(Waiting for Release|Closed|No Action Required)$/ ) {
        fail("$item is in $state state; cannot check in");
    }
}

exit 0;
