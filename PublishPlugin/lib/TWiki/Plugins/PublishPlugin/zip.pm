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
package Foswiki::Plugins::PublishPlugin::zip;

use strict;

use Foswiki::Func;
use File::Path;

sub new {
    my( $class, $path, $web ) = @_;
    my $this = bless( {}, $class );
    $this->{path} = $path;
    $this->{web} = $web;

    eval "use Archive::Zip qw( :ERROR_CODES :CONSTANTS )";
    die $@ if $@;
    $this->{zip} = Archive::Zip->new();

    return $this;
}

sub addDirectory {
    my( $this, $dir ) = @_;
    $this->{logger}->logError("Error adding $dir") unless
      $this->{zip}->addDirectory( $dir );
}

sub addString {
    my( $this, $string, $file ) = @_;
    $this->{logger}->logError("Error adding $string") unless
      $this->{zip}->addString( $string, $file );
}

sub addFile {
    my( $this, $from, $to ) = @_;
    $this->{logger}->logError("Error adding $from") unless
      $this->{zip}->addFile( $from, $to );
}

sub close {
    my $this = shift;
    my $dir = $this->{path};
    if ($this->{web} =~ m!^(.*)/.*?$!) {
        $dir .= $1;
    }
    eval { File::Path::mkpath($dir) };
    $this->{logger}->logError($@) if $@;
    my $landed = "$this->{web}.zip";
    $this->{logger}->logError("Error writing $landed") if
      $this->{zip}->writeToFileNamed( "$this->{path}$landed" );
    return $landed;
}

1;
