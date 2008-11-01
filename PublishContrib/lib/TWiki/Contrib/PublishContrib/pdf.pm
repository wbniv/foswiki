#
# Copyright (C) 2005 Crawford Currie, http://c-dot.co.uk
#
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
#
# PDF writer module for PublishContrib
#

use strict;

package TWiki::Contrib::PublishContrib::pdf;
use base 'TWiki::Contrib::PublishContrib::file';

use File::Path;

sub new {
    my( $class, $path, $web, $genopt, $logger, $query ) = @_;
    return $class->SUPER::new( $path, "${web}_$$", $genopt, $logger, $query );
}

sub close {
    my $this = shift;
    my $dir = $this->{path};
    if ($this->{web} =~ m!^(.*)/.*?$!) {
        $dir .= $1;
    }
    eval { File::Path::mkpath($dir) };
    die $@ if ($@);

    my @files = map { "$this->{path}/$_" }
      grep { /\.html$/ } @{$this->{files}};

    my $cmd = $TWiki::cfg{PublishContrib}{PDFCmd};
    die "{PublishContrib}{PDFCmd} not defined" unless $cmd;

    my $landed = "$this->{web}.pdf";
    my @extras = split( /\s+/, $this->{genopt} );

    $ENV{HTMLDOC_DEBUG} = 1; # see man htmldoc - goes to apache err log
    $ENV{HTMLDOC_NOCGI} = 1; # see man htmldoc
    my $sb;
    if (defined $TWiki::sandbox) {
        $sb = $TWiki::sandbox
    } else {
        $sb = $TWiki::Plugins::SESSION->{sandbox};
    }
    die "Could not find sandbox" unless $sb;
	$sb->{TRACE} = 1;
    my( $data, $exit ) =
      $sb->sysCommand(
          $cmd,
          FILE => "$this->{path}$landed",
          FILES => \@files,
          EXTRAS => \@extras );
    # htmldoc failsa lot, so log rather than dying
    $this->{logger}->logError("htmldoc failed: $exit/$data/$@") if $exit;

    # Get rid of the temporaries
    unlink(@{$this->{files}});

    return $landed;
}

1;
