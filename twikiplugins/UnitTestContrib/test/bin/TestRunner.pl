#!/usr/bin/perl -w
# See bottom of file for description

require 5.006;

BEGIN {
    use Cwd 'abs_path';

    # root the tree
    my $here = Cwd::abs_path(Cwd::getcwd());

    # scoot up the tree looking for a bin dir that has setlib.cfg
    my $root = $here;
    while( !-e "$root/bin/setlib.cfg" ) {
        $root =~ s#/[^/]*$##;
    }
    unshift @INC, "$root/test/unit";
    unshift @INC, "$root/bin";
    unshift @INC, "$root/lib";
    unshift @INC, "$root/lib/CPAN/lib";
    require 'setlib.cfg';
};

use strict;
use TWiki;   # If you take this out then TestRunner.pl will fail on IndigoPerl
use Unit::TestRunner;
use Cwd;

my %options;
while (scalar(@ARGV) && $ARGV[0] =~ /^-/) {
    $options{shift(@ARGV)} = 1;
}

my ($stdout, $stderr, $log); # will be destroyed at the end, if created
if ($options{-log}) {
    require Unit::Eavesdrop;
    my @gmt = gmtime(time());
    $gmt[4]++;
    $gmt[5] += 1900;
    $log = sprintf("%0.4d",$gmt[5]);
    for (my $i = 4; $i >= 0; $i--) {
        $log .= sprintf("%0.2d", $gmt[$i]);
    }
    $log .= '.log';
    open(F, ">$log") || die $!;
    print STDERR "Logging to $log\n";
    $stdout = new Unit::Eavesdrop('STDOUT');
    $stdout->teeTo(\*F);
    # Don't need this, all the required info goes to STDOUT. STDERR is
    # really just treated as a black hole (except when debugging)
#    $stderr = new Unit::Eavesdrop('STDERR');
#    $stderr->teeTo(\*F);
}
print STDERR "Options: ",join(' ',keys %options),"\n";

unless (defined $ENV{TWIKI_ASSERTS}) {
    print "exporting TWIKI_ASSERTS=1 for extra checking; disable by exporting TWIKI_ASSERTS=0\n";
    $ENV{TWIKI_ASSERTS} = 1;
}

if ($ENV{TWIKI_ASSERTS}) {
    print "Assert checking on $ENV{TWIKI_ASSERTS}\n";
} else {
    print "Assert checking off $ENV{TWIKI_ASSERTS}\n";
}

if ($options{-clean}) {
    require File::Path;
    my @x = glob "$TWiki::cfg{DataDir}/Temp*";
    File::Path::rmtree([@x]) if scalar(@x);
    @x = glob "$TWiki::cfg{PubDir}/Temp*";
    File::Path::rmtree([@x]) if scalar(@x);
}

testForFiles($TWiki::cfg{DataDir}.'/Temp*');
testForFiles($TWiki::cfg{PubDir}.'/Temp*');

my $testrunner = Unit::TestRunner->new();
my $exit = $testrunner->start(@ARGV);

print STDERR "Run was logged to $log\n" if $options{-log};

exit $exit;

sub testForFiles {
    my $test = shift;
    my @list = glob $test;
    die "Please remove $test (or run with the -clean option) to run tests\n" if (scalar(@list));
}

1;

__DATA__

This script runs the test suites/cases defined on the command-line.

Author: Crawford Currie, http://c-dot.co.uk

Copyright (C) 2007 WikiRing, http://wikiring.com
All Rights Reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
