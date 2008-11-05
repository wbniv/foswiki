#!/usr/bin/perl -w
#
# Copyright (C) 2007 Markus Hesse
#
# For licensing info read LICENSE file in the TWiki root.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at 
# http://www.gnu.org/copyleft/gpl.html
# Set library paths in @INC, at compile time

package TWiki::Contrib::SearchEngineKinoSearchAddOn::KinoSearch;

use TWiki;
use TWiki::Func;
use Error qw( :try );
use Time::Local;
use IO::File;

use KinoSearch::InvIndexer;
use KinoSearch::Analysis::PolyAnalyzer;

#use TWiki::Contrib::SearchEngineKinoSearchAddOn::Stringifier;
use strict;

# Create a new instance of self.
# parameter: Type may be "index", "update" or "search"
# QS
sub new {
    my $handler = shift;
    my $type    = shift;
    my $self = bless {}, $handler;

    $self->{Session} = $TWiki::Plugins::SESSION;

    if (!($type eq "search") ) {$self->{Log} = $self->openLog($type)};
    $self->{Debug}   = $self->debugPref();

    $self
}

sub openLog {
    my ($self, $type) = (@_);

    my $LOGFILE = new IO::File;
    my $fileName = $self->logFileName($type);

    $LOGFILE->open(">>$fileName") || die "Logfile cannot be opend in $fileName.";

    $LOGFILE;
}

sub log {
    my ($self, $logString, $force) = (@_);
 
    if ($self->{Debug} || $force || 0) {
	my $logtime = TWiki::Func::formatTime( time(), '$rcs', 'servertime' ); 
	$self->{Log}->print( "| $logtime | $logString\n");

	print STDERR "$logString\n";
    }
}

# Yields the directory, I want to do logs
# I take $TWiki::cfg{KinoSearchLogDir} or if not given 
# TWiki::Func::getPubDir()/../kinosearch/logs
# QS
sub logDirName {
    my $log = $TWiki::cfg{KinoSearchLogDir};

    if (!$log) {
	$log = TWiki::Func::getPubDir();
	$log .="/../kinosearch/logs";
    }

    return $log;
}

sub logFileName {
    my ($self, $prefix) = (@_);
    my $logdir = logDirName();
    my $time = TWiki::Func::formatTime( time(), '$year$mo$day', 'servertime');

    return "$logdir/$prefix-$time.log";
}


# Path where the index is stored
# QS
sub indexPath {
    my $idx = $TWiki::cfg{KinoSearchIndexDir};

    if (!$idx) {
	$idx = TWiki::Func::getPubDir();
	$idx .="/../kinosearch/index";
    }

    return $idx;
}

# Path where the attachments are stored.
# QS
sub pubPath {
    return TWiki::Func::getPubDir(); 
}

# List of webs that shall not be indexed
# QS
sub skipWebs {
    #TODO: the defaults should not be here in code
    #the settings should be added to the Config.spec file.
    my $to_skip = TWiki::Func::getPreferencesValue( "KINOSEARCHINDEXSKIPWEBS" ) || "Trash, Sandbox";
    my %skipwebs;

    foreach my $tmpweb ( split( /\,\s+|\,|\s+/, $to_skip ) ) {
	$skipwebs{$tmpweb} = 1;
    }
    return %skipwebs;
}

# List of attachments to be skipped.
# QS
sub skipAttachments {
    my $to_skip = TWiki::Func::getPreferencesValue( "KINOSEARCHINDEXSKIPATTACHMENTS" ) || "";
    my %skipattachments;

    foreach my $tmpattachment ( split( /\,\s+/, $to_skip ) ) {
	$skipattachments{$tmpattachment} = 1;
    }
    
    return %skipattachments;
}

# List of file extensions to be indexed
# QS
sub indexExtensions {
    my $extensions = TWiki::Func::getPreferencesValue( "KINOSEARCHINDEXEXTENSIONS" ) || ".pdf, .doc, .xml, .html, .txt, .xls, .ppt";
    my %indexextensions;

    foreach my $tmpextension ( split( /\,\s+/, $extensions ) ) {
	$indexextensions{$tmpextension} = 1;
    }

    return %indexextensions;
}

# Variables to be indexed.
# Obsolet?
sub indexeVariables {
    return TWiki::Func::getPreferencesValue( "KINOSEARCHINDEXVARIABLES" );
}

# QS
sub analyserLanguage {
    return TWiki::Func::getPreferencesValue( "KINOSEARCHANALYSERLANGUAGE") || 'en';
}

sub summaryLength {
    return TWiki::Func::getPreferencesValue( "KINOSEARCHSUMMARYLENGTH") || 300;
}

# Returns, if debug statements etc shall be shown
# QS
sub debugPref {
    return TWiki::Func::getPreferencesValue( "KINOSEARCHDEBUG" ) || 0;
}

# Returns an analyser
# QS
sub analyser {
    my ($self, $language) = @_;

    return KinoSearch::Analysis::PolyAnalyzer->new( language => $language);
}

1;
