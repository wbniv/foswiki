# For licensing info read LICENSE file in the TWiki root.
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

package TWiki::Contrib::SearchEngineKinoSearchAddOn::StringifyBase;
use strict;
use Module::Pluggable (require => 1, search_path => [qw/TWiki::Contrib::SearchEngineKinoSearchAddOn::StringifierPlugins/]);

__PACKAGE__->plugins;

use constant DEFAULT_HANDLER => "TWiki::Contrib::SearchEngineKinoSearchAddOn::StringifyPlugins::Text";
{
    my %mime_handlers;
    my %extension_handlers;
    sub register_handler {
        my ($package, @specs) = @_;

        for my $spec (@specs) { 
            if ($spec =~ m{/}) {
                $mime_handlers{$spec} = $package;
            } else {
                $extension_handlers{$spec} = $package;
            }
        }
    }
    sub handler_for {
        my ($self, $filename, $mime) = @_;
        if (exists $mime_handlers{$mime}) { return $mime_handlers{$mime} }
	$filename = lc($filename);
        for my $spec (keys %extension_handlers) {
            if ($filename =~ /$spec$/) { return $extension_handlers{$spec} }
        }
        return DEFAULT_HANDLER;
    }

    # Returns 1, if the program can be called.
    # This is as service method that a sub calss can use to decise, 
    # if it wants to register or not.
    sub _programExists {
	my ($self, $program) = @_;

	return defined(`$program 2>&1`);
    }
}

sub new { 
    my ($handler) = @_;
    my $self = bless {}, $handler;

    $self;
}

# Service method to remove the director $dir and  
# all contence including sub directories
sub rmtree {
    my ($self, $dir) = @_;
    local *DIR;

    # If the dir is infact a file, I just delete that.
    if (-f $dir) {
	unlink($dir);
    }

    opendir (DIR, $dir) || return 0;
    while (my $file = readdir(DIR)) {
        # Ignores . and ..
        next if ($file =~ /^\.{1,2}$/);

        $file = "$dir/$file";
        if (-d $file) {
            $self->rmtree($file);
        } elsif (-f $file) {
            unlink($file);
        }
    }
    closedir DIR;
    rmdir($dir);
    return 1;
}

1;
