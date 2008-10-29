require 5.006;

package RcsTests;

use base qw(TWikiTestCase);
use strict 'vars';
sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

use TWiki;
use TWiki::Store;
use TWiki::Store::RcsLite;
use TWiki::Store::RcsWrap;
use File::Path;

my $testWeb = "TestRcsWebTests";
my $user = "TestUser1";

my $rTopic = "TestTopic";
my $twiki;
my $class;

sub RcsLite {
    my $this = shift;
    $TWiki::cfg{StoreImpl} = 'RcsLite';
    $class = 'TWiki::Store::RcsLite';
}

sub RcsWrap {
    my $this = shift;
    $TWiki::cfg{StoreImpl} = 'RcsWrap';
    $class = 'TWiki::Store::RcsWrap';
}

sub fixture_groups {
    my $groups = [ 'RcsLite' ];
    eval {
        `co -V`; # Check to see if we have co
    };
    if ($@ || $?) {
        print STDERR "*** CANNOT RUN RcsWrap TESTS - NO COMPATIBLE co: $@\n";
    } else {
        push(@$groups, 'RcsWrap');
    }
    return ( $groups );
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
    die unless (defined $TWiki::cfg{PubUrlPath});
    die unless (defined $TWiki::cfg{ScriptSuffix});
    $TWiki::cfg{Register}{AllowLoginName}    =  1;
    $twiki = new TWiki();
    $twiki->{sandbox}->{TRACE} = 0;
    # Switch off pipes to maximise debug opportunities
    # The following setting is for debugging and disabled
    # since it makes so much noise that normal tests drown
    # Note enabling these makes later test cases fail when
    # run as TWikiSuite
    #$twiki->{sandbox}->{REAL_SAFE_PIPE_OPEN} = 0;
    #$twiki->{sandbox}->{EMULATED_SAFE_PIPE_OPEN} = 0;

    $TWiki::cfg{WarningFileName} = "$TWiki::cfg{TempfileDir}/junk";
    die unless $twiki;
    die unless $twiki->{prefs};
    File::Path::mkpath("$TWiki::cfg{DataDir}/$testWeb");
    File::Path::mkpath("$TWiki::cfg{PubDir}/$testWeb");
    $this->assert(open(F, ">$TWiki::cfg{TempfileDir}/itme3122"), $!);
    print F "old";
    $this->assert(close(F), $!);
}

sub tear_down {
    my $this = shift;
    unlink $TWiki::cfg{WarningFileName};
    unlink "$TWiki::cfg{TempfileDir}/itme3122";
    File::Path::rmtree("$TWiki::cfg{DataDir}/$testWeb");
    File::Path::rmtree("$TWiki::cfg{PubDir}/$testWeb");
    $twiki->finish();
    $this->SUPER::tear_down();
}

# Tests temp file creation in RcsFile
sub test_mktmp {
    # this is only used on WINDOWS so needs a special test
    my $this = shift;
    my $tmpfile = TWiki::Store::RcsFile::mkTmpFilename();
    $this->assert(!-e $tmpfile);
}

# Tests reprev, for both Wrap and Lite
sub verify_RepRev {
    my ($this) = @_;
    my $topic = "RcsRepRev";

    my $rcs = $class->new( $twiki, $testWeb, $topic, "" );
    $rcs->addRevisionFromText( "there was a man\n\n", "in once", "JohnTalintyre" );
    $this->assert_equals( "there was a man\n\n", $rcs->getRevision(1) );
    $this->assert_equals( 1, $rcs->numRevisions() );

    $rcs->replaceRevision( "there was a cat\n", "1st replace",
                           "NotJohnTalintyre", time() );
    $this->assert_equals( 1, $rcs->numRevisions() );
    $this->assert_equals( "there was a cat\n", $rcs->getRevision(1) );
    $rcs->addRevisionFromText( "and now this\n\n\n", "2nd entry", "J1" );
    $this->assert_equals( 2, $rcs->numRevisions() );
    $this->assert_equals( "there was a cat\n", $rcs->getRevision(1) );
    $this->assert_equals( "and now this\n\n\n", $rcs->getRevision(2) );

    $rcs->replaceRevision( "then this", "2nd replace", "J2", time() );
    $this->assert_equals( 2, $rcs->numRevisions );
    $this->assert_equals( "there was a cat\n", $rcs->getRevision(1) );
    $this->assert_equals( "then this", $rcs->getRevision(2) );
}

