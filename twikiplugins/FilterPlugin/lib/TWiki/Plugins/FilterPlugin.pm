# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005-2007 Michael Daum http://wikiring.de
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
###############################################################################
package TWiki::Plugins::FilterPlugin;
use strict;

###############################################################################
use vars qw(
        $currentWeb $currentTopic $user $VERSION $RELEASE
	$NO_PREFS_IN_TOPIC $SHORTDESCRIPTION
        $debug
    );

$VERSION = '$Rev$';
$RELEASE = '1.30';
$NO_PREFS_IN_TOPIC = 1;
$SHORTDESCRIPTION = 'Substitute and extract information from content by using regular expressions';
$debug = 0; # toggle me

###############################################################################
sub writeDebug {
  #&TWiki::Func::writeDebug("- FilterPlugin - " . $_[0]) if $debug;
  print STDERR "DEBUG: FilterPlugin - $_[0]\n" if $debug;
}

###############################################################################
sub initPlugin {
  ($currentTopic, $currentWeb, $user) = @_;

  TWiki::Func::registerTagHandler('FORMATLIST', \&handleFormatList);
  TWiki::Func::registerTagHandler('SUBST', \&handleSubst);
  TWiki::Func::registerTagHandler('EXTRACT', \&handleExtract);
  return 1;
}

###############################################################################
sub commonTagsHandler {
  while($_[0] =~ s/%STARTSUBST{(?!.*%STARTSUBST)(.*?)}%(.*?)%STOPSUBST%/&handleFilterArea($1, 1, $2)/ges) {
    # nop
  }
  while($_[0] =~ s/%STARTEXTRACT{(?!.*%STARTEXTRACT)(.*?)}%(.*?)%STOPEXTRACT%/&handleFilterArea($1, 0, $2)/ges) {
    # nop
  }
}

###############################################################################
sub handleFilterArea {
  my ($theAttributes, $theMode, $theText) = @_;

  $theAttributes ||= '';
  #writeDebug("called handleFilterArea($theAttributes)");

  my %params = TWiki::Func::extractParameters($theAttributes);
  return handleFilter(\%params, $theMode, $theText);
}


###############################################################################
# filter a topic or url thru a regular expression
# attributes
#    * pattern
#    * format
#    * hits
#    * topic
#    * expand
#
sub handleFilter {
  my ($params, $theMode, $theText) = @_;

  #writeDebug("called handleFilter");
  #writeDebug("theMode = '$theMode'");
  #writeDebug("theText = '$theText'") if $theText;

  # get parameters
  my $thePattern = $params->{pattern} || '';
  my $theFormat = $params->{format} || '';
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $theLimit = $params->{limit} || $params->{hits} || 100000; 
  my $theSkip = $params->{skip} || 0;
  my $theTopic = $params->{_DEFAULT} || $params->{topic} || $currentTopic;
  my $theWeb = $currentWeb;
  if ($theTopic =~ /^(.*)\.(.*?)$/) { # TODO : put normalizeWebTopicName() into the DakarContrib
    $theWeb = $1;
    $theTopic = $2;
  }
  my $theExpand = $params->{expand} || 'on';
  my $theSeparator = $params->{separator} || '';
  my $theExclude = $params->{exclude} || '';
  my $theSort = $params->{sort} || 'off';
  my $theReverse = $params->{reverse} || '';

  # get the source text
  my $text = "";
  if ($theText) { # direct text
    $text = $theText;
  } else { # topic text
    $text = &TWiki::Func::readTopicText($theWeb, $theTopic);
    if ($text =~ /^No permission to read topic/) {
      return showError("$text");
    }
    if ($text =~ /%STARTINCLUDE%(.*)%STOPINCLUDE%/gs) {
      $text = $1;
      if ($theExpand eq 'on') {
	$text = &TWiki::Func::expandCommonVariables($text, $currentTopic, $currentWeb);
	$text = &TWiki::Func::renderText($text, $currentWeb);
      }
    }
  }

  my $result = '';
  my $hits = $theLimit;
  my $skip = $theSkip;
  if ($theMode == 0) {
    # extraction mode
    my @result = ();
    while($text =~ /$thePattern/gms) {
      my $arg1 = $1 || '';
      my $arg2 = $2 || '';
      my $arg3 = $3 || '';
      my $arg4 = $4 || '';
      my $arg5 = $5 || '';
      my $arg6 = $6 || '';
      my $match = $theFormat;
      $match =~ s/\$1/$arg1/g;
      $match =~ s/\$2/$arg2/g;
      $match =~ s/\$3/$arg3/g;
      $match =~ s/\$4/$arg4/g;
      $match =~ s/\$5/$arg5/g;
      $match =~ s/\$6/$arg6/g;
      next if $theExclude && $match =~ /^($theExclude)$/;
      next if $skip-- > 0;
      push @result,$match;
      $hits--;
      last if $theLimit > 0 && $hits <= 0;
    }
    if ($theSort ne 'off') {
      if ($theSort eq 'alpha' || $theSort eq 'on') {
	@result = sort {uc($a) cmp uc($b)} @result;
      } elsif ($theSort eq 'num') {
	@result = sort {$a <=> $b} @result;
      }
    }
    @result = reverse @result if $theReverse eq 'on';
    $result = join($theSeparator, @result);
  } elsif ($theMode == 1) {
    # substitution mode
    $result = $text;
    while($text =~ /$thePattern/gsi) {
      my $arg1 = $1 || '';
      my $arg2 = $2 || '';
      my $arg3 = $3 || '';
      my $arg4 = $4 || '';
      my $arg5 = $5 || '';
      my $arg6 = $6 || '';
      my $match = $theFormat;
      $match =~ s/\$1/$arg1/g;
      $match =~ s/\$2/$arg2/g;
      $match =~ s/\$3/$arg3/g;
      $match =~ s/\$4/$arg4/g;
      $match =~ s/\$5/$arg5/g;
      $match =~ s/\$6/$arg6/g;
      next if $theExclude && $match =~ /^($theExclude)$/;
      next if $skip-- > 0;
      #writeDebug("match=$match");
      $result =~ s/$thePattern/$match/gmsi;
      #writeDebug("($hits) result=$result");
      $hits--;
      last if $theLimit > 0 && $hits <= 0;
    }
  }
  $result = $theHeader.$result.$theFooter;
  &escapeParameter($result);
  #$result = &TWiki::Func::expandCommonVariables($result, $currentTopic, $currentWeb);

  #writeDebug("result=$result");
  return $result;
}

