# LatexModePlugin::CrossRef.pm
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

package TWiki::Plugins::LatexModePlugin::CrossRef;

use strict;

sub handleSections {

    my ($l,$e,$lbltag,$text) = @_;
    my $cl = length($l);

    my $MAXDEPTH = TWiki::Func::getContext()->{'LMPcontext'}->{'maxdepth'};

    my $label = '';
    if ($lbltag and ($lbltag =~ m/\{(.*?)\}/)) {
        $label = $1;
        $label = 'sec:'.$label unless ($label =~ m/^sec:/);
    }

    my $ret = '---'.$l.' '.$text." \n";
    if (exists(TWiki::Func::getContext()->{'genpdflatex'})) {
        $ret .= '<latex>\label{'.$label."}</latex>\n" if ($label ne '');
        return($ret);
    }
    return('---'.$ret) if ( ($cl > $MAXDEPTH) );

    
    TWiki::Func::getContext()->{'LMPcontext'}->{'sec'.$cl.'cnt'} += 1;

    my $sn = '';
    for my $c ( 1 .. $cl ) {
        $sn .= TWiki::Func::getContext()->{'LMPcontext'}->{'sec'.$c.'cnt'} ;
        $sn .= '.' if $c < $cl;
    }

    if ( $cl < TWiki::Func::getContext()->{'LMPcontext'}->{'curdepth'} )
    {
        for my $c ( ($cl+1) .. $MAXDEPTH ) {
            TWiki::Func::getContext()->{'LMPcontext'}->{'sec'.$c.'cnt'} = 0;
          }
    }
    TWiki::Func::getContext()->{'LMPcontext'}->{'curdepth'} = $cl;

    TWiki::Func::getContext()->{'LMPcontext'}->{'secrefs'}->{$label} = $sn;

    $ret = "\n<!-- ";
    $ret .= '<nop>Sub' x ($cl-1);
    $ret .= "Section ";
    $ret .= "-->";
    $ret .= " <a name=\"$label\"></a> " if ($label ne '');
    $ret .= "\n---";
    $ret .= '+' x $cl;
    $ret .= $e." $sn. ".$text;
    return( $ret );

}

# =========================
sub handleReferences
{
# This function converts references to defined
# equations/figures/tables and replaces them with the Eqn/Fig/Tbl
# number
### my ( $math_string ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    my $ref = $_[0];	
    my ($backref,$txt) = ("",""); 

    my %LMPc = %{ TWiki::Func::getContext()->{'LMPcontext'} };

    if (exists(TWiki::Func::getContext()->{'genpdflatex'})) {
        $txt = '<latex>\ref{'.$ref.'}</latex>';

    } else {

        # my %tblrefs = %{ $LMPc{'tblrefs'} };
        my %tblrefs = defined(%{ $LMPc{'tblrefs'} }) ? %{$LMPc{'tblrefs'}} : ();
        my %figrefs = defined(%{ $LMPc{'figrefs'} }) ? %{$LMPc{'figrefs'}} : ();
        my %eqnrefs = defined(%{ $LMPc{'eqnrefs'} }) ? %{$LMPc{'eqnrefs'}} : ();
        my %secrefs = defined(%{ $LMPc{'secrefs'} }) ? %{$LMPc{'secrefs'}} : ();
        # my %eqnrefs = %{ $LMPc{'eqnrefs'} };
        # print STDERR map {"$_ => $secrefs{$_}\n"} keys %secrefs;

    if ($ref=~m/^sec\:/) {
        $backref = exists($secrefs{$ref}) ? $secrefs{$ref} : "?? REFLATEX error: {$ref} not defined in sections list ??";
        $txt = '<a href="#'.$ref.'">'.$backref.'</a>';
    } elsif ($ref=~m/^tbl\:/) {
        $backref = exists($tblrefs{$ref}) ? $tblrefs{$ref} : "?? REFLATEX error: {$ref} not defined in table list ??";
        $txt = '<a href="#'.$ref.'">'.$backref.'</a>';
    } elsif ($ref=~m/^fig\:/) {
        $backref = exists($figrefs{$ref}) ? $figrefs{$ref} : "?? REFLATEX error: {$ref} not defined in fig list ??";
        $txt = '<a href="#'.$ref.'">'.$backref.'</a>';
    } else {
        if (exists($eqnrefs{$ref})) {
            $backref = $eqnrefs{$ref}; }
        elsif (exists($eqnrefs{ "eqn:".$ref })) {
            $backref = $eqnrefs{ "eqn:".$ref }; }
        else { $backref = "?? REFLATEX{$ref} not defined in eqn list ??"; }
        $txt = '(<a href="#'.$ref.'">'.$backref.'</a>)';
    }
    }

    return($txt);
}

