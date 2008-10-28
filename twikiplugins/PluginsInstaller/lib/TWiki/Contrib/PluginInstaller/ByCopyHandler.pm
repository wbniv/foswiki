package TWiki::Contrib::PluginInstaller::ByCopyHandler;

use TWiki::Contrib::PluginInstaller::Common;
use TWiki::Contrib::PluginInstaller::DirHandler;

use File::Basename;
use File::Copy;

use vars qw { @ISA };

@ISA = ( TWiki::Contrib::PluginInstaller::DirHandler);

sub handle {
    my ($self,$filename,$baseDir,$dir)=@_;    

    my ($source,$target) = $self->_makeSourceTarget($filename,$baseDir,$dir);

    printVeryVerbose "      -> Copying $filename to $dir\n";

    if (-e $target) {
        printNotQuiet "         -> Creating Backup and Overwriting ".basename($target)."\n";
        $self->_backup($baseDir."/".$config->{uninstallDir},$filename,$target);
    }
    
    copy($source, $target) || warn "Warning: Failed to copy $from to $to: $!";
    
}


1;