# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006-2007 Michael Daum http://michaeldaumconsulting.com
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

package TWiki::Plugins::ClassificationPlugin::Core;

use strict;

use vars qw(%hierarchies $baseWeb $baseTopic);

use constant DEBUG => 0; # toggle me

###############################################################################
sub writeDebug {
  print STDERR '- ClassificationPlugin::Core - '.$_[0]."\n" if DEBUG;
}

###############################################################################
sub init {
  ($baseWeb, $baseTopic) = @_;

  %hierarchies = ();
}

###############################################################################
sub finish {

  foreach my $hierarchy (values %hierarchies) {
    next unless defined $hierarchy;
    $hierarchy->finish();
    undef $hierarchies{$hierarchy->{web}};
  }
}


###############################################################################
sub OP_subsumes {
  my ($r, $l, $map) = @_;
  my $lval = $l->matches( $map );
  my $rval = $r->matches( $map );
  return 0 unless ( defined $lval  && defined $rval);

  my $hierarchy = getHierarchy($baseWeb);
  return $hierarchy->subsumes($lval, $rval);
}

###############################################################################
sub OP_isa {
  my ($r, $l, $map) = @_;
  my $lval = $l->matches( $map );
  my $rval = $r->matches( $map );
  return 0 unless ( defined $lval  && defined $rval);

  my $hierarchy = getHierarchy($baseWeb);
  my $cat = $hierarchy->getCategory($rval);
  return 0 unless $cat;

  return ($cat->contains($lval))?1:0;
}

###############################################################################
sub OP_distance {
  my ($r, $l, $map) = @_;
  my $lval = $l->matches( $map );
  my $rval = $r->matches( $map );

  return 0 unless ( defined $lval  && defined $rval);

  my $hierarchy = getHierarchy($baseWeb);
  my $dist = $hierarchy->distance($lval, $rval);
  return $dist || 0;
}

