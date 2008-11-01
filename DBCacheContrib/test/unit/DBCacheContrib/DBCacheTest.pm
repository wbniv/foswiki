use strict;

use TWiki::Contrib::DBCacheContrib;
use TWiki::Contrib::DBCacheContrib::Map;

use TWiki::Func;

package DBCacheTest;
use base qw(TWikiFnTestCase);

sub new {
    my $self = shift()->SUPER::new('DBCacheTest', @_);
    return $self;
}

# Set up the test fixture
sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    my $meta = new TWiki::Meta($this->{twiki}, $this->{test_web}, "FormTest");

    $meta->putKeyed('FIELD', {name=>"FieldOne",
                              title=>"FieldOne",
                              value=>"Value One",
                          });
    $meta->putKeyed('FIELD',
                    {name=>"FieldTwo",
                     title=>"FieldTwo",
                     value=>"Value Two",
                 });
    $meta->putKeyed('FIELD',
                    {name=>"FieldThree",
                     title=>"FieldThree",
                     value=>"7.1",
                 });
    $meta->putKeyed('FIELD',
                    {name=>"BackSlash",
                     title=>"Back Slash",
                     value=>"One",
                 });
    $meta->putKeyed('FILEATTACHMENT',
                    {name=>"conftest.val",
                     attr=>"",
                     comment=>"Bangra bingo",
                     date=>"1091696180",
                     path=>"conftest.val",
                     size=>"8",
                     user=>"guest",
                     version=>"1.2",
                 });
    $meta->putKeyed('FILEATTACHMENT',
                    {name=>"left.gif",
                     attr=>"",
                     comment=>"left arrer",
                     date=>"1091696102",
                     path=>"left.gif",
                     size=>"107",
                     user=>"guest",
                     version=>"1.1",
                 });
    $meta->putKeyed('FILEATTACHMENT',
                    {name=>"right.gif",
                     attr=>"h",
                     comment=>"",
                     date=>"1091696127",
                     path=>"right.gif",
                     size=>"105",
                     user=>"guest",
                     version=>"1.1",
                 });

    $meta->putKeyed('TOPICINFO',
                    {author=>"guest",
                     date=>"1089644791",
                     format=>"1.0",
                     version=>"1.1",
                 });
    $meta->put('FORM',
               {name=>"ThisForm",
            });
    $meta->put('TOPICMOVED',
               {by=>"guest",
                date=>"1091696242",
                from=>"$this->{test_web}.FormsTest",
                to=>"$this->{test_web}.FormTest",
            });
    $meta->put('TOPICPARENT',
               {name=>"WebHome",
            });

    TWiki::Func::saveTopic( $this->{test_web}, "FormTest", $meta,
                            "CategoryForm" );
    $this->{test_meta} = $meta;
}

sub tear_down {
    my $this = shift;
    unlink(
        TWiki::Func::getWorkArea('DBCacheContrib').
            "/$this->{test_web}._DBCache");
    $this->SUPER::tear_down();
}

# Create a set of test functions for each different store impl
sub list_tests {
    my $this = shift;
    my @set;
                
    my %seen = ();

    my $clz = new Devel::Symdump(qw(DBCacheTest));
    for my $i ($clz->functions()) {
        next unless $i =~ /::verify_/;
        foreach my $inc (@INC) {
            my $d = "$inc/TWiki/Contrib/DBCacheContrib/Archivist";
            if (-d $d) {
                opendir(D, $d) || next;
                foreach my $a (readdir D) {
                    next unless $a =~ s/\.pm$//;
                    my $fn = $i;
                    $fn =~ s/\W/_/g;
                    my $sfn = 'DBCacheTest::test_'.$fn.$a;
                    next if $seen{$sfn}; # bad INC path
                    $seen{$sfn} = 1;
                    no strict 'refs';
                    *$sfn = sub {
                        my $this = shift;
                        $TWiki::cfg{Extensions}{DBCacheContrib}{Archivist} =
                          'TWiki::Contrib::DBCacheContrib::Archivist::'.$a;
                        &$i($this);
                    };
                    use strict 'refs';
                    push(@set, $sfn);
                }
                closedir(D);
            }
        }
    }
    return @set;
}

