# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.com
# Copyright (C) 2005... Aurelio A. Heckert, aurium@gmail.com
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
# This is an empty TWiki plugin. Use it as a template
# for your own plugins; see TWiki.TWikiPlugins for details.
#
# Each plugin is a package that may contain these functions:        VERSION:
#
#   earlyInitPlugin         ( )                                     1.020
#   initPlugin              ( $topic, $web, $user, $installWeb )    1.000
#   initializeUserHandler   ( $loginName, $url, $pathInfo )         1.010
#   registrationHandler     ( $web, $wikiName, $loginName )         1.010
#   beforeCommonTagsHandler ( $text, $topic, $web )                 1.024
#   commonTagsHandler       ( $text, $topic, $web )                 1.000
#   afterCommonTagsHandler  ( $text, $topic, $web )                 1.024
#   startRenderingHandler   ( $text, $web )                         1.000
#   outsidePREHandler       ( $text )                               1.000
#   insidePREHandler        ( $text )                               1.000
#   endRenderingHandler     ( $text )                               1.000
#   beforeEditHandler       ( $text, $topic, $web )                 1.010
#   afterEditHandler        ( $text, $topic, $web )                 1.010
#   beforeSaveHandler       ( $text, $topic, $web )                 1.010
#   afterSaveHandler        ( $text, $topic, $web, $errors )        1.020
#   writeHeaderHandler      ( $query )                              1.010  Use only in one Plugin
#   redirectCgiQueryHandler ( $query, $url )                        1.010  Use only in one Plugin
#   getSessionValueHandler  ( $key )                                1.010  Use only in one Plugin
#   setSessionValueHandler  ( $key, $value )                        1.010  Use only in one Plugin
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
package TWiki::Plugins::FlowchartPlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $pluginName
        $debug $exampleCfgVar
    );

# This should always be $Rev: 13786 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 13786 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

# for th 1.0 need:
#   * Validate data
#   * show error message
$pluginName = 'FlowchartPlugin';  # Name of this Plugin

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

    # Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
    $exampleCfgVar = TWiki::Func::getPluginPreferencesValue( "EXAMPLE" ) || "default";

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

    # do custom extension rule, like for example:
    $_[0] =~ s/%FLOWCHART%/&mostraFluxograma($_[0], $_[1], $_[2], '')/ge;
    $_[0] =~ s/%FLOWCHART\{([^\n]*?)\}%/&mostraFluxograma($_[0], $_[1], $_[2], $1)/ge;
    $_[0] =~ s/\s*%FLOWCHART_BR%\s*/ /g;
    $_[0] =~ s/%FLOWCHART_START%//g;
    $_[0] =~ s/%FLOWCHART_STOP%//g;
    # $_[0] =~ s/%XYZ{(.*?)}%/&handleXyz($1)/ge;
}

my %fluxItens;
my $totItens = 0;
my %caixa = (
  'w'     => 0,
  'h'     => 0,
  'areaX' => 0,
  'areaY' => 0,
  'bigerPosX' => 1,
  'bigerPosY' => 1,
  'color_start'     => 'c0d8c0',
  'color_end'       => 'b0b8c0',
  'color_end-error' => 'e0a0a0',
  'color_action'    => 'c0d0e0',
  'color_question'  => 'e0d0c0',
  'style'   => 'fill-opacity:1;stroke:none;stroke-width:1.5;stroke-linecap:round;stroke-linejoin:round;overflow:visible;'
);
my %seta = (
  'N'     => "M 5,0 L 0,10 L 5,8 L 10,10 L 5,0 z",
  'S'     => "M 5,10 L 0,0 L 5,2 L 10,0 L 5,10 z",
  'L'     => "M 10,5 L 0,0 L 2,5 L 0,10 L 10,5 z",
  'O'     => "M 0,5 L 10,0 L 8,5 L 10,10 L 0,5 z",
  'style' => 'stroke:none;fill:#707070;'
);
my $textSize = 17;
my $styleText = "font-size:${textSize}px;font-style:normal;font-variant:normal;font-weight:normal;font-stretch:normal;fill:#000000;stroke:none;font-family:Bitstream Vera Sans;text-anchor:middle;writing-mode:lr-tb;";
my $styleLinha = 'stroke-width:2px;stroke:#000000;stroke-opacity:0.40;fill:none;';


sub mostraFluxograma
{
  my ( $text, $topic, $web, $params ) = @_;
  my $myPub = TWiki::Func::getPubDir() ."/$web/$topic";
  my $mapImg = TWiki::Func::readFile( "$myPub/flowchartMapImg_$topic.txt" );
  
  $style = TWiki::Func::extractNameValuePair( $params, 'tag-style' ) ||
           TWiki::Func::getPluginPreferencesValue( 'TAG_STYLE' )    ||
           'border:1px dotted #505050;';
  
  return "$mapImg
<img src=\"\%ATTACHURL%/flowchart_$topic.png\" usemap=\"#flowchart_$topic\" style=\"$style\" alt=\"flowchart_$topic\"/>";
}

