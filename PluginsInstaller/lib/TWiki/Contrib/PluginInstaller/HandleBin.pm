package TWiki::Contrib::PluginInstaller::HandleBin;

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
    $self->SUPER::handle($filename,$baseDir,$config->{binDir});
}

1;
