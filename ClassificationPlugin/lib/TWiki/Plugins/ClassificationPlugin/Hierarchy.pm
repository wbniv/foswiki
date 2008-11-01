# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2006-2008 Michael Daum http://michaeldaumconsulting.com
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

package TWiki::Plugins::ClassificationPlugin::Hierarchy;

use strict;
use TWiki::Plugins::DBCachePlugin::Core;
use TWiki::Plugins::ClassificationPlugin::Category;
use Storable;
require TWiki::Prefs;

use constant OBJECTVERSION => 0.49;
use constant DEBUG => 0; # toggle me

use vars qw(%insideInit);

###############################################################################
# static
sub writeDebug {
  #&TWiki::Func::writeDebug('- ClassificationPlugin - '.$_[0]) if DEBUG;
  print STDERR '- ClassificationPlugin::Hierarchy - '.$_[0]."\n" if DEBUG;
}

################################################################################
# static
sub getCacheFile {
  my $web = shift;

  $web =~ s/^\s+//go;
  $web =~ s/\s+$//go;
  $web =~ s/[\/\.]/_/go;

  return TWiki::Func::getWorkArea("ClassificationPlugin").'/'.$web.'.hierarchy';
}

################################################################################
# constructor
sub new {
  my $class = shift;
  my $web = shift;

  $web =~ s/\//\./go;
  #writeDebug("new hierarchy for web $web");
  my $this;
  my $cacheFile = getCacheFile($web);
  
  my $session = $TWiki::Plugins::SESSION;
  my $refresh = '';
  $refresh = $session->{cgiQuery}->param('refresh') || '' if defined $session;
  $refresh = $refresh eq 'on'?1:0;

  unless ($refresh) {
    eval {
      $this = Storable::lock_retrieve($cacheFile);
    };
  }

  if ($this && $this->{_version} == OBJECTVERSION) {
    writeDebug("restored hierarchy object (v$this->{_version}) from $cacheFile");
    return $this;
  } else {
    writeDebug("creating new object");
  }

  $this = {
    web=>$web,
    idCounter=>0,
    @_
  };

  $this = bless($this, $class);
  $this->init();

  $this->{gotUpdate} = 1;
  $this->{_version} = OBJECTVERSION;

  return $this;
}

################################################################################
# does not invalidate this object; it is kept intact to be cached in memory
# in a mod_perl or speedy-cgi setup; we only store it to disk if we updated it 
sub finish {
  my $this = shift;

  my $gotUpdate = $this->{gotUpdate};
  $this->{gotUpdate} = 0;

  foreach my $cat ($this->getCategories()) {
    $gotUpdate ||= $cat->{gotUpdate};
    $cat->{gotUpdate} = 0;
  }

  if ($gotUpdate) {
    writeDebug("saving hierarchy $this->{web}");
    my $cacheFile = getCacheFile($this->{web});
    Storable::lock_store($this, $cacheFile);
  }

}

################################################################################
# mode = 0 -> do nothing
# mode = 1 -> a tagged topic has been saved
# mode = 2 -> a categorized topic has been saved
# mode = 3 -> a classified topic has been saved
# mode = 4 -> a category has been saved
# mode = 5 -> clear all
sub purgeCache {
  my ($this, $mode) = @_;

  return unless $mode;
  writeDebug("purging hierarchy cache for $this->{web} - mode = $mode");

  if ($mode == 1 || $mode == 3 || $mode > 4) { # tagged and classified topics
    undef $this->{_tagIntersection};
    undef $this->{_coOccurrence};
  } 

  if ($mode > 1) { # categorized and classified topics
    foreach my $cat (values %{$this->{_categories}}) {
      $cat->purgeCache() if $cat;
    }
  } 

  if ($mode > 3) { # category topics
    undef $this->{_categories};
    undef $this->{_distance};
    undef $this->{_prefs};
    undef $this->{_top};
    undef $this->{_bottom};
    undef $this->{_aclAttribute};
  }

  if ($mode > 4) { # clear all of the rest
    undef $this->{_catFields};
    undef $this->{_tagFields};
  }

  $this->{gotUpdate} = 1;
}

################################################################################
# destructor
sub DESTROY {
  my $this = shift;

  $this->purgeCache(5);
}

