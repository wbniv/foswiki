use strict;

package FuncUsersContribSuite;

# Some basic tests for adding/removing users in the TWiki users topic,
# and finding them again.

use base qw(FoswikiTestCase);

use TWiki;
use TWiki::Contrib::FuncUsersContrib;
use TWiki::UI::Register;
use Error qw( :try );

my $twiki;
my $me;
my $saveTopic;
my $ttpath;

my $testSysWeb = 'TemporaryFuncUsersTestsSystemWeb';
my $testNormalWeb = "TemporaryFuncUsersTestsWeb";
my $testUsersWeb = "TemporaryFuncUsersTestsUsersWeb";
my $testTopic = "TmpUsersTopic".time();
my $testUser;

my $topicquery;

my $original;

use vars qw( @mails );

sub registerUser {
    my ($this, $login, $wn, $email) = @_;
    $TWiki::cfg{Register}{NeedVerification} = 0;
    my $query = new CGI ({
                          'TopicName' => [
                                          'UserRegistration'
                                         ],
                          'Twk1Email' => [
                                          $email
                                         ],
                          'Twk1WikiName' => [
                                             $wn
                                            ],
                          'Twk1Name' => [
                                         'Test User'
                                        ],
                          'Twk0Comment' => [
                                            ''
                                           ],
                          'Twk1LoginName' => [
                                              $login
                                             ],
                          'Twk1FirstName' => [
                                              'Test'
                                             ],
                          'Twk1LastName' => [
                                             'User'
                                            ],
                          'action' => [
                                       'register'
                                      ]
                         });

    $query->path_info( "/$testUsersWeb/UserRegistration" );
    my $session = new TWiki( $TWiki::cfg{DefaultUserName}, $query);
    $session->{net}->setMailHandler(\&sentMail);

    try {
        TWiki::UI::Register::register_cgi($session);
    } catch TWiki::OopsException with {

    } catch Error::Simple with {
        $this->assert(0, shift->stringify());
    } otherwise {
        $this->assert(0, "expected an oops redirect");
    };
}

# callback used by Net.pm
sub sentMail {
    my($net, $mess ) = @_;
    push( @mails, $mess );
    return undef;
}

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    $original = $TWiki::cfg{SystemWebName};
    $TWiki::cfg{UsersWebName} = $testUsersWeb;
    $TWiki::cfg{SystemWebName} = $testSysWeb;
    $TWiki::cfg{LocalSitePreferences} = "$testUsersWeb.SitePreferences";
    $TWiki::cfg{MapUserToWikiName} = 1;
    $TWiki::cfg{PasswordManager} = 'TWiki::Users::HtPasswdUser';
    $TWiki::cfg{Htpasswd}{FileName} = "/tmp/htpasswd";
    open(F,">$TWiki::cfg{Htpasswd}{FileName}") || die;
    close F;
    $TWiki::cfg{MinPasswordLength} = 0;

    $twiki = new TWiki('AdminUser');

    $topicquery = new CGI( "" );
    $topicquery->path_info("/$testNormalWeb/$testTopic");
    try {
        my $twikiUserObject = $twiki->{user};
        $twiki->{store}->createWeb($twikiUserObject, $testUsersWeb);

        # Create an admin group/user
        $twiki->{store}->saveTopic(
            $twiki->{user}, $testUsersWeb, 'AdminGroup',
            '   * Set GROUP = '.$twikiUserObject->wikiName().", AdminGroup\n");

        $twiki->{store}->createWeb($twikiUserObject, $testSysWeb, $original);
        $twiki->{store}->createWeb($twikiUserObject, $testNormalWeb, '_default');

        $twiki->{store}->copyTopic(
            $twikiUserObject, $original, $TWiki::cfg{SitePrefsTopicName},
            $testSysWeb, $TWiki::cfg{SitePrefsTopicName} );

        $this->registerUser('usera', 'UserA', 'usera@example.com');
        $this->registerUser('userb', 'UserB', 'userb@example.com');
        $this->registerUser('userc', 'UserC', 'userc@example.com');

        $twiki->{store}->saveTopic($twiki->{user}, $testUsersWeb, 'AandBGroup',
                  "   * Set GROUP = UserA, UserB");
        $twiki->{store}->saveTopic($twiki->{user}, $testUsersWeb, 'AandCGroup',
                  "   * Set GROUP = UserA, UserC");
        $twiki->{store}->saveTopic($twiki->{user}, $testUsersWeb, 'BandCGroup',
                  "   * Set GROUP = UserC, UserB");

    } catch TWiki::AccessControlException with {
        my $e = shift;
        $this->assert(0,$e->stringify());
    } catch Error::Simple with {
        $this->assert(0,shift->stringify()||'');
    };
    $twiki = new TWiki();
    $TWiki::Plugins::SESSION = $twiki;
    @mails = ();
}

