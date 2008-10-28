#
# GenPDFLatex.pm (converts a TWiki topic to Latex or PDF using HTML::Latex)
#    (based on GenPDF.pm package)
#
# This package Copyright (c) 2005 W Scott Hoge 
# (shoge -at- bwh -dot- harvard -dot- edu)
# and distributed under the GPL (see below)
#
# part of the TWiki WikiClone (see http://twiki.org)
# Copyright (C) 1999 Peter Thoeny, peter@thoeny.com
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

## This package was used to capture STDOUT during development
##
#  package Redirect;
#  
#  sub TIEHANDLE  { 
#      return bless [], $_[0];
#  } 
#  
#  sub PRINT {
#      my $fh = shift;
#      push @$fh, @_;
#  }
#  
#  1;


package TWiki::Contrib::GenPDFLatex;

use strict;

use vars qw( $VERSION $RELEASE $debug );

use File::Copy;

# use TWiki::Plugins::LatexModePlugin qw($preamble);

# number the release version of this addon
$VERSION = '$Rev$';
$RELEASE = '2.000';

=pod

=head1 TWiki::Contrib::GenPDFLatex

TWiki::Contrib::GenPDFLatex - Generates raw latex or pdflatex file from a 
    TWiki topic

=head1 DESCRIPTION

See the GenPDFLatexAddOn TWiki topic for the full description.

=head1 METHODS

Methods with a leading underscore should be considered local methods
and not called from outside the package.

=cut

######################################################################
#### these paths need to be properly configured (either here or in
#### LocalSite.cfg)

# path to location of local texmf tree, where custom style files are storedx
$ENV{'HOME'} = $TWiki::cfg{Plugins}{GenPDFLatex}{home} ||
    '/home/nobody';
# full path to pdflatex and bibtex
my $pdflatex = $TWiki::cfg{Plugins}{GenPDFLatex}{pdflatex} ||
    '/usr/share/texmf/bin/pdflatex';
my $bibtex = $TWiki::cfg{Plugins}{BibtexPlugin}{bibtex} || 
    '/usr/share/texmf/bin/bibtex';

# directory where the html2latex parser will store copies of
# referenced images, if needed
my $htmlstore = $TWiki::cfg{Plugins}{GenPDFLatex}{h2l_store} ||
    '/tmp/';

######################################################################


use CGI::Carp qw( fatalsToBrowser );
use CGI;
use TWiki::Func;
use TWiki::UI::View;

use HTML::LatexLMP;
use File::Basename;
use File::Temp;

use Archive::Zip qw( :ERROR_CODES :CONSTANTS );