sub verify_RepRev2839 {
    my ($this) = @_;
    my $topic = "RcsRepRev";

    my $rcs = $class->new( $twiki, $testWeb, $topic, "" );
    $rcs->addRevisionFromText( "there was a man", "in once", "JohnTalintyre" );
    $this->assert_equals( "there was a man", $rcs->getRevision(1) );
    $this->assert_equals( 1, $rcs->numRevisions() );

    $rcs->replaceRevision( "there was a cat", "1st replace",
                           "NotJohnTalintyre", time() );
    $this->assert_equals( 1, $rcs->numRevisions() );
    $this->assert_equals( "there was a cat", $rcs->getRevision(1) );
    $rcs->addRevisionFromText( "and now this", "2nd entry", "J1" );
    $this->assert_equals( 2, $rcs->numRevisions() );
    $this->assert_equals( "there was a cat", $rcs->getRevision(1) );
    $this->assert_equals( "and now this", $rcs->getRevision(2) );

    $rcs->replaceRevision( "then this", "2nd replace", "J2", time() );
    $this->assert_equals( 2, $rcs->numRevisions );
    $this->assert_equals( "there was a cat", $rcs->getRevision(1) );
    $this->assert_equals( "then this", $rcs->getRevision(2) );
}

# Tests locking - Wrap only
sub verify_RcsWrapOnly_ciLocked {

    return unless $class =~ /RcsWrap/;

    my $this = shift;
    my $topic = "CiTestLockedTempDeleteMeItsOk";
    # create the fixture
    my $rcs = TWiki::Store::RcsWrap->new( $twiki, $testWeb, $topic, "" );
    $rcs->addRevisionFromText( "Shooby Dooby", "original", "BungditDin" );
    # hack the lock
    my $vfile = $rcs->{file}.",v";
    `co -f -q -l $vfile`; # Only if we have co
    unlink("$topic.txt");

    # file is now locked by blocker_socker, save some new text
    $rcs->saveFile( $rcs->{file}, "Shimmy Dimmy" );
    # check it in
    $rcs->_ci( "Gotcha", "SheikAlot" );
    my $txt = $rcs->readFile($vfile);
    $this->assert_matches(qr/Gotcha/s, $txt);
    $this->assert_matches(qr/BungditDin/s, $txt);
    $this->assert_matches(qr/Shimmy Dimmy/, $txt);
    $this->assert_matches(qr/Shooby Dooby/, $txt);
    $this->assert_matches(qr/SheikAlot/s, $txt);
}

sub verify_simple1 {
    my $this = shift;
    $this->checkGetRevision([ "a", "b\n", "c\n" ]);
}

sub verify_simple2 {
    my $this = shift;
    $this->checkGetRevision([ "a", "b", "a\n", "b", "a", "b\n","a\nb\n" ]);
}

sub verify_simple3 {
    my $this = shift;
    $this->checkGetRevision([ "a\n", "b" ]);
}

sub verify_simple4 {
    my $this = shift;
    $this->checkGetRevision([ "" ]);
}

sub verify_simple5 {
    my $this = shift;
    $this->checkGetRevision([ "", "a" ]);
}

sub verify_simple6 {
    my $this = shift;
    $this->checkGetRevision([ "", "a", "a\n", "a\n\n", "a\n\n\n" ]);
}

sub verify_simple7 {
    my $this = shift;
    $this->checkGetRevision([ "", "a", "a\n", "a\nb" ]);
}

sub verify_simple8 {
    my $this = shift;
    $this->checkGetRevision([ "", "a", "a\n", "a\nb", "a\nb\n" ]);
}

sub verify_simple9 {
    my $this = shift;
    $this->checkGetRevision([ "", "\n", "\n\n", "a", "a\n", "a\n\n", "\na","\n\na", "" ]);
}

sub verify_simple10 {
    my $this = shift;
    $this->checkGetRevision([ "a", "b", "a\n", "b", "a", "b\n","a\nb\n", "a\nc\n" ]);
}

