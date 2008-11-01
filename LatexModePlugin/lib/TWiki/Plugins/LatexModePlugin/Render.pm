# LatexModePlugin::Render.pm
# Copyright (C) 2005-2006 W Scott Hoge, shoge at bwh dot harvard dot edu
# Copyright (C) 2002 Graeme Lufkin, gwl@u.washington.edu
#
# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
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

package TWiki::Plugins::LatexModePlugin::Render;

use strict;

use vars qw( $EXT );

my $debug = $TWiki::Plugins::LatexModePlugin::debug;

use Digest::MD5 qw( md5_hex );

#we use the basename() function to determine which script is running
use File::Copy qw( move copy );
use File::Temp;

# use Image::Info to identify image size.
use Image::Info qw( image_info );


######################################################################
### installation specific variables:

my $pathSep = ($^O =~ m/^Win/i) ? "\\" : '/' ;

my $PATHTOLATEX = $TWiki::cfg{Plugins}{LatexModePlugin}{latex} ||
    '/usr/share/texmf/bin/latex';
my $PATHTOPDFLATEX = $TWiki::cfg{Plugins}{LatexModePlugin}{pdflatex} ||
    '/usr/share/texmf/bin/pdflatex';
my $PATHTODVIPS = $TWiki::cfg{Plugins}{LatexModePlugin}{dvips} ||
    '/usr/share/texmf/bin/dvips';
my $PATHTOCONVERT = $TWiki::cfg{Plugins}{LatexModePlugin}{convert} ||
    '/usr/X11R6/bin/convert';
my $PATHTODVIPNG = $TWiki::cfg{Plugins}{LatexModePlugin}{dvipng} ||
    '/usr/share/texmf/bin/dvipng';
my $PATHTOMIMETEX = $TWiki::cfg{Plugins}{LatexModePlugin}{mimetex} ||
    '/usr/local/bin/mimetex';

my $DEFAULTENGINE = $TWiki::cfg{Plugins}{LatexModePlugin}{engine} ||
    'dvipng';  # options: 'dvipng', 'ps', 'pdf', 'mimetex'

my $DISABLE = $TWiki::cfg{Plugins}{LatexModePlugin}{donotrenderlist} ||
    'input,include,catcode';
my @norender = split(',',$DISABLE);

my $tweakinline = $TWiki::cfg{Plugins}{LatexModePlugin}{tweakinline} || 
    0;

my $GREP =  $TWiki::cfg{Plugins}{LatexModePlugin}{fgrep} ||
    $TWiki::fgrepCmd ||
    '/usr/bin/fgrep';

# This is the extension/type of the generated images. Valid types
# are png, and gif.
$EXT = $TWiki::cfg{Plugins}{LatexModePlugin}{imagetype} || 'png';

### The variables below this line will likely not need to be changed
######################################################################

#this is the name of the latex file created by the program.  You shouldn't
#need to change it unless for some bizarre reason you have a file attached to
#a TWiki topic called twiki_math or twiki_math.tex
my $LATEXBASENAME = 'twiki_math';
my $LATEXFILENAME = $LATEXBASENAME . '.tex';


#this variable gives the length of the hash code.  If you switch to a different
#hash function, you will likely have to change this
my $HASH_CODE_LENGTH = 32;

### the following are sandbox templates
my $dvipngargs = " -D %DENSITY|N% -T tight".
    " --%EXT|S%".
    " -gamma %GAMMA|N%".
    " -pp %NUM|N% -o %OUTIMG|F% %DVIFILE|F% "; # >> %LOG|F% 2>&1";

my $dvipsargs = " -E -pp %NUM|N% -o %EPS|F% %DVI|F% ";
    # ">> %LOG|F% 2>&1 ";

my $convertargs = " -density %DENSITY|N%".
    "  %EPS|F% -antialias -trim -gamma %GAMMA|N% ";
## note: below, %OUTIMG|F% is appended to $convertargs 

## # this hash table is used to store declared markup options 
## # to be used during rendering (e.g. in-line vs. own-line equations)
my %markup_opts = ();

my $sandbox =  $TWiki::sharedSandbox || $TWiki::sandbox;
# $TWiki::Plugins::LatexModePlugin::sandbox;

# sub _writeOpts {
# ## 
#     my ($web,$topic,$s1,$s2) = @_;
#     my $fn = &TWiki::Func::getPubDir() . "/".$web.'/'.$topic.'/mapping.txt';
#     open(F, ">>$fn") or return;
#     print F `date`;
#     print F "\t".$s1."\n";
#     print F "-"x70;
#     print F "\n".$s2."\n";
#     print F "x"x70;
#     print F "\n";
#     close(F);
#          
# }