sub desenhaFluxograma
{
  my ( $text, $topic, $web, $params ) = @_;
  my $myPub = TWiki::Func::getPubDir() ."/$web/$topic";
  my $percentReduce;

  $caixa{'w'} =     TWiki::Func::extractNameValuePair( $params, 'item-w' ) ||
                    TWiki::Func::getPluginPreferencesValue('ITEM_WIDTH')   ||
                    140;
  $caixa{'h'} =     TWiki::Func::extractNameValuePair( $params, 'item-h' ) ||
                    TWiki::Func::getPluginPreferencesValue('ITEM_HEIGHT')  ||
                    40;
  $caixa{'areaX'} = TWiki::Func::extractNameValuePair( $params, 'area-w' ) ||
                    TWiki::Func::getPluginPreferencesValue('ITEM_AREA_W')  ||
                    180;
  $caixa{'areaY'} = TWiki::Func::extractNameValuePair( $params, 'area-h' ) ||
                    TWiki::Func::getPluginPreferencesValue('ITEM_AREA_H')  ||
                    70;
  $percentReduce =  TWiki::Func::extractNameValuePair( $params, 'percent' ) ||
                    TWiki::Func::getPluginPreferencesValue('PERCENT_IMG')   ||
                    70;
  $textSize =       TWiki::Func::extractNameValuePair( $params, 'text-size' ) ||
                    TWiki::Func::getPluginPreferencesValue('TEXT_SIZE')       ||
                    17;

  $text =~ s/.*%FLOWCHART_START%(.*)$/$1/   if ( $text =~ m/%FLOWCHART_START%/ );
  $text =~ s/(.*)%FLOWCHART_STOP%.*$/$1/    if ( $text =~ m/%FLOWCHART_STOP%/ );
  my ( $id, $title, $goto, $gotoYes, $gotoNo, $color );
  foreach $line ( split /\n/, $text ) {
    if ( $line =~ m/^---[+][+][ ]+(.+)/ ) {
      registerLastItem($id, $title, $type, $goto, $gotoYes, $gotoNo, $color);
      ( $id,  $title,   $type,    $goto,  $gotoYes,  $gotoNo,  $color ) =
      ( '',   '',       'action', '',     '',        '',       ''     );
      $title .= $1;
    }
    #if ( $line =~ m/^[ ][ ][ ]\*\s*(.+?[^ ])\s*:\s*(.+[^ ])\s*/ ) { # Não tá funcionando Porra!
    if ( $line =~ m/^\s\*\s*(.+?[^ ])\s*:\s*(.+[^ ])\s*/ ) { # Isso tá errado e funciona. Merda!
      $id = $2       if ( lc($1) eq 'id' );
      $type = $2     if ( lc($1) eq 'type' );
      $goto = $2     if ( lc($1) eq 'goto' );
      $gotoYes = $2  if ( lc($1) eq 'yes' );
      $gotoNo = $2   if ( lc($1) eq 'no' );
      $color = $2    if ( lc($1) eq 'color' );
    }
  }
  registerLastItem($id, $title, $type, $goto, $gotoYes, $gotoNo, $color);

  my $error = '';
  my $svg = &montaSVG($topic, $web);
  my $mapImg = &montaMapImg($topic, $web, $percentReduce);
  unless (-d $myPub){
    mkdir $myPub or die "can't create directory $myPub";
  }
  TWiki::Func::saveFile( "$myPub/flowchart_$topic.svg", $svg );
  TWiki::Func::saveFile( "$myPub/flowchartMapImg_$topic.txt", $mapImg );
  system ("convert", "$myPub/flowchart_$topic.svg",
          '-resize', $percentReduce.'%x'.$percentReduce.'%', "$myPub/flowchart_$topic.png");
}

