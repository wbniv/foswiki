# tests for the Filesystem::Virtual::NextWiki interface
#
# ASSUMES FILE-BASED STORE
#
package FilesysVirtualPluginSuite;
use base qw( TWikiFnTestCase );

use strict;
use POSIX ':errno_h';

use TWiki;
use Filesys::Virtual::NextWiki;

my $T = $Filesys::Virtual::NextWiki::TOPIC_EXT;
my $F = $Filesys::Virtual::NextWiki::FILES_EXT;

sub new {
    my $self = shift()->SUPER::new('FilesysVirtualTests', @_);
    return $self;
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up(@_);
    open( FILE, ">$TWiki::cfg{TempfileDir}/testfile.gif" );
    print FILE "Blah";
    close(FILE);
    # initial conditions:
    # /$this->{test_web}
    #    /$this->{test_topic}
    #    /NoView/
    #        /BlahBlah.txt
    #    /NoView.txt
    #    /NoView_files/
    #        A.gif
    #    /NoChange/
    #    /NoChange.txt
    #    /NoChange_files/
    #        A.gif
    TWiki::Func::saveTopic(
        $this->{test_web}, $TWiki::cfg{WebPrefsTopicName}, undef, <<HERE);

   * Set ALLOWWEBVIEW = $TWiki::cfg{DefaultUserWikiName}
   * Set ALLOWWEBCHANGE = $TWiki::cfg{DefaultUserWikiName}

HERE
    $this->_make_permWeb_fixture('view');
    $this->_make_permWeb_fixture('change');

    # Force re-init for prefs
    $this->{twiki} = new TWiki( undef, $this->{request} );

    $this->{handler} = new Filesys::Virtual::NextWiki();
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
    unlink("$TWiki::cfg{TempfileDir}/testfile.gif");
}

# make an access-controlled subweb fixture
sub _make_permWeb_fixture {
    my ($this, $condition) = @_;
    my $CONDITION = uc($condition);
    my $Condition = ucfirst(lc($condition));
    TWiki::Func::createWeb("$this->{test_web}/No$Condition");
    TWiki::Func::saveTopic(
        $this->{test_web}, "No$Condition/BlahBlah", undef, <<HERE);
EMPTY
HERE
    TWiki::Func::saveTopic(
        $this->{test_web}, "No$Condition", undef, <<HERE);
EMPTY
HERE
    TWiki::Func::saveAttachment(
        $this->{test_web}, "No$Condition",
        "A.gif", { file => "$TWiki::cfg{TempfileDir}/testfile.gif" });

    TWiki::Func::saveTopic(
        "$this->{test_web}/No$Condition",
        $TWiki::cfg{WebPrefsTopicName}, undef, <<HERE);
   * Set DENYWEB$CONDITION = $TWiki::cfg{DefaultUserWikiName}
HERE
    TWiki::Func::saveTopic(
        $this->{test_web}, "No$Condition", undef, <<HERE);
   * Set DENYTOPIC$CONDITION = $TWiki::cfg{DefaultUserWikiName}
HERE
}

sub _make_attachments_fixture {
    my $this = shift;
    TWiki::Func::saveAttachment(
        $this->{test_web}, $this->{test_topic},
        "A.gif", { file => "$TWiki::cfg{TempfileDir}/testfile.gif" });
    TWiki::Func::saveAttachment(
        $this->{test_web}, $this->{test_topic},
        "B C.jpg", { file => "$TWiki::cfg{TempfileDir}/testfile.gif" });}

sub _check_modtime {
    my ($this, $apath, $bpath) = @_;
    my ($s, $t) = $this->{handler}->modtime($apath);
    if (-e $bpath) {
        $this->assert_equals(1, $s);
        my @stat = CORE::stat($bpath);
        my ($sec, $min, $hr, $dd, $mm, $yy, $wd, $yd, $isdst) =
          localtime($stat[9]);
        $yy += 1900;
        $mm++;
        my $e = "$yy$mm$dd$hr$min$sec";
        $this->assert_equals($e, $t);
    } else {
        $this->assert_equals(0, $s);
    }
}

sub _check_stat {
    my ($this, $apath, $bpath, $perms) = @_;
    my @bstat = $this->{handler}->stat($apath);
    if (-e $bpath) {
        my @astat = CORE::stat($bpath);
        $astat[2] = $perms; # override file system
        while (scalar(@astat) && scalar(@bstat)) {
            if (defined $astat[0] && defined $bstat[0]) {
                $this->assert_str_equals($astat[0], $bstat[0]);
            }
            shift @astat; shift@bstat;
        }
        $this->assert_equals(scalar(@astat), scalar(@bstat));
    } else {
        $this->assert_equals(0, scalar(@bstat));
    }
}

