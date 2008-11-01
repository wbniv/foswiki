package TWiki::Contrib::PluginInstaller::HandleData;

use File::Copy;
use File::Basename;
use TWiki::Contrib::PluginInstaller::Common;
use TWiki::Contrib::PluginInstaller::DirHandler;
use TWiki::Contrib::Test::Mock::MockCGI;

use TWiki::UI::Save;

use vars qw { @ISA };
@ISA = (TWiki::Contrib::PluginInstaller::DirHandler);

sub handle {
    my ($self,$baseDir,$filename,$config)=@_;
    
    my ($source,$target) = $self->_makeSourceTarget($filename,$baseDir,$config->{dataDir});
    
    printVeryVerbose "      -> Processing $source\n";
            
    if ($source =~ /,v$/ or $source =~ /.lock$/ or $source =~ /~$/) {
        printNotQuiet "         -> Don't process version, locks or backup files: ".basename($source)."\n";
        return;
    }
    
    copy($source,$target);
    %storeSettings=$config->getStoreSettings();
    my $cmd = $storeSettings{"ciCmd"};

    # The following should work:
    #my $query=new TWiki::Contrib::Test::Mock::MockCGI();
    #$filename=~ /.+?(\/.*)\.txt/;
    #$query->{path_info} =$1;
    #$query->{url}=$config->{viewScriptPath}.$query->{path_info};
    #$query->setParam('topic','');
    #$query->setParam('text',readText($source));
    #$query->{remote_user}="PluginInstaller";
    #    
    #my $thePathInfo = $query->path_info(); 
    #my $theRemoteUser = $query->remote_user();
    #my $theTopic = $query->param( 'topic' );
    #my $theUrl = $query->{url};
    #my ( $topic, $web, $dummy, $userName ) = TWiki::initialize( $thePathInfo, $theRemoteUser,$theTopic, $theUrl );
    #TWiki::UI::Save::savemulti( $web, $topic, $userName, $query );
    #
    # but keeps telling me 
    #         ci: diff.exe failed for unknown reason
    #         ci aborted
    #
    # Something like the previous is the best way to handle the 
    # versioning of the installed topics, because that way the 
    # installer don't know how the topic is being stored.
    
    #For now.... just use the old plain ci command
    #This code is working, but twiki can retrieve neither 
    #the revisions nor the differences between revisions
    #The following was copied from the RcsWrap.pm file
    $cmd =~ s/%USERNAME%/"PluginInstaller"/;
    $cmd =~ s/%FILENAME%/$config->{cmdQuote}$target$config->{cmdQuote}/;
    $cmd =~ s/%COMMENT%/"'InstalledbyPluginInstaller'"/;
    $cmd =~ /(.*)/;
    $cmd = $1;       # safe, so untaint variable
    my $rcsOutput=`$cmd`;
   
}

sub readText {
    my ($filename)=@_;
    open FILE,"< $filename";
    my $text = join("",<FILE>);    
    close FILE;
    return $text;
}

sub getWebTopic {
    my ($self,$filename) = @_;
    
    my $result = $self->_removeDirFromFilename($filename);
    $result=~ m!(.*)\..*!;
    return split "/",$1;
}    
    
1;