my $itemPositionDefault = 1; # will be 1 only to the frist!
my $firstItemId;
my $lastItemId;
sub registerLastItem
{
  use Encode;
  my ($id, $title, $type, $goto, $gotoYes, $gotoNo, $color) = @_;
  if ( $title ) {
    $totItens++;
    $id =~ s/\s*([^ ]*)\s*/$1/g;
    $id =~ s/[^a-zA-Z0-9]/_/g;
    $id = "fluxIten$totItens" if ( !$id );
    #$title = `echo $title | iconv -t utf-8`;                # convert to utf-8 by shell
    #$title = encode("utf8", decode("iso-8859-1", $title));  # convert to utf-8 from iso
    $title = encode("utf8", $title);                         # convert to utf-8 (from anything?)
    $fluxItens{$id} = {
      'title'   => $title,
      'type'    => lc $type,
      'goto'    => $goto,
      'gotoYes' => $gotoYes,
      'gotoNo'  => $gotoNo,
      'x'       => $itemPositionDefault,
      'y'       => $itemPositionDefault,
      'color'   => $color
    };
    if ( $itemPositionDefault == 1 ) { # Yeah... this is the first item.
      $firstItemId = $id;
      $itemPositionDefault = 0  # to the other ones, the position is not defined.
    } else {
      if ( $fluxItens{$lastItemId}->{'type'} =~ m/question|end|end-error/ ) {
        $fluxItens{$lastItemId}->{'goto'} = '';
        if ( lc $fluxItens{$lastItemId}->{'gotoYes'} eq 'next' ){
          $fluxItens{$lastItemId}->{'gotoYes'} = $id;
        }
        if ( lc $fluxItens{$lastItemId}->{'gotoNo'} eq 'next' ){
          $fluxItens{$lastItemId}->{'gotoNo'} = $id;
        }
      } else {
        my $goto = lc $fluxItens{$lastItemId}->{'goto'};
        if ( $goto eq '' || $goto eq 'next' ) {
          $fluxItens{$lastItemId}->{'goto'} = $id;
        }
      }
    }
    $lastItemId = $id;
  }
}

sub montaSVG
{
  my ( $topic, $web ) = @_;

  my $svg = '<!-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  <<             Created with FlowchartPlugin for TWiki                >>
  <<  Get it on http://twiki.org/cgi-bin/view/Plugins/FlowchartPlugin  >>
    This flowchart was based on:
    '. TWiki::Func::getViewUrl( $web, $topic ) .'
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -->';

  $svg .= &encaixaItemRecursive();
  $svg .= &linkItensRecursive();
  
  return '<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg"'.
' width="'.  ( $caixa{bigerPosX} * $caixa{areaX} ) .'px"'.
' height="'. ( $caixa{bigerPosY} * $caixa{areaY} ) .'px">'."\n$svg\n</svg>";
}

