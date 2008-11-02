# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005-2006 Michael Daum <micha@nats.informatik.uni-hamburg.de>
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

###############################################################################
package TWiki::Plugins::VotePlugin::Core;

###############################################################################
use vars qw($debug $isInitialized $pubUrlPath);

use strict;
use Digest::MD5 qw(md5_base64);
use Fcntl qw(:flock);
use CGI;

$debug = 0; # toggle me

###############################################################################
sub handleVote {
    my ($session, $params, $topic, $web) = @_;

    $web = TWiki::Func::expandCommonVariables('%BASEWEB%');
    $topic = TWiki::Func::expandCommonVariables('%BASETOPIC%');

    unless ($pubUrlPath) {
        $pubUrlPath = TWiki::Func::getPubUrlPath().'/'.TWiki::Func::getTwikiWebname().'/VotePlugin';
    }

    my $defaults = TWiki::Func::getPreferencesValue('VOTEPLUGIN_DEFAULTS')
      || '';

    while ($defaults =~ s/^\s*(\w+)=\"(.*?)\"//) {
        $params->{$1} = $2 unless defined $params->{$1};
    }

    my $id =       defined($params->{id}) ? $params->{id} : '_default';
    my $isGlobal = isTrue($params->{global}, 0);
    my $isOpen =   isTrue($params->{open}, 1);
    my $isSecret = isTrue($params->{secret}, 1);
    my $bayesian = isTrue($params->{bayesian}, 0);
    my $submit =   isTrue($params->{submit}, 1);
    my $saveto =   $params->{saveto};
    my $canReset = canReset($id);

    my @prompts = ();

    my $defaultStarsFormat =
      '| $key$reset | $small<div class="star-info">Score: $score, My vote: $mylast, Total votes: $sum</div> |';
    my $defaultSelectFormat =  '| $key$reset | $prompt | $bars |';
    my $defaultChartFormat = '<div>$bar(300) $option $perc% ($score)</div>';

    if (defined($params->{style})) {
        # Compatibility
        my $format = '';
        if ($params->{style} =~ /perc/) {
            $format .= '$perc% ';
        }
        if ($params->{style} =~ /total/) {
            $format .= '($freq)';
        }
        if ($params->{style} =~ /sum/) {
            $format .= '$sum votes';
        }
        $defaultSelectFormat = $format;
    }
    my $separator = $params->{separator};

    $separator = "\n" unless defined $separator;

    # Compatibility
    if (defined($params->{select})) {
        push(@prompts, {
            type => 'select',
            name => expandFormattingTokens($params->{select}),
            format => $defaultSelectFormat,
            options =>
              [ map { expandFormattingTokens($_) }
                  split(/\s*,\s*/, $params->{options} || '') ]});
    }

    my $n = 1;
    while (1) {
        if (defined($params->{"select$n"})) {
            push(@prompts, {
                type => 'select',
                name => expandFormattingTokens($params->{"select$n"}),
                format => $params->{"format$n"} || $defaultSelectFormat,
                chart => $params->{"chart$n"} || $defaultChartFormat,
                options =>
                  [ map { expandFormattingTokens($_) }
                      split(/\s*,\s*/, $params->{"options$n"} || '') ]});
        } elsif (defined($params->{"stars$n"})) {
            unless (($params->{"width$n"} || 5) =~ /^\d+$/) {
                return inlineError("Expected integer width for stars$n=");
            }
            push(@prompts, {
                type => 'stars',
                name => $params->{"stars$n"},
                format => $params->{"format$n"} || $defaultStarsFormat,
                width => $params->{"width$n"} || 5 });
        } else {
            last;
        }
        $n++;
    }

    # check attributes
    if (!scalar(@prompts)) {
        return inlineError("no prompts specified ".$params->stringify());
    }

    my $mess;
    if ($canReset) {
        my $query = TWiki::Func::getCgiQuery();
        if (defined $query->param('Reset'.$id)) {
            clearVotesData($web, $topic, $id, $isGlobal, $saveto);
            $mess = "$id has been reset";
        }
    }

    # read in the votes
    my $lines = getVoteData($web, $topic, $id, $isGlobal, $saveto);
    my %votes;

    my %lastVote;
    foreach my $line (split/\r?\n/, $lines) {
        if ($line =~ /^\|(.*)\|$/) {
            my @data = split(/\|/, $1);
            my $vid = $data[0];
            my $voter = $data[1];
            my $weight = $data[2];
            my $date = (scalar(@data) > 4) ? $data[4] : '';

            foreach my $item (split(/,/, $data[3] || '')) {
                if ($item =~ /^(.+)=(.+)$/) {
                    my ($row, $choice) = ($1, $2);
                    $votes{$voter}{$vid}{$row} = [ $choice, $weight, $date ];
                }
            }
        } elsif (!$saveto && $line =~ /^([^\|]+)\|([^\|]+)\|(.*?)\|(.+)$/) {
            # Old format - compatibility only
            my $date = $1;
            my $voter = $2;
            my $weight = $3;
            my $data = $4;
            foreach my $item (split(/\|/, $data)) {
                if ($item =~ /^(.+)=(.+)$/) {
                    my ($row, $choice) = ($1, $2);
                    $votes{$voter}{$id}{$row} = [ $choice, $weight, $date ];
                }
            }
        }
    }

    # Terminology:
    # An =id= is the identifier of a %VOTE
    # A =key= is the identifier of a vote row e.g. stars="" or select=""
    # A =choice= is the identified of one of the options in a key

    # collect statistics. This is complicated by the fact that we
    # have top level keys (represented by $key) which can receive
    # a rating for lines of stars, and also individual values in a
    # select, each of which has its own frequency. For the purposes
    # of this analysis, a line of stars is treated as having a single
    # leaf value, so the frequency of that value should be the same as the
    # total number of votes for the key.
    my %keyValueFreq; # frequency of a specific value for a given key
    my %totalVotes;   # total votes for a given key
    my %totalVoters;  # how many different people voted for each key
    my %totalRate;    # Total of all ratings for each key
    my %items;        # Hash of id's that have the same key
    my $voteSum = 0;  # Sum of the number of votes on all rated items
    my $rateSum = 0;  # Sum of all ratings of rated items
    foreach my $voter (keys %votes) {
        foreach my $vid (keys %{$votes{$voter}}) {
            foreach my $key (keys %{$votes{$voter}{$vid}}) {
                my $choice = $votes{$voter}{$vid}{$key}->[0];
                my $weight = $votes{$voter}{$vid}{$key}->[1];
                $keyValueFreq{$vid}{$key}{$choice} += $weight;
                $totalVotes{$key} += $weight;
                $items{$key}{$vid} = 1;
                $voteSum += $weight;
                if ($choice =~ /^[\d.]+$/) {
                    $totalRate{$key} += $choice * $weight;
                    $rateSum += $choice * $weight;
                }
                $totalVoters{$key}++;
            }
        }
    }

    my $act;
    if ($isOpen) {
        $act = TWiki::Func::getScriptUrl($web, $topic, 'view');
    } else {
        $act = TWiki::Func::getScriptUrl($web, $topic, 'viewauth');
    }

    # Additional hidden parameters that accompany the form submission
    my %hidden = (
        vote_register => $id,
        vote_isGlobal => $isGlobal,
        vote_isSecret => $isSecret,
        vote_isOpen => $isOpen,
        vote_saveTo => $saveto,
        vote_inTopic => "$web.$topic",
       );

    # Do we need a submit button?
    my $needSubmit = scalar(@prompts) > 1;

    my @rows;
    foreach my $prompt (@prompts) {
        my $key = $prompt->{name};
        my $row;

        if ($prompt->{type} eq 'stars') {
            my $numItems = scalar(keys(%{$items{$key}}));

            # avg_num_votes: The average number of votes of all items that have
            # num_votes>0
            # avg_rating: The average rating of each item (again, of those that
            # have num_votes>0)
            my $avg_num_votes = $numItems ? $voteSum / $numItems : 0;
            my $avg_rating = $voteSum ? $rateSum / $voteSum : 0;
            my $myLastVote =
              $votes{getIdent($isSecret, $isOpen)}{$id}{$key}->[0] || 0;
            my $mean = 0;
            if ($totalVotes{$key}) {
                $mean = $totalRate{$key} / $totalVotes{$key};
                if ($bayesian) {
                    $mean = ($avg_num_votes * $avg_rating +
                               $totalVotes{$key} * $mean) /
                                 ($avg_num_votes + $totalVotes{$key});
                }
            }
            push(@rows, showLineOfStars(
                $id, $prompt, $submit, $needSubmit, $act,
                $mean, $myLastVote, $totalVoters{$key} || 0));
        }
        else {
            my $opts = CGI::option({selected=>'selected',
                                    value=>''}, 'Select ...');

            foreach my $optionName (@{$prompt->{options}}) {
                $opts .= CGI::option($optionName);
            }
            my $o = { name => 'vote_data_'.$key, size => 1 };
            unless ($needSubmit) {
                $o->{onchange} = 'javascript: submit()';
            }
            my $select = $submit ? CGI::Select($o, $opts) : '';

            push(@rows, showSelect(
                $id, $prompt, $submit, $select, $keyValueFreq{$id}{$key},
                $totalVotes{$id}{$key}, $params));
        }
    }

    my $result = join($separator, @rows);
    if ($submit) {
        my $hiddens = '';
        while (my ($k, $v) = each %hidden) {
            $hiddens .= CGI::input(
                { type => 'hidden', name => $k, value => $v });
        }
        # Don't use CGI::form because it generates TML-busting newlines
        my $form = CGI::start_form(-id => $id, -action => $act,
                                  -method => 'post');
        $form =~ s/\r?\n//g; # CGI::start_form adds unwanted \n's
        $result = $form.$hiddens.$separator.$result;
        if ($needSubmit) {
            $result .= $separator.CGI::submit(
                { name=> 'OK', value=>'OK',
                  style=>'color:green'});
        }
        $result .= $separator.CGI::end_form();
    }

    if ($canReset) {
        if ($mess) {
            $mess = CGI::span({class => 'twikiAlert'}, $mess);
        } else {
            $mess = CGI::start_form(-name => 'resetForm',
                                    -action => '');
            $mess =~ s/\r?\n//g; # CGI::start_form adds unwanted \n's
            $mess .= CGI::submit({ name => 'Reset'.$id, value=>'Reset'})
              . CGI::end_form();
        }
        $result =~ s/\$reset/ $mess /g;
    } else {
        $result =~ s/\$reset//g;
    }

    # Render tables and remove newlines
    # so we can embed votes in TWiki tables
    $result = TWiki::Func::renderText($result);
    $result =~ s/\n//g;
    return $result;
}

