# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at 
# http://www.gnu.org/copyleft/gpl.html
#
# =========================
#
# initPlugin is required, all other are optional. 
# For increased performance, all handlers except initPlugin are
# disabled. To enable a handler remove the leading DISABLE_ from
# the function name. Remove disabled handlers you do not need.
#
# NOTE: To interact with TWiki use the official TWiki functions 
# in the TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!


# =========================
package TWiki::Plugins::GenPDFLatexPlugin;

use strict;

use File::Basename qw( basename );

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $pluginName
        $debug $pdflatex_ifelse $pdflatex_ifonly $script
    );

$VERSION = '1.300';
$RELEASE = 'Dakar';

$pluginName = 'GenPDFLatexPlugin';  # Name of this Plugin


my $pdflatex_ifonly = qr/%PDFLATEXIF{?(.*?)}?%(.*?)%PDFLATEXENDIF%/s;
my $pdflatex_ifelse = qr/%PDFLATEXIF{?(.*?)}?%(.*?)%ELSE%(.*?)%PDFLATEXENDIF%/s;

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.021 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPluginPreferencesFlag( "DEBUG" );

    # get the name of the script that called us
    $script = basename( $0 );

    # Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
    # $exampleCfgVar = TWiki::Func::getPluginPreferencesValue( "EXAMPLE" ) || "default";

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # This is the place to define customized tags and variables
    # Called by TWiki::handleCommonTags, after %INCLUDE:"..."%

    $_[0] =~ s!%PDFLATEXLINK{?(.*?)}?%!&handleCreate($1)!geos;

    $_[0] =~ s/$pdflatex_ifelse/&handlePDFcond($1,$2,$3)/geos;
    $_[0] =~ s/$pdflatex_ifonly/&handlePDFcond($1,$2,'')/geos;

    $_[0] =~ s!%CITE{(.*?)}%!<latex>\\cite{$1}</latex>!gs
        if ($script =~ m/genpdflatex/);

}

sub handleCreate {
    my $prefs = $_[0];
    my %opts;

    $opts{'text'} = "Create PDF/Latex Version";
    while ( $prefs=~ m/(.*?)=\"(.*?)\"/g ) {
        my ($a,$b) = ($1,$2);
        # remove leading/trailing whitespace from key names
        $a =~ s/^\s*|\s*$//;    

        $opts{$a} = $b;
    }
    my $text = $opts{'text'};
    delete $opts{'text'};

    my $link = '%SCRIPTURL%/genpdflatex/%WEB%/%TOPIC%';
    if (keys %opts) {
        $link .= "?" unless ($link=~m/\?/);
        
        my @p = map {"$_=$opts{$_}"} (keys %opts);

        $link .= join('&',@p);
    }
    my $ret = "";
    $ret = "[[$link][$text]]" unless ($script =~ m/genpdflatex/);

    return($ret);
}

sub handlePDFcond {
    my ($opts,$tex,$html) = @_;

    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::handlePDFcon\n".
                             "\topts: $opts\n\ttex: $tex\n\thtml:$html\n"
                             ) if $debug;

    if ($script =~ m/genpdflatex/) {
        return('<latex>'.$tex.'</latex><p>');
    } else {
        return($html);
    }

}

# =========================

1;
