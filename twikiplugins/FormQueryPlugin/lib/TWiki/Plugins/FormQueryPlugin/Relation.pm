#
# Copyright (C) Motorola 2003 - All rights reserved
#
use strict;

# Relationship between topic names
# Any topic with a name matching the parent re will be set as a child of
# the derived parent topic, if it exists. The format of the childof map
# is a semicolon-separated list of triples, each of the format:
#
# <re> <relation> <derivative>
#
# where <re> is a regular expression that matches the child topic
# and <derivative> is the name of the parent topic. This is a standard
# regular expression except that $1, $2 ... are given a 1:1 mapping to
# $1, $2 ... in the derivative (i.e. instead of \d+ on the LHS use $1).
#
# <relation> is the name of the relation, which is one-to-many from the parent
# to children, and is stored alongside normal fields in the parent and child.
# In the parent it appears as the field "<relation>" and in the child as the
# field "<relation>_of".
#
# So, let's say we have the relation "detest" that relates topics called
# "TestItem$1x$2" to parents "ReQ$1" i.e. TestItem7576x39 has the relation
# "detest_of" to ReQ7576. This would be expressed in the relation map by:
#
# TestItem$1x$2 detest ReQ$1
#
# TestItem7576x39 will get the field "detest_of" which will contain
# the value "ReQ7576" and ReQ7576 will get the field "detest" which
# will contain the value "TestItem7576x39". If there is a second topic
# TestItem7576x40, the "detest" field of ReQ7576 will contain
# "TestItem7576x39,TestItem7576x40".
#
# The method "apply" is used to get from a shild topic to a parent topic
# name. 
package TWiki::Plugins::FormQueryPlugin::Relation;

# PUBLIC create a new relation by parsing the given string
sub new {
    my ( $class, $cm ) = @_;
    my $this = {};
    if ( $cm =~ m/^\s*([^\s]+)\s+(\w+)\s+([^\s]+)/o ) {
        my $child = $1;
        $this->{relation} = $2;
        my $parent = $3;
        $this->{child} = $child;
        $this->{parent} = $parent;
        my $n = 1;
        while ( $child =~ s/%(\w)/(\\w+)/o ) {
            $parent =~ s/%$1/\$$n/;
            $n++;
        }
        $this->{childToParent} = "\$parent =~ s/^${child}\$/$parent/o";
    }
    return bless( $this, $class );
}

sub childToParent {
    my $this = shift;

    return $this->{relation} . "_of";
}

sub parentToChild {
    my $this = shift;

    return $this->{relation};
}

# PUBLIC apply the relation to derive a new topic name
sub apply {
    my ( $this, $topic ) = @_;
    my $parent = $topic;
    eval $this->{childToParent};
    if ( $parent eq $topic ) {
        return undef;
    } else {
        return $parent;
    }
}

# Derivative creation. A derivative is defined as the next topic that
# does not exist found by incrementing the last %n in the re. This
# method computes a pattern for the next child in the sequence, returning
# a topic name with a '\n' where the topic number should go. It is
# the responsibility of the caller to determine if this conflicts with
# any known topic.
sub nextChild {
    my ( $this, $topic ) = @_;

    # find out what all the other fields should be by matching this
    # topic
    my $parent = $this->{parent};
    my @chars;
    #print "NextChild for $topic in ", $this->toString(),"\n";
    # Replace map characters in the parent with (\w+) and
    # record the character for each match number ($1, $2 etc )
    while ( $parent =~ s/%(\w)/(\\w+)/o ) {
        #print STDERR "Push $1\n";
        push( @chars, $1 );
    }

    # use apply to find the parent of the known child
    my $dad = $topic;
    #print STDERR "Dad $topic \-\> ";

    # match this against the expanded parent
    $dad =~ m/$parent/;
    #print STDERR "$dad $1\n";

    # $ns are now the field values we want to re-use in the new
    # child. Record these.
    my $n = 1;
    my %map;
    foreach my $ch ( @chars ) {
        $map{$ch} = eval "\$$n";
        $n++;
    }

    # Now replace the named field values in the child expression
    my $child = $this->{child};
    foreach my $key ( keys( %map )) {
        #print STDERR "Map %$key -> $map{$key}\n";
        $child =~ s/%$key/$map{$key}/;
    }
    # the remaining % in the child is what we want to increment
    $child =~ s/%\w/\n/o;

    return $child;
}

sub toString {
    my $this = shift;

    return $this->{child} . " " . $this->{relation} . " " . $this->{parent};
}

1;
