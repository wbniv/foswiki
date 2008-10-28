package TWiki::Contrib::PluginInstaller::Common;

use Exporter;
@ISA=(Exporter);
@EXPORT=qw(makepath printVerbose printVeryVerbose printNotQuiet checkDirectory);
@EXPORT_OK=qw(init);

use vars qw {
    $config
};

=begin text

---++++ makepath($to)
Make a directory and all directories leading to it.

=cut
sub makepath {
    my ($to) = @_;
    chop($to) if ($to =~ /\n$/o);
    $to =~ m!^\.?\/(.*?)\/(.*)$!;
    buildpath($1,$2);
    
}

sub buildpath {
    my ($parent,$to) =@_;
    chop($to) if ($to =~ /\n$/o);
    if (($to =~ m!(.*?)\/(.*)$!) ||($to =~ m!([^\/]+)$!)) {
        mkdir("$parent/$1") || warn "Warning: Failed to make $to: $!" unless (-e "$parent/$1" || -d "$parent/$1");
        buildpath("$parent/$1",$2);
    }
}    

sub init {
    $config=shift;    
}

sub printVerbose {
    my $text=shift;    
    print $text if (($config->{-v}||$config->{-vv}) && !$config->{-q}) ;
}

sub printVeryVerbose{
    my $text=shift;    
    print $text if ($config->{-vv} && !$config->{-q});
}

sub printNotQuiet {
    my $text=shift;    
    print $text unless ($config->{-q});
}

sub checkDirectory {
    return $_[0] =~ /$_[1]/;    
}
1;