# Copyright (C) 2002 Mike Barton, Marco Carnut, Peter HErnst
#	(C) 2003 Martin Cleaver, (C) 2004 Matt Wilkie (C) 2007 Crawford Currie
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
# This is the FindElsewhere TWiki plugin,
# see http://twiki.org/cgi-bin/view/Plugins/FindElsewherePlugin for details.

package TWiki::Plugins::FindElsewherePlugin::Core;

use strict;

BEGIN {
    # Do a dynamic 'use locale' for this module
    if( $TWiki::useLocale || $TWiki::cfg{UseLocale}) {
        require locale;
        import locale ();
    }
}

use vars qw(
            $disabledFlag $disablePluralToSingular
            $webNameRegex $wikiWordRegex $abbrevRegex $singleMixedAlphaNumRegex
            $noAutolink $redirectable $initialised @webList %linkedWords $findAcronyms
           );

$initialised = 0;

sub _debug {
    # Uncomment for debug
    #TWiki::Func::writeDebug( "FindElsewherePlugin: ".join(' ', @_));
}

sub _lazyInit {
    return 1 if $initialised;
    $initialised = 1;

    my $otherWebs = TWiki::Func::getPreferencesValue( "LOOKELSEWHEREWEBS" );
    unless( defined( $otherWebs)) {
        # Compatibility, deprecated
        $otherWebs = TWiki::Func::getPluginPreferencesValue( "LOOKELSEWHEREWEBS" );
    }

    unless( defined( $otherWebs )) {
        # SMELL: Retained for compatibility, but would be much better
        # off without this, as we could use the absence of webs to mean the
        # plugin is disabled.
        $otherWebs = "TWiki,Main";
    }

    $findAcronyms = TWiki::Func::getPreferencesValue( "LOOKELSEWHEREFORACRONYMS" ) || "all";

    $disablePluralToSingular =
      TWiki::Func::getPreferencesFlag( "DISABLEPLURALTOSINGULAR" );
    unless( defined( $disablePluralToSingular)) {
        # Compatibility, deprecated
        $disablePluralToSingular =
          TWiki::Func::getPluginPreferencesFlag( "DISABLEPLURALTOSINGULAR" );
    }

    $redirectable =
      TWiki::Func::getPreferencesFlag( "LOOKELSEWHEREFORLOCAL" );

    @webList = split( /[,\s]+/, $otherWebs );

    $webNameRegex = TWiki::Func::getRegularExpression('webNameRegex');
    $wikiWordRegex = TWiki::Func::getRegularExpression('wikiWordRegex');
    $abbrevRegex = TWiki::Func::getRegularExpression('abbrevRegex');

    $noAutolink = TWiki::Func::getPreferencesFlag('NOAUTOLINK');

    my $upperAlphaRegex = TWiki::Func::getRegularExpression('upperAlpha');
    my $lowerAlphaRegex = TWiki::Func::getRegularExpression('lowerAlpha');
    my $numericRegex = TWiki::Func::getRegularExpression('numeric');
    $singleMixedAlphaNumRegex = qr/[$upperAlphaRegex$lowerAlphaRegex$numericRegex]/;

    # Plugin correctly initialized
    return 1;
}

