# Copyright (C) Meredith Lesly 2006
# Some routines that will be added to TWiki::Func in the future
#
# Please note that the implementation of most of the functions are 
# Dakar specific. Using the routines should be safe; just don't
# rely on the specific implementation details
#

=pod


---+!! !MoreFuncContrib

This contrib contains basic functionality needed by many plugins that is not
included in Dakar's TWiki::Func. Some or all of these will probably be merged
into the TWiki::Func at some point.

%TOC%

=cut

use strict;

package TWiki::Contrib::MoreFuncContrib;
use TWiki::Meta;
use TWiki::Func;
use TWiki::Plugins;

use vars qw( $VERSION );
$VERSION = '1.000';

=pod

---++ Webs, Topics, and Attachments

=cut

=pod

---+++ readTopicMeta($web, $topic, $rev) -> $metadata

Returns the metadata for a topic. 

=cut

#
# SMELL: This should be rewritten to use an Store subroutine.
#
sub readTopicMeta {
    my( $web, $topic, $rev ) = @_;

    my ($meta, $text) =  $TWiki::Plugins::SESSION->{store}->readTopic( undef, @_ );
    return $meta;
}

=pod

---+++ getTopicPreferenceValue($web, $topic, $prefName) -> $pref

Returns the value of a topic's preference.

=cut

sub getTopicPreferenceValue {
    my ($web, $topic, $prefName) = @_;

    my $meta = readTopicMeta($web, $topic);
    my $prefHash = $meta->get('PREFERENCE', $prefName);

    return $prefHash->{value} if $prefHash;
    return 0;
}

=pod

---+++ getChildWebs($web) -> $listOfWebs

Returns a list of a web's child webs

=cut

sub getChildWebs {
    my $web = shift;
    my @kids =  $TWiki::Plugins::SESSION->{store}->_getSubWebs($web);
    my $kidlist = join(',', @kids);
    $kidlist =~ s#.*/##;
    return split(',', $kidlist);
}

=pod

---++ Plugin-specific file handling

=cut

=pod

---+++ readWorkFile($pluginName, $fileName) -> $data

Returns the contents of a file in a particular plugin's work area

=cut

sub readWorkFile {
    my ($pluginName, $fileName) = @_;
    my $workArea = TWiki::Func::getWorkArea($pluginName);
    return readFile("$workArea/$fileName") if $workArea and ( -r "$workArea/$fileName");
    return 0;
}

=pod

---+++ saveWorkFile($pluginName, $fileName, $data)

Saves $data to a file in a plugin's work area

=cut

sub saveWorkFile {
    my ($pluginName, $fileName, $data) = @_;
    my $workArea = TWiki::Func::getWorkArea($pluginName);
    return saveFile("$workArea/$fileName", $data) if $workArea and ( -w "$workArea/$fileName");
    return 0;
}

=pod

---+++ deleteWorkFile($pluginName, $fileName)

Delete a file in a plugin's work area

=cut

sub deleteWorkFile {
    my ($pluginName, $fileName) = @_;
    my $workArea = TWiki::Func::getWorkArea($pluginName);
    return unlink("$workArea/$fileName") if $workArea and ( -w "$workArea/$fileName");
    return 0;
}

=pod

---++ General Utilities

=cut

=pod

---+++ getSearchObj($session) -> searchObj

=cut

sub getSearchObj {
    my $session = shift;
    die "no session`" unless $session;
    return $session->{search};
}

=pod

---+++ buildMimeHash($session) -> $hash

Return a mapping of extention to mime type

=cut

sub buildMimeHash {
    my $data = TWiki::readFile($TWiki::cfg{MimeTypesFileName});
    my $res;

    foreach my $line (split(/\n/, $data)) {
        if ($line =~ m#^\s+(\S+)\s+([a-z0-9\s]+)$#) {
            my $type = $1;
            my @suffixes = split(/\s/, $2);
            foreach my $suffix (@suffixes) {
                $res->{$suffix} = $type;
            }
        }
    }
    return $res;
}

=pod

----+++ suffixToMimeType ( $session, $theFilename ) -> $mimetype

Returns the mime type of a file based on its suffix

=cut

sub suffixToMimeType {
    my( $session, $theFilename ) = @_;

    my $mimeType = 'text/plain';
    if( $theFilename =~ /\.([^.]+)$/ ) {
        my $suffix = $1;
        my $mimeHash = buildMimeHash();
        return $mimeHash->{$suffix};
    }
    return $mimeType;
}

=pod

'Web*, FooBar' ==> ( 'Web*', 'FooBar' ) ==> ( 'Web.*', "FooBar" )

=cut

sub makeTopicPattern {
    my( $pattern ) = @_ ;
    return '' unless( $pattern );
    # 'Web*, FooBar' ==> ( 'Web*', 'FooBar' ) ==> ( 'Web.*', "FooBar" )
    $pattern =~ tr/ //d;
    my @arr = map { s/[^\*\_$TWiki::regex{mixedAlphaNum}]//go; s/\*/\.\*/go; $_ }
        split( ',', $pattern );
    return '' unless( @arr );
    # ( 'Web.*', 'FooBar' ) ==> "^(Web.*|FooBar)$"
    return '^(' . join( '|', @arr ) . ')$';
}



1;
