#!/usr/bin/perl
# Test program for NativeTWikiSearch
# If it is correctly installed, this program will accept parameters like grep
# e.g.
# perl test.pl -i -l NativeTWikiSearch test.pl Makefile.PL NativeTWikiSearch.xs
#
use NativeTWikiSearch;
die <<MOAN unless scalar(@ARGV);
I need parameters, like grep!
Try:
perl test.pl -i -l NativeTWikiSearch test.pl Makefile.PL NativeTWikiSearch.xs
If it returns at least 3 filenames and doesn't crash, it worked.
MOAN
my $result = NativeTWikiSearch::cgrep(\@ARGV);
print "RESULT\n".join("\n", @$result)."\n";
