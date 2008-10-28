#
# Copyright (C) 2007 Crawford Currie, http://c-dot.co.uk
#
package TWiki::Configure::Checkers::DBCacheContrib::Archivist;

use strict;

use TWiki::Configure::Checker;

use base 'TWiki::Configure::Checker';

sub check {
    my $this = shift;

    my $mess = '';
    eval "use $TWiki::cfg{DBCacheContrib}{Archivist}";
    if ($@) {
        $mess = $this->ERROR(
            "Could not load $TWiki::cfg{DBCacheContrib}{Archivist}: $@");
    }

    return $mess;
};

1;
