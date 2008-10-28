#!/usr/bin/perl
use FindBin;
chdir $FindBin::Bin;

@skip = qw(twikiplugins tools test working logs);
print <<END;
Run this script from anywhere.

The script will scan ../lib/MANIFEST and compare the contents with 
what is checked in under subversion. Any differences are reported.

END
print "The ",join(',', @skip)," directories are *not* scanned.\n";

my %man;

map{ s/ .*//; $man{$_} = 1; } grep { !/^!include/  } split(/\n/, `cat ../lib/MANIFEST` );

my @lost;
my $sk = join('|', @skip);
foreach my $dir( grep { -d "../$_" }
                   split(/\n/, `svn ls ..`) ) {
    next if $dir =~ /^($sk)\/$/;
    print "Examining $dir\n";
    push( @lost,
          grep { !$man{$_} && !/\/TestCases\// && ! -d "../$_" }
            map{ "$dir$_" }
              split(/\n/, `cd .. && svn ls -R $dir`));
}
print "The following files were found in subversion, but are not in MANIFEST\n";
print join("\n", @lost ),"\n";