sub genfile() {

    my ($query, $webName, $topic, $scriptUrlPath, $userName );
    if( $TWiki::Plugins::VERSION >= 1.1 ) { 
        # Dakar interface 
        my $session = shift;

        $query = $session->{cgiQuery};
        $webName = $session->{webName};
        $topic = $session->{topicName};

        $TWiki::Plugins::SESSION = $session;

    } else {
        # Cairo interface
        $query = new CGI;
    }
    my $thePathInfo = $query->path_info(); 
    my $theRemoteUser = $query->remote_user();
    my $theTopic = $query->param( 'topic' );
    my $theUrl = $query->url;
    
    ( $topic, $webName, $scriptUrlPath, $userName ) = 
        TWiki::initialize( $thePathInfo, $theRemoteUser,
                           $theTopic, $theUrl, $query );

    my $action = $query->param('output') || "";

    $debug = 0;

    if ( $action eq 'latex' ) {

        my $tex = _genlatex( $webName, $topic, $userName, $query );

        if (length($tex) > 0) {
            print $query->header( -TYPE => "text/html",
                                  -attachment=>"$topic.tex" );
            print $tex;
        } else {
            print $query->header( -TYPE => "text/html" );

            print "GenPDFLatex error:  No latex file generated.";
        }

    } elsif ( $action eq 'srczip' ) {

        my $tex = _genlatex( $webName, $topic, $userName, $query );

        my @filelist = _get_file_list($webName,$topic);

        if ($debug) {
            print $query->header( -TYPE => "text/html" );
        
            print "<p>Generating ZIP file of latex source + attached bib and fig files\n<p>";
    
            print "<ul>";
            print map {"<li> $_"} @filelist;
            print "</ul>";
        }

        my $zip = Archive::Zip->new();
        my ($tmpzip,$WDIR) = ('','');
        if ( defined($zip) ) {

            $WDIR = File::Temp::tempdir();
            $tmpzip = $WDIR."tmp.zip";

            my $member = $zip->addString( $tex, $topic.'.tex' );
    #        $member->desiredCompressionMethod( COMPRESSION_DEFLATED );
        
            # use hard-disk path rather than relative url paths for images
            my $url = TWiki::Func::getPubDir();
        
            foreach my $c (@filelist) {
                my $member = $zip->addFile( join('/',$url,$webName,$topic,$c), $c );
            }
            die 'write error' unless 
                $zip->writeToFileNamed( $tmpzip ) == AZ_OK;
        }

        if (-f $tmpzip) {
            print $query->header( -TYPE => "application/zip",
                                  -attachment=> $topic."_src.zip" );
            open(F,$tmpzip);
            while (<F>) {
                print;
            }
            close(F);

            unlink($tmpzip) unless ($debug);

            rmdir($WDIR) || print STDERR "genpdflatex: Can't remove $WDIR: $!\n";
            $WDIR = undef;

        } else {
            print $query->header( -TYPE => "text/html" );
        
            print "GenPDFLatex error:  No ZIP file generated.";
        }
        undef($zip);


    } elsif ( $action eq 'pdf' ) {

        my $tex = _genlatex( $webName, $topic, $userName, $query );

        # create a temporary working directory
        my $WDIR = File::Temp::tempdir();
        `chmod a+rwx $WDIR` if ($debug);

        my $latexfile = $WDIR.'/lmp_content.tex';

        open(F,">$latexfile");
        print F $tex;
        close(F);

        my ($base,$path,$extension) = fileparse($latexfile,'\.tex');
        my $texrel  = "$base$extension";   #relative name of the tex file
        my $logfile = "$path$base.log";
        my $pdffile = "$path$base.pdf";

        # change to working directory for latex processing
        use Cwd;
        my $SDIR = getcwd();
        $SDIR = $1 if ( ($SDIR) and ($SDIR =~ m/^(.*)$/) );

        my @filelist = _get_file_list($webName,$topic);
        foreach my $f (@filelist) {
            copy( join('/',TWiki::Func::getPubDir(),$webName,$topic,$f), $path.'/'.$f );
        }

        chdir($path);
        my $flag = 0;
        my $ret = "";
        do {
            $ret = `$pdflatex -interaction=nonstopmode $texrel`;
            $ret .= `$bibtex $base` if ($tex =~ m/\\bibliography\{/);
            $flag++ unless ($ret =~ m/Warning.*?Rerun/i);
        } while ($flag < 2);

        my @errors = grep /^!/, $ret;

        my $log = 
        open(F,"$logfile");
        while (<F>) {
            $log .= $_."\n";
            push(@errors, grep /Error\:/, $_);
        }
        close(F);

        if(@errors){
            print $query->header( -TYPE => "text/html" );
            print "<html><body>";
            print "pdflatex reported " . scalar(@errors) . " errors while creating PDF:";
            print "<ul>\n";
            print map {"<li>$_ "} @errors;
            print "</ul>\n";

            print "</html></body>";

        } elsif (-f $pdffile) {

            print $query->header( -TYPE => "application/pdf",
                                  -attachment=>"$topic.pdf" );

            open(F,"$pdffile");
            while (<F>) {
                print;
            }
            close(F);
        } else {
            print $query->header( -TYPE => "text/html" );
            print "<html><body>\n";
            print "<h1>PDFLATEX processing error:</h1>\n";
            
            if ($debug) {
                print "Attached files: <ul>";
                print map {"<li> $_"} @filelist;
                print "</ul>";
            }
            print "<pre>".$log;
            print "</pre></body></html>\n";
        }

        do {
            # clean up the working directory
            opendir(D,$WDIR) || print STDERR "genpdflatex: Can't open $WDIR: $!\n";
            foreach my $t ( grep(/$base/, readdir(D)) ) {
                $t =~ m/^(.*?)$/;
                $t = $1;            # untaint it
                unlink("$t") || print STDERR "genpdflatex: Can't remove $t: $!\n";
            }
            close(D);
            # remove the attached files
            foreach my $f (@filelist) {
                unlink("$f") || print STDERR "genpdflatex: Can't remove $f: $!\n";
            }

            chdir($SDIR) if ($SDIR ne "");
            rmdir($WDIR) || print STDERR "genpdflatex: Can't remove $WDIR: $!\n";
            $WDIR = undef;
        } unless ($debug);

    } else {

        my $optpg = &TWiki::Func::getPreferencesValue( "GENPDFLATEX_OPTIONSPAGE" ) || "";

        my $text = "";
        if ( $optpg ne "" ) {
            # if an options page is defined

            my ($optWeb,$optTopic) = ($1,$2) if $optpg =~ /(.*)[\.\/](.*)/ ;
            # print STDERR "$optWeb . $optTopic \n";
            if ($optTopic eq "") { 
                $optTopic = $optWeb;
                $optWeb = $webName;
            }
            $optWeb = $webName if ($optWeb eq "");

            if (TWiki::UI::webExists( $optWeb, $optTopic ) ) {

                my $skin = "plain"; # $query->param( "skin" );
                my $tmpl = &TWiki::Store::readTemplate( "view", $skin );

                $text = TWiki::Func::readTopicText($optWeb, $optTopic, undef );

                $tmpl =~ s/%TEXT%/$text/;
                $tmpl =~ s/%META:\w+{.*?}%//gs;

                $tmpl .= "<p>(edit the $optpg topic to modify this form.)";

                $text = TWiki::Func::expandCommonVariables($tmpl, $optTopic, $optWeb);
                $text = TWiki::Func::renderText($text);

                $text =~ s/%.*?%//g;    # clean up any spurious TWiki tags
            }
        } 

        # if (0) {
        #     ### I was hoping to render the form inside the default template,
        #     ### but it didn't look as nice as I'd hoped...
        #
        #     my ($optWeb,$optTopic) = ($1,$2) if $optpg =~ /(.*)[\.\/](.*)/ ;
        #     print STDERR "$optWeb . $optTopic \n";
        #     if ($optTopic eq "") { 
        #         $optTopic = $optWeb;
        #         $optWeb = $webName;
        #     }
        #     $optWeb = $webName if ($optWeb eq "");
        # 
        #     my $stdout = tie *STDOUT, 'Redirect';
        #     
        #     # TWiki::Func::redirectCgiQuery( $query, $optpg );
        #     TWiki::UI::View::view( $optWeb, $optTopic, $userName, $query );
        # 
        #     my $text = join('',@{ $stdout });
        # 
        #     $stdout = undef;
        #     untie(*STDOUT);
        # }

        if (length($text) == 0) {
            # if optpg is undefined, or points to a non-existent topic, then
            # use the default form defined below.
            while (<DATA>) {
                $text .= $_;
            }
        }

        $text =~ s/\$scriptUrlPath/$scriptUrlPath/g;
        $text =~ s/\$topic/$topic/g;
        $text =~ s/\$web/$webName/g;

        $text =~ s!<title>.*?</title>!<title>TWiki genpdflatex: $webName/$topic</title>!;

        foreach my $c ($query->param()) {
            my $o = $query->param($c);
            $text =~ s/\$$c/$o/g;
            
            $text .= "<br>$c = ".$query->param($c) if ($debug);
        }

        # elliminate style lines and packages if the options are not declared. 
        $text =~ s/\n.*?\$style.*?\n/\n/g;
        $text =~ s/\$packages//g;

        print $query->header;
        print $text;
        
    }
    
}


sub _get_file_list {
    my ($meta,$text) = TWiki::Func::readTopic( $_[0], $_[1] ); # $webName, $topic
    my @filelist;
    
    my %h = %{$meta};
    foreach my $c (@{$h{'FILEATTACHMENT'}}) {
        my %h2 = %{$c};
        next if ($h2{'attr'} eq 'h');
        push @filelist, $h2{'name'};
    }
    return(@filelist);
}

sub _list_possible_classes {
    # this is a debug subroutine to check if the latex environment is
    # operational on the server.
    print $ENV{'HOME'};
    print $ENV{'PATH'};
    my ($base,$path) = fileparse($pdflatex);
    $ENV{'PATH'} .= ':'.$base;  # use correct dir sep for your OS.

    my @paths = split(/:/,`$base/kpsepath tex`);
    
    my %classes = ();

    print "<ul>";
    foreach (@paths) {
        print "<li>".$_;
        (my $p = $_) =~ s!(texmf.*?)/.*$!$1!;
        $p =~ s/\!//g;
        print "   $p";
        if ( (-d $p) and (-f $p."/ls-R")) {
            open(F,"$p/ls-R") or next;
            while (<F>) {
                chomp;
                $classes{$_} = 1 if (s/\.cls$//);
            }
            close(F);
        }
    }
    print "</ul>";

    if (keys %classes) {
        print "<ul>";
        print map {"<li> $_"} sort keys %classes;
        print "</ul>";
    }
}

sub _genlatex {
    my( $webName, $topic, $userName, $query) = @_;

    # twiki rendering set-up
    my $rev = $query->param( "rev" );
    my $viewRaw = $query->param( "raw" ) || "";
    my $unlock  = $query->param( "unlock" ) || "";
    my $skin    = "plain"; # $query->param( "skin" );
    my $contentType = $query->param( "contenttype" );


    my $tmpl;
    if( $TWiki::Plugins::VERSION >= 1.1 ) { 
        # Dakar interface
        my $session = $TWiki::Plugins::SESSION;
        my $store = $session->{store};

        return unless ( $store->topicExists( $webName, $topic ) );

        my $tmpl = $session->{templates}->readTemplate( 'view', $skin );
    } else {
        return unless TWiki::UI::webExists( $webName, $topic );

        $tmpl = &TWiki::Store::readTemplate( "view", $skin );
    }

    TWiki::Func::getContext()->{ 'genpdflatex' } = 1;
    
    ### from TWiki::Contrib::GenPDF::_getRenderedView

    my $text = TWiki::Func::readTopicText($webName, $topic, $rev );
    $text = TWiki::Func::expandCommonVariables($text, $topic, $webName);
        
    # $text =~ s/\\/\n/g;

    ### for compatibility w/ SectionalEditPlugin (can't override skin
    ### directives in TWiki::Func::getSkin)
    $text =~ s!<.*?section.*?>!!g;

    # protect latex new-lines at end of physical lines
    $text =~ s!(\\\\)$!$1    !g;  
    $text =~ s!(\\\\)\n!$1    \n!g;  

    $text = TWiki::Func::renderText($text);
    
    $text =~ s/%META:\w+{.*?}%//gs; # clean out the meta-data

    my $preamble = TWiki::Func::getContext->{'LMPcontext'}->{'preamble'};
    print STDERR $preamble."\n" if ($debug);

    # remove the twiki-special <nop> tag (It gets ignored in the HTML
    # parser anyway, this just cuts down on the number of error
    # messages.)
    $text =~ s!<nop>!!g;

    # use hard-disk path rather than relative url paths for images
    my $pdir = TWiki::Func::getPubDir();
    my $purlh = TWiki::Func::getUrlHost();
    my $purlp = TWiki::Func::getPubUrlPath();

    $text =~ s!<img(.*?) src="($purlh)?$purlp!<img$1 src="$pdir\/!sgi;

    # $url =~ s/$ptmp//;
    # $text =~ s!<img(.*?) src="\/!<img$1 src="$url\/!sgi;

    # add <p> tags to all paragraph breaks
    # while ($text =~ s!\n\n!\n<p />\n!gs) {}

    ## strip out all <p> tags from within <latex></latex>
    my $t2 = $text;
    # while ($text =~ m!<latex>(.*?)</latex>!gs) {
    #     my $t = $1;
    #     (my $u = $t) =~ s!\n?<p\s?\/?>!!gs;
    #     # print STDERR $t."\n".$u."\nxxxxxx\n";
    #     $t2 =~ s/\Q$t\E/$u/s;
    # }
    {                           # catch all nested <latex> tags!
        my $c = 0;
        my $txt = '';
        while ($text =~ m!\G(.*?<(/?)latex>)!gs) {
            if ($2 eq '/') {
                $c = $c - 1;
                $txt .= $1;
                if ($c == 0) {
                    (my $n = $txt) =~ s!\n?<p\s?\/?>|\n\n!!gs;
                    $t2 =~ s/\Q$txt\E/$n/;
                    $txt = '';
                }
            } else { 
                $txt .= $1 if ($c > 0);
                $c = $c + 1;
            }
        }
    }

    $text = "<html><body>".$t2."</body></html>";
    if ($debug) {
        open(F,">$htmlstore/LMP.html");
        print F $text;
        close(F);
    }

    # html parser set-up
    my %options  = ();
    my @packages = ();
    my @heads    = ();
    my @banned   = ();
    
    push(@heads,'draftcls') 
        if $query->param('draftcls');
    push(@heads,$query->param('ncol')) 
        if $query->param('ncol');
    push(@packages,split(/\,/,$query->param('packages')))
        if $query->param('packages');
    $options{document_class} = $query->param('class') 
        if $query->param('class');
    $options{font_size} = $query->param('fontsize') 
        if $query->param('fontsize');
    $options{image} = $query->param('imgscale') 
        if $query->param('imgscale');
    
    $options{paragraph} = 0;

    my $parser = new HTML::LatexLMP();
    
    $parser->set_option(\%options);
    $parser->add_package(@packages);
    $parser->add_head(@heads);
    $parser->ban_tag(@banned);
    $parser->set_option({ store => $htmlstore });
    # $parser->set_log('/tmp/LMP.log');
    # open(F,">/tmp/LMP.html"); print F $text; close(F);
    my $tex = $parser->parse_string($text."<p>",1);

    $tex =~ s/(\\begin\{document\})/\n$preamble\n$1/;

    # some packages, e.g. endfloat, need environments to end on their own line
    $tex =~ s/([^\n])\\end\{/$1\n\\end\{/g; 

    # if color happens to appear outside of a latex environment,
    # ensure that the color package is included.
    # SMELL: there must be a better way to do this.
    if ( ($tex =~ m/\\textcolor/) and 
         !($tex =~ m/includepackage\{color\}/) ) {
        $tex =~ s!(\\begin\{document\})!\\usepackage{color}\n$1!;
    }

    return($tex);
}

1;

__DATA__
<html><body>
    <form action="$scriptUrlPath/genpdflatex/$web/$topic">
    <table border=1>
    <tr>
    <td> Web Name: 
    <td> $web
    <tr>
    <td> Topic Name: 
    <td> $topic
    <tr> 
    <td> Latex document style:
    <td>
    <select name="class">
    <option value="$style">$style</option>
    <option value="article">Generic Article</option>
    <option value="book">Book</option>
    <option value="IEEEtran">IEEE Trans</option>
    <option value="ismrm">MRM / JMRI (ISMRM)</option>
    <option value="cmr">Concepts in MR</option>
    <option value="letter">Letter</option>
    </select>
    <tr> 
    <td> Number of columns per page:
    <td>
    <input type="radio" name="ncol" value="onecolumn" checked="on" /> 1 column
     <input type="radio" name="ncol" value="twocolumn" /> 2 column
    <tr>
    <td> Font size:
    <td>
    <select name="fontsize">
    <option value="10"> 10pt </option>
    <option selected="true" value="11"> 11pt </option>
    <option value="12"> 12pt </option>
    </select>
    <tr>
    <td>Draft? (typically, double-spaced <br> with end-floats)
    <td>
    <input type="checkbox" name="draftcls" checked="on" />
    <tr>
    <td>Additional packages to include:
    <td><input name="packages" type="text" size="40" value="$packages" ></input>
    <tr>
    <td>Output file type:
    <td>
    <table>
    <tr><td><input type="radio" name="output" checked="on" value="latex" /> latex .tex file
    <tr><td><input type="radio" name="output" value="pdf" /> pdflatex PDF file
    <tr><td><input type="radio" name="output" value="srczip" /> ZIP file (.tex + attachments)
    </table>
    <tr>
    <td>
    <td>
    <input type="submit" value="Produce PDF/Latex" />
    </table>
    </form>
</body></html> 