sub encaixaItemRecursive
{
  my $id = $_[0];
  my $svg = "\n";
  if ( !$id ) { # it is the first item
    $id = $firstItemId;
    $_[1] = 1;
    $_[2] = 1;
  } else {
    if ( $fluxItens{$id}->{x} ) {
      return ''; # it's already defined.
    }
    $fluxItens{$id}->{x} = $_[1];
    $fluxItens{$id}->{y} = $_[2];
  }
  $caixa{x} = $fluxItens{$id}->{x} * $caixa{areaX} - ( ($caixa{areaX}+$caixa{w}) / 2);
  $caixa{y} = $fluxItens{$id}->{y} * $caixa{areaY} - ( ($caixa{areaY}+$caixa{h}) / 2);
  my $color = $caixa{ 'color_'.$fluxItens{$id}->{type} };
  $color = $fluxItens{$id}->{color}  if ( $fluxItens{$id}->{color} ne '' );
  if ( $fluxItens{$id}->{type} eq 'start' ) {
    $svg .= '  <rect id="caixa_'.$id.'" x="'.$caixa{x}.'" y="'.$caixa{y}.'"
        rx="'.($caixa{'h'}/3).'" ry="'.($caixa{h}/3).'"
        width="'.$caixa{'w'}.'" height="'.$caixa{h}.'"
        style="fill:#'.$color.';'.$caixa{style}.'" />';
  }
  if ( $fluxItens{$id}->{type} eq 'action' ) {
    $svg .= '  <rect id="caixa_'.$id.'" x="'.$caixa{x}.'" y="'.$caixa{y}.'"
        width="'.$caixa{'w'}.'" height="'.$caixa{h}.'"
        style="fill:#'.$color.';'.$caixa{style}.'" />';
  }
  if ( $fluxItens{$id}->{type} eq 'question' ) {
    #transform="matrix(escalaX, inclinaY, inclinaX, escalaY, posX, posY)"
    $svg .= '  <path id="caixa_'.$id.'"
        d="M 0.4,0.0 L 0.6,0.0 L 1.0,0.3 L 1.0,0.7 L 0.6,1.0 L 0.4,1.0 L 0.0,0.7 L 0.0,0.3 L 0.4,0.0 z"
        transform="matrix('.$caixa{'w'}.', 0,0, '.$caixa{'h'}.', '.$caixa{x}.','.$caixa{y}.')"
        style="fill:#'.$color.';'.$caixa{style}.'" />';
  }
  if ( $fluxItens{$id}->{type} eq 'end' || $fluxItens{$id}->{type} eq 'end-error' ) {
    $svg .= '  <rect id="caixa_'.$id.'" x="'.$caixa{x}.'" y="'.$caixa{y}.'"
        rx="'.($caixa{'h'}/3).'" ry="'.($caixa{h}/3).'"
        width="'.$caixa{'w'}.'" height="'.$caixa{h}.'"
        style="fill:#'.$color.';'.$caixa{style}.'" />';
  }
  $svg .= "\n".'  <text xml:space="preserve" id="text_'.$id.'" style="'.$styleText.'">';
  my $tilteLineX = $fluxItens{$id}->{x} * $caixa{areaX} - ( $caixa{areaX} / 2 );
  my $tilteLineY = $fluxItens{$id}->{y} * $caixa{areaY} - ( $caixa{areaY} / 2 );
  foreach $tilteLine ( split /%FLOWCHART_BR%/, $fluxItens{$id}->{title} ) {
    $tilteLine =~ s/<nop>//g;
    $tilteLine =~ s/^\s*([^\s].*[^\s])\s*$/$1/;
    $svg .= "<tspan x=\"$tilteLineX\" y=\"$tilteLineY\">$tilteLine</tspan>";
    $tilteLineY += $textSize;
  }
  $svg .= '</text>';
  if ( $fluxItens{$id}->{'goto'} ne '' ) {
    $caixa{bigerPosY} = ($_[2]+1)  if ( $caixa{bigerPosY} < ($_[2]+1) );
    $svg .= &encaixaItemRecursive ( $fluxItens{$id}->{'goto'}, $_[1], ($_[2]+1) );
  }
  my $gotoYesAlreadyExists;
  if ( $fluxItens{$id}->{'gotoYes'} ne '' ) {
    $caixa{bigerPosY} = ($_[2]+1)  if ( $caixa{bigerPosY} < ($_[2]+1) );
    if ( $fluxItens{$fluxItens{$id}->{'gotoYes'}}->{x} == 0 ) {
      $gotoYesAlreadyExists = 0;
      $svg .= &encaixaItemRecursive ( $fluxItens{$id}->{'gotoYes'}, $_[1], ($_[2]+1) );
    } else {
      $gotoYesAlreadyExists = 1;  # The next already exists. The gotoNo can go down!
    }
  }
  if ( $fluxItens{$id}->{'gotoNo'} ne '' ) {
    if ( $gotoYesAlreadyExists ) {
      $svg .= &encaixaItemRecursive ( $fluxItens{$id}->{'gotoNo'}, $_[1], ($_[2]+1) );
    } else {
      $caixa{bigerPosX}++   if ( $fluxItens{$fluxItens{$id}->{'gotoNo'}}->{x} == 0 );
      if ( $fluxItens{$fluxItens{$id}->{'gotoNo'}}->{x} == 0 ) {
        $fluxItens{$fluxItens{$id}->{'gotoNo'}}->{'firstInTheColumn'} = 1;
        $svg .= &encaixaItemRecursive ( $fluxItens{$id}->{'gotoNo'}, $caixa{bigerPosX}, $_[2] );
      }
    }
  }
  return $svg
}

