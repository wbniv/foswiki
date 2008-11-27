# See botton of file for license and copyright information

# Equivalent of RcsWrap and RcsLite for a subversion checkout area
package Foswiki::Store::Subversive;
use base 'Foswiki::Store::RcsFile';

use strict;
use Assert;

require File::Spec;

require Foswiki::Sandbox;

sub new {
    my ( $class, $session, $web, $topic, $attachment ) = @_;
    my $this = $class->SUPER::new($session, $web, $topic, $attachment);
    undef $this->{rcsFile};
    return $this;
}

sub init {
    my $this = shift;

    return unless $this->{topic};

    unless ( -e $this->{file} ) {
        _mkPathTo( $this, $this->{file} );

        unless ( open( F, '>' . $this->{file} ) ) {
            throw Error::Simple(
                'svn add of ' . $this->{file} . ' failed: ' . $! );
        }
        close(F);

        my ( $output, $exit ) =
          $Foswiki::sandbox->sysCommand(
              $Foswiki::cfg{SubversionContrib}{svnCommand}.
                ' add %FILENAME|F%', FILENAME => $this->{file} );
        if ($exit) {
            throw Error::Simple(
                'svn add of ' . $this->{file} . ' failed: ' . $output );
        }
    }
}

# Make any missing paths on the way to this file
sub _mkPathTo {
    my ( $this, $file ) = @_;

    my @components = split( /(\/+)/, $file );
    pop(@components);
    my $path = '';
    for my $dir (@components) {
        if ( $dir =~ /\/+/ ) {
            $path .= '/';
        }
        elsif ($path) {
            if ( !-e "$path$dir" && -e "$path/.svn" ) {
                my ( $output, $exit ) =
                  Foswiki::sandbox->sysCommand(
                      $Foswiki::cfg{SubversionContrib}{svnCommand}.
                        ' mkdir %FILENAME|F%', FILENAME => $path . $dir );
                if ($exit) {
                    throw Error::Simple( 'svn mkdir of ' 
                          . $path 
                          . $dir
                          . ' failed: '
                          . $output );
                }
            }
            $path .= $dir;
        }
    }
}

sub getRevisionInfo {
    my ($this, $version) = @_;
    my $info = Foswiki::sandbox->sysCommand(
        $Foswiki::cfg{SubversionContrib}{svnCommand}.
          ' info -r $version %FILENAME|F%',
        FILENAME => $this->{file} );
    my $changedAuthor = ($info =~ /^Last Changed Author: (.*)$/) ? $1 : '';
    my $changedDate = ($info =~ /^Last Changed Date: (.*)$/) ? $1 : '';
    my $rev = ($info =~ /^Revision: (.*)$/) ? $1 : '';
    $changedDate = Foswiki::Time::parseTime($changedDate);
    return (
        $rev,
        $changedDate,
        $this->{session}->{users}
          ->getCanonicalUserID( $changedAuthor ),
        '' );
}

=pod

---++ ObjectMethod getLatestRevision() -> $text

Get the text of the most recent revision

=cut

sub getLatestRevision {
    my $this = shift;
    return _readFile( $this, $this->{file} );
}

=pod

---++ ObjectMethod getLatestRevisionTime() -> $text

Get the time of the most recent revision

=cut

sub getLatestRevisionTime {
    my $this = shift;

    my ( $output, $exit ) =
      $Foswiki::sandbox->sysCommand(
          $Foswiki::cfg{SubversionContrib}{svnCommand}.
            ' info %FILE|F%', FILE => $this->{file} );
    if ($exit) {
        throw Error::Simple( 'Subversive: info failed: ' . $! );
    }
    my $changedDate = ($output =~ /^Last Changed Date: (.*)$/) ? $1 : '';
    $changedDate = Foswiki::Time::parseTime($changedDate);
    return $changedDate;
}

=pod

---++ ObjectMethod moveWeb(  $newWeb )

Move a web.

=cut

