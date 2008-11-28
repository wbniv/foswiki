#! perl -w
#
# Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2005-2007 Foswiki Contributors.
# All Rights Reserved. Foswiki Contributors are listed in
# the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# For licensing info read license.txt file in the TWiki root.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at 
# http://www.gnu.org/copyleft/gpl.html
#
# HELP
print <<'END';
Change the "shebang" lines of all perl scripts found in the current
directory.

"shebang" lines tell the shell what interpreter to use for running
scripts. By default the TWiki bin scripts are set to user the
"/usr/bin/perl" interpreter, which is where perl lives on most
UNIX-like platforms. On some platforms you will need to change this line
to run a different interpreter e.g. "D:\indigoperl\bin\perl"
or "/usr/bin/speedy"

This script will change the "shebang" lines of all scripts found in
the directory where the script is run from.

Note: the path to the interpreter *must not* contain any spaces.
END

use strict;

my $new = 'perl';
$/ = "\n";

while (1) {
    print "Enter path to interpreter [hit enter to choose '$new']: ";
    my $n = <>;
    chomp $n;
    last if( !$n );
    $new = $n;
};

unless( -x $new ) {
    print "Warning: I could not find an executable at $new
Are you sure you want to use this path (y/n)? ";
    my $n = <>;
    die "Aborted" unless $n =~ /^y/i;
}

my $changed = 0;
my $scanned = 0;
opendir(D, ".") || die $!;
foreach my $file (grep { -f && /^\w+$/ } readdir D) {
    $scanned++;
    $/ = undef;
    open(F, "<$file") || die $!;
    my $contents = <F>;
    close F;

    if( $contents =~ s/^#!\s*\S+/#!$new/s ) {
        open(F, ">$file") || die $!;
        print F $contents;
        close F;
        print "$file modified\n";
        $changed++;
    } else {
        print "$file modified\n";
    }
}
closedir(D);
print "$changed of $scanned files changed\n";
