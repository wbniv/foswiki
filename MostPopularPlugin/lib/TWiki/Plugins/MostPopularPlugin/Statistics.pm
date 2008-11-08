# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Adapted from lib/TWiki/UI/Statistics.pm
# by Koen Martens, kmartens@sonologic.nl
# Copyright (C) 2006-2008 Koen Martens, kmartens@sonologic.nl
# Copyright (C) 1999-2006 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
# Copyright (C) 2002 Richard Donkin, rdonkin@bigfoot.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.

=begin twiki

---+ package TWiki::UI::Statistics
Statistics extraction and presentation

=cut
package TWiki::Plugins::MostPopularPlugin::Statistics;

use strict;
use Assert;
use File::Copy qw(copy);
use IO::File;
use Error qw( :try );

use TWiki::UI::Statistics;
use TWiki::Func;
use File::Copy;

my $debug = 0;

BEGIN {
    # Do a dynamic 'use locale' for this module
    if( $TWiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=pod

---++ StaticMethod statistics( $session )
=statistics= command handler.
This method is designed to be
invoked via the =TWiki::UI::run= method.

Generate statistics topic.
If a web is specified in the session object, generate WebStatistics
topic update for that web. Otherwise do it for all webs

=cut

sub statistics {
    my $session = shift;

    my $webName = $session->{webName};

    my $tmp = '';
    # web to redirect to after finishing
    my $destWeb = $TWiki::cfg{UsersWebName};
    my $logDate = $session->{cgiQuery}->param( 'logdate' ) || '';
    $logDate =~ s/[^0-9]//g;  # remove all non numerals
    $debug = $session->{cgiQuery}->param( 'debug' );

    my $dir="$TWiki::cfg{RCS}{WorkAreaDir}/MostPopularPlugin";

    unless( -d $dir ) {
        mkdir( $dir ) || throw Error::Simple(
            'RCS: failed to create MostPopularPlugin work area: '.$! );
    }       

    unless( $session->inContext( 'command_line' )) {
        # running from CGI
        $session->writePageHeader();
        print CGI::start_html(-title=>'TWiki: Create Usage Statistics');
    }
    # Initial messages
    _printMsg( $session, 'TWiki: Create Usage Statistics' );
    _printMsg( $session, '!Do not interrupt this script!' );
    _printMsg( $session, '(Please wait until page download has finished)' );


    # FIXME move the temp dir stuff to TWiki.cfg
    my $tmpDir;
    if ( $TWiki::cfg{OS} eq 'UNIX' ) { 
        $tmpDir = $ENV{'TEMP'} || "/tmp"; 
    } elsif ( $TWiki::cfg{OS} eq 'WINDOWS' ) {
        $tmpDir = $ENV{'TEMP'} || "c:/"; 
    } else {
        # FIXME handle other OSs properly - assume Unix for now.
        $tmpDir = "/tmp";
    }

    my $logFile = $TWiki::cfg{LogFileName};

    my $logWildCard = $logFile;
    $logWildCard=~s/%DATE%/*/g;

    my @files=glob($logWildCard);

    # hash of hashes (web -> topic) with grand totals
    my %totalViews=();
    my %totalWebViews=();

    foreach(@files) {
      $logFile = $_;

      if($logFile=~/log([0-9][0-9][0-9][0-9])([0-9][0-9])\.txt/) {
        my $logMonth=$2; my $logYear=$1; my $logMonthYear="$logMonth $logYear";

        unless( -e $logFile ) {
          _printMsg( $session, "!Log file $logFile does not exist; aborting" );
          return;
        }

        # Copy the log file to temp file, since analysis could take some time

        my $randNo = int ( rand 1000);	# For mod_perl with threading...
        my $tmpFilename = TWiki::Sandbox::untaintUnchecked( "$tmpDir/twiki-stats.$$.$randNo" );

        File::Copy::copy ($logFile, $tmpFilename)
          or throw Error::Simple( 'Cannot backup log file: '.$! );

        my $TMPFILE = new IO::File;
        open $TMPFILE, $tmpFilename
          or throw Error::Simple( 'Cannot open backup file: '.$! );

        # Do a single data collection pass on the temporary copy of logfile,
        # then process each web once.
        my ($viewRef, $contribRef, $statViewsRef, $statSavesRef, $statUploadsRef) =
          TWiki::UI::Statistics::_collectLogData( $session, $TMPFILE, $logMonthYear );

	foreach my $web (keys %{$viewRef}) {
	  foreach my $topic (keys %{$viewRef->{$web}}) {
	    $totalViews{$web}{$topic}+=$viewRef->{$web}->{$topic};
	    $totalWebViews{$web}+=$viewRef->{$web}->{$topic};
          }
        }
      }
    }

    my @sortView=();
    my @sortWeb=();
    my @sortTopic=();

    # sort per topic stats
    foreach my $web (keys %totalViews) {
      foreach my $topic (keys %{$totalViews{$web}}) {
	push(@sortView,$totalViews{$web}{$topic});
	push(@sortWeb,$web);
	push(@sortTopic,$topic);
      }
    }

    my $done=0;
    while(!$done) {
      $done=1;
      for (0..$#sortView-1) {
        if($sortView[$_]<$sortView[$_+1]) {
	  $done=0;
	  $tmp=$sortView[$_]; $sortView[$_]=$sortView[$_+1]; $sortView[$_+1]=$tmp;
	  $tmp=$sortWeb[$_]; $sortWeb[$_]=$sortWeb[$_+1]; $sortWeb[$_+1]=$tmp;
	  $tmp=$sortTopic[$_]; $sortTopic[$_]=$sortTopic[$_+1]; $sortTopic[$_+1]=$tmp;
	}
      }
    }

    # sort per web stats
    my @sortWebs=();
    my @sortWebViews=();

    foreach my $web (keys %totalWebViews) {
      push(@sortWebs,$web);
      push(@sortWebViews,$totalWebViews{$web});
    }

    $done=0;
    while(!$done) {
      $done=1;
      for (0..$#sortWebs-1) {
	if($sortWebViews[$_]<$sortWebViews[$_+1]) {
	  $done=0;
	  $tmp=$sortWebViews[$_]; $sortWebViews[$_]=$sortWebViews[$_+1]; $sortWebViews[$_+1]=$tmp;
	  $tmp=$sortWebs[$_]; $sortWebs[$_]=$sortWebs[$_+1]; $sortWebs[$_+1]=$tmp;
	}
      }
    }

    open(STATFILE,">$dir/statfile.tmp") || throw Error::Simple(
	"Unable to open $dir/statfile.tmp");
    for (0..$#sortView) {
      print STATFILE "$sortWeb[$_] $sortTopic[$_] $sortView[$_]\n";
    }
    close(STATFILE);
    move("$dir/statfile.tmp","$dir/statfile.txt")
	|| throw Error::Simple("Unable to move $dir/statfile.tmp to $dir/statfile.txt");

    open(STATFILE,">$dir/statfileweb.tmp") || throw Error::Simple(
	"Unable to open $dir/statfileweb.tmp");
    for (0..$#sortWebs) {
      print STATFILE "$sortWebs[$_] $sortWebViews[$_]\n";
    }
    close(STATFILE);
    move("$dir/statfileweb.tmp","$dir/statfileweb.txt")
	|| throw Error::Simple("Unable to move $dir/statfileweb.tmp to $dir/statfileweb.txt");

    _printMsg( $session, 'End creating usage statistics' );
    print CGI::end_html() unless( $session->inContext( 'command_line' ) );
}

# Debug only
# Print all entries in a view or contrib hash, sorted by web and item name
sub _debugPrintHash {
    my ($statsRef) = @_;
    # print "Main.WebHome views = " . ${$statsRef}{'Main'}{'WebHome'}."\n";
    # print "Main web, TWikiGuest contribs = " . ${$statsRef}{'Main'}{'Main.TWikiGuest'}."\n";
    foreach my $web ( sort keys %$statsRef) {
        my $count = 0;
        print $web,' web:',"\n";
        # Get reference to the sub-hash for this web
        my $webhashref = ${$statsRef}{$web};
		# print 'webhashref is ' . ref ($webhashref) ."\n";
        # Items can be topics (for view hash) or users (for contrib hash)
        foreach my $item ( sort keys %$webhashref ) {
            print "  $item = ",( ${$webhashref}{$item} || 0 ),"\n";
            $count += ${$webhashref}{$item};
        }
        print "  WEB TOTAL = $count\n";
    }
}


sub _printMsg {
    my( $session, $msg ) = @_;

    if( $session->inContext('command_line') ) {
        $msg =~ s/&nbsp;/ /go;
    } else {
        if( $msg =~ s/^\!// ) {
            $msg = CGI::h4( CGI::span( { class=>'twikiAlert' }, $msg ));
        } elsif( $msg =~ /^[A-Z]/ ) {
            # SMELL: does not support internationalised script messages
            $msg =~ s/^([A-Z].*)/CGI::h3($1)/ge;
        } else {
            $msg =~ s/(\*\*\*.*)/CGI::span( { class=>'twikiAlert' }, $1 )/ge;
            $msg =~ s/^\s\s/&nbsp;&nbsp;/go;
            $msg =~ s/^\s/&nbsp;/go;
            $msg .= CGI::br();
        }
        $msg =~ s/==([A-Z]*)==/'=='.CGI::span( { class=>'twikiAlert' }, $1 ).'=='/ge;
    }
    print $msg,"\n";
}

1;