sub verify_loadSimple {
    my $this = shift;
    my $db = new TWiki::Contrib::DBCacheContrib($this->{test_web});
    my @res = $db->load();
    $this->assert_str_equals("0 3 0", join(' ',@res));
    my $topic = $db->get("WebPreferences");
    $this->assert($topic);
    my $info = $topic->get("info");
    $this->assert_not_null($info);
    $this->assert_equals($topic, $info->get("_up"));
    my $user = $info->get("author");
    $user = $this->{twiki}->{users}->getWikiName($user);
    $this->assert_str_equals("TWikiGuest", $user);
    $this->assert_str_equals("1.1", $info->get("format"));

    $topic = $db->get("FormTest");
    $this->assert_not_null($topic);
    $info = $topic->get("info");
    $this->assert_not_null($info);
    $this->assert_equals($topic, $info->get("_up"));
    $user = $info->get("author");
    $user = $this->{twiki}->{users}->getWikiName($user);
    $this->assert_str_equals("TWikiGuest", $user);
    $this->assert_str_equals("1.1", $info->get("format"));
    $this->assert_str_equals("1.1", $info->get("version"));
    $this->assert_str_equals("WebHome", $topic->get("parent"));
    $this->assert_matches(qr/^CategoryForm\s*$/s, $topic->get("text"));
    $this->assert_str_equals("ThisForm", $topic->get("form"));
    my $form = $topic->get("ThisForm");
    $this->assert_not_null($form);
    $this->assert_equals($topic, $form->get("_up"));
    $this->assert_str_equals("Value One", $form->get("FieldOne"));
    $this->assert_str_equals("Value Two", $form->get("FieldTwo"));
    $this->assert_equals(7.1, $form->get("FieldThree"));
    $this->assert_str_equals("One", $form->get("BackSlash"));

    my $atts = $topic->get("attachments");
    $this->assert_not_null($atts);
    for my $i ( 0..2 ) {
        my $att = $atts->get("[$i]");
        $this->assert_not_null($att);
        $this->assert_equals($topic, $att->get("_up"));
        if( "conftest.val" eq $att->get("name")) {
            $this->assert_str_equals("", $att->get("attr"));
            $this->assert_str_equals("Bangra bingo", $att->get("comment"));
            $this->assert_equals("1091696180", $att->get("date"));
            $this->assert_str_equals("conftest.val", $att->get("path"));
            $this->assert_str_equals(8, $att->get("size"));
            $this->assert_str_equals("guest", $att->get("user"));
            $this->assert_equals(1.2, $att->get("version"));
        } elsif ("left.gif" eq $att->get("name")) {
            $this->assert_str_equals("", $att->get("attr"));
            $this->assert_str_equals("left arrer", $att->get("comment"));
            $this->assert_equals(1091696102, $att->get("date"));
            $this->assert_str_equals("left.gif", $att->get("path"));
            $this->assert_str_equals(107, $att->get("size"));
            $this->assert_str_equals("guest", $att->get("user"));
            $this->assert_equals(1.1, $att->get("version"));
        } else {
            $this->assert_str_equals("right.gif", $att->get("name"));
            $this->assert_str_equals("h", $att->get("attr"));
            $this->assert_str_equals("", $att->get("comment"));
            $this->assert_equals(1091696127, $att->get("date"));
            $this->assert_str_equals("right.gif", $att->get("path"));
            $this->assert_str_equals(105, $att->get("size"));
            $this->assert_str_equals("guest", $att->get("user"));
            $this->assert_equals(1.1, $att->get("version"));
        }
    }

    my $moved = $topic->get("moved");
    $this->assert_not_null($moved);
    $this->assert_equals($topic, $moved->get("_up"));
    $this->assert_str_equals("guest", $moved->get("by"));
    $this->assert_equals(1091696242, $moved->get("date"));
    $this->assert_str_equals(
        "$this->{test_web}.FormsTest", $moved->get("from"));
    $this->assert_str_equals(
        "$this->{test_web}.FormTest", $moved->get("to"));
}