sub tear_down {
    my $this = shift;

    $this->removeWebFixture($twiki, $testUsersWeb);
    $this->removeWebFixture($twiki, $testSysWeb);
    $this->removeWebFixture($twiki, $testNormalWeb);
    unlink($TWiki::cfg{Htpasswd}{FileName});
    $this->SUPER::tear_down();
}

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

sub test_getListOfUsers {
    my $this = shift;
    my $list = TWiki::Func::getListOfUsers();
    my $ulist = join(',', map{$_->stringify()}@$list);
    $this->assert_str_equals("usera/TemporaryFuncUsersTestsUsersWeb.UserA,userb/TemporaryFuncUsersTestsUsersWeb.UserB,userc/TemporaryFuncUsersTestsUsersWeb.UserC", $ulist);
}

sub test_getListOfGroups {
    my $this = shift;
    my $list = TWiki::Func::getListOfGroups();
    my $ulist = join(',', map{$_->stringify()}@$list);
    $this->assert_str_equals('TemporaryFuncUsersTestsUsersWeb.AandBGroup/TemporaryFuncUsersTestsUsersWeb.AandBGroup,TemporaryFuncUsersTestsUsersWeb.AandCGroup/TemporaryFuncUsersTestsUsersWeb.AandCGroup,TemporaryFuncUsersTestsUsersWeb.BandCGroup/TemporaryFuncUsersTestsUsersWeb.BandCGroup,AdminGroup/TemporaryFuncUsersTestsUsersWeb.AdminGroup', $ulist);
}

sub test_lookupUser {
    my $this = shift;
    my $u = TWiki::Func::lookupUser(login=>'userb');
    $this->assert_str_equals('userb/TemporaryFuncUsersTestsUsersWeb.UserB',
                             $u->stringify());
    $u = TWiki::Func::lookupUser(wikiname=>'UserB');
    $this->assert_str_equals('userb/TemporaryFuncUsersTestsUsersWeb.UserB',
                             $u->stringify());
    $u = TWiki::Func::lookupUser(wikiname=>'%MAINWEB%.UserB');
    $this->assert_str_equals('userb/TemporaryFuncUsersTestsUsersWeb.UserB',
                             $u->stringify());
    $u = TWiki::Func::lookupUser(wikiname=>$testUsersWeb.'.UserB');
    $this->assert_str_equals('userb/TemporaryFuncUsersTestsUsersWeb.UserB',
                             $u->stringify());
    $u = TWiki::Func::lookupUser(email=>'userb@example.com');
    $this->assert_str_equals('userb/TemporaryFuncUsersTestsUsersWeb.UserB',
                             $u->[0]->stringify());
}

sub test_isAdmin {
    my $this = shift;
    my $list = TWiki::Func::getListOfUsers();
    foreach my $u ( @$list ) {
        $twiki->{user} = $u;
        $this->assert(!TWiki::Func::isAdmin(), $u->stringify());
    }
}

sub test_isInGroup {
    my $this = shift;
    $twiki->{user} = TWiki::Func::lookupUser(wikiname=>'UserA');
    $this->assert(TWiki::Func::isInGroup('AandBGroup'));
    $this->assert(TWiki::Func::isInGroup('AandCGroup'));
    $this->assert(!TWiki::Func::isInGroup('BandCGroup'));
}

