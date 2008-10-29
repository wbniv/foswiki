use strict;

# Authors: Crawford Currie http://wikiring.com
#
# Make sure that all the right plugin handlers are called in the
# right places with the right parameters.
#
# Here are the handlers we need to test, and the current status:
#
# | *Handler*                    | *Tested by* |
# | afterAttachmentSaveHandler   | *untested* |
# | afterCommonTagsHandler       | test_commonTagsH# | afterEditHandler             | *untested* |
# | afterRenameHandler           | *untested* |
# | afterSaveHandler             | *untested* |
# | beforeAttachmentSaveHandler  | *untested* |
# | beforeCommonTagsHandler      | test_commonTagsHandlers |
# | beforeEditHandler            | *untested* |
# | beforeSaveHandler            | *untested* |
# | commonTagsHandler            | test_commonTagsHandlers |
# | earlyInitPlugin              | test_earlyInit |
# | endRenderingHandler          | test_renderingHandlers |
# | initPlugin                   | all tests |
# | initializeUserHandler        | test_earlyInit |
# | insidePREHandler             | test_renderingHandlers |
# | modifyHeaderHandler          | *untested* |
# | mergeHandler                 | *untested* |
# | outsidePREHandler            | test_renderingHandlers |
# | postRenderingHandler         | test_renderingHandlers |
# | preRenderingHandler          | test_renderingHandlers |
# | redirectrequestHandler      | *untested* |
# | registrationHandler          | *untested* |
# | renderFormFieldForEditHandler| *untested* |
# | renderWikiWordHandler        | *untested* |
# | startRenderingHandler        | test_renderingHandlers |
# | writeHeaderHandler           | *untested* |
#
# We do this by actually writing a valid plugin implementation to the
# plugins area in the code, and removing it again when we are done. Each
# bespoke plugin has specialised handlers designed to interact with this
# test.
#
# The handlers that are not currently tested are represented in the code
# below using a function called "detest_<handlername>". If you are going
# to write a test for the handler, rename it to "test_<handlername>" and
# start coding....
#
package PluginHandlerTests;
use base qw(TWikiFnTestCase);

use strict;
use TWiki;
use Error qw( :try );
use TWiki::Plugin;
use Symbol qw(delete_package);

my $systemWeb = "TemporaryPluginHandlersSystemWeb";

sub new {
    my $self = shift()->SUPER::new("PluginHandlers", @_);
    return $self;
}

# Set up the test fixture.
sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
    # Disable all plugins
    foreach my $key (keys %{$TWiki::cfg{Plugins}}) {
        $TWiki::cfg{Plugins}{$key}{Enabled} = 0;
    }
    # Locate the code
    my $found;
    foreach my $inc (@INC) {
        if (-e "$inc/TWiki/Plugins/EmptyPlugin.pm") {
            # Found it
            $found = $inc;
            last;
        }
    }
    die "Can't find code" unless $found;
    $this->{code_root} = "$found/TWiki/Plugins/";
    $this->{twiki}->{store}->createWeb($this->{twiki}->{user},
                                       $systemWeb,
                                       $TWiki::cfg{SystemWebName});
    $TWiki::cfg{SystemWebName} = $systemWeb;
}

sub tear_down {
    my $this = shift;

    $this->removeWebFixture($this->{twiki}, $systemWeb);
    unlink($this->{plugin_pm});
    Symbol::delete_package("TWiki::Plugins::$this->{plugin_name}");
    $this->SUPER::tear_down();
}

