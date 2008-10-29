#
# Copyright (C) 2004 C-Dot Consultants - All rights reserved
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
package TWiki::Contrib::BuildContrib::BaseBuild;

use strict;

=begin twiki

---++ Package TWiki::Contrib::BuildContrib::BaseBuild

This is a class used to provide all the services required for
Build implementations.

---+++ Methods


=cut

my $NL = "\n";

=begin twiki

---++++ readManifest($baseDir,$path,$file,$manifest,$noManifestFileHook) => \@files

Reads the specified manifest file. The parameters are:
  * $baseDir: The root dir as assumed by the manifest file
  * $path: path to be added to $file, if present
  * $file: The absolute path to the manifest file
  * $noManifestFileHook (optional): A pointer to a sub to be called if
    the manifest file is not found

The manifest file consists of a list of file paths, each relative to the
root of the installation. Wildcards may NOT be used. Each file has an
optional octal permissions mask and a description; for example,
<verbatim>
data/TWiki/MyPlugin.txt 0664 Plugin description topic
</verbatim>
If no permissions are given, permissions are guessed from the permissions
on the file in the source tree.

This sub returns a reference to a list of hashes with the information of
each file. Each hash has the following information:
   * name: Path of the file
   * description: (optional) Description of the file
   * permissions: (optional) Permission of the file

=cut

sub readManifest {

    # TODO: Support for wildcards?
    my ( $baseDir, $path, $file, $noManifestFileHook ) = @_;
    $file ||= '';
    $file = $path . $file if $path;
print STDERR "---- $baseDir, $path, $file\n";

    unless ( $file && open( PF, '<' . $file ) ) {
        print STDERR 'COULD NOT OPEN MANIFEST FILE ', $file, $NL;
        &$noManifestFileHook()
          if defined($noManifestFileHook)
        ;    #CodeSmell - calling package sub not object method
        return undef;
    }
    my @files;
    my @otherModules;
    my $line;
    while ( $line = <PF> ) {
        next if $line =~ /^\s*#/;
        if ( $line =~ /^!include\s+(\S+)\s*$/ ) {
            push( @otherModules, $1 );
        }
        elsif ( $line =~ /^(".*"|\S+)\s+(0?\d\d\d)?\s*(\S.*)?\s*$/o ) {
            my $name = $1;
            $name =~ s/^"(.*)"$/$1/;
            my $permissions = $2;
            my $desc        = $3;
            unless ($permissions) {

                # No permissions in MANIFEST, apply defaults
                if ( $name =~ /\.pm$/ ) {
                    $permissions = '0444';
                }
                elsif ( $name =~ /\.pl$/ ) {
                    $permissions = '0554';
                }
                elsif ($name =~ /^data\/.*\.txt$/
                    || $name =~ /^pub\// )
                {
                    $permissions = '0664';
                }
                elsif ( $name =~ /^bin\// ) {
                    $permissions = '0555';
                }
                else {
                    $permissions = '0444';
                }
                if (-d $baseDir.'/'.$name) {
                    #default directories to traversable.
                    $permissions = '0775';
                }
            }
            $permissions = "0$permissions";
            $permissions =~ s/^0+/0/;
            my $n = {
                name        => $name,
                description => ( $desc || '' ),
                permissions => $permissions
            };
            push( @files, $n );
        }
    }
    close(PF);
    return ( \@files, \@otherModules );
}

=begin twiki

---++++ findInINC($fileName) => $path

Looks for a file in the paths listed in @INC. The parameters are:
  * $fileName: File to find in the @INC paths

Returns the path to the first instance of the file found in @INC.

=cut

sub findInINC {

    #TODO: Receive a sub to determine if the file is in the path?
    my $fileName = shift;
    foreach my $dir (@INC) {
        if ( -f $dir . '/' . $fileName ) {
            return $dir . '/' . $fileName;
        }
    }
    return undef;
}

1;