###############################################################################
sub handleSubst {
  my ($session, $params, $theTopic, $theWeb) = @_;
  return handleFilter($params, 1);
}

###############################################################################
sub handleExtract {
  my ($session, $params, $theTopic, $theWeb) = @_;
  return handleFilter($params, 0);
}

###############################################################################
sub handleFormatList {
  my ($session, $params, $theTopic, $theWeb) = @_;
  
  #writeDebug("handleFormatList()");

  my $theList = $params->{_DEFAULT} || $params->{list} || '';
  my $thePattern = $params->{pattern} || '\s*(.*)\s*';
  my $theFormat = $params->{format} || '$1';
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $theSplit = $params->{split} || '[,\s]+';
  my $theSeparator = $params->{separator} || ', ';
  my $theLimit = $params->{limit} || -1; 
  my $theSkip = $params->{skip} || 0; 
  my $theSort = $params->{sort} || 'off';
  my $theUnique = $params->{unique} || '';
  my $theExclude = $params->{exclude} || '';
  my $theReverse = $params->{reverse} || '';

  &escapeParameter($theList);
  $theList = &TWiki::Func::expandCommonVariables($theList, $theTopic, $theWeb);

  #writeDebug("theList='$theList'");
  #writeDebug("thePattern='$thePattern'");
  #writeDebug("theFormat='$theFormat'");
  #writeDebug("theSplit='$theSplit'");
  #writeDebug("theSeparator='$theSeparator'");
  #writeDebug("theLimit='$theLimit'");
  #writeDebug("theSkip='$theSkip'");
  #writeDebug("theSort='$theSort'");
  #writeDebug("theUnique='$theUnique'");
  #writeDebug("theExclude='$theExclude'");

  my %seen = ();
  my @result;
  my $count = 0;
  my $skip = $theSkip;
  foreach my $item (split(/$theSplit/, $theList)) {
    #writeDebug("found '$item'");
    next if $theExclude && $item =~ /^($theExclude)$/;
    next if $item =~ /^$/; # skip empty elements
    my $arg1 = '';
    my $arg2 = '';
    my $arg3 = '';
    my $arg4 = '';
    my $arg5 = '';
    my $arg6 = '';
    if ($item =~ m/$thePattern/) {
      $arg1 = $1 || '';
      $arg2 = $2 || '';
      $arg3 = $3 || '';
      $arg4 = $4 || '';
      $arg5 = $5 || '';
      $arg6 = $6 || '';
    } else {
      next;
    }
    my $line = $theFormat;
    #writeDebug("arg1=$arg1") if $arg1;
    #writeDebug("arg2=$arg2") if $arg2;
    #writeDebug("arg3=$arg3") if $arg3;
    #writeDebug("arg4=$arg4") if $arg4;
    #writeDebug("arg5=$arg5") if $arg5;
    #writeDebug("arg6=$arg6") if $arg6;
    $line =~ s/\$1/$arg1/g;
    $line =~ s/\$2/$arg2/g;
    $line =~ s/\$3/$arg3/g;
    $line =~ s/\$4/$arg4/g;
    $line =~ s/\$5/$arg5/g;
    $line =~ s/\$6/$arg6/g;
    #writeDebug("after susbst '$line'");
    if ($theUnique eq 'on') {
      next if $seen{$line};
      $seen{$line} = 1;
    }
    next if $line eq '';
    $line =~ s/\$index/$count+1/ge;
    if ($skip-- <= 0) {
      push @result, $line;
      $count++;
      last if $theLimit - $count == 0;
    }
  }
  #writeDebug("count=$count");
  return '' if $count == 0;

  if ($theSort ne 'off') {
    if ($theSort eq 'alpha' || $theSort eq 'on') {
      @result = sort {uc($a) cmp uc($b)} @result;
    } elsif ($theSort eq 'num') {
      @result = sort {$a <=> $b} @result;
    }
  }
  @result = reverse @result if $theReverse eq 'on';

  my $result = $theHeader.join($theSeparator, @result).$theFooter;
  $result =~ s/\$count/$count/g;
  &escapeParameter($result);
  $result = &TWiki::Func::expandCommonVariables($result, $theTopic, $theWeb);
  $result =~ s/\s+$//go; # SMELL what the hell: where do the linefeeds come from

  #writeDebug("result=$result");

  return $result;
}

###############################################################################
sub escapeParameter {
  return '' unless $_[0];

  my $mixedAlphaNum = TWiki::Func::getRegularExpression('mixedAlphaNum');

  $_[0] =~ s/\$percnt/\%/go;
  $_[0] =~ s/\$dollar/\$/go;
  $_[0] =~ s/\$nop//go;
  $_[0] =~ s/\$n([^$mixedAlphaNum]|$)/\n$1/go;
}

###############################################################################
sub showError {
  my ($errormessage) = @_;
  return "<font size=\"-1\" color=\"#FF0000\">$errormessage</font>" ;
}

1;
