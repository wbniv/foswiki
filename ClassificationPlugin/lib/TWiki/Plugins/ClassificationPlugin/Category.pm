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

package TWiki::Plugins::ClassificationPlugin::Category;

use strict;

use constant DEBUG => 0; # toggle me

###############################################################################
# static
sub writeDebug {
  #&TWiki::Func::writeDebug('- ClassificationPlugin - '.$_[0]) if DEBUG;
  print STDERR '- ClassificationPlugin::Category - '.$_[0]."\n" if DEBUG;
}

################################################################################
# constructor
sub new {
  my $class = shift;
  my $hierarchy = shift;
  my $name = shift;

  my $this = {
    name=>$name,
    origWeb=>$hierarchy->{web},
    id=>$hierarchy->{idCounter}++,
    hierarchy=>$hierarchy,
    summary=>'',
    title=>$name,
    @_
  };
  $this->{gotUpdate} = 1;

  $this = bless($this, $class);

  # register to hierarchy
  $hierarchy->setCategory($name, $this);

  #writeDebug("new category name=$this->{name} title=$this->{title} web=$hierarchy->{web}"); 

  return $this;
}

###############################################################################
sub purgeCache {
  my $this = shift;

  #writeDebug("purging category cache for $this->{name}");
  undef $this->{_topics};
  undef $this->{_prefs};
  undef $this->{_subsumes};
  undef $this->{_contains};
  undef $this->{_nrLeafs};
  undef $this->{_isCyclic};
  undef $this->{_perms};

  $this->{gotUpdate} = 1;
}

###############################################################################
# destructor
sub DESTROY {
  my $this = shift;

  $this->purgeCache();
  undef $this->{icon};
  undef $this->{parents};
  undef $this->{children};
  undef $this->{hierarchy};
}

###############################################################################
sub init {
  my $this = shift;

  #writeDebug("init category $this->{name}");
  foreach my $name (keys %{$this->{parents}}) {
    my $parent = $this->{parents}{$name};

    # make sure the parents are pointers, not the category names
    unless (ref($parent)) {
      $parent = $this->{hierarchy}->getCategory($name);
      if ($parent) {
        $this->{parents}{$name} = $parent;
      } else {
        delete $this->{parents}{$name};
      }
    }

    # establish child relation
    $parent->addChild($this) if $parent;
  }

  $this->{gotUpdate} = 1;
}

###############################################################################
sub countLeafs {
  my $this = shift;
	
  my $nrLeafs = $this->{_nrLeafs};

  unless (defined $nrLeafs) {
    #writeDebug("counting leafs of $this->{name}");
    $nrLeafs = scalar($this->getLeafs());
    $this->{_nrLeafs} = $nrLeafs;
    $this->{gotUpdate} = 1;
    #writeDebug("countLeafs($this->{name})=$nrLeafs");
  }


  return $nrLeafs;
}

###############################################################################
sub getLeafs {
  my ($this, $result, $seen) = @_;

  $seen ||= {};
  $result ||= {};

  return keys %$result if $seen->{$this};
  $seen->{$this} = 1;

  foreach my $topic ($this->getTopics()) {
    $result->{$topic} = 1;
  }

  foreach my $child ($this->getChildren()) {
    next if $child->{name} eq 'BottomCategory';
    $child->getLeafs($result, $seen);
  }

  return keys %$result;
}