sub linkItensRecursive
{
  my $idFrom = $_[0];
  my $svg = "\n\n";
  
  if ( !$idFrom ) { # it is the first item
    $idFrom = $firstItemId;
  }
  
  if ( $fluxItens{$idFrom}->{linked} ) {
    return ''; # it's already defined.
  }
  $fluxItens{$idFrom}->{linked} = 1;
  
  if ( $fluxItens{$idFrom}->{'goto'}    eq '' &&
       $fluxItens{$idFrom}->{'gotoYes'} eq '' &&
       $fluxItens{$idFrom}->{'gotoNo'}  eq '' ) {
    return ''; # it is the end.
  }
  
  # d="M Ponto1 C Guia1 Guia2 Ponto2"
  my ( $iniX,$iniY, $endX,$endY, $guideIniX,$guideIniY, $guideEndX,$guideEndY, $setaType, $exitBy );
  my $gotoYesExitBy;
  
  if ( $fluxItens{$idFrom}->{'goto'} ne '' ) {
    $idTo = $fluxItens{$idFrom}->{'goto'};
    ( $iniX,$iniY, $endX,$endY, $guideIniX,$guideIniY, $guideEndX,$guideEndY, $setaType, $exitBy ) =
      &getLinkLine( $idFrom, $idTo );
    $svg .= "  <path id=\"form_${idFrom}_to_$idTo\"
        d=\"M $iniX,$iniY C $guideIniX,$guideIniY $guideEndX,$guideEndY $endX,$endY\"
        style=\"$styleLinha\" />\n";
    $svg .= '  <path id="seta_to_'.$idTo.'" d="'. $seta{$setaType} .'"
        transform="translate('.($endX-5).','.($endY-5).')" style="'.$seta{style}.'" />';
    $svg .= &linkItensRecursive($idTo);
  }
  if ( $fluxItens{$idFrom}->{'gotoYes'} ne '' ) {
    $idTo = $fluxItens{$idFrom}->{'gotoYes'};
    ( $iniX,$iniY, $endX,$endY, $guideIniX,$guideIniY, $guideEndX,$guideEndY, $setaType, $exitBy ) =
      &getLinkLine( $idFrom, $idTo );
    $gotoYesExitBy = $exitBy;
    $svg .= "  <path id=\"form_${idFrom}_to_$idTo\"
        d=\"M $iniX,$iniY C $guideIniX,$guideIniY $guideEndX,$guideEndY $endX,$endY\"
        style=\"$styleLinha\" />\n";
    $svg .= '  <path id="seta_to_'.$idTo.'" d="'. $seta{$setaType} .'"
        transform="translate('.($endX-5).','.($endY-5).')" style="'.$seta{style}.'" />';
    $svg .= "\n  <circle cx=\"$iniX\" cy=\"$iniY\" r=\"2.5\" stroke=\"none\" fill=\"green\"/>";
    $svg .= &linkItensRecursive($idTo);
  }
  if ( $fluxItens{$idFrom}->{'gotoNo'} ne '' ) {
    $idTo = $fluxItens{$idFrom}->{'gotoNo'};
    ( $iniX,$iniY, $endX,$endY, $guideIniX,$guideIniY, $guideEndX,$guideEndY, $setaType, $exitBy ) =
      &getLinkLine( $idFrom, $idTo );
    if ( $exitBy eq $gotoYesExitBy ) {
      $iniX += 5   if ( $exitBy eq 'N' || $exitBy eq 'S' );
      $iniY -= 5   if ( $exitBy eq 'L' || $exitBy eq 'O' );
    }
    $svg .= "  <path id=\"form_${idFrom}_to_$idTo\"
        d=\"M $iniX,$iniY C $guideIniX,$guideIniY $guideEndX,$guideEndY $endX,$endY\"
        style=\"$styleLinha\" />\n";
    $svg .= '  <path id="seta_to_'.$idTo.'" d="'. $seta{$setaType} .'"
        transform="translate('.($endX-5).','.($endY-5).')" style="'.$seta{style}.'" />';
    $svg .= "\n  <circle cx=\"$iniX\" cy=\"$iniY\" r=\"2.5\" stroke=\"none\" fill=\"red\"/>";
    $svg .= &linkItensRecursive($idTo);
  }

  return $svg
}