# =========================
sub handleFloat
{
# This function mimics the construction of float environments in latex,
# producing a back-reference list for Figures and Tables.

### my ( $input ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    my $input = $_[0];	
    my $prefs = $_[1];

    my %c = %{ &TWiki::Func::getContext() }; 
    my %LMPc = %{ $c{'LMPcontext'} };

    my @a=('0'..'9','a'..'z','A'..'Z');
    my $str = map{ $a[ int rand @a ] } (0..7);
    my %opts = ( 'label' => $str,
                 'span'  => 'onecol',
                 'caption' => ' ' );

    # fix inputs to catch nested TWiki markup
    my $cnt = 0; 
    my $tmp = '{'.$prefs.'}%'.$input;
    # print STDERR "CrossRef: handleFloat: ".$tmp."\n";
    while ($tmp =~ m/(\{|\})(%?)/g) {
        ($1 eq '{') ? $cnt++ : $cnt--;
        last if ( ($cnt == 0) and ($2 eq '%') );
    }
    $prefs = substr($tmp,1,(pos $tmp)-2,'');
    $input = substr($tmp,2,length($input));
    # print STDERR "CrossRef: handleFloat: ".pos($tmp)."\t".$prefs."\n\t".$input."\n";


    my %opts2 = TWiki::Func::extractParameters( $prefs );
    map { $opts{$_} = $opts2{$_} } keys %opts2;
    # while ( $prefs=~ m/(.*?)=\"(.*?)\"/g ) {
    #     my ($a,$b) = ($1,$2);
    #     # remove leading/trailing whitespace from key names
    #     $a =~ s/^\s*|\s*$//;    
    # 
    #     $opts{$a} = $b;
    # }

    my $env = ($_[2] eq 'fig') ? "Figure" : "Table" ;
    my $tc  = ($opts{'span'} =~ m/^twoc/) ? '*' : '' ;

    # ensure that the first 4 chars of the label conform to 
    # 'fig:' or 'tbl:' or ...
    ( $opts{'label'} = $_[2].":".$opts{'label'} )
        unless ( substr($opts{'label'},0,4) eq $_[2].':' );
        
    # print STDERR map {" $_ => $opts{$_}\n" } keys %opts;
    my $txt2 = "";
    if( exists(TWiki::Func::getContext()->{'genpdflatex'}) ) {           ## for genpdflatex
        # in Cairo (at least) latex new-lines, '\\', get translated to 
        # spaces, '\', but if they appear at the end of the line. 
        # So pad in a few spaces to protect them...
        $input =~ s!\n!  \n!g;

        $txt2 = '<latex>';
        $txt2 .= "\n\\begin{".lc($env).$tc."}\\centering\n";
        $txt2 .= $input."\n\\caption{".$opts{'caption'}."}\n";
        $txt2 .= '\label{'.$opts{'label'}."}\n\\end{".lc($env).$tc."}";
        $txt2 .= '</latex>';
        
    } else {
        ## otherwise, generate HTML ...

        my %figrefs = defined(%{ $LMPc{'figrefs'} }) ? %{$LMPc{'figrefs'}} : ();
        my %tblrefs = defined(%{ $LMPc{'tblrefs'} }) ? %{$LMPc{'tblrefs'}} : ();

        my $infrmt = '<tr><td><td align="center">%s</td><td></tr>';
        my $cpfrmt = '<tr><td><td width="90%%" id="lmp-caption"> *%s %d*: %s</td><td></tr>';

        if ($_[2] eq 'fig') {
            $LMPc{'fig'}++;
            
            $txt2 .= sprintf($infrmt."\n",$input).
                sprintf($cpfrmt."\n",$env,$LMPc{'fig'},$opts{'caption'});
                
            my $key = $opts{'label'};
            $figrefs{$key} = $LMPc{'fig'};
            
        } elsif ($_[2] eq 'tbl') {
            $LMPc{'tbl'}++;
            
            $txt2 .= sprintf($cpfrmt."\n",$env,$LMPc{'tbl'},$opts{'caption'}).
                sprintf($infrmt."\n",$input);
            
            my $key = $opts{'label'};
            $tblrefs{$key} = $LMPc{'tbl'};
        } else {
            $txt2 .= $input;
        }
        $txt2 = '<a name="'.$opts{'label'}.'"></a>' .
            '<table width="100%" border=0>'."\n" .
            $txt2 .
            '</table>';

        $LMPc{'tblrefs'} = \%tblrefs;
        $LMPc{'figrefs'} = \%figrefs;

        TWiki::Func::getContext()->{'LMPcontext'} = \%LMPc;
        
    } # end. if !($latexout)

    return($txt2);
}

1;
