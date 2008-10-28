package TWiki::Func2;

use strict;
use Error qw( :try );
use Assert;
use TWiki::Plugins;


sub isAdmin {
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->{user}->isAdmin();
}

sub isInGroup {
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    my $group = shift;

    return $TWiki::Plugins::SESSION->{user}->isInList($group);
}

1;

# EOF

    