################################################################################
sub init {
  my $this = shift;

  # be anal
  die "recursive call to Hierarchy::init" if $insideInit{$this->{web}};
  $insideInit{$this->{web}} = 1;

  writeDebug("called Hierarchy::init for $this->{web}");
  my $session = $TWiki::Plugins::SESSION;
  $this->{_prefs} = new TWiki::Prefs($session);

  my $db = TWiki::Plugins::DBCachePlugin::Core::getDB($this->{web});

  # itterate over all topics and collect categories
  my $seenImport = {};
  foreach my $topicName ($db->getKeys()) {
    my $topicObj = $db->fastget($topicName);
    my $form = $topicObj->fastget("form");
    next unless $form;
    $form = $topicObj->fastget($form);

    # get topic types
    my $topicType = $form->fastget("TopicType");
    next unless $topicType;

    if ($topicType =~ /\bCategory\b/) {
      # this topic is a category in itself
      #writeDebug("found category '$topicName' in web $this->{web}");
      my $cat = $this->{_categories}{$topicName};
      $cat = $this->createCategory($topicName) unless $cat;

      my $cats = $this->getCategoriesOfTopic($topicObj);
      if ($cats) {
        $cat->setParents(keys %$cats);
      } else {
        $cat->setParents('TopCategory');
      }

      my $summary = $form->fastget("Summary") || '';
      $summary =~ s/<nop>//go;
      $summary =~ s/^\s+//go;
      $summary =~ s/\s+$//go;

      my $title = $form->fastget("TopicTitle") || $topicName;
      $title =~ s/<nop>//go;
      $title =~ s/^\s+//go;
      $title =~ s/\s+$//go;
      $cat->setSummary($summary);
      $cat->setTitle($title);
      $cat->setIcon($form->fastget("Icon"));

      # import foregin categories
      $cat->importCategories($form->fastget("ImportedCategory"), $seenImport);
    }
  }

  #writeDebug("checking for default categories");
  # every hierarchy has one top node
  my $topCat = 
    $this->{_categories}{'TopCategory'} || 
    $this->createCategory('TopCategory', title=>'TOP');

  # every hierarchy has one BOTTOM node
  my $bottomCat = 
    $this->{_categories}{'BottomCategory'} ||
    $this->createCategory('BottomCategory', title=>'BOTTOM');

  # remember these
  $this->{_top} = $topCat;
  $this->{_bottom} = $bottomCat;

  # init nested structures
  foreach my $cat (values %{$this->{_categories}}) {
    $cat->init();
  }

  # add categories with no children as a parent to BottomCategory
  my @bottomParents = ();
  foreach my $cat (values %{$this->{_categories}}) {
    next if $cat->getChildren() || $cat == $bottomCat;
    $cat->addChild($bottomCat);
    push @bottomParents, $cat;
  }
  $bottomCat->setParents(@bottomParents);

  # init these again
  foreach my $cat (@bottomParents) {
    $cat->init();
  }

  # reset distances, delay computeDistance til we need it
  undef $this->{_distance};
  $this->{gotUpdate} = 1;

  if (0) {
    foreach my $cat (values %{$this->{_categories}}) {
      my $text = "$cat->{name}:";
      foreach my $child ($cat->getChildren()) {
	$text .= " $child->{name}";
      }
      writeDebug($text);
    }
    $this->printDistanceMatrix();
  }

  writeDebug("done init $this->{web}");
  undef $insideInit{$this->{web}};
}

################################################################################
sub printDistanceMatrix {
  return unless DEBUG;

  my ($this) = @_;

  my $distance = $this->{_distance} || $this->computeDistance();

  foreach my $catName1 (sort $this->getCategoryNames()) {
    my $cat1 = $this->{_categories}{$catName1};
    my $catId1 = $cat1->{id};
    foreach my $catName2 (sort $this->getCategoryNames()) {
      my $cat2 = $this->{_categories}{$catName2};
      my $catId2 = $cat2->{id};
      my $dist =  $$distance[$catId1][$catId2];
      next unless $dist;
      writeDebug("distance($catName1/$catId1, $catName2/$catId2) = $dist");
    }
  }
}

