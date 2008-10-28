# LatexModePlugin::Parse.pm
# Copyright (C) 2006 W Scott Hoge, shoge at bwh dot harvard dot edu
# Copyright (C) 2006 Evan Chou, chou86.e at gmail dot com
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
package TWiki::Plugins::LatexModePlugin::Parse;

use strict;

use vars qw( $VERSION $RELEASE );

=head1 The TWiki LatexModePlugin LaTeX Parse module

This module provides the ability to include LaTeX source files
in TWiki topics.

This module is approaching *beta*-level stability.  It has successfully
rendered a few test examples from mulitiple authors.  But no warranty
or fitness for a particular purpose is claimed.  Also, the translation
syntaxes and processing order are subject to change.

This document describes version $Rev$ of the module.

=cut

$VERSION = '$Rev$';
$RELEASE = 0.1;

# ==========

my %thmhash;
my $thm_autonumber = 0;
my %commands;

# to prevent executing arbitrary code in the 'eval' below, allow
# only registered commands to run.
my @regSubs = ( '&addToTitle', '&formThanks', '&handleAuthor', '&makeTitle', '&formBib', '&formInst' );

# open(F,"/var/www/twiki/conf/latex2tml.cfg") or die $!;
while (<DATA>) {
    next if ( length($_) == 0 or $_ =~ m/^\s+$/);

    my $s = substr($_,0,1,'');
    my @a = split(/$s/,$_);
    my %h;
    next if ($#a < 0);

    $h{'size'} = $a[1];

    $a[2] = substr($a[2],0,length($a[2])-2)."\n" if ($a[2] =~ m/\\n$/);
    $h{'command'} = $a[2];

    $commands{$a[0]} = \%h;
}
# close(F);
# print STDERR "Keys: ";
# print STDERR map {"$_  "} sort keys %commands;
# print STDERR ":Keys\n";

my %entities = (  '\`{A}'   => '&Agrave;',
                  "\\\'{A}" => '&Aacute;',
                  '\^{A}'   => '&Acirc;' ,
                  '\"{A}'   => '&Auml;'  ,
                  '\c{C}'   => '&Ccedil;',
                  '\`{E}'   => '&Egrave;',
                  "\\\'{E}" => '&Eacute;',
                  '\^{E}'   => '&Ecirc;' ,
                  '\"{E}'   => '&Euml;'  ,
                  '\`{I}'   => '&Igrave;',
                  "\\\'{I}" => '&Iacute;',
                  '\^{I}'   => '&Icirc;' ,
                  '\"{I}'   => '&Iuml;'  ,
                  '\~{N}'   => '&Ntilde;',
                  '\`{O}'   => '&Ograve;',
                  "\\\'{O}" => '&Oacute;',
                  '\^{O}'   => '&Ocirc;' ,
                  '\~{O}'   => '&Otilde;',
                  '\"{O}'   => '&Ouml;'  ,
                  '\`{U}'   => '&Ugrave;',
                  "\\\'{U}" => '&Uacute;',
                  '\^{U}'   => '&Ucirc;' ,
                  '\"{U}'   => '&Uuml;'  ,
                  "\\\'{Y}" => '&Yacute;', 
                  '\"{Y}'   => '&Yuml;',
                  '\`{a}'   => '&agrave;',
                  "\\\'{a}" => '&aacute;',
                  '\^{a}'   => '&acirc;' ,
                  '\"{a}'   => '&auml;'  ,
                  '\c{c}'   => '&ccedil;',
                  '\`{e}'   => '&egrave;',
                  "\\\'{e}" => '&eacute;',
                  '\^{e}'   => '&ecirc;' ,
                  '\"{e}'   => '&euml;'  ,
                  '\`{i}'   => '&igrave;',
                  "\\\'{i}" => '&iacute;',
                  '\^{i}'   => '&icirc;' ,
                  '\"{i}'   => '&iuml;'  ,
                  '\~{n}'   => '&ntilde;',
                  '\`{o}'   => '&ograve;',
                  "\\\'{o}" => '&oacute;',
                  '\^{o}'   => '&ocirc;' ,
                  '\~{o}'   => '&otilde;',
                  '\"{o}'   => '&ouml;'  ,
                  '\`{u}'   => '&ugrave;',
                  "\\\'{u}" => '&uacute;',
                  '\^{u}'   => '&ucirc;' ,
                  '\"{u}'   => '&uuml;'  ,
                  "\\\'{y}" => '&yacute;', 
                  '\"{y}'   => '&yuml;' 
                  );


sub printF {

    my ($t) = @_;
    open(F,">>/tmp/alltex_uH.txt");
    print F $t;
    close(F);

}


=head2 Syntax

To include full LaTeX source documents in a TWiki topic, insert
the text to be converted inbetween the tags %BEGINALLTEX% and
%ENDALLTEX%.

=begin twiki


---+++ Example

<verbatim>
%BEGINALLTEX%
\documentclass{article}

\begin{document}

\section{A Brand \emph{New} Day}

\fbox{ \[Ax =b \] }

\begin{itemize}
\item A
\item B
  \begin{enumerate}
  \item 1
  \item 2
    \begin{itemize}
    \item a
    \item b
    \end{itemize}
  \item 3
  \end{enumerate}
\item C
\end{itemize}

\end{document}

%ENDALLTEX%
</verbatim>

will be converted to

<verbatim>
---+ A Brand  <em>New</em> Day

<table align="left" border="1"><tr><td>
%BEGINLATEX{inline="0"}%\begin{displaymath} Ax =b  \end{displaymath}%ENDLATEX%
</table>

<ul>
<li> A
<li> B
  <ol>
  <li> 1
  <li> 2
    <ul>
    <li> a
    <li> b
    </ul>
  <li> 3
  </ol>
<li> C
</ul>

</verbatim>

=end twiki

=cut

sub handleAlltex
{

    my $txt = '';

    my $math_string = $_[0];
    my $params = $_[1];

    #get rid of comments
    # %  ... \n
    # $math_string =~ s!([^\\])%+.*?\n!$1!gs;
    # $math_string =~ s!%\n!\n!g;
    # while($math_string =~ s!\n\%+.*?\n!\n!g){};
    $math_string =~ s!\\%!LMPpcntLMP!g;
    $math_string =~ s!%.*?\n!!gs;
    $math_string =~ s!LMPpcntLMP!%!g;


    my ($pre,$doc);
    #everything between \documentclass and \begin{doc..} is preamble
    if ( $math_string =~ m!(\\documentclass\s*(\[.*?\])?\s*\{.*?\})\s*(\[.*?\])?(.*?)\\begin\s*\{document\}\s*(.*?)\s*\\end\s*\{document\}!is ) {
        
        $pre = $4;     # preamble
        $doc = $5;     # document

        TWiki::Func::getContext()->{'LMPcontext'}->{'preamble'} .= $pre;
        TWiki::Func::getContext()->{'LMPcontext'}->{'docclass'} .= $1;
        printF($1);
    }
    else {
        $pre = '';
        $doc = $math_string;
    }

    if ( exists(TWiki::Func::getContext()->{'genpdflatex'}) ) {
        # protect latex new-lines at end of physical lines
        $doc =~ s/(\\\\)$/$1  /gs;
        #protect paragraph breaks
        $doc =~ s/\n\n/\n\\par\n/gs;

        return('<latex>'.$doc.'</latex>');
    }

    TWiki::Func::getContext()->{'LMPcontext'}->{'title'} = '';
    TWiki::Func::getContext()->{'LMPcontext'}->{'thanks'} = '';
    TWiki::Func::getContext()->{'LMPcontext'}->{'thankscnt'} = 0;

    unlink("/tmp/alltex_uH.txt");
    # printF("handleAlltex($params)");

=begin twiki

The parsing is done in three stages:
   1. All environments, e.g. =\begin{env} .. \end{env}= are extracted.  Known environments are converted to HTML/TML.  Unknown environments are rendered as images.
   2. Remaining text is grouped into blocks, 
   3. Blocks are searched for commands
      a. Known commands are converted to HTML/TML.  
      b. Unknown commands are marked as LATEX, for possible rendering in future version of the module or tranlations list.

=end twiki

=cut

    $doc = protectVerbatim( $doc );
    &mathShortToLong($doc);
    $doc = extractEnvironments( $doc )
        if ($TWiki::Plugins::LatexModePlugin::Parse::RELEASE > 0.01);

    $doc = extractBlocks( $doc )
        if ($TWiki::Plugins::LatexModePlugin::Parse::RELEASE > 0.01);

    $doc = extractSimple( $doc )
        if ($TWiki::Plugins::LatexModePlugin::Parse::RELEASE > 0.01);


=pod

The output will be rendered in HTML by default.  Alternatively,
one can render the output in TWiki Markup (TML).  This is achieved
by declaring 

   * Set LATEXMODEPLUGIN_ALLTEXMODE = tml

as a topic/web/twiki-wide preference setting, or by passing in =tml= as
the =latex= parameter on view.  e.g. 
<a href="%TOPIC%?latex=tml">%TOPIC%?latex=tml</a>

The option of TML output is provided for the following reason: it
is unlikely that all portions of the .tex to TWiki topic
conversion will render successfully.  [ The I<parser> in almost
complete. The I<converter>? not so much. ;-) ] With a .tex to TML
converter in place, one can copy-and-paste the twiki markup to
another topic to correct the rendering problems.

=cut

    # replace all extracted verbatim blocks
    $doc =~ s/%VERBATIMBLOCK\{(.*?)\}%/&extractVerbatim($1)/ge;
    $doc =~ s/%VERBATIMLINE\{(.*?)\}%/&extractVerbatim($1)/ge;

    open(F,">/tmp/after_eB.txt");
    print F $doc;
    print F "\n"; print F 'x'x70; print F "\n";
    close(F);

    $doc = "<verbatim>\n".$doc."\n</verbatim>\n"
    if ( TWiki::Func::getContext()->{'LMPcontext'}->{'alltexmode'} );
    #we are done!
    return($doc);

}


