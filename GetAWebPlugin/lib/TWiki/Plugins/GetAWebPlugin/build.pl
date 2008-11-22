#!/usr/bin/perl -w
BEGIN {
    unshift @INC, split( /:/, $ENV{TWIKI_LIBS} );
}
use TWiki::Contrib::Build;

# Create the build object
$build = new TWiki::Contrib::Build('GetAWebPlugin');

# (Optional) Set the details of the repository for uploads.
# This can be any web on any accessible TWiki installation.
# These defaults will be used when expanding tokens in .txt
# files, but be warned, they can be overridden at upload time!

# name of web to upload to
$build->{UPLOADTARGETWEB} = 'Extensions';
# Full URL of pub directory
$build->{UPLOADTARGETPUB} = 'http://foswiki.org/pub';
# Full URL of bin directory
$build->{UPLOADTARGETSCRIPT} = 'http://foswiki.org/bin';
# Script extension
$build->{UPLOADTARGETSUFFIX} = '';

# Build the target on the command line, or the default target
$build->build($build->{target});

