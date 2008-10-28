#!/usr/bin/perl
# Cron script that refreshes the develop installs
use strict;

my $BRANCH = $ARGV[0];
my $ROOT = $ENV{HOME};
my $COMMIT_FLAG = "$ROOT/svncommit";
my $UPDATE_FLAG = "$ROOT/update_in_progress";
my $LATEST = "$ROOT/twikisvn/pub/Bugs/latest_$BRANCH/rev.txt";

chdir("$ROOT/twikisvn") || die $!;

if( -e $UPDATE_FLAG) {
    exit 0;
}

# /tmp/svncommit is created by an svn hook on a checkin
# See post-commit.pl
if ( ! -f $COMMIT_FLAG ) {
    #print "No new updates; exiting\n";
    exit 0;
}

print "Update started at ",`date`;
print "Last update was to ",`cat $LATEST`;

open(F, ">$UPDATE_FLAG") || die $!;
print F time();
close(F);

eval {
    undef $/;
    print "Updating\n";
    my $rev = `svn update $ROOT/twikisvn`;

    # Remove all links before refreshing from the manifests
    print `find $ROOT/twikisvn -name Bugs -prune -o -type l -exec rm -f \\{\\} \\;`;
    print `perl pseudo-install.pl -link default`;

    # Copy the bin scripts over to cgi-bin
    print `cp $ROOT/twikisvn/bin/* $ROOT/public_html/cgi-bin/`;

    print "Updated $rev";
    $rev =~ s/^.*revision (\d+).*?$/$1/s;
    open(F, ">$LATEST") || die $!;
    print F "$rev\n";
    close(F);

    # Do this last just in case the update failed. If it is still there,
    # the cron will try again.
    unlink($COMMIT_FLAG);
};
my $e = $@;
unlink($UPDATE_FLAG);
die $e if $e;
