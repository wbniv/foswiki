#!/usr/bin/perl -w
#
# Build a Foswiki Release from branches in the Foswiki  svn repository - see http://foswiki.org/Development/BuildingARelease
# checkout Foswiki Branch
# run the unit tests
# run other tests
# build a release tarball & upload...
# Sven Dowideit Copyright (C) 2006-2008 All rights reserved.
#
# If you are Sven (used by Sven's automated nightly build system) - call with perl autoBuildFoswiki.pl -sven
# everyone else, can just run perl autoBuildFoswiki.pl
#
#

my $SvensAutomatedBuilds = 0;
if ( grep('-sven', @ARGV) ) {
   $SvensAutomatedBuilds = 1;
   print STDERR "doing an automated Sven build";
}



my $foswikiBranch = 'trunk';

unless ( -e $foswikiBranch ) {
   print STDERR "doing a fresh checkout\n";
   `svn co http://svn.foswiki.org/$foswikiBranch > Foswiki-svn.log`;
   chdir($foswikiBranch.'/core');
} else {
#TODO: should really do an svn revert..
   print STDERR "using existing checkout, removing ? files";
   chdir($foswikiBranch);
   `svn status | grep ? | sed 's/?/rm -r/' | sh > Foswiki-svn.log`;
   `svn up >> Foswiki-svn.log`;
   chdir('core');
}

my $foswikihome = `pwd`;
chomp($foswikihome);

`mkdir working/tmp`;
`chmod 777 working/tmp`;
`chmod 777 lib`;
#TODO: add a trivial and correct LocalSite.cfg
`chmod -R 777 data pub`;

#TODO: replace this code with 'configure' from comandline
my $localsite = getLocalSite($foswikihome);
open(LS, ">$foswikihome/lib/LocalSite.cfg");
print LS $localsite;
close(LS);


`perl pseudo-install.pl developer`;

#run unit tests
#TODO: testrunner should exit == 0 if no errors?
chdir('test/unit');
my $unitTests = "export FOSWIKI_LIBS=; export FOSWIKI_HOME=$foswikihome;perl ../bin/TestRunner.pl -clean FoswikiSuite.pm 2>&1 > $foswikihome/Foswiki-UnitTests.log";
my $return = `$unitTests`;
my $errorcode = $? >> 8;
unless ($errorcode == 0) {
    open(UNIT, "$foswikihome/Foswiki-UnitTests.log");
    local $/ = undef;
    my $unittestErrors = <UNIT>;
    close(UNIT);
    
    chdir($foswikihome);
    if ($SvensAutomatedBuilds) {
    	`scp Foswiki* distributedinformation\@distributedinformation.com:~/www/Foswiki_$foswikiBranch/`;
    	sendEmail('foswiki-svn@lists.sourceforge.net', "Subject: Foswiki $foswikiBranch has Unit test FAILURES\n\n see http://fosiki.com/Foswiki_$foswikiBranch/ for output files.\n".$unittestErrors);
    }
    die "\n\n$errorcode: unit test failures - need to fix them first\n" 
}

chdir($foswikihome);
#TODO: add a performance BM & compare to something golden.
`perl tools/MemoryCycleTests.pl > $foswikihome/Foswiki-MemoryCycleTests.log 2>&1`;
`/usr/local/bin/perlcritic --severity 5 --statistics --top 20 lib/  > $foswikihome/Foswiki-PerlCritic.log 2>&1`;
`/usr/local/bin/perlcritic --severity 5 --statistics --top 20 bin/ >> $foswikihome/Foswiki-PerlCritic.log 2>&1`;
#`cd tools; perl check_manifest.pl`;
#`cd data; grep '%META:TOPICINFO{' */*.txt | grep -v TestCases | grep -v 'author="ProjectContributor".*version="\$Rev'`;

#TODO: #  fix up release notes with new changelogs - see
#
#    * http://foswiki.org/Tasks/ReleaseNotesTml?type=patch
#        * Note that the release note is edited by editing the topic data/Foswiki/FoswikiReleaseNotes04x00. The build script creates a file in the root of the zip called FoswikiReleaseNotes04x00? .html, and the build script needs your Twiki to be running to look up the release note topic and show it with the simple text skin.
#            * Note - from 4.1 we need to call this data/Foswiki/FoswikiReleaseNotes04x01 
#
#

print "\n\n ready to build release\n";

#TODO: clean the setup again
#   1.  Install developer plugins (hard copy)
#      * perl pseudo-install.pl developer to install the plugins specified in MANIFEST 
#   2. use the configure script to make your system basically functional
#      * ensure that your apache has sufficient file and directory permissions for data and pub 
#   3. cd tools
#   4. perl build.pl release
#      * Note: if you specify a release name the script will attempt to commit to svn 
chdir('lib');
`perl ../tools/build.pl release -auto > $foswikihome/Foswiki-build.log 2>&1`;

chdir($foswikihome);
if ($SvensAutomatedBuilds) {
	#push the files to my server - http://fosiki.com/
	`scp Foswiki* distributedinformation\@fosiki.com:~/www/Foswiki_$foswikiBranch/` ;
	my $buildOutput = `ls -alh *auto*`;
	$buildOutput .= "\n";
	$buildOutput .= `grep 'All tests passed' $foswikihome/Foswiki-UnitTests.log`;
	sendEmail('Builds@fosiki.com', "Subject: Foswiki $foswikiBranch built OK\n\n see http://fosiki.com/Foswiki_$foswikiBranch/ for output files.\n".$buildOutput);
}


sub getLocalSite {
   my $foswikidir = shift;

#   open(TS, "$foswikidir/lib/Foswiki.spec");
#   local $/ = undef;
#   my $localsite = <TS>;
#   close(TS);
   my $localsite = `grep 'Foswiki::cfg' $foswikidir/lib/Foswiki.spec`;

   $localsite =~ s|/home/httpd/foswiki|$foswikidir|g;
   $localsite =~ s|# \$Foswiki|\$Foswiki|g;

   return $localsite;
}

#Yes, this email setup only works for Sven - will look at re-using the .settings file CC made for BuildContrib
sub sendEmail {
    return unless ($SvensAutomatedBuilds);
    my $toAddress = shift;
    my $text = shift;
    use Net::SMTP;

    my $smtp = Net::SMTP->new('mail.iinet.net.au', Hello=>'sven.home.org.au', Debug=>0);

    $smtp->mail('SvenDowideit@WikiRing.com');
    $smtp->to($toAddress);

    $smtp->data();
    $smtp->datasend("To: $toAddress\n");
    $smtp->datasend($text);
    $smtp->dataend();

    $smtp->quit;
}
1;
