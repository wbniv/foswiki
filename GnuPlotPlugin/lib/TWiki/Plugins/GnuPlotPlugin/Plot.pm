
package TWiki::Plugins::GnuPlotPlugin::Plot;

require TWiki::Plugins::GnuPlotPlugin::PlotSettings;

use strict;
use Assert;

my $debug = 0;

sub new{
    my ($class, $web, $topic, $plotName) = @_;
    $debug = $TWiki::Plugins::GnuPlotPlugin::debug;
    TWiki::Func::writeDebug( "GnuPlotPlugin::Plot::new - Creating new Plot with name $plotName" ) if $debug;
    my $self = {};
    $self->{WEB}   = $web;
    $self->{TOPIC} = $topic;
    $self->{NAME}  = $plotName;
    $self->{PATH}  = TWiki::Func::getPubDir() . "/$web/$topic";
    $self->{GNUFILE} = "$plotName.gnu";
    $self->{PNGFILE} = "$plotName.png";
    $self->{ERRFILE} = "$plotName.err";
#    $self->{SETTINGS} = [];

    bless ($self, $class);
    return $self;    
}


sub render{
    my $self = shift;    
    TWiki::Func::writeDebug( "GnuPlotPlugin::Plot::render - Rendering $self->{NAME}" ) if $debug;

    my $renderedText = "<a name=\"gnuplot" . $self->{NAME} . "\"></a>\n";
    my $gnuFile = $self->{PATH} . "/" . $self->{GNUFILE};
    my $gnuTmpFile = "/tmp/" . $self->{GNUFILE};
    my $pngFile = $self->{PATH} . "/" . $self->{PNGFILE};
    if (-e $gnuFile) 
    { 
        parseFile($self, $gnuFile, $gnuTmpFile);
        my $errFile = $self->{PATH} . "/" . $self->{ERRFILE};

        # Update $gnuplotPath, $gnuplotHelperPath and $execCmd to fit your environment
        my $gnuplotPath = "/usr/bin/gnuplot";
        my $gnuplotHelperPath = "/home/httpd/twiki/tools/gnuplot.pl";
        my $execCmd = "/usr/bin/perl %HELPERSCRIPT|F% %GNUPLOT|F% %WORKDIR|F% %INFILE|F% %OUTFILE|F% %ERRFILE|F% ";
        TWiki::Func::writeDebug( "GnuPlotPlugin::Plot::render - GnuPlot path: $gnuplotPath" ) if $debug;
        TWiki::Func::writeDebug( "GnuPlotPlugin::Plot::render - GnuPlot helper path: $gnuplotHelperPath" ) if $debug;
        TWiki::Func::writeDebug( "GnuPlotPlugin::Plot::render - Executing $execCmd in sandbox" ) if $debug;
        TWiki::Func::writeDebug( "GnuPlotPlugin::Plot::render - errorfile set to $errFile" ) if $debug;
        my $sandbox = $TWiki::sharedSandbox; 
        my ($output, $status) = $sandbox->sysCommand($execCmd,
                                                     HELPERSCRIPT => $gnuplotHelperPath,
                                                     GNUPLOT => $gnuplotPath,
                                                     WORKDIR => $self->{PATH},
                                                     INFILE => $gnuTmpFile,
                                                     OUTFILE => $pngFile,
                                                     ERRFILE => $errFile
                                                    );
        TWiki::Func::writeDebug("gnuplot-sandbox: output $output status $status") if $debug;
        if(-s $pngFile)
        {
            $renderedText .= "%ATTACHURL%/$self->{PNGFILE}\n\n";
        }
        else
        {
            $renderedText .= "*GnuPlotPlugin Error:* Cannot display the plot because the image file ($self->{PNGFILE}) has zero size. With a bit of luck the reason for this will be shown below.\n---\n"
        }
        if(-s $errFile)
        {
            open (ERRFILE, $errFile);
            my @errLines = <ERRFILE>;
            for (@errLines)
            {
                if(/($self->{PATH})/)
                {
                    my $maskedPath = $1;
                    $maskedPath =~ tr/[a-z][A-Z][0-9]\//\*/;
                    s/$self->{PATH}/$maskedPath/g;
                }
            }
            $renderedText .= "*Gnuplot Error:* <verbatim>" . join("", @errLines) . "</verbatim>";
        }
        $renderedText .= editPlotSettingsButton($self);
    }
    else
    {
        TWiki::Func::writeDebug( "GnuPlotPlugin::Plot::render - $gnuFile does not exist" ) if $debug;
        $renderedText = "No settings found for this plot (<nop>$self->{GNUFILE} not found). Click on the Edit button below to generate and edit the settings for this plot.\n";
        $renderedText .= "\n" . editPlotSettingsButton($self);
    }
    return $renderedText;
}

sub parseFile {
    my ($self, $gnuFile, $gnuTmpFile) = @_;
    TWiki::Func::writeDebug( "GnuPlotPlugin::Plot::readFile - Reading settings from $gnuFile" ) if $debug;
    open (INFILE, $gnuFile) or return newFile();
    open (OUTFILE, ">", $gnuTmpFile) or die;
    my $plotString = "";
    my $terminal = "set terminal png\n";
    while (<INFILE>)
    {
        if (/^set/ and not /terminal/)
        {
            print OUTFILE $_;
            next;
        }
        if (/^set/ and /terminal/ and /png/ and /size/)
        {
            $terminal = $_;
            next;
        }        
        if (/^plot/ or /^splot/)
        {
            chomp;
            $plotString = buildPlotString($self, $_);
            next; 
        }
    }
    if ($plotString eq "") { $plotString = "test" };
    print OUTFILE "$terminal";
    print OUTFILE "$plotString\n\n";
}

sub editPlotSettingsButton {
    my $self = shift;
    my $text = '';
    $text .= "<form action='" . TWiki::Func::getScriptUrl( "$self->{WEB}", "$self->{TOPIC}", "view" ) . "#gnuplot".$self->{NAME}."' method=\"post\" >\n";
    $text .= "<input type=\"hidden\" name=\"gnuPlotName\" value=\"$self->{NAME}\" />\n";
    $text .= "<input type=\"hidden\" name=\"gnuPlotAction\" value=\"edit\" />\n";
    $text .= "<input type=\"submit\" value=\"Edit Plot Settings\" class=\"twikiSubmit\"></input>\n";
    $text .= "</form>\n";
    return $text;
}





sub buildPlotString {
    my $self = shift;
    my $plotString = shift;
    my @inPlots = split(/,/, $plotString);
    my @outPlots = ();
    foreach (@inPlots)
    {
        if (/('.*')/)
        {
            my $plotSpec = $_;
            my $dataFile = substr($1,1);
            chop($dataFile);
            my $fullPathToDataFile = $self->{PATH} . "/" . $dataFile;
            $plotSpec =~ s/$dataFile/$fullPathToDataFile/;
            unless ($plotSpec =~ /title/)
            {
                $plotSpec .= " title \"" . $dataFile . "\"";
            }
            if(-e $fullPathToDataFile)
            {
                push(@outPlots,  $plotSpec );
            }
        }
        else
        {
             push(@outPlots, $_);
        }
    }
    return join(", ", @outPlots);
}
1;