# Build the plugin source, using the code passed in $code as the
# body of the plugin. $code will normally be at least one handler
# implementation, sometimes more than one.
sub makePlugin {
    my ($this, $test, $code) = @_;

    $this->{plugin_name} = ucfirst("${test}Plugin");
    $this->{plugin_pm} = $this->{code_root}.$this->{plugin_name}.".pm";

    $code = <<HERE;
package TWiki::Plugins::$this->{plugin_name};

use vars qw( \$called \$tester \$VERSION );
\$called = {};
\$VERSION = 999.911;

sub initPlugin {
    \$called->{initPlugin}++;
    return 1;
}
# line 11
$code
1;
HERE
    open(F, ">$this->{plugin_pm}") ||
      die "Failed to open $this->{plugin_pm}: $!";
    print F $code;
    close(F);
    try {
        $this->{twiki}->{store}->saveTopic(
            $this->{twiki}->{users}->findUserByWikiName($TWiki::cfg{AdminUserWikiName})->[0],
            $TWiki::cfg{SystemWebName},
            $this->{plugin_name}, <<'EOF');
   * Set PLUGINVAR = Blah
EOF
    } catch TWiki::AccessControlException with {
        $this->assert(0,shift->stringify());
    } catch Error::Simple with {
        $this->assert(0,shift->stringify());
    };
    $TWiki::cfg{Plugins}{$this->{plugin_name}}{Enabled} = 1;
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki(); # default user
    eval "\$TWiki::Plugins::$this->{plugin_name}::tester = \$this;";
    $this->checkCalls(1, 'initPlugin');
    $TWiki::Plugins::SESSION = $this->{twiki};
}

sub checkCalls {
    my ($this, $number, $name) = @_;
    my $saw = eval "\$TWiki::Plugins::$this->{plugin_name}::called->{$name} || 0";
    $this->assert_equals(
        $number, $saw, "calls($name) $saw != $number ".join(' ',caller));
}

sub test_commonTagsHandlers {
    my $this = shift;
    $this->makePlugin('beforeCommonTagsHandler', <<'HERE');
sub beforeCommonTagsHandler {
    #my( $text, $topic, $theWeb, $meta ) = @_;
    $tester->assert_str_equals('Zero', $_[0], "ONE $_[0]");
    $tester->assert_str_equals('Tropic', $_[1], "TWO $_[1]");
    $tester->assert_str_equals('Werb', $_[2], "THREE $_[2]");
    $tester->assert($_[3]->isa('TWiki::Meta'), "FOUR $_[3]");
    $tester->assert_str_equals('Wibble', $_[3]->get('WIBBLE')->{wibble});
    $_[0] = 'One';
    $called->{beforeCommonTagsHandler}++;
}
sub commonTagsHandler {
    #my( $text, $topic, $theWeb, $included, $meta ) = @_;
    $tester->assert_str_equals('One', $_[0]);
    $tester->assert_str_equals('Tropic', $_[1]);
    $tester->assert_str_equals('Werb', $_[2]);
    $tester->assert($_[4]->isa('TWiki::Meta'), "OUCH $_[4]");
    $tester->assert_str_equals('Wibble', $_[4]->get('WIBBLE')->{wibble});
    $_[0] = 'Two';
    $called->{commonTagsHandler}++;
}
sub afterCommonTagsHandler {
    #my( $text, $topic, $theWeb, $meta ) = @_;
    $tester->assert_str_equals('Two', $_[0]);
    $tester->assert_str_equals('Tropic', $_[1]);
    $tester->assert_str_equals('Werb', $_[2]);
    $tester->assert($_[3]->isa('TWiki::Meta'));
    $tester->assert_str_equals('Wibble', $_[3]->get('WIBBLE')->{wibble});
    $_[0] = 'Zero';
    $called->{afterCommonTagsHandler}++;
}
HERE
    # Crude test to ensure all handlers are called, and in the right order.
    # Doesn't verify that they are called at the right time
    my $meta = new TWiki::Meta($this->{twiki}, "Werb", "Tropic");
    $meta->put('WIBBLE', { wibble => 'Wibble' } );
    TWiki::Func::expandCommonVariables("Zero", "Tropic", "Werb", $meta);
    $this->checkCalls(1, 'beforeCommonTagsHandler');
    $this->checkCalls(1, 'commonTagsHandler');
    $this->checkCalls(1, 'afterCommonTagsHandler');
}

