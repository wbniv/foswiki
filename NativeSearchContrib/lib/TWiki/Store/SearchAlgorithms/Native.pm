#
# Copyright (C) 2007 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.
#
package TWiki::Store::SearchAlgorithms::Native;

use Assert;
use NativeTWikiSearch;

=pod

---+ package TWiki::Store::SearchAlgorithms::Native

Native implementation of the RCS cache search. Requires tools/native_search
to be built and installed.

---++ search($searchString, $topics, $options, $sDir) -> \%seen
Search .txt files in $dir for $string. See RcsFile::searchInWebContent
for details.

Rude and crude, this makes no attempt to handle UTF-8.

=cut

sub search {
    my ($searchString, $topics, $options, $sDir) = @_;

    $searchString ||= '';
    if (!$options->{type} || $options->{type} ne 'regex') {
        # Escape non-word chars in search string for plain text search
        $searchString =~ s/(\W)/\\$1/g;
    }
    $searchString =~ s/^(.*)$/\\b$1\\b/go if $options->{'wordboundaries'};
    my @fs;
    push(@fs, '-i') unless $options->{casesensitive};
    push(@fs, '-l') if $options->{files_without_match};
    push(@fs, $searchString);
    push(@fs, map { "$sDir/$_.txt" } @$topics);
    my $matches = NativeTWikiSearch::cgrep(\@fs);
    my %seen;
    if (defined($matches)) {
        for (@$matches) {
            # Note use of / and \ as dir separators, to support
            # Winblows
            if (/([^\/\\]*)\.txt(:(.*))?$/) {
                push( @{$seen{$1}}, $3 );
            }
        }
    }
    return \%seen;
}

1;
