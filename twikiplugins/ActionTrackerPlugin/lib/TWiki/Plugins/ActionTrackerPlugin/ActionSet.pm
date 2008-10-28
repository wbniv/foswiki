#
# Copyright (C) Motorola 2002 - All rights reserved
#
# TWiki extension that adds tags for action tracking
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

# Perl object that represents a set of actions.
package TWiki::Plugins::ActionTrackerPlugin::ActionSet;

use strict;
use integer;
use TWiki::Func;

use TWiki::Plugins::ActionTrackerPlugin::Format;

# PUBLIC constructor
sub new {
    my $class = shift;
    my $this = {};

    $this->{ACTIONS} = [];

    return bless( $this, $class );
  }

# PUBLIC Add this action to the list of actions
sub add {
    my ( $this, $action ) = @_;

    push @{$this->{ACTIONS}}, $action;
  }

# PUBLIC STATIC load an action set from a block of text,
# ignoring the rest of the text
sub load {
    my ( $web, $topic, $text ) = @_;
    my $actions = new TWiki::Plugins::ActionTrackerPlugin::ActionSet();

    # FORMAT DEPENDANT ACTION SCAN
    my $actionNumber = 0;
    my $gathering;
    my $processAction = 0;
    my $attrs;
    my $descr;
    foreach my $line ( split( /\r?\n/, $text )) {
        if ( $gathering ) {
            if ( $line =~ m/^$gathering\b.*/ ) {
                $gathering = undef;
                $processAction = 1;
            } else {
                $descr .= $line."\n";
                next;
            }
        } elsif ( $line =~ m/.*?%ACTION{(.*?)}%(.*)$/o ) {
            $attrs = $1;
            $descr = $2;
            if ( $descr =~ m/\s*<<(\w+)\s*(.*)$/o ) {
                $descr = $2;
                $gathering = $1;
                next;
            }
            $processAction = 1;
        }
        if ( $processAction ) {
            my $action = new TWiki::Plugins::ActionTrackerPlugin::Action
              ( $web, $topic, $actionNumber++, $attrs, $descr );
            $actions->add( $action );
            $processAction = 0;
        }
    }
    return $actions;
}

# PRIVATE place to put sort fields
my @_sortfields;

# PUBLIC sort by due date or, if given, by an ordered sequence
# of attributes by string value
sub sort {
    my ( $this, $order ) = @_;
    if ( defined( $order ) ) {
        $order =~ s/[^\w,]//g;
        @_sortfields = split( /,\s*/, $order );
        @{$this->{ACTIONS}} = sort {
            foreach my $sf ( @_sortfields ) {
                my ( $x, $y ) = ( $a->{$sf}, $b->{$sf} );
                if ( defined( $x ) && defined( $y )) {
                    my $c = ( $x cmp $y );
                    return $c if ( $c != 0 );
                    # COVERAGE OFF should never be needed
                } elsif ( defined( $x ) ) {
                    return -1;
                } elsif ( defined( $y ) ) {
                    return 1;
                }
                # COVERAGE ON
            }
            # default to sorting on due
            my $x = $a->secsToGo();
            my $y = $b->secsToGo();
            return $x <=> $y;
        } @{$this->{ACTIONS}};
    } else {
        @{$this->{ACTIONS}} =
          sort {
              my $x = $a->secsToGo();
              my $y = $b->secsToGo();
              return $x <=> $y;
          } @{$this->{ACTIONS}};
    }
}

# PUBLIC Concatenate another action set to this one
sub concat {
    my ( $this, $actions ) = @_;

    push @{$this->{ACTIONS}}, @{$actions->{ACTIONS}};
}

# PUBLIC Search the set of actions for actions that match the given
# attributes. Return an ActionSet. If the search expression is empty,
# all actions match.
sub search {
    my ( $this, $attrs ) = @_;
    my $action;
    my $chosen = new TWiki::Plugins::ActionTrackerPlugin::ActionSet();

    foreach $action ( @{$this->{ACTIONS}} ) {
        if ( $action->matches( $attrs ) ) {
            $chosen->add( $action );
        }
    }

    return $chosen;
}

sub stringify {
    my $this = shift;
    my $txt = 'ActionSet{';
    foreach my $action ( @{$this->{ACTIONS}} ) {
        $txt .= "\n " . $action->stringify();
    }
    return $txt."\n}";
}

# PUBLIC format the action set as an HTML table
# Pass $type="name" to to get an anchor to a position
# within the topic, "href" to get a jump. Defaults to "name".
# Pass $newWindow=1 to get separate browser window,
# $newWindow=0 to get jump in same window.
sub formatAsHTML {
    my ( $this, $format, $jump, $newWindow, $class ) = @_;
    return $format->formatHTMLTable( \@{$this->{ACTIONS}}, $jump, $newWindow,
                                    $class );
}

# PUBLIC format the action set as a plain string
sub formatAsString {
    my ( $this, $format ) = @_;
    return $format->formatStringTable( \@{$this->{ACTIONS}} );
}