################################################################################
# computes the distance between all categories using a Wallace-Kollias
# algorith for transitive closure
sub computeDistance {
  my $this = shift;

  my @distance;

  writeDebug("called computeDistance() Wallace-Kollias");

  my $topId = $this->{_top}->{id};
  $distance[$topId][$topId] = 0;

  my $bottomId = $this->{_bottom}->{id};
  $distance[$bottomId][$bottomId] = 0;

  # root of induction
  my %ancestors = ($topId=>$this->{_top});
  
  writeDebug("propagate");
  foreach my $child ($this->{_top}->getChildren()) {
    $distance[$topId][$child->{id}] = 1;
    $child->computeDistance(\@distance, \%ancestors);
  }

  writeDebug("finit");
  my $maxId = $this->{idCounter}-1;
  for my $id1 (0..$maxId) {
    for my $id2 ($id1..$maxId) {
      next if $id1 == $id2;
      my $dist = $distance[$id1][$id2];
      if (defined($dist)) {
        $distance[$id2][$id1] = -$dist;
      } else {
        $dist = $distance[$id2][$id1];
        $distance[$id1][$id2] = -$dist if defined $dist;
      }
    }
  }

  writeDebug("done computeDistance() Wallace-Kollias");

  if (0) {
    my $oldDistance = $this->DISABLED_computeDistance();
    foreach my $catName1 (sort $this->getCategoryNames()) {
      my $cat1 = $this->{_categories}{$catName1};
      my $catId1 = $cat1->{id};
      foreach my $catName2 (sort $this->getCategoryNames()) {
        my $cat2 = $this->{_categories}{$catName2};
        my $catId2 = $cat2->{id};
        my $dist =  $distance[$catId1][$catId2];
        my $oldDist = $$oldDistance[$catId1][$catId2];
        if (defined($dist)) {
          if (defined($oldDist)) {
            if ($oldDist == $dist) {
              #writeDebug("distance($ancestors{$id1}->{name},$ancestors{$id2}->{name}) = $dist ... OK");
            } else {
              writeDebug("distance($catName1,$catName2) = $dist != $oldDist");
            }
          } else {
            writeDebug("distance($catName1,$catName2) = $dist ... but NO OLD");
          }
        } else {
          if (defined($oldDist)) {
            writeDebug("distance($catName1,$catName2) = $oldDist ... but NO NEW");
          }
        }
      }
    }
  }

  $this->{_distance} = \@distance;
  $this->{gotUpdate} = 1;

  return \@distance;
}

################################################################################
# computes the distance between all categories using a modified floyd-warshall
# algorithm for transitive closures
sub DISABLED_computeDistance {
  my $this = shift;

  writeDebug("called computeDistance_FLOYD_WARSHALL()");

  # init matrix
  my $totalIterations = 0;
  my $effectiveIteratons = 0;

  my @distance;
  my $bottomId = $this->{_bottom}->{id};


  writeDebug("init");
  for my $cat ($this->getCategories()) {
    my $id = $cat->{id};
    $distance[$id][$id] = 0; # diagonal

    my @children = $cat->getChildren();
    if (@children) {
      foreach my $child (@children) {
        $distance[$id][$child->{id}] = 1; # direct contectedness
      }
    } else {
      unless ($id == $bottomId) { # bottom
        $distance[$id][$bottomId] = 1; # leaf nodes
      }
    }
  }

  # floyd-warshall algorithm for transitive closure
  # used to computing min- and max distances, reused in
  # subsumption and partof relations
  my $maxId = $this->{idCounter}-1;
  writeDebug("propagate");
  writeDebug("maxId=$maxId");
  foreach my $catIId (0..$maxId) {

    foreach my $catJId (0..$maxId) {
      next if $catIId == $catJId; # skip current row

      my $distIJ = $distance[$catIId][$catJId];

      foreach my $catKId (0..$maxId) {
        $totalIterations++;
        next if $catKId == $catIId || $catKId == $catJId; # skip current row

        my $distIK = $distance[$catIId][$catKId];
        next unless $distIK;

        my $distKJ = $distance[$catKId][$catJId];
        next unless $distKJ;

        my $minSum = $distIK+$distKJ;
        $distance[$catIId][$catJId] = $minSum if !$distIJ || $distIJ > $minSum;
        $effectiveIteratons++;
      }
    }
  }

  # fill other half of the matrix, the reverse relation,
  # we are using qubic memory already anyway
  writeDebug("finit");
  for my $id1 (0..$maxId) {
    for my $id2 (0..$maxId) {
      next if $id1 == $id2;
      my $dist = $distance[$id1][$id2];
      next unless $dist;
      $distance[$id2][$id1] = -$dist;
    }
  }

  $this->{_distance} = \@distance;
  $this->{gotUpdate} = 1;

  writeDebug("totalIterations=$totalIterations, effectiveIteratons=$effectiveIteratons");
  writeDebug("done computeDistance");
  
  return \@distance;
}

