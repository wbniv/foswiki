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
# adds sitemap.xml, google site verification file, and alias from
# index.html to WebHome.html (or other user specified default).
# I'd love to use LWP, but it tells me "400 Library does not
# allow method POST for 'ftp:' URLs"
# TODO: clean up ftp site, removing/archiving/backing up old version

package TWiki::Contrib::PublishContrib::ftp;
use base 'TWiki::Contrib::PublishContrib::file';

use strict;

use File::Temp qw(:seekable);
use File::Spec;

sub new {
    my( $class, $path, $web, $genopt, $logger, $query ) = @_;
    my $this = $class->SUPER::new($path, $web, $genopt, $logger, $query);

    foreach my $param qw(destinationftpserver
                         destinationftppath destinationftpusername
                         destinationftppassword fastupload) {
        my $p = $query->param($param);
        $p =~ /^(.*)$/;
        $this->{$param} = $1;
        $query->delete($param);
    }

    $this->{fastupload} ||= 0;
    die "destinationftppath param not defined"
      unless (defined($this->{destinationftppath}));
    die "destinationftpusername param not defined"
      unless (defined($this->{destinationftpusername}));
    if ($this->{destinationftpserver}) {
        die "destinationftppassword param not defined"
          unless (defined($this->{destinationftppassword}));
        if ($this->{destinationftppath} =~ /^\/?(.*)$/) {
            $this->{destinationftppath} = $1;
        }
        print "fastUpload = $this->{fastupload}<br />";
    }

    return $this;
}

sub addString {
    my( $this, $string, $file) = @_;

    $this->SUPER::addString( $string, $file );
    $this->_upload($file);
}

sub addFile {
    my( $this, $from, $to ) = @_;
    $this->SUPER::addFile( $from, $to );

    $this->_upload($to);
}

sub _upload {
    my ($this, $to) = @_;

    return unless ($this->{destinationftpserver});

    my $localfilePath = "$this->{path}/$this->{web}/$to";

    my $attempts = 0;
    my $ftp;
    while ($attempts < 2) {
        eval {
            $ftp = $this->_ftpConnect();
            if ($to =~ /^\/?(.*\/)([^\/]*)$/) {
                $ftp->mkdir($1, 1)
                  or die "Cannot create directory ", $ftp->message;
            }

            if ($this->{fastupload}) {
                # Calculate checksum for local file
                open(F, "<", $localfilePath)
                  or die "Failed to open $localfilePath for checksum computation: $!";
                local $/;
                my $data = <F>;
                close(F);
                my $localCS = Digest::MD5::md5($data);

                # Get checksum for remote file
                my $remoteCS = '';
                my $tmpFile = new File::Temp(DIR => File::Spec->tmpdir(), UNLINK => 1);
                if ($ftp->get("$to.md5", $tmpFile)) {
                    # SEEK_SET to pos 0
                    $tmpFile->seek(0, 0);
                    $remoteCS = <$tmpFile>;
                }

                if ($localCS eq $remoteCS) {
                    # Unchanged
                    print "skipped uploading $to to $this->{destinationftpserver} (no changes) <br />";
                    $attempts = 2;
                    return;
                } else {
                    open(F, ">", "$localfilePath.md5")
                      or die "Failed to open $localfilePath.md5 for write: $!";
                    print F $localCS;
                    close(F);

                    $ftp->put("$localfilePath.md5", "$to.md5")
                      or die "put failed ", $ftp->message;
                }
            }

            $ftp->put($localfilePath, $to)
              or die "put failed ", $ftp->message;
            print "<b>FTPed</b> $to to $this->{destinationftpserver} <br />";
            $attempts = 2;
        };

        if ($@) {
            # Got an error; try restarting the session a couple of times
            # before giving up
            print "<font color='red'>FTP ERROR: ".$@."</font><br>";
            if (++$attempts == 2) {
                print "<font color='red'>Giving up on $to</font><br>\n";
                return;
            }
            print "...retrying in 30s<br>\n";
            eval {
                $ftp->quit();
            };
            $this->{ftp_interface} = undef;
            sleep(30);
        };
    }
}

sub _ftpConnect {
    my $this = shift;

    if (!$this->{ftp_interface}) {
        require Net::FTP;
        my $ftp =
          Net::FTP->new($this->{destinationftpserver},
                        Debug => 1, Timeout => 30, Passive => 1)
              or die "Cannot connect to $this->{destinationftpserver}: $@";
        $ftp->login($this->{destinationftpusername},
                    $this->{destinationftppassword})
          or die "Cannot login ", $ftp->message;

        $ftp->binary();

        if ( $this->{destinationftppath} ne '') {
            $ftp->mkdir($this->{destinationftppath}, 1);
            $ftp->cwd($this->{destinationftppath})
              or die "Cannot change working directory ", $ftp->message;
        }
        $this->{ftp_interface} = $ftp;
    }
    return $this->{ftp_interface};
}

sub close {
    my $this = shift;

    my $landed = $this->SUPER::close();

    if ($this->{destinationftpserver}) {
        $landed = $this->{destinationftpserver};
        $this->{ftp_interface}->quit() if $this->{ftp_interface};
        $this->{ftp_interface} = undef;
    }

    return $landed;
}

1;

