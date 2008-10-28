
package TWiki::Plugins::GnuPlotPlugin::PlotSettings;

require TWiki::Plugins::GnuPlotPlugin;

use strict;
use Assert;

my $debug = 0;

sub fromFile{
    my ($class, $web, $topic, $plotName) = @_;
    $debug = $TWiki::Plugins::GnuPlotPlugin::debug;
    TWiki::Func::writeDebug( "GnuPlotPlugin::PlotSettings::fromFile - Creating new PlotSettings Object from file for $web / $topic / $plotName" );
    my $self = {};
    $self->{WEB}   = $web;
    $self->{TOPIC} = $topic;
    $self->{NAME}  = $plotName;
    $self->{TEXT}  = undef;
#    $self->{SETTINGS} = [];

    my $gnuFile = buildFileName($web, $topic, $plotName);
    $self->{TEXT} = readFile($gnuFile);
    
    bless ($self, $class);
    return $self;    
}

sub buildFileName{
    my ($web, $topic, $plotName) = @_;
    return TWiki::Func::getPubDir() . "/$web/$topic/$plotName.gnu";
}
sub readFile {
    my $gnuFile = $_[0];
    TWiki::Func::writeDebug( "GnuPlotPlugin::PlotSettings::readFile - Reading settings from $gnuFile" ) if $debug;
    open (INFILE, $gnuFile) or return newFile();
    my $content = '';
    my $plotString = "test";
    my $terminal = "set terminal png\n";
    while (<INFILE>)
    {
        if(/^set/ and not /terminal/)
        {
            $content .= $_;
            next;
        }
        if(/^set/ and /terminal/ and /png/ and /size/)
        {
            $terminal = $_;
            next;
        }
        if (/^plot/ or /^splot/)
        {
            $plotString = $_;
        }
    }
    $content .= $terminal;
    $content .= $plotString;
    return $content;
}

sub writeFile{
    my ($web, $topic, $plotName, $text) = @_;
    my $webDir = TWiki::Func::getPubDir() . "/$web";
    unless (-e $webDir) { mkdir $webDir };
    unless (-e "$webDir/$topic") { mkdir "$webDir/$topic" };
    my $gnuFile =  "$webDir/$topic/$plotName.gnu";
    TWiki::Func::writeDebug( "GnuPlotPlugin::PlotSettings::writeFile - Writing ---=$text=--- to $gnuFile" );# if $debug;
    open (OUTFILE, ">", $gnuFile) or die "Cannot create new Gnuplot file!";
    TWiki::Func::writeDebug( "GnuPlotPlugin::PlotSettings::writeFile - Writing ---=$text=--- to $gnuFile" );# if $debug;
    print OUTFILE "$text";
    close OUTFILE;
}

sub newFile{
    TWiki::Func::writeDebug( "GnuPlotPlugin::PlotSettings::newFile - Creating new default settings" ) if $debug;
    my $text = '';
    $text .= "set datafile separator \",\"\n";
    $text .= "set terminal png\n";
    $text .= "plot sin(x), cos(x), x*x/10\n";
    return $text;
}


sub render{
    my $self = shift;
#    $self->{WEB}   
#    $self->{TOPIC}
#    $self->{NAME} 
#    $self->{TEXT}  
    my $text = '';
    $text .= "*Edit Settings for !$self->{NAME}*\n";
    $text .= "<a name=\"gnuplot" . $self->{NAME} . "\"></a>\n";
    $text .= "<form action=" . TWiki::Func::getScriptUrl( "$self->{WEB}", "$self->{TOPIC}", "view" ) . "\#gnuplot$self->{NAME}\" method=\"post\">\n";
    $text .= "<table>\n";
    $text .= "  <tr valign=\"middle\">\n";
    $text .= "    <td><textarea  rows=\"10\" cols=\"90\" name=\"gnuPlotSettingsText\" >$self->{TEXT}</textarea>\n";
    $text .= "    </td>\n";
    $text .= "    <td><input  type=\"submit\" value=\"Save Settings\" class=\"twikiSubmit\" /><br>\n";
    $text .= "        <a target=\"GnuPlotPlugin\" onclick=\"return launchWindow('TWiki','GnuPlotPlugin')\" href=\"/twiki/bin/view/TWiki/GnuPlotPlugin\">GnuPlotPlugin help</a><br>\n";
    $text .= "        <a target=\"GnuPlotHelp\" onclick=\"return launchWindow('TWiki','GnuPlotHelp')\" href=\"/twiki/bin/view/TWiki/GnuPlotHelp\">Gnuplot help</a>\n";
    $text .= "    </td>\n";
    $text .= "  </tr>\n";
    $text .= "</table>\n";
    $text .= "<input type=\"hidden\" name=\"gnuPlotName\" value=\"$self->{NAME}\" />";
    $text .= "<input type=\"hidden\" name=\"gnuPlotAction\" value=\"save\" />";
    $text .= "</form>\n";
    return $text;
}


1;