###############################################################################
sub handleTAGCOOCCURRENCE {
  my ($session, $params, $theTopic, $theWeb) = @_;

  my $theTag1 = $params->{tag1};
  my $theTag2 = $params->{tag2};
  my $thisTopic = $params->{_DEFAULT} || $params->{topic} || $baseTopic;
  my $thisWeb = $params->{web} || $baseWeb;
  my $theFormat = $params->{format} || '   * $tag1, $tag2: $count$n';
  my $theSep = $params->{separator} || '';
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $theArrayFormat = $params->{arrayformat} || '$tag2 ($count)';
  my $theArraySep = $params->{arrayseparator};
  my $theAllPairs = $params->{allpairs} || 'on';

  $theAllPairs = ($theAllPairs eq 'on')?1:0;
  $theArraySep = ',' unless defined($theArraySep);

  my $hierarchy = getHierarchy($thisWeb);
  my $coocc = $hierarchy->getCooccurrence($theTag1, $theTag2);

  my $result = '';

  # format
  my @result = ();
  if (defined($theTag1)) {
    if (defined($theTag2)) {
      # mode 3: coocurrences of tag1 and tag2
      my $count = $$coocc{$theTag1}{$theTag2};
      if (defined($count)) {
        push @result,  expandVariables($theFormat,
          tag1=>$theTag1,
          tag2=>$theTag2,
          count=>$count,
        );
      }
    } else {
      # mode 2: all coocurrences of tag1
      my @coocurringTags = sort keys %{$$coocc{$theTag1}};
      my $arrayResult = '';
      if ($theFormat =~ /\$array/) {
        my @arrayResult = ();
        foreach my $tag (@coocurringTags) {
          push @arrayResult, expandVariables($theArrayFormat,
            tag2=>$tag,
            count=>$$coocc{$theTag1}{$tag},
          );
        }
        $arrayResult = join($theArraySep, @arrayResult);
      }
      foreach my $theTag2 (@coocurringTags) {
        my $count = $$coocc{$theTag1}{$theTag2};
        if (defined($count)) {
          push @result,  expandVariables($theFormat,
            tag1=>$theTag1,
            tag2=>$theTag2,
            count=>$count,
            array=>$arrayResult,
          );
        }
      }
    }
  } else {
    if (defined($theTag2)) {
      # mode 2: all coocurrences of tag1
      my @coocurringTags = sort keys %{$$coocc{$theTag2}};
      my $arrayResult = '';
      if ($theFormat =~ /\$array/) {
        my @arrayResult = ();
        foreach my $tag (@coocurringTags) {
          push @arrayResult, expandVariables($theArrayFormat,
            tag2=>$tag,
            count=>$$coocc{$theTag1}{$tag},
          );
        }
        $arrayResult = join($theArraySep, @arrayResult);
      }
      foreach my $theTag1 (@coocurringTags) {
        my $count = $$coocc{$theTag1}{$theTag2};
        if (defined($count)) {
          push @result,  expandVariables($theFormat,
            tag1=>$theTag1,
            tag2=>$theTag2,
            count=>$count,
            array=>$arrayResult,
          );
        }
      }
    } else {
      # mode 1: full cooccurrence matrix
      my %seen;
      foreach my $theTag1 (sort keys %{$coocc}) {
        my @coocurringTags = sort keys %{$$coocc{$theTag1}};
        #writeDebug("coocurringTags($theTag1)=@coocurringTags");
        my $arrayResult = '';

        if ($theFormat =~ /\$array/) {
          my @arrayResult = ();
          foreach my $tag (@coocurringTags) {
            next if $seen{$theTag1}{$tag};
            next if $seen{$tag}{$theTag1};
            $seen{$theTag1}{$tag} = 1;
            $seen{$tag}{$theTag1} = 1;
            push @arrayResult, expandVariables($theArrayFormat,
              tag2=>$tag,
              count=>$$coocc{$theTag1}{$tag},
            );
          }
          $arrayResult = join($theArraySep, @arrayResult);
        }

        if ($theAllPairs) {
          foreach my $theTag2 (@coocurringTags) {
            next if $seen{$theTag1}{$theTag2};
            next if $seen{$theTag2}{$theTag1};
            $seen{$theTag1}{$theTag2} = 1;
            $seen{$theTag2}{$theTag1} = 1;
            my $count = $$coocc{$theTag1}{$theTag2};
            if (defined($count)) {
              push @result,  expandVariables($theFormat,
                tag1=>$theTag1,
                tag2=>$theTag2,
                count=>$count,
                array=>$arrayResult,
              );
            }
          }
        } else {
          push @result,  expandVariables($theFormat,
            tag1=>$theTag1,
            array=>$arrayResult,
          );
        }
      }
    }
  }
  
  $theHeader = expandVariables($theHeader);
  $theFooter = expandVariables($theFooter);
  $theSep = expandVariables($theSep);

  return $theHeader.join($theSep, @result).$theFooter;
}

###############################################################################
sub handleTAGRELATEDTOPICS {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called handleTAGRELATEDTOPICS()");

  my $thisTopic = $params->{_DEFAULT} || $params->{topic} || $baseTopic;
  my $thisWeb = $params->{web} || $baseWeb;
  my $theFormat = $params->{format} || '$topic';
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $theSep = $params->{separator};
  my $theIntersect = $params->{intersect} || 2;
  my $theMax = $params->{max} || 0;

  # sanitice parameters
  $theIntersect =~ s/[^\d]//g;
  $theIntersect = 2 if $theIntersect eq '';
  $theMax =~ s/[^\d]//g;
  $theMax = 0 if $theMax eq '';
  $theSep = ', ' unless defined $theSep;
  ($thisTopic, $thisWeb) = 
    TWiki::Func::normalizeWebTopicName($thisTopic, $thisWeb);

  my $hierarchy = getHierarchy($thisWeb);
  my $tagIntersection = $hierarchy->getTagIntersection($thisTopic);
  return unless $tagIntersection;

  # sort most intersecting first
  my @foundTopics = 
    sort {$$tagIntersection{$b}{size} <=> $$tagIntersection{$a}{size}} 
      grep {$$tagIntersection{$_}{size} >= $theIntersect}
        keys %$tagIntersection;

  # format result
  my @lines;
  my $count = 0;
  foreach my $topic (@foundTopics) {
    $count++;
    last if $theMax && $count > $theMax;
    push @lines, expandVariables($theFormat,
      'topic'=>$topic,
      'web'=>$thisWeb,
      'index'=>$count,
      'size'=>$$tagIntersection{$topic}{size},
      'tags'=>join(', ', sort @{$$tagIntersection{$topic}{tags}}),
    );
  }

  #writeDebug("done handleTAGRELATEDTOPICS()");

  return '' unless @lines;
  $theHeader = expandVariables($theHeader, count=>$count);
  $theFooter = expandVariables($theFooter, count=>$count);
  $theSep = expandVariables($theSep);

  return $theHeader.join($theSep, @lines).$theFooter;
}