sub test_modtime_R {
    my $this = shift;
    $this->_check_modtime('/', $TWiki::cfg{DataDir});
}

sub test_modtime_W {
    my $this = shift;
    $this->_check_modtime(
        "/$this->{test_web}",
        "$TWiki::cfg{DataDir}/$this->{test_web}");
    $this->_check_modtime(
        "/Nosuchweb",
        "$TWiki::cfg{DataDir}/Nosuchweb");
    $this->_check_modtime(
        "/$this->{test_web}/NoView",
        "$TWiki::cfg{DataDir}/$this->{test_web}/NoView");
}

sub test_modtime_D {
    my $this = shift;
    $this->_make_attachments_fixture();
    $this->_check_modtime(
        "/$this->{test_web}/$this->{test_topic}$F",
        "$TWiki::cfg{PubDir}/$this->{test_web}/$this->{test_topic}");
    $this->_check_modtime(
        "/$this->{test_web}/NoView$F",
        "$TWiki::cfg{PubDir}/$this->{test_web}/NoView");
}

sub test_modtime_T {
    my $this = shift;
    $this->_check_modtime(
        "/$this->{test_web}/$this->{test_topic}$T",
        "$TWiki::cfg{DataDir}/$this->{test_web}/$this->{test_topic}.txt");
    $this->_check_modtime(
        "/$this->{test_web}/NoView$T",
        "$TWiki::cfg{DataDir}/$this->{test_web}/NoView.txt");
}

sub test_modtime_A {
    my $this = shift;
    $this->_make_attachments_fixture();
    $this->_check_modtime(
        "/$this->{test_web}/$this->{test_topic}$F/A.gif",
        "$TWiki::cfg{PubDir}/$this->{test_web}/$this->{test_topic}/A.gif");
    $this->_check_modtime(
        "/$this->{test_web}/NoView$F/A.gif",
        "$TWiki::cfg{PubDir}/$this->{test_web}/NoView/A.gif");
}

sub test_list_R {
    my $this = shift;
    my @elist = TWiki::Func::getListOfWebs('public,user');
    push(@elist, '.');
    @elist = sort @elist;
    my @alist = $this->{handler}->list('/');
    while (scalar(@elist) && scalar(@alist)) {
        $this->assert_str_equals($elist[0], $alist[0]);
        shift @elist; shift@alist;
    }
    $this->assert_equals(scalar(@elist), scalar(@alist));
}

sub test_list_W {
    my $this = shift;
    my @elist = $TWiki::Plugins::SESSION->{store}->getListOfWebs(
        'public,user', $this->{test_web});
    foreach my $f (TWiki::Func::getTopicList( $this->{test_web} )) {
        if (-d "$TWiki::cfg{PubDir}/$this->{test_web}/$f") {
            push( @elist, "$f$F" );
        }
        push(@elist, "$f$T");
    }
    push (@elist, '..');
    push (@elist, '.');
    @elist = sort @elist;
    my @alist = $this->{handler}->list("/$this->{test_web}");
    #print STDERR "E ".join(' ',@elist),"\n";
    #print STDERR "A ".join(' ',@alist),"\n";
    while (scalar(@elist) && scalar(@alist)) {
        $this->assert_str_equals($elist[0], $alist[0]);
        shift @elist; shift@alist;
    }
    $this->assert_equals(scalar(@elist), scalar(@alist));

    @alist = $this->{handler}->list("/$this->{test_web}/NoView");
    $this->assert_equals(0, scalar(@alist));
}

sub test_list_D {
    my $this = shift;
    $this->_make_attachments_fixture();
    my @elist = ('.', '..', 'A.gif', 'B C.jpg');
    my @alist = $this->{handler}->list(
        "$this->{test_web}/$this->{test_topic}$F");
    while (scalar(@elist) && scalar(@alist)) {
        $this->assert_str_equals($elist[0], $alist[0]);
        shift @elist; shift@alist;
    }
    $this->assert_equals(scalar(@elist), scalar(@alist));
}

sub test_list_T {
    my $this = shift;
    $this->_make_attachments_fixture();
    my @alist = $this->{handler}->list(
        "$this->{test_web}/$this->{test_topic}$T");
    $this->assert_equals(1, scalar(@alist));
    $this->assert_str_equals("$this->{test_topic}$T", $alist[0]);
}