my %simple = ( # '\~' => '&nbsp;',
               '\\noindent' => '',
               '\\\\' => "<br>",
               '\vfill' => '',
               '\newblock' => '',
               '``' => '&ldquo;',
               "''" => '&rdquo;', 
               '\\o' => '&oslash;',
               '\\O' => '&Oslash;',
               '\\AA' => '&Aring;',
               '\\aa' => '&aring;',
               '\\ae' => '&aelig;',
               '\\AE' => '&AElig;',
               '\\mainmatter' => '',
               '\\clearpage' => '',
               '\\centering' => '', # clear it, if not caught in block proc
               '\\sloppy' => '' );

foreach my $c (keys %entities) {
    my $m = $entities{$c};
    $c =~ s/\{|\}//g;
    $simple{$c} = $m;
}

sub extractSimple {

    my ($doc) = @_;

    # convert simple commands to TML
    # convertSimple($doc);
    my ($pre,$block);
    my $txt = '';
    do {
        ($pre,$block,$doc) = umbrellaHook( $doc,
                                           '\%BEGINLATEX',
                                           'ENDLATEX\%');
        
        if ( ($pre =~ m/\\/) and (length($pre)>0) ) {
            convertSimple($pre);
            # $pre =~ s/(\\\w+)\b/%BEGINLATEX{inline="1"}%$1%ENDLATEX%/g;
            # $pre =~ s/(\\\w+)\b/% \$ $1 \$ %/g;
        }
        $txt .= $pre;
        # $txt .= ($pre =~ m!\\!)? processBlock($pre,$n) : $pre ;
        # $txt .= '||'.$pre.'||';
        $txt .= $block;
        
    } while ($block ne '');
    if ( ($doc =~ m/\\/) and (length($doc)>0) ) {
        convertSimple($doc);
        # $doc =~ s/(\\\w+)\b/% \$ $1 \$ %/g;
    }
    $txt .= $doc;
    $doc = $txt;
    $doc =~ s/~+/&nbsp;/g;

    return($doc);
}

sub convertSimple
{
    
    # $simple{'\\maketitle'} = TWiki::Func::getContext()->{'LMPcontext'}->{'title'}."\n<br>\n".TWiki::Func::getContext()->{'LMPcontext'}->{'thanks'}."\n<br>\n";

    $_[0]=~s/\\maketitle/&makeTitle()/e;

    foreach my $c ( keys %simple ) {
        my $m  = $simple{$c}; 
        # printF( "$c --> $m\n" );
        $_[0] =~ s/\Q$c\E/$m/g;
    }
    # my $s1 = "%BEGINLATEX<nop>%";
    # my $s2 = "%<nop>ENDLATEX%";
    # 
    # $_[0] =~ s/(\\\w+)\b/$s1$1$s2/g; # mark all unkown commands 
    
}

my %embed = ( '\\em' => [ '<em>', '</em>' ],
              '\\bf' => [ '<strong>', '</strong>' ],
              '\\small' => [ '<font size="-2">','</font>' ],
              '\\tiny' => [ '<font size="-3">','</font>' ],
              '\\footnotesize' => [ '<font size="-4">','</font>' ],
              '\\large' => [ '<font size="+1">','</font>' ],
              '\\raggedleft' => [ '<div style="text-align:right">', '</div>' ],
              '\\centering' => [ '<div align="center">', '</div>' ]
              );