###############################################################################
# Check if the current user can reset a vote, and if they can, return a
# button that does it
sub canReset {
    my $id = shift;

    my $controls = TWiki::Func::getPreferencesValue('VOTEPLUGIN_RESETTERS');
    return '' unless (defined $controls);
    foreach my $control (split(/\s*;\s*/, $controls)) {
        next unless $control =~ /^\s*(\w+)\s*\((.*)\)\s*$/;
        my ($who, $whats) = ($1, $2);
        next unless $who eq TWiki::Func::getWikiName();
        foreach my $ide (split(/\s*,\s*/, $whats)) {
            $ide = quotemeta($ide);
            $ide =~ s/\\\*/.*/g;
            $ide =~ s/\\\?/./g;
            if ($id =~ /^$ide$/) {
                return 1;
            }
        }
    }
    return 0;
}

###############################################################################
sub registerVote {
    #print STDERR "called registerVote()\n";

    # check parameters
    my $query = TWiki::Func::getCgiQuery();
    my $id = $query->param('vote_register');

    return unless defined $id;

    my $web;
    my $topic = $query->param('vote_inTopic');
    ($web, $topic) = TWiki::Func::normalizeWebTopicName('', $topic);
    my $user = TWiki::Func::getWikiUserName();
    my $isSecret = $query->param('vote_isSecret') || 0;

    my $isOpen = $query->param('vote_isOpen') || 0;
    my $ident = getIdent($isSecret, $isOpen);
#    $ident = int(rand(100)) 
#      if $debug; # for testing

    # Apply a weighting for the voting user
    my $weightsTopic = TWiki::Func::getPreferencesValue(
        'VOTEPLUGIN_WEIGHTINGS');
    my $weight = 1;
    if ($weightsTopic) {
        my ($wweb, $wtopic) = TWiki::Func::normalizeWebTopicName(
            $web, $weightsTopic);
        if (TWiki::Func::topicExists($wweb, $wtopic)) {
            my ($meta, $text) = TWiki::Func::readTopic($wweb, $wtopic);
            foreach my $line (split(/\n/, $text)) {
                if ($line =~ /^\|\s*(\S+)\s*\|\s*(\d+)\s*\|$/) {
                    ($wweb, $wtopic) =  TWiki::Func::normalizeWebTopicName(
                        undef, $1);
                    if ($user eq "$wweb.$wtopic") {
                        $weight = $2 / 100.0;
                    }
                }
            }
        }
    }

    # write the votes
    my $voteData = "|$id|$ident|$weight|";
    my @v;
    foreach my $key ($query->param()) {
        my $val = $query->param($key);
        next unless $key =~ s/^vote_data_//;
        push @v, "$key=$val";
    }
    $voteData .= join(',', @v) . '|' . _getLocalDate() . "|\n";

    saveVotesData($web, $topic, $id,  $query->param('vote_isGlobal') || 0,
                  $query->param('vote_saveTo') || '', $voteData);
    # invalidate cache entry
    if (defined &TWiki::Cache::invalidateEntry) {
        TWiki::Cache::invalidateEntry($web, $topic);
    }
}