sub test_setACLsBodyText {
    my $this = shift;

    my $ua = TWiki::Func::lookupUser(wikiname=>'UserA')->webDotWikiName();
    my $ub = TWiki::Func::lookupUser(wikiname=>'UserB')->webDotWikiName();
    my $uc = TWiki::Func::lookupUser(wikiname=>'UserC')->webDotWikiName();
    my $acls = {
        $ua => { VIEW => 1, CHANGE => 0, RENAME => 1 },
        $ub => { VIEW => 0, CHANGE => 1, RENAME => 0 },
        $uc => { VIEW => 0, CHANGE => 0, RENAME => 1 },
    };
    TWiki::Func::setACLs([ qw(VIEW CHANGE RENAME) ],
                         $acls,
                         $testNormalWeb,
                         $testTopic,
                         1);
    $twiki = new TWiki();
    $TWiki::Plugins::SESSION = $twiki;
    $this->assert(TWiki::Func::checkAccessPermission(
        'VIEW', 'UserA', undef, $testTopic, $testNormalWeb));
    $this->assert(!TWiki::Func::checkAccessPermission(
        'CHANGE', 'UserA', undef, $testTopic, $testNormalWeb));
    $this->assert(TWiki::Func::checkAccessPermission(
        'RENAME', 'UserA', undef, $testTopic, $testNormalWeb));
    $this->assert(!TWiki::Func::checkAccessPermission(
        'VIEW', 'UserB', undef, $testTopic, $testNormalWeb));
    $this->assert(TWiki::Func::checkAccessPermission(
        'CHANGE', 'UserB', undef, $testTopic, $testNormalWeb));
    $this->assert(!TWiki::Func::checkAccessPermission(
        'RENAME', 'UserB', undef, $testTopic, $testNormalWeb));
    $this->assert(!TWiki::Func::checkAccessPermission(
        'VIEW', 'UserC', undef, $testTopic, $testNormalWeb));
    $this->assert(!TWiki::Func::checkAccessPermission(
        'CHANGE', 'UserC', undef, $testTopic, $testNormalWeb));
    $this->assert(TWiki::Func::checkAccessPermission(
        'RENAME', 'UserC', undef, $testTopic, $testNormalWeb));
}

sub test_setACLsPrefs {
    my $this = shift;

    my $ua = TWiki::Func::lookupUser(wikiname=>'UserA')->webDotWikiName();
    my $ub = TWiki::Func::lookupUser(wikiname=>'UserB')->webDotWikiName();
    my $uc = TWiki::Func::lookupUser(wikiname=>'UserC')->webDotWikiName();
    my $acls = {
        $ua => { VIEW => 1, CHANGE => 0, RENAME => 1 },
        $ub => { VIEW => 0, CHANGE => 1, RENAME => 0 },
        $uc => { VIEW => 0, CHANGE => 0, RENAME => 1 },
    };
    TWiki::Func::setACLs([ qw(VIEW CHANGE RENAME) ],
                         $acls,
                         $testNormalWeb,
                         $testTopic,
                         0);
    $twiki = new TWiki();
    $TWiki::Plugins::SESSION = $twiki;
    $this->assert(TWiki::Func::checkAccessPermission(
        'VIEW', 'UserA', undef, $testTopic, $testNormalWeb));
    $this->assert(!TWiki::Func::checkAccessPermission(
        'CHANGE', 'UserA', undef, $testTopic, $testNormalWeb));
    $this->assert(TWiki::Func::checkAccessPermission(
        'RENAME', 'UserA', undef, $testTopic, $testNormalWeb));
    $this->assert(!TWiki::Func::checkAccessPermission(
        'VIEW', 'UserB', undef, $testTopic, $testNormalWeb));
    $this->assert(TWiki::Func::checkAccessPermission(
        'CHANGE', 'UserB', undef, $testTopic, $testNormalWeb));
    $this->assert(!TWiki::Func::checkAccessPermission(
        'RENAME', 'UserB', undef, $testTopic, $testNormalWeb));
    $this->assert(!TWiki::Func::checkAccessPermission(
        'VIEW', 'UserC', undef, $testTopic, $testNormalWeb));
    $this->assert(!TWiki::Func::checkAccessPermission(
        'CHANGE', 'UserC', undef, $testTopic, $testNormalWeb));
    $this->assert(TWiki::Func::checkAccessPermission(
        'RENAME', 'UserC', undef, $testTopic, $testNormalWeb));

    # totally inadequate test of getACLs
    $acls = TWiki::Func::getACLs([ 'VIEW' ],
                         $testNormalWeb,
                         $testTopic);
    $this->assert($acls->{"$testUsersWeb.UserA"}->{VIEW});
    $this->assert(!$acls->{"$testUsersWeb.UserB"}->{VIEW});
    $this->assert(!$acls->{"$testUsersWeb.UserC"}->{VIEW});
}