sub moveWeb {
    my ( $this, $newWeb ) = @_;
    _moveFile(
        $this,
        $Foswiki::cfg{DataDir} . '/' . $this->{web},
        $Foswiki::cfg{DataDir} . '/' . $newWeb
    );
    if ( -d $Foswiki::cfg{PubDir} . '/' . $this->{web} ) {
        _moveFile(
            $this,
            $Foswiki::cfg{PubDir} . '/' . $this->{web},
            $Foswiki::cfg{PubDir} . '/' . $newWeb
        );
    }
}

=pod

---++ ObjectMethod getRevision($version) -> $text

   * =$version= if 0 or undef, or out of range (version number > number of revs) will return the latest revision.

Get the text of the given revision.

Designed to be overridden by subclasses, which can call up to this method
if the main file revision is required.

=cut

sub getRevision {
    my ($this, $version) = @_;
die "NOT DONE YET";
    return _readFile( $this, $this->{file} );
}

=pod

---++ ObjectMethod restoreLatestRevision()

Restore the plaintext file from the revision at the head.

=cut

sub restoreLatestRevision {
    my ($this) = @_;

    my $rev  = $this->numRevisions();
    my $text = $this->getRevision($rev);

    return _saveFile( $this, $this->{file}, $text );
}

=pod

---++ ObjectMethod removeWeb( $web )

   * =$web= - web being removed

Destroy a web, utterly. Removed the data and attachments in the web.

Use with great care! No backup is taken!

=cut

sub removeWeb {
    my $this = shift;

    # Just make sure of the context
    ASSERT( !$this->{topic} ) if DEBUG;

    _rmtree( $this, $Foswiki::cfg{DataDir} . '/' . $this->{web} );
    _rmtree( $this, $Foswiki::cfg{PubDir} . '/' . $this->{web} );
}

=pod

---++ ObjectMethod moveTopic( $newWeb, $newTopic )

Move/rename a topic.

=cut

sub moveTopic {
    my ( $this, $newWeb, $newTopic ) = @_;

    my $oldWeb   = $this->{web};
    my $oldTopic = $this->{topic};

    # Move data file
    my $new =
      new Foswiki::Store::Subversive( $this->{session}, $newWeb, $newTopic, '' );
    _moveFile( $this, $this->{file}, $new->{file} );

    # Move attachments
    my $from = $Foswiki::cfg{PubDir} . '/' . $this->{web} . '/' . $this->{topic};
    if ( -e $from ) {
        my $to = $Foswiki::cfg{PubDir} . '/' . $newWeb . '/' . $newTopic;
        _moveFile( $this, $from, $to );
    }
}

=pod

---++ ObjectMethod copyTopic( $newWeb, $newTopic )

Copy a topic.

=cut

sub copyTopic {
    my ( $this, $newWeb, $newTopic ) = @_;

    my $oldWeb   = $this->{web};
    my $oldTopic = $this->{topic};

    my $new =
      new Foswiki::Store::Subversive( $this->{session}, $newWeb, $newTopic, '' );

    _copyFile( $this, $this->{file}, $new->{file} );

    if (
        opendir( DIR,
            $Foswiki::cfg{PubDir} . '/' . $this->{web} . '/' . $this->{topic}
        )
      )
    {
        for my $att ( grep { !/^\./ } readdir DIR ) {
            $att = Foswiki::Sandbox::untaintUnchecked($att);
            my $oldAtt =
              new Foswiki::Store::Subversive( $this->{session}, $this->{web},
                $this->{topic}, $att );
            $oldAtt->copyAttachment( $newWeb, $newTopic );
        }

        closedir DIR;
    }
}

sub moveAttachment {
    my ( $this, $newWeb, $newTopic, $newAttachment ) = @_;

    # FIXME might want to delete old directories if empty
    my $new =
      Foswiki::Store::Subversive->new( $this->{session}, $newWeb, $newTopic,
        $newAttachment );

    _moveFile( $this, $this->{file}, $new->{file} );
}

