#
# Copyright (C) Motorola 2003 - All rights reserved
# Copyright (C) Crawford Currie 2004
#
use strict;

=begin text

---++ package TWiki::Contrib::DBCacheContrib::Search

Search operators work on the fields of a TWiki::Contrib::DBCacheContrib::Map.
%STARTSECTION{"searchoperators"}%
Fields are given by name, and values by strings or numbers. Strings should always be surrounded by 'single-quotes'. Strings which are regular expressions (RHS of =, != =~ operators) use 'perl' regular expression syntax (google for =perlre= for help). Numbers can be signed integers or decimals. Single quotes in values may be escaped using backslash (\).

The following operators are available:
| *Operator* | *Result* | *Meaning* |
| <code>=</code> | Boolean | LHS exactly matches the regular expression on the RHS. The expression must match the whole string. |
| <code>!=</code> | Boolean | Inverse of = |
| <code>=~</code> | Boolean | LHS contains RHS i.e. the RHS is found somewhere in the field value. |
| <code>&lt;</code> | Boolean | Numeric < |
| <code>&gt;</code> | Boolean | Numeric > |
| <code>&gt;=</code> | Boolean | Numeric >= |
| <code>&lt;=</code> | Boolean | Numeric <= |
| =lc= | String | Unary lower case |
| =uc= | String | Unary UPPER CASE |
| =EARLIER_THAN= | BOOLEAN | Date is earlier than the given date |
| =LATER_THAN= | Boolean | LHS is later than the given date (string containing a date e.g. '1 Apr 2003') |
| =WITHIN_DAYS= | Boolean | Date (which must be in the future) is within n _working_ days of todays date |
| <code>!</code> | Boolean | Unary NOT |
| =AND= | Boolean | AND |
| =OR= | Boolean | OR |
| <code>()</code> | any | Bracketed subexpression |

Dates for =EARLIER_THAN=, =LATER_THAN= and =WITHIN_DAYS= must be dates in the format expected by =Time::ParseDate= (like the ActionTrackerPlugin). =WITHIN_DAYS= works out the number of _working_ days (i.e. excluding Saturday and Sunday). Apologies in advance if your weekend is offset &plusmn; a day! Integers will automatically be converted to dates, by assuming they represent a number of seconds since midnight GMT on 1st January 1970.

%ENDSECTION{"searchoperators"}%

---+++ Example
Get a list of attachments that have a date earlier than 1st January 2000
<verbatim>
  $db = new TWiki::Contrib::DBCacheContrib::DBCache( $web ); # always done
  $db->load();
  my $search = new TWiki::Contrib::DBCacheContrib::Search("date EARLIER_THAN '1st January 2000'");

  foreach my $topic ($db->getKeys()) {
     my $attachments = $topic->get("attachments");
     foreach my $val ($attachments->getValues()) {
       if ($search->matches($val)) {
          print $val->get("name") . "\n";
       }
     }
  }
</verbatim>

A search object implements the "matches" method as its general
contract with the rest of the world.

=cut

package TWiki::Contrib::DBCacheContrib::Search;

# Operator precedences
my %operators =
  (
    'lc' => { exec => \&OP_lc, prec => 5},
    'uc' => { exec => \&OP_uc, prec => 5},
    '=' => { exec => \&OP_equal, prec => 4},
    '=~' => { exec => \&OP_match, prec => 4},
    '!=' => { exec => \&OP_not_equal, prec => 4},
    '>=' => { exec => \&OP_gtequal, prec => 4},
    '<=' => { exec => \&OP_smequal, prec => 4},
    '>' => { exec => \&OP_greater, prec => 4},
    '<' => { exec => \&OP_smaller, prec => 4},
    'EARLIER_THAN' => { exec => \&OP_earlier_than, prec => 4},
    'LATER_THAN' => { exec => \&OP_later_than, prec => 4},
    'WITHIN_DAYS' => { exec => \&OP_within_days, prec => 4},
    'IS_DATE' => { exec => \&OP_is_date, prec => 4},
    '!' => { exec => \&OP_not, prec => 3},
    'AND' => { exec => \&OP_and, prec=> 2},
    'OR' => { exec => \&OP_or, prec => 1},
    'FALSE' => { exec => \&OP_false, prec=> 0},
    'NODE' => { exec => \&OP_node, prec => 0},
    'NUMBER' => { exec => \&OP_string, prec => 0},
    'REF' => { exec => \&OP_ref, prec => 0},
    'STRING' => { exec => \&OP_string, prec => 0},
    'TRUE' => { exec => \&OP_true, prec => 0},
    'i2d' => { exec => \&OP_i2d, prec => 0},
  );

