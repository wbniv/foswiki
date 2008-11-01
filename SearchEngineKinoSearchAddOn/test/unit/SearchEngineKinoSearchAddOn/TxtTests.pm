# Test for Text.pm
package TxtTests;
use base qw( TWikiFnTestCase );

use strict;

use TWiki::Contrib::SearchEngineKinoSearchAddOn::StringifyBase;
use TWiki::Contrib::SearchEngineKinoSearchAddOn::Stringifier;

sub set_up {
        my $this = shift;

    $this->SUPER::set_up();
    # Use RcsLite so we can manually gen topic revs
    $TWiki::cfg{StoreImpl} = 'RcsLite';

    $this->{attachmentDir} = 'attachement_examples/';
    if (! -e $this->{attachmentDir}) {
        #running from twiki/test/unit
        $this->{attachmentDir} = 'SearchEngineKinoSearchAddOn/attachement_examples/';
    }

    $this->registerUser("TestUser", "User", "TestUser", 'testuser@an-address.net');

    $this->{twiki}->{store}->saveTopic($this->{twiki}->{user},$this->{users_web}, "TopicWithTxtAttachment", <<'HERE');
Just an example topic with TXT
Keyword: ASCII
HERE
    $this->{twiki}->{store}->saveAttachment($this->{users_web}, "TopicWithTxtAttachment", "Simple_example.txt",
                                            $this->{twiki}->{user}, {file => $this->{attachmentDir}."Simple_example.txt"})
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
}

sub test_stringForFile {
    my $this = shift;
    my $stringifier = TWiki::Contrib::SearchEngineKinoSearchAddOn::StringifyPlugins::Text->new();

    my $text  = $stringifier->stringForFile($this->{attachmentDir}.'Simple_example.txt');
    my $text2 = TWiki::Contrib::SearchEngineKinoSearchAddOn::Stringifier->stringFor($this->{attachmentDir}.'Simple_example.txt');

    $this->assert(defined($text), "No text returned.");
    
    $this->assert_str_equals($text, $text2, "TXT stringifier not well registered.");

    my $ok = $text =~ /woodstock/;
    $this->assert($ok, "Text woodstock not included")
}

1;