###############################################################################
sub handleHIERARCHY {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called handleHIERARCHY(".$params->stringify().")");

  my $thisWeb = $params->{_DEFAULT} || $params->{web} || $baseWeb;
  $thisWeb =~ s/\./\//go;

  my $hierarchy = getHierarchy($thisWeb);
  return $hierarchy->toHTML($params);
}

###############################################################################
sub handleISA {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called handleISA()");
  my $thisWeb = $params->{web} || $baseWeb;
  my $thisTopic = $params->{_DEFAULT} || $params->{topic} || $baseTopic;
  my $theCategory = $params->{cat} || 'TopCategpory';

  return 1 if $theCategory =~ /^TOP|TopCategory$/o;
  return 0 if $theCategory =~ /^BOTTOM|BottomCategory$/o;
  return 0 unless $theCategory;

  ($thisWeb, $thisTopic) =
    TWiki::Func::normalizeWebTopicName($thisWeb, $thisTopic);

  my %lookingForCategory = map {$_=>1} split(/\s*,\s*/,$theCategory);
  my $hierarchy = getHierarchy($thisWeb);

  foreach my $catName (keys %lookingForCategory) {
    my $cat = $hierarchy->getCategory($catName);
    next unless $cat;
    return 1 if $cat->contains($thisTopic);
  }

  return 0;
}

###############################################################################
sub handleSUBSUMES {
  my ($session, $params, $theTopic, $theWeb) = @_;

  my $thisWeb = $params->{web} || $baseWeb;
  my $theCat1 = $params->{_DEFAULT} || $baseTopic;
  my $theCat2 = $params->{cat} || '';

  #writeDebug("called handleSUBSUMES($theCat1, $theCat2)");

  return 0 unless $theCat2;

  my $hierarchy = getHierarchy($thisWeb);
  my $cat1 = $hierarchy->getCategory($theCat1);
  return 0 unless $cat1;

  my $result = 0;
  foreach my $catName (split(/\s*,\s*/,$theCat2)) {
    $catName =~ s/^\s+//g;
    $catName =~ s/\s+$//g;
    next unless $catName;
    my $cat2 = $hierarchy->getCategory($catName);
    next unless $cat2;
    $result = $cat1->subsumes($cat2) || 0;
    last if $result;
  }

  #writeDebug("result=$result");

  return $result;
}

###############################################################################
sub handleDISTANCE {
  my ($session, $params, $theTopic, $theWeb) = @_;

  my $thisWeb = $params->{web} || $baseWeb;
  my $theFrom = $params->{_DEFAULT} || $params->{from} || $baseTopic;
  my $theTo = $params->{to} || 'TopCategory';
  my $theAbs = $params->{abs} || 'off';
  my $theFormat = $params->{format} || '$dist';

  #writeDebug("called handleDISTANCE($theFrom, $theTo)");

  my $hierarchy = getHierarchy($thisWeb);
  my $distance = $hierarchy->distance($theFrom, $theTo);

  return '' unless defined $distance;

  $distance = abs($distance) if $theAbs eq 'on';

  #writeDebug("distance=$distance");

  my $result = $theFormat;
  $result =~ s/\$dist/$distance/g;

  return $result;
}

