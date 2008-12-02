# See bottom of file for notices

=pod

---+ package Foswiki::Plugins::SafeWikiPlugin::Node

A tree node in an HTML parse tree

=cut

package Foswiki::Plugins::SafeWikiPlugin::Node;

use strict;
use Assert;

sub new {
    my( $class, $tag, $attrs ) = @_;

    my $this = {};

    $this->{tag} = lc($tag);
    $this->{attrs} = {};
    if( $attrs ) {
        while (my ($k, $v) = each %$attrs) {
            $this->{attrs}->{$k} = $v;
        }
    }
    $this->{children} = [];

    return bless( $this, $class );
}

# debug generate the parse tree as HTML
sub stringify {
    my( $this, $shallow ) = @_;
    my $r = '';
    if( $this->{tag} ) {
        $r .= '<'.$this->{tag};
        foreach my $attr ( keys %{$this->{attrs}} ) {
            if ($attr =~ /^\w+$/) {
                $r .= " ".$attr."='".$this->{attrs}->{$attr}."'";
            }
        }
        $r .= '>';
    }
    if( $shallow ) {
        $r .= '...';
    } else {
        foreach my $kid ( @{$this->{children}} ) {
            $r .= $kid->stringify();
        }
    }
    if( $this->{tag} ) {
        $r .= '</'.lc($this->{tag}).'>';
    }
    return $r;
}

sub isLeaf {
    return 0;
}

# Called by the parser
sub addChild {
    my( $this, $node ) = @_;
    push( @{$this->{children}}, $node );
}

# generate the parse tree, applying filters
sub generate {
    my ($this, $filterURI, $filterHandler) = @_;
    my $tag = $this->{tag};

    # make the names of the function versions
    my $f = '_'.uc( $tag );
    $f =~ s/[^\w]//; # clean up !DOCTYPE etc

    # See if we have a tag-specific function for this tag type
    if ($this->can($f)) {
        # if the fn returns false, filter the entire tag and all children
        return '' unless $this->$f($filterURI);
    }

    # Unconditionally filter the handlers from all tags
    $this->filterHandlers($filterHandler);

    # Process children
    my $text = '';
    foreach my $kid ( @{$this->{children}} ) {
        $text .= $kid->generate($filterURI, $filterHandler);
    }

    # Rebuild the tag parameters
    my @params;
    while (my ($k, $v) = each %{$this->{attrs}} ) {
        next unless $k && $k =~ /^\w+$/;
        my $q = $v =~ m/"/ ? "'" : '"';
        push( @params, $k.'='.$q.$v.$q );
    }
    my $p = join( ' ', @params );
    $p = ' '.$p if $p;

    # Rebuild the tag
    return "<$tag$p>$text</$tag>";
}

# remove the event handlers named in the parameters from the tag
sub filterHandlers {
    my ($this, $filter) = @_;

    foreach my $attr (keys %{$this->{attrs}}) {
        next unless $attr =~ /^on[a-z]+$/i;
        $this->{attrs}->{$attr} = &$filter($this->{attrs}->{$attr});
        ASSERT(defined $this->{attrs}->{$attr});
    }
}

sub filterURIs {
    my $this = shift;
    my $filter = shift;

    foreach my $attr (@_) {
        if (defined($this->{attrs}->{$attr})) {
            $this->{attrs}->{$attr} = &$filter($this->{attrs}->{$attr});
            ASSERT(defined $this->{attrs}->{$attr});
        }
    }
    return 1;
}

# The following functions are each called when the tag with the same name
# is being generated. If the function returns 0, the tag is completely
# removed. For the most part these functions just filter the URI-valued
# attributes of the tags.

sub _A {
    my ($this, $filter) = @_;
    $this->filterURIs($filter, 'href')
      if $Foswiki::cfg{Plugins}{SafeWikiPlugin}{FilterAll};
    return 1;
}

sub _APPLET {
    my ($this, $filter) = @_;
    $this->filterURIs($filter, 'archive', 'code', 'codebase');
    return 1;
}

sub _AREA {
    my ($this, $filter) = @_;
    $this->filterURIs($filter, 'href')
      if $Foswiki::cfg{Plugins}{SafeWikiPlugin}{FilterAll};
    return 1;
}

sub _BASE {
    my ($this, $filter) = @_;
    $this->filterURIs($filter, 'href')
      if $Foswiki::cfg{Plugins}{SafeWikiPlugin}{FilterAll};
    return 1;
}

sub _BLOCKQUOTE {
    my ($this, $filter) = @_;
    $this->filterURIs($filter, 'cite')
      if $Foswiki::cfg{Plugins}{SafeWikiPlugin}{FilterAll};
    return 1;
}

sub _BODY {
    my ($this, $filter) = @_;
    $this->filterURIs($filter, 'background')
      if $Foswiki::cfg{Plugins}{SafeWikiPlugin}{FilterAll};
    return 1;
}

sub _DEL {
    my ($this, $filter) = @_;
    $this->filterURIs($filter, 'cite')
      if $Foswiki::cfg{Plugins}{SafeWikiPlugin}{FilterAll};
    return 1;
}

sub _EMBED {
    my ($this, $filter) = @_;
    $this->filterURIs($filter, 'pluginspace', 'pluginurl', 'src');
    $this->filterURIs($filter, 'href', 'target', 'src')
      if $Foswiki::cfg{Plugins}{SafeWikiPlugin}{FilterAll};
    return 1;
}

sub _FORM {
    my ($this, $filter) = @_;
    $this->filterURIs($filter, 'action')
      if $Foswiki::cfg{Plugins}{SafeWikiPlugin}{FilterAll};
    return 1;
}

sub _FRAME {
    my ($this, $filter) = @_;
    $this->filterURIs($filter, 'src', 'longdesc')
      if $Foswiki::cfg{Plugins}{SafeWikiPlugin}{FilterAll};
    return 1;
}

sub _IFRAME {
    my ($this, $filter) = @_;
    $this->filterURIs($filter, 'src', 'longdesc')
      if $Foswiki::cfg{Plugins}{SafeWikiPlugin}{FilterAll};
    return 1;
}

sub _IMG {
    my ($this, $filter) = @_;
    $this->filterURIs($filter, 'src', 'longdesc', 'usemap')
      if $Foswiki::cfg{Plugins}{SafeWikiPlugin}{FilterAll};
    return 1;
}

sub _INPUT {
    my ($this, $filter) = @_;
    $this->filterURIs($filter, 'src', 'usemap')
      if $Foswiki::cfg{Plugins}{SafeWikiPlugin}{FilterAll};
    return 1;
}

sub _LINK {
    my ($this, $filter) = @_;
    $this->filterURIs($filter, 'href')
      if $Foswiki::cfg{Plugins}{SafeWikiPlugin}{FilterAll};
    return 1;
}

sub _OBJECT {
    my ($this, $filter) = @_;
    $this->filterURIs($filter, 'archive', 'codebase');
    $this->filterURIs($filter, 'data', 'usemap')
      if $Foswiki::cfg{Plugins}{SafeWikiPlugin}{FilterAll};
    return 1;
}

sub _SCRIPT {
    my ($this, $filter) = @_;
    return 0 unless (defined($this->{attrs}->{src}));
    $this->filterURIs($filter, 'src');
    return 1;
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
