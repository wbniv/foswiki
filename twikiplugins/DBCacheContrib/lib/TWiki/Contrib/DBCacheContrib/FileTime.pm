#
# Copyright (C) Motorola 2003 - All rights reserved
# Copyright (C) Crawford Currie 2004
#
use strict;

=begin text

---++ package TWiki::Contrib::DBCacheContrib::FileTime

Object that handles a file/time tuple for use in Storable and
=TWiki::Contrib::DBCacheContrib::Archive=.

=cut

package TWiki::Contrib::DBCacheContrib::FileTime;

=begin text

---+++ =new($file)=
   * =$file= - filename
Construct from a file name

=cut

sub new {
    my ( $class, $file ) = @_;
    my $this = bless( {}, $class );
    return $this unless ( $file ); # needed for read()
    $this->{file} = $file;
    my @sinfo = stat( $file );
    $this->{time} = $sinfo[9];
    return $this;
}

=begin text

---+++ =uptodate()= -> boolean
Check the file time against what is seen on disc. Return 1 if consistent, 0 if inconsistent.

=cut

sub uptodate {
    my $this = shift;
    my $file = $this->{file};
    if ( -r $file && defined( $this->{time} )) {
        my @sinfo = stat( $file );
        my $fileTime = $sinfo[9];
        if ( defined( $fileTime) && $fileTime == $this->{time} ) {
            return 1;
        }
    }
    return 0;
}

=begin text

---+++ =toString()= -> string
Generates a string representation of the object.

=cut

sub toString {
    my $this = shift;
    my $stime = localtime( $this->{time} );
    return $this->{file} . ":$stime"
}

=begin text

---+++ =write()=
TWiki::Contrib::DBCacheContrib::Archive hook

=cut

sub write {
    my ( $this, $archive ) = @_;

    $archive->writeString( $this->{file} );
    $archive->writeInt( $this->{time} );
}

=begin text

---+++ =read()=
TWiki::Contrib::DBCacheContrib::Archive hook

=cut

sub read {
    my ( $this, $archive ) = @_;

    $this->{file} = $archive->readString();
    $this->{time} = $archive->readInt();
}

1;