sub test_list_A {
    my $this = shift;
    $this->_make_attachments_fixture();
    my @alist = $this->{handler}->list(
        "$this->{test_web}/$this->{test_topic}$F/A.gif");
    $this->assert_equals(1, scalar(@alist));
    $this->assert_str_equals("A.gif", $alist[0]);
}

sub test_stat_R {
    my $this = shift;
    $this->_check_stat('/', $TWiki::cfg{DataDir}, 01777);
}

sub test_stat_W {
    my $this = shift;
    $this->_check_stat(
        "/$this->{test_web}",
        "$TWiki::cfg{DataDir}/$this->{test_web}", 01777);
    $this->_check_stat(
        "/Notaweb",
        "$TWiki::cfg{DataDir}/Notaweb", 0);
    $this->_check_stat(
        "/$this->{test_web}/NoView",
        "$TWiki::cfg{DataDir}/$this->{test_web}/NoView", 01111);
    $this->_check_stat(
        "/$this->{test_web}/NoChange",
        "$TWiki::cfg{DataDir}/$this->{test_web}/NoChange", 01555);
}

sub test_stat_D {
    my $this = shift;
    $this->_check_stat(
        "/$this->{test_web}/$this->{test_topic}$F",
        "$TWiki::cfg{PubDir}/$this->{test_web}/$this->{test_topic}",
        01777);
    $this->_check_stat(
        "/$this->{test_web}/NoView$F",
        "$TWiki::cfg{PubDir}/$this->{test_web}/NoView",
        01111);
}

sub test_stat_T {
    my $this = shift;
    $this->_check_stat(
        "/$this->{test_web}/$this->{test_topic}$T",
        "$TWiki::cfg{DataDir}/$this->{test_web}/$this->{test_topic}.txt",
        0666);
    $this->_check_stat(
        "/$this->{test_web}/NoView$T",
        "$TWiki::cfg{DataDir}/$this->{test_web}/NoView.txt",
        0000);
    $this->_check_stat(
        "/$this->{test_web}/NoChange$T",
        "$TWiki::cfg{DataDir}/$this->{test_web}/NoChange.txt",
        0444);
}

sub test_stat_A {
    my $this = shift;
    $this->_make_attachments_fixture();
    $this->_check_stat(
        "/$this->{test_web}/$this->{test_topic}$F/A.gif",
        "$TWiki::cfg{PubDir}/$this->{test_web}/$this->{test_topic}/A.gif");
}

sub test_mkdir_R {
    my $this = shift;
    # Should be blocked
    my $s = $this->{handler}->mkdir('/');
    $this->assert($!);
    $this->assert(!$s);
}

sub test_mkdir_W_preexisting {
    my $this = shift;
    my $web = $this->{test_web};
	$this->assert( TWiki::Func::webExists($web) );
	my @elist = TWiki::Func::getTopicList($web);
    $this->assert($this->{handler}->mkdir("/$web"));
	my @alist = TWiki::Func::getTopicList($web);
    while (scalar(@elist) && scalar(@alist)) {
        $this->assert_str_equals($elist[0], $alist[0]);
        shift @elist; shift@alist;
    }
    $this->assert_equals(scalar(@elist), scalar(@alist));
}

sub test_mkdir_W_unexisting {
    my $this = shift;
    my $web = "$this->{test_web}_NUMPTY";
	my @elist = TWiki::Func::getTopicList('_default');
    $this->assert($this->{handler}->mkdir("/$web"));
	my @alist = TWiki::Func::getTopicList($web);
    while (scalar(@elist) && scalar(@alist)) {
        $this->assert_str_equals($elist[0], $alist[0]);
        shift @elist; shift@alist;
    }
    $this->assert_equals(scalar(@elist), scalar(@alist));
}

sub test_mkdir_D_withtopic {
    my $this = shift;
    my $web = "$this->{test_web}/$this->{test_topic}$F";
    $this->assert($this->{handler}->mkdir("/$web"));
    $this->assert(
        -e "$TWiki::cfg{PubDir}/$this->{test_web}/$this->{test_topic}");
    $this->assert(
        -d "$TWiki::cfg{PubDir}/$this->{test_web}/$this->{test_topic}");
}

sub test_mkdir_T {
    my $this = shift;
    my $web = "$this->{test_web}/$this->{test_topic}$T";
    $this->assert(!$this->{handler}->mkdir("/$web"));
    $this->assert($!);
}

sub test_mkdir_A {
    my $this = shift;
    # Can't mkdir in an attachments dir
    my $web = "$this->{test_web}/$this->{test_topic}$F/nah";
    $this->assert(!$this->{handler}->mkdir("/$web"));
    $this->assert($!);
}