###############################################################################
sub handleCATFIELD {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called handleCATFIELD(".$params->stringify().")");

  my $theFormat = $params->{format} || '$cat';
  my $theSep = $params->{separator};
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $theTypes = $params->{type} || $params->{types} || '';
  my $thisTopic = $params->{_DEFAULT} || $params->{topic} || $baseTopic;
  my $thisWeb = $params->{web} || $baseWeb;

  $theSep = ', ' unless defined $theSep;

  ($thisWeb, $thisTopic) = 
    TWiki::Func::normalizeWebTopicName($thisWeb, $thisTopic);

  my $topicTypes;
  if ($theTypes) {
    #writeDebug("type mode");
    @{$topicTypes} = split(/\s*,\s*/,$theTypes);
  } else {
    #writeDebug("topic mode");
    $topicTypes = getTopicTypes($thisWeb, $thisTopic);
  }
  return '' unless $topicTypes && @$topicTypes;

  my $hierarchy = getHierarchy($thisWeb);
  my $catFields = $hierarchy->getCatFields(@$topicTypes);
  #writeDebug("found catFields=".join(',',@$catFields));
  my @result;
  my $count = @$catFields;
  my $index = 1;
  foreach my $catField (@$catFields) {
    my $line = $theFormat;
    $line =~ s/\$cat\b/$catField/g;
    $line =~ s/\$index\b/$index/g;
    $index++;
    push @result, $line;
  }

  my $result = $theHeader.join($theSep, @result).$theFooter;
  $result = expandVariables($result, 'count'=>$count);

  #writeDebug("result=$result");
  return $result;
}

###############################################################################
sub handleTAGFIELD {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called handleTAGFIELD(".$params->stringify().")");

  my $theFormat = $params->{format} || '$tag';
  my $theSep = $params->{separator};
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $theTypes = $params->{_DEFAULT} || $params->{type} || $params->{types} || '';

  $theSep = ', ' unless defined $theSep;

  my $thisTopic = $params->{topic} || $baseTopic;
  my $thisWeb = $params->{web} || $baseWeb;

  ($thisWeb, $thisTopic) = 
    TWiki::Func::normalizeWebTopicName($thisWeb, $thisTopic);

  #writeDebug("thisWeb=$thisWeb, thisTopic=$thisTopic");

  my $topicTypes;
  if ($theTypes) {
    @{$topicTypes} = split(/\s*,\s*/,$theTypes);
  } else {
    $topicTypes = getTopicTypes($thisWeb, $thisTopic);
  }
  return '' unless $topicTypes && @$topicTypes;

  my $hierarchy = getHierarchy($thisWeb);

  my $tagFields = $hierarchy->getTagFields(@$topicTypes);
  #writeDebug("found tagFields=".join(',',@$tagFields));
  my @result;
  my $count = @$tagFields;
  my $index = 1;
  foreach my $tagField (@$tagFields) {
    my $line = $theFormat;
    $line =~ s/\$tag\b/$tagField/g;
    $line =~ s/\$index\b/$index/g;
    $index++;
    push @result, $line;
  }

  my $result = $theHeader.join($theSep, @result).$theFooter;
  $result = expandVariables($result, 'count'=>$count);

  #writeDebug("result=$result");
  return $result;
}