sub getLinkLine
{
  my ( $idFrom, $idTo ) = @_;
  my ( $iniX,$iniY, $endX,$endY, $guideIniX,$guideIniY, $guideEndX,$guideEndY, $setaType, $exitBy );
  
  if ( $fluxItens{$idFrom}->{x} < $fluxItens{$idTo}->{x} ) {
    if ( $fluxItens{$idFrom}->{y} == $fluxItens{$idTo}->{y} ) {   # Case 1
      $iniX = $fluxItens{$idFrom}->{x} * $caixa{areaX} - ( ($caixa{areaX}-$caixa{w}) / 2 );
      $iniY = $fluxItens{$idFrom}->{y} * $caixa{areaY} - ( $caixa{areaY} / 2 ) + ($caixa{h}/6);
      $endX = ($fluxItens{$idTo}->{x}-1) * $caixa{areaX} + ( ($caixa{areaX}-$caixa{w}) / 2 );
      $endY = $fluxItens{$idFrom}->{y} * $caixa{areaY} - ( $caixa{areaY} / 2 ) - ($caixa{h}/6);
      if( ($fluxItens{$idFrom}->{x}+1) == $fluxItens{$idTo}->{x} ) {
        $guideIniX = $iniX + (($caixa{areaX}-$caixa{w})/2);   $guideIniY = $iniY;
        $guideEndX = $endX - (($caixa{areaX}-$caixa{w})/2);   $guideEndY = $endY;
      } else {
        $guideIniX = $iniX + ($caixa{areaX}/2);   $guideIniY = $iniY + ($caixa{areaY}/4);
        $guideEndX = $endX - ($caixa{areaX}/2);   $guideEndY = $endY - ($caixa{areaY}/4);
      }
      $setaType = 'L';
      $exitBy = 'L';
    }
    if ( $fluxItens{$idFrom}->{y} < $fluxItens{$idTo}->{y} ) {    # Case 2
      $iniX = $fluxItens{$idFrom}->{x} * $caixa{areaX} - ( ($caixa{areaX}-$caixa{w}) / 2 );
      $iniY = $fluxItens{$idFrom}->{y} * $caixa{areaY} - ( $caixa{areaY} / 2 ) + ($caixa{h}/6);
      $endX = ($fluxItens{$idTo}->{x}-1) * $caixa{areaX} + ( ($caixa{areaX}-$caixa{w}) / 2 );
      $endY = $fluxItens{$idTo}->{y} * $caixa{areaY} - ( $caixa{areaY} / 2 ) - ($caixa{h}/6);
      if( ($fluxItens{$idFrom}->{x}+1) == $fluxItens{$idTo}->{x} ) {
        $guideIniX = $endX + ($caixa{areaX}-$caixa{w});   $guideIniY = $iniY;
        $guideEndX = $iniX - ($caixa{areaX}-$caixa{w});   $guideEndY = $endY;
      } else {
        $guideIniX = ( $iniX + $endX ) / 2;   $guideIniY = $iniY;
        $guideEndX = ( $iniX + $endX ) / 2;   $guideEndY = $endY;
      }
      $setaType = 'L';
      $exitBy = 'L';
    }
    if ( $fluxItens{$idFrom}->{y} > $fluxItens{$idTo}->{y} ) {    # Case 3
      $iniX = $fluxItens{$idFrom}->{x} * $caixa{areaX} - ( $caixa{areaX} / 2 ) - ($caixa{w}/8);
      $iniY = ($fluxItens{$idFrom}->{y}-1) * $caixa{areaY} + ( ($caixa{areaY}-$caixa{h}) / 2 );
      $endX = ($fluxItens{$idTo}->{x}-1) * $caixa{areaX} + ( ($caixa{areaX}-$caixa{w}) / 2 );
      $endY = $fluxItens{$idTo}->{y} * $caixa{areaY} - ( $caixa{areaY} / 2 ) - ($caixa{h}/6);
      $guideIniX = $iniX;   $guideIniY = $iniY - $caixa{areaY};
      $guideEndX = $endX - ($caixa{areaX}/2);   $guideEndY = $endY;
      $setaType = 'L';
      $exitBy = 'N';
    }
  }
  if ( $fluxItens{$idFrom}->{x} > $fluxItens{$idTo}->{x} ) {
    if ( $fluxItens{$idFrom}->{y} == $fluxItens{$idTo}->{y} ) {   # Case 4
      $iniX = ($fluxItens{$idFrom}->{x}-1) * $caixa{areaX} + ( ($caixa{areaX}-$caixa{w}) / 2 );
      $iniY = $fluxItens{$idFrom}->{y} * $caixa{areaY} - ( $caixa{areaY} / 2 ) + ($caixa{h}/6);
      $endX = $fluxItens{$idTo}->{x} * $caixa{areaX} - ( ($caixa{areaX}-$caixa{w}) / 2 );
      $endY = $fluxItens{$idTo}->{y} * $caixa{areaY} - ( $caixa{areaY} / 2 ) - ($caixa{h}/6);
      if( ($fluxItens{$idFrom}->{x}+1) == $fluxItens{$idTo}->{x} ) {
        $guideIniX = $iniX - (($caixa{areaX}-$caixa{w})/2);   $guideIniY = $iniY;
        $guideEndX = $endX + (($caixa{areaX}-$caixa{w})/2);   $guideEndY = $endY;
      } else {
        $guideIniX = $iniX - ($caixa{areaX}/2);   $guideIniY = $iniY + ($caixa{areaY}/4);
        $guideEndX = $endX + ($caixa{areaX}/2);   $guideEndY = $endY - ($caixa{areaY}/4);
      }
      $setaType = 'O';
      $exitBy = 'O';
    }
    if ( $fluxItens{$idFrom}->{y} < $fluxItens{$idTo}->{y} ) {    # Case 5
      $iniX = ($fluxItens{$idFrom}->{x}-1) * $caixa{areaX} + ( ($caixa{areaX}-$caixa{w}) / 2 );
      $iniY = $fluxItens{$idFrom}->{y} * $caixa{areaY} - ( $caixa{areaY} / 2 ) + ($caixa{h}/6);
      $endX = $fluxItens{$idTo}->{x} * $caixa{areaX} - ( ($caixa{areaX}-$caixa{w}) / 2 );
      $endY = $fluxItens{$idTo}->{y} * $caixa{areaY} - ( $caixa{areaY} / 2 ) - ($caixa{h}/6);
      if( ($fluxItens{$idFrom}->{x}-1) == $fluxItens{$idTo}->{x} ) {
        $guideIniX = $endX - ($caixa{areaX}-$caixa{w});   $guideIniY = $iniY;
        $guideEndX = $iniX + ($caixa{areaX}-$caixa{w});   $guideEndY = $endY;
      } else {
        $guideIniX = ( $iniX + $endX ) / 2;   $guideIniY = $iniY;
        $guideEndX = ( $iniX + $endX ) / 2;   $guideEndY = $endY;
      }
      $setaType = 'O';
      $exitBy = 'O';
    }
    if ( $fluxItens{$idFrom}->{y} > $fluxItens{$idTo}->{y} ) {    # Case 6
      if ( $fluxItens{$idFrom}->{'firstInTheColumn'} ) {
        $iniX = $fluxItens{$idFrom}->{x} * $caixa{areaX} - ( $caixa{areaX} / 2 ) - ($caixa{w}/8);
        $iniY = ($fluxItens{$idFrom}->{y}-1) * $caixa{areaY} + ( ($caixa{areaY}-$caixa{h}) / 2 );
        $guideIniX = $iniX;   $guideIniY = $iniY - $caixa{areaY};
        $exitBy = 'N';
      } else {
        $iniX = ($fluxItens{$idFrom}->{x}-1) * $caixa{areaX} + ( ($caixa{areaX}-$caixa{w}) / 2 );
        $iniY = $fluxItens{$idFrom}->{y} * $caixa{areaY} - ( $caixa{areaY} / 2 ) + ($caixa{h}/6);
        $exitBy = 'O';
      }
      $endX = $fluxItens{$idTo}->{x} * $caixa{areaX} - ( ($caixa{areaX}-$caixa{w}) / 2 );
      $endY = $fluxItens{$idTo}->{y} * $caixa{areaY} - ( $caixa{areaY} / 2 ) - ($caixa{h}/6);
      if ( ! $fluxItens{$idFrom}->{'firstInTheColumn'} ) {
        if( ($fluxItens{$idFrom}->{x}-1) == $fluxItens{$idTo}->{x} ) {
          $guideIniX = $endX - ($caixa{areaX}-$caixa{w});   $guideIniY = $iniY;
        } else {
          $guideIniX = ( $iniX + $endX ) / 2;   $guideIniY = $iniY;
        }
      }
      if( ($fluxItens{$idFrom}->{x}-1) == $fluxItens{$idTo}->{x} ) {
        $guideEndX = $iniX + ($caixa{areaX}-$caixa{w});   $guideEndY = $endY;
      } else {
        $guideEndX = ( $iniX + $endX ) / 2;   $guideEndY = $endY;
      }
      $guideEndX = $endX + ($caixa{areaX}/2);   $guideEndY = $endY;
      $setaType = 'O';
    }
  }
  if ( $fluxItens{$idFrom}->{x} == $fluxItens{$idTo}->{x} ) {
    if ( $fluxItens{$idFrom}->{y} < $fluxItens{$idTo}->{y} ) {    # Case 7
      if ( ($fluxItens{$idFrom}->{y}+1) == $fluxItens{$idTo}->{y} ) {  # Case 7.a
        $iniX = $fluxItens{$idFrom}->{x} * $caixa{areaX} - ( $caixa{areaX} / 2 );
        $iniY = $fluxItens{$idFrom}->{y} * $caixa{areaY} - ( ($caixa{areaY}-$caixa{h}) / 2 );
        $endY = ($fluxItens{$idTo}->{y}-1) * $caixa{areaY} + ( ($caixa{areaY}-$caixa{h}) / 2 );
        $endX = $iniX;
        $guideIniX = $iniX;   $guideIniY = $iniY;
        $guideEndX = $endX;   $guideEndY = $endY;
        $setaType = 'S';
        $exitBy = 'S';
      } else {  # . . . . . . . . . . . . . . . . . . . . . . . . . .  # Case 7.b
        $iniX = $fluxItens{$idFrom}->{x} * $caixa{areaX} - ( ($caixa{areaX}-$caixa{w}) / 2 );
        $iniY = $fluxItens{$idFrom}->{y} * $caixa{areaY} - ( $caixa{areaY} / 2 ) + ($caixa{h}/6);
        $endY = $fluxItens{$idTo}->{y} * $caixa{areaY} - ( $caixa{areaY} / 2 ) - ($caixa{h}/6);
        $endX = $iniX;
        $guideIniX = $iniX + ( $caixa{areaX}-$caixa{w} )/1.5;   $guideIniY = $iniY;
        $guideEndX = $endX + ( $caixa{areaX}-$caixa{w} )*1.5;   $guideEndY = $endY;
        $setaType = 'O';
        $exitBy = 'L';
      }
    }
    if ( $fluxItens{$idFrom}->{y} > $fluxItens{$idTo}->{y} ) {    # Case 8
      $iniX = $fluxItens{$idFrom}->{x} * $caixa{areaX} - ( ($caixa{areaX}-$caixa{w}) / 2 );
      $iniY = $fluxItens{$idFrom}->{y} * $caixa{areaY} - ( $caixa{areaY} / 2 ) + ($caixa{h}/6);
      $endY = $fluxItens{$idTo}->{y} * $caixa{areaY} - ( $caixa{areaY} / 2 ) - ($caixa{h}/6);
      $endX = $iniX;
      $guideIniX = $iniX + ( $caixa{areaX}-$caixa{w} )/1.5;   $guideIniY = $iniY;
      $guideEndX = $endX + ( $caixa{areaX}-$caixa{w} )*1.5;   $guideEndY = $endY;
      $setaType = 'O';
      $exitBy = 'L';
    }
  }
  
  return ( $iniX,$iniY, $endX,$endY, $guideIniX,$guideIniY, $guideEndX,$guideEndY, $setaType, $exitBy );
}