# =========================
sub handleLatex
{
# This function takes a string of math, computes its hash code, and returns a
# link to what will be the image representing this math.
### my ( $math_string ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    my $math_string = $_[0];	
    my $escaped = $_[0];
    my $prefs = $_[1];

    my %LMPc = %{ TWiki::Func::getContext()->{'LMPcontext'} };

    my %eqnrefs = defined(%{ $LMPc{'eqnrefs'} }) ? %{$LMPc{'eqnrefs'}} : ();

    # remove latex-common HTML entities from within math env
    $math_string =~ s/\<br\s*\/\>//og;
    $math_string =~ s/&amp;/&/og;
    $math_string =~ s/&lt;/\</og;    
    $math_string =~ s/&gt;/\>/og;    

    # set default rendering parameters
    my %opts = ( 'inline' => 0, 
                 'density' => $LMPc{'default_density'}, 
                 'gamma' =>   $LMPc{'default_gamma'}, 
                 'scale' =>   $LMPc{'default_scale'},
                 'bgcolor' => 'white',
                 'engine' => $DEFAULTENGINE,
                 'color' => 'black',
                 'web' => $LMPc{'web'},
                 'topic' => $LMPc{'topic'}
                 );

    my %opts2 = TWiki::Func::extractParameters( $prefs );
    # map { $opts{$_} = $opts2{$_} } keys %opts2;
    if( exists($opts2{'attachment'}) ){
        $opts{'gamma'} = 1.0;   # use a different default gamma for images
    }
    foreach my $k (keys %opts2) {
        my $b = $opts2{$k};

        # remove leading/trailing whitespace from key names
        (my $a = $k) =~ s/^\s*|\s*$//;

        # scrub the inputs, since this gets passed to 'convert' (in
        # particular, shield against 'density=166|cat%20/etc/passwd'
        # type inputs). alpha-numeric OK. slash, space, and brackets
        # are valid in preamble. need semi-colon in eqn lables!
        # allow '-' and '_' in eqn labels too.
        $b =~ m/([\.\\\w\s\:\-\_\{\}]+)/; 
        $b = $1;

        $opts{$a} = $b;

        $LMPc{'use_color'} = 1 if ( ($a eq 'color') || ($a eq 'bgcolor'));
    }
    if ( ($LMPc{'use_color'} == 1) and !( $LMPc{'preamble'} =~ m/ackage\{color/) ) {
        $LMPc{'preamble'} = "\\RequirePackage{color}\n".$LMPc{'preamble'};
    }
    if ( ( $LMPc{'preamble'} =~ m/package\{color/i) and 
         !($LMPc{'preamble'} =~ m/definecolor\{Red/) ) {

        $LMPc{'preamble'} .= <<'COLORS';

        \definecolor{Red}{rgb}{1,0,0}
        \definecolor{Blue}{rgb}{0,0,1}
        \definecolor{Yellow}{rgb}{1,1,0}
        \definecolor{Orange}{rgb}{1,0.4,0}
        \definecolor{Pink}{rgb}{1,0,1}
        \definecolor{Purple}{rgb}{0.5,0,0.5}
        \definecolor{Teal}{rgb}{0,0.5,0.5}
        \definecolor{Navy}{rgb}{0,0,0.5}
        \definecolor{Aqua}{rgb}{0,1,1}
        \definecolor{Lime}{rgb}{0,1,0}
        \definecolor{Green}{rgb}{0,0.5,0}
        \definecolor{Olive}{rgb}{0.5,0.5,0}
        \definecolor{Maroon}{rgb}{0.5,0,0}
        \definecolor{Brown}{rgb}{0.6,0.4,0.2}
        \definecolor{Black}{gray}{0}
        \definecolor{Gray}{gray}{0.5}
        \definecolor{Silver}{gray}{0.75}
        \definecolor{White}{gray}{1}

COLORS
    }

    &TWiki::Func::writeDebug( "- LatexModePlugin::handleLatex( ".
                              $math_string . " :: ". 
                              join('; ',map{"$_ => $opts{$_}"}keys(%opts)). 
                              " )" ) if $debug;

    my $txt;

    if( exists($opts{'label'}) ) {
        ( $opts{'label'} = "eqn:".$opts{'label'} )
            # unless ( substr($opts{'label'},0,4) eq 'eqn:' );
            unless ($opts{'label'} =~ m/^eqn?:/ );
    }

    if ( exists(TWiki::Func::getContext()->{'genpdflatex'}) ) {

        if( exists($opts{'label'}) ) {
            # strip off any 'displaymath' calls
            $math_string =~ s!\\\[|\\\]!!g; 
            $math_string =~ s!\\(begin|end)\{displaymath\}!!g;

            if ($math_string =~ m/eqnarray(\*?)/) {

                # try to handle equation arrays.
                if ($1 eq '*') {
                    $math_string =~ s/eqnarray\*/eqnarray/g;
                    
                    # leave no numbers ...
                    $math_string =~ s!\\\\!\\nonumber \\\\!g;
                    # except for the last one
                }
                # slip the label in..
                my $lbl = '\label{'.$opts{'label'}.'}';
                $math_string =~ s/(begin\{.*?\})/$1$lbl/;

            } else {
                $math_string = "\n\\begin{equation}\n".
                    '    \label{'.$opts{'label'}."}"."\n".
                    "    ".$math_string."\n".
                    "\\end{equation}\n";
            }
        }
        # strip off all comments
        $math_string =~ s!\\%!LMPpcntLMP!g;
        $math_string =~ s!%.*?\n!!gs;
        $math_string =~ s!LMPpcntLMP!%!g;

        # in Cairo (at least) latex new-lines, '\\', get translated to 
        # spaces, '\', if they appear at the end of the line.
        # So protect them here...
        $math_string =~ s!\n!  \n!g;
        $txt = '<latex>'.$math_string.'</latex>';

        
    } else {

        # compute the MD5 hash of this string, using both the markup text
        # and the declared options.
        my $hash_code = md5_hex( $math_string . 
                                 join('; ', sort map{"$_=>$opts{$_}"} keys(%opts)) );
        # _writeOpts($LMPc{"web"},$LMPc{"topic"},$hash_code,
        #            $math_string .' :: '. 
        #            join('; ', sort map{"$_=>$opts{$_}"} keys(%opts)));

        if ( ($opts{'inline'} eq 1) and ($tweakinline) ) {

            if ($tweakinline eq 2) {
                ### this goes with the new trimInline code (v >= 3.6)
                ### 
                if ($opts{'engine'} eq 'mimetex') {
                    $math_string = '\cdot \ '.$math_string.' \ \cdot ';
                } else {
                    $math_string = '$\cdot$ '.$math_string.' $\cdot$';
                }
            } else {
                ### this goes with the old trimInline code (v < 3.6)
                ### 
                $math_string = '\fbox{ \ ' . $math_string;
                if ($opts{'engine'} ne 'mimetex') {
                    $math_string .= '\vphantom{$\sqrt{\{ \}^{T^T}}$}' ;
                }
                $math_string .= ' \ }';
            } 
        }
        #store the string in a hash table, indexed by the MD5 hash
        $LMPc{'hashed_math_strings'}->{$hash_code} = $math_string;
        
        
        ### store the declared options for the rendering later...
        # $LMPc{'markup_opts'}{$hash_code} = \%opts;
        $markup_opts{$hash_code} = \%opts;
        

        # replace troublesome characters in the string, so the alt tag
        # doesn't break:
        $escaped =~ s/\"/&quot;/gso;
        $escaped =~ s/\n/ /gso;
        $escaped =~ s!\&!\&amp\;!g;
        $escaped =~ s!\>!\&gt\;!g;
        $escaped =~ s!\<!\&lt\;!g;    
        # and NOP the WikiWords:
        $escaped =~ s!(\u\w\l\w+\u\w)!<nop>$1!g;

        my $image_name =  join('/', ( &TWiki::Func::getPubUrlPath(),
                                      $LMPc{'web'}, $LMPc{'topic'},
                                      "latex$hash_code.$EXT" ) );
        
        # if image currently exists, get its dimensions
        my $outimg = &TWiki::Func::getPubDir() . "/".$LMPc{'web'}.'/'.$LMPc{'topic'}."/"."latex$hash_code.$EXT";
        my $str = "";
        if ( !($LMPc{'rerender'}) and (-f $outimg) ) {
            my $img = image_info($outimg);
            $str = sprintf("width=\"%d\" height=\"%d\"",
                           ($opts{'scale'} * $img->{width} ),
                           ($opts{'scale'} * $img->{height})  );
            undef($img);
        }
        
        #return a link to an attached image, which we will create later
        if( ($opts{'inline'} eq 1) or 
            ($opts{'inline'} eq "on") or 
            ($opts{'inline'} eq "true") ) {

            my $algn;
            if ($tweakinline) {
                $algn = 'middle';
            } else {
                $algn = ($escaped =~ m/[\_\}\{]|[yjgpq]/) ? 'middle' : 'bottom' ;
            }
            $txt = "<img style=\"vertical-align:$algn;\" align=\"$algn\" $str src=\"$image_name\" alt=\"$escaped\" />"; 

        } elsif( exists($opts{'label'}) ) {
            $LMPc{'eqn'}++;
            
            $txt = '<a name="'.$opts{'label'}.'"></a>'.
                '<table width="100%" border=0><tr>'."\n".
                '<td width=10>&nbsp;</td>'.
                '<td width="100%" align="center">'.
                "<img src=\"$image_name\" $str alt=\"$escaped\" /></td>".
                "<td width=10>(".
                '<a href="#'.$opts{'label'}.'" title="'.$opts{'label'}.'">'.
                $LMPc{'eqn'}.
                '</a>'.
                ")</dt></tr></table>\n";
            
            if ( exists( $eqnrefs{ $opts{'label'} } ) ) {
                $LMPc{'error_catch_all'} .= 
                    "&nbsp;&nbsp;&nbsp;Error! multiple equation labels '$opts{'label'}' defined.\n".
                    "(Eqns. $eqnrefs{$opts{'label'}} and ".$LMPc{'eqn'}.")<br>\n";
            } else {
                $eqnrefs{ $opts{'label'} } = $LMPc{'eqn'};
            }

        } else {
            $txt = "<div align=\"center\"><img src=\"$image_name\" $str alt=\"$escaped\" /></div>";
        }
        $LMPc{'eqnrefs'} = \%eqnrefs;
        TWiki::Func::getContext()->{'LMPcontext'} = \%LMPc;

    }  # end 'if !$latexout';

    return($txt);
}

sub createTempLatexFiles {

    my %hashed_math_strings = %{ $_[0] };

    my %LMPc = %{ &TWiki::Func::getContext()->{'LMPcontext'} };
    # print STDERR '-'x70; print STDERR "\n";

    my $pdf_image_number = 0;   # initialize the image count
    my $dvi_image_number = 0;   # initialize the image count

    #this hash table maps the digest strings to the output filenames
    my %pdf_hash_code_mapping = ();
    my %dvi_hash_code_mapping = ();
    my %mimetex_hash_code_mapping = ();

    #create the intermediate latex file
    do { $_[0] .= "<BR>can't write $LATEXFILENAME: $!\n"; 
         return; } unless open( DVIOUT, ">$LATEXFILENAME" );

    my $PDFLATEXFILENAME = 'pdf_'.$LATEXFILENAME;
    do { $_[0] .= "<BR>can't write $PDFLATEXFILENAME: $!\n"; 
         return; } unless open( PDFOUT, ">$PDFLATEXFILENAME" );

    # disable commands flagged as 'do not render'
    # e.g. lock-out the inclusion of other files via input/include
    foreach my $c (@norender) {
        $LMPc{'preamble'} =~ s!\\$c\b!\\verb-\\-$c!g;
    }

    my $txt = '';
    if ( TWiki::Func::getContext()->{'LMPcontext'}->{'docclass'} ) {
        $txt .= TWiki::Func::getContext()->{'LMPcontext'}->{'docclass'}."\n";
    } else {
        $txt .= "\\documentclass{article}\n";
    }
    $txt .= $LMPc{'preamble'}."\n\\begin{document}\n\\pagestyle{empty}\n";
    print DVIOUT $txt;
    print PDFOUT $txt;
    
    while( (my $key, my $value) = each( %hashed_math_strings ) ) {
        
        # restore the declared rendering options
        my %opts = %{ $markup_opts{$key} };
        # my %opts = defined($LMPc{'markup_opts'}{$key}) ? %{$LMPc{'markup_opts'}{$key}} : ();

        $value =~ s/\n\s*?\n/\n/gs;
        # disable commands flagged as 'do not render'
        # e.g. lock-out the inclusion of other files via input/include
        foreach my $c (@norender) {
            $value =~ s!\\$c\b!\\verb-\\-$c!g;
        }

        if( exists($opts{'attachment'}) ) {
            # copy image attachments to the working directory

            my ($ext,$af) = ('','');
            my @extlist = ('','.eps','.eps.gz','.pdf','.png','.jpg');
            if ( ( $TWiki::Plugins::VERSION < 1.1 ) or
                 ( $TWiki::cfg{Plugins}{LatexModePlugin}{bypassattach}) ) { 
                # Cairo interface
                
                $af = join( $pathSep, &TWiki::Func::getPubDir(),
                            $LMPc{'web'}, $LMPc{'topic'},
                            $opts{'attachment'} );
                
                $af = TWiki::Sandbox::normalizeFileName( $af );

                foreach my $e (@extlist) {
                    $ext = $e;
                    if (-f $af.$ext) {
                        &TWiki::Func::writeDebug( "LatexModePlugin: copy ".$af.$ext ) 
                            if ($debug);
                        # copy( $af.$ext, $LATEXWDIR ) || do {
                        copy( $af.$ext, "." ) || do {
                            &TWiki::Func::writeDebug( "LatexModePlugin: copy failed ".$! );
                            $value = "attachment \{".$markup_opts{$key}->{'attachment'}."\} \ not found";
                        };
                        $markup_opts{$key}->{'attachment'} .= $ext;
                        
                        if ($ext ne '') {
                            # if the Plugin chooses the extension, then
                            # set the rendering engine as well.
                            if ($ext =~ m/\.eps/) {
                                $markup_opts{$key}->{'engine'} = 'ps';
                            } else {
                                $markup_opts{$key}->{'engine'} = 'pdf';
                            }
                        }

                        last;
                    }
                }                
            } else {
                # Dakar interface
                my $ext;
                my $af= $opts{'attachment'};
                foreach my $e (@extlist) {
                    $ext = $e;
                    if ( TWiki::Func::attachmentExists( $LMPc{'web'},
                                                        $LMPc{'topic'},
                                                        $af.$ext ) ) {
                        
                        $markup_opts{$key}->{'attachment'} .= $ext;
                        if ($ext ne '') {
                            # if the Plugin chooses the extension, then
                            # set the rendering engine as well.
                            if ($ext =~ m/\.eps/) {
                                $markup_opts{$key}->{'engine'} = 'ps';
                            } else {
                                $markup_opts{$key}->{'engine'} = 'pdf';
                            }
                        }

                        open(F,">".'.'.$pathSep.$af.$ext);
                        print F TWiki::Func::readAttachment( $LMPc{'web'},
                                                             $LMPc{'topic'},
                                                             $af.$ext );
                        close(F);
                        last;
                    }
                }
            }
        } # end of copy attachment piece
        $value = " (attachment ".$markup_opts{$key}->{'attachment'}." not found) "
            if ( exists($markup_opts{$key}->{'attachment'}) and
                 !(-f $markup_opts{$key}->{'attachment'}) );


        &TWiki::Func::writeDebug( "LatexModePlugin: ".
                                  $value . " :: " .
                                  join('; ', sort map{"$_=>$opts{$_}"} keys(%opts))
                                  ) if ($debug);
        $txt = "\n\\clearpage\n";
        # $txt .= "% $LATEXBASENAME.$EXT.$image_number --> $key \n";
        $txt .= "% $key \n";
        $txt .= '\pagecolor{'.$opts{'bgcolor'}."} \n" if ($LMPc{'use_color'} == 1 );
        $txt .= '\textcolor{'.$opts{'color'}.'}{' if ($LMPc{'use_color'} == 1 );
        $txt .= " $value ";
        $txt .= '}' if ($LMPc{'use_color'} == 1);

        if ( $markup_opts{$key}->{'engine'} eq 'pdf' ) {
            print PDFOUT $txt;
            $pdf_image_number++;
            $pdf_hash_code_mapping{$key} = $pdf_image_number;
        } elsif ( $markup_opts{$key}->{'engine'} eq 'mimetex' ) {
            ### mimetex just does math
            my $MIMELATEXFILENAME = $key.'.txt';
            do { $_[0] .= "<BR>can't write $MIMELATEXFILENAME: $!\n"; 
                 return; } unless open( MIMEOUT, ">$MIMELATEXFILENAME" ) ;

            # mimetex assumes all input is mathmode
            $value =~ s/\$(.*?)\$/$1/;
            $value =~ s/\$\$(.*?)\$\$/$1/;
            $value =~ s/\\\[(.*?)\\\]/$1/;

            print MIMEOUT '\\'.$opts{'color'}.' ' if ($LMPc{'use_color'} == 1);
            print MIMEOUT $value;
            close MIMEOUT;
            $mimetex_hash_code_mapping{$key} = 1;
        } else {
            print DVIOUT $txt;
            $dvi_image_number++;
            $dvi_hash_code_mapping{$key} = $dvi_image_number;
        }
    }
    $txt = "\n\\clearpage\n(end)\n\\end{document}\n";
    print DVIOUT $txt; close( DVIOUT );
    print PDFOUT $txt; close( PDFOUT );

    return( \%dvi_hash_code_mapping, \%pdf_hash_code_mapping, 
            \%mimetex_hash_code_mapping );
}

# =========================

sub renderEquations {

    my %LMPc = %{ &TWiki::Func::getContext()->{'LMPcontext'} };
    # print STDERR '-'x70; print STDERR "\n";
    # print STDERR map {"$_ => $LMPc{$_}\n"} keys %LMPc;
    # print STDERR '+'x70; print STDERR "\n";
    # print STDERR map {"$_ => $LMPc{'figrefs'}{$_}\n"} keys %{ $LMPc{'figrefs'} };
    # print STDERR '-'x70; print STDERR "\n";

    my $path;

    &TWiki::Func::writeDebug( " TWiki::LatexModePlugin::renderEquations( ".$LMPc{'web'}.'.'.$LMPc{'topic'}." )" ) if $debug;

    #my @revinfo = &TWiki::Func::getRevisionInfo($web, $topic, "", 0);
    #&TWiki::Func::writeDebug( "- LatexModePlugin: @revinfo" ) if $debug;

    #check if there was any math in this document
    return unless defined( $LMPc{'hashed_math_strings'} );
    # return unless scalar( keys( %hashed_math_strings ) );

    ## 'halt-on-error' is not supported in older versions of tetex, so check to see if it exists:
    ## 
    my ($resp,$exit);
    if (-x $PATHTOLATEX) {
        ($resp,$exit) = $sandbox->sysCommand("$PATHTOLATEX ".' --help');
    } elsif (-x $PATHTOPDFLATEX) {
        ($resp,$exit) = $sandbox->sysCommand("$PATHTOPDFLATEX ".' --help');
    }
    if ($resp =~ m/halt\-on\-error/) {
        $LMPc{'haltonerror'} = ' -halt-on-error ';
    } else {
        $LMPc{'haltonerror'} = ' ';
    }
    # print STDERR $LMPc{'haltonerror'}."\n";


    my %hashed_math_strings = %{ $LMPc{'hashed_math_strings'} };

    # &TWiki::Func::writeDebug( join(" ", keys(%hashed_math_strings) ) ) if ($debug);

    return unless length(keys(%hashed_math_strings)) > 0;


    $_[0] .= "\n<hr>TWiki LatexModePlugin error messages:<br>\n".
        $LMPc{'error_catch_all'} if ( length($LMPc{'error_catch_all'}) > 0 );


    #if this is a view script, then we will try to delete old files
    my $delete_files = ( &TWiki::Func::getContext()->{'view'} ) || 0;

    my %extfiles = ();
    $path = &TWiki::Func::getPubDir() . "/".$LMPc{'web'}.'/'.$LMPc{'topic'};
    if ( ( $TWiki::Plugins::VERSION < 1.1 )  or
         ( $TWiki::cfg{Plugins}{LatexModePlugin}{bypassattach}) ) {
        # Cairo interface
        opendir(D,$path);
        my @a = grep(/\.$EXT$/,readdir(D));
        for my $c (0 .. $#a) {
            $extfiles{$c}->{name} = $a[$c-1];
            $extfiles{$c}->{date} =  (stat( $path.$pathSep.$a[$c-1] ))[9];
        }
        closedir(D);
    } else { 
        # Dakar interface
        my ( $meta, undef ) = TWiki::Func::readTopic( $LMPc{'web'}, $LMPc{'topic'} );

        if ( defined( $meta->{FILEATTACHMENT} ) ) {
            foreach my $c ( @{ $meta->{FILEATTACHMENT} } ) {
                $extfiles{$c}->{name} = $c->{name};
                $extfiles{$c}->{date} = $c->{date} || 0;
            }
        }

    }

    &TWiki::Func::writeDebug( "LatexModePlugin::Render - Scanning file attachments" ) if $debug;
    &TWiki::Func::writeDebug( " pre-hashes: ".join(' ',keys(%hashed_math_strings) ) ) if $debug;

    foreach my $a ( keys %extfiles ) {
        my $fn = $extfiles{$a}->{name}; # ( $TWiki::Plugins::VERSION >= 1.1 ) ? $a->{name} : $a;

        &TWiki::Func::writeDebug( "\n-- $fn --\n" ) if ($debug);

        # print STDERR "$fn : ". ($extfiles{$a}->{date}) ."  ".time." \n";
        
        # was the image likely generated by this plugin?
        if( $fn =~ m/^latex[0-9a-f]+\.$EXT$/ ) {

            my $hash_code = substr( $fn, 5, $HASH_CODE_LENGTH );

            #is the image still used in the document?
            if( exists( $hashed_math_strings{$hash_code} ) ) {
                #if the image is already there, we don't need to re-render
                delete( $hashed_math_strings{$hash_code} )
                    unless ($LMPc{'rerender'});
                next;
            }

            # print STDERR "( ".(time - $extfiles{$a}->{date})." > 100 ) \n";
            if( $delete_files   # flag is set
                &&              # and
                ( (time - $extfiles{$a}->{date}) > 100 ) # file is old
                ) {

                #delete the old image
                &TWiki::Func::writeDebug( "Deleting old image that I think belongs to me: $fn ".(-f $path.$pathSep.$fn) ) if $debug;
                if ( $fn =~ /^([-\@\w.]+)$/ ) { # untaint filename
                    $fn = TWiki::Sandbox::normalizeFileName($1);
                    
                    if ( ( $TWiki::Plugins::VERSION < 1.1 ) or
                         ( $TWiki::cfg{Plugins}{LatexModePlugin}{bypassattach}) ) { 
                        # Cairo interface
                        unlink( $path.$pathSep.$fn ) if (-f $path.$pathSep.$fn);
                    } else {
                        # Dakar interface
                        TWiki::Func::moveAttachment( $LMPc{'web'},
                                                     $LMPc{'topic'}, 
                                                     $fn,
                                                     $TWiki::cfg{TrashWebName},
                                                     'TrashAttachment', $fn )
                            if (-f $path.$pathSep.$fn); # should be replaced by attacmentexists? function
                      }
                }
            }
        }
    }
    &TWiki::Func::writeDebug( " post-hashes: ".join(' ',keys(%hashed_math_strings) ) ) if $debug;

    # for INCLUDED pages, check to see if each image exists already on TWiki. 
    # remove from list of strings to create if it does.
    foreach my $key (keys %hashed_math_strings) {
        my $w = $markup_opts{$key}->{'web'};
        my $t = $markup_opts{$key}->{'topic'};

        my $path = &TWiki::Func::getPubDir() .$pathSep.$w.$pathSep.$t.$pathSep;
        if ( ( $TWiki::Plugins::VERSION < 1.1 )  or
             ( $TWiki::cfg{Plugins}{LatexModePlugin}{bypassattach}) ) {
            # Cairo interface
            if ( (-f $path.'latex'.$key.'.'.$EXT ) and 
                 !($LMPc{'rerender'}) ) {
                delete( $hashed_math_strings{$key} ); }
            
        } else { 
            # Dakar interface
            if ( TWiki::Func::attachmentExists($w,$t,'latex'.$key.'.'.$EXT) and 
                 !($LMPc{'rerender'}) ) {
                delete( $hashed_math_strings{$key} ); }

        }
    }  

    #check if there are any new images to render
    if ( scalar( keys( %hashed_math_strings ) ) == 0 ) {
        TWiki::Func::getContext()->{'LMPcontext'}->{'hashed_math_strings'} = ();
        return;
    }

    # create a temporary working directory
    my $LATEXWDIR = File::Temp::tempdir();

    &TWiki::Func::writeDebug( "LatexModePlugin working directory: $LATEXWDIR" ) if $debug;

    ### create the temporary Latex Working Directory...
    #does the topic's attachment directory exist?
    if( -e $LATEXWDIR ) {
        #if it's not really a directory, we can't do anything
        return unless ( -d $LATEXWDIR );

        # FIXME: this section should never be called, but should
        # report an error in the event that it does
        &TWiki::Func::writeDebug( "Directory already exists." ) if $debug;
    } else {
        #create the directory if it didn't exist
        return unless mkdir( $LATEXWDIR );
        &TWiki::Func::writeDebug( " Directory $LATEXWDIR does not exist" ) if $debug;
    }
    # move into the temprorary working directory
    # use Cwd 'cwd';
    # (my $saveddir = cwd) =~ s/^([-\@\w.]+)$/$1/; 
    # $saveddir now untainted

    my $LATEXLOG = File::Temp::tempnam( $LATEXWDIR, 'latexlog' );

    do { $_[0] .= "<BR>unable to access latex working directory.";
         return; } unless chdir( $LATEXWDIR );
    # system("echo \"$LATEXWDIR\n^O\n\" > $LATEXLOG");
    open(LF,">$LATEXLOG");
    print LF "$LATEXWDIR\n\n";
    close(LF);

    my ($dvim, $pdfm, $mimem) = createTempLatexFiles( \%hashed_math_strings );
    my %dvi_hash_code_mapping = %{ $dvim };
    my %pdf_hash_code_mapping = %{ $pdfm };
    my %mimetex_hash_code_mapping = %{ $mimem };

    # generate the output images by running latex-dvips-convert on the file
    # system("$PATHTOLATEX -interaction=nonstopmode -halt-on-error $LATEXFILENAME >> $LATEXLOG 2>&1");
    if ( scalar(%pdf_hash_code_mapping) ) {
        $sandbox->sysCommand("$PATHTOPDFLATEX ".
                             ' -interaction=nonstopmode '.
                             $LMPc{'haltonerror'}.
                             ' %FILE|F% ',
                             FILE => 'pdf_'.$LATEXFILENAME
                             );
        (my $log = 'pdf_'.$LATEXFILENAME) =~ s/\.tex$/\.log/;
        my ($resp,$ret) = $sandbox->sysCommand( $GREP.' -A 2 Error %LOG|F%',
                                                LOG => $LATEXWDIR.$pathSep.$log );
        ### report errors on 'preview' and 'save'
        if ( ( TWiki::Func::getContext()->{'preview'} ) || 
             ( TWiki::Func::getContext()->{'save'} ) ) {
            
            $_[0] .= "\n<hr>Latex rendering error messages:<pre>$resp</pre>\n" 
                if ( ( length($resp) > 0 ) or ( $ret > 0 ) );
        }
    }
    if ( scalar(%dvi_hash_code_mapping) ) {
        $sandbox->sysCommand("$PATHTOLATEX ".
                             ' -interaction=nonstopmode '.
                             $LMPc{'haltonerror'}.
                             ' %FILE|F% ',
                             FILE => $LATEXFILENAME
                             );

        ### report errors on 'preview' and 'save'
        if ( ( TWiki::Func::getContext()->{'preview'} ) || 
             ( TWiki::Func::getContext()->{'save'} ) ) {
            # my $resp = `$GREP -A 3 -i "!" $LATEXLOG`;
            (my $logf = $LATEXFILENAME) =~ s/\.tex$/\.log/;
            # $sandbox->{TRACE} = 1;
            
            my ($resp,$ret) = $sandbox->sysCommand( $GREP.' -A 1 ! %LOG|F%',
                                                    LOG => $LATEXWDIR.$pathSep.$logf );
            $_[0] .= "\n<hr>Latex rendering error messages:<pre>$resp</pre>\n" 
                if ( ( length($resp) > 0 ) or ( $ret > 0 ) );
            # $sandbox->{TRACE} = 0;
        }
    }

    if (%dvi_hash_code_mapping) {
        if ( -f $LATEXBASENAME.".dvi" ) {
            &makePNGs( \%dvi_hash_code_mapping, 
                       $LMPc{'topic'}, $LMPc{'web'}, 
                       $LATEXLOG, $LATEXWDIR );
        } else {
            $_[0] .= "<br>Latex rendering error!! dvi file was not created.<br>";
        }
    }
    if (%mimetex_hash_code_mapping) {
        &TWiki::Func::writeDebug( "mimetex: ".
           join(' ',keys %mimetex_hash_code_mapping) ) if $debug;

        &makePNGs( \%mimetex_hash_code_mapping, 
                   $LMPc{'topic'}, $LMPc{'web'}, 
                   $LATEXLOG, $LATEXWDIR );
        
    }
    if (%pdf_hash_code_mapping) {
        if ( -f 'pdf_'.$LATEXBASENAME.".pdf" ) {
            &makePNGs( \%pdf_hash_code_mapping, 
                       $LMPc{'topic'}, $LMPc{'web'}, 
                       $LATEXLOG, $LATEXWDIR );
        } else {
            $_[0] .= "<br>Latex rendering error!! pdf file was not created.<br>"
            }
    }

    #clean up the intermediate files
    unless ($debug) {
        opendir(D,$LATEXWDIR);
        my @files = grep(/$LATEXBASENAME/,readdir(D));
        close(D);

        while( (my $key, my $value) = each( %hashed_math_strings ) ) {
            my %opts = %{ $markup_opts{$key} };
            
            if( exists($opts{'attachment'}) ) {
                # delete image attachments from the working directory
                my $af = join( '/', $LATEXWDIR,
                               $opts{'attachment'} );
                unlink($af);
            }
            
            if ( $opts{'engine'} eq 'mimetex' ) {
                unlink( $key.'.txt' ) if (-f $key.'.txt');
            }

        }

	foreach my $fn ( @files ) { 
            #again, we need to untaint the globbed filenames
            # next if ($fn =~ /index/);
            if( $fn =~ /^([-\@\w.]+)$/ ) {
                $fn = $1; # $fn now untainted
                unlink( "$fn" );
            } else {
                &TWiki::Func::writeDebug( "Bizzare error.  match of \$fn failed? $fn" ) if $debug;
            }
	}
    }

    #clear the hash table of math strings
    $LMPc{'hashed_math_strings'} = ();
    # $LMPc{'markup_opts'} = ();
    %markup_opts = ();
    &TWiki::Func::writeDebug( "Math strings reset, done." ) if $debug;

    # remove the log file
    unlink($LATEXLOG) unless ($debug);

    # remove the temporary working directory
    rmdir($LATEXWDIR);
    $LATEXWDIR = undef;
    # move back to the previous directory.
    # chdir($saveddir) if ( $saveddir );
    TWiki::Func::getContext()->{'LMPcontext'} = \%LMPc;

}


sub makePNGs {

    my ($h,$topic,$web,$LATEXLOG,$LATEXWDIR) = @_;

    my %hash_code_mapping = %{ $h };

    #generate image files based on the hash code
    while( (my $key, my $value) = each( %hash_code_mapping ) ) {
        # restore (again) the rendering options
        # my %opts = %{ $LMPc{'markup_opts'}->{$key} };
        my %opts = %{ $markup_opts{$key} };
        
        # calculate point-to-pixel mapping (1pt/72dpi*density) 
        # == 1.61 for density=116
        my $ptsz = ($opts{'density'}/72); 
        
        my $num = $hash_code_mapping{$key};

        my $outimg = "latex$key.$EXT";

        system("echo \"engine: $opts{'attachment'} $opts{'engine'}\" >> $LATEXLOG") if (exists($opts{'attachment'}) and ($debug) );
        if (  (-x $PATHTODVIPNG) and 
              ($opts{'engine'} ne 'ps') and 
              ($opts{'engine'} ne 'mimetex') and 
              ($opts{'engine'} ne 'pdf') ) {
            # if dvipng is installed ...
            # $EXT = lc($EXT);
            # my $cmd = "$PATHTODVIPNG -D ".$opts{'density'}." -T tight".
            #     " --".$EXT.
            #     " -gamma ".($opts{'gamma'}+1.0).
            #     " -bg Transparent ".
            #     " -pp $num -o $outimg ".$LATEXBASENAME.".dvi >> $LATEXLOG 2>&1";
            # system($cmd);
            my $args = $dvipngargs;
            $args .= ' -bg transparent '; # unless ($tweakinline ne 0);
            # dvipng 1.7 uses 'transparent'
            # dvipng 1.5 uses 'Transparent'

            $sandbox->sysCommand( "$PATHTODVIPNG $args",
                                  DENSITY => $opts{'density'},
                                  EXT => lc($EXT),
                                  GAMMA => ($opts{'gamma'}+1.0),
                                  NUM => $num,
                                  DVIFILE => $LATEXBASENAME.".dvi",
                                  OUTIMG => $outimg,
                                  LOG => $LATEXLOG
                                  );

        } elsif ($opts{'engine'} eq 'pdf') {

            my $ccmd = $convertargs;
            $ccmd .= " -transparent %BGC|S% " 
                unless ( ($markup_opts{$key}{'inline'} ne 0) and
                         ($tweakinline ne 0) );
            $ccmd .= " %OUTIMG|F%";

            $sandbox->sysCommand( $PATHTOCONVERT." $ccmd",
                                  DENSITY => $opts{'density'},
                                  EPS => 'pdf_'.$LATEXBASENAME.".pdf[".($num-1)."]",
                                  EXT => lc($EXT),
                                  GAMMA => $opts{'gamma'},
                                  BGC => $opts{'bgcolor'},
                                  OUTIMG => $outimg,
                                  LOG => $LATEXLOG );

        } elsif ($opts{'engine'} eq 'mimetex') {
            my $ccmd = $PATHTOMIMETEX.' -d -f %IN|F% ';
            # my $ccmd = $PATHTOMIMETEX.' -d -f '.$key.'.txt '; # > '.$outimg;
            # `$ccmd`;
            
            my ($data,$ret) = $sandbox->sysCommand( $ccmd,
                                            IN => $key.'.txt' );
 
            if ($ret eq 0) {
                open(OI,">$outimg");
                binmode(OI);
                print OI $data;
                close(OI);
            }

            &TWiki::Func::writeDebug( $outimg ) if ($debug);

        } else {
            # OTW, use dvips/convert ...

        # system("$PATHTODVIPS -E -pp $num -o $LATEXBASENAME.$num.eps $LATEXBASENAME.dvi >> $LATEXLOG 2>&1 ");
        
        # my $cmd = "-density $opts{'density'} $LATEXBASENAME.$num.eps ";
        # $cmd .= "-antialias -trim -gamma ".$opts{'gamma'}." ";
        # $cmd .= " -transparent white " 
        #     unless ( ($markup_opts{$key}{'inline'} ne 0) and
        #              ($tweakinline ne 0) );
        # $cmd .= $outimg;
        # 
            my ($d,$e) =
                $sandbox->sysCommand( "$PATHTODVIPS $dvipsargs",
                                      NUM => $num,
                                      EPS => $LATEXBASENAME.$num.".eps",
                                      DVI => $LATEXBASENAME.".dvi",
                                      LOG => $LATEXLOG );
            # print STDERR "dvips: $d $e" if length($d) > 0;

        # system("echo \"$PATHTOCONVERT $cmd\" >> $LATEXLOG") if ($debug);
        # system("$PATHTOCONVERT $cmd");
            my $ccmd = $convertargs;
            $ccmd .= " -transparent %BGC|S% " 
                unless ( ($markup_opts{$key}{'inline'} ne 0) ); #and
                         # ($tweakinline ne 0) );
            $ccmd .= " %OUTIMG|F%";

            $sandbox->sysCommand( $PATHTOCONVERT." $ccmd",
                                  DENSITY => $opts{'density'},
                                  EPS => $LATEXBASENAME.$num.".eps",
                                  EXT => lc($EXT),
                                  GAMMA => $opts{'gamma'},
                                  BGC => $opts{'bgcolor'},
                                  OUTIMG => $outimg,
                                  LOG => $LATEXLOG );

        }
        if (-f $outimg) {
            
            if ( ($markup_opts{$key}{'inline'} ne 0)
                 and ($tweakinline) 
                 and (-x $PATHTOCONVERT) 
                 ) {
                trimInlineImage($outimg,$sandbox,$opts{'bgcolor'},
                                $LATEXWDIR,$ptsz);
            }

            ### this won't work from within makePNGs.  It should 
            ### be returned to modify the rendered topic.
            # my $img = image_info($outimg);
            # 
            # my $str = sprintf("width=\"%d.0\" height=\"%d.0\"",
            #                   ($opts{'scale'} * $img->{width}),
            #                   ($opts{'scale'} * $img->{height}) );
            # $_[0] =~ s/($outimg\")/$1 $str/;

            if ( ( $TWiki::Plugins::VERSION < 1.1 ) ||
                 ( $TWiki::cfg{Plugins}{LatexModePlugin}{bypassattach}) )
            {
                # Cairo interface
                my $path = &TWiki::Func::getPubDir() . 
                    "/".$opts{'web'}.'/'.$opts{'topic'};

                mkdir( $path.$pathSep )unless (-e $path.$pathSep);

                move($outimg,$path.$pathSep.$outimg) or 
                    $_[0] .= "<br> LatexModePlugin error: Move of $outimg failedg: $!";
            } else {
                # Dakar interface
                TWiki::Func::saveAttachment( $opts{'web'},
                                             $opts{'topic'},
                                             $outimg,
                                             { file => $outimg,
                                               comment => '',
                                               filedate => time,
                                               hide => 1 } );
                unlink($outimg) unless $debug; # delete working copy
            }                
            # undef($img);
        }
    }


}

sub trimInlineImage {
    
    if ($tweakinline eq 2) {
        trimInlineImage_v2(@_);
    } else {
        trimInlineImage_v1(@_);
    }

}

# =========================

sub trimInlineImage_v2 {

    my ($in,$sandbox,$bgcolor,$LATEXWDIR,$ptsz) = @_;

    (my $out = $in ) =~ s/\.(png|gif)/.xpm/;
    $sandbox->sysCommand("$PATHTOCONVERT %IN|F%  %OUT|F%",
                         IN => $in,
                         OUT => $out );

    my ($pre, $xpm);
    my ($canvaschar,$cpp) = (' ',1);
    my ($col, $flag, $cnt) = (0,0,0);
    my ($midu, $midl, $sum)  = (0,0,'');

    open(F,"<$out") || print STDERR $!;

    ## run through the XPM image line-by-line
    ## counting the number of lines above and below the 'cdot'
    while(<F>){
        
        if ($flag) { 
            # print length($_);
            if ($col == 0) {
                $col = (length($_)-4)/$cpp;
                $sum = '0' x $col;
                # print $sum."\n";
            }
            # print '  '.$col.'  '.($col == 0);
            $xpm .= $_;             # store the image as we go

            # count of line above 'cdot'
            $midu = $cnt if ( !(substr($_,1,$cpp) =~ m/\Q$canvaschar\E|\;/) 
                              and ($midu eq 0 ) );
            # count ending line of 'cdot'
            $midl = $cnt if ( !(substr($_,1,$cpp) =~ m/\Q$canvaschar\E|\;/) );

            $cnt += 1 if ( substr($_,0,1) eq "\""); # count the lines

            # print substr($_,1,$cpp)." $midu $cnt\n";
            
            ### form a bit-map of the pixels used to
            ### calculate the horizontal trim later.
            $_ =~ s/^\"//; $_ =~ s/\"\,?\n$//;
            # print $_."\n";
            foreach my $c ( 0 .. (length($_)/$cpp-1) ) {
                my $t = substr($_,$c*$cpp,$cpp);
                if ( ($t ne $canvaschar) or substr($sum,$c,1) == 1 ) {
                    substr($sum,$c,1,'1');
                }
            }
            # print $sum."\n";
            
        } else {
            $pre .= $_;
            if ($_ =~ m/\"(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\"/) {
                $cpp = $4;
                &TWiki::Func::writeDebug( "cpp:'".$cpp."'" ) if ($debug);
            }
            if ($_ =~ m/None|gray100/) {
                $canvaschar = substr($_,1,$cpp);
            }
            # &TWiki::Func::writeDebug( "canvaschar:'".$canvaschar."'" ) if ($debug);

        }
        $flag = 1 if m!/\*\spixels\s\*/!; # switch between 'pre' and the image
    }
    close(F);
    # print $xpm;


    # print "$cnt  $midu $midl $col\n";
    # print "blank uptop: ".($midu)."\n";
    # print "blank below: ".($cnt-$midl-1)."\n";

    my $adt = ($cnt - $midl - 1 - $midu);
    $adt = 0 if ($adt < 0);
    # print "add to top: ".$adt."\n";

    my $adb = $midu - ($cnt - $midl - 1) ;
    $adb = 0 if ($adb < 3);
    # print "add to bottom: ".$adb."\n";

    ## calculate the amount of horizontal trim 
    # print $sum ."\n";
    my ($frnt,$back) = (0,0);
    $frnt = length($1)*$cpp if ($sum =~ m/^(1+0+)/); # from the left 
    # $back = length($1)*$cpp if ($sum =~ m/(0+1+)$/); # and from the right
    $back = length($1)*$cpp if ($sum =~ m/(0+1+0{0,2})$/); # and from the right
    # print "frnt: $frnt back: $back\n";

    $pre =~ m/\"$col\s+$cnt/;
    my $nr = $cnt + $adt + $adb;      # calculate the new number of rows
    my $nc = $col - ($frnt + $back)/$cpp;  # calculate the new number of columns
    $pre =~ s/\"$col\s+$cnt/\"$nc $nr/;

    ## output the image
    open(F,">mod_$out") || print STDERR $!;
    print F $pre;
    for (1..$adt) {
        print F '"';
        print F $canvaschar x $nc;
        print F "\",\n";
    }
    # print F $xpm;
    foreach my $l (split(/\n/,$xpm)) {
        $l =~ s/^\".{$frnt}/\"/;
        $l =~ s/.{$back}\"(\,?)$/\"$1/;
        $l .= ',' if ( !($l =~ m/\,$/) and ($adb > 0) );
        
        print F $l."\n" unless ( ($l =~ m/^\};/) and ($adb > 0) );
    }
    for (1..$adb) {
        print F '"';
        print F $canvaschar x $nc;
        print F "\",\n";
    }
    print F "};\n" if ($adb > 0);
    
    close(F);


    $sandbox->sysCommand("$PATHTOCONVERT mod_%OUT|F% -transparent %BGC|S% %IN|F%",
                         OUT => $out,
                         BGC => $bgcolor,
                         IN  => $in);

    unlink("mod_$out") unless ($debug);
    unlink("$out") unless ($debug);
}

# =========================

sub trimInlineImage_v1 {
    my ($outimg,$sandbox,$bgcolor,$LATEXWDIR,$ptsz) = @_;

    my $tmpfile = File::Temp::tempnam( $LATEXWDIR, 'tmp' ).".$EXT";
    move($outimg,$tmpfile);
                
    # my $args = "$tmpfile -background black -trim $outimg";
    # system("$PATHTOCONVERT $args");
    # system("echo \"$PATHTOCONVERT $args\" >> $LATEXLOG") if ($debug);

    my ($d,$e) = 
        $sandbox->sysCommand("$PATHTOCONVERT %IN|F% ".
                             " -background %BGC|S% -trim ".
                             " %OUT|F% ",
                             IN => $tmpfile,
                             BGC => $bgcolor,
                             OUT => $outimg );
    # print STDERR "convert: $d $e\n" if ($e > 0);
    
    my $img2 = image_info($outimg);
    
    my ($nw,$nh) = ( $img2->{width}-round(8*$ptsz), 
                     $img2->{height}-round(4*$ptsz) );
    $nw = $1 if ($nw =~ m/(\d+)/); # untaint
    $nh = $1 if ($nh =~ m/(\d+)/); # untaint
    $nh = round(15*$ptsz)
        if ($nh < round(15*$ptsz) ); # set a minimum height
    
    my ($sh,$sh2) = ( round(3.1*$ptsz), round(2.25*$ptsz) );
    $sh = $1 if ($sh =~ m/(\d+)/); # untaint
    $sh2 = $1 if ($sh2 =~ m/(\d+)/); # untaint
    
    # my $cmd = " -crop ".$nw."x".$nh."+$sh+$sh2 -transparent white $outimg";
    
    move($outimg,$tmpfile);
    # system("$PATHTOCONVERT $tmpfile $cmd");
    # system("echo \"$PATHTOCONVERT $tmpfile $cmd\" >> $LATEXLOG") if ($debug);
    ($d,$e) = 
        $sandbox->sysCommand("$PATHTOCONVERT %INIMG|F% ".
                             " -crop ".
                             '%NW|N%'.'x'.'%NH|N%'.
                             '+'.'%SH|N%'.'+'.'%SH2|N%'.
                             ' -transparent %BGC|S% %OUTIMG|F%',
                             INIMG => $tmpfile,
                             NW => $nw,
                             NH => $nh,
                             SH => $sh,
                             SH2 => $sh2,
                             BGC => $bgcolor,
                             OUTIMG => $outimg
                             );
    # print STDERR "convert: $d $e\n" if ($e > 0);
    unlink("$tmpfile") unless ($debug);
    
    ## Another strategy: trim gives better horizontal
    ## results but is too aggressive vertically.
    ##    * convert eps --> 1.png (with a border)
    ##    * shave 1.png by border size 
    ##    * copy 1.png --> 2.png
    ##    * trim 2.png
    ##    * extract off image and page size using identify
    ##      (this gives crop coordinates).
    ##      UPDATE: unfortunately, this is not robust.
    ##    * crop 1.png, using width-coordinates from
    ##      trim and hieght coordinates from shave
    
### EXAMPLE:
# /usr/X11R6/bin/convert -density 116 twiki_math.4.ps  -antialias -trim -gamma 0.6 -transparent white  t1.png
# cp t1.png t2.png
# mogrify -shave 2x2 t2.png
# identify t2.png
# "t2.png PNG 35x24+2+2 PseudoClass 256c 8-bit 365.0 0.000u 0:01"
# mogrify -trim t2.png
# identify t2.png
# "tmp.png PNG 11x11+8+6 PseudoClass 256c 8-bit 306.0 0.000u 0:01"
# mogrify -crop 11x24+10+3 t1.png
# 
}

# =========================

sub round {
    
    my ($i) = @_;
    
    # my $a = ( ($i - int($i)) > 0.5 ) ? int($i) : int($i) + 1;
    my $a = int($i);
    $a = $a + 1 if ( ($i - int($i)) > 0.5 );

    return($a);
}



1;