###############################################################################
sub handleCATINFO {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called handleCATINFO(".$params->stringify().")");
  my $theCat = $params->{cat};
  my $theFormat = $params->{format} || '$link';
  my $theSep = $params->{separator};
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $thisWeb = $params->{web} || $baseWeb;
  my $thisTopic = $params->{_DEFAULT} || $params->{topic} || $baseTopic;
  my $theSubsumes = $params->{subsumes} || '';
  my $theSortChildren = $params->{sortchildren} || 'off';
  my $theMaxChildren = $params->{maxchildren} || 0;
  my $theHideNull = $params->{hidenull} || 'off';

  $theSep = ', ' unless defined $theSep;
  $theMaxChildren =~ s/[^\d]//go;
  $theMaxChildren = 0 unless defined $theMaxChildren;

  if ($theCat) { # cats mode
    ($thisWeb, $theCat) = 
      TWiki::Func::normalizeWebTopicName($thisWeb, $theCat);
  } else { # dogs mode
    ($thisWeb, $thisTopic) = 
      TWiki::Func::normalizeWebTopicName($thisWeb, $thisTopic);
  }

  my $hierarchy = getHierarchy($thisWeb);
  return '' unless $hierarchy;

  $theSubsumes =~ s/^\s+//go;
  $theSubsumes =~ s/\s+$//go;
  my $subsumesCat = $hierarchy->getCategory($theSubsumes);

  my $categories;
  if ($theCat) { # cats mode
    $categories->{$theCat} = 1;
  } else { # dogs mode
    $categories = $hierarchy->getCategoriesOfTopic($thisTopic);
  }

  my @categories = keys %$categories;
  #@categories = grep (!/^(TopCategory|BottomCategory)$/, @categories);
  return '' unless @categories;
  
  my @result;
  foreach my $catName (sort @categories) {
    if ($catName =~ /^(TopCategory|BottomCategory)$/ &&
        !TWiki::Func::topicExists($thisWeb, $catName)) {
      next;
    }
    my $category = $hierarchy->getCategory($catName);
    unless ($category) {
      writeDebug("Woops: there's no category '$catName' ... found in $thisTopic");
      next;
    }


    # skip catinfo from another branch of the hierarchy
    next if $subsumesCat && !$hierarchy->subsumes($subsumesCat, $category);

    my $line = $theFormat;

    my $parents = '';
    if ($line =~ /\$parents?\b/) {
      my @links = ();
      foreach my $parent ($category->getParents()) {
        push @links, $parent->getLink();
      }
      $parents = join(', ', @links);
    }

    my $parentsName = '';
    if ($line =~ /\$parents?names?/) {
      my @names = ();
      foreach my $parent ($category->getParents()) {
        push @names, $parent->{name};
      }
      $parentsName = join(', ', @names);
    }

    my $parentsTitle = '';
    if ($line =~ /\$parents?title/) {
      my @titles = ();
      foreach my $parent ($category->getParents()) {
        push @titles, $parent->{title};
      }
      $parentsTitle = join(', ', @titles);
    }

    my $parentLinks = '';
    if ($line =~ /\$parents?links?/) {
      my @links = ();
      foreach my $parent ($category->getParents()) {
        push @links, $parent->getLink();
      }
      $parentLinks = join(', ', @links);
    }

    my $parentUrls = '';
    if ($line =~ /\$parents?urls?/) {
      my @urls = ();
      foreach my $parent ($category->getParents()) {
        push @urls, $parent->getUrl();
      }
      $parentUrls = join(', ', @urls);
    }

    my @children;
    my $moreChildren = '';
    if ($line =~ /\$children/) {
      @children = $category->getChildren();
      @children = grep {$_->{name} ne 'BottomCategory'} 
        @children;

      if ($theHideNull eq 'on') {
        @children = grep {$_->countLeafs() > 0} 
          @children;
      }

      if ($theSortChildren eq 'on') {
        @children = 
          sort {$b->countLeafs() <=> $a->countLeafs() || 
                $a->{title} cmp $b->{title}} 
            @children;
      }

      if ($theMaxChildren && $theMaxChildren < @children) {
        if (splice(@children, $theMaxChildren)) {
          $moreChildren = $params->{morechildren} || '';
        }
      }
    }

    my $children = '';
    if ($line =~ /\$children?\b/) {
      my @links = ();
      foreach my $child (@children) {
        push @links, $child->getLink();
      }
      $children = join(', ', @links);
    }

    my $childrenName = '';
    if ($line =~ /\$children?names?/) {
      my @names = ();
      foreach my $child (@children) {
        push @names, $child->{name};
      }
      $childrenName = join(', ', @names);
    }

    my $childrenTitle = '';
    if ($line =~ /\$children?title/) {
      my @titles = ();
      foreach my $child (@children) {
        push @titles, $child->{title};
      }
      $childrenTitle = join(', ', @titles);
    }

    my $childrenLinks = '';
    if ($line =~ /\$children?links?/) {
      my @links = ();
      foreach my $child (@children) {
        push @links, $child->getLink();
      }
      $childrenLinks = join(', ', @links);
    }

    my $childrenUrls = '';
    if ($line =~ /\$children?urls?/) {
      my @urls = ();
      foreach my $child (@children) {
        push @urls, $child->getUrl();
      }
      $childrenUrls = join(', ', @urls);
    }

    my $isCyclic = 0;
    $isCyclic = $category->isCyclic() if $theFormat =~ /\$cyclic/;

    my $countLeafs = '';
    $countLeafs = $category->countLeafs() if $theFormat=~ /\$leafs/;

    my $title = $category->{title} || $catName;
    my $link = $category->getLink();
    my $url = $category->getUrl();
    my $summary = $category->{summary} || '';

    my $iconUrl = $category->getIconUrl();

    $line =~ s/\$more/$moreChildren/g;
    $line =~ s/\$link/$link/g;
    $line =~ s/\$url/$url/g;
    $line =~ s/\$web/$thisWeb/g;
    $line =~ s/\$origweb/$category->{origWeb}/g;
    $line =~ s/\$(name|topic)/$catName/g;
    $line =~ s/\$title/$title/g;
    $line =~ s/\$summary/$summary/g;
    $line =~ s/\$parents?name/$parentsName/g;
    $line =~ s/\$parents?title/$parentsTitle/g;
    $line =~ s/\$parents?links?/$parentLinks/g;
    $line =~ s/\$parents?urls?/$parentUrls/g;
    $line =~ s/\$parents?/$parents/g;
    $line =~ s/\$cyclic/$isCyclic/g;
    $line =~ s/\$leafs/$countLeafs/g;

    $line =~ s/\$children?name/$childrenName/g;
    $line =~ s/\$children?title/$childrenTitle/g;
    $line =~ s/\$children?links?/$childrenLinks/g;
    $line =~ s/\$children?urls?/$childrenUrls/g;
    $line =~ s/\$children?/$children/g;
    $line =~ s/\$icon/$iconUrl/g;
    push @result, $line;
  }
  return '' unless @result;
  my $result = $theHeader.join($theSep, @result).$theFooter;
  $result = expandVariables($result, 'count'=>scalar(@categories));

  #writeDebug("result=$result");
  return $result;
}