sub test_getACLsBodyTextIMPLIED {
    my $this = shift;

    my $twiki = new TWiki('AdminUser');
    $twiki->{store}->saveTopic($twiki->{user}, $testNormalWeb, $testTopic,
                  "no allow or deny lines at all");

    # Everyone is allowed
    # No-one is denied
    my $acls = TWiki::Func::getACLs([ 'VIEW' ],
                         $testNormalWeb,
                         $testTopic);
    $this->assert(defined($acls->{"$testUsersWeb.UserA"}));
    $this->assert(defined($acls->{"$testUsersWeb.UserA"}->{VIEW}));
    $this->assert($acls->{"$testUsersWeb.UserA"}->{VIEW});
    $this->assert($acls->{"$testUsersWeb.UserB"}->{VIEW});
    $this->assert($acls->{"$testUsersWeb.UserC"}->{VIEW});
}

sub test_getACLsBodyTextEMPTYDENIED {
    my $this = shift;

    my $twiki = new TWiki('AdminUser');
    $twiki->{store}->saveTopic($twiki->{user}, $testNormalWeb, $testTopic,
                  "      * Set DENYTOPICVIEW =");

    # Everyone is allowed
    # No-one is denied
    my $acls = TWiki::Func::getACLs([ 'VIEW' ],
                         $testNormalWeb,
                         $testTopic);

    $this->assert($acls->{"$testUsersWeb.UserA"}->{VIEW});
    $this->assert($acls->{"$testUsersWeb.UserB"}->{VIEW});
    $this->assert($acls->{"$testUsersWeb.UserC"}->{VIEW});
}

sub test_getACLsBodyTextEMPTYALLOWED {
    my $this = shift;

    my $twiki = new TWiki('AdminUser');
    $twiki->{store}->saveTopic($twiki->{user}, $testNormalWeb, $testTopic,
                  "      * Set ALLOWTOPICVIEW =");

    # totally inadequate test of getACLs
    my $acls = TWiki::Func::getACLs([ 'VIEW' ],
                         $testNormalWeb,
                         $testTopic);
    $this->assert(!$acls->{"$testUsersWeb.UserA"}->{VIEW});
    $this->assert(!$acls->{"$testUsersWeb.UserB"}->{VIEW});
    $this->assert(!$acls->{"$testUsersWeb.UserC"}->{VIEW});
}

sub test_getACLsBodyTextUserADENIED {
    my $this = shift;

    my $twiki = new TWiki('AdminUser');
    $twiki->{store}->saveTopic($twiki->{user}, $testNormalWeb, $testTopic,
                  "      * Set DENYTOPICVIEW = UserA");

    # totally inadequate test of getACLs
    my $acls = TWiki::Func::getACLs([ 'VIEW' ],
                         $testNormalWeb,
                         $testTopic);
    $this->assert(!$acls->{"$testUsersWeb.UserA"}->{VIEW});
    $this->assert($acls->{"$testUsersWeb.UserB"}->{VIEW});
    $this->assert($acls->{"$testUsersWeb.UserC"}->{VIEW});
}

