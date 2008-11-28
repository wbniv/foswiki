#!/usr/bin/perl;
#
# Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2007 Foswiki Contributors.
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
# As per the GPL, removal of this notice is prohibited.
#
# Author: Crawford Currie http://c-dot.co.uk
#
use strict;

use lib '../lib/CPAN/lib';

use Algorithm::Diff;

sub usage {
    die <<NEWBIE
This script will synchronise the content of a set of webs in a local
subversion checkout with the content of a local TWiki that is tagged
with %STARTSECTION{"distributiondoc"}% sections. It
only synchronises topics found in subversion; linked documents (e.g. those
created by pseudo-install.pl) are ignored.

Progress and error messages are printed to STDERR. The output of the
script is a list of changed topics.

The script must be run in the subversion checkout area:

cd ..../bin
perl ../tools/mergeDoc.pl [-svn2twiki] <twikipath> <web1> <web2> ... <webN>
<svnpath> is the absolute file path to the root of the subversion checkout.
<web1> <web2> ... <webN> are the webs to synchronise

Options:
   -svn2twiki - overwrite the content of the twiki with what's in subversion.
                Note: text outside the %STARTSECTION{"distributiondoc"}% is
                retained. Default is to update the subversion checkout from
                twiki.
NEWBIE
}

my $path = '';
my @synchedFiles;
my $quiet = 1;

unless (scalar(@ARGV)) {
    usage();
}

my $mode = 't2s';
if ($ARGV[0] eq '-svn2twiki') {
    $mode = 's2t';
    shift @ARGV;
}

my $svnpath = '..';
my $twikipath = shift @ARGV;

unless ($svnpath && -d $svnpath) {
    print STDERR "Bad svn path $svnpath";
    usage();
}

# Iterate over selected webs
foreach my $web (@ARGV) {
    unless (opendir(D, "$svnpath/data/$web")) {
        print STDERR "Failed to open $web: $!";
        next;
    }
    # iterate over topics
    foreach my $topic (sort readdir(D)) {
        local $/;
        next unless $topic =~ /^\w+\.txt$/;

        my $path = "$web/$topic";
        $path =~ s/.txt$//;

        # load subversion version
        my $svnfile = "$svnpath/data/$path.txt";

        if (-l $svnfile) {
            next; # a link; ignore it
        }

        unless (open(SF, "<$svnfile")) {
            print STDERR "Failed to open $svnfile: $!\n";
            next;
        }
        my $svnVersion = <SF>;

        # Hack off META; save it
        $svnVersion =~ s/\r//;
        my @svnLines = split(/\n/, $svnVersion);
        my @svntop;
        while (scalar(@svnLines) && $svnLines[0] =~ /^%META:\w+{.*?}%$/) {
            push(@svntop, shift(@svnLines));
        }
        my @svnbottom;
        while (scalar(@svnLines) && $svnLines[-1] =~ /^(%META:\w+{.*?}%|\s*)$/) {
            unshift(@svnbottom, pop(@svnLines));
        }

        # Load tagged version
        my $twikifile = "$twikipath/data/$path.txt";
        unless (open(TF, "<$twikifile")) {
            print STDERR "Failed to open $twikifile: $!\n";
            next;
        }
        my $twikiVersion = <TF>;
        $twikiVersion =~ s/\r//;
        if ($twikiVersion !~ /.*%STARTSECTION{"distributiondoc"}%/) {
            print STDERR "$twikifile has no 'distributiondoc' section\n";
            next;
        }
        # Hack off stuff outside the distribution section and save it
        $twikiVersion =~ s/(.*%STARTSECTION{"distributiondoc"}%\s*)//s;
        my @twikitop = split(/\n/, $1);
        unless ($twikiVersion =~ s/(\s*%ENDSECTION{"distributiondoc"}%.*)//s) {
            print STDERR "$twikifile has missing %ENDSECTION\n";
            next;
        }
        my @twikibottom = split(/\n/, $1);
        my @twikiLines = split(/\n/, $twikiVersion);

        #### now have two versions, $svnVersion and $twikiVersion

        # Compare. To do a two way merge would require a 3-way diff,
        # but that's too complicated.
        my $diff;
        if ($mode eq 't2s') {
            $diff = Algorithm::Diff->new(\@svnLines, \@twikiLines);
        } else {
            $diff = Algorithm::Diff->new(\@twikiLines, \@svnLines);
        }
        my $changed = 0;
        my @new;
        while ($diff->Next()) {
            if ($diff->Same()) {
                push(@new, $diff->Same(1));
                next;
            }
            if ($diff->Items(1)) {
                # Deleted
                #$changes .= "< ".join("\n< ", $diff->Items(1))."\n";
                $changed++;
            }
            if ($diff->Items(2)) {
                # Inserted
                #$changes .= "> ".join("\n", $diff->Items(2))."\n";
                push(@new, $diff->Items(2));
                $changed++;
            }
        }
        next unless ($changed);
        print STDERR "---+ $path: $changed change(s)\n";
        my ($top, $bottom, $outfile);
        if ($mode eq 't2s') {
            # update subversion from twiki
            $top = \@svntop;
            $bottom = \@svnbottom;
            $outfile = $svnfile;
        } else {
            # update twiki from subversion
            $top = \@twikitop;
            $bottom = \@twikibottom;
            $outfile = $twikifile;
        }
        my $content = join("\n", @$top, @new, @$bottom);
        if (open(F, ">$outfile")) {
            print F $content,"\n";
            print STDERR "\t$outfile has been updated\n";
            close(F);
            push(@synchedFiles, $path);
        } else {
            print STDERR "Failed to open $outfile for write: $!\n";
        }
    }
    closedir(D);
}

if (scalar(@synchedFiles)) {
    print join(" ", @synchedFiles)."\n";
}
