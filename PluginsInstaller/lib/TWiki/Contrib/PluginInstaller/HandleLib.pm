package TWiki::Contrib::PluginInstaller::HandleLib;

use TWiki::Contrib::PluginInstaller::ByCopyHandler;
use TWiki::Contrib::PluginInstaller::Common;

use vars qw { @ISA };

@ISA= (TWiki::Contrib::PluginInstaller::ByCopyHandler);

use File::Copy;

sub new {
    return bless {};   
}

sub handle {
    my ($self,$baseDir,$filename,$config)=@_;
    if ((!(checkDirectory($filename,"TWiki/Plugins/"))) && (!(checkDirectory($filename,"TWiki/Contrib/")))) {
        print "         -> Cannot install lib files outside the Plugin or Contrib dirs: $filename\n";
        return;
    }    

    $self->SUPER::handle($filename,$baseDir,$config->{libDir});
}

1;
