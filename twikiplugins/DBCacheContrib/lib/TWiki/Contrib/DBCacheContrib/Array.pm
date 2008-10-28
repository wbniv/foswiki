#
# Copyright (C) Motorola 2003 - All rights reserved
# Copyright (C) Crawford Currie 2004
#
package TWiki::Contrib::DBCacheContrib::Array;

use strict;
use Assert;

=begin text

---++ package TWiki::Contrib::DBCacheContrib::Array

Generic array object. This is required because perl arrays are not objects,
and cannot be subclassed e.g. for serialisation. To avoid lots of horrid
code to handle special cases of the different perl data structures, we use
this array object instead.

=cut

use TWiki::Contrib::DBCacheContrib::Search;

=begin text

---+++ =new()=
Create a new, empty array object

=cut

sub new {
    my $class = shift;
    my $this = {};

    # this leaves {values} undefined!???
    # PRIVATE the actual array
    $this->{values} = ();

    return bless( $this, $class );
}

# PUBLIC dispose of this array, breaking any circular references
sub DESTROY {
    my $this = shift;
    #print STDERR "Destroy ",ref($this),"\n";
    $this->{values} = undef;
    # should be enough; nothing else should be pointing to the array
}

=begin text

---+++ =add($object)=
   * =$object= any perl data type
Add an element to the end of the array

=cut

sub add {
    my $this = shift;
    return push( @{$this->{values}}, shift );
}

=begin text

---+++ =find($object)= -> integer
   * $object datum of the same type as the content of the array
Uses "==" to find the given element in the array and return it's index

=cut

sub find {
    my ( $this, $obj ) = @_;
    my $i = 0;
    foreach my $meta ( @{$this->{values}} ) {
        return $i if ( $meta == $obj );
        $i++;
    }
    return -1;
}

=begin text

---+++ =remove($index)=
   * =$index= - integer index
Remove an entry at an index from the array.

=cut

sub remove {
    my ( $this, $i ) = @_;
    splice( @{$this->{values}}, $i, 1 );
}

=begin text

---+++ =get($key, $root)= -> datum
   * =$k= - key
   * $root - what # refers to
*Subfield syntax*
   * =get("9", $r)= where $n is a number will get the 9th entry in the array
   * =get("[9]", $r)= will also get the 9th entry
   * =get(".9", $r)= will also get the 9th entry
   * =get(".X", $r)= will return the sum of the subfield =X= of each entry
   * =get("[?<i>search</i>]", $r)= will perform the given search over the entries in the array. Always returns an array result, even when there is only one result. For example: <code>[?name='Sam']</code> will return an array of all the entries that have their subfield =name= set to =Sam=.
   * =#= means "reset to root". So =get("#[3]", $r)= will return the 4th entry of $r (assuming $r is an array!).
   * =get("[*X]", $r)= will get a new array made from subfield X of each entry in this array.

Where the result of a subfield expansion is another object (a Map or an Array) then further subfield expansions can be used. For example,
<verbatim>
get("parent.UserTable[?SubTopic='ThisTopic'].UserName", $web);
</verbatim>

See also =TWiki::Contrib::DBCacheContrib::Map= for syntax that applies to maps.

=cut