###############################################################################
# recursive version of the Wallace-Kollias for transitive closure
sub computeDistance {
  my ($this, $distance, $ancestors) = @_;

  my $thisId = $this->{id};
  return if $ancestors->{$thisId};


  # become an ancestor
  $ancestors->{$thisId} = $this;
  $$distance[$thisId][$thisId] = 0;
      
  # loop over all ancestors
  foreach my $ancestor (values %$ancestors) {
    next unless $ancestor;
    my $ancestorId = $ancestor->{id};
    my $newDistance = $$distance[$ancestorId][$thisId] + 1;

    # loop over all children
    foreach my $child ($this->getChildren()) {
      my $childId = $child->{id};
      my $ancestorToChild = $$distance[$ancestorId][$childId];

      # ... to find out if there is a shorter path
      if (!$ancestorToChild || $newDistance < $ancestorToChild) {
        $$distance[$ancestorId][$childId] = $newDistance;
        #writeDebug("computed distance ($ancestor->{name},$child->{name})=$newDistance");
      }
    }
  }

  # recursion
  foreach my $child ($this->getChildren()) {
    $child->computeDistance($distance, $ancestors);
  }

  $ancestors->{$thisId} = 0;
}

###############################################################################
sub distance {
  my ($this, $that) = @_;

  return $this->{hierarchy}->catDistance($this, $that);
}

###############################################################################
sub subsumes {
  my ($this, $that) = @_;

  return $this->{hierarchy}->subsumes($this, $that);
}

###############################################################################
# returns 1 if the given topic is in the current category or any sub-category
sub contains {
  my ($this, $topic, $seen) = @_;

  my $result = $this->{_contains}{$topic};
  #return $result if defined $result;

  $result = 0;
  my $hierarchy = $this->{hierarchy};
  my $cats = $hierarchy->getCategoriesOfTopic($topic);
  foreach my $cat (keys %$cats) {
    #writeDebug("checking $cat");
    $result = $hierarchy->subsumes($this, $cat);
    last if $result;
  }
  #writeDebug("called contains($this->{name}, $topic) = $result");
  
  # cache
  $this->{_contains}{$topic} = $result;
  $this->{gotUpdate} = 1;
  return $result;
}

###############################################################################
sub setParents {
  my $this = shift;

  #writeDebug("called $this->{name}->setParents(@_)");
  foreach my $parent (@_) {
    my $parentObj = $parent;
    my $parentName = $parent;
    if(ref($parentObj)) {
      $parentName = $parentObj->{name};
    } else {
      $parentObj = $this->{hierarchy}->getCategory($parent) || 1;
    }
    $this->{parents}{$parentName} = $parentObj;
  }
  $this->{gotUpdate} = 1;
}

###############################################################################
sub getParents {
  my $this = shift;
  return values %{$this->{parents}};
}

###############################################################################
sub getTopics {
  my $this = shift;

  unless (defined($this->{_topics})) {

    writeDebug("refreshing _topics in $this->{name}");

    my $hierarchy = $this->{hierarchy};
    my $db = TWiki::Plugins::DBCachePlugin::Core::getDB($hierarchy->{web});

    foreach my $topicName ($db->getKeys()) {
      my $topicObj = $db->fastget($topicName);

      my $form = $topicObj->fastget("form");
      next unless $form;

      $form = $topicObj->fastget($form);
      next unless $form;

      my $topicTypes = $form->fastget('TopicType');
      next unless $topicTypes;

      next if $topicTypes =~ /\bCategory\b/o;

      my $cats = $hierarchy->getCategoriesOfTopic($topicObj);
      next unless $cats;

      foreach my $name (keys %$cats) {
        next unless $name eq $this->{name};
        #writeDebug("adding $topicName it to category $this->{name}");
        $this->{_topics}{$topicName} = 1;
      }
    }
  }

  return keys %{$this->{_topics}};
}

###############################################################################
# register a subcategory
sub addChild {
  my ($this, $category) = @_;

  #writeDebug("called $this->{name}->addChild($category->{name})");
  $this->{children}{$category->{name}} = $category;
  $this->{gotUpdate} = 1;
}

###############################################################################
sub getChildren {
  my $this = shift;
  return values %{$this->{children}};
}

###############################################################################
sub setSummary {
  my ($this, $summary) = @_;
  $summary = TWiki::urlDecode($summary);
  $this->{summary} = $summary;
  $this->{gotUpdate} = 1;
  return $summary;
}