my $bopRE =
  "AND\\b|OR\\b|!=|=~?|<=?|>=?|LATER_THAN\\b|EARLIER_THAN\\b|WITHIN_DAYS\\b|IS_DATE\\b";
my $uopRE = "!|[lu]c\\b";

my $now = time();


# PUBLIC STATIC used for testing only; force 'now' to be a particular
# time.
sub forceTime {
    my $t = shift;

    require Time::ParseDate;

    $now = Time::ParseDate::parsedate( $t );
}

=begin text

---+++ =new($string)=
   * =$string= - string containing an expression to parse
Construct a new search node by parsing the passed expression.

=cut

sub new {
    my ( $class, $string, $left, $op, $right ) = @_;
    my $this;
    if ( defined( $string )) {
        if ( $string =~ m/^\s*$/o ) {
            return new TWiki::Contrib::DBCacheContrib::Search( undef, undef, "TRUE", undef );
        } else {
            my $rest;
            ( $this, $rest ) = _parse( $string );
            return $this;
        }
    } else {
        $this = {};
        $this->{right} = $right;
        $this->{left} = $left;
        $this->{op} = $op;
        return bless( $this, $class );
    }
}

# PRIVATE STATIC generate a Search by popping the top two operands
# and the top operator. Push the result back onto the operand stack.
sub _apply {
    my ( $opers, $opands ) = @_;
    my $o = pop( @$opers );
    my $r = pop( @$opands );
    die "Bad search" unless defined( $r );
    my $l = undef;
    if ( $o =~ /^$bopRE$/o ) {
        $l = pop( @$opands );
        die "Bad search" unless defined( $l );
    }
    my $n = new TWiki::Contrib::DBCacheContrib::Search( undef, $l, $o, $r );
    push( @$opands, $n);
}

