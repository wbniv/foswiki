#
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

# A specialisation of Section for the root of the table of contents
{ package TopLevelSection;

  @TopLevelSection::ISA = qw(Section);
  
  ######################################################################
  # 'Object' methods.

  # Constructor requires a context which provides loader services
  sub new {
    my ($class, $web, $wif) = @_;
    my $this = $class->SUPER::new(0, "ROOT");
    $this->{ISA} = "TopLevelSection";
    $this->{WIF} = $wif;
    $this->{WEB} = $web;
    return bless($this, $class);
  }

  # PUBLIC the wif to use to access the environment
  sub wif {
    my $this = shift;
    return $this->{WIF};
  }

  # PUBLIC the web this is the toc of
  sub web {
    my $this = shift;
    return $this->{WEB};
  }

  # Set/get the current topic being read and flag it as loaded; we are
  # about to perform an operation that requires it.
  sub currentTopic {
    my $this = shift;
    my $currTopic = $this->_findTopic($this->wif()->topicName());
    $currTopic->loaded(1) if $currTopic;
    return $currTopic;
  }

  # Load all topics under the given section.
  sub loadTopics {
    my ($this, $sec) = @_;

    if ( defined( $sec->wikiName() ) ) {
      $this->loadTopic($sec);
    }

    if ( scalar( @{$sec->{SECTIONS}} ) ) {
      my $subsection;
      foreach $subsection ( @{$sec->{SECTIONS}} ) {
        $this->loadTopics($subsection);
      }
    }
  }
    
  # Load the sections for a topic from the data directory
  sub loadTopic {
    my ($this, $section) = @_;
    return if (defined($section->loaded()));
    die unless defined($section->wikiName());
    my $text = $this->wif()->readTopic($section->_getTopicURL());
    $text =~ s/\r//go;
    $section->parseTopicText($text);
  }
  
  # PUBLIC STATIC
  # Factor method to generate the TOC for a web.
  # Initialise the table of contents from the WebOrder topic. The
  # table will only be partially populated; no topics will actually
  # be parsed yet.
  sub createTOC {
    my ($web, $wif) = @_;

    if (!$wif->topicExists("WebOrder")) {
      return (undef, Section::_error("No WebOrder in this web"));
    }

    my $this = TopLevelSection->new($web, $wif);
    # load the table of contents topic
    my $tocText = $wif->readTopic("WebOrder");
    # allow [[Odd Wiki Word]] links
    my @tocNames = split( /[\n\r]/, $tocText );
    # extract the bulleted list
    @tocNames = grep( /^\s+\*\s/, @tocNames );
      
    my $tocEntry;
    my $attrs = TocPlugin::Attrs->new("");

    # Check that each topic in the WebOrder only appears once
    my %seen;
    my $retmess = "";

    foreach $tocEntry ( @tocNames ) {
      my $name = $tocEntry;
      $name =~ s/^[\s\*]*//o;
      
      my $level = 0;
      while ($tocEntry =~ s/^(\t|   )//o) {
        $level++;
      }

      if ($seen{$name}) {
        $retmess .=
          Section::_error("Topic $name used more than once in WebOrder<br>");
      }
      $seen{$name} = 1;

      $attrs->set("level", $level);
      $attrs->set("text", $name);
      my $ne = $this->processSECTIONTag($attrs);
      my $wn = Section::_toWikiName($name);
      $ne->wikiName($wn) if ($wif->topicExists($wn));
    }
    if ($retmess ne "") {
      return (undef, $retmess);
    }
  
    return ($this, "");
  }

  
  # TOCCHECK tag implementation
  sub processTOCCHECKTag {
    my $this = shift;

    # Find files in this web which are not listed in the WebOrder topic
    # Get list of files in the web
    my @fullList = $this->wif()->webDirList();
    
    my $result = "";
    my $topic;
    foreach $topic ( @fullList ) {
      # ignore topics that start with "Web"
      if ($topic !~ m/^Web/o && !$this->_findTopic($topic)) {
        $result = $result . "\n<LI>" . $topic . "</LI>";
      }
    }

    if ($result ne "") {
      $result = Section::_error("The following topics were not found " .
                       "in the WebOrder:\n<OL>" . $result . "\n</OL>\n");
    }
    return $result;
  }
  
  # Generate table of contents
  sub processTOCTag {
    my ($this, $attrSet) = @_;

    my $html = "<DIV>\n";
    my $topic = $attrSet->get("topic");
    my $depth = $attrSet->get("depth");
    my $root = $this->_getRoot();
    if (defined($topic)) {
      $topic = Section::_toWikiName($topic);
      $root = $root->_findTopic($topic);
      if (!$root) {
        return Section::_error("Bad topic $topic");
      }
    }

    $this->loadTopics($root);
    $html = $html . $root->generateTOC($depth);

    return $html . "</DIV>";
  }
  
  # REFTABLE tag implementation
  sub processREFTABLETag {
    my ( $this, $attrSet ) = @_;
    my $type = $attrSet->get("type");
    
    return Section::_error("Bad type in REFTABLE") unless (defined($type));
    return $this->generateRefTable($type);
  }

  # Get a list of all file-level topics in the toc.
  sub getTopicList {
    my ($this, $topics) = @_;
    my $section;
    foreach $section ( @{$this->{SECTIONS}} ) {
      if (defined($section->wikiName())) {
        push @$topics, $section->wikiName();
      }
      getTopicList($section, $topics);
    }
  }

  sub toPrint {
    my ($this, $toc, $wif, $web, $nohtml) = @_;
    return $this->SUPER::toPrint($wif, $toc, $web, $nohtml);
  }

  sub toString {
    my ($this, $nohtml) = @_;
    my $res = $this->{ISA}."(web=" .
      $this->{WEB} . " topic=" .
	$this->wif()->topicName() . ") ";
    $res .= "<b>" unless $nohtml;
    $res .= "ISA";
    $res .= "</b>" unless $nohtml;
    return $res . " [" .
	  $this->SUPER::toString($nohtml) . "]";
  }
}

1;
