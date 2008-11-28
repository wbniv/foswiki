# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008 SvenDowideit@home.org.au
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
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
#
# As per the GPL, removal of this notice is prohibited.

package TWiki::Store::SearchAlgorithms::Kino;

use strict;

use TWiki::Contrib::SearchEngineKinoSearchAddOn::Search;

=pod

---+ package TWiki::Store::SearchAlgorithms::Kino

use KinoSearch to speed up SEARCH

---++ search($searchString, $topics, $options, $sDir) -> \%seen
Search .txt files in $dir for $searchString. See RcsFile::searchInWebContent
for details.

=cut

sub search {
    my ( $searchString, $topics, $options, $sDir, $sandbox, $web ) = @_;

#TODO: MASSIVE LIMITATION: as the current KinoSearch does not support wildcards, it can't really
# be used for partial matches on anything.

    #just a bit experimental
    my $showAttachments = $TWiki::cfg{SearchEngineKinoSearchAddOn}{showAttachments} || 0;


    my $scope = $options->{scope} || 'text';
#print STDERR "search : type=$options->{type}, scope=$scope ($searchString) (".scalar(@$topics).")\n";

    my $searcher =
      TWiki::Contrib::SearchEngineKinoSearchAddOn::Search->newSearch();

    if ( $options->{type} eq 'regex' ) {

        #there are a few regex's we could try to optimise..
        #like '.*' which is bizzarly used in WebChanges etc
        if (   ( $searchString eq '.*' )
            || ( $searchString eq '\.*' ) )
        {
            $options->{type} = 'text';
            $searchString = "web:$web";    #i hope it optimises out
        }
        elsif ( $searchString =~ /^(\s\w)*$/ ) {    #not actually a regex..
            $options->{type} = 'text';
            $searchString = "\"$searchString\"";
            if ( scalar(@$topics) > 0 ) {
                $searchString .=
                  " AND (" . join( ' OR ', map { "topic:$_" } @$topics ) . ')';
            }
        }
    }

    my $scopePrefix = '';
    if ( $scope eq 'all' ) {
	$scopePrefix = '';
    } elsif ( $scope eq 'attachments' ) {
	#damnit, TWiki::Search excludes this
	#$searchAttachments = " AND (attachment:yes)"
	$showAttachments = 1;
    } elsif ( $scope eq 'topic' ) {
	$scopePrefix = 'topic:';
    } elsif ( $scope eq 'text' ) {
	#$scopePrefix = 'bodytext:';
    }

    my $search = $searchString;
    if ( $options->{type} eq 'text' ) {
        $search = $scopePrefix.$search;
    } elsif ( $options->{type} eq 'keyword' ) {
        $search = $scopePrefix.$search;
    } elsif ( $options->{type} eq 'literal' ) {
        $search = $scopePrefix.'"'.$search.'"';
    }
    elsif ( $options->{type} eq 'all' ) {
	#'all' can't really work well with pluggable search options from this point in the code
	#the 'agregation needs to happen in TWiki::Search
	#TODO: need to separate out free form strings and other terms - the terms (including web: don't work so well inside topic:
    }
    else {

#TODO: can optimise by breaking up the regex, kino searching on any static text, and then
#using that reduced topic set.

        #TODO: make configurable so that we use Forking if selected..

        #wimp out, and use what works.
        use TWiki::Store::SearchAlgorithms::Forking;
        return TWiki::Store::SearchAlgorithms::Forking::search( $searchString,
            $topics, $options, $sDir, $sandbox, $web );
    }

    #actually need to just do _this_ Store's web.
    $search = $searcher->searchStringForWebs( $search, $web );

#print STDERR "Kino: $search\n";

    #do the search.
    my $docs = $searcher->docsForQuery($search);

    my $ntopics = 0;

    my %seen;
    
    # output the list of hits
    while ( my $hit = $docs->fetch_hit_hashref ) {
        my $resweb   = $hit->{web};
        my $restopic = $hit->{topic};

     # For partial name search of topics, just hold the first part of the string
        if ( $restopic =~ m/(\w+)/ ) { $restopic =~ s/ .*//; }

        # topics moved away maybe are still indexed on old web
        #next unless &TWiki::Func::topicExists( $resweb, $restopic );

        # read topic
        #my( $meta, $text ) = TWiki::Func::readTopic( $resweb, $restopic );
        # Why these changes to the text?
        #$text =~ s/%WEB%/$resweb/gos;
        #$text =~ s/%TOPIC%/$restopic/gos;
        #my $text;

     # Check that the topic can be viewed. (iirc this is done in TWiki::Search.)
     #	    if (! $self->topicAllowed($restopic, $resweb,  $text, $remoteUser)) {
     #	        next;
     #	    }

	if ($hit->{attachment}) {
	    if (($showAttachments) &&
                ( $scope eq 'all' ) ){
		my $name = $hit->{name};
		my $url = " %PUBURL%/$resweb/$restopic/$name ";
#print STDERR "$resweb.$restopic - $name\n";
		push( @{ $seen{$url} }, $url );
	    }
	} else {
	    #assume its a topic.
#print STDERR "$resweb.$restopic\n";
            push( @{ $seen{"$restopic"} }, $hit->{excerpt} );
	}
    }

    return \%seen;
}

1;