# PRIVATE STATIC simple stack parser for grabbing boolean expressions
sub _parse {
    my $string = shift;

    $string .= " ";
    my @opands;
    my @opers;
    while ( $string !~ m/^\s*$/o ) {
        if ( $string =~ s/^\s*($bopRE)//o ) {
            # Binary comparison op
            my $op = $1;
            while ( scalar( @opers ) > 0 && $operators{$op}->{prec} < $operators{$opers[$#opers]}->{prec} ) {
                _apply( \@opers, \@opands );
            }
            push( @opers, $op );
        } elsif ( $string =~ s/^\s*($uopRE)//o ) {
            # unary op
            push( @opers, $1 );
        } elsif ( $string =~ s/^\s*\'(.*?)(?<!\\)\'//o ) {
            push( @opands, new TWiki::Contrib::DBCacheContrib::Search(
                undef, undef, "STRING", $1 ));
        } elsif ( $string =~ s/^\s*(-?\d+(\.\d*)?(e-?\d+)?)//io ) {
            push( @opands, new TWiki::Contrib::DBCacheContrib::Search(
                undef, undef, "NUMBER", $1 ));
        } elsif ( $string =~ s/^\s*(\@\w+(?:\.\w+)+)//o ) {
            push( @opands, new TWiki::Contrib::DBCacheContrib::Search(
                undef, undef, "REF", $1 ));
        } elsif ( $string =~ s/^\s*([\w\.]+)//o ) {
            push( @opands, new TWiki::Contrib::DBCacheContrib::Search(
                undef, undef, "NODE", $1 ));
        } elsif ( $string =~ s/^\s*\(//o ) {
            my $oa;
            ( $oa, $string ) = _parse( $string );
            push( @opands, $oa );
        } elsif ( $string =~ s/^\s*\)//o ) {
            last;
        } else {
            return ( undef, "Parser stuck at $string" );
        }
    }
    while ( scalar( @opers ) > 0 ) {
        _apply( \@opers, \@opands );
    }
    die "Bad search" unless ( scalar( @opands ) == 1 );
    return ( pop( @opands ), $string );
}

sub matches {
  my ($this, $map) = @_;

  my $handler = $operators{$this->{op}};
  return 0 unless $handler;

  return $handler->{exec}($this->{right}, $this->{left}, $map);
}

sub OP_true { return 1; }

sub OP_false { return 0; }

sub OP_string { return $_[0]; }

sub OP_number { return $_[0]; }

sub OP_or {
  my ($r, $l, $map) = @_;
  return 0 unless $l;
  return ($l->matches( $map ) || $r->matches( $map ));
}

sub OP_and {
  my ($r, $l, $map) = @_;
  return 0 unless $l;
  return ( $l->matches( $map ) && $r->matches( $map ))?1:0;
}

sub OP_not {
  my ($r, $l, $map) = @_;
  return ($r->matches($map))?0:1;
}

sub OP_lc {
  my ($r, $l, $map) = @_;
  return lc($r->matches($map));
}

sub OP_uc {
  my ($r, $l, $map) = @_;
  return uc($r->matches($map));
}

sub OP_i2d {
  my ($r, $l, $map) = @_;
  return 0 unless $r;
  return TWiki::Time::formatTime( $r->matches( $map ), '$email', 'gmtime' );
}

sub OP_node {
  my ($r, $l, $map) = @_;

  return 0 unless ($map && defined $r);
  # Only reference the hash if the contained form does not
  # define the field
  my $form = $map->get("form");
  my $val = $map->get($form)->get( $r );
  unless ($val) {
      $val = $map->get( $r );
  }
  return $val;
}

sub OP_ref {
  my ($r, $l, $map) = @_;
  return 0 unless ($map && defined $r);

  # get web db
  my $web = $map->fastget('_web');

  # parse reference chain
  my %seen;
  while ($r =~ /^\@(\w+)\.(.*)$/) {
      my $ref = $1;
      $r = $2;

      # protect against infinite loops
      return 0 if $seen{$ref}; # outch
      $seen{$ref} = 1;

      # get form
      my $form = $map->fastget('form');
      return 0 unless $form; # no form

      # get refered topic
      $form = $map->fastget($form);
      $ref = $form->fastget($ref);
      return 0 unless $ref; # unknown field

      # get topic object
      $map = $web->fastget($ref);
      return 0 unless $map; # unknown ref
  }

  # the tail is a property of the referenced topic
  my $val = $map->get($map->get("form"))->get( $r );
  unless ($val) {
      $val = $map->get( $r );
  }
  return $val;
}

sub OP_equal {
  my ($r, $l, $map) = @_;

  my $lval = $l->matches( $map );
  my $rval = $r->matches( $map );
  return 0 unless ( defined $lval  && defined $rval);

  return ( $lval =~ m/^$rval$/ )?1:0;
}
sub OP_not_equal {
  my ($r, $l, $map) = @_;

  my $lval = $l->matches( $map );
  my $rval = $r->matches( $map );
  return 0 unless ( defined $lval  && defined $rval);

  return ( $lval =~ m/^$rval$/ )?0:1;
}
sub OP_match {
  my ($r, $l, $map) = @_;

  my $lval = $l->matches( $map );
  my $rval = $r->matches( $map );
  return 0 unless ( defined $lval  && defined $rval);

  return ( $lval =~ m/$rval/ )?1:0;
}
sub OP_greater {
  my ($r, $l, $map) = @_;

  my $lval = $l->matches( $map );
  my $rval = $r->matches( $map );
  return 0 unless ( defined $lval  && defined $rval);

  return ( $lval > $rval )?1:0;
}

sub OP_smaller {
  my ($r, $l, $map) = @_;

  my $lval = $l->matches( $map );
  my $rval = $r->matches( $map );
  return 0 unless ( defined $lval  && defined $rval);

  return ( $lval < $rval )?1:0;
}

sub OP_gtequal {
  my ($r, $l, $map) = @_;

  my $lval = $l->matches( $map );
  my $rval = $r->matches( $map );
  return 0 unless ( defined $lval  && defined $rval);

  return ( $lval >= $rval )?1:0;
}

sub OP_smequal {
  my ($r, $l, $map) = @_;

  my $lval = $l->matches( $map );
  my $rval = $r->matches( $map );
  return 0 unless ( defined $lval  && defined $rval);

  return ( $lval <= $rval )?1:0;
}

sub OP_within_days {
  my ($r, $l, $map) = @_;

  my $lval = $l->matches( $map );
  if ($lval !~ /^-?\d+$/) {
    require Time::ParseDate;
    $lval = Time::ParseDate::parsedate( $lval );
  }
  return 0 unless( defined( $lval ));
  my $rval = $r->matches( $map );
  return ( $lval >= $now && workingDays( $now, $lval ) <= $rval )?1:0;
}

sub OP_later_than {
  my ($r, $l, $map) = @_;

  my $lval = $l->matches( $map );
  if ($lval !~ /^-?\d+$/) {
    require Time::ParseDate;
    $lval = Time::ParseDate::parsedate( $lval );
  }
  return 0 unless( defined( $lval ));
  
  my $rval = $r->matches( $map );
  if ($rval !~ /^-?\d+$/) {
    require Time::ParseDate;
    $rval = Time::ParseDate::parsedate( $rval );
  }
  return 0 unless( defined( $lval ));
  return ( $lval > $rval )?1:0;
}

sub OP_earlier_than {
  my ($r, $l, $map) = @_;

  my $lval = $l->matches( $map );
  if ($lval !~ /^-?\d+$/) {
    require Time::ParseDate;
    $lval = Time::ParseDate::parsedate( $lval );
  }
  return 0 unless( defined( $lval ));
  
  my $rval = $r->matches( $map );
  if ($rval !~ /^-?\d+$/) {
    require Time::ParseDate;
    $rval = Time::ParseDate::parsedate( $rval );
  }
  return 0 unless( defined( $lval ));
  return ( $lval < $rval )?1:0;
}

sub OP_is_date {
  my ($r, $l, $map) = @_;

  my $lval = $l->matches( $map );
  if ($lval !~ /^-?\d+$/) {
    require Time::ParseDate;
    $lval = Time::ParseDate::parsedate( $lval );
  }
  return 0 unless( defined( $lval ));
  
  my $rval = $r->matches( $map );
  if ($rval !~ /^-?\d+$/) {
    require Time::ParseDate;
    $rval = Time::ParseDate::parsedate( $rval );
  }
  return 0 unless( defined( $lval ));
  return ( $lval == $rval )?1:0;
}


# PUBLIC STATIC calculate working days between two times
# Published because it's useful elsewhere
sub workingDays {
    my ( $start, $end ) = @_;

    use integer;
    my $elapsed_days = ( $end - $start ) / ( 60 * 60 * 24 );
    # total number of elapsed 7-day weeks
    my $whole_weeks = $elapsed_days / 7;
    my $extra_days = $elapsed_days - ( $whole_weeks * 7 );
    if ( $extra_days > 0 ) {
        my @lt = localtime( $start );
        my $wday = $lt[6]; # weekday, 0 is sunday

        if ($wday == 0) {
            $extra_days-- if ( $extra_days > 0 );
        } else {
            $extra_days-- if ($extra_days > (6 - $wday));
            $extra_days-- if ($extra_days > (6 - $wday));
        }
    }
    return $whole_weeks * 5 + $extra_days;
}

=begin text

---+++ =toString()= -> string
Generates a string representation of the object.

=cut

sub toString {
    my $this = shift;

    my $text = "";
    if ( defined( $this->{left} )) {
        if ( !ref($this->{left}) ) {
            $text .= $this->{left};
        } else {
            $text .= "(" . $this->{left}->toString() . ")";
        }
        $text .= " ";
    }
    $text .= $this->{op} . " ";
    if ( !ref($this->{right}) ) {
        $text .= "'" . $this->{right} . "'";
    } else {
        $text .= "(" . $this->{right}->toString() . ")";
    }
    return $text;
}

=begin text

--+++ =addOperator(%oper)
Add an operator to the parser

=%oper= is a hash, containing the following fields:
   * =name= - operator string
   * =prec= - operator precedence, positive non-zero integer.
     Larger number => higher precedence.
   * =arity= - set to 1 if this operator is unary, 2 for binary. Arity 0
     is legal, should you ever need it.
   * =exec= - the handler to implement the new operator

=cut

sub addOperator {
  my %oper = @_;

  my $name = $oper{name};
  die "illegal operator definition" unless $name;

  $operators{$name} = \%oper;

  if ($oper{arity} == 2) {
    $bopRE .= "|\\b$name\\b";
  } elsif ($oper{arity} == 1) {
    $uopRE .= "|\\b$name\\b";
  } else {
    die "illegal operator definition"; 
  }
}

1;