###############################################################################
sub setTitle {
  my ($this, $title) = @_;
  $title = TWiki::urlDecode($title);
  $this->{title} = $title;
  $this->{gotUpdate} = 1;
  return $title;
}

###############################################################################
sub isCyclic {
  my $this = shift;

  my $result = $this->{_isCyclic};
  return $result if defined $result;

  #writeDebug("called isCyclic($this->{name})");

  $result = 0;
  foreach my $child ($this->getChildren()) {
    next if $child->{name} eq 'BottomCategory';
    $result = $child->subsumes($this);
    if ($result) {
      #writeDebug("child $child->{name} subsumes $this->{name}: $result");
      last;
    }
  }
  
  # cache
  $this->{_isCyclic} = $result;
  $this->{gotUpdate} = 1;
  return $result;
}

###############################################################################
sub checkAccessPermission {
  my ($this, $user, $type, $seen) = @_;

  return 1 if $this->{name} =~ /^(TopCategory|BottomCategory)$/;

  $type ||= 'VIEW';
  $seen ||= {};

  # prevent infinit recursions
  return 0 if $seen->{$this};
  $seen->{$this} = 1;

  # normalize calling parameter not to trash the cache
  $user = TWiki::Func::getWikiName($user);

  # lookup cache
  my $access = $this->{_perms}{$type}{$user};

  unless (defined $access) {
    my $topic = $this->{name};
    my $web = $this->{origWeb};
    #writeDebug("checking $type access to category $web.$topic for $user");
    $access = TWiki::Func::checkAccessPermission($type, $user, undef, $topic, $web);
  
    if ($access) {
      # recurse til access granted
      foreach my $parent (values %{$this->{parents}}) {
        next if $parent->{name} eq 'TopCategory';
        $access = $parent->checkAccessPermission($user, $type, $seen);
        last if $access;
      }
    }

    # cache result
    $this->{_perms}{$type}{$user} = $access;
  }

  return $access;
}

###############################################################################
sub getPreferences {
  my ($this) = @_;

  unless ($this->{_prefs}) {
    require TWiki::Prefs::PrefsCache;
    $this->{_prefs} = new TWiki::Prefs::PrefsCache($this->{hierarchy}->{_prefs}, undef, 'CAT', 
      $this->{origWeb}, $this->{name}); 
  }
  
  return $this->{_prefs};
}

###############################################################################
sub importCategories {
  my ($this, $impCats, $seen) = @_;

  return unless $impCats;
  $seen ||= {};

  #writeDebug("called importCategories($impCats)");
  #writeDebug("already seen=".join(',', sort keys %$seen));

  my $thisHierarchy = $this->{hierarchy};
  my $thisWeb = $thisHierarchy->{web};
  foreach my $impCat (split(/\s*,\s*/, $impCats)) {

    my ($impWeb, $impTopic) = TWiki::Func::normalizeWebTopicName($thisWeb, $impCat);
    $impWeb =~ s/\//\./go;
    next unless TWiki::Func::webExists($impWeb);

    # SMELL: prevent deep recursion of two webs importing each other's categories
    my $impHierarchy = TWiki::Plugins::ClassificationPlugin::getHierarchy($impWeb);
    next unless $impHierarchy;

    $impCat = $impHierarchy->getCategory($impTopic);
    next unless $impCat;
    
    # import all child categories of impCat
    foreach my $impChild ($impCat->getChildren()) {
      my $name = $impChild->{name};
      next if $name eq 'BottomCategory';

      next if $seen->{$name};
      $seen->{$name} = 1;
      #writeDebug("importing category $name from $impChild->{hierarchy}->{web}");
      my %parents = map {$_->{name}=>1} $impChild->getParents();
      $parents{$this->{name}} = 1;

      my $cat = $thisHierarchy->getCategory($name);
      $cat = $thisHierarchy->createCategory($name);
      $cat->setTitle($impChild->{title});
      $cat->setSummary($impChild->{summary});
      $cat->setParents(keys %parents);
      $cat->setIcon($impChild->getIcon());
      $cat->{origWeb} = $impWeb;

      # recurse
      $cat->importCategories("$impWeb.$name", $seen);
    }
  }

  $this->{gotUpdate} = 1;
  #writeDebug("done importCategories()");
}