sub test_earlyInit {
    my $this = shift;
    $this->makePlugin('earlyInitPlugin', <<'HERE');
sub earlyInitPlugin {
    # $tester not set up yet
    die "EIP $called->{earlyInitPlugin}" if  $called->{earlyInitPlugin};
    die "IP $called->{initPlugin}" if $called->{initPlugin};
    die "IUH $called->{initializeUserHandler}" if $called->{initializeUserHandler};
    $called->{earlyInitPlugin}++;
}

sub initializeUserHandler {
    # $tester not set up yet
    die "$called->{earlyInitPlugin}" unless $called->{earlyInitPlugin};
    die "$called->{initPlugin}" unless !$called->{initPlugin};
    die "$called->{initializeUserHandler}" unless !$called->{initializeUserHandler};
    $called->{initializeUserHandler}++;
    my $ru = $_[0] || 'undef';
    die "RU $ru" unless $ru eq ($TWiki::Plugins::SESSION->{remoteUser}||'undef');
    my $url = $_[1] || 'undef';
    die "URL $url" unless $url eq (TWiki::Func::getCgiQuery()->url() || undef);
    my $path = $_[2] || 'undef';
    die "PATH $path" unless $path eq (TWiki::Func::getCgiQuery->path_info() || 'undef');
}
HERE
    $this->checkCalls(1, 'earlyInitPlugin');
    $this->checkCalls(1, 'initPlugin');
    $this->checkCalls(1, 'initializeUserHandler');
}

