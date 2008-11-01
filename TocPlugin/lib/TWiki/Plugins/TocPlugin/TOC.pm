
# Copyright (C) Motorola 2001 - All rights reserved
#
# TWiki extension that adds tags for the generation of tables of contents.
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
use strict;
use integer;

use TWiki::Plugins::TocPlugin::Attrs;
use TWiki::Plugins::TocPlugin::Section;
use TWiki::Plugins::TocPlugin::TopLevelSection;

{ package TOC;

  # Private
  sub _processTag {
    my ($toc, $wif, $ct, $tag, @params) = @_;
    
    if ($tag eq "TOCCHECK") {
      return $toc->processTOCCHECKTag(@params);
    } elsif ($tag eq "CONTENTS") {
      return $toc->processTOCTag(@params);
    } elsif ($tag eq "REFTABLE") {
      return $toc->processREFTABLETag(@params);
    } elsif ($tag eq "TOCDUMP") {
      return $toc->toString(0);
    } else {
#      my $ct = $toc->currentTopic();
      return Section::_error("Bad $tag: Current topic not in WebOrder") unless $ct;
      if ($tag eq "ANCHOR") {
        my $anc = $ct->processANCHORTag(@params);
        return $anc->generateTarget() if $anc;
      } elsif ($tag eq "SECTION") {
#        my $ct = $toc->currentTopic();
        my $sec = $ct->processSECTIONTag(@params);
        return $sec->generateTarget() if $sec;
      } elsif ($tag eq "REF") {
        return $ct->processREFTag(@params);
      }
    }
    return Section::_error("Bad tag $tag: " . join(",", @params));
  }
  
  # Process TOC tags in the current topic
  # MAIN ENTRY POINT for TWiki
  sub _processTOCTags {
    my ($toc, $wif, $text) = @_;
   
    my $ct = $toc->currentTopic();

    # remove sections and anchors that were generated from the text
    # from the current topic for reload as the content may have changed
    $ct->purge() if $ct;

    # Anchors and sections must be done before we generate the table
    # of contents and ref tables.
    while ($text =~
           s/%((SECTION[0-9]+)|ANCHOR)({[^%]*})?%(.*)/\<TOC_Mark\>/o) {
      my $tag = $1;
      my $attrs = TocPlugin::Attrs->new($3);
      $attrs->set("text", $4);
      if ($ct) {
        if ($tag =~ s/SECTION([0-9]+)//o) {
          my $level = $1;
          $attrs->set("level", $ct->level() + $level);
          $text =~ s/\<TOC_Mark\>/&_processTag($toc, $wif, $toc->currentTopic, "SECTION", $attrs)/eo;
        } else {
          $text =~ s/\<TOC_Mark\>/&_processTag($toc, $wif, $toc->currentTopic, "ANCHOR", $attrs)/eo;
        }
      }
    }
    # The order in which the other tags is done is irrelevant
    my $nullatt = TocPlugin::Attrs->new("");
    $text =~ s/%(REF|REFTABLE){([^%]*)}%/&_processTag($toc, $wif, $toc->currentTopic, $1, TocPlugin::Attrs->new($2))/geo;
    $text =~ s/%(TOCDUMP)%/&_processTag($toc, $wif, $toc->currentTopic, $1, $nullatt)/geo;
    $text =~ s/%(TOCCHECK)%/&_processTag($toc, $wif, $toc->currentTopic, $1, $nullatt)/geo;
    $text =~ s/%(CONTENTS)({[^%]*})?%/&_processTag($toc, $wif, $toc->currentTopic, $1, TocPlugin::Attrs->new($2))/geo;
    return $text;
  }

  sub _printWithTOCTags {
    my ($toc, $wif, $ct, $text) = @_;
   
    # remove sections and anchors that were generated from the text
    # from the current topic for reload as the content may have changed
    $ct->purge() if $ct;

    # Anchors and sections must be done before we generate the table
    # of contents and ref tables.
    while ($text =~
           s/%((SECTION[0-9]+)|ANCHOR)({[^%]*})?%(.*)/\<TOC_Mark\>/o) {
      my $tag = $1;
      my $attrs = TocPlugin::Attrs->new($3);
      $attrs->set("text", $4);
      if ($tag =~ s/SECTION([0-9]+)//o) {
        my $level = $1;
        $attrs->set("level", $ct->level() + $level);
        $text =~ s/\<TOC_Mark\>/&_processTag($toc, $wif, $ct, "SECTION", $attrs)/eo;
      } else {
        $text =~ s/\<TOC_Mark\>/&_processTag($toc, $wif, $ct, "ANCHOR", $attrs)/eo;
      }
    }
    # The order in which the other tags is done is irrelevant
    my $nullatt = TocPlugin::Attrs->new("");
    $text =~ s/%(REF|REFTABLE){([^%]*)}%/&_processTag($toc, $wif, $ct, $1, TocPlugin::Attrs->new($2))/geo;
    $text =~ s/%(CONTENTS)({[^%]*})?%/&_processTag($toc, $wif, $ct, $1, TocPlugin::Attrs->new($2))/geo;
    $text =~ s/%(TOCCHECK)%/&_processTag($toc, $wif, $ct, $1, $nullatt)/geo;
    $text =~ s/%(TOCDUMP)%/&_processTag($toc, $wif, $ct, $1, $nullatt)/geo;
    
    return $text;
  }



  my $toc = undef;

  sub _webPrint {
    my ($toc, $wif, $web) = @_;
    return $toc->toPrint($toc, $wif, $web, 0);
  }

  sub processTopic {
    my ($wif, $web, $topic, $text) = @_;

    # If this is a different web, need to reload the weborder
    # If the topic is WebOrder, have to reload the weborder
    # If the topic is something else, need to reset it to the weborder
    if (!$toc || $web ne $toc->web() || $topic eq "WebOrder") {
      my $mess;
      ($toc, $mess) = TopLevelSection::createTOC($web, $wif);
      if ($toc && $topic eq "WebPrint") {
	return _webPrint($toc, $wif, $web);
      }

      return Section::replaceAllTags($text, $mess) unless $toc;
    }
    my $ct = $toc->currentTopic();

# CarlMikkelsen didn't understand why this test was here, and it got in his way,
# so he removed it.  This is important so that there can be a topic NOT in WebOrder
# that uses tags other than %SECTION% and %ANCHOR%.
#    return Section::replaceAllTags($text, Section::_error("Topic $topic not in WebOrder")) unless $ct;

    return _processTOCTags($toc, $wif, $text);
  }
}

1;