sub test_delete_R {
    my $this = shift;
    # Can't delete the root
    $this->assert(!$this->{handler}->delete("/"));
}

sub test_delete_W {
    my $this = shift;
    TWiki::Func::createWeb("$this->{test_web}/blah");
    $this->assert(!$this->{handler}->delete("/$this->{test_web}/blah"));
    $this->assert(TWiki::Func::webExists("$this->{test_web}/blah"));
}

sub test_delete_D {
    my $this = shift;
    # Delete an attachments directory; refuse
    $this->_make_attachments_fixture();
    $this->assert(!$this->{handler}->delete("/$this->{test_web}/$this->{test_topic}$F"));
}

sub test_delete_T {
    my $this = shift;

    $this->assert(!$this->{handler}->delete("/$this->{test_web}/NotATopic"));
    $this->assert(TWiki::Func::topicExists($this->{test_web},$this->{test_topic}));
    my $n = '';
    while (TWiki::Func::topicExists(
        $TWiki::cfg{TrashWebName}, $this->{test_topic}.$n)) {
        $n++;
    }
    $this->_make_attachments_fixture();
    $this->assert($this->{handler}->delete("/$this->{test_web}/$this->{test_topic}$T"));
    $this->assert(!TWiki::Func::topicExists($this->{test_web}, $this->{test_topic}));
    $this->assert(TWiki::Func::topicExists($TWiki::cfg{TrashWebName}, "$this->{test_topic}$n"));
    $this->assert(TWiki::Func::attachmentExists($TWiki::cfg{TrashWebName}, "$this->{test_topic}$n", "A.gif"));

    $this->assert(!$this->{handler}->test('e', "/$this->{test_web}/$this->{test_topic}$T"));
    $this->assert(!$this->{handler}->test('e', "/$this->{test_web}/$this->{test_topic}$F"));
}

sub test_delete_A {
    my $this = shift;
    $this->assert(!$this->{handler}->delete("/$this->{test_web}/$this->{test_topic}$F/A.gif"));
    $this->_make_attachments_fixture();
    $this->assert($this->{handler}->delete("/$this->{test_web}/$this->{test_topic}$F/A.gif"));
    $this->assert(!TWiki::Func::attachmentExists($this->{test_web}, "$this->{test_topic}", "A.gif"));
}

sub test_rmdir_R {
    my $this = shift;
    # Can't delete the root
    $this->assert(!$this->{handler}->delete("/"));
}

sub test_rmdir_W {
    my $this = shift;
    # non-existant
    $this->assert(!$this->{handler}->rmdir("/$this->{test_web}/blah"));
    TWiki::Func::createWeb("$this->{test_web}/blah");
	TWiki::Func::saveTopic(
        "$this->{test_web}/blah", "BlahBlah",
        undef, "Numpty" );
    my $n = '';
    while (TWiki::Func::webExists(
        "$TWiki::cfg{TrashWebName}/$this->{test_web}/blah$n")) {
        $n++;
    }
    # Web not empty
    $this->assert(!$this->{handler}->rmdir("/$this->{test_web}/blah"), $!);

    # empty it
    $this->assert(TWiki::Func::webExists("$this->{test_web}/blah"));
    foreach my $topic ($this->{handler}->list("/$this->{test_web}/blah")) {
        next if $topic =~ /^\.+$/;
        next if $topic eq "WebPreferences$T";
        $this->{handler}->delete("/$this->{test_web}/blah/$topic");
    }
    $this->assert(TWiki::Func::webExists("$this->{test_web}/blah"));
    $this->assert($this->{handler}->rmdir("/$this->{test_web}/blah"), $!);
    $this->assert(!TWiki::Func::webExists("$this->{test_web}/blah"));
    $this->assert(TWiki::Func::webExists(
        "$TWiki::cfg{TrashWebName}/$this->{test_web}/blah$n"));
    # non-empty
    $this->assert(!$this->{handler}->rmdir("/$this->{test_web}"));
}

sub test_rmdir_D {
    my $this = shift;
    # non-existant
    $this->assert(!$this->{handler}->rmdir("/$this->{test_web}/$this->{test_topic}$F"));
    $this->_make_attachments_fixture();
    # not empty
    $this->assert(!$this->{handler}->rmdir("/$this->{test_web}/$this->{test_topic}$F"));
    # empty it
    $this->{handler}->delete("/$this->{test_web}/$this->{test_topic}$F/A.gif");
    $this->{handler}->delete("/$this->{test_web}/$this->{test_topic}$F/B C.jpg");
    $this->assert($this->{handler}->rmdir("/$this->{test_web}/$this->{test_topic}$F"));
}

