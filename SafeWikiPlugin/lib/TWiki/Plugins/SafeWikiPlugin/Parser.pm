# See bottom of file for notices

package TWiki::Plugins::SafeWikiPlugin::Parser;
use base 'HTML::Parser';

use strict;

require TWiki::Plugins::SafeWikiPlugin::Node;
require TWiki::Plugins::SafeWikiPlugin::Leaf;

sub new {
    my ($class) = @_;

    my $this = $class->SUPER::new(
        start_h => [\&_openTag, 'self,tagname,attr' ],
        end_h => [\&_closeTag, 'self,tagname'],
        declaration_h => [\&_ignore, 'self'],
        default_h => [\&_text, 'self,text'],
        comment_h => [\&_comment, 'self,text'] );
    $this->empty_element_tags(1);
    if ($TWiki::cfg{Plugins}{SafeWikiPlugin}{CheckPurity}) {
        $this->strict_end(1);
        $this->strict_names(1);
    }
    return $this;
}

sub parseHTML {
    my $this = $_[0];
    $this->_resetStack();
    $this->parse($_[1]);
    $this->eof();
    $this->_apply(undef);
    return $this->{stackTop};
}

sub stringify {
    my $this = shift;
    my $s;

    if ($this->{stackTop}) {
        $s = "0: ".$this->{stackTop}->stringify();
        my $n = 1;
        foreach my $entry (reverse @{$this->{stack}}) {
            $s .= "\n".($n++).': '.$entry->stringify();
        }
    } else {
        $s = 'empty stack';
    }
    return $s;
}

sub _resetStack {
    my $this = shift;

    $this->{stackTop} = undef;
    $this->{stack} = ();
}

# Support autoclose of the tags that are most typically incorrectly
# nested. Autoclose triggers when a second tag of the same type is
# seen without the first tag being closed.
my %autoclose = map { ($_, 1) } qw( li td th tr);

sub _openTag {
    my( $this, $tag, $attrs ) = @_;

    if ($autoclose{$tag} &&
          $this->{stackTop} && $this->{stackTop}->{tag} eq $tag) {
        $this->_apply( $tag );
    }

    push( @{$this->{stack}}, $this->{stackTop} ) if $this->{stackTop};
    $this->{stackTop} =
      new TWiki::Plugins::SafeWikiPlugin::Node($tag, $attrs);
}

sub _closeTag {
    my( $this, $tag ) = @_;

    if ($TWiki::cfg{Plugins}{SafeWikiPlugin}{CheckPurity}) {
        if (!$this->{stackTop} || $this->{stackTop}->{tag} ne $tag) {
            die "Unclosed <$this->{stackTop}->{tag} at </$tag\n".
              $this->stringify();
        }
    }
    $this->_apply( $tag );
}

sub _text {
    my( $this, $text ) = @_;
    return unless length($text);
    my $l = new TWiki::Plugins::SafeWikiPlugin::Leaf($text);
    if (defined $this->{stackTop}) {
        die "Unexpected leaf: ".$this->stringify()
          if $this->{stackTop}->isLeaf();
        $this->{stackTop}->addChild( $l );
    } else {
        $this->{stackTop} = $l;
    }
}

sub _comment {
    my( $this, $text ) = @_;
}

sub _ignore {
}

sub _apply {
    my( $this, $tag ) = @_;

    while( $this->{stack} && scalar( @{$this->{stack}} )) {
        my $top = $this->{stackTop};
        $this->{stackTop} = pop( @{$this->{stack}} );
        die 'Stack underflow: '.$this->stringify()
          unless $this->{stackTop};
        die 'Stack top is leaf: '.$this->stringify()
          if $this->{stackTop}->isLeaf();
        $this->{stackTop}->addChild( $top );
        last if( $tag && $top->{tag} eq $tag );
    }
}

1;
__DATA__

Copyright (C) 2007-2008 C-Dot Consultants http://c-dot.co.uk
All rights reserved
Author: Crawford Currie

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details, published at
http://www.gnu.org/copyleft/gpl.html

This notice must be retained in all copies or derivatives of this
code.
