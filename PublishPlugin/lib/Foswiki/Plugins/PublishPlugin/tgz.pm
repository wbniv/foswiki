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
# Archive::Zip writer module for PublishPlugin
#
use strict;

package Foswiki::Plugins::PublishPlugin::tgz;

use Foswiki::Func;
use File::Path;

sub new {
    my( $class, $path, $web ) = @_;
    my $this = bless( {}, $class );
    $this->{path} = $path;
    $this->{web} = $web;

    eval "use Archive::Tar";
    die $@ if $@;
    $this->{tar} = Archive::Tar->new();

    return $this;
}

sub addDirectory {
    # Not needed
}

sub addString {
    my( $this, $string, $file ) = @_;
    unless ($this->{tar}->add_data( $file, $string )) {
        $this->{logger}->logError($this->{tar}->error());
    }
}

sub addFile {
    my( $this, $from, $to ) = @_;
    local $/ = undef;
    if (open(R, "<$from")) {
        $this->addString( <R>, $to );
        close(R);
    } else {
        $this->{logger}->logError("Failed to open $from: $!");
    }
}

sub close {
    my $this = shift;
    my $dir = $this->{path};
    if ($this->{web} =~ m!^(.*)/.*?$!) {
        $dir .= $1;
    }
    eval { File::Path::mkpath($dir) };
    $this->{logger}->logError($@) if $@;
    my $landed = "$this->{web}.tgz";
    unless ($this->{tar}->write( "$this->{path}$landed", 1 )) {
        $this->{logger}->logError($this->{tar}->error())
    };
    return $landed;
}

1;