sub verify_cache {
    my $this = shift;
    my $db = new TWiki::Contrib::DBCacheContrib($this->{test_web});
    $this->assert_str_equals($this->{test_web}, $db->{_web});
    $this->assert_equals(0, $db->{loaded});

    # There should be no cache there
    my @res = $db->load();
    $this->assert_equals("0 3 0", join(' ',@res));
    $this->assert_equals(1, $db->{loaded});
    @res = $db->load();
    $this->assert_str_equals("0 0 0", join(' ',@res));
    my $initial = $db;

    # There's a cache there now; read all from cache
    $db = new TWiki::Contrib::DBCacheContrib($this->{test_web});
    $this->assert_equals(0, $db->{loaded});
    @res = $db->load();
    $this->assert_str_equals("3 0 0", join(' ',@res));
    $this->assert_equals(1, $db->{loaded});
    $this->checkSameAs($initial,$db);

    @res = $db->load();
    $this->assert_str_equals("0 0 0", join(' ', @res));
    $this->checkSameAs($initial,$db);

    sleep(1);# wait for clock tick, and re-save one file
    TWiki::Func::saveTopic(
        $this->{test_web}, "FormTest", $this->{test_meta}, "CategoryForm" );

    # One file in the cache has been touched
    $db = new TWiki::Contrib::DBCacheContrib($this->{test_web});
    @res = $db->load();
    $this->assert_str_equals("2 1 0", join(' ',@res));

    $this->checkSameAs($initial,$db);
    $db = new TWiki::Contrib::DBCacheContrib($this->{test_web});
    @res = $db->load();
    $this->assert_str_equals("3 0 0", join(' ',@res));
    $this->checkSameAs($initial,$db);

    # A new file has been created
    TWiki::Func::saveTopicText( $this->{test_web}, "NewFile", "Blah" );

    $db = new TWiki::Contrib::DBCacheContrib($this->{test_web});
    @res = $db->load();
    $this->assert_str_equals("3 1 0", join(' ',@res));

    # One file in the cache has been deleted
    $this->{twiki}->{store}->moveTopic(
        $this->{test_web}, "FormTest", "Trash", "FormTest$$",
        $this->{twiki}->{user});
    $db = new TWiki::Contrib::DBCacheContrib($this->{test_web});
    @res = $db->load();
    $this->assert_str_equals("3 0 1", join(' ',@res));

    $this->{twiki}->{store}->moveTopic(
        $this->{test_web}, "NewFile", "Trash", "NewFile$$",
        $this->{twiki}->{user});
    TWiki::Func::saveTopic(
        $this->{test_web}, "FormTest", $this->{test_meta}, "CategoryForm" );
    $db = new TWiki::Contrib::DBCacheContrib($this->{test_web});
    @res = $db->load();
    $this->assert_str_equals("2 1 1", join(' ',@res));

    $this->checkSameAs($initial, $db);
}

sub checkSameAs {
    my ( $this, $first, $second, $cmping, $checked, $where ) = @_;
    $cmping = "ROOT" unless ( defined($cmping ));
    $checked = {} unless ( defined( $checked ));
    return if ( $checked->{$first} );
    $checked->{$first} = 1;
    $where ||= join(' ',caller());
    my $type = ref($first);

    $this->assert_str_equals(
        $type, ref($second),
        "$cmping:\n|$type|\n|".ref($second)."|\nat $where");
    if ($type =~ /Map$/ || $type =~ /DBCacheContrib$/) {
        $this->checkSameAsMap($first, $second, $cmping, $checked, $where);
    } elsif ($type =~ /Array$/) {
        $this->checkSameAsArray($first, $second, $cmping, $checked, $where);
    } elsif ($type =~ /FileTime$/) {
        $this->checkSameAsFileTime(
            $first, $second, $cmping, $checked, $where);
    } else {
        $this->assert(0,ref($first)." != ".ref($second)." $where");
    }
}

sub checkSameAsMap {
    my ( $this, $first, $second, $cmping, $checked, $where ) = @_;

    foreach my $k ($first->getKeys()) {
        next if $k eq "_up";
        my $a = $first->fastget( $k ) || "";
        my $b = $second->fastget( $k ) || "";
        my $c = "$cmping.$k";
        if (ref($a)) {
            $this->checkSameAs($a, $b, $c, $checked, $where );
        } elsif ( $k !~ /^_/ && $c !~ /\.date$/ ) {
            if($c =~ /\.text$/) {
                $this->assert_matches(qr/^$a\s*$/, $b, "$c ($a!=$b) $where");
            } else {
                $this->assert_str_equals($a, $b, "$c ($a!=$b) $where");
            }
        }
    }
}

sub checkSameAsArray {
    my ( $this, $first, $second, $cmping, $checked, $where ) = @_;

    $this->assert_equals($first->size(), $second->size(), $cmping." ".
                           $first->size()." ". $second->size().$where);
    my $i = 0;
    foreach my $a (@{$first->{values}}) {
        my $c = "$cmping\[$i\]";
        my $b = $second->get($i++);
        if ( ref( $a )) {
            $this->checkSameAs($a, $b, $c, $checked, $where );
        } else {
            if($c =~ /\.text$/) {
                $this->assert_matches(qr/^$a\s*$/, $b, "$c ($a!=$b) $where");
            } else {
                $this->assert_str_equals($a, $b, "$c ($a!=$b) $where");
            }
        }
    }
}

sub checkSameAsFileTime {
    my ( $this, $first, $second, $cmping, $checked, $where ) = @_;
    $this->assert_str_equals($first->{file}, $second->{file},$cmping.$where);
}

1;