sub verify_simple11 {
    my $this = shift;
    $this->checkGetRevision([ "one\n", "1\n2\n", "one\nthree\n4\n", "one\ntwo\nthree\n" ]);
}

sub verify_simple12 {
    my $this = shift;
    $this->checkGetRevision([ "three\nfour\n", "one\ntwo\nthree\n" ]);
}

sub verify_simple13 {
    my $this = shift;
    $this->checkGetRevision([ '@expand@\n', "strict;\n", "head 1.99;\n" ]);
}

sub verify_simple14 {
    my $this = shift;
    $this->checkGetRevision([ '@expand@', "strict;\n", "head 1.99;\n" ]);
}

sub verify_simple15 {
    my $this = shift;
    $this->checkGetRevision([ "a".chr(0xFF), "b".chr(0xFF) ] );
}

sub verify_simple16 {
    my $this = shift;
    $this->checkDifferences([ "1\n", "2\n" ]);
}

sub verify_simple17 {
    my $this = shift;
    $this->checkDifferences([ "\n", "1\n" ]);
}

sub verify_simple18 {
    my $this = shift;
    $this->checkDifferences([ "1\n", "2\n" ]);
}

sub verify_simple19 {
    my $this = shift;
    $this->checkDifferences([ "2\n", "1\n" ]);
}

sub verify_simple20 {
    my $this = shift;
    $this->checkDifferences([ "1\n2\n3\n", "a\n1\n2\n3\nb\n" ]);
}

sub verify_simple21 {
    my $this = shift;
    $this->checkDifferences([ "a\n1\n2\n3\nb\n", "1\n2\n3\n" ]);
}

sub verify_simple22 {
    my $this = shift;
    $this->checkDifferences([ "1\n2\n3\n", "a\nb\n1\n2\n3\nb\nb\n" ]);
}

sub verify_simple23 {
    my $this = shift;
    $this->checkDifferences([ "a\nb\n1\n2\n3\nb\nb\n", "1\n2\n3\n" ]);
}

sub verify_simple24 {
    my $this = shift;
    $this->checkDifferences([ "1\n2\n3\n4\n5\n6\n7\n8\none\nabc\nABC\ntwo\n",
                              "A\n1\n2\n3\none\nIII\niii\ntwo\nthree\n"]);
}

sub verify_simple25 {
    my $this = shift;
    $this->checkDifferences(
        [ "A\n1\n2\n3\none\nIII\niii\ntwo\nthree\n",
          "1\n2\n3\n4\n5\n6\n7\n8\none\nabc\nABC\ntwo\n" ]);
}

sub verify_simple26 {
    my $this = shift;
    $this->checkDifferences(
        [ "one\ntwo\nthree\nfour\nfive\nsix\n",
          "one\nA\ntwo\nB\nC\nfive\n" ]);
}

sub verify_simple27 {
    my $this = shift;
    $this->checkDifferences([ "A\nB\n", "A\nC\n\nB\n" ]);
}

sub checkGetRevision {
    my( $this, $revs ) = @_;
    my $topic = "TestRcsTopic";

    my $rcs = $class->new( $twiki, $testWeb, $topic );

    for( my $i = 0; $i < scalar(@$revs); $i++ ) {
        my $text = $revs->[$i];
        $rcs->addRevisionFromText( $text, "rev".($i+1), "UserForRev".($i+1) );
    }

    $rcs = $class->new( $twiki, $testWeb, $topic );

    $this->assert_equals(scalar(@$revs), $rcs->numRevisions());
    for( my $i = 1; $i <= scalar(@$revs); $i++ ) {
        my $text = $rcs->getRevision( $i );
        $this->assert_str_equals( $revs->[$i-1], $text,
                                  "rev ".$i.
                                  ": expected '$revs->[$i-1]', got '$text'");
    }
}

