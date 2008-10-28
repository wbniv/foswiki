package TWiki::Contrib::PluginInstaller::Installer;

use TWiki::Contrib::PluginInstaller::PrepareInstall;

use TWiki::Contrib::PluginInstaller::HandleData;
use TWiki::Contrib::PluginInstaller::HandleLib;

use TWiki::Contrib::PluginInstaller::Common;
use File::Copy;
use Text::Diff;

use vars qw{
    $config;
};


sub new {
    my $type=$_[0];
    $config=$_[1];
    TWiki::Contrib::PluginInstaller::Common::init($config);
    return bless {};    
}


sub install {
    my $self=shift;
    prepareInstallEnviroment($config);

    my $pluginPackage=$config->{pluginPackage};
    my $web=$config->{web};
    my $incomingDir=$config->{incomingDir};

    if (! -f "$incomingDir/$pluginPackage.zip") {
        print "Can't find $incomingDir/$pluginPackage.zip for installing\n";
        return;
    } else {
        printNotQuiet "2. Installing $pluginPackage\n";
        $self->_unzipFile();
        $self->_copyFiles($pluginPackage,$web);
        printNotQuiet "\n\n";        
    }
}

#--------------------------------------------------------

sub _unzipFile {
    my $self=shift;
    my $incomingDir=$config->{incomingDir};
    my $pluginPackage=$config->{pluginPackage};
    my $pluginPackageFile="$incomingDir/$pluginPackage.zip";
    my $pluginPackageDir="$incomingDir/$pluginPackage";
    
    printVerbose "   * Inflating $pluginPackage.zip to temp directory\n";
    if ($config->{useArchiveZip}) {
        my $zip=Archive::Zip->new($pluginPackageFile);
        my @members=$zip->members();
        foreach my $member (@members) {
            $zip->extractMember($member->fileName(),$pluginPackageDir."/".$member->fileName());
            printVeryVerbose "      -> Inflating ".$member->fileName() . "\n";
        }
    } else {
        system($config->{unzipPath}. " $pluginPackageFile ".$config->{unzipParams}." $pluginPackageDir");    
    }
    print "\n"; 
}

#--------------------------------------------------------

sub _copyFiles {
    my ($self,$pluginPackage,$web)=@_;
    my $incomingDir=$config->{incomingDir};
    printVerbose "   * Copying archives from dir $incomingDir/$pluginPackage to twiki\n";
    $self->_processDir("$incomingDir/$pluginPackage","","");
}

#########################################################

sub _getDirEntries {
    my $dir=shift;
    opendir DIR,$dir;
    my @entries = readdir DIR;
    close DIR;
    return @entries;
}

#--------------------------------------------------------

sub _processDir {
    my ($self,$baseDir,$dir,$parentDir) = @_;
    my @entries = _getDirEntries($baseDir.$parentDir.$dir);
    foreach my $entry (@entries) {
        next if ($entry =~ /^\.+$/);
        my $name= "$parentDir$dir/$entry";
        my $path = "$baseDir$name";
        if (-d $path && (!($path =~ /$config->{uninstallDir}/))) {
            printVeryVerbose "      -> Processing $name directory\n";
            $self->_processDir($baseDir,$entry,$parentDir.$dir."/");
        } elsif (-f $path) {
            $path =~ m!^$baseDir\/(.*?)\/.*$!;
            my $targetDir=$1;
            my $handerSub = "handle$targetDir";

            if ($self->can($handerSub)) {
                $self->$handerSub($baseDir,$name);
            } else {
                my $handlerClass="TWiki::Contrib::PluginInstaller::Handle".uc (substr($targetDir,0,1)).substr($targetDir,1);
                eval ("use $handlerClass;");
                if (@$) {
                    print " don't know how to handle resources in directory $targetDir\n";     
                } else {
                    $handlerClass->handle($baseDir,$name,$config);   
                }
            }
        }elsif (! $path =~ /$config->{uninstallDir}/) {
            warn "This should not be happening....";
        }
    }
    close DIR;
}

#sub handlebin {
#    my ($self,$baseDir,$filename)=@_;
#    _doHandleByCopy($filename,$baseDir,$config->{binDir});
#}

sub _doHandleByCopy {
    my ($filename,$baseDir,$dir)=@_;    

    my ($source,$target) = _makeSourceTarget($filename,$baseDir,$dir);

    printVeryVerbose "      -> Copying $filename to $dir\n";

    if (-e $target) {
        print "         -> Creating Backup and Overwriting $target\n";
        _backup($baseDir."/".$config->{uninstallDir},$filename,$target);
    }
    File::Copy::copy($source, $target) ||
        warn "Warning: Failed to copy $from to $to: $!";
    
}

sub _makeSourceTarget {
    my ($filename,$sourceDir,$targetDir)=@_;
    my $source="$sourceDir$filename";
    my $target="$targetDir/"._removeDirFromFilename($filename);
    return ($source,$target);    
}

sub _removeDirFromFilename {
    my ($filename,$dir) =@_;
    $filename =~ m!\/.*?\/(.*)!;
    return $1;
}

sub handlepub {
    #print "Goal pub\n";
}

#sub handledata {
#    my ($self,$baseDir,$filename)=@_;
#    return if ($filename =~ /,v$/ or $filename =~ /.lock$/ or $filename =~ /~$/);
#    
#    my ($source,$target) = _makeSourceTarget($filename,$baseDir,$config->{dataDir});
    #TWiki::Contrib::PluginInstaller::HandleData::handle($source,$target);
#}


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
    File::Copy::copy($target, $filePath);
}




1;