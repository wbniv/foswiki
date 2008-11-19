# Copyright (C) 2005 ILOG http://www.ilog.fr
# and Foswiki Contributors. All Rights Reserved. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of the TWiki distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.

=pod

---+ package Foswiki::Plugins::WysiwygPlugin::TML2HTML::Leaf

Object for a leaf node in an HTML parse tree

A leaf node is text in the document.

See also Foswiki::Plugins::WysiwygPlugin::TML2HTML::Node

=cut

package Foswiki::Plugins::WysiwygPlugin::HTML2TML::Leaf;
use base 'Foswiki::Plugins::WysiwygPlugin::HTML2TML::Base';

use strict;

sub new {
    my( $class, $text ) = @_;

    my $this = {};

    $this->{tag} = '';
    $this->{nodeType} = 3;
    $this->{text} = $text;
    return bless( $this, $class );
}

# Entities that we want to decoded in plain text
# Do *not* add lt or gt, as you will turn > and < in plain text into HTML
# tags!
my %text_entities = (
    quot => 34, amp => 38,
   );
my $text_entities_re = join('|', keys %text_entities);

sub generate {
    my( $this, $options ) = @_;
    my $t = $this->{text};

    if (!($options & $WC::KEEP_WS)) {
        $t =~ s/\t/   /g;
        $t =~ s/\n/$WC::CHECKw/g;
        $t =~ s/  +/ /g;
    }
    if( $options & $WC::NOP_ALL ) {
        # escape all embedded wikiwords
        $t =~ s/$WC::STARTWW($Foswiki::regex{wikiWordRegex})/<nop>$1/go;
        $t =~ s/$WC::STARTWW($Foswiki::regex{abbrevRegex})/<nop>$1/go;
        $t =~ s/\[/<nop>[/g;
    }
    unless ($options & $WC::KEEP_ENTITIES) {
        $t =~ s/&($text_entities_re);/chr($text_entities{$1})/ego;
        $t =~ s/&nbsp;/$WC::NBSP/g;
    }
    return (0, $t);
}

sub stringify {
    my $this = shift;
    return $this->{text};
}

sub isInline {
    return 1;
}

1;
