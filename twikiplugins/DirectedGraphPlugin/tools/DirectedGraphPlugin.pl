#!/usr/bin/perl

# Support script for sandbox security mechanism for DirectedGraphPlugin
# Sets the proper working dir and calls dot

use strict;

my $debug = 1;

if ($debug) {
    open( DEBUGFILE, ">>/tmp/DirectedGraphPlugin.pl.log" );
    print DEBUGFILE "\n----\nCalling dot; got parameters:\n";
    print DEBUGFILE join( "\n", @ARGV ) . "\n";
    close DEBUGFILE;
}

if ( $#ARGV != 5 ) {
    open( DEBUGFILE, ">>/tmp/DirectedGraphPlugin.pl.log" );
    print DEBUGFILE "Usage: DirectedGraphPlugin.pl dot_executable working_dir infile format outfile errfile\n";
    close DEBUGFILE;
    die "Usage: DirectedGraphPlugin.pl dot_executable working_dir infile format outfile errfile\n";
}

open( ERRFILE, "$ARGV[5]" );
print ERRFILE "";
close ERRFILE;

unless ( chdir "$ARGV[1]" ) {
    open( ERRFILE, ">>$ARGV[5]" );
    print ERRFILE "Couldn't change working dir to $ARGV[1]: $!\n";
    close ERRFILE;
    die "Couldn't change working dir to $ARGV[1]: $!\n";
}

# GV_FILE_PATH need to be set for dot to load custom icons (shapefiles)
my $execCmd = "GV_FILE_PATH=\"$ARGV[1]/\" $ARGV[0] -T$ARGV[3] $ARGV[2] -o $ARGV[4] 2> $ARGV[5] ";

if ($debug) {
    open( DEBUGFILE, ">>/tmp/DirectedGraphPlugin.pl.log" );
    print DEBUGFILE "Built command line: " . $execCmd . "\n";
    close DEBUGFILE;
}

print `$execCmd`;
if ($?) {
    print "Problem executing dot command";
    if ($debug) {
       open( DEBUGFILE, ">>/tmp/DirectedGraphPlugin.pl.log" );
       print DEBUGFILE "Problem executing dot command: '$execCmd', got:\n$!";
       close DEBUGFILE;
    }
    die "Problem executing dot command: '$execCmd', got:\n$!";
}