sub saveVotesData {
    my ($web, $topic, $id, $isGlobal, $saveto, $voteData) = @_;
    if ($saveto) {
        my $text = '';
	my $meta = '';
        $saveto =~ /(.*)/;
        my ($vw, $vt) = TWiki::Func::normalizeWebTopicName($web, $1);
        if (TWiki::Func::topicExists($vw, $vt)) {
            ( $meta, $text ) = TWiki::Func::readTopic( $vw, $vt );
        }
	$text .= $voteData;
        TWiki::Func::saveTopic($vw, $vt, $meta, $text, { minor => 1} );
    } else {
        my $votesFile = getVotesFile($web, $topic, $id, $isGlobal);
        # open and lock the votes
        open(VOTES, ">>$votesFile") || die "cannot append $votesFile";
        flock(VOTES, LOCK_EX); # wait for exclusive rights
        seek(VOTES, 0, 2); # seek EOF in case someone else appended
        # stuff while we were waiting
        print VOTES $voteData;
        # unlock and close
        flock(VOTES, LOCK_UN);
        close VOTES;
    }
}

sub clearVotesData {
    my ($web, $topic, $id, $isGlobal, $saveto) = @_;
    if ($saveto) {
        my $text = '';
	my $meta = '';
        $saveto =~ /(.*)/;
        my ($vw, $vt) = TWiki::Func::normalizeWebTopicName($web, $1);
        if (TWiki::Func::topicExists($vw, $vt)) {
            ( $meta, $text ) = TWiki::Func::readTopic( $vw, $vt );
        }
        $text =~ s/(^|\n)((\|.*\||\s+)\n+)*$/$1/s;
        TWiki::Func::saveTopicText($vw, $vt, $meta, $text, { minor => 1} );
    } else {
        my $votesFile = getVotesFile($web, $topic, $id, $isGlobal);
        unlink($votesFile) || die "cannot remove $votesFile: $!";
    }
}