sub copyAttachment {
    my ( $this, $newWeb, $newTopic ) = @_;

    my $oldWeb     = $this->{web};
    my $oldTopic   = $this->{topic};
    my $attachment = $this->{attachment};

    my $new =
      Foswiki::Store::Subversive->new( $this->{session}, $newWeb, $newTopic,
        $attachment );

    _copyFile( $this, $this->{file}, $new->{file} );
}

sub _saveStream {
    my ( $this, $fh ) = @_;

    ASSERT($fh) if DEBUG;

    _mkPathTo( $this, $this->{file} );
    open( F, '>' . $this->{file} )
      || throw Error::Simple( 'RCS: open ' . $this->{file} . ' failed: ' . $! );
    binmode(F)
      || throw Error::Simple(
        'RCS: failed to binmode ' . $this->{file} . ': ' . $! );
    my $text;
    binmode(F);
    while ( read( $fh, $text, 1024 ) ) {
        print F $text;
    }
    close(F)
      || throw Error::Simple(
        'RCS: close ' . $this->{file} . ' failed: ' . $! );

    chmod( $Foswiki::cfg{RCS}{filePermission}, $this->{file} );

    return '';
}

sub _copyFile {
    my ( $this, $from, $to ) = @_;

    _mkPathTo( $this, $to );

    my ( $output, $exit ) = $Foswiki::sandbox->sysCommand(
        $Foswiki::cfg{SubversionContrib}{svnCommand}.' cp %FROM|F% %TO|F%',
        FROM => $from,
        TO   => $to
    );
    if ($exit) {
        throw Error::Simple(
            'Subversive: copy ' . $from . ' to ' . $to . ' failed: ' . $! );
    }
}

sub _moveFile {
    my ( $this, $from, $to ) = @_;

    _mkPathTo( $this, $to );
    my ( $output, $exit ) = $Foswiki::sandbox->sysCommand(
        $Foswiki::cfg{SubversionContrib}{svnCommand}.' mv %FROM|F% %TO|F%',
        FROM => $from,
        TO   => $to
    );
    if ($exit) {
        throw Error::Simple(
            'Subversive: move ' . $from . ' to ' . $to . ' failed: ' . $! );
    }
}

sub _saveFile {
    my ( $this, $name, $text ) = @_;

    _mkPathTo( $this, $name );

    open( FILE, '>' . $name )
      || throw Error::Simple(
        'RCS: failed to create file ' . $name . ': ' . $! );
    binmode(FILE)
      || throw Error::Simple( 'RCS: failed to binmode ' . $name . ': ' . $! );
    print FILE $text;
    close(FILE)
      || throw Error::Simple(
        'RCS: failed to create file ' . $name . ': ' . $! );

    return undef;
}

sub _readFile {
    my ( $this, $name ) = @_;
    my $data;
    if ( open( IN_FILE, '<' . $name ) ) {
        binmode(IN_FILE);
        local $/ = undef;
        $data = <IN_FILE>;
        close(IN_FILE);
    }
    $data ||= '';
    return $data;
}

sub _mkTmpFilename {
    my $tmpdir = File::Spec->tmpdir();
    my $file = _mktemp( 'twikiAttachmentXXXXXX', $tmpdir );
    return File::Spec->catfile( $tmpdir, $file );
}

