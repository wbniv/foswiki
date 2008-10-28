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

use TWiki::Func;

# Canned interface to TWiki. Provided so that TOC scripts don't have to use
# TWiki::Func everywhere. This makes testing easier and
# significantly improves portability between versions (a TWikiIF can easily
# be written for older versions of TWiki).
{ package TOCIF;

  # Singleton instance
  my $singleton;

  # Factory method, returns a singleton instance of a TWiki interface
  sub getInterface {
    my ($class, $web, $topic) = @_;
    my $this;
    if ($singleton) {
      $this = $singleton;
    } else {
      $this = {};
      $singleton = $this;
    }
    $this->{WEBNAME} = $web;
    $this->{TOPIC} = $topic;
    return bless($this, $class);
  }

  sub webName {
    my $this = shift;
    return $this->{WEBNAME};
  }

  sub topicName {
    my $this = shift;
    return $this->{TOPIC};
  }

  sub topicExists {
    my ($this, $topic) = @_;
    return TWiki::Func::topicExists($this->webName(), $topic);
  }

  sub readTopic {
    my ($this, $topic) = @_;
    my $text = "";
    # read the topic
    $text = TWiki::Func::readTopic($this->webName(), $topic);
    # expand the variables -- in the context of the appropriate topic
    $text = TWiki::Func::expandCommonVariables($text, $topic, $this->webName());
    # this can't be right -- turn verbatim tags into pre tags
    $text =~ s/<verbatim>/<pre>/go;
    $text =~ s/<\/verbatim>/<\/pre>/go;
    return $text;
  }

  sub webDirList {
    my $this = shift;
    return TWiki::Func::getTopicList($this->webName());
  }
}

1;
