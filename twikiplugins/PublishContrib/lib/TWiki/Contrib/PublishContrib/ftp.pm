# Copyright (C) 2005 Crawford Currie, http://c-dot.co.uk
# Copyright (C) 2006 Martin Cleaver, http://www.cleaver.org
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
# driver for writing html output to and ftp server, for hosting purposes
# adds sitemap.xml, google site verification file, and alias from index.html to WebHome.html (or other user specified default

use strict;

package TWiki::Contrib::PublishContrib::ftp;
use base 'TWiki::Contrib::PublishContrib::file';

sub new {
    my( $class, $path, $web, $genopt, $logger, $query ) = @_;
    my $this = $class->SUPER::new($path, $web, $genopt, $logger);
    
    foreach my $param qw(defaultpage googlefile destinationftpserver destinationftppath destinationftpusername destinationftppassword fastupload relativeurl) {
        $this->{$param} = $query->param($param);
        $query->delete($param);
    }

    if ($this->{destinationftpserver}) {
        die "destinationftppath param not defined"
          unless (defined($this->{destinationftppath}));
        die "destinationftpusername param not defined"
          unless (defined($this->{destinationftpusername}));
        die "destinationftppassword param not defined"
          unless (defined($this->{destinationftppassword}));
    }
    return $this;
}

sub addString {
    my( $this, $string, $file) = @_;
    filterHtml(\$string) if( $file =~ /\.html$/ );
    $this->SUPER::addString( $string, $file );
    push( @{$this->{remotefiles}}, "$file" );

    if( $file =~ /(.*)\.html?$/ ) {
        my $topic = $1;
        push( @{$this->{urls}}, "$file" );
        #write link from index.html to actual topic
        if ($this->{defaultpage} &&
              $topic eq $this->{defaultpage}) {
            $this->addString( $string, 'default.htm' );
            $this->addString( $string, 'index.html' );
            print '(default.htm, index.html)';
        }
    }
}

sub addFile {
    my( $this, $from, $to ) = @_;
    $this->SUPER::addFile( $from, $to );
    push( @{$this->{remotefiles}}, "$to" );
}

sub close {
    my $this = shift;

    #write sitemap.xml
    my $sitemap = $this->createSitemap( \@{$this->{urls}} );
    $this->addString($sitemap, 'sitemap.xml');
    print 'Published sitemap.xml<br />';
    #write google verification files (comma seperated list)
    if ($this->{googlefile}) {
        my @files = split(/[,\s]+/, $this->{googlefile});
        for my $file (@files) {
            my $simplehtml = '<html><title>'.$file.'</title><body>just for google</body></html>';
            $this->addString($simplehtml, $file);
            print 'Published googlefile : '.$file.'<br />';
        }
    }

    my $landed = $this->SUPER::close();

    # use LWP to ftp to server
    # TODO: clean up ftp site, removing/archiving/backing up old version
    if ($this->{destinationftpserver}) {
        $landed = $this->{destinationftpserver};

        #well, i'd love to use LWP, but it tells me "400 Library does not
        #allow method POST for 'ftp:' URLs"

        require Net::FTP;
        my $ftp = Net::FTP->new($this->{destinationftpserver},
                                Debug => 0)
          or die "Cannot connect to $this->{destinationftpserver}: $@";

        $ftp->login($this->{destinationftpusername}, $this->{destinationftppassword})
          or die "Cannot login ", $ftp->message;
        $ftp->binary();

        my $destinationftppath = $this->{destinationftppath};
        if ( $destinationftppath =~ /^\/?(.*)$/ ) {
            $destinationftppath = $1;
        }
        if ( $destinationftppath ne '') {
            $ftp->mkdir($destinationftppath, 1);
            $ftp->cwd($destinationftppath)
              or die "Cannot change working directory ", $ftp->message;
        }

        my $fastUpload = $this->{fastupload} || 0;
        print "fastUpload = $fastUpload <br />";
        for my $remoteFilename (@{$this->{remotefiles}}) {
            my $localfilePath = "$this->{path}/$this->{web}/$remoteFilename";
            if ( $remoteFilename =~ /^\/?(.*\/)([^\/]*)$/ ) {
                $ftp->mkdir($1, 1)
                  or die "Cannot create directory ", $ftp->message;
            }
            #TODO: this is a really crap way to reduce upload times
            #remote time and local times don't match, will have to base it on twiki revisions and sending a manifest
            #for eg, add username, topic mod date and rev to sitemap, and download and compare
            #and similar for big files - ie attachments.
            my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
                $atime,$mtime,$ctime,$blksize,$blocks)
              = stat($localfilePath);
            my $remoteSize = $ftp->size($remoteFilename);
            my $remoteMTime = $ftp->mdtm($remoteFilename);
            #print "($remoteMTime eq $mtime) && ($remoteSize eq $size) ";
            if (($fastUpload eq 1) && ($remoteSize eq $size) && (!( $remoteFilename =~ /(.*)\.html?$/ ))) {
                #file's already there
                print "<b>skipped</b> uploading $remoteFilename to $this->{destinationftpserver} <br />";
            } else {
                $ftp->put($localfilePath, $remoteFilename)
                  or die "put failed ", $ftp->message;
                print "<b>FTPed</b> $remoteFilename to $this->{destinationftpserver} <br />";
            }
        }

        $ftp->quit;
    }

    return $landed;
}

#===============================================================================
sub filterHtml {
    my $string = shift;
    #this is dangerous as heck - it'll remove 'protected script and css' happily
    #$$string =~ s/<!--.*?-->//gs;     # remove all HTML comments
}

sub createSitemap {
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

