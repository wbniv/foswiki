#!/usr/bin/perl
unless (scalar(@ARGV)) {
    print <<DOC;
Build an extension

When run from the 'twikiplugins' directory of a TWiki checkout, this
script will build the BuildContrib-enabled extension named in the
first parameter. The second parameter is the build target for the extension.

Examples:
$ perl build.pl ActionTrackerPlugin
$ perl build.pl SubscribePlugin upload
$ for f in FirstPlugin SecondPlugin; do perl build.pl $f release; done
DOC
    exit 1;
}

my $extension = shift(@ARGV);
$extension =~ s./+$..;

my $extdir = "Contrib";
if ($extension =~ /Plugin$/) {
    $extdir = "Plugins";
}

my $scriptDir = "$extension/lib/TWiki/$extdir/$extension";
unless (-e "$scriptDir/build.pl") {
    die "$scriptDir/build.pl not found";
}

use Cwd;
chdir($scriptDir);
do 'build.pl';
