# See bottom of file for description
package Unit::TestCase;

use strict;
use Error qw( :try );
use Carp;
use Unit::HTMLDiffer;

$Carp::Verbose = 1;

use vars qw( $differ );

sub new {
    my $class = shift;
    my $this = bless({}, $class);
    @{$this->{annotations}} = ();
    return $this;
}

sub set_up {
    my $this = shift;
    @{$this->{annotations}} = ();
}

sub tear_down {
}

sub _fixture_test {
    my ($this, $set_up, $test) = @_;
    $this->$set_up();
    $this->$test();
}

=pod

Implement this to return an array of arrays, each of which is a list
of the names of fixture setup functions. For example, ( [ A, B ], [ C, D] ).

This will generate a call for each of the functions whose names start
with verify_ in the test package, with a call to each of the setup
functions. For example, say we have a test function called verify_this.
Then the test functions generated will be:
   verify_this_A_C
   verify_this_A_D
   verify_this_B_C
   verify_this_B_D

The setup functions are called in order; for example, verify_this_A_C is
implemented as:
   $this->A();
   $this->C();
   $this->verify_this();

=cut

sub fixture_groups {
    return ();
}

sub list_tests {
    my ($this, $suite) = @_;
    die "No suite" unless $suite;
    my @tests;
    my @verifies;
    my $clz = new Devel::Symdump($suite);
    for my $i ($clz->functions()) {
        if ($i =~ /^$suite\:\:test/) {
            push(@tests, $i);
        } elsif ($i =~ /^$suite\:\:(verify.*$)/) {
            push(@verifies, $1);
        }
    }
    my $fg = $this->fixture_groups();

    # Generate a verify method for each combination of the different
    # fixture methods
    my @setups = ();
    push(@tests, _gen_verification_functions(
        \@setups, $suite, \@verifies,
        $this->fixture_groups()));
    return @tests;
}

sub _gen_verification_functions {
    my $setups = shift;
    my $suite = shift;
    my $verifies = shift;
    my $group = shift;
    my @tests;
    foreach my $setup_function (@$group) {
        push(@$setups, $setup_function);
        if (scalar(@_)) {
            push (@tests, _gen_verification_functions(
                $setups, $suite, $verifies, @_));
        } else {
            foreach my $verify (@$verifies) {
                my $fn = $suite.'::'.$verify.'_'.join('_', @$setups);
                my $sup = join(';', map { '$this->'.$_.'()' } @$setups);
                my $code = <<SUB;
*$fn = sub {
    my \$this = shift;
    $sup;
    \$this->$verify();
}
SUB
                eval $code;
                die $@ if $@;
                push(@tests, $fn);
            }
        }
        pop(@$setups);
    }
    return @tests;
}

sub assert {
    my ($this, $bool, $mess) = @_;
    return 1 if $bool;
    $mess ||= "Assertion failed";
    $mess = join("\n", @{$this->{annotations}})."\n".$mess;
    $mess = Carp::longmess($mess);
    die $mess;
}

sub assert_equals {
    my ($this, $expected, $got, $mess) = @_;
    if (defined($got) && defined($expected)) {
        $this->assert($expected eq $got,
                      $mess || "Expected:'$expected'\n But got:'$got'\n");
    } elsif (!defined($got)) {
        $this->assert_null($expected);
    } else {
        $this->assert_null($got);
    }
}

sub assert_not_null {
    my ($this, $wot, $mess) = @_;
    $this->assert(defined($wot), $mess);
}

sub assert_null {
    my ($this, $wot, $mess) = @_;
    $this->assert(!defined($wot), $mess);
}

sub assert_str_equals {
    my ($this, $expected, $got, $mess) = @_;
    $this->assert_not_null($expected);
    $this->assert_not_null($got);
    $this->assert($expected eq $got, $mess || "Expected:'$expected'\n But got:'$got'\n");
}

sub assert_str_not_equals {
    my ($this, $expected, $got, $mess) = @_;
    $this->assert_not_null($expected);
    $this->assert_not_null($got);
    $this->assert($expected ne $got, $mess || "Expected:'$expected'\n And got:'$got'\n");
}

sub assert_num_equals {
    my ($this, $expected, $got, $mess) = @_;
    $this->assert_not_null($expected);
    $this->assert_not_null($got);
    $this->assert($expected == $got, $mess || "Expected:'$expected'\n But got:'$got'\n");
}

sub assert_matches {
    my ($this, $expected, $got, $mess) = @_;
    $this->assert_not_null($expected);
    $this->assert_not_null($got);
    $this->assert($got =~ /$expected/, $mess || "Expected:'$expected'\n But got:'$got'\n");
}