sub convertEmbed
{
    my ($b) = @_;


    $b =~ s/^\s*\{(.*)\}\s*/$1/gs;
    $b =~ s!\\\/$!!;
    # printF("convertEmb  (pre): $b\n");
    
    return($b) unless ($b=~m/\\/);
    foreach my $c ( keys %embed) {
        # printF( "$c --> @{$embed{'$c'}}\n" );
        if ($b =~ s/\Q$c\E\b//g) {
            $c = extractBlocks($c);
                        
            $b = $embed{$c}[0].$b.$embed{$c}[1];
        }
    }
    # printF("convertEmb (post): $b\n");
    return($b);
}

# use base qw( TWiki::Plugins::LatexModePlugin );

sub expandSpecialChars {
    return;
    my ($b,$cmd,$txt) = ('','','');
    my (@a);

    if ($cmd =~ m!\\[\`\"\'\^\~\.duvtbHc]$!) {
        # map special text characters to html entities
        $b =~ s/\\$cmd$//;
        $txt .= $b;
        my $t = $cmd.shift(@a);
        $txt .= ( exists( $entities{$t} ) ) ? 
            $entities{$t} : 
            '%BEGINLATEX{inline="1"}%'.$t.'%ENDLATEX%';
    }
}

sub expandComplexBlocks {
    # elsif ( exists( $commands{$cmd} ) ) 
    my ($cmd,$star,$opts,$aref) = @_;

    my @a = @{$aref};           
    # a big downside to this is that it makes a copy of the
    # array... which is the entire text early on.

    my $cnt = scalar(@a);
    my $txt = '';

    {

        # if found command defined in %commands...
        my $sz = 0;
        my $str = $commands{$cmd}{'command'};
        # print F $b." ";
        while ($sz < $commands{$cmd}{'size'}) {
            # grab the number of needed blocks of the stack
            my $t = shift(@a);
            if (length($t) > 0) {
                $t = substr($t,1,length($t)-2);
                printF( "  :".$t.": " );
                
                if ($t =~ m/([\d\.]+)\\linewidth/) {
                    $t = sprintf("%4.2f",($1/1)*100)."\%";
                }
                $sz++;
                $str =~ s/\$$sz/$t/gs;
            }
        }
        $str =~ s/\$o/$opts/;
        $str =~ s/\$c/$cmd/;
        
        # ensure that twiki section commands land at the start
        # of a new line
        $str = "\n\n".$str if ($str=~m/^\-\-\-/); 
        
        printF("\n$str\n-+-+-+-\n"); # debug output
        
        # process the command...
        
        my $cmd = $1 if ($str =~ s/^(&\w+)\((.*)\)$/$2/s);
        
        $str = extractBlocks($str) if ($str =~ m/\\/); 
        # convertSimple($str) if ($str =~ m/\\/); 
        
        if (defined($cmd)) {
            $str =~ s/^(\"|\')|(\"|\')$//g;
            printF("Try dynamic command: $cmd($str)\n");
            my @z = grep(@regSubs,$cmd);
            
            if ($cmd eq $z[0]) {
                my $t;
                eval('$t = '.$cmd.'($str);'); 
                printF(" ".$@) if $@;
                $txt .= $t;
            }
        } else {
            $txt .= $str ; # convertEmbed( $str );
        }
        printF( "\n" );
        
        
    }
    return($txt,($cnt-scalar(@a)));
}

sub processBlock {
    my ($b,$n) = @_;

    my $txt = '';# " <b>BLOCK-$n:</b>";

    $b = convertEmbed($b);

    if ($b =~ m/^(.+?)%BEGINLATEX.*?ENDLATEX%/s)  {
        my $g = $b;
        my ($o2,$n2) = (undef,undef);
        do {
            # printF( "====".$g."=====\n" );
            my $o1 = $1; $o2 = $2;
            my $n1 = $o1; $n2 = $o2;
            if ($n1=~m/\\\w+/) {
                $n1 = extractBlocks($n1);
            }
            # printF( "==__".$n1."__===\n" );
            $b =~ s/\Q$o1\E/$n1/;
        } while ($g =~ s/\G(.*?)%BEGINLATEX.*?ENDLATEX%(.*)/$2/sg);
        
        if (length($o2)>0) {
            # if ($n2=~m/\\\w+/) {
            $n2 = extractBlocks($n2);
            # }
            # printF( "\n=+=+".$b."+=+= $o2\n" );
            $b =~ s/\Q$o2\E/$n2/;
            # printF( "\n=-=-".$b."-=-=\n" );
        }
    # } else {
        # convertSimple($b);
    }
    
    # printF("calling convertEmbed\n");
    $b = convertEmbed($b);
    $txt .= $b;

    # $txt .= "<b>:BLOCK-$n</b> ";
    return($txt);
}

# sub process_Block_Old {
#     my ($b,$n) = @_;
# 
#     my $txt =  " <b>BLOCK-$n:</b>";
# 
#     $b = convertEmbed($b);
# 
#     # # examine everything outside of the BEGINLATEX .. ENDLATEX blocks
#     # # 
#     my ($pre,$block);
#     do {
#         ($pre,$block,$b) = umbrellaHook( $b,
#                                          '\%BEGINLATEX',
#                                          'ENDLATEX\%');
#         
#         if ( ($pre =~ m/\\/) and (length($pre)>0) ) {
#             # $pre = extractBlocks($pre);
#             convertSimple($pre);
#             $txt .= ' <em>OB:</em>'.$pre.'<em>:OB </em>';
#         } else {
#             $txt .= $pre;
#         }
#         #  $txt .= ($pre =~ m!\\!)? processBlock($pre,$n) : $pre ;
#         # $txt .= '||'.$pre.'||';
#         $txt .= $block;
#         
#     } while ($block ne '');
#     # $b = extractBlocks($b);
#     convertSimple($b);
# 
#     $txt .= ' <em>OB:</em>'.$b.'<em>:OB </em>' if (length($b)>0);
# 
#     $txt .= "<b>:BLOCK-$n</b> ";
#     return($txt);
# }
# 

sub extractBlocks {

    my $doc = $_[0];

    my($pre,$block);
    my $txt = '';
    #resuse $pre for beginning    

    my @a;

    printF('x'x70); printF("\n");
    printF($doc);
    printF('x'x70); printF("\n");
    return($doc) unless ($doc =~ m/\{|\}/);

    ## parse once through to collect all nested braces
    do {
	($pre,$block,$doc) = umbrellaHook( $doc,
                                       '\{',
                                       '\}');

        if ($pre =~ m/^(.*)(\\[\w\*]+?)$/s) {
            push(@a,$1);        # before command
            push(@a,$2);        # command
        } elsif ( ($pre =~ m/[A-Z]+$/) || 
                  ($doc =~ m/^\%/) ){
            # printF("++ $pre ++ $block ++ $doc\n");
            # protect twiki commands, like %BEGINFIGURE{ ... }%
            $block = $pre.$block.substr($doc,0,1,'');
            printF("protecting '$block'\n");
        } else {
            push(@a,$pre);
        }
        push(@a,$block);

    } while ($block ne '');
    #there is still some $doc left, so push it onto the stack:
    push(@a,$doc);

    #### Convert the found blocks
    my $b = '';
    do {
        $b = shift(@a);

        ## lump the BEGINLATEX .. ENDLATEX blocks together:
        my $cnt = 0; 
        while ($b=~m/\%(BEGIN|END)LATEX/g) { 
            ($1 eq 'BEGIN') ? $cnt++ : $cnt--;
        }
        printF( "\n-- ".scalar(@a)."  $cnt\nb: ".$b ) if ($cnt != 0);
        while ( ($cnt !=0) and (scalar(@a) >0) ) {
            my $c = shift(@a);
            if ($c =~ s/^(.*?ENDLATEX%)//s) {
                $b .= $1;
                unshift(@a,$c);
                # printF( "\n***** $a[0]\n" );
                # printF( "\nxx ".scalar(@a)."\n".$b );
                $cnt = 0;
            } else {
                $b .= $c;
            }
        }
        printF( "\n++ ".scalar(@a)."\nb: ''".$b."''\n" );
        ## BEGINLATEX .. ENDLATEX blocks are now grouped, proceed to treat
        ## remaining tex commands of the form '\cmd{}' and '\cmd'
        my $NN = ($b =~ m/(\n+)$/) ? $1 : '';
        $b =~ s/\s+$//;
        $b .= $NN;

        if ($b=~m/\\[\"\'\`\^\~\.\[\]\*\=\,\\\w]+$/) {
            # if the block is a command, it's a complex command
            my ($cmd,$star,$opts) = ('','','');
            ($cmd,$star,$opts) = ($1,$2,$3) if
                (
                 ($b =~ s!(\\[\"\'\`\^\~\.duvtbHc])$!!) # test for single char commands
                 or 
                 ($b =~ s!(\\\w+)\b(\*?)(\[
                                         ([\\\w\d\.\=\,\s]+?)
                                         \])?$!!xs) # test for a latex command;
                 );
            $star = '' unless defined($star);
            printF( "\nFound command: $cmd$star ") if ($cmd ne '');
            (defined($opts) and ($opts ne '') ) ?
                printF(" opts = $opts \n") : printF("\n");

            if ($cmd =~ m!\\[\`\"\'\^\~\.duvtbH]$!) {
                # map special text characters to html entities
                # $b =~ s/\\$cmd$//;
                $txt .= $b;
                my $t = $cmd.shift(@a);
                printF($t);
                $txt .= ( exists( $entities{$t} ) ) ? 
                    $entities{$t} : 
                    '%BEGINLATEX{inline="1"}%'.$t.'%ENDLATEX%';
            } elsif ($cmd ne '') {
                # $txt .= "<em>$cmd$star$opts</em>";
                if ( exists( $commands{$cmd} ) ) {
                    # $txt .= ' (K) '; # known command
                    if ($cmd eq '\label') {
                        my $t = shift(@a);
                        $t = substr($t,1,length($t)-2);
                        printF( "  :".$t.": " );
                        $t = ' %SECLABEL{'.$t.'}% ';
                        $txt =~ s/(---\++\!?\s+)([\w\s\$\%\\]+)$/$1$t$2/s;
                    } else {
                        # (defined($opts)) ?
                        # $b =~ s/\$cmd\*?\Q$opts\E//;
                        # $b =~ s/\$cmd\*?//;
                        $txt .= $b;
                        my($a,$trimcnt) = 
                            expandComplexBlocks($cmd,$star,$opts,\@a);
                        $txt .= $a;
                        foreach (1 .. $trimcnt) { shift(@a); }
                    }
                } else {
                    # unknown command
                    if ($cmd ne '\c') {
                        my $s1 = "%BEGINLATEX<nop>% "; 
                        # $b =~ s/(\\[\"\'\`\^\~\.\w]+)$/$s1$1/;
                        $s1 .= $cmd;
                        $s1 .= $star if defined($star);
                        $s1 .= $opts if defined($opts);
                        $b = $s1.$b;
                        # if the first character of the next block is a brace, it
                        # likely means we have a complex command...  So group
                        # them.
                        while ( (scalar(@a)>0) and
                                (($a[0]=~m/^\s*(\{|\})/s) or (length($a[0])==0)) ){
                            $b .= shift(@a);
                        } 
                        $b .= " %<nop>ENDLATEX% ";
                    }
                    printF($b."\n");
                    $txt .= $b; 
                }
            } else {
                $txt .= $b;# . "<font size=\"+5\">Parse: shouldn't get here</font>";
            }
        } elsif ($b=~m/\{/) {
            #
            $b = convertEmbed($b);
            (my $c=$b)=~s/%BEGINLATEX.*?ENDLATEX%//gs;
            $c=~s/%\p{IsUpper}+?\{.*\}%//gs; # take out all twiki tags
            # should probably look for nested tags
            
            $b = extractBlocks($b) if ($c=~m/\{.*\}/);
            $txt .= $b;
        } else {
            (my $c=$b)=~s/%BEGINLATEX.*?ENDLATEX%//gs;
            $txt .= ( ($c =~ m!\\!) and !($b=~m/^\s*$/)) ? 
                processBlock($b,scalar(@a)) : $b ;
            #$txt .= " <b>BLOCK+".scalar(@a).":</b>".$b.
            #     "<b>:BLOCK+".scalar(@a)."</b> " if !( $b =~ m/^\s*$/);
        }

    } while (scalar(@a)>0);

    return($txt);
}

sub pushVerb {
    my $txt1 = '%VERBATIMLINE{';
    my $txt2 = '}%';

    while ($_[0] =~ m/\\verb(\*?)(.)/sg) {
        my $u = $1;
        my $d = $2;
        $_[0] =~ s/\\verb\*?\Q$d\E(.+?)\Q$d\E/$txt1.&storeVerbatim($1,$u).$txt2/es;
    }
}

sub mathShortToLong {
    #change all $ .. $, $$ .. $$, and \[ .. \] to math environments
    ### warning: can't do this within verbatim blocks!

    $_[0] =~ s!\\\[(.*?)\\\]!\\begin\{displaymath\} $1 \\end\{displaymath\}!gis;
    $_[0] =~ s!\$\$(.*?)\$\$!\\begin\{displaymath\} $1 \\end\{displaymath\}!gis;
    $_[0] =~ s!\$(.*?)\$!\\begin\{math\} $1 \\end\{math\}!gis;

}

sub extractEnvironments {

    my $doc = $_[0];

    my($pre,$block);
    my $txt = '';
    do {
	($pre,$block,$doc) = umbrellaHook( $doc,
                                           '\\\\begin\s*\{.*?\}',
                                           '\\\\end\s*\{.*?\}');
        # &pushVerb($pre,$1) if ($pre =~ m/\\verb(.)/);
        # &mathShortToLong($pre);
        # $pre = extractEnvironments($pre) if ($pre =~ m/\\begin\{.*?math\}/);
	$txt .= $pre;

        # if ($block =~ m/^\\begin\{verbatim\}/) {
        #     $txt .= '%VERBATIMBLOCK{'.storeVerbatim($block).'}%';
        # } else {
        #     &pushVerb($block,$1) if ($block =~ m/\\verb(.)/);
        #     &mathShortToLong($block);
            $txt .= convertEnvironment($block) if ($block ne '');
        # }
    } while ($block ne '');

    #there is still some $doc left:
    # &pushVerb($doc,$1) if ($doc =~ m/\\verb(.)/);
    # &mathShortToLong($doc);
    # $doc = extractEnvironments($doc) if ($doc =~ m/\\begin\{.*?math\}/);
    $txt .= $doc;

    return($txt);
}

sub protectVerbatim {

    my $doc = $_[0];

    my($pre,$block);
    my $txt = '';
    do {
	($pre,$block,$doc) = umbrellaHook( $doc,
                                           '\\\\begin\s*\{verbatim\}',
                                           '\\\\end\s*\{verbatim\}');
	$txt .= $pre;
        $txt .= '%VERBATIMBLOCK{'.storeVerbatim($block).'}%'
            unless ($block eq '');
    } while ($block ne '');

    #there is still some $doc left:
    $txt .= $doc;

    &pushVerb($txt,$1) if ($txt =~ m/\\verb(.)/);

    return($txt);
}

=head2 Supported Environments

=over 1

=item *

$ .. $, $$ .. $$, \[ .. \], math, displaymath, equation, eqnarray

=item * 

itemize, enumerate, description

=item *

table, figure

=item *

verbatim

=item *

abstract, bibliography, keywords

=back

=begin html

<p>

=end html

LaTeX enviroments that are I<not supported> are passed to the TWiki
LaTeX rendering engine to generate an image.  For nested
environments, image rendering occurs at the first unrecognized enviroment.

=cut

sub convertEnvironment
{
    my ($block) = @_;

    printF("\n"); printF('-'x70); printF("\n");
    printF($block);
    printF("\n"); printF('-'x70); printF("\n");

    #now process the block!
    $block =~ m!^\\begin\{(.*?)\}!si;
    my $bname = $1;

    my $txt = '';
    my $label = '';
    $label = 'label="'.$1.'"' if ($block=~s!\\label\{(.*?)\}\s*!!);

    if ($bname eq 'math') {
        $txt .= '%BEGINLATEX{inline="1"}%'.$block.'%ENDLATEX%';
    }
    elsif ( ($bname eq 'displaymath') ||
            ($bname eq 'eqnarray*') ){
        $txt .= '%BEGINLATEX{inline="0"}%'.$block.'%ENDLATEX%';
    }
    elsif ($bname eq 'eqnarray') {
        $block =~ s!(\\\\|\\end\{eqnarray\})!\\nonumber $1!g;
        $txt .= '%BEGINLATEX{inline="0" '.$label.'}%'.$block.'%ENDLATEX%';
    }
    elsif ($bname eq 'center') {
        $block =~ s!\\(begin|end)\{center\}!!g;
        $block =  extractEnvironments($block);
        # $block =  extractBlocks($block);

        $txt .= '<div align="center">'.$block.'</div>';
    } 
    elsif ($bname eq 'equation') {
        $block =~ s/\n\s*\n/\n/g;
        $block =~ s!\\(begin|end)\{equation\}!\\$1\{displaymath\}!g;
        # print STDERR $block."\n";
        $txt .= '%BEGINLATEX{inline="0" '.$label.'}%'.$block.'%ENDLATEX%';
    }
    elsif ( ($bname eq 'flushright') ) {
        $block =~ s!^\\begin\{$bname\}!<div style="text-align:right">!;
        $block =~ s!\\end\{$bname\}$!</div>!;
        
        $block = extractEnvironments($block);
        # $block = extractBlocks( $block );
        $txt .= $block;
    }
    elsif ( ($bname eq 'quotation') || ($bname eq 'quote') ) {
        $block =~ s!^\\begin\{$bname\}!<blockquote>!;
        $block =~ s!\\end\{$bname\}$!</blockquote>!;

        $block = extractEnvironments($block);
        # $block .= extractBlocks( $block );
        $txt .= $block;
    }
    # elsif ($bname eq 'verbatim') {
    #     $block =~ s!^\\begin\{$bname\}!<verbatim>!;
    #     $block =~ s!\\end\{$bname\}$!</verbatim>!;
    #     $block =~ s/\\(begin|end){math}/\$/g;
    #     $txt .= $block;
    # }
    elsif ( ($bname =~ m/(itemize|enumerate|description)/ ) ) {
        my $tag = 'ul>';
        $tag = 'ol>' if ($1 eq 'enumerate');
        $tag = 'dl>' if ($1 eq 'description');

        $block =~ s!^\\begin\{$bname\}!\<$tag!;
        $block =~ s!\\end\{$bname\}$!\</$tag!;
        while ($block =~ m/\\(.+?)\b/g) {
            my $match = $1;
            my $pos = (pos $block) - length($match) - 1;
            $txt .= substr($block,0,$pos,'');

            if ($match eq 'item') {
              if ($tag eq 'dl>') {
                $block =~ s/^\\item\[(.*?)\]/<dt> *$1* <\/dt><dd>/;
                $block =~ s!^\\item!<dt></dt><dd>!;
              } else {
                $block =~ s/^\\item\[(.*?)\]/<li value="$1">/;
                $block =~ s/^\\item/<li>/;
              }
            }
            elsif ($match eq 'subitem') {
                $block =~ s/^\\subitem/ %BR%&nbsp;&nbsp;&nbsp;&nbsp; /;
            }
            elsif ($match eq 'begin') {
                my ($pre,$blk2,$post);
                ($pre,$block,$post) = umbrellaHook( $block, 
                                                    '\\\\begin\s*\{.*?\}',
                                                    '\\\\end\s*\{.*?\}');
                $txt .= $pre.convertEnvironment($block);
                $block = $post;
            } else {            # ignore it...
                $txt .= substr($block,0,length($match)+2,'');
            }
        }
        $txt .= $block;
    }
    elsif (0) { # ($bname =~ /tabular/) {
        printF("=====processing tabular=====\n");
        $block =~ s!^\\begin\{$bname\*?\}(\[\w+\])?!!;
        $block =~ s!\\end\{$bname\*?\}$!!; 
        
        $block =~ s/\x0d?\n//g;
        $block =~ s/\{([\@\{\.\}rlc]+)\}\s/ /; # peel off the table structure
        printF($block);

        my $struct = $1;
        $struct =~ s/\|//g;
        printF("\nstruct: ".$struct."\n");
        $struct =~ s/\@\{.*?\}//g;
        my @rows = split(/\\\\/,$block);
        my $t = "<table>\n";
        foreach my $r (@rows) {
            $t .= "<tr>";
            my @l = split(/\&/,$r);
            if ($l[0]=~s/\\hline//){
                $t .= '<tr><td colspan="'.length($struct).'">'.
                    '<hr></td></tr>'."\n";
            }
            foreach my $cnt ( 0 .. (scalar(@l)-1) ) {
                $t .= "\t".'<td align="';
                my $a = substr($struct,$cnt,1);
                if ($a eq 'c') {  $t .= 'center'; }
                elsif ($a eq 'r') {  $t .= 'right'; }
                else {  $t .= 'left'; }
                $t .= '">';
                $l[$cnt] =~ s/^\s+/ /;
                $l[$cnt] =~ s/\s+$/ /;
                if ($l[$cnt] =~ m/\\/) {
                    $l[$cnt] = extractEnvironments($l[$cnt]);
                    $l[$cnt] = extractBlocks($l[$cnt]);
                }
                $t .= $l[$cnt];
                $t .= '</td>'."\n";
            }
            $t .= "</tr>\n";
        }
        $t .= "</table>\n";
        $txt .= $t;
        printF("\n$t\n");
        printF("\n===== done with tabular ====\n");
    }
    elsif ($bname =~ /(figure|table)(\*?)/) {
        my $type = uc($1);
        my $span = ($2 eq '*') ? ' span="twoc" ' : '';
        $block =~ s!^\\begin\{$bname\*?\}(\[\w+\])?!!;
        $block =~ s!\\end\{$bname\*?\}$!!; 

        $block =~ s/(.+)\\caption//s;
        my $env = $1;

        my ($pre,$caption) = ('','');
	($pre,$caption,$block) = umbrellaHook( $block,
                                               '\{',
                                               '\}');
        $env .= $block;
        if (length($caption) > 0) {
            $caption = substr($caption,1,length($caption)-2);
            if ($caption =~ m/\\/) {
                # $caption = convertEmbed( $caption );
                $caption = extractEnvironments($caption);
                # captions are stored in the TWiki tag, which is not
                # processed later... so process the contents now.
                $caption = extractBlocks( $caption );
                $caption =~ s/([\"])/\\$1/g;
            }
            $caption = 'caption="'.$caption.'"';
        }
        $txt .= '%BEGIN'.$type.'{'.$label.' '.$caption.' '.$span.'}%';

        $env = extractEnvironments($env);
        # $env = extractBlocks($env);

        $txt .= $env;
        $txt .= '%END'.$type.'%';
    }
    elsif ($bname =~ /abstract|keywords/) {
        my $env = $block;
        $env =~ s!\\begin\{$bname\*?\}!!;
        $env =~ s!\\end\{$bname\*?\}!!; 

        $env = extractEnvironments($env);

        $txt .= "<blockquote>\n*".ucfirst($bname).":* ".$env."</blockquote>\n";

    }
    elsif ($bname =~ /bibliography/) {
        # for this to work, the LatexModePlugin must precede the BibtexPlugin
        # i.e. in LocalSite.cfg: $TWiki::cfg{PluginsOrder} = 'SpreadSheetPlugin,LatexModePlugin,BibtexPlugin';
        my $env = $block;
        $env =~ s!\\begin\{$bname\*?\}(\{\d+\})?!!;
        $env =~ s!\\end\{$bname\*?\}!!;
        $txt .= "\n\n---+ References\n\n<div class=\"bibtex\"><table><tr>";
        my $cnt = 1;
        while ($env =~ m!\\bibitem\{(.*?)\}!g) {
            my $t = "<tr valign=\"top\"><td>[<a name=\"$1\">".$cnt."</a>] </td>\n<td> ";
            $env =~ s!\\bibitem\{$1\}!$t!;
            $cnt++;
        }
        $env =~ s/\~/&nbsp;/g;
        while ($env =~ m!\{(.*?)\}!g) {
            my $t = $1;
            $env =~ s/\{$t\}/$t/ unless ( ($env =~ m!\\[^\s]+\{$t\}!) or
                                          ($env =~ m!%\w+\{$t\}%!) );
        }
        $txt .= $env."</table></div>\n";
    }
    else {
        # $txt .= "<br><blockquote>\n---- \n";
         # $block =~ s/$env/convertEnvironment($env)/e if ($env=~m/\begin\{/);
        # $txt .= $block;
        $txt .= "%BEGINLATEX%\n".$block."\n%ENDLATEX%\n";
        # $txt .= "<br>\n---- <br></blockquote>\n";
        # $text .= LaTeX2TML($block);
    }

    return($txt);
}


## derived from code contributed by TWiki:Main.EvanChou 
#
#
#helper function that grabs the right tag (no need for weird divtree)
#do not give regex delimiteres that match!
#
sub umbrellaHook
{
    #pass in the process text, and delimiters (in regex)
    #returns list (before,umbrella,after) (first one it sees)
    my $txt = $_[0]; 
    my $delim_l = $_[1];
    my $delim_r = $_[2];

    # open(F,">>/tmp/alltex_uH.txt");
    # print F $txt;
    # print F "\n"; print F '-'x70; print F "\n";
    # close(F);

    my $nleft = 0;
    my $nright = 0;
    my $umb = '';
    my $front;

    my $before = '';

    my $cnt = 0;

    if($txt =~ s!^(.*?)($delim_l)!!is) {
	$nleft++;
	$before = $1;
	$umb = $2; 

#	return ($before, $umb,$txt);
#	my $pl = -1;
#	my $pr = -1;

	while ($nright < $nleft) {
	    if($txt =~ s!^(.*?)($delim_r)!!is) {
		$nright++;
                $front = $1; 
                $umb .= $1 . $2;
	    } else {
		#mismatch!	       		
		$txt = $before . $umb . $txt;
		$before = '';
		$umb = '';
		last;
	    }

	    #count how many left's are before this right
	    while($front =~ m!$delim_l!gis) {
		$nleft++;
	    }
#	    $pl = $nleft;
#	    $pr = $nright;
	}
    }
    else {
    }
    return ($before, $umb, $txt);

}

sub handleNewTheorem {

    my $pre = $_[0];

    #parse preamble and set up theorem numbering
    #first find the section-linked thm (\newtheorem{$envname}{$type}[section])
    if($pre =~ m!\\newtheorem\{(.*?)\}\{(.*?)\}\[section\]!i) {
	#$1 = theorem env name
	#$2 = theorem type
	my $thm_envname = $1;
	my $thm_type = $2;
	my $thm_maintype = $1;

	$thmhash{$thm_envname} = $thm_type;
	$thm_autonumber = 1;

	#now find everything else that is associated with it
	# \newtheorem{$envname}[$thm_maintype]{$type}
	$thm_maintype = quotemeta($thm_maintype);

#	$txt .= "$thm_maintype \n $pre \n";
	while ($pre =~ m!\\newtheorem\s*\{(.*?)\}\[$thm_maintype\]\{(.*?)\}!i) {
	    #$1 = env name
	    #$2 = thm type
	    $thm_envname = $1;
	    $thm_type = $2;
	    $thmhash{$thm_envname} = $thm_type;

	    $thm_envname = quotemeta($thm_envname);
	    $thm_type = quotemeta($thm_type);
	    $pre =~ s!\\newtheorem\{$thm_envname\}\[$thm_maintype\]\{$thm_type\}!!i;

#	    $txt .= "$thm_envname => $thm_type\n";
	}
    }
}

1;

=head2 Supported simple and complex commands

=begin text

use TWiki:Plugins.PerlDocPlugin to see a complete list of supported commands

=end text

=begin man

use TWiki:Plugins.PerlDocPlugin to see a complete list of supported commands

=end man

=begin twiki

   * commands with reasonably complete support (.tex --> HTML/TML)
      * section, subsection, subsubsection
      * cite, ref
      * parbox, fbox
      * emph, em, centering, bf, textit, textbf, centerline
      * large, small, tiny, footnotesize
      * verb
      * bibliographystyle, bibliography (with the TWiki:Plugins.BibtexPlugin installed)

   * commands with limited support
      * includegraphics, 
      * label (works with equations, figures, tables, and sections) 
      * tabular (alignment and \hline works, vertical lines are ignored however.  multicolumn support needs to be added.)
      * title, address, name, maketitle (these work, but don&rsquo;t match the latex class output of the original document)

   * commands that are ignored
      * vspace, hspace, vfill, noindent, sloppy, mainmatter

=end twiki

All mathmode commands are supported, as all mathmode enviroments are
rendered as an image using the background C<latex> engine.  Commands
that are not recognized are tagged as LATEX.  In future versions of
the module, these may be passed off to the rendering engine as well.
Error handling needs to be improved before this will be useful,
however.

=head2 Installation

For now, the TWiki::Plugins::LatexModePlugin::Parse module is only
available on the TWiki SVN development tree, 
<a href="http://svn.twiki.org:8181/svn/twiki/branches/TWikiRelease04x00/twikiplugins/LatexModePlugin/lib/TWiki/Plugins/LatexModePlugin">here</a>.
Download the Parse.pm file and copy it to the
C<lib/TWiki/Plugins/LatexModePlugin/> directory of your TWiki
installation.  Documentation for the module is provided in 
C<pod> format, and can be completely viewed using the TWiki:Plugins.PerlDocPlugin 
or partially viewed using C<perldoc> or C<pod2text>.


=head2 Translation syntax

Here is a description of the syntax used to define LaTeX to
HTML/TML translations in the module.

Environments are currently handled by code chunks.  See the
C<convertEnvironment> subroutine for examples.

The syntax for complex commands is a mash-up between LaTeX and
Perl.  In a single line, the command and its replacement are
described.  This first character is the array seperator, used in the
Parse C<split> command.

=over 1 

=item *

The first array element is the latex command.

=item *

The second element is the number of bracketed blocks the command uses

=item *

The third array element is the replacement command.

=back

The numbered strings, =$1, $2, ...= etc., are used to declare the
placement of the bracketed blocks in the replacement.  Command
options, =\cmd[ _opts_ ]{ .. }= can be included with an =$o= string in
the replacement.

An example:

   !\parbox!2!<table align="left" width="$1"><tr><td>$2</table>!


If one needs greater flexibility, the replacement command can be a
function call.  The function call needs to start with an apersand,
C<&>, and the full function name needs to be regestered in the global
C<regSubs> array.  See the lines for C<\author>, C<\title>, and
C<\address> for examples.


Feel free to submit code patches to expand the list of known commands
and environments!


=head2 Caveat Emptor

This is what it is.  And it is not a replacement for more complete
LaTeX2HTML translators like
[[http://www.latex2html.org/][latex2html]],
[[http://pauillac.inria.fr/~maranget/hevea/index.html][helvea]]
or [[http://www.ccs.neu.edu/home/dorai/tex2page/tex2page-doc.html][tex2page]].
It may eventually grow to become something close to those, but it's
not there yet.

=head2 Dev Notes

=head3 Rendering Weirdness.

It turns out that the idea of passing off unwieldy markup to the
rendering engine is dicey at best.  This was attempted with
=\maketitle=, and =dvipng= complained about missing fonts.  It's
probably better to have custom rountines to produce HTML/TML where
possible.

Switching between =dvips+convert= and =dvipng= can get around this
problem to render all of the images.  But this is not a serious
solution.

=head3 Including Graphics

There are many ways to include graphics in latex files.  So, I figured the most reasonable way to support them all is to render them using the backend image rendering.  As of TWiki:Plugins.LatexModePlugin v3.3, the rendering of images in TWiki can be done dynamically using =dvipng=, =dvips=, or =pdflatex=.  So, to render images in twiki, one can 
   * use the =includegraphics= command from the =graphicx= package, but do not declare the filename extension.
   * attach the image to the topic, with the file type extension stated. <br> The Plugin recognizes .eps, .pdf, .png, and .jpg file types.
   * the correct rendering engine will be called based on the image filename extension.

Alternatively, one can write a custom TWiki macro to handle attached .pdf images (e.g. %SHOWPDF{image.pdf}%), and then use a translation declaration to render the image (e.g. =:\includegraphics:1:%SHOWPDF{$1}%:=).


=head2 Acknowledgements

Thanks to <a href="http://twiki.org/cgi-bin/view/Main/EvanChou">EvanChou</a> for the inspiration for taking this on, and for
providing the core parsing routines.


=cut

sub storeVerbatim {
    my $t = $_[0];
    $t =~ s/\s/_/g if ( ($_[1]) and ($_[1] eq '*'));
    $t =~ s/(^\s+)|(\s+$)//g;   # TWiki requires no spaces between '=' and verbatim line

    push( @{ TWiki::Func::getContext()->{'LMPcontext'}->{'verb'} }, $t );
    return( scalar( @{ TWiki::Func::getContext()->{'LMPcontext'}->{'verb'} } ) - 1 );
}

sub extractVerbatim {

    my @a = @{ TWiki::Func::getContext()->{'LMPcontext'}->{'verb'} };

    my $block = $a[ $_[0] ];

    $block =~ s!^\\begin\{verbatim\}!<verbatim>!;
    $block =~ s!\\end\{verbatim\}$!</verbatim>!;

    $block = '='.$block.'=' unless ($block =~ m/\<verbatim\>/);

    return( $block );
}

sub addToTitle {

    my ($str) = @_;   

    TWiki::Func::getContext()->{'LMPcontext'}->{'title'} .= $str."\n";
    printF( "title now:\n".TWiki::Func::getContext()->{'LMPcontext'}->{'title'} );
    return('');
}

sub formThanks {
    my ($str) = @_;

    my $cnt =   TWiki::Func::getContext()->{'LMPcontext'}->{'thankscnt'};
    $cnt = $cnt + 1;

    TWiki::Func::getContext()->{'LMPcontext'}->{'thanks'} .=
        $cnt.'. '.$str."<br>\n";

    TWiki::Func::getContext()->{'LMPcontext'}->{'thankscnt'} = $cnt;

    # return( '%BEGINLATEX{inline="1"}% $^'.$cnt.'$ %ENDLATEX%' );
    return( '<sup>'.$cnt.'</sup>' );

}

sub makeTitle {
    my $t = TWiki::Func::getContext()->{'LMPcontext'}->{'title'}.
        "\n<br>\n".
        TWiki::Func::getContext()->{'LMPcontext'}->{'thanks'}.
        "\n<br>\n";
    return( $t );
}

sub formBib {
    my ($str) = @_;
    printF("formBib: $str ");

    if ($str =~ m/style\=/) {
        TWiki::Func::getContext()->{'LMPcontext'}->{'bibstyle'} = $str;
        return('');
    } else {

        my $style = TWiki::Func::getContext()->{'LMPcontext'}->{'bibstyle'};
        my @files = ();
        $str =~ s/.*?\=\"(.*)\"$/$1/;
        foreach my $f (split(/\,/,$str)) {
            push(@files,$f.".bib");
        }
        my $t = join(',',@files);
        return( "\n\n".'%BIBTEXREF{ '.$style.' file="'.$t.'"}%' );
    }
}


sub handleAuthor {
    my ($str) = @_;
    my @a = split(/\\and/,$str);
    if (scalar(@a)>1) {
        $a[ $#a ] = ' and '.$a[ $#a  ];
        $str = join(', ',@a );
    }

    addToTitle('<div align="center"><font size="+1">'.$str.'</font></div>');

}

sub formInst {
    my ($str) = @_;
    my @a = split(/\\and/,$str);

    my $cnt =   TWiki::Func::getContext()->{'LMPcontext'}->{'thankscnt'};
    foreach (@a) {
        $cnt = $cnt + 1;

        TWiki::Func::getContext()->{'LMPcontext'}->{'thanks'} .=
            $cnt.'. '.$_."<br>\n";

        TWiki::Func::getContext()->{'LMPcontext'}->{'thankscnt'} = $cnt;
    }
}

# 
# 
# :\title:1: <h1 align="center">$1</h1> :
# 
# :\includegraphics:1:%SHOWPDF{$1}%:
__DATA__
:\section:1:---+ $1 \n:
:\subsection:1:---++ $1 \n::
:\subsubsection:1:---+++ $1 \n::
:\cite:1:~%CITE{$1}%:
!\ref!1!~%REFLATEX{$1}%!
!\eqref!1!~%REFLATEX{$1}%!
!\parbox!2!<table align="left" width="$1"><tr><td>$2</table>!
!\fbox!1!<table align="left" border="1"><tr><td>$1</table>!
:\emph:1: <em>$1</em>:
:\vspace*:1::
:\vspace:1::
:\hspace*:1::
:\hspace:1::
:\name:1:&addToTitle('<div align="center">$1</div>'):
:\includegraphics:1:%BEGINLATEX{attachment="$1" engine="pdf"}% \includegraphics$o{$1} %ENDLATEX%:
:\label:1:$1:  # modifies a past-parsed string to insert %SECLABEL% above
:\bibliographystyle:1:&formBib('bibstyle="$1"'):
:\bibliography:1:&formBib('file="$1"'):
:\maketitle:0:&makeTitle():
:\thanks:1:&formThanks('$1'):
!\footnote!1! <br><blockquote><hr style="height:1px;"><font size="-3">Footnote: $1 </font><hr style="height:1px;"></blockquote>!
:\runningtitle:2: :
:\title:1:&addToTitle(<h1 align="center">$1</h1>):
:\author:1:&handleAuthor('$1'):
!\address!1!&addToTitle(<table align="center"><tr><td valign="top">Address correspondence to:<td valign="top">$1</table>)!
:\url:1: $1:
:\textit:1: _$1_ :
:\textbf:1: *$1* :
:\centerline:1:<div align="center">$1</div>:
:\thispagestyle:1: :
:\pagestyle:1: :
:\frontmatter:0::
:\mainmatter:0::
!\titlerunning!1! *Running Title:* $1!
!\authorrunning!1! *Authors:* $1!
:\tocauthor:1::
:\institute:1:&formInst('$1'):
:\inst:1:<sup>$1</sup>:
:\email:0: :
:\AE:0: &AElig;:
:\ae:0: &aelig;:
:\tableofcontents:0:%TOC%:
!\keywords!1! <blockquote><b>Keywords:</b> $1 </blockquote> !
!\multicolumn!3!<td span="$1">$3</td>!