sub verify_GetBinaryRevision {
    my( $this, $revs ) = @_;
    my $topic = "TestRcsTopic";

    my $atttext1 = "\000123\003\n";
    my $atttext2 = "\003test test test\000\n";
    my $attachment = "file.binary";
    my $rcs = $class->new( $twiki, $testWeb, $topic, $attachment );
    $rcs->saveFile("tmp.tmp", $atttext1) && die;
    my $fh;
    open($fh, "<tmp.tmp");
    $rcs->addRevisionFromStream( $fh, "comment attachment",
                       "UserForRev" );
    close($fh);
    unlink("tmp.tmp");
    $rcs->saveFile("tmp.tmp", $atttext2) && die;
    open($fh, "<tmp.tmp");
    $rcs->addRevisionFromStream( $fh, "comment attachment",
                                 "UserForRev" );
    close($fh);
    unlink("tmp.tmp");

    $rcs = $class->new( $twiki, $testWeb, $topic, $attachment );

    my $text = $rcs->getRevision( 1 );
    $this->assert_str_equals( $atttext1, $text );
    $text = $rcs->getRevision( 2 );
    $this->assert_str_equals( $atttext2, $text );
}

# ensure RCS keywords are not expanded in the checked-out version
sub verify_Keywords {
    my( $this ) = @_;
    my $topic = "TestRcsTopic";
    my $check = '$Author$ $Date$ $Header$ $Id$ $Locker$ $Log$ $Name$ $RCSfile$ $Revision$ $Source$ $State$';
    my $rcs = $class->new( $twiki, $testWeb, $topic, undef );
    $rcs->addRevisionFromText( $check, "comment", "UserForRev0" );
    open(F,"<$rcs->{file}") || die "Failed to open $rcs->{file}";
    local $/ = undef;
    $this->assert_str_equals($check, <F>);
    close(F);
}

sub checkDifferences {
    my( $this, $set ) = @_;
    my($from, $to) = @$set;
    my $topic = "RcsDiffTest";
    my $rcs = $class->new( $twiki, $testWeb, $topic, "" );

    $rcs->addRevisionFromText( $from, "num 0", "RcsWrapper" );
    $rcs->addRevisionFromText( $to, "num 1", "RcsWrapper" );

    $rcs = $class->new( $twiki, $testWeb, $topic, "" );

    my $diff = $rcs->revisionDiff( 1, 2 );

    # apply the differences to the text of topic 1
    my $data = TWiki::Store::RcsLite::_split( $from );
    my $l = 0;
    #print "\nStart: ",join('\n',@$data),"\n";
    foreach my $e ( @$diff ) {
        #print STDERR "    $e->[0] $l: ";
        if( $e->[0] eq 'u' ) {
            $l++;
        } elsif( $e->[0] eq 'c' ) {
            $this->assert_str_equals($data->[$l], $e->[1]);
            $data->[$l] = $e->[2];
            $l++;
        } elsif($e->[0] eq '-') {
            $this->assert_str_equals($data->[$l], $e->[1]);
            splice(@$data, $l, 1);
        } elsif($e->[0] eq '+') {
            splice(@$data, $l, 0, $e->[2]);
            $l++;
        } elsif($e->[0] eq 'l') {
            $l = $e->[2] - 1;
        } else {
            $this->assert(0, $e->[0]);
        }
        #for my $i (0..$#$data) {
        #    print STDERR '^' if $i == $l;
        #    print STDERR $data->[$i];
        #    print STDERR '\n' unless($i == $#$data);
        #}
        #print STDERR " -> $l\n";
    }
    $this->assert_str_equals($to, join("\n",@$data));
}

sub verify_RevAtTime {
    my( $this ) = @_;

    my $rcs = $class->new( $twiki, $testWeb, 'AtTime', "" );
    $rcs->addRevisionFromText( "Rev0\n", '', "RcsWrapper", 0 );
    $rcs->addRevisionFromText( "Rev1\n", '', "RcsWrapper", 1000 );
    $rcs->addRevisionFromText( "Rev2\n", '', "RcsWrapper", 2000 );
    $rcs = $class->new( $twiki, $testWeb, 'AtTime', "" );

    my $r = $rcs->getRevisionAtTime(500);
    $this->assert_equals(1, $r);
    $r = $rcs->getRevisionAtTime(1500);
    $this->assert_equals(2, $r);
    $r = $rcs->getRevisionAtTime(2500);
    $this->assert_equals(3, $r);
}

