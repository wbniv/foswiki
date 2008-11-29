use strict;

package FileTimeTest;

use base qw(FoswikiTestCase);

use TWiki::Contrib::DBCacheContrib::FileTime;
use TWiki::Contrib::DBCacheContrib::Array;
use TWiki::Func;
use Storable;

my $files; # fixture
my $testweb = "TemporaryFileTimeTestWeb";
my $root;
my $acache;
my $scache;
my $twiki;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

sub _readFile {
    my $f = shift;
    local $/ = undef;
    open(F,"<",$f) || die $!;
    my $x = <F>;
    close(F);
    return $x;
}

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    $twiki = new TWiki( "TestUser1" );

    $twiki->{store}->createWeb($twiki->{user}, $testweb);

    my $dbt = _readFile("DBCacheContrib/testDB.dat");
    $root = TWiki::Func::getDataDir() . "/$testweb";
    $files = new TWiki::Contrib::DBCacheContrib::Array();
    foreach my $t ( split(/\<TOPIC\>/,$dbt)) {
        if ( $t =~ m/\"(.*?)\"/o ) {
            $twiki->{store}->saveTopic( $twiki->{user}, $testweb, $1,
                                        $t, undef );
            $files->add(new TWiki::Contrib::DBCacheContrib::FileTime( "$root/$1.txt" ));
        }
    }
    $acache = "$root/cache.Archive";
    $scache = "$root/cache.Storable";
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
    $twiki->{store}->removeWeb($twiki->{user}, $testweb);
}

sub test_OK {
    my $this = shift;
    # Make sure the file times reflect what's on disc
    foreach my $ft ( $files->getValues() ) {
        $this->assert($ft->uptodate());
    }
}

sub test_touchOne {
    my $this = shift;
    sleep(1);# make sure file times are different
    `touch $root/Dir4.txt`;

    foreach my $ft ( $files->getValues() ) {
        if ( $ft->{file} eq "$root/Dir4.txt") {
            $this->assert(!$ft->uptodate());
        } else {
            $this->assert($ft->uptodate());
        }
    }
}

sub test_delOne {
    my $this = shift;
    `rm $root/Dir2.txt`;

    foreach my $ft ( $files->getValues() ) {
        if ( $ft->{file} eq "$root/Dir2.txt") {
            $this->assert(!$ft->uptodate());
        } else {
            $this->assert($ft->uptodate());
        }
    }
}

1;
