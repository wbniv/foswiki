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
    my( $class, $path, $web, $genopt, $logger, $query ) = @_;
    my $this = bless( {}, $class );
    $this->{path} = $path;
    $this->{web} = $web;
    $this->{genopt} = $genopt;
    $this->{logger} = $logger;

    foreach my $param qw(defaultpage googlefile relativeurl) {
        my $p = $query->param($param);
        $p =~ /^(.*)$/;
        $this->{$param} = $1;
        $query->delete($param);
    }

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

    if( $file =~ /(.*)\.html?$/ ) {
        my $topic = $1;
        push( @{$this->{urls}}, "$file" );
        # write link from index.html to actual topic
        if ($this->{defaultpage} && $topic eq $this->{defaultpage}) {
            $this->addString( $string, 'default.htm' );
            $this->addString( $string, 'index.html' );
            print '(default.htm, index.html)';
        }
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

    # write sitemap.xml
    my $sitemap = $this->_createSitemap( \@{$this->{urls}} );
    $this->addString($sitemap, 'sitemap.xml');
    print 'Published sitemap.xml<br />';

    # write google verification files (comma seperated list)
    if ($this->{googlefile}) {
        my @files = split(/[,\s]+/, $this->{googlefile});
        for my $file (@files) {
            my $simplehtml = '<html><title>'.$file
              .'</title><body>just for google</body></html>';
            $this->addString($simplehtml, $file);
            print 'Published googlefile : '.$file.'<br />';
        }
    }

    return $this->{web};
}

sub _createSitemap {
    my $this = shift;
    my $filesRef = shift;    #( \@{$this->{files}} )
    my $map = << 'HERE';
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.google.com/schemas/sitemap/0.84">
%URLS%
</urlset>
HERE

    my $topicTemplatePre = "<url>\n<loc>";
    my $topicTemplatePost = "</loc>\n</url>";

    die "relativeurl param not defined" unless (defined($this->{relativeurl}));

    my $urls = join("\n",
        map {
            "$topicTemplatePre$this->{relativeurl}".
              "$_$topicTemplatePost\n"
          }  @$filesRef );

    $map =~ s/%URLS%/$urls/;

    return $map;
}

1;