sub verify_RevInfo {
    my( $this ) = @_;

    my $rcs = $class->new( $twiki, $testWeb, 'RevInfo', "" );
    $rcs->addRevisionFromText( "Rev1\n", 'FirstComment', "FirstUser", 0 );
    $rcs->addRevisionFromText( "Rev2\n", 'SecondComment', "SecondUser", 1000 );
    $rcs->addRevisionFromText( "Rev3\n", 'ThirdComment', "ThirdUser", 2000 );

    $rcs = $class->new( $twiki, $testWeb, 'RevInfo', "" );

    my ($rev, $date, $user, $comment) = $rcs->getRevisionInfo(1);
    $this->assert_equals(1, $rev);
    $this->assert_equals(0, $date);
    $this->assert_str_equals('FirstUser', $user);
    $this->assert_str_equals('FirstComment', $comment);

    ($rev, $date, $user, $comment) = $rcs->getRevisionInfo(2);
    $this->assert_equals(2, $rev);
    $this->assert_equals(1000, $date);
    $this->assert_str_equals('SecondUser', $user);
    $this->assert_str_equals('SecondComment', $comment);

    ($rev, $date, $user, $comment) = $rcs->getRevisionInfo(3);
    $this->assert_equals(3, $rev);
    $this->assert_equals(2000, $date);
    $this->assert_str_equals('ThirdUser', $user);
    $this->assert_str_equals('ThirdComment', $comment);

    ($rev, $date, $user, $comment) = $rcs->getRevisionInfo(0);
    $this->assert_equals(3, $rev);
    $this->assert_equals(2000, $date);
    $this->assert_str_equals('ThirdUser', $user);
    $this->assert_str_equals('ThirdComment', $comment);

    ($rev, $date, $user, $comment) = $rcs->getRevisionInfo(4);
    $this->assert_equals(3, $rev);
    $this->assert_equals(2000, $date);
    $this->assert_str_equals('ThirdUser', $user);
    $this->assert_str_equals('ThirdComment', $comment);

    unlink($rcs->{rcsFile});

    $rcs = $class->new( $twiki, $testWeb, 'RevInfo', "" );

    ($rev, $date, $user, $comment) = $rcs->getRevisionInfo(3);
    $this->assert_equals(1, $rev);
    $this->assert_str_equals($twiki->{users}->getCanonicalUserID($TWiki::cfg{DefaultUserLogin}), $user);
    $this->assert_str_equals('Default revision information', $comment);
}

# If a .txt file exists with no ,v and we perform an op on that
# file, a ,v must be created for rev 1 before the op is completed.
sub verify_MissingVrestoreRev {
    my( $this ) = @_;

    my $file = "$TWiki::cfg{DataDir}/$testWeb/MissingV.txt";

    open(F, ">$file") || die;
    print F "Rev 1\n";
    close(F);

    my $rcs = $class->new( $twiki, $testWeb, 'MissingV', "" );
    my ($rev, $date, $user, $comment) = $rcs->getRevisionInfo(3);
    $this->assert_equals(1, $rev);
    $this->assert_equals(1, $rcs->numRevisions());

    my $text = $rcs->getRevision(0);
    $this->assert_matches(qr/^Rev 1/, $text);

    $text = $rcs->getRevision(1);
    $this->assert_matches(qr/^Rev 1/, $text);

    $rcs->restoreLatestRevision("ArtForger");

    $this->assert(-e "$file,v");

    $text = $rcs->getRevision(0);
    $this->assert_matches(qr/^Rev 1/, $text);

    unlink($file);
    unlink("$file,v");
}

# If a .txt file exists with no ,v and we perform an op on that
# file, a ,v must be created for rev 1 before the op is completed.
sub verify_MissingVrepRev {
    my( $this ) = @_;

    my $file = "$TWiki::cfg{DataDir}/$testWeb/MissingV.txt";

    open(F, ">$file") || die;
    print F "Rev 1\n";
    close(F);

    my $rcs = $class->new( $twiki, $testWeb, 'MissingV', "" );
    my ($rev, $date, $user, $comment) = $rcs->getRevisionInfo(3);
    $this->assert_equals(1, $rev);
    $this->assert_equals(1, $rcs->numRevisions());

    my $text = $rcs->getRevision(0);
    $this->assert_matches(qr/^Rev 1/, $text);

    $text = $rcs->getRevision(1);
    $this->assert_matches(qr/^Rev 1/, $text);

    $rcs->replaceRevision("2", "no way", "me", time());

    $this->assert(-e "$file,v");

    $text = $rcs->getRevision(0);
    $this->assert_matches(qr/^2/, $text);

    unlink($file);
    unlink("$file,v");
}