sub test_rmdir_T {
    my $this = shift;
    # Should just delete the topic
    $this->assert($this->{handler}->rmdir("/$this->{test_web}/$this->{test_topic}$T"));
}

sub test_rmdir_A {
    my $this = shift;
    $this->_make_attachments_fixture();
    $this->assert($this->{handler}->rmdir("/$this->{test_web}/$this->{test_topic}$F/A.gif"));
    $this->assert(!TWiki::Func::attachmentExists($this->{test_web},$this->{test_topic},"A.gif"));
}

sub test_open_R_read {
    my $this = shift;
    $this->assert(!$this->{handler}->open_read("/"));
}

sub test_open_read_W {
    my $this = shift;
    $this->assert(!$this->{handler}->open_read("/$this->{test_web}"));
}

sub test_open_read_D {
    my $this = shift;
    $this->assert(!$this->{handler}->open_read("/$this->{test_web}/$this->{test_topic}$F"));
}

sub test_open_read_T {
    my $this = shift;
    my $fh = $this->{handler}->open_read(
        "/$this->{test_web}/$this->{test_topic}$T");
    $this->assert($fh);
    local $/;
    my $data = <$fh>;
    $this->assert($this->{handler}->close_read($fh));
    $this->assert($data =~ /BLEEGLE/s);
}

sub test_open_read_A {
    my $this = shift;
    $this->_make_attachments_fixture();
    my $fh = $this->{handler}->open_read(
        "/$this->{test_web}/$this->{test_topic}$F/A.gif");
    $this->assert($fh, $!);
    local $/;
    my $data = <$fh>;
    $this->assert($this->{handler}->close_read($fh));
    $this->assert($data =~ /Blah/s);
}

sub test_open_R_write {
    my $this = shift;
    $this->assert(!$this->{handler}->open_write("/"));
}

sub test_open_write_W {
    my $this = shift;
    $this->assert(!$this->{handler}->open_write("/$this->{test_web}"));
}

sub test_open_write_D {
    my $this = shift;
    $this->assert(!$this->{handler}->open_write("/$this->{test_web}/$this->{test_topic}$F"));
}

sub test_open_write_T {
    my $this = shift;

    # Existing topic
    my $fh = $this->{handler}->open_write(
        "/$this->{test_web}/$this->{test_topic}$T");
    $this->assert($fh, $!);
    print $fh "BINGO";
    $this->assert($this->{handler}->close_write($fh));
    my ($meta, $text) = TWiki::Func::readTopic(
        $this->{test_web},$this->{test_topic});
    $this->assert($text =~ /BINGO/s, $text);

    # new topic
    $fh = $this->{handler}->open_write(
        "/$this->{test_web}/NewTopic$T");
    $this->assert($fh, $!);
    print $fh "BINGO";
    $this->assert($this->{handler}->close_write($fh));
    ($meta, $text) = TWiki::Func::readTopic($this->{test_web},"NewTopic");
    $this->assert($text =~ /BINGO/s, $text);
}

sub test_open_write_A {
    my $this = shift;
    $this->_make_attachments_fixture();

    # Existing attachment
    my $fh = $this->{handler}->open_write(
        "/$this->{test_web}/$this->{test_topic}$F/A.gif");
    $this->assert($fh, $!);
    print $fh "BINGO";
    $this->assert($this->{handler}->close_read($fh));

    $fh = $this->{handler}->open_read(
        "/$this->{test_web}/$this->{test_topic}$F/A.gif");
    $this->assert($fh, $!);
    local $/;
    my $data = <$fh>;
    $this->assert($this->{handler}->close_read($fh));
    $this->assert($data !~ /Blah/s);
    $this->assert($data =~ /BINGO/s);

    # New attachment
    $fh = $this->{handler}->open_write(
        "/$this->{test_web}/$this->{test_topic}$F/D.gif");
    $this->assert($fh, $!);
    print $fh "NEWBIE";
    $this->assert($this->{handler}->close_read($fh));
    $this->assert(TWiki::Func::attachmentExists($this->{test_web},$this->{test_topic},"D.gif"));
    $fh = $this->{handler}->open_read(
        "/$this->{test_web}/$this->{test_topic}$F/A.gif");
    $this->assert($fh, $!);
    local $/;
    $data = <$fh>;
    $this->assert($this->{handler}->close_read($fh));
    $this->assert($data =~ /NEWBIE/s, $data);
}

# later
sub test_list_details {
    my $this = shift;
}

# later
sub test_size {
    my $this = shift;
}

# later
sub test_seek {
    my $this = shift;
}

# later
sub test_utime {
    my $this = shift;
}

1;

