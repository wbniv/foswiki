#
# Copyright (C) Motorola 2003 - All rights reserved
# Copyright (C) Crawford Currie 2004
#
package TWiki::Contrib::DBCacheContrib::Map;

use strict;

use TWiki::Contrib::DBCacheContrib::Array;
use Assert;

=begin text

---++ package TWiki::Contrib::DBCacheContrib::Map
Generic map object for mapping names to things. A name is defined as
  =name = \w+ | \w+ "." name=
The . indicates a field reference in a sub-map.
Objects in the map are either strings, or other objects that must
support toString.

=cut

=begin text

---+++ =new($string)=
   * $string - optional attribute string in standard TWiki syntax
Create a new, empty array object. Optionally parse a standard attribute
string containing name=value pairs. The
value may be a word or a quoted string (no escapes!)

=cut

sub new {
    my ( $class, $string ) = @_;
    my $this = bless( {}, $class );
    $this->{keys} = ();

    if ( defined( $string ) ) {
        my $orig = $string;
        my $n = 1;
        while ( $string !~ m/^[\s,]*$/o ) {
            if ( $string =~ s/^\s*(\w[\w\.]*)\s*=\s*\"(.*?)\"//o ) {
                $this->set( $1, $2 );
            } elsif ( $string =~ s/^\s*(\w[\w\.]*)\s*=\s*([^\s,\}]*)//o ) {
                $this->set( $1, $2 );
            } elsif ( $string =~ s/^\s*\"(.*?)\"//o ) {
                $this->set( "\$$n", $1 );
                $n++;
            } elsif ( $string =~ s/^\s*(\w[\w+\.]*)\b//o ) {
                $this->set( $1, "on" );
            } elsif ( $string =~ s/^[^\w\.\"]//o ) {
                # skip bad char or comma
            } else {
                # some other problem
                die "TWiki::Contrib::DBCacheContrib::Map: Badly formatted attribute string at '$string' in '$orig'";
            }
        }
    }
    return $this;
}

# PUBLIC dispose of this map, breaking any circular references
sub DESTROY {
    my $this = shift;
    #print STDERR "Destroy ",ref($this),"\n";
    $this->{keys} = undef;
    # should be enough; nothing else should be pointing to the keys
}

=begin text

---+++ =fastget($k)= -> datum
   * =$k= - key
Get the value for a key, but without any subfield field expansion

=cut

sub fastget {
    #my ( $this, $attr ) = @_;
    return $_[0]->{keys}{$_[1]};
}

=begin text

---+++ =get($k, $root)= -> datum
   * =$k= - key
   * =$root= what # refers to
Get the value corresponding to key =$k=; return undef if not set.

*Subfield syntax*
   * =get("X",$r)= will get the subfield named =X=.
   * =get("X.Y",$r)= will get the subfield =Y= of the subfield named =X=.
   * =get("[X]",$r) = will get the subfield named =X= (so X[Y] and X.Y are synonymous)..
   * =#= means "reset to root". So =get("#.Y", $r) will return the subfield =Y= of $r (assuming $r is a map!), as will =get("#[Y]"=.

Where the result of a subfield expansion is another object (a Map or an Array) then further subfield expansions can be used. For example,
<verbatim>
get("UserTable[0].Surname", $web);
</verbatim>

See also =TWiki::Contrib::DBCacheContrib::Array= for syntax that applies to arrays.

=cut