sub verify_MissingVdelRev {
    my( $this ) = @_;

    my $file = "$TWiki::cfg{DataDir}/$testWeb/MissingV.txt";

    open(F, ">$file") || die;
    print F "Rev 1";
    close(F);

    my $rcs = $class->new( $twiki, $testWeb, 'MissingV', "" );
    my ($rev, $date, $user, $comment) = $rcs->getRevisionInfo(3);
    $this->assert_equals(1, $rev);
    $this->assert_equals(1, $rcs->numRevisions());

    my $text = $rcs->getRevision(0);
    $this->assert_matches(qr/^Rev 1/, $text);

    $text = $rcs->getRevision(1);
    $this->assert_matches(qr/^Rev 1/, $text);

    $text = $rcs->getRevision(2);
    $this->assert_matches(qr/^Rev 1/, $text);

    $rcs->addRevisionFromText("Rev 2", "more", "idiot", time());
    $this->assert(-e "$file,v");

    $text = $rcs->getRevision(1);
    $this->assert_matches(qr/^Rev 1/, $text);

    $text = $rcs->getRevision(2);
    $this->assert_matches(qr/^Rev 2/, $text);

    $text = $rcs->getRevision(0);
    $this->assert_matches(qr/^Rev 2/, $text);

    $rcs->deleteRevision();

    $this->assert(-e "$file,v");

    $text = $rcs->getRevision(0);
    $this->assert_matches(qr/^Rev 1/, $text);

    $text = $rcs->getRevision(1);
    $this->assert_matches(qr/^Rev 1/, $text);

    $text = $rcs->getRevision(2);
    $this->assert_matches(qr/^Rev 1/, $text);

    unlink($file);
    unlink("$file,v");
}

sub verify_Item2957 {
    my( $this ) = @_;
    my $rev1 = <<HERE;
A
C


E
B
HERE
    my $rev2 = <<HERE;
A
C

F

D
B
HERE
    my $rev3 = <<HERE;
A
F
B
HERE
    my $file = "$TWiki::cfg{DataDir}/$testWeb/Item2957.txt";
    open(F, ">$file") || die;
    print F $rev1;
    close(F);

    my $rcs = $class->new( $twiki, $testWeb, 'Item2957', '' );
    $rcs->addRevisionFromText($rev2, "more", "idiot", time());
    $rcs = $class->new( $twiki, $testWeb, 'Item2957', '' );
    $rcs->addRevisionFromText($rev3, "more", "idiot", time());

    $rcs = $class->new( $twiki, $testWeb, 'Item2957', '' );
    my $text = $rcs->getRevision(1);
    if ($TWiki::cfg{OS} eq 'WINDOWS') {
        $text =~ s/\r\n/\n/sg;
    }
    $this->assert_equals($rev1, $text);
    $rcs = $class->new( $twiki, $testWeb, 'Item2957', '' );
    $text = $rcs->getRevision(2);
    $this->assert_equals($rev2, $text);
    $rcs = $class->new( $twiki, $testWeb, 'Item2957', '' );
    $text = $rcs->getRevision(3);
    $this->assert_equals($rev3, $text);
}

sub verify_Item3122 {
    my( $this ) = @_;

    my $rcs = $class->new( $twiki, $testWeb, 'Item3122', 'itme3122' );
    $rcs->addRevisionFromText("new", "more", "idiot", time());
    my $text = $rcs->getRevision(1);
    $this->assert_equals("new", $text);
    $rcs = $class->new( $twiki, $testWeb, 'Item3122', 'itme3122' );
    my $fh;
    $this->assert(open($fh, "<$TWiki::cfg{TempfileDir}/itme3122"), $!);
    $rcs->addRevisionFromStream($fh, "more", "idiot", time());
    close($fh);
    $text = $rcs->getRevision(1);
    $this->assert_equals("new", $text);
    $text = $rcs->getRevision(2);
    $this->assert_equals("old", $text);
}

1;
