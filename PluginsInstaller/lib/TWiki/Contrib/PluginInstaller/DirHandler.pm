package TWiki::Contrib::PluginInstaller::DirHandler;

use TWiki::Contrib::PluginInstaller::Common;
use File::Copy;

sub _makeSourceTarget {
    my ($self,$filename,$sourceDir,$targetDir)=@_;
    my $source="$sourceDir$filename";
    my $target="$targetDir/".$self->_removeDirFromFilename($filename);
    return ($source,$target);    
}

sub _removeDirFromFilename {
    my ($self,$filename) =@_;
    $filename =~ m!\/.*?\/(.*)!;
    return $1;
}

sub _backup {
    my ($baseDir,$filename,$target) = @_; 
    my $filePath=$baseDir.$filename;
    my $path;
    if ($filePath =~ /^(.*)\/[^\/]*$/) {
        $path=$1;
    } else {
        $path=$filePath;
    }
    makepath($path);
    copy($target, $filePath);
}

1;