###############################################################################
sub handleTAGINFO {
  my ($session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called handleTAGINFO(".$params->stringify().")");
  my $theCat = $params->{cat};
  my $theFormat = $params->{format} || '$link';
  my $theSep = $params->{separator};
  my $theHeader = $params->{header} || '';
  my $theFooter = $params->{footer} || '';
  my $thisWeb = $params->{web} || $baseWeb;
  my $thisTopic = $params->{_DEFAULT} || $params->{topic} || $baseTopic;

  $theSep = ', ' unless defined $theSep;

  ($thisWeb, $thisTopic) = 
    TWiki::Func::normalizeWebTopicName($thisWeb, $thisTopic);

  # get tags
  require TWiki::Plugins::DBCachePlugin::Core;
  my $db = TWiki::Plugins::DBCachePlugin::Core::getDB($thisWeb);
  return '' unless $db;
  my $topicObj = $db->fastget($thisTopic);
  return '' unless $topicObj;
  my $form = $topicObj->fastget('form');
  return '' unless $form;
  my $formObj = $topicObj->fastget($form);
  return '' unless $formObj;
  my $tags = $formObj->fastget('Tag');
  return '' unless $tags;
  my @tags = split(/\s*,\s*/, $tags);

  my @result;
  foreach my $tag (sort @tags) {
    $tag =~ s/^\s+//go;
    $tag =~ s/\s+$//go;
    my $line = $theFormat;
    my $url = TWiki::Func::getScriptUrl($thisWeb, "WebTagCloud", "view", search=>$tag);
    my $link = "<a href='$url'>$tag</a>";
    $line =~ s/\$url/$url/g;
    $line =~ s/\$link/$link/g;
    $line =~ s/\$web/$thisWeb/g;
    $line =~ s/\$name/$tag/g;
    push @result, $line;
  }
  my $result = $theHeader.join($theSep, @result).$theFooter;
  $result = expandVariables($result, 'count'=>scalar(@tags));

  #writeDebug("result='$result'");
  return $result;
}

###############################################################################
# reparent based on the category we are in
# takes the first category in alphabetic order
sub beforeSaveHandler {
  my ($text, $topic, $web, $meta) = @_;

  writeDebug("beforeSaveHandler($web, $topic)");
  my $doAutoReparent = TWiki::Func::getPreferencesFlag('CLASSIFICATIONPLUGIN_AUTOREPARENT', $web);
  $doAutoReparent = 1 unless defined $doAutoReparent;

  unless ($meta) {
    my $session = $TWiki::Plugins::SESSION;
    $meta = new TWiki::Meta($session, $web, $topic, $text);
  }

  # get topic type info
  my $topicType = $meta->get('FIELD', 'TopicType');
  return unless $topicType;
  $topicType = $topicType->{value};

  if ($doAutoReparent) {

    # get categories of this topic,
    # must get it from current meta data
    return unless $topicType =~ /ClassifiedTopic|CategorizedTopic|Category/;

    my @allCats;
    my $hierarchy = getHierarchy($web);
    my $catFields = $hierarchy->getCatFields(split(/\s*,\s*/,$topicType));

    # get categories from meta data
    foreach my $field (@$catFields) {
      my $cats = $meta->get('FIELD',$field);
      next unless $cats;
      $cats = $cats->{value};
      next unless $cats;
      foreach my $cat (split(/\s*,\s*/,$cats)) {
        $cat =~ s/^\s+//go;
        $cat =~ s/\s+$//go;
        push @allCats, $cat;
      }
    }

    # set the new parent topic
    if (@allCats) {
      @allCats = sort @allCats;
      my $firstCat = shift @allCats;
      # TODO: check if the firstCat exists and only then set the parent
      # don't autoset to HomeTopic if TopCategory
      $firstCat = $TWiki::cfg{HomeTopic} if $firstCat eq 'TopCategory';
      $meta->remove('TOPICPARENT');
      $meta->putKeyed('TOPICPARENT', {name=>$firstCat});

    } else {
      #$meta->putKeyed('TOPICPARENT', {name=>''});
    }
  } else {
    writeDebug("not autoreparenting");
  }

  # cache invalidation
  my $mode = 0;
  $mode = 1 if $topicType =~ /\bTaggedTopic\b/;
  $mode = 2 if $topicType =~ /\bCategorizedTopic\b/;
  $mode = 3 if $topicType =~ /\bClassifiedTopic\b/;
  $mode = 4 if $topicType =~ /\bCategory\b/;

  # try even harder if it missing the CategorizedTopic TopicType but
  # still uses categories
  if ($mode < 2) { 
    my $hierarchy = getHierarchy($web); 
    my $catFields = $hierarchy->getCatFields(split(/\s*,\s*/,$topicType));
    if ($catFields && @$catFields) {
      $mode = ($mode < 1)?2:3;
    }
  }

  writeDebug("mode=$mode");

  if ($mode) {
    my $hierarchy;

    $hierarchy = getHierarchy($web);
    $hierarchy->purgeCache($mode);
#    $hierarchy->init();
  }
}

###############################################################################
sub afterSaveHandler {
  #my ($text, $topic, $web, $meta) = @_;

  finish(); # not called by modifyHeaderHandler
}

###############################################################################
sub renderFormFieldForEditHandler {
  my ($name, $type, $size, $value, $attrs, $possibleValues) = @_;
  return undef unless $type =~ /^(cat|tag|widget)$/;

  #writeDebug("called renderFormFieldForEditHandler($name, $type, $size, $value, $attrs, $possibleValues)");

  my $widget = '';

  # category widget
  if ($type eq 'cat') {
    my %params = TWiki::Func::extractParameters($possibleValues);
    my $web = $params{web} || '';
    my $top = $params{_DEFAULT} || $params{top} || 'TopCategory';
    my $exclude = $params{exclude} || '';

    $widget = '%DBCALL{"Applications.ClassificationApp.RenderEditCategoryBrowser" '
      .'NAME="$name" VALUE="$value" TOP="$top" EXCLUDE="$exclude" THEWEB="$web"}%';

    $widget =~ s/\$web/$web/g;
    $widget =~ s/\$top/$top/g;
    $widget =~ s/\$exclude/$exclude/g;
  } 
  
  # tagging widget
  elsif ($type eq 'tag') {
    my %params = TWiki::Func::extractParameters($possibleValues);
    my $web = $params{web} || '';
    my $filter = $params{filter} || '';

    $widget = '%DBCALL{"Applications.ClassificationApp.RenderEditTagCloud" '
      .'NAME="$name" VALUE="$value" FILTER="$filter" THEWEB="$web"}%';

    $widget =~ s/\$web/$web/g;
    $widget =~ s/\$filter/$filter/g;
  }

  # generic widget
  else {
    $widget = $possibleValues;
    $widget =~ s/\$nop//go;
  }

  $widget =~ s/\$name/$name/g;
  $widget =~ s/\$type/$type/g;
  $widget =~ s/\$size/$size/g;
  $widget =~ s/\$value/$value/g;
  $widget =~ s/\$attrs/$attrs/g;
  $widget = TWiki::Func::expandCommonVariables($widget);

  # SMELL: fix for TwistyPlugin
  $widget =~ s/\%_TWISTYSCRIPT{\"(.*?)\"}\%/<script type="text\/javascript\"\>$1<\/script>/g;

  #writeDebug("widget=$widget");

  return $widget;
}

###############################################################################
sub getTopicTypes {
  my ($web, $topic) = @_;

  require TWiki::Plugins::DBCachePlugin::Core;
  my $db = TWiki::Plugins::DBCachePlugin::Core::getDB($web);
  return undef unless $db;

  my $topicObj = $db->fastget($topic);
  return undef unless $topicObj;

  my $form = $topicObj->fastget("form");
  return undef unless $form;

  $form = $topicObj->fastget($form);
  return undef unless $form;

  my $topicTypes = $form->fastget('TopicType');
  return undef unless $topicTypes;

  my @topicTypes = split(/\s*,\s*/, $topicTypes);

  return \@topicTypes;
}


###############################################################################
# returns the hierarchy object for a given web; construct a new one if
# not already done
sub getHierarchy {
  my $web = shift;

  unless (defined $hierarchies{$web}) {
    require TWiki::Plugins::ClassificationPlugin::Hierarchy;
    $hierarchies{$web} = new TWiki::Plugins::ClassificationPlugin::Hierarchy($web);
  }

  return $hierarchies{$web};
}

###############################################################################
sub expandVariables {
  my ($theFormat, %params) = @_;

  #writeDebug("called expandVariables($theFormat)");

  foreach my $key (keys %params) {
    #die "params{$key} undefined" unless defined($params{$key});
    $theFormat =~ s/\$$key\b/$params{$key}/g;
  }
  $theFormat =~ s/\$percnt/\%/go;
  $theFormat =~ s/\$nop//go;
  $theFormat =~ s/\$n/\n/go;
  $theFormat =~ s/\$t\b/\t/go;
  $theFormat =~ s/\$dollar/\$/go;

  #writeDebug("result='$theFormat'");

  return $theFormat;
}


###############################################################################
1;