###############################################################################
sub setIcon {
  my ($this, $icon) = @_;

  $this->{icon} = $icon;
  $this->{gotUpdate} = 1;
  return $icon;
}

###############################################################################
sub getIcon {
  my $this = shift;

  return $this->{icon} || 'folder.gif';
}

###############################################################################
sub getIconUrl {
  my $this = shift;

  my $icon = $this->{icon} || 'folder.gif';

  return 
    $TWiki::cfg{PubUrlPath}.
    '/Applications/ClassificationApp/IconSet/'.
    $icon;

}

###############################################################################
sub getLink {
  my $this = shift;

  return "<a href='".$this->getUrl()."'>$this->{title}</a>";
}

###############################################################################
sub getUrl {
  my $this = shift;
  
  my $hierWeb = $this->{hierarchy}->{web};
  if ($hierWeb ne $this->{origWeb}) {
    return TWiki::Func::getScriptUrl($hierWeb, 
      'Category', 'view', name=>$this->{name});
  }

  return TWiki::Func::getScriptUrl($hierWeb, 
      $this->{name}, 'view');
}

###############################################################################
# get a list of all offsprings
sub getSubCategories {
  my ($this, $minDepth, $maxDepth) = @_;

  my %result = ();
  $minDepth ||= 1;
  $maxDepth ||= 99999999;
  $this->_getSubCategories($minDepth, $maxDepth, \%result);
  return values %result;
}

sub _getSubCategories {
  my ($this, $minDepth, $maxDepth, $result) = @_;

  return if $maxDepth <= 0;

  my $botCat = $this->{hierarchy}->{_bottom};
  foreach my $child ($this->getChildren()) {
    next if $child eq $botCat;
    next if $result->{$child->{name}};

    $result->{$child->{name}} = $child if $minDepth <= 1;
    $child->_getSubCategories($minDepth-1, $maxDepth-1, $result);
  }
}