sub test_getACLsBodyTextUserAALLOWED {
    my $this = shift;

    my $twiki = new TWiki('AdminUser');
    $twiki->{store}->saveTopic($twiki->{user}, $testNormalWeb, $testTopic,
                  "      * Set ALLOWTOPICVIEW = UserA");

    # totally inadequate test of getACLs
    my $acls = TWiki::Func::getACLs([ 'VIEW' ],
                         $testNormalWeb,
                         $testTopic);
    $this->assert($acls->{"$testUsersWeb.UserA"}->{VIEW});
    $this->assert(!$acls->{"$testUsersWeb.UserB"}->{VIEW});
    $this->assert(!$acls->{"$testUsersWeb.UserC"}->{VIEW});
}

sub test_getACLsBodyTextUserAALLOWEDUserBDENIED {
    my $this = shift;

    my $twiki = new TWiki('AdminUser');
    $twiki->{store}->saveTopic($twiki->{user}, $testNormalWeb, $testTopic,
                  "      * Set ALLOWTOPICVIEW = UserA"."\n".
                  "      * Set DENYTOPICVIEW = UserB");

    # totally inadequate test of getACLs
    my $acls = TWiki::Func::getACLs([ 'VIEW' ],
                         $testNormalWeb,
                         $testTopic);
    $this->assert($acls->{"$testUsersWeb.UserA"}->{VIEW});
    $this->assert(!$acls->{"$testUsersWeb.UserB"}->{VIEW});
    $this->assert(!$acls->{"$testUsersWeb.UserC"}->{VIEW});
}

sub test_setWEBACLsBodyText {
    my $this = shift;

    my $ua = TWiki::Func::lookupUser(wikiname=>'UserA')->webDotWikiName();
    my $ub = TWiki::Func::lookupUser(wikiname=>'UserB')->webDotWikiName();
    my $uc = TWiki::Func::lookupUser(wikiname=>'UserC')->webDotWikiName();
    my $acls = {
        $ua => { VIEW => 1, CHANGE => 0, RENAME => 1 },
        $ub => { VIEW => 0, CHANGE => 1, RENAME => 0 },
        $uc => { VIEW => 0, CHANGE => 0, RENAME => 1 },
    };
    TWiki::Func::setACLs([ qw(VIEW CHANGE RENAME) ],
                         $acls,
                         $testNormalWeb,
                         undef,
                         1);
    $twiki = new TWiki();
    $TWiki::Plugins::SESSION = $twiki;
    $this->assert(TWiki::Func::checkAccessPermission(
        'VIEW', 'UserA', undef, $testTopic, $testNormalWeb));
    $this->assert(!TWiki::Func::checkAccessPermission(
        'CHANGE', 'UserA', undef, $testTopic, $testNormalWeb));
    $this->assert(TWiki::Func::checkAccessPermission(
        'RENAME', 'UserA', undef, $testTopic, $testNormalWeb));
    $this->assert(!TWiki::Func::checkAccessPermission(
        'VIEW', 'UserB', undef, $testTopic, $testNormalWeb));
    $this->assert(TWiki::Func::checkAccessPermission(
        'CHANGE', 'UserB', undef, $testTopic, $testNormalWeb));
    $this->assert(!TWiki::Func::checkAccessPermission(
        'RENAME', 'UserB', undef, $testTopic, $testNormalWeb));
    $this->assert(!TWiki::Func::checkAccessPermission(
        'VIEW', 'UserC', undef, $testTopic, $testNormalWeb));
    $this->assert(!TWiki::Func::checkAccessPermission(
        'CHANGE', 'UserC', undef, $testTopic, $testNormalWeb));
    $this->assert(TWiki::Func::checkAccessPermission(
        'RENAME', 'UserC', undef, $testTopic, $testNormalWeb));

    # totally inadequate test of getACLs
    my $get_acls = TWiki::Func::getACLs([ qw(VIEW CHANGE RENAME) ],
                         $testNormalWeb,
                         undef);
    $this->assert($get_acls->{"$testUsersWeb.UserA"}->{VIEW});
    $this->assert(!$get_acls->{"$testUsersWeb.UserB"}->{VIEW});
    $this->assert(!$get_acls->{"$testUsersWeb.UserC"}->{VIEW});

    $this->assert(!$get_acls->{"$testUsersWeb.UserA"}->{CHANGE});
    $this->assert($get_acls->{"$testUsersWeb.UserB"}->{CHANGE});
    $this->assert(!$get_acls->{"$testUsersWeb.UserC"}->{CHANGE});

    $this->assert($get_acls->{"$testUsersWeb.UserA"}->{RENAME});
    $this->assert(!$get_acls->{"$testUsersWeb.UserB"}->{RENAME});
    $this->assert($get_acls->{"$testUsersWeb.UserC"}->{RENAME});
}