sub handle {
    return unless _lazyInit();

    if ( $noAutolink ) {
        _debug('NOAUTOLINK set');
        return;
    }

    unless (scalar(@webList)) {
        _debug('no webs');
        # no point if there are no webs to search
        return;
    }

    # Find instances of WikiWords not in this web, but in the otherWeb(s)
    # If the WikiWord is found in theWeb, put the word back unchanged
    # If the WikiWord is found in the otherWeb, link to it via [[otherWeb.WikiWord]]
    # If it isn't found there either, put the word back unchnaged

    my $removed = {};
    my $text = takeOutBlocks( $_[0], 'noautolink', $removed );

    # Match 
    # 0) (Allowed preambles: "\s" and "(")
    # 1) [[something]] - (including [[something][something]], but non-greedy),
    # 2) WikiWordAsWebName.WikiWord,
    # 3) WikiWords, and 
    # 4) WIK IWO RDS
    %linkedWords = ();
    $text =~ s/(\[\[.*?\]\]|(?:^|(?<=[\s\(,]))(?:$webNameRegex\.)?(?:$wikiWordRegex|$abbrevRegex))/findTopicElsewhere($_[1],$1)/geo;

    putBackBlocks( \$text, $removed, 'noautolink' );

    $_[0] = $text;
}

sub makeTopicLink {
    ##my($otherWeb, $theTopic) = @_;
    return "[[$_[0].$_[1]][$_[0]]]";
}

sub findTopicElsewhere {
    # This was copied and pruned from TWiki::internalLink
    my( $theWeb, $theTopic ) = @_;
    my $original = $theTopic;
    my $linkText = $theTopic;
    my $nonForcedAcronym = 0;

    if ($theTopic =~ /^\[\[($webNameRegex)\.($wikiWordRegex)\](?:\[(.*)\])?\]$/o) {
        if ($redirectable && $1 eq $theWeb) {
            # The topic is *supposed* to be in this web, but the web is
            # redirectable so we can ignore the web specifier
            # remove the web name and continue
            $theTopic = $2;
            $linkText = $3 || $theTopic;
        } else {
            # The topic is an explicit link to another web
            return $theTopic;
        }
    } elsif ($theTopic =~ /^\[\[($wikiWordRegex)\](?:\[(.*)\])?\]$/o) {
            # No web specifier, look elsewhere
            $theTopic = $1;
            $linkText = $2 || $theTopic;
    } elsif ($theTopic =~ /^\[\[($abbrevRegex)\](?:\[(.*)\])?\]$/o) {
            # No web specifier, look elsewhere
            $theTopic = $1;
            $linkText = $2 || $theTopic;
    } elsif ($theTopic =~ /^$abbrevRegex$/o) {
            $nonForcedAcronym = 1;
    } elsif ($theTopic =~ /^($webNameRegex)\.($wikiWordRegex)$/o) {
        if ($redirectable && $1 eq $theWeb) {
            $linkText = $theTopic = $2;
        } else {
            return $theTopic;
        }
    }

    if ( $nonForcedAcronym ) {
      return $theTopic if $findAcronyms eq "none";
      return $linkedWords{$theTopic} if ( $findAcronyms eq "all" && $linkedWords{$theTopic} );
      return $theTopic if ( $findAcronyms eq "first" && $linkedWords{$theTopic} );
    }

    # Turn spaced-out names into WikiWords - upper case first letter of
    # whole link, and first of each word.
    $theTopic =~ s/^(.)/\U$1/o;
    $theTopic =~ s/\s($singleMixedAlphaNumRegex)/\U$1/go;
    $theTopic =~ s/\[\[($singleMixedAlphaNumRegex)(.*)\]\]/\u$1$2/o;

    # Look in the current web, return if found
    my $exist = TWiki::Func::topicExists( $theWeb, $theTopic );

    if( ! $exist ) {
        if( !$disablePluralToSingular && $theTopic =~ /s$/ ) {
            my $theTopicSingular = makeSingular( $theTopic );
            if( TWiki::Func::topicExists( $theWeb, $theTopicSingular ) ) {
                _debug("$theTopicSingular was found in $theWeb" );
                return $original; # leave it as we found it
            }
        }
    } else {
        _debug("$theTopic was found in $theWeb: $linkText" );
        return $original; # leave it as we found it
    }

    # Look in the other webs, return when found
    my @topicLinks;
    
    foreach ( @webList ) {
        my $otherWeb = $_;

        # For systems running WebNameAsWikiName
        # If the $theTopic is a reference to a the name of 
        # otherWeb, point at otherWeb.WebHome - MRJC
        if ($otherWeb eq $theTopic) {
            _debug("$theTopic is the name of another web $otherWeb.");
            return "[[$otherWeb.WebHome][$otherWeb]]";
        }

        my $exist = TWiki::Func::topicExists( $otherWeb, $theTopic );
        if( ! $exist ) {
            if( !$disablePluralToSingular && $theTopic =~ /s$/ ) {
                my $theTopicSingular = makeSingular( $theTopic );
                if( TWiki::Func::topicExists( $otherWeb, $theTopicSingular ) ) {
                    _debug("$theTopicSingular was found in $otherWeb");
                    push(@topicLinks, makeTopicLink($otherWeb, $theTopic));
                }
            }
        }
        else  {
            _debug("$theTopic was found in $otherWeb");
            push(@topicLinks, makeTopicLink($otherWeb,$theTopic));
        }
    }

    if (scalar(@topicLinks) > 0) {
        if (scalar(@topicLinks) == 1) {
            # Topic found in one place
            # If link text [[was in this form]], free it
            $linkText =~ s/\[\[(.*)\]\]/$1/o;

            # Link to topic
            $topicLinks[0] =~ s/(\[\[.*?\]\[)(.*?)(\]\])/$1$linkText$3/o;
            $linkedWords{$theTopic} = $topicLinks[0];
            return $topicLinks[0];
        } else {
            # topic found in several places
            # If link text [[was in this form]] <em> it
            $linkText =~ s/\[\[(.*)\]\]/<em>$1<\/em>/go;

            # If $linkText is a WikiWord, prepend with <nop>
            # (prevent double links)
            $linkText =~ s/($wikiWordRegex)/<nop\/>$1/go;
            my $renderedLink = "$linkText<sup>(".join(",", @topicLinks ).")</sup>";
            $linkedWords{$theTopic} = $renderedLink;
            return $renderedLink;
        }
    }
    return $linkText;
}

sub makeSingular  {
    my ($theWord) = @_;

    $theWord =~ s/ies$/y/o;       # plurals like policy / policies
    $theWord =~ s/sses$/ss/o;     # plurals like address / addresses
    $theWord =~ s/([Xx])es$/$1/o; # plurals like box / boxes
    $theWord =~ s/([A-Za-rt-z])s$/$1/o; # others, excluding ending ss like address(es)
    return $theWord;
}

my $placeholderMarker = 0;

sub takeOutBlocks {
    my( $intext, $tag, $map ) = @_;

    return $intext unless( $intext =~ m/<$tag\b/i );

    my $out = '';
    my $depth = 0;
    my $scoop;
    my $tagParams;

    foreach my $token ( split/(<\/?$tag[^>]*>)/i, $intext ) {
    	if ($token =~ /<$tag\b([^>]*)?>/i) {
    		$depth++;
    		if ($depth eq 1) {
    			$tagParams = $1;
    			next;
    		}
    	} elsif ($token =~ /<\/$tag>/i) {
            if ($depth > 0) {
                $depth--;
                if ($depth eq 0) {
                    my $placeholder = $tag.$placeholderMarker;
                    $placeholderMarker++;
                    $map->{$placeholder}{text} = $scoop;
                    $map->{$placeholder}{params} = $tagParams;
                    $out .= '<!--'.$TWiki::TranslationToken.$placeholder.
                      $TWiki::TranslationToken.'-->';
                    $scoop = '';
                    next;
                }
            }
    	}
    	if ($depth > 0) {
    		$scoop .= $token;
    	} else {
    		$out .= $token;
    	}
    }

	# unmatched tags
	if (defined($scoop) && ($scoop ne '')) {
		my $placeholder = $tag.$placeholderMarker;
		$placeholderMarker++;
		$map->{$placeholder}{text} = $scoop;
		$map->{$placeholder}{params} = $tagParams;
		$out .= '<!--'.$TWiki::TranslationToken.$placeholder.
          $TWiki::TranslationToken.'-->';
	}

    return $out;
}

sub putBackBlocks {
    my( $text, $map, $tag, $newtag, $callback ) = @_;

    $newtag = $tag if (!defined($newtag));

    foreach my $placeholder ( keys %$map ) {
        if( $placeholder =~ /^$tag\d+$/ ) {
            my $params = $map->{$placeholder}{params} || '';
            my $val = $map->{$placeholder}{text};
            $val = &$callback( $val ) if ( defined( $callback ));
            if ($newtag eq '') {
            	$$text =~ s(<!--$TWiki::TranslationToken$placeholder$TWiki::TranslationToken-->)($val);
            } else {
            	$$text =~ s(<!--$TWiki::TranslationToken$placeholder$TWiki::TranslationToken-->)
                  (<$newtag$params>$val</$newtag>);
            }
            delete( $map->{$placeholder} );
        }
    }
}

1;
