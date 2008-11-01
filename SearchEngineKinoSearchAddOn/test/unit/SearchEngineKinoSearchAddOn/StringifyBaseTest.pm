# Test for StringifyBase.pm
package StringifyBaseTest;
use base qw( TWikiFnTestCase );

use strict;
use File::Temp qw/tmpnam/;

use TWiki::Contrib::SearchEngineKinoSearchAddOn::StringifyBase;

sub set_up {
    my $this = shift;
    
    $this->{attachmentDir} = 'tree_example/';
    if (! -e $this->{attachmentDir}) {
        #running from twiki/test/unit
        $this->{attachmentDir} = 'SearchEngineKinoSearchAddOn/tree_example/';
    }

    $this->SUPER::set_up();
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
}

sub test_rmtree {
    my $this = shift;
    my $stringifier = TWiki::Contrib::SearchEngineKinoSearchAddOn::StringifyBase->new();

    # Lets create a test directory that I will delete afterwards.
    # Note: Here I use unix commands and don't care on windows compatibility.
    my $tmp_dir = tmpnam();

    my $cmd = "cp -R $this->{attachmentDir} $tmp_dir";
    `$cmd`;

    # Now lets try to remove that dir
    $stringifier->rmtree($tmp_dir);

    $this->assert(! (-f $tmp_dir), "Directory $tmp_dir not deleteted.");

    # Now try to delete just a file
    $cmd = "cp -R $this->{attachmentDir}\test_file.txt $tmp_dir";
    $stringifier->rmtree($tmp_dir);

    $this->assert(! (-f $tmp_dir), "File $tmp_dir not deleteted.");
}

sub test_handler_for {
    my $this = shift;
    my $stringifier = TWiki::Contrib::SearchEngineKinoSearchAddOn::StringifyBase->new();

    my $handler = $stringifier->handler_for("test.pdf", "dummy");
    $this->assert($handler->isa("TWiki::Contrib::SearchEngineKinoSearchAddOn::StringifyPlugins::PDF"), 
		  "Bad handler for test.pdf");

    # I check that capital letters in the file name don't confuse the stringifier
    $handler = $stringifier->handler_for("TEST.PDF", "dummy");
    $this->assert($handler->isa("TWiki::Contrib::SearchEngineKinoSearchAddOn::StringifyPlugins::PDF"), 
		  "Bad handler for TEST.PDF");
}

1;