sub montaMapImg
{
  my ( $topic, $web, $perReduce ) = @_;
  $reduce = $perReduce / 100;
  return '<map name="flowchart_'.$topic.'">'. &encaixaMapImg($topic, $web, $reduce) ."\n</map>";
}
sub encaixaMapImg
{
  my ( $topic, $web, $reduce, $id ) = @_;
  my $mapImg = "\n";
  if ( !$id ) { # it is the first item
    $id = $firstItemId;
  }
  
  if ( $fluxItens{$id}->{maped} ) {
    return ''; # it's already defined.
  }
  $fluxItens{$id}->{maped} = 1;
  
  my $URL = TWiki::Func::getViewUrl( $web, $topic );
  my $title = $fluxItens{$id}->{title};
  $title = encode( "iso-8859-1", decode("utf-8", $title) );      # convert from utf-8 to iso
  $title =~ s/%FLOWCHART_BR%/ /g;  $title =~ s/\"/\'/g;  $title =~ s/\s+/ /g;
  my $anchor = $title;
  $anchor =~ s/[^a-zA-Z0-9]/_/g;  $anchor =~ s/_+/_/g;  $anchor =~ s/(^_*|_*$)//g;
  my $x = ( $fluxItens{$id}->{x} * $caixa{areaX} - ( ($caixa{areaX}+$caixa{w}) / 2) ) * $reduce;
  my $y = ( $fluxItens{$id}->{y} * $caixa{areaY} - ( ($caixa{areaY}+$caixa{h}) / 2) ) * $reduce;
  my $w = $caixa{w} * $reduce;
  my $h = $caixa{h} * $reduce;
  $mapImg .= '  <area href="'.$URL.'#'.$anchor.'" title="'.$title.'"';
  $mapImg .= ' shape="rect" coords="'.$x.','.$y.','.($x+$w).','.($y+$h).'">';
  
  if ( $fluxItens{$id}->{'goto'} ne '' ) {
    $mapImg .= &encaixaMapImg( $topic, $web, $reduce, $fluxItens{$id}->{'goto'} );
  }
  if ( $fluxItens{$id}->{'gotoYes'} ne '' ) {
    $mapImg .= &encaixaMapImg( $topic, $web, $reduce, $fluxItens{$id}->{'gotoYes'} );
  }
  if ( $fluxItens{$id}->{'gotoNo'} ne '' ) {
    $mapImg .= &encaixaMapImg( $topic, $web, $reduce, $fluxItens{$id}->{'gotoNo'} );
  }
  
  return $mapImg;
}

# =========================
sub afterSaveHandler
{
### my ( $text, $topic, $web, $error ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::afterSaveHandler( $_[2].$_[1] )" ) if $debug;
    
    my $web = $_[2];
    $web =~ s/(\/)/\./g;

    my $tempFileName = $TWiki::cfg{TempfileDir} . '/' . $web . '_' . $_[1] . '.txt';

    TWiki::Func::saveFile( $tempFileName, 'ini' );
    
    # This handler is called by TWiki::Store::saveTopic just after the save action.
    # New hook in TWiki::Plugins $VERSION = '1.020'

    # Hire is the right position to create the image.
    if ( $_[0] =~ m/%FLOWCHART%/ ) {
      &desenhaFluxograma($_[0], $_[1], $_[2], '');
    }
    if ( $_[0] =~ m/%FLOWCHART\{([^\n]*?)\}%/ ) {
      &desenhaFluxograma($_[0], $_[1], $_[2], $1);
    }
}

# =========================

1;
