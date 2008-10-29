# Run _all_ test suites in the current directory (core and plugins)
require 5.006;

package TWikiSuite;
use base 'Unit::TestSuite';

use strict;

# Assumes we are run from the "test/unit" directory

sub include_tests {
    my $this = shift;
    push(@INC, '.');
    my @list;
    opendir(DIR, ".") || die "Failed to open .";
    foreach my $i (sort readdir(DIR)) {
        next if $i =~ /^Empty/ || $i =~ /^\./;
        if ($i =~ /^Fn_[A-Z]+\.pm$/ || $i =~ /^.*Tests\.pm$/) {
            push(@list, $i);
        }
    }
    closedir(DIR);

    # Add standard extensions tests
    my $read_manifest = 0;
    my $home = $ENV{TWIKI_HOME};
    unless ($home) {
        require Cwd;
        $home = Cwd::abs_path('../..');
    }

    if (open(F, "$home/lib/MANIFEST")) {
        $read_manifest = 1;
    } else {
        # dunno which plugins we require
        $read_manifest = 0;
    }
    if ($read_manifest) {
        local $/ = "\n";
        while (<F>) {
            if (m#^!include (twikiplugins/\w+)/.*?/(\w+)$#) {
                my $d = "$home/$1/test/unit/$2";
                next unless (-e "$d/${2}Suite.pm");
                push(@INC, $d);
                push(@list, "${2}Suite.pm");
            }
        }
        close(F);
    }
    print STDERR "Running tests from ",join(', ', @list),"\n";
    return @list;
};

1;