sub get {
    my ( $this, $key, $root ) = @_;

    # If empty string, then we are the required result
    return $this unless $key;

    if ( $key =~ m/^(\w+)(.*)$/o ) {
        # Sub-expression
        my $field = $this->{keys}{$1};
        return $field->get( $2, $root ) if ( $2 && ref( $field ));
        return $field;
    } elsif ( $key =~ m/^\.(.*)$/o ) {
        return $this->get( $1, $root );
    } elsif ( $key =~ m/^\[(.*)$/o ) {
        my ( $one, $two ) = TWiki::Contrib::DBCacheContrib::Array::mbrf( "[", "]", $1 );
        my $field = $this->get( $one, $root );
        return $field->get( $two, $root ) if ( $two  && ref( $field ));
        return $field;
    } elsif ( $key =~ m/^#(.*)$/o ) {
        return $root->get( $1, $root );
    } else {
        #print STDERR "ERROR: bad Map expression at $key\n";
        return undef; 
    }
}

=begin text

---+++ =set($k, $v)=
   * =$k= - key
   * =$v= - value
Set the given key, value pair in the map.

=cut

sub set {
    my ( $this, $attr, $val ) = @_;
    if ( $attr =~ m/^(\w+)\.(.*)$/o ) {
        $attr = $1;
        my $field = $2;
        if ( !defined( $this->{keys}{$attr} )) {
            $this->{keys}{$attr} = new TWiki::Contrib::DBCacheContrib::Map();
        }
        $this->{keys}{$attr}->set( $field, $val );
    } else {
        $this->{keys}{$attr} = $val;
    }
}

=begin text

---+++ =size()= -> integer
Get the size of the map

=cut

sub size {
    my $this = shift;

    return scalar( keys( %{$this->{keys}} ));
}

=begin text

---+++ =remove($index)= -> old value
   * =$index= - integer index
Remove an entry at an index from the array. Return the old value.

=cut

sub remove {
    my ( $this, $attr ) = @_;

    if ( $attr =~ m/^(\w+)\.(.*)$/o && ref( $this->{keys}{$attr} )) {
        $attr = $1;
        my $field = $2;
        return $this->{keys}{$attr}->remove( $field );
    } else {
        my $val = $this->{keys}{$attr};
        delete( $this->{keys}{$attr} );
        return $val;
    }
}

=begin text

---+++ =getKeys()= -> perl array

Get a "perl" array of the keys in the map, suitable for use with =foreach=

=cut

sub getKeys {
    my $this = shift;

    return keys( %{$this->{keys}} );
}

=begin text

---+++ =getValues()= -> perl array

Get a "perl" array of the values in the Map, suitable for use with =foreach=

=cut

sub getValues {
    my $this = shift;

    return values( %{$this->{keys}} );
}

=begin text

---+++ =search($search)= -> search result
   * =$search= - TWiki::Contrib::DBCacheContrib::Search object to use in the search
Search the map for keys that match with the given object.
values. Return a =TWiki::Contrib::DBCacheContrib::Array= of matching keys.

=cut

sub search {
    my ( $this, $search ) = @_;
    ASSERT($search) if DEBUG;
    my $result = new TWiki::Contrib::DBCacheContrib::Array();

    foreach my $meta ( values( %{$this->{keys}} )) {
        if ( $search->matches( $meta )) {
            $result->add( $meta );
        }
    }

    return $result;
}

=begin text

---+++ =toString($limit, $level, $strung)= -> string
   * =$limit= - recursion limit for expansion of elements
   * =$level= - currentl recursion level
Generates an HTML string representation of the object.

=cut

sub toString {
    my ( $this, $limit, $level, $strung ) = @_;

    if ( !defined( $strung )) {
        $strung = {};
    } elsif( $strung->{$this} ) {
        return $this;
    }
    $level = 0 unless (defined($level));
    $limit = 2 unless (defined($limit));
    if ( $level == $limit ) {
        return $this.'.....';
    }
    $strung->{$this} = 1;
    my $key;
    my $ss = '';
    foreach $key ( keys %{$this->{keys}} ) {
        my $item = $key.' = ';
        my $entry = $this->{keys}{$key};
        if ( ref( $entry )) {
            $item .= $entry->toString( $limit, $level + 1, $strung );
        } elsif ( defined( $entry )) {
            $item .= '"'.$entry.'"';
        } else {
            $item .= 'UNDEF';
        }
        $ss .= CGI::li( $item );
    }
    return CGI::ul($ss);
}

=begin text

---+++ write($archive)
   * =$archive= - the TWiki::Contrib::DBCacheContrib::Archive being written to
Writes this object to the archive. Archives are used only if Storable is not available. This
method must be overridden by subclasses is serialisation of their data fields is required.

=cut

sub write {
    my ( $this, $archive ) = @_;

    $archive->writeInt( $this->size());
    foreach my $key ( keys %{$this->{keys}} ) {
        $archive->writeObject( $key );
        $archive->writeObject( $this->{keys}{$key} );
    }
}

=begin text

---+++ read($archive)
   * =$archive= - the TWiki::Contrib::DBCacheContrib::Archive being read from
Reads this object from the archive. Archives are used only if Storable is not available. This
method must be overridden by subclasses is serialisation of their data fields is required.

=cut

sub read {
    my ( $this, $archive ) = @_;

    my $sz = $archive->readInt();
    while ( $sz-- > 0 ) {
        my $key = $archive->readObject();
        $this->{keys}{$key} = $archive->readObject();
    }
}

1;