sub assert_does_not_match {
    my ($this, $expected, $got, $mess) = @_;
    $this->assert_not_null($expected);
    $this->assert_not_null($got);
    $this->assert($got !~ /$expected/, $mess || "Expected:'$expected'\n And got:'$got'\n");
}

sub assert_deep_equals {
    my ($this, $expected, $got, $mess, $sniffed) = @_;

    $sniffed = {} unless $sniffed;

    if (ref($expected)) {
        # Cycle eliminator.
        if (defined($sniffed->{$expected})) {
            $this->assert_equals($sniffed->{$expected}, $got);
            return;
        }

        $sniffed->{$expected} = $got;
    }

    if (UNIVERSAL::isa($expected, 'ARRAY')) {
        $this->assert(UNIVERSAL::isa($got, 'ARRAY'));
        for ( 0..$#$expected ) {
            $this->assert_deep_equals($expected->[$_], $got->[$_],
                                      $mess, $sniffed);
        }
    }
    elsif (UNIVERSAL::isa($expected, 'HASH')) {
        $this->assert(UNIVERSAL::isa($got, 'HASH'));
        my %matched;
        for ( keys %$expected ) {
            $this->assert_deep_equals($expected->{$_}, $got->{$_},
                                      $mess, $sniffed);
            $matched{$_} = 1;
        }
        for (keys %$got) {
            $this->assert($matched{$_});
        }
    }
    elsif (UNIVERSAL::isa($expected, 'REF') ||
        UNIVERSAL::isa($expected, 'SCALAR')) {
        $this->assert_equals(ref($expected), ref($got), $mess);
        $this->assert_deep_equals($$expected, $$got, $mess, $sniffed);
    }
    else {
        $this->assert_equals($expected, $got, $mess);
    }
}

sub annotate {
    my ($this, $mess) = @_;
    push(@{$this->{annotations}}, $mess) if defined($mess);
}

# 1:1 HTML comparison. Correctly compares attributes in tags. Uses HTML::Parser
# which is tolerant of unbalanced tags, so the actual may have unbalanced
# tags which will _not_ be detected.
sub assert_html_equals {
    my( $this, $e, $a, $mess ) = @_;

    my ($package, $filename, $line) = caller(0);
    my $opts =
      {
       options => 'rex',
       reporter =>
       \&Unit::HTMLDiffer::defaultReporter,
       result => ''
      };

    $mess ||= "$a\ndoes not equal\n$e";
    $this->assert($e, "$filename:$line\n$mess");
    $this->assert($a, "$filename:$line\n$mess");
    $differ ||= new Unit::HTMLDiffer();
    if( $differ->diff($e, $a, $opts)) {
        $this->assert(0, "$filename:$line\n$mess\n$opts->{result}");
    }
}

# See if a block of HTML occurs in a larger
# block of HTML. Both blocks must be well-formed HTML.
sub assert_html_matches {
    my ($this, $e, $a, $mess ) = @_;

    $differ ||= new Unit::HTMLDiffer();

    $mess ||= "$a\ndoes not match\n$e";
    my ($package, $filename, $line) = caller(0);
    unless( $differ->html_matches($e, $a)) {
        $this->assert(0, "$filename:$line\n$mess");
    }
}

# invoke a subroutine while grabbing stdout, so the "http
# response" doesn't flood the console that you're running the
# unit test from.
# $this->capture(\&proc, ...) -> $stdout
# ... params get passed on to &proc
sub capture {
    my $this = shift;
    my $proc = shift;
    
    require File::Temp;
    my $tmpdir = File::Temp::tempdir(CLEANUP => 1);

    my $text = undef;
    my $response = undef;
    my @params = @_;
    my $result;
    my ( $release ) = $Foswiki::RELEASE =~ /-(\d+)\.\d+\.\d+/;

    {
        local *STDOUT;
        open(STDOUT, ">$tmpdir/data");

        $result = &$proc( @params );
    }
    
    if ( $release >= 5 ) {
        $response =
          UNIVERSAL::isa( $params[0], 'Foswiki' )
          ? $params[0]->{response}
          : $Foswiki::Plugins::SESSION->{response};

        # Capture headers
        Foswiki::Engine->finalizeCookies($response);
        foreach my $header ( keys %{ $response->headers } ) {
            $text .= $header . ': ' . $_ . "\x0D\x0A"
              foreach $response->getHeader($header);
        }
        $text .= "\x0D\x0A";

        # Capture body
        $text .= $response->body() if $response->body();
    }
    else {
        open( FH, "$tmpdir/data" );
        local $/ = undef;
        $text = <FH>;
        close(FH);
    }

    return ( $text, $result );
}

1;

__DATA__

=pod

Base class for unit testcases
Author: Crawford Currie, http://c-dot.co.uk


Copyright (C) 2007 WikiRing, http://wikiring.com
All Rights Reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

=cut