sub getVoteData {
    my ($web, $topic, $id, $isGlobal, $saveto) = @_;

    my $lines = '';
    if ($saveto) {
        my ($vw, $vt) = TWiki::Func::normalizeWebTopicName($web, $saveto);
        if (TWiki::Func::topicExists($vw, $vt)) {
            my $meta;
            ( $meta, $lines ) = TWiki::Func::readTopic( $vw, $vt );
        }
    } else {
        my $votesFile = getVotesFile($web, $topic, $id, $isGlobal);
        if (open(F, "<$votesFile")) {
            local $/ = undef;
            $lines = <F>;
            close(F);
        }
    }
    return $lines;
}


###############################################################################
sub getVotesFile {
    my ($web, $topic, $id, $global) = @_;

    my $path = TWiki::Func::getWorkArea('VotePlugin');
    my $flatweb = $web;
    $flatweb =~ s/\//./g;
    my $votesFile = $path.'/'.
      ($global ? '' : "${flatweb}_${topic}_").
        ($id ? "_$id" : '');
    $votesFile = normalizeFileName($votesFile);

    if (! -e $votesFile) {
        my $attachPath = TWiki::Func::getPubDir()."/$web/$topic";
        my $oldVotesFile = "$attachPath/_Votes" . ($id?"_$id":"") . ".txt";

        if (!-e $oldVotesFile ) {
            $oldVotesFile = "$attachPath/Votes" . ($id?"_$id":"") . ".txt";
        }

        if (open(F, "<$oldVotesFile") && open(G, ">$votesFile")) {
            local $/;
            print G <F>;
            close(G); close(F);
            unlink $oldVotesFile;
        }
    }

    return $votesFile;
}

###############################################################################
# wrapper
sub normalizeFileName {
    my $fileName = shift;

    if (defined &TWiki::Sandbox::normalizeFileName) {
        return TWiki::Sandbox::normalizeFileName($fileName);
    }

    if (defined &TWiki::normalizeFileName) {
        return TWiki::normalizeFileName($fileName)
    }

    TWiki::Func::writeWarning("normalizeFileName not found ... you live dangerous");
    return $fileName;
}


###############################################################################
sub _getLocalDate {
    my( $sec, $min, $hour, $mday, $mon, $year) = localtime(time());
    $year = sprintf("%.4u", $year + 1900);  # Y2K fix
    my $date = sprintf("%.2u-%.2u-%.2u", $year, $mon, $mday);
    return $date;
}

