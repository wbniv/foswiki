use strict;
use integer;

{ package Assert;
  
  sub assert {
    my ($line,$test,$mess) = @_;
    $mess = "" unless $mess;
    die "Assert at line $line failed: $mess" unless $test;
  }
  
  sub contains {
    my ($line,$test,$expected) = @_;

    my $ein = $expected;

    $expected =~ s/ /\\s+/go;
    $expected =~ s/[\n\r]+/\\s*/go;
    $expected =~ s/([.()\[\]])/\\$1/go;
    $expected =~ s/<nop>/!!!NO!!!/go;
    $expected =~ s/(<[^>]*>)/\\s*$1\\s*/go;
    $expected =~ s/!!!NO!!!/<nop>/go;
    $expected =~ s/(\\s\*)+/\\s*/go;
    $expected =~ s/(\\s[+])+/\\s+/go;

    $test =~ s/^\s*//o;
    $test =~ s/\s*$//o;
    return $test =~ /$expected/s;
  }

  sub sContains {
    my ($line,$test,$expected) = @_;
    assert($line, contains($line,$test,$expected),
	   "\nsaw      \"$test\"\nexpected \"$expected\"");
  }
  
  sub sEquals {
    my ($line,$test,$expected) = @_;
    if (!contains($line, $test, "^" . $expected . "\$")) {
      # find the first mismatched character
      my $i = 1;
      while ($i < length($test) && $i < length($expected)) {
	my $ts = substr($test, 0, $i);
	my $es = substr($expected, 0, $i);
	if ($ts ne $es) {
	  my $rest = substr($test, $i, length($test));
	  assert($line, 0,
		 "\nsaw      \"$ts*****$rest\"\nexpected \"$expected\"");
	}
	$i++;
      }
      assert($line, 0, "\nsaw      \"$test\"\nexpected \"$expected\"");
    }
    return 1;
  }

  sub equals {
    my ($line,$test,$expected) = @_;
    assert($line, $test == $expected, "saw $test expected $expected");
  }

  sub fileContains {
    my ($line, $fn, $expected) = @_;

    undef $/; # set to read to EOF
    assert($line, open(IN_FILE, "<$fn"), "open $fn");
    my $text = "";
    my $l;
    while ($l = <IN_FILE>) {
      $text = $text . $l;
    }
    close(IN_FILE);

    sContains($line, $text, $expected);
  }
}

1;