################################################################################
# this computes the minimum distance between two categories or a topic
# and a category or between two topics. if a non-category topic is under
# consideration then all of its categories are measured against each other
# while computing the overall minimal distances.  so simplest case
# is measuring the distance between two categories; the most general case is
# computing the min distance between two sets of categories.
sub distance {
  my ($this, $topic1, $topic2) = @_;

  #writeDebug("called distance($topic1, $topic2)");

  my %catSet1 = ();
  my %catSet2 = ();

  # if topic1/topic2 are of type Category then they are the objects themselves
  # to be taken under consideration

  # check topic1
  my $extraDistance = 0;
  my $catObj = $this->getCategory($topic1);
  if ($catObj) { # known category
    $catSet1{$topic1} = $catObj->{id};
  } else {
    my $cats = $this->getCategoriesOfTopic($topic1);
    return undef unless $cats; # no categories, no distance
    foreach my $name (keys %$cats) {
      $catObj = $this->getCategory($name);
      $catSet1{$name} = $catObj->{id} if $catObj;
    }
    $extraDistance++; # going to its categories is one extra step
  }

  # check topic2
  $catObj = $this->getCategory($topic2);
  if ($catObj) { # known category
    $catSet2{$topic2} = $catObj->{id};
  } else {
    my $cats = $this->getCategoriesOfTopic($topic2);
    return undef unless $cats; # no categories, no distance
    foreach my $name (keys %$cats) {
      $catObj = $this->getCategory($name);
      $catSet2{$name} = $catObj->{id} if $catObj
    }
    $extraDistance++; # going to its categories is one extra step
  }

  if (DEBUG) {
    #writeDebug("catSet1 = ".join(',', sort keys %catSet1));
    #writeDebug("catSet2 = ".join(',', sort keys %catSet2));
  }

  # get the min distance between the two category sets
  my $distance = $this->{_distance} || $this->computeDistance();
  my $min;
  foreach my $id1 (values %catSet1) {
    foreach my $id2 (values %catSet2) {
      my $dist = $$distance[$id1][$id2];
      next unless defined $dist;
      $min = $dist if !defined($min) || abs($min) > abs($dist);
    }
  }

  # both sets aren't connected
  return undef unless defined($min);

  $min += $extraDistance;
  #writeDebug("min=$min");

  return $min;
}

################################################################################
# fast lookup of the distance between two categories
sub catDistance {
  my ($this, $cat1, $cat2) = @_;

  my $id1;
  my $id2;
  my $cat1Obj = $cat1;
  my $cat2Obj = $cat2;

  if (ref($cat1)) {
    $id1 = $cat1->{id};
  } else {
    $cat1Obj = $this->getCategory($cat1);
    return undef unless defined $cat1Obj;
    $id1 = $cat1Obj->{id};
  }

  if (ref($cat2)) {
    $id2 = $cat2->{id};
  } else {
    $cat2Obj = $this->getCategory($cat2);
    return undef unless defined $cat2Obj;
    $id2 = $cat2Obj->{id};
  }

  $this->computeDistance() unless $this->{_distance};
  my $dist = $this->{_distance}[$id1][$id2];
  #writeDebug("catDistance($cat1Obj->{name}, $cat2Obj->{name})=$dist");
  return $dist;
}

