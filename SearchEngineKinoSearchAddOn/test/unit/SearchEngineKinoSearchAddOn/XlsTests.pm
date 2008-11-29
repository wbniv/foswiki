# Test for XLS.pm
package XlsTests;
use base qw( FoswikiFnTestCase );

use strict;

use TWiki::Contrib::SearchEngineKinoSearchAddOn::StringifyBase;
use TWiki::Contrib::SearchEngineKinoSearchAddOn::Stringifier;

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
    $this->{attachmentDir} = 'attachement_examples/';
    if (! -e $this->{attachmentDir}) {
        #running from twiki/test/unit
        $this->{attachmentDir} = 'SearchEngineKinoSearchAddOn/attachement_examples/';
    }

    # Use RcsLite so we can manually gen topic revs
    #$TWiki::cfg{StoreImpl} = 'RcsLite';

    #$this->registerUser("TestUser", "User", "TestUser", 'testuser@an-address.net');
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
}

sub test_stringForFile {
    my $this = shift;
    my $stringifier = TWiki::Contrib::SearchEngineKinoSearchAddOn::StringifyPlugins::XLS->new();

    my $text  = $stringifier->stringForFile($this->{attachmentDir}.'Simple_example.xls');
    my $text2 = TWiki::Contrib::SearchEngineKinoSearchAddOn::Stringifier->stringFor($this->{attachmentDir}.'Simple_example.xls');

    $this->assert(defined($text), "No text returned.");
    $this->assert_str_equals($text, $text2, "DOC stringifier not well registered.");

    my $ok = $text =~ /dummy/;
    $this->assert($ok, "Text dummy not included")
}

sub test_SpecialCharacters {
    # I check, that speciual characzers are not destroied by the stringifier.

    my $this = shift;
    my $stringifier = TWiki::Contrib::SearchEngineKinoSearchAddOn::StringifyPlugins::XLS->new();

    my $text  = $stringifier->stringForFile($this->{attachmentDir}.'Simple_example.xls');
    
    $this->assert($text =~ m\Größer\, "Text Größer not found.");
		  
    $text  = $stringifier->stringForFile($this->{attachmentDir}.'Portuguese_example.xls');

    # print "Text = $text\n";
    $this->assert($text =~ m\Formatação\, "Text Formatação not found.");		  
    $this->assert(!($text =~ m\GENERAL\), "Bad string GENERAL appeares.");
}

sub test_Numbers {
    # I check, that numbers are found

    my $this = shift;
    my $stringifier = TWiki::Contrib::SearchEngineKinoSearchAddOn::StringifyPlugins::XLS->new();

    my $text  = $stringifier->stringForFile($this->{attachmentDir}.'Simple_example.xls');

    #print "Test = $text\n";

    $this->assert($text =~ m\200\,  "Number 200 not found.");
    $this->assert($text =~ m\0.23\, "Number 0,23 not found.");
    $this->assert($text =~ m\4711\, "Number 4711 not found.");
    $this->assert($text =~ m\312\,  "Number 312 Euro not found.");
}

sub test_calculatedNumbers {
    # I check, that calculated numbers are found

    my $this = shift;
    my $stringifier = TWiki::Contrib::SearchEngineKinoSearchAddOn::StringifyPlugins::XLS->new();

    my $text  = $stringifier->stringForFile($this->{attachmentDir}.'Simple_example.xls');

    $this->assert(($text =~ m\217\)==1,  "Number 200 + 17 not found.");
    $this->assert(($text =~ m\5\)==1, "Number 5 not found.");
}

1;
