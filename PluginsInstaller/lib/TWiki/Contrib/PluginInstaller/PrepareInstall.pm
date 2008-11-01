package TWiki::Contrib::PluginInstaller::PrepareInstall;

use Exporter;
use TWiki::Contrib::PluginInstaller::Common;

@ISA=(Exporter);
@EXPORT=qw(prepareInstallEnviroment);

sub prepareInstallEnviroment {
    my $config=shift;
    
    printNotQuiet "1. Preparing the Install Enviroment\n";        
    _loadTWikiConfig($config);
    _checkUnzipMechanism($config);
    printNotQuiet "\n";

}

sub _loadTWikiConfig {
    my $config=shift;
    my $twikiLibPath = $config->{twikiLibPath};

    printVerbose "   * Loading $twikiLibPath/TWiki.cfg .... ";
    
    do "$twikiLibPath/TWiki.cfg";
    $config->{dataDir}=$dataDir;
    $config->{pubDir}=$pubDir;
    $config->{templateDir}=$templateDir;
    $config->{storeTopicImpl}=$storeTopicImpl;
    $config->putStoreSettings(@storeSettings);
    $config->{libDir}=$config->{twikiLibPath};
    $config->{binDir}=$config->{twikiBinDir};
    #There is an error in the original Twiki.cfg file. 
    #The quotes are inverted in the condition
    
    $cmdQuote =  ($OS eq "UNIX") ? "'" :  "\""; 
    $config->{cmdQuote}=$cmdQuote;

   
    printVerbose " LOADED\n";

}   

#######################################
# Zip Stuff
#######################################

sub _checkUnzipMechanism {
    my $config=shift;

    printVerbose "   * Checking if Archive::Zip is installed .... ";
    eval "use Archive::Zip";
    if ($@) {
        printVerbose "NOT INSTALLED\n";
        $config->{useArchiveZip}=0;
        _checkUnzipPath($config);
    } else {
        printVerbose "INSTALLED \n";
        $config->{useArchiveZip}=1;
    }
    $config->{unzipPath}=$unzipPath;
    $config->{unzipParams}=$unzipParams;
}

sub _checkUnzipPath {
    my $config=shift;
    my $unzipPath =$config->{unzipPath};
    
    printVerbose "   * Searching an unzip program at $unzipPath .... ";
    
    if ($unzipPath && -f $unzipPath) {
        printVerbose "FOUND\n";
    } else {
        printVerbose "NOT FOUND\n";
        _findUnzipPath();
    }    
}

sub _findUnzipPath {
    print "     Please tell me the path to an unzip program\n      ---> "; 
    my $configPath;
    do {
        chomp ($configPath = <STDIN>) ;
    } until ((-f "$configPath") ? 1 :
        (print("     Hmmm - I can't see $configPath ... please check and try again\n      --->"), 0) 
        );
    
    print "     Please tell me the parameters to indicate to the unzip program the target directory\n      ---> "; 
    my $params;
    chomp ($params = <STDIN>) ;
        
    $config->{unzipPath} = $configPath;
    $config->{unzipParams} = $params;

    _checkUnzipPath($config);
}



1;