################################################################################
sub computeCoocurrence {
  my $this = shift;

  #writeDebug("called computeCooccurrence()");

  my $coocc = {};
  my $db = TWiki::Plugins::DBCachePlugin::Core::getDB($this->{web});

  # loop over all topics and collect all cooccurence information
  foreach my $topic ($db->getKeys()) {
    my $topicObj = $db->fastget($topic);
    my $form = $topicObj->fastget("form");
    next unless $form;

    $form = $topicObj->fastget($form);
    next unless $form;

    my $tags = $form->fastget("Tag");
    next unless $tags;

    my @tags = 
      sort 
        map {$_ =~ s/^\s+//go; $_ =~ s/\s+$//go; $_} 
          split(/\s*,\s*/, $tags);

    my $length = scalar(@tags);
    next unless $length > 0;

    for (my $i = 0; $i < $length; $i++) {
      my $tagI = $tags[$i];
      for (my $j = $i+1; $j < $length; $j++) {
        my $tagJ = $tags[$j];
        next if $tagI eq $tagJ;
        $$coocc{$tagI}{$tagJ}++;
      }
    }
  }

  # reflexivity
  my @tags = keys %{$coocc};
  my $length = scalar(@tags);
  for (my $i = 0; $i < $length; $i++) {
    my $tagI = $tags[$i];
    for (my $j = 0; $j < $length; $j++) {
      my $tagJ = $tags[$j];
      next if $tagI eq $tagJ;
      my $value = $$coocc{$tagI}{$tagJ} || $$coocc{$tagI}{$tagJ};
      next unless $value;
      $$coocc{$tagI}{$tagJ} = $$coocc{$tagJ}{$tagI} = $value;
    }
  }

  if (0) {
    foreach my $tagI (sort keys %{$coocc}) {
      foreach my $tagJ (sort keys %{$$coocc{$tagI}}) {
        writeDebug("'$tagI' cooccurs with '$tagJ' $$coocc{$tagI}{$tagJ} times");
      }
    }
  }

  # cache
  $this->{_coOccurrence} = $coocc;
  $this->{gotUpdate} = 1;

  #writeDebug("done computeCooccurrence()");

  return $coocc;
}

################################################################################
# compute the cooccurrence of all tags with each other. this is a 2-dimensional
# matrix of integers. each cell's integer indicates how often one tag cooccurred
# with another.
sub getCooccurrence {
  my ($this, $tag1, $tag2) = @_;

  my $coocc = $this->{_coOccurrence} || $this->computeCoocurrence();

  # mode 1: return full cooccurrence matrix
  return $coocc unless defined($tag1);

  # mode 2: return a hash of tags coocurring with tag1
  return $$coocc{$tag1} unless defined($tag2);

  # mode 3: return coocurrence of tag1 and tag2
  return $$coocc{$tag1}{$tag2};
}

################################################################################
# find all topics that use the same set of tags
# returns a hash of all topics that use intersecting tags.
# hash entries are indexed by topic names. each hash entry
# is of the format
# {
#   tags => @tags,
#   size => scalar(@tags)
# }
# the intersection size is cached to ease sorting later on.
sub getTagIntersection {
  my ($this, $thisTopic) = @_;

  # lookup cache
  my $tagIntersection = $this->{_tagIntersection}{$thisTopic};
  return $tagIntersection if defined $tagIntersection;

  $tagIntersection ||= {};

  # get current tags
  my $db = TWiki::Plugins::DBCachePlugin::Core::getDB($this->{web});
  my $thisTopicObj = $db->fastget($thisTopic);
  unless ($thisTopicObj) {
    $this->{_tagIntersection}{$thisTopic} = $tagIntersection;
    $this->{gotUpdate} = 1;
    return undef;
  }

  my $thisForm = $thisTopicObj->fastget("form");
  unless ($thisForm) {
    $this->{_tagIntersection}{$thisTopic} = $tagIntersection;
    $this->{gotUpdate} = 1;
    return undef;
  }

  $thisForm = $thisTopicObj->fastget($thisForm);
  my $tags = $thisForm->fastget('Tag');
  unless ($tags) {
    $this->{_tagIntersection}{$thisTopic} = $tagIntersection;
    $this->{gotUpdate} = 1;
    return undef;
  }

  # create initial tag hash
  my %thisTagHash = ();
  foreach my $tag (split(/\s*,\s*/,$tags)) {
    $tag =~ s/^\s+//go;
    $tag =~ s/\s+$//go;
    $thisTagHash{$tag} = 1;
  }

  # loop over all topics and collect all intersecting topics
  foreach my $topic ($db->getKeys()) {
    next if $topic eq $thisTopic;

    my $topicObj = $db->fastget($topic);
    my $form = $topicObj->fastget("form");
    next unless $form;

    $form = $topicObj->fastget($form);
    next unless $form;

    my $tags = $form->fastget("Tag");
    next unless $tags;
    
    # count number of intersecting tags
    my %intersection = %thisTagHash;
    foreach my $tag (split(/\s*,\s*/, $tags)) {
      $tag =~ s/^\s+//go;
      $tag =~ s/\s+$//go;
      $intersection{$tag}++;
    }

    # filter out non-intersecting tags
    foreach my $tag (keys %intersection) {
      my $count = $intersection{$tag};
      delete $intersection{$tag} 
        if $count < 2;
    }

    my @tags = keys %intersection;
    my $size = scalar(@tags);

    $tagIntersection->{$topic} = {
      tags => \@tags,
      size => $size
    };
    #writeDebug("$thisTopic and $topic share $size tags");
  }

  # cache
  $this->{_tagIntersection}{$thisTopic} = $tagIntersection;
  $this->{gotUpdate} = 1;

  return $tagIntersection;
}


################################################################################
# return true if cat1 subsumes cat2 (is an ancestor of)
sub subsumes {
  my ($this, $cat1, $cat2) = @_;

  my $result = $this->catDistance($cat1, $cat2);
  return (defined($result) && $result > 0)?1:0;
}

################################################################################
sub getCategoriesOfTopic {
  my ($this, $topic) = @_;

  # allow topicName or topicObj
  my $topicObj;
  if (ref($topic)) {
    $topicObj = $topic;
  } else {
    my $db = TWiki::Plugins::DBCachePlugin::Core::getDB($this->{web});
    $topicObj = $db->fastget($topic);
  }
  return undef unless $topicObj;

  my $form = $topicObj->fastget("form");
  return undef unless $form;
  $form = $topicObj->fastget($form);

  #writeDebug("getCategoriesOfTopic(".$topicObj->fastget('topic').")");

  # get typed topics
  my $topicType = $form->fastget("TopicType");
  return undef unless $topicType;

  my $catFields = $this->getCatFields(split(/\s*,\s*/,$topicType));
  return undef unless $catFields;

  # get all categories in all category formfields
  my %cats;
  my $found = 0;
  foreach my $catField (@$catFields) {
    # get category formfield
    #writeDebug("looking up '$catField'");
    my $cats = $form->fastget($catField);
    next unless $cats;
    #writeDebug("$catField=$cats");
    foreach my $cat (split(/\s*,\s*/, $cats)) {
      $cat =~ s/^\s+//go;
      $cat =~ s/\s+$//go;
      $cats{$cat} = 1;
      $found = 1;
    }
  }
  return undef unless $found;
  return \%cats;
}


################################################################################
# get names of category formfields of a topictype
sub getCatFields {
  my ($this, @topicTypes) = @_;

  #writeDebug("called getCatFields(".join(',',@topicTypes).")");

  my %allCatFields;
  my $found = 0;
  foreach my $topicType (@topicTypes) {
    # lookup cache
    #writeDebug("looking up '$topicType' in cache");
    my $catFields = $this->{_catFields}{$topicType};
    if (defined($catFields)) {
      $found = 1;
      foreach my $cat (@$catFields) {
        $allCatFields{$cat} = 1;
      }
      next;
    }
    #writeDebug("looking up form definition for $topicType in web $this->{web}");

    # looup form definition -> ASSUMPTION: TopicTypes must be TWikiForms too
    my $db = TWiki::Plugins::DBCachePlugin::Core::getDB($this->{web});
    my $formDef = $db->fastget($topicType);
    next unless $formDef;

    # check if this is a TopicStub
    my $form = $formDef->fastget('form');
    next unless $form; # woops got no form
    $form = $formDef->fastget($form);
    my $type = $form->fastget('TopicType') || '';
    #writeDebug("type=$type");

    if ($type =~ /\bTopicStub\b/) {
      #writeDebug("reading stub");
      # this is a TopicStub, lookup the target
      my ($targetWeb, $targetTopic) = 
        TWiki::Func::normalizeWebTopicName($this->{web}, $form->fastget('Target'));

      $db = TWiki::Plugins::DBCachePlugin::Core::getDB($targetWeb);
      $formDef = $db->fastget($targetTopic);
      next unless $formDef;# never reach
    }

    # parse in cat fields
    @$catFields = ();

    my $text = $formDef->fastget('text');
    my $inBlock = 0;
    $text =~ s/\r//g;
    $text =~ s/\\\n//g; # remove trailing '\' and join continuation lines
    # | *Name:* | *Type:* | *Size:* | *Value:*  | *Tooltip message:* | *Attributes:* |
    # Tooltip and attributes are optional
    foreach my $line ( split( /\n/, $text ) ) {
      if ($line =~ /^\s*\|.*Name[^|]*\|.*Type[^|]*\|.*Size[^|]*\|/) {
        $inBlock = 1;
        next;
      }
      if ($inBlock && $line =~ s/^\s*\|\s*//) {
        $line =~ s/\\\|/\007/g; # protect \| from split
        my ($title, $type, $size, $vals) =
          map { s/\007/|/g; $_ } split( /\s*\|\s*/, $line );
        $type ||= '';
        $type = lc $type;
        $type =~ s/^\s*//go;
        $type =~ s/\s*$//go;
        next if !$title or $type ne 'cat';
        $title =~ s/<nop>//go;
        push @$catFields, $title;
      } else {
        $inBlock = 0;
      }
    }

    # cache
    #writeDebug("setting cache for '$topicType' to ".join(',',@$catFields));
    $this->{_catFields}{$topicType} = $catFields;
    $this->{gotUpdate} = 1;
    foreach my $cat (@$catFields) {
      $allCatFields{$cat} = 1;
    }
  }
  my @allCatFields = sort keys %allCatFields;

  #writeDebug("... result=".join(",",@allCatFields));

  return \@allCatFields;
}

###############################################################################
# get names of tag formfields of a topictype
sub getTagFields {
  my ($this, @topicTypes) = @_;

  #writeDebug("called getTagFields(".join(',',@topicTypes).")");

  my %allTagFields;
  my $found = 0;
  foreach my $topicType (@topicTypes) {
    $topicType =~ s/^\s+//go;
    $topicType =~ s/\s+$//go;

    # lookup cache
    #writeDebug("looking up '$topicType' in cache");
    my $tagFields = $this->{_tagFields}{$topicType};
    if (defined($tagFields)) {
      $found = 1;
      foreach my $tag (@$tagFields) {
        $allTagFields{$tag} = 1;
      }
      #writeDebug("... found");
      next;
    }
    #writeDebug("looking up form definition for $topicType");

    # looup form definition -> ASSUMPTION: TopicTypes must be TWikiForms too
    my $db = TWiki::Plugins::DBCachePlugin::Core::getDB($this->{web});
    my $formDef = $db->fastget($topicType);
    next unless $formDef;

    # check if this is a TopicStub
    my $form = $formDef->fastget('form');
    next unless $form; # woops got no form
    $form = $formDef->fastget($form);
    my $type = $form->fastget('TopicType');
    #writeDebug("type=$type");

    if ($type =~ /\bTopicStub\b/) {
      #writeDebug("reading stub");
      # this is a TopicStub, lookup the target
      my ($targetWeb, $targetTopic) = 
        TWiki::Func::normalizeWebTopicName($this->{web}, $form->fastget('Target'));

      $db = TWiki::Plugins::DBCachePlugin::Core::getDB($targetWeb);
      $formDef = $db->fastget($targetTopic);
      next unless $formDef;# never reach
    }

    # parse in tag fields
    @$tagFields = ();

    my $text = $formDef->fastget('text');
    my $inBlock = 0;
    $text =~ s/\r//g;
    $text =~ s/\\\n//g; # remove trailing '\' and join continuation lines
    # | *Name:* | *Type:* | *Size:* | *Value:*  | *Tooltip message:* | *Attributes:* |
    # Tooltip and attributes are optional
    foreach my $line ( split( /\n/, $text ) ) {
      if ($line =~ /^\s*\|.*Name[^|]*\|.*Type[^|]*\|.*Size[^|]*\|/) {
        $inBlock = 1;
        next;
      }
      if ($inBlock && $line =~ s/^\s*\|\s*//) {
        $line =~ s/\\\|/\007/g; # protect \| from split
        my ($title, $type, $size, $vals) =
          map { s/\007/|/g; $_ } split( /\s*\|\s*/, $line );
        $type ||= '';
        $type = lc $type;
        $type =~ s/^\s*//go;
        $type =~ s/\s*$//go;
        next if !$title or $type ne 'tag';
        $title =~ s/<nop>//go;
        push @$tagFields, $title;
      } else {
        $inBlock = 0;
      }
    }

    # cache
    #writeDebug("setting cache for '$topicType' to ".join(',',@$tagFields));
    $this->{_tagFields}{$topicType} = $tagFields;
    $this->{gotUpdate} = 1;
    foreach my $tag (@$tagFields) {
      $allTagFields{$tag} = 1;
    }
  }
  $allTagFields{Tag} = 1 unless $found; # default
  my @allTagFields = sort keys %allTagFields;

  #writeDebug("... result=".join(",",@allTagFields));

  return \@allTagFields;
}

###############################################################################
sub getCategories {
  my $this = shift;

  unless (defined($this->{_categories})) {
    $this->init();
    die "init returned no categories" unless defined $this->{_categories};
  }
  return values %{$this->{_categories}}
}

###############################################################################
sub getCategoryNames {
  my $this = shift;

  unless (defined($this->{_categories})) {
    $this->init();
    die "init returned no categories" unless defined $this->{_categories};
  }
  return keys %{$this->{_categories}}
}


###############################################################################
sub getCategory {
  my ($this, $name) = @_;

  unless (defined($this->{_categories})) {
    $this->init();
    die "init returned no categories" unless defined $this->{_categories};
  }
  my $cat = $this->{_categories}{$name};

  unless ($cat) {
    # try id
    if ($name =~ /^\d+/) {
      foreach my $cat (keys %{$this->{_categories}}) {
        last if $cat->{id} == $name;
      }
    }
  }

  return $cat
}

###############################################################################
sub setCategory {
  $_[0]->{_categories}{$_[1]} = $_[2];
}

###############################################################################
sub createCategory {
  return new TWiki::Plugins::ClassificationPlugin::Category(@_);
}

###############################################################################
# static
sub inlineError {
  return '<span class="twikiAlert">' . $_[0] . '</span>' ;
}

###############################################################################
sub toHTML {
  my ($this, $params) = @_;

  #writeDebug("called toHTML for hierarchy in '$this->{web}'");

  my $nrCalls = 0;
  my $top = $params->{top} || 'TopCategory';
  my $header = $params->{header} || '';
  my $footer = $params->{footer} || '';
  my $separator = $params->{separator} || '';

  my @result;
  foreach my $name (split(/\s*,\s*/,$top)) {
    #writeDebug("searching for category $name");
    my $cat = $this->getCategory($name);
    next unless $cat;
    #writeDebug("found category ".$cat->{name});
    my $catResult =  $cat->toHTML($params, \$nrCalls);
    push @result, $catResult if $catResult
  }
  my $result = '';
  if (@result) {
    $separator = TWiki::Plugins::ClassificationPlugin::Core::expandVariables($separator);
    $result = join($separator, @result);
  }

  $header = TWiki::Plugins::ClassificationPlugin::Core::expandVariables($header,
    depth=>0,
    indent=>'',
  );
  $footer = TWiki::Plugins::ClassificationPlugin::Core::expandVariables($footer,
    depth=>0,
    indent=>'',
  );

  #writeDebug("done toHTML");
  return TWiki::Func::expandCommonVariables($header.$result.$footer);
}

###############################################################################
# get preferences of a set of categories
sub getPreferences {
  my ($this, @cats) = @_;

  unless ($this->{_prefs}) {
    my $session = $TWiki::Plugins::SESSION;

    require TWiki::Prefs;
    my $prefs = new TWiki::Prefs($session);

    require TWiki::Prefs::PrefsCache;
    $prefs = new TWiki::Prefs::PrefsCache($prefs, undef, 'CAT'); 

    foreach my $cat (@cats) {
      $cat =~ s/^\s+//go;
      $cat =~ s/\s+$//go;
      my $catObj = $this->getCategory($cat);
      $prefs = $catObj->getPreferences($prefs);
    }

    $this->{_prefs} = $prefs;
  }

  return $this->{_prefs};
}

###############################################################################
sub checkAccessPermission {
  my ($this, $mode, $user, $topic, $order) = @_;

  # get acl attribute
  my $aclAttribute = $this->{_aclAttribute};

  unless (defined $aclAttribute) {
    $aclAttribute = 
      TWiki::Func::getPreferencesValue('CLASSIFICATIONPLUGIN_ACLATTRIBUTE', $this->{web}) || 
      'Category';
    $this->{_aclAttribute} = $aclAttribute;
  }

  # get categories and gather access control lists
  my $db = TWiki::Plugins::DBCachePlugin::Core::getDB($this->{web});
  my $topicObj = $db->fastget($topic);
  return undef unless $topicObj;

  my $form = $topicObj->fastget('form');
  return undef unless $form;

  $form = $topicObj->fastget($form);
  return undef unless $form;

  my $cats = $form->fastget($aclAttribute);
  return undef unless $cats;

  #my $prefs = $this->getPreferences(split(/\s*,\s*/, $cats));

  my $allowed = 1;

  return $allowed;
}

1;