# Test that the rendering handlers are called in the correct sequence.
# The sequence is:
# 1 startRenderingHandler
# 2 preRenderingHandler
# -*- insidePreHandler and outsidePreHandler -*-
# 3 endRenderingHandler
# 4 postRenderingHandler
# Each handler checks its params and the state of the text, and prepends
# an id to the text to say its been called and make sure that text can be
# written.
use vars qw( @oprelines @iprelines );
sub test_renderingHandlers {
    my $this = shift;
    $this->makePlugin('renderingHandlers', <<'HERE');
# Called after verbatim, literal, head, textareas, script have
# all been removed, but *before* PRE is removed
sub startRenderingHandler {
    my ($text, $web, $topic ) = @_;
    $called->{startRenderingHandler}++;
    $tester->assert_str_equals("Gruntfos", $_[1]);
    $tester->assert_str_equals("WebHome", $_[2]);
    $text =~ s/\d+${TWiki::TranslationToken}--/NUMBERx--/g;
    $text =~ s/${TWiki::TranslationToken}/x/g;
    $tester->assert_str_equals(<<INNER, $text);
<!--xliteralNUMBERx-->
<!--xverbatimNUMBERx-->
<pre>
PRE
</pre>
<!--xheadNUMBERx-->
<!--xscriptNUMBERx-->
<!--xtextareaNUMBERx-->
<nop>
INNER
   $_[0] = "startRenderingHandler\n".$_[0];
}
# Called after all blocks have been removed
sub preRenderingHandler {
    my ($text, $removed ) = @_;
    $called->{preRenderingHandler}++;
    $text =~ s/\d+${TWiki::TranslationToken}--/NUMBERx--/g;
    $text =~ s/${TWiki::TranslationToken}/x/g;
    $tester->assert_str_equals(<<INNER, $text);
startRenderingHandler
<!--xliteralNUMBERx-->
<!--xverbatimNUMBERx-->
<!--xpreNUMBERx-->
<!--xheadNUMBERx-->
<!--xscriptNUMBERx-->
<!--xtextareaNUMBERx-->
<nop>
INNER
    # Check the removed blocks (which have unpredictable numbers, as the
    # keys are generated when they are added to the removed hash)
    foreach my $k ( keys %{$removed} ) {
        if ($k =~ /^literal/) {
            $tester->assert_str_equals("\nLITERAL\n", $removed->{$k}{'text'});
        } elsif ($k =~ /^verbatim/) {
            $tester->assert_str_equals("\nVERBATIM\n", $removed->{$k}{'text'});
        } elsif ($k =~ /^pre/) {
            $tester->assert_str_equals("\nPRE\n", $removed->{$k}{'text'});
        } elsif ($k =~ /^head/) {
            $tester->assert_str_equals("<head>\nHEAD\n</head>",
                 $removed->{$k}{'text'});
        } elsif ($k =~ /^script/) {
            $tester->assert_str_equals("<script>\nSCRIPT\n</script>",
                 $removed->{$k}{'text'});
        } elsif ($k =~ /^textarea/) {
            $tester->assert_str_equals("<textarea>\nTEXTAREA\n</textarea>",
                  $removed->{$k}{'text'});
        }
    }
    $_[0] = "preRenderingHandler\n$_[0]";
}

# Called after PRE blocks have been re-inserted, but *before* any other block
# types have been reinserted (so markers are still present)
sub endRenderingHandler {
    my ( $text ) = @_;
    $text =~ s/^\n//s;
    $text =~ s/\d+${TWiki::TranslationToken}--/NUMBERx--/g;
    $text =~ s/${TWiki::TranslationToken}/x/g;
    $tester->assert_str_equals(<<INNER, $text);
preRenderingHandler
startRenderingHandler
<!--xliteralNUMBERx-->
<!--xverbatimNUMBERx-->
<pre>
PRE
</pre>
<!--xheadNUMBERx-->
<!--xscriptNUMBERx-->
<!--xtextareaNUMBERx-->
<nop>
INNER
    $called->{endRenderingHandler}++;
    $_[0] = "endRenderingHandler\n$_[0]";
}

# Called after all blocks have been re-inserted
sub postRenderingHandler {
    my ($text) = @_;
    $tester->assert_str_equals(<<INNER, "$text\n");
endRenderingHandler
preRenderingHandler
startRenderingHandler

LITERAL

<pre>
VERBATIM
</pre>
<pre>
PRE
</pre>
<head>
HEAD
</head>
<script>
SCRIPT
</script>
<textarea>
TEXTAREA
</textarea>
INNER
    $called->{postRenderingHandler}++;
    $_[0] = "postRenderingHandler\n$_[0]";
}

# Should only be called on one line
sub insidePREHandler {
    my( $text ) = @_;
    $text =~ s/\d+${TWiki::TranslationToken}--/NUMBERx--/g;
    $text =~ s/${TWiki::TranslationToken}/x/g;
    push(@PluginHandlerTests::iprelines, $text);
    $called->{insidePREHandler}++;
}

# Should be called on every line that the inside handler is *not*
# called on
sub outsidePREHandler {
    my( $text ) = @_;
    $text =~ s/\d+${TWiki::TranslationToken}--/NUMBERx--/g;
    $text =~ s/${TWiki::TranslationToken}/x/g;
    push(@PluginHandlerTests::oprelines, $text);
    $called->{outsidePREHandler}++;
}
HERE
    my $text = <<HERE;
<literal>
LITERAL
</literal>
<verbatim>
VERBATIM
</verbatim>
<pre>
PRE
</pre>
<head>
HEAD
</head>
<script>
SCRIPT
</script>
<textarea>
TEXTAREA
</textarea>
HERE
    @oprelines = ();
    @iprelines = ();
    my $out = TWiki::Func::renderText($text, "Gruntfos")."\n";
    $this->assert_str_equals(<<HERE, $out);
postRenderingHandler
endRenderingHandler
preRenderingHandler
startRenderingHandler

LITERAL

<pre>
VERBATIM
</pre>
<pre>
PRE
</pre>
<head>
HEAD
</head>
<script>
SCRIPT
</script>
<textarea>
TEXTAREA
</textarea>
HERE
    $this->assert_str_equals('', $iprelines[0]);
    $this->assert_str_equals('PRE', $iprelines[1]);
    $this->assert_str_equals('preRenderingHandler', $oprelines[0]);
    $this->assert_str_equals('startRenderingHandler', $oprelines[1]);
    $this->assert_str_equals('<!--xliteralNUMBERx-->', $oprelines[2]);
    $this->assert_str_equals('<!--xverbatimNUMBERx-->', $oprelines[3]);
    $this->assert_str_equals('<!--xpreNUMBERx-->', $oprelines[4]);
    $this->assert_str_equals('<!--xheadNUMBERx-->', $oprelines[5]);
    $this->assert_str_equals('<!--xscriptNUMBERx-->', $oprelines[6]);
    $this->assert_str_equals('<!--xtextareaNUMBERx-->', $oprelines[7]);
    $this->assert_str_equals('<nop>', $oprelines[8]);
    $this->checkCalls(1, 'preRenderingHandler');
    $this->checkCalls(1, 'startRenderingHandler');
    $this->checkCalls(1, 'endRenderingHandler');
    $this->checkCalls(1, 'postRenderingHandler');
}