###############################################################################
sub inlineError {
    return '<span class="twikiAlert">Error: '.$_[0].'</span>';
}

###############################################################################
sub expandFormattingTokens {
    my $text = shift;
    $text =~ s/\$quote/\'/go;# Compatibility

    return $text;
    if( defined( &TWiki::Func::decodeFormatTokens )) {
        $text = TWiki::Func::decodeFormatTokens( $text );
    } else {
        $text =~ s/\$n\(\)/\n/gs;
        $text =~ s/\$n\b/\n$1/gs;
        $text =~ s/\$nop(\(\))?//gs;
        $text =~ s/\$quot(\(\))?/\"/gs;
        $text =~ s/\$percnt(\(\))?/\%/gs;
        $text =~ s/\$dollar(\(\))?/\$/gs;
    }
    $text =~ s/\$doublequote?/\"/gs;
    return $text;
}

###############################################################################
sub getIdent {
    my ($isSecret, $isOpen) = @_;

    my $user = TWiki::Func::getWikiUserName();

    my $ident;

    if ($isOpen) {
        my $date = _getLocalDate();
        $ident = ($ENV{REMOTE_ADDR}||'').",$user,$date";
    } else {
        $ident = $user;
    }

    if ($isSecret) {
        return md5_base64($ident);
    } else {
        return $ident;
    }
}

###############################################################################
sub showSelect {
    my ($id, $prompt, $submit, $select, $keyValueFreq, $totalVotes, $params) = @_;

    my $key = $prompt->{name};
    my $totty = $totalVotes || 0;
    my $row = $prompt->{format};
    $row =~ s/\$key/$key/g;
    $row =~ s/\$prompt/$select/g;
    $row =~ s/\$sum/$totty/;
    my $bars = '';
    foreach my $value (sort {$keyValueFreq->{$b} <=>
                               $keyValueFreq->{$a}}
                         keys %{$keyValueFreq}) {
        my $score = $keyValueFreq->{$value} || 0;

        my $perc = $totty ? int(1000 * $score / $totty) / 10 : 0;
        my $bar = expandFormattingTokens($prompt->{chart});
        $bar =~ s/\$option/$value/;
        $bar =~ s/\$perc/$perc/g;
        $bar =~ s/\$score/$score/g;
        $bar =~ s/\$bar(\((\d+)\))?/_makeBar($2, $perc, $params)/ge;
        $bars .= $bar;
    }
    $row =~ s/\$bars/$bars/g;
    return $row;
}

sub _makeBar {
    my ($width, $perc, $params) = @_;
    $width = $width || $params->{width} || 300;
    my $graph = CGI::img(
        { src=>$pubUrlPath.'/leftbar.gif',
          alt=>'leftbar',
          height=>14});
    $graph .= CGI::img(
        { src => $pubUrlPath.'/mainbar.gif',
          alt => 'mainbar',
          height => 14,
          width => $width / 100 * $perc });
    $graph .= CGI::img(
        { src=>$pubUrlPath.'/rightbar.gif',
          alt => 'rightbar',
          #width => $width - $width / 100 * $perc,
          height => 14});
    return $graph;
}

###############################################################################
sub showLineOfStars {
    my ($form, $prompt, $submit, $needSubmit, $act,
        $mean, $myLast, $total) = @_;
    my $max = $prompt->{width};
    my $perc = $total ? int(1000 * $mean / $total) / 10 : 0;

    $mean = sprintf("%.3g", $mean);
    my $row = expandFormattingTokens($prompt->{format});
    $row =~ s/\$key/$prompt->{name}/g;
    $row =~ s/\$sum/$total/g;
    $row =~ s/\$score/$mean/g;
    $row =~ s/\$perc/$perc/g;
    $row =~ s/\$mylast/$myLast/g;
    require TWiki::Contrib::RatingContrib;
    my $eAttrs = {};
    if ($submit && !$needSubmit) {
        $eAttrs = {
            onChange =>
              "javascript: document.getElementById('$form').submit()" };
    }
    my $ul = TWiki::Contrib::RatingContrib::renderRating(
        'vote_data_'.$prompt->{name}, $max, ($row =~ /\$small/) ? 1 : 0,
        $mean, $eAttrs);

    $row =~ s/\$(small|large)/$ul/g;

    return $row;
}

sub isTrue {
    my( $value, $default ) = @_;

    $default ||= 0;

    return $default unless defined( $value );

    $value =~ s/^\s*(.*?)\s*$/$1/gi;
    $value =~ s/off//gi;
    $value =~ s/no//gi;
    $value =~ s/false//gi;
    return ( $value ) ? 1 : 0;
}

1;

