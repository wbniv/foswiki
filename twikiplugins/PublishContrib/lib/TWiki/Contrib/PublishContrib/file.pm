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
# File writer module for PublishContrib
#
use strict;

package TWiki::Contrib::PublishContrib::file;

use File::Copy;
use File::Path;

sub new {
    my( $class, $path, $web, $genopt, $logger ) = @_;
    my $this = bless( {}, $class );
    $this->{path} = $path;
    $this->{web} = $web;
    $this->{genopt} = $genopt;
    $this->{logger} = $logger;

    File::Path::mkpath("$this->{path}/$web");

    return $this;
}

sub addDirectory {
    my( $this, $name ) = @_;
    my $d = "$this->{web}/$name";
    eval { File::Path::mkpath("$this->{path}/$d") };
    $this->{logger}->logError($@) if $@;
    push( @{$this->{dirs}}, $d );
}

sub addString {
    my( $this, $string, $file) = @_;
    my $f = "$this->{web}/$file";
    if (open(F, ">$this->{path}/$f")) {
        print F $string;
        close(F);
        push( @{$this->{files}}, $f );
    } else {
        $this->{logger}->logError("Cannot write $f: $!");
    }
}

sub addFile {
    my( $this, $from, $to ) = @_;
    my $f = "$this->{web}/$to";
    my $dest = "$this->{path}/$f";
    eval { File::Copy::copy( $from, $dest ); };
    $this->{logger}->logError($@) if $@;
    my @stat = stat( $from );
    $this->{logger}->logError("Unable to stat $from") unless @stat;
    utime( @stat[8,9], $dest );
    push( @{$this->{files}}, $f );
}

sub close {
    my $this = shift;
    # Generate sitemap.html
    my $links = join("<br />\n",
        map { "<a href='$_'>$_</a>" }  @{$this->{files}} );
    return $this->{web};
}

1;

