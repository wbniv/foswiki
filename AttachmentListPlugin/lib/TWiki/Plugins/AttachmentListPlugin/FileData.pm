# Plugin for TWiki Collaboration Platform, http://TWiki.org/
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

package TWiki::Plugins::AttachmentListPlugin::FileData;

use strict;
use overload ( '""' => \&as_string );

my %sortKeys = (
    '$fileDate'      => [ 'date',      'integer' ],
    '$fileSize'      => [ 'size',      'integer' ],
    '$fileUser'      => [ 'user',      'string' ],
    '$fileExtension' => [ 'extension', 'string' ],
    '$fileName'      => [ 'name',      'string' ],
    '$fileTopic'     => [ 'topic',     'string' ]
);

my $defaultPlaceholderNoExtension =
  'NONE';    # placeholder extension if file does not have an extension

=pod

=cut

sub new {
    my ( $class, $web, $topic, $attachment ) = @_;
    my $this = {};
    $this->{'topic'}      = $topic;
    $this->{'web'}        = $web;
    $this->{'attachment'} = $attachment;

    # only copy sort keys to FileData attributes
    $this->{'date'} = $attachment->{'date'} || 0;
    $this->{'size'} = $attachment->{'size'} || 0;

    my $userName = $attachment->{'user'} || 'UnknownUser';
    if ( $TWiki::Plugins::VERSION < 1.2 ) {
        $userName =~ s/^(.*?\.)*(.*?)$/$2/;    # remove Main. from username
    }
    else {
        $userName = TWiki::Func::getWikiName($userName);
    }
    $this->{'user'}      = $userName;
    $this->{'name'}      = $attachment->{'name'} || '';
    $this->{'extension'} = _getExtension( $this->{'attachment'}->{name} );
    my $hiddenAttr = $attachment->{'attr'} || '';
    $hiddenAttr =~ s/h/hidden/;
    $this->{'hidden'} = $hiddenAttr;

    bless $this, $class;
}

sub getSortKey {
    my ($inRawKey) = @_;
    return $sortKeys{$inRawKey}[0];
}

sub getCompareMode {
    my ($inRawKey) = @_;
    return $sortKeys{$inRawKey}[1];
}

=pod

Returns the file extension of a filename.

=cut

sub _getExtension {
    my ($fileName) = @_;

    my @nameParts = ( split( /\./, $fileName ) );
    my $extension = '';
    $extension = lc $nameParts[$#nameParts] if ( scalar @nameParts > 1 );
    $extension ||= lc $defaultPlaceholderNoExtension;
    return $extension;
}

sub as_string {
    my $self = shift;

    return
        "FileData: topic="
      . $self->{'topic'}
      . "; web="
      . $self->{'web'}
      . "; name="
      . $self->{name};
}
1;