sub test_afterAttachmentSaveHandler {
    my $this = shift;
    $this->makePlugin('afterAttachmentSaveHandler', <<'HERE');
sub afterAttachmentSaveHandler {
    my ($attachmentAttrHash, $topic, $web, $error) = @_;
    $called->{afterAttachmentSaveHandler}++;
}
HERE
}

sub test_afterEditHandler {
    my $this = shift;
    $this->makePlugin('afterEditHandler', <<'HERE');
sub afterEditHandler {
    my( $text, $topic, $web ) = @_;
    $called->{afterEditHandler}++;
}
HERE
}

sub test_afterRenameHandler {
    my $this = shift;
    $this->makePlugin('afterRenameHandler', <<'HERE');
sub afterRenameHandler {
    my ($oldWeb, $oldTopic, $oldAttachment, $newWeb,
        $newTopic, $newAttachment) = @_;
    $called->{afterRenameHandler}++;
}
HERE
}

sub test_afterSaveHandler {
    my $this = shift;
    $this->makePlugin('afterSaveHandler', <<'HERE');
sub afterSaveHandler {
    my ($theText, $theTopic, $theWeb, $error, $meta) = @_;
    $called->{afterSaveHandler}++;
}
HERE
}

sub test_beforeAttachmentSaveHandler {
    my $this = shift;
    $this->makePlugin('beforeAttachmentSaveHandler', <<'HERE');
sub beforeAttachmentSaveHandler {
    my( $attrHashRef, $topic, $web ) = @_;
    $called->{beforeAttachmentSaveHandler}++;
}
HERE
}

sub test_beforeEditHandler {
    my $this = shift;
    $this->makePlugin('beforeEditHandler', <<'HERE');
sub beforeEditHandler {
    my( $text, $topic, $web, $meta ) = @_;
    $called->{beforeEditHandler}++;
}
HERE
}

sub test_beforeSaveHandler {
    my $this = shift;
    $this->makePlugin('beforeSaveHandler', <<'HERE');
sub beforeSaveHandler {
    my ( $theText, $theTopic, $theWeb, $meta ) = @_;
    $called->{beforeSaveHandler}++;
}
HERE
}

sub test_modifyHeaderHandler {
    my $this = shift;
    $this->makePlugin('modifyHeaderHandler', <<'HERE');
sub modifyHeaderHandler {
    my ($headers, $query) = @_;
    $called->{modifyHeaderHandler}++;
}
HERE
}

sub test_mergeHandler {
    my $this = shift;
    $this->makePlugin('mergeHandler', <<'HERE');
sub mergeHandler {
    my ($diff, $old, $new, $info) = @_;
    $called->{mergeHandler}++;
}
HERE
}

sub test_redirectrequestHandler {
    my $this = shift;
    $this->makePlugin('redirectrequestHandler', <<'HERE');
sub redirectrequestHandler {
    my ( $query, $url ) = @_;
    $called->{redirectrequestHandler}++;
}
HERE
}

sub test_registrationHandler {
    my $this = shift;
    $this->makePlugin('registrationHandler', <<'HERE');
sub registrationHandler {
    my ( $web, $wikiName, $loginName ) = @_;
    $called->{registrationHandler}++;
}
HERE
}

sub test_renderFormFieldForEditHandler {
    my $this = shift;
    $this->makePlugin('renderFormFieldForEditHandler', <<'HERE');
sub renderFormFieldForEditHandler {
    my ($name, $type, $size, $value, $attributes, $possibleValues) = @_;
    $called->{renderFormFieldForEditHandler}++;
}
HERE
}

sub test_renderWikiWordHandler {
    my $this = shift;
    $this->makePlugin('renderWikiWordHandler', <<'HERE');
sub renderWikiWordHandler {
    my ($text) = @_;
    $called->{renderWikiWordHandler}++;
}
HERE
}

sub test_writeHeaderHandler {
    my $this = shift;
    $this->makePlugin('writeHeaderHandler', <<'HERE');
sub writeHeaderHandler {
    my ($query) = @_;
    $called->{writeHeaderHandler}++;
}
HERE
}

1;