# Adapted from CPAN - File::MkTemp
sub _mktemp {
    my ( $template, $dir, $ext, $keepgen, $lookup );
    my ( @template, @letters );

    ASSERT( @_ == 1 || @_ == 2 || @_ == 3 ) if DEBUG;

    ( $template, $dir, $ext ) = @_;
    @template = split //, $template;

    ASSERT( $template =~ /XXXXXX$/ ) if DEBUG;

    if ($dir) {
        ASSERT( -e $dir ) if DEBUG;
    }

    @letters =
      split( //, 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ' );

    $keepgen = 1;

    while ($keepgen) {
        for ( my $i = $#template ; $i >= 0 && ( $template[$i] eq 'X' ) ; $i-- )
        {
            $template[$i] = $letters[ int( rand 52 ) ];
        }

        undef $template;

        $template = pack 'a' x @template, @template;

        $template = $template . $ext if ($ext);

        if ($dir) {
            $lookup = File::Spec->catfile( $dir, $template );
            $keepgen = 0 unless ( -e $lookup );
        }
        else {
            $keepgen = 0;
        }

        next if $keepgen == 0;
    }

    return ($template);
}

sub _rmtree {
    my ( $this, $root ) = @_;

    my ( $output, $exit ) =
      $Foswiki::sandbox->sysCommand( $Foswiki::cfg{SubversionContrib}{svnCommand}.
                                     ' rm %FILENAME|F%', FILENAME => $root );
    if ($exit) {
        throw Error::Simple( 'svn rm of ' . $root . ' failed: ' . $output );
    }
}

sub addRevisionFromText {
    my ( $this, $text, $comment, $user, $date ) = @_;
    $this->init();

    _saveFile( $this, $this->{file}, $text );
}

sub addRevisionFromStream {
    my ( $this, $stream, $comment, $user, $date ) = @_;
    $this->init();

    _saveStream( $this, $stream );
}

sub replaceRevision {
    throw Error::Simple("Not implemented");
}

sub deleteRevision {
    throw Error::Simple("Not implemented");
}

# SMELL: this just returns the subversion revision, not the true number of
# revisions (which is only available from svn log)
sub numRevisions {
    my $this = shift;

    my ( $output, $exit ) =
      $Foswiki::sandbox->sysCommand(
          $Foswiki::cfg{SubversionContrib}{svnCommand}.
            ' info %FILE|F%', FILE => $this->{file} );
    if ($exit) {
        throw Error::Simple( 'Subversive: info failed: ' . $! );
    }
    $output =~ /^Revision: (\d+)$/m;
    return $1 || 1;
}

sub revisionDiff {
    my ( $this, $rev1, $rev2, $contextLines ) = @_;
    my $nr = $this->numRevisions();

    $rev1 = 1         if ( $rev1 < 1 );
    $rev1 = 'WORKING' if ( $rev1 > $nr );
    $rev2 = 1         if ( $rev2 < 1 );
    $rev2 = 'WORKING' if ( $rev2 > $nr );
    my $ft = "$rev1:$rev2";
    $ft = $rev2 if ( $rev1 eq 'WORKING' );
    $ft = $rev1 if ( $rev2 eq 'WORKING' );

    if ( $rev1 == $rev2 || $ft eq 'WORKING' ) {
        return [];
    }

    my ( $output, $exit ) = $Foswiki::sandbox->sysCommand(
        $Foswiki::cfg{SubversionContrib}{svnCommand}.
          ' diff -r%FT|U% --non-interactive %FILE|F%',
        FT   => $ft,
        FILE => $this->{file}
    );
    if ($exit) {
        throw Error::Simple( 'Subversive: diff failed: ' . $! );
    }
    $output =~ s/\nProperty changes on:.*$//s;
    require Foswiki::Store::RcsWrap;
    return Foswiki::Store::RcsWrap::parseRevisionDiff( "---\n" . $output );
}

sub getRevisionAtTime {
    my ($this, $date) = @_;
    throw Error::Simple("Not implemented");
    my $info = Foswiki::sandbox->sysCommand(
        $Foswiki::cfg{SubversionContrib}{svnCommand}.
          ' info -r {%DATE|U%} %FILENAME|F%',
        DATE => Foswiki::FormatTime($date, '$http'),
        FILENAME => $this->{file} );
    my $rev = ($info =~ /^Revision: (.*)$/) ? $1 : 0;
    return $rev;
}

1;
__END__
# Copyright (C) 2008 Foswiki Contributors
# Copyright (C) 2005-2007 TWiki Contributors.
# Foswiki Contributors are listed in the AUTHORS file in the root of
# this distribution. NOTE: Please extend that file, not this notice.
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
#
# Author: Crawford Currie http://c-dot.co.uk