# PUBLIC find actions that have changed.
# Recent actions will have a UID that lets us match them exactly,
# but older actions will not have a UID and will have to be
# matched using a fuzzy match tuned for detecting 'interesting'
# state changes in actions.
# See Action->fuzzyMatches for details.
# Changed actions are returned as text in a hash keyed on the
# names of people who have registered for notification.
sub findChanges {
    my ( $this, $old, $date, $format, $notifications ) = @_;

    my @matchOld;
    my @matchNew;
    my $oaction;
    my $naction;
    my $o;
    my $n;

    # Try and match by UIDs first. If all the actions in your
    # wiki are known to have UIDs, they should all match here.
    $o = 0;
    foreach $oaction ( @{$old->{ACTIONS}} ) {
        my $uid = $oaction->{uid};
        if ( defined( $uid )) {
            $n = 0;
            foreach $naction ( @{$this->{ACTIONS}} ) {
                if ( defined( $naction->{uid} ) && $naction->{uid} eq $uid ) {
                    $naction->findChanges( $oaction, $format, $notifications );
                    $matchOld[$o] = 1;
                    $matchNew[$n] = 1;
                    last;
                }
                $n++;
            }
        }
        $o++;
    }

    # Assume the action _order_ is not changed, but actions may have
    # been inserted or deleted. For each old action,
    # find the next new action that fuzzyMatches the old action starting
    # from the most recently matched new action.
    for ( $o = 0; $o < scalar( @{$old->{ACTIONS}} ); $o++ ) {
        if ( !$matchOld[$o] ) {
            $oaction = @{$old->{ACTIONS}}[$o];
            my $bestMatch = -1;
            my $bestScore = -1;
            for ( $n = 0; $n < scalar( @{$this->{ACTIONS}} ); $n++ ) {
                if ( !$matchNew[$n] ) {
                    $naction = @{$this->{ACTIONS}}[$n];
                    my $score = $naction->fuzzyMatches( $oaction );

                    if ( $score > $bestScore ) {
                        $bestMatch = $n;
                        $bestScore = $score;
                    }
                }
            }
            if ( $bestScore > 7 ) {
                $naction = @{$this->{ACTIONS}}[$bestMatch];
                $naction->findChanges( $oaction, $format, $notifications );
                $matchNew[$bestMatch] = 1;
            }
        }
    }
}

# PUBLIC get a map of all people who have actions in this action set
sub getActionees {
    my ( $this, $whos ) = @_;
    my $action;

    foreach $action ( @{$this->{ACTIONS}} ) {
        my @persons = split( /,\s*/, $action->{who} );
        foreach my $person ( @persons ) {
            $whos->{$person} = 1;
        }
    }
}

# PUBLIC STATIC get all actions in topics in the given web that
# match the search expression
# $web - name of the web to search
# $attrs - attributes to match
# $internal - boolean true if topic permissions can be ignored
sub allActionsInWeb {
    my ( $web, $attrs, $internal ) = @_;
    $internal = 0 unless defined ( $internal );
    my $actions = new TWiki::Plugins::ActionTrackerPlugin::ActionSet();
	my @tops = TWiki::Func::getTopicList( $web );
	my $topics = $attrs->{topic};

	@tops = grep( /^$topics$/, @tops ) if ( $topics );
    my $grep =
      TWiki::Func::searchInWebContent( '%ACTION{.*}%', $web,
                                       \@tops,
                                       { type => 'regex',
                                         files_without_match => 1,
                                         casesensitive => 1 } );

    foreach my $topic ( keys %$grep ) {
        # SMELL: always read the text, because it's faster in the current
        # impl to find the perms embedded in it
        my $text = TWiki::Func::readTopicText(
            $web, $topic, undef, $internal );
        next unless $internal || TWiki::Func::checkAccessPermission(
            'VIEW', TWiki::Func::getWikiName(), $text, $topic, $web);
        my $tacts = TWiki::Plugins::ActionTrackerPlugin::ActionSet::load(
            $web, $topic, $text );
        $tacts = $tacts->search( $attrs );
        $actions->concat( $tacts );
    }

    return $actions;
}

# PUBLIC STATIC get all actions in all webs that
# match the search in $attrs
sub allActionsInWebs {
    my ( $theweb, $attrs, $internal ) = @_;
    $internal = 0 unless defined ( $internal );
    my $filter = $attrs->{web} || $theweb;
    my $choice = 'user';
    # Exclude webs flagged as NOSEARCHALL
    $choice .= ',public' if $filter ne $theweb;
    my @webs = grep { /^$filter$/ } TWiki::Func::getListOfWebs( $choice );
    my $actions = new TWiki::Plugins::ActionTrackerPlugin::ActionSet();

    foreach my $web ( @webs ) {
        my $subacts = allActionsInWeb( $web, $attrs, $internal );
        $actions->concat( $subacts );
    }
    return $actions;
}

1;
