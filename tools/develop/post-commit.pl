#!/usr/bin/perl
# POST-COMMIT HOOK
#
#   [1] REPOS-PATH   (the path to this repository)
#   [2] REV          (the number of the revision just committed)
#
# Must be chdired to the tools subdirectory when this is run
#
use strict;

my $REPOS = $ARGV[0];
my $first = `cat ../lastupdate`;
chomp($first);
my $last = $ARGV[1] || `/usr/bin/svnlook youngest $REPOS`;
chomp($last);
my $BRANCH = $ARGV[2];

die unless $last;
die unless $BRANCH;

$first ||= ($last-1);

my @changes;
for (my $i = $first + 1; $i <= $last; $i++) {
    push( @changes,
          map { s/^.*?$BRANCH\///; $_ }
           grep { /twiki\/branches\/$BRANCH/ }
            split(/\n/, `/usr/bin/svnlook changed -r $i $REPOS` ));
}
exit 0 unless scalar( @changes );

sub _add {
   my( $cur, $rev, $changed ) = @_;
   return $cur if $cur =~ /\b$rev\b/;
   $$changed = 1;
   my @curr = split(/\s+/, $cur);
   push(@curr, $rev);
   return join(" ", sort @curr);
}

# Don't know where STDERR goes, so send it somewhere we can read it
open(STDERR, ">>../logs/post-commit.log") || die $!;
print STDERR "Post-Commit $first..$last in $REPOS\n";
$/ = undef;

for my $rev ($first..$last) {
    # Update the list of checkins for referenced bugs
    my $logmsg = `/usr/bin/svnlook log -r $rev $REPOS`;

    my @list;
    while( $logmsg =~ s/\b(Item\d+):// ) {
        push(@list, $1);
    }

    foreach my $item (@list) {
        my $fi = "data/Bugs/$item.txt";
        my $changed = 0;

        open(F, "<$fi") || next;
        my $text = <F>;
        close(F);

        unless( $text =~ s/^(%META:FIELD.*name="Checkins".*value=")(.*?)(".*%)$/$1._add($2,$rev,\$changed).$3/gem ) {
            $text .= "\n" unless $text =~ /\n$/s;
            $text .= "%META:FIELD{name=\"Checkins\" attributes=\"\" title=\"Checkins\" value=\"$rev\"}%\n";
            $changed = 1;
        }

        next unless $changed;

        print STDERR `co -l -f $fi`;
        die $! if $?;
        open(F, ">$fi") || die "Failed to write $fi: $!";
        print F $text;
        close(F);
        print STDERR `ci -mauto -u $fi`;
        die $! if $?;

        # 777 in case subversion user is not Apache user
        chmod(0777, $fi);

        print STDERR "Updated $item with $rev\n";
    }
}

# Create the flag that tells the cron job to update from the repository
open(F, ">>../svncommit") || die "Failed to write ../svncommit: $!";
print F join(" ", @changes);
close(F);

# Create the flag for this script
open(F, ">../lastupdate") || die $!;
print F "$last\n";
close(F);

close(STDERR);