sub test_setWEBACLsPrefs {
    my $this = shift;

    my $ua = TWiki::Func::lookupUser(wikiname=>'UserA')->webDotWikiName();
    my $ub = TWiki::Func::lookupUser(wikiname=>'UserB')->webDotWikiName();
    my $uc = TWiki::Func::lookupUser(wikiname=>'UserC')->webDotWikiName();
    my $acls = {
        $ua => { VIEW => 1, CHANGE => 0, RENAME => 1 },
        $ub => { VIEW => 0, CHANGE => 1, RENAME => 0 },
        $uc => { VIEW => 0, CHANGE => 0, RENAME => 1 },
    };
    TWiki::Func::setACLs([ qw(VIEW CHANGE RENAME) ],
                         $acls,
                         $testNormalWeb,
                         undef,
                         0);
    $twiki = new TWiki();
    $TWiki::Plugins::SESSION = $twiki;
    $this->assert(TWiki::Func::checkAccessPermission(
        'VIEW', 'UserA', undef, undef, $testNormalWeb));
    $this->assert(!TWiki::Func::checkAccessPermission(
        'CHANGE', 'UserA', undef, undef, $testNormalWeb));
    $this->assert(TWiki::Func::checkAccessPermission(
        'RENAME', 'UserA', undef, undef, $testNormalWeb));
    $this->assert(!TWiki::Func::checkAccessPermission(
        'VIEW', 'UserB', undef, undef, $testNormalWeb));
    $this->assert(TWiki::Func::checkAccessPermission(
        'CHANGE', 'UserB', undef, undef, $testNormalWeb));
    $this->assert(!TWiki::Func::checkAccessPermission(
        'RENAME', 'UserB', undef, undef, $testNormalWeb));
    $this->assert(!TWiki::Func::checkAccessPermission(
        'VIEW', 'UserC', undef, undef, $testNormalWeb));
    $this->assert(!TWiki::Func::checkAccessPermission(
        'CHANGE', 'UserC', undef, undef, $testNormalWeb));
    $this->assert(TWiki::Func::checkAccessPermission(
        'RENAME', 'UserC', undef, undef, $testNormalWeb));

    # totally inadequate test of getACLs
    my $get_acls = TWiki::Func::getACLs([ qw(VIEW CHANGE RENAME) ],
                         $testNormalWeb,
                         undef);
    $this->assert($get_acls->{"$testUsersWeb.UserA"}->{VIEW});
    $this->assert(!$get_acls->{"$testUsersWeb.UserB"}->{VIEW});
    $this->assert(!$get_acls->{"$testUsersWeb.UserC"}->{VIEW});


    $this->assert(!$get_acls->{"$testUsersWeb.UserA"}->{CHANGE});
    $this->assert($get_acls->{"$testUsersWeb.UserB"}->{CHANGE});
    $this->assert(!$get_acls->{"$testUsersWeb.UserC"}->{CHANGE});

    $this->assert($get_acls->{"$testUsersWeb.UserA"}->{RENAME});
    $this->assert(!$get_acls->{"$testUsersWeb.UserB"}->{RENAME});
    $this->assert($get_acls->{"$testUsersWeb.UserC"}->{RENAME});

}


1;
