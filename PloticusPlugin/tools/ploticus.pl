#!/usr/bin/perl

# Support script for sandbox security mechanism for PloticusPlugin
# Sets the proper working dir and calls ploticus

my $debug = 0;

if ($debug) {
    open( DEBUGFILE, ">>/tmp/ploticus.pl.log" );
    print DEBUGFILE "\n----\nCalling ploticus; got parameters:\n";
    print DEBUGFILE join( "\n", @ARGV ) . "\n";
    close DEBUGFILE;
}

if ( $#ARGV != 5 ) {
    open( DEBUGFILE, ">>/tmp/ploticus.pl.log" );
    print DEBUGFILE "Usage: ploticus.pl ploticus_executable working_dir infile format outfile errfile\n";
    close DEBUGFILE;
    die "Usage: ploticus.pl ploticus_executable working_dir infile format outfile errfile\n";
}

my $ploticusBin = $ARGV[0];

open( ERRFILE, "$ARGV[5]" );
print ERRFILE "";
close ERRFILE;

print "Changing dir to" . $ARGV[1] . "\n" if $debug;
unless ( chdir "$ARGV[1]" ) {
    open( ERRFILE, ">>$ARGV[5]" );
    print ERRFILE "Couldn't change working dir to $ARGV[1]: $!\n";
    close ERRFILE;
    die "Couldn't change working dir to $ARGV[1]: $!\n";
}

my $execCmd = "$ARGV[0] -f $ARGV[2] -$ARGV[3] -o $ARGV[4] 2> $ARGV[5] ";

if ($debug) {
    print "Built command line: " . $execCmd . "\n";
    open( DEBUGFILE, ">>$ARGV[5]" );
    print DEBUGFILE "Built command line: " . $execCmd . "\n";
    close DEBUGFILE;
}

print `$execCmd`;
if ($!) {
    open( ERRFILE, ">>$ARGV[5]" );
    print ERRFILE "Problem with executing ploticus command: '$execCmd', got:\n$!";
    close ERRFILE; 
    die "Problem with executing ploticus command: '$execCmd', got:\n$!";
}