###############################################################################
sub toHTML {
  my ($this, $params, $nrCalls, $index, $nrSiblings, $seen, $depth) = @_;

  $depth ||= 0;

  my $maxDepth = $params->{depth};
  return '' if $maxDepth && $depth >= $maxDepth;

  $index ||= 1;
  $nrSiblings ||= 0;
  $seen ||= {};
  return '' if $seen->{$this};
  $seen->{$this} = 1;

  #return '' unless $this->checkAccessPermission();

  my $header = $params->{header} || '';
  my $footer = $params->{footer} || '';
  my $format = $params->{format};
  my $separator = $params->{separator} || '';

  $format = '<ul><li> <a href="$url"><img src="$icon" />$title</a> ($leafs) $children</li></ul>' 
    unless defined $format;

  #writeDebug("toHTML() nrCalls=$$nrCalls, name=$this->{name}");

  # format sub-categories
  my @children = sort {$a->{name} cmp $b->{name}} $this->getChildren();
  my $nrChildren = @children-1;
  my $childIndex = 1;
  my @subResult;

  my $open = $params->{open};
  my $doChildren = 1;
  if ($open) {
    $doChildren = 0;
    foreach my $opener (split(/\s*,\s*/, $open)) {
      if ($this->{hierarchy}->subsumes($this, $opener)) {
        $doChildren = 1;
        last;
      }
    }
  }

  if ($doChildren) {
    foreach my $child (@children) {
      next if $child->{name} eq 'BottomCategory';
      my $childResult = $child->toHTML($params, $nrCalls, $childIndex, $nrChildren, $seen, $depth+1);
      push @subResult, $childResult if $childResult;
      $childIndex++;
    }
  }

  my $subResult = '';
  if (@subResult) {
    $separator = TWiki::Plugins::ClassificationPlugin::Core::expandVariables($separator);
    $subResult = join($separator, @subResult);
  }

  $seen->{$this} = 0;

  my $minDepth = $params->{mindepth};
  return $subResult 
    if $minDepth && $depth <= $minDepth;

  return $subResult
    if defined $params->{exclude} && $this->{name} =~ /^($params->{exclude})$/;

  return $subResult
    if defined $params->{include} && $this->{name} !~ /^($params->{include})$/;

  my $nrLeafs = $this->countLeafs();

  return $subResult
    if defined $params->{hidenull} && $params->{hidenull} eq 'on' && !$nrLeafs;

  return $subResult
    if defined $params->{duplicates} && $params->{duplicates} eq 'off' && $params->{seen}{$this->{name}};

  $params->{seen}{$this->{name}} = 1;

  my $nrTopics = scalar(keys %{$this->{_topics}});
  my $nrSubcats = scalar(grep !/^BottomCategory$/, keys %{$this->{children}});
  my $isCyclic = 0;
  $isCyclic = $this->isCyclic() if $format =~ /\$cyclic/;

  my $indent = $params->{indent} || '   ';
  $indent = $indent x $depth;

  my $iconUrl = $this->getIconUrl();


  if ($subResult) {
    $header = TWiki::Plugins::ClassificationPlugin::Core::expandVariables($header,
      'web'=>$this->{hierarchy}->{web}, 
      'origweb'=>$this->{origWeb} || '', 
      'topic'=>$this->{name},
      'name'=>$this->{name},
      'summary'=>$this->{summary},
      'title'=>$this->{title},
      'children'=>$subResult,
      'siblings'=>$nrSiblings,
      'count'=>$nrTopics,
      'index'=>$index,
      'subcats'=>$nrSubcats,
      'call'=>$$nrCalls++,
      'leafs'=>$nrLeafs,
      'cyclic'=>$isCyclic,
      'id'=>$this->{id},
      'depth'=>$depth,
      'indent'=>$indent,
      'icon'=>$iconUrl,
    );
    $footer = TWiki::Plugins::ClassificationPlugin::Core::expandVariables($footer,
      'web'=>$this->{hierarchy}->{web}, 
      'origweb'=>$this->{origWeb} || '', 
      'topic'=>$this->{name},
      'name'=>$this->{name},
      'summary'=>$this->{summary},
      'title'=>$this->{title},
      'children'=>$subResult,
      'siblings'=>$nrSiblings,
      'count'=>$nrTopics,
      'index'=>$index,
      'subcats'=>$nrSubcats,
      'call'=>$$nrCalls++,
      'leafs'=>$nrLeafs,
      'cyclic'=>$isCyclic,
      'id'=>$this->{id},
      'depth'=>$depth,
      'indent'=>$indent,
      'icon'=>$iconUrl,
    );
    $subResult = $header.$subResult.$footer;
  }

  return TWiki::Plugins::ClassificationPlugin::Core::expandVariables($format, 
    'link'=>($this->{name} =~ /^(TopCategory|BottomCategory)$/)?
      "<b>$this->{title}</b>":$this->getLink(),
    'url'=>($this->{name} =~ /^(TopCategory|BottomCategory)$/)?"":
      $this->getUrl(),
    'web'=>$this->{hierarchy}->{web}, 
    'origweb'=>$this->{origWeb} || '', 
    'topic'=>$this->{name},
    'name'=>$this->{name},
    'summary'=>$this->{summary},
    'title'=>$this->{title},
    'children'=>$subResult,
    'siblings'=>$nrSiblings,
    'count'=>$nrTopics,
    'index'=>$index,
    'subcats'=>$nrSubcats,
    'call'=>$$nrCalls++,
    'leafs'=>$nrLeafs,
    'cyclic'=>$isCyclic,
    'id'=>$this->{id},
    'depth'=>$depth,
    'indent'=>$indent,
    'icon'=>$iconUrl,
  );
}

1;