sub get {
    my ( $this, $key, $root ) = @_;
    # Field
    if ( $key =~ m/^(\d+)(.*)/o ) {
        return undef unless ( $this->size() > $1 );
        my $field = $this->{values}[$1];
        return $field->get( $2, $root ) if ( $2  && ref( $field ));
        return $field;
    } elsif ( $key =~ m/^\.(.*)$/o ) {
        return $this->get( $1, $root );
	} elsif ( $key =~ /^(\w+)$/o ) {
        return $this->sum( $key );
	} elsif ( $key =~ m/^\[\?(.+)$/o ) {
        my ( $one, $two ) = mbrf( "[", "]", $1);
        my $res = $this->search( new TWiki::Contrib::DBCacheContrib::Search( $one ) );
        return $res->get( $two ) if ( $two && ref( $res ));
        return $res;
	} elsif ( $key =~ m/^\[\*(.+)$/o ) {
        my ( $one, $two ) = mbrf( "[", "]", $1);
        my $res = new TWiki::Contrib::DBCacheContrib::Array();

        foreach my $meta ( @{$this->{values}} ) {
            if ( ref( $meta )) {
                my $fieldval = $meta->get( $one, $root );
                if ( defined( $fieldval ) ) {
                    $res->add( $fieldval );
                }
            }
        }

        return $res;
	} elsif ( $key =~ m/^\[(.+)\](.*)$/o ) {
        my $field = $this->get( $1, $root );
        return $field->get( $2, $root ) if ( $2 && ref( $field ));
        return $field;
    } elsif ( $key =~ m/^#(.*)$/o ) {
        return $root->get( $1, $root );
    } else {
        die "ERROR: bad Array expression at $key";
	}
}

=begin text

---+++ =size()= -> integer
Get the size of the array

=cut

sub size {
    my $this = shift;
    return 0 unless ( defined( $this->{values} ));
    return scalar( @{$this->{values}} );
}

=begin text

---+++ =sum($field)= -> number
   * =$field= - name of a field in the class of objects stored by this array
Returns the sum of values of the given field in the objects stored in this array.

=cut

sub sum {
    my ( $this, $field ) = @_;
    return 0 if ( $this->size() == 0 );

    my $sum = 0;
    my $subfields;

    if ( $field =~ s/(\w+)\.(.*)/$1/o ) {
        $subfields = $2;
    }

    foreach my $meta ( @{$this->{values}} ) {
        if ( ref( $meta )) {
            my $fieldval = $meta->get( $field, undef );
            if ( defined( $fieldval ) ) {
                if ( defined( $subfields )) {
                    die "$field has no subfield $subfields" unless ( ref( $fieldval ));
                    $sum += $fieldval->sum( $subfields );
                } elsif ( $fieldval =~ m/^\s*\d+/o ) {
                    $sum += $fieldval;
                }
            }
        }
    }

    return $sum;
}

sub contains {
    my ( $this, $tv ) = @_;
    return ( $this->find( $tv ) >= 0 );
}

=begin text

---+++ =search($search)= -> search result
   * =$search= - TWiki::Contrib::DBCacheContrib::Search object to use in the search
Search the array for matches with the given object.
values. Return a =TWiki::Contrib::DBCacheContrib::Array= of matching entries.

=cut

sub search {
    my ( $this, $search ) = @_;
    ASSERT($search) if DEBUG;
    my $result = new TWiki::Contrib::DBCacheContrib::Array();

    return $result unless ( $this->size() > 0 );

    foreach my $meta ( @{$this->{values}} ) {
        if ( $search->matches( $meta )) {
            $result->add( $meta );
        }
    }

    return $result;
}

=begin text

---+++ =getValues()= -> perl array

Get a "perl" array of the values in the array, suitable for use with =foreach=

=cut

# For some reason when an empty array is restored from Storable,
# getValues gives us a one-element array. Archive doesn't,
# it gives us a nice empty array. With storable, the one
# entry is undef.
sub getValues {
    my $this = shift;

    return undef unless ( defined( @{$this->{values}} ));
    # does this return the array by reference? probably not...
    return @{$this->{values}};
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
    } elsif ( $strung->{$this} ) {
        return $this;
    }
    $level = 0 unless (defined($level));
    $limit = 2 unless (defined($limit));
    if ( $level == $limit ) {
        return "$this.....";
    }
    $strung->{$this} = 1;
    my $ss = '';
    if ( $this->size() > 0 ) {
        my $n = 0;
        foreach my $entry ( @{$this->{values}} ) {
            my $item = '';
            if( ref( $entry )) {
                $item .= $entry->toString( $limit, $level + 1, $strung );
            } elsif( defined( $entry )) {
                $item .= '"'.$entry.'"';
            } else {
                $item .= 'UNDEF';
            }
            $ss .= CGI::li( $item );
            $n++;
        }
    }
    return CGI::ol({start=>0}, $ss);
}

=begin text

---+++ write($archive)
   * =$archive= - the TWiki::Contrib::DBCacheContrib::Archive being written to
Writes this object to the archive. Archives are used only if Storable is not available. This
method must be overridden by subclasses is serialisation of their data fields is required.

=cut

sub write {
    my ( $this, $archive ) = @_;

    my $sz = $this->size();
    $archive->writeInt( $sz );
    foreach my $v ( @{$this->{values}} ) {
        $archive->writeObject( $v );
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
        push( @{$this->{values}}, $archive->readObject() );
    }
}

# PUBLIC but not exported
# bracket-matching split of a string into ( $one, $two ) where $one
# matches the section before the closing bracket and $two matches
# the section after. throws if the closing bracket isn't found.
sub mbrf {
	my ($ob, $cb, $s) = @_;
	
	my @a = reverse(split(/ */, $s));
	my $pre = "";
	my $d = 0;
	
	while ( $#a >= 0 ) {
        my $c = pop( @a );
        if ($c eq $cb) {
            if ( !$d ) {
                return ( $pre, join("", reverse(@a)));
            } else {
                $d--;
            }
        } elsif ( $c eq $ob ) {
            $d++;
        }
        $pre .= $c;
	}
	die "ERROR: mismatched $ob$cb at $s";
}

1;
