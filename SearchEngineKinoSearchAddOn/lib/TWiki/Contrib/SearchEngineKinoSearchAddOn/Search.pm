#!/usr/bin/perl -wT
#
# Copyright (C) 2007 Markus Hesse
#
# For licensing info read LICENSE file in the TWiki root.
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
# Set library paths in @INC, at compile time

package TWiki::Contrib::SearchEngineKinoSearchAddOn::Search;
use base TWiki::Contrib::SearchEngineKinoSearchAddOn::KinoSearch;

use KinoSearch::Searcher;
use KinoSearch::Analysis::PolyAnalyzer;
use KinoSearch::QueryParser::QueryParser;

# New instance to search the index
# QS
sub newSearch {
    my $self = shift;
    return $self->new("search")
}


sub searchCgi {
  my $session = shift;

  $TWiki::Plugins::SESSION = $session;
  my $searcher = TWiki::Contrib::SearchEngineKinoSearchAddOn::Search->newSearch();
  my $text = $searcher->search(0, $session);

  $session->writeCompletePage($text, 'view');
}

# Method to do the search.
# NOTE: The parameter $session is normally undef. I use it only for testing 
# withing unit tests.
sub search {
    my ($self, $debug, $session) = (@_);
    
    $self->{Debug}   = $debug;
    $session ||= $TWiki::Plugins::SESSION;
    
    # write log entry - should be used throughout this script
    $debug && TWiki::Func::writeDebug( "kinosearch starting..." );
    my $query = TWiki::Func::getCgiQuery();

    # getting the web, the topic and the user from the SESSION object
    my $webName    = $session->{webName};
    my $topicName  = $session->{topicName};
    my $remoteUser = $session->{user}||"TWikiGuest";
    my $websStr = $query->param('web') || '';
    my $limit   = $self->limit($query);

    $remoteUser = TWiki::Func::userToWikiName($remoteUser);

    # getting some params - all params should be documented in KinoSearch topic
    my $search        = $query->param( "search" )    || "";
    my $nosummary     = $query->param( "nosummary" ) || "";
    my $noheader      = $query->param( "noheader" )  || "";
    my $nototal       = $query->param( "nototal" )   || "";
    my $showlock      = $query->param( "showlock" )  || "";
    my $rss           = $query->param( "rss" )       || "";

    # usersearch will be printed out
    my $usersearch = $search;
    
    # gather result
    my $result = '';

    # some vars
    my $originalSearch = $search;
    my $tempVal = "";
    
    # Google like search, example: soap +wsdl +"web service" -shampoo
    #$search =~ s/[\+\-]\s+//go;      # remove spaces between +/- and text: - shampoo => -shampoo
    #$search =~ s/\+/ and /go;      # substitute + for and
    #$search =~ s/\-/ and not /go; # substitute - for and not
    #$search =~ s/^\sand\s//go;       # if new search starts with and, it should be removed


    $search = $self->searchStringForWebs($search, $websStr);

    # load the template
    if( $rss ){
        $tmpl = TWiki::Func::readTemplate( "kinosearchrss" );
    } else {
        $tmpl = TWiki::Func::readTemplate( "kinosearch" );
    }
    $tmpl =~ s/\%META{.*?}\%//go;  # remove %META{"parent"}%

    # split the template into sections
    my( $tmplHead, $tmplSearch,
        $tmplTable, $tmplNumber, $tmplTail ) = split( /%SPLIT%/, $tmpl );
    $tmplHead   = TWiki::Func::expandCommonVariables( $tmplHead,   $topicName, $webName);
    $tmplSearch = TWiki::Func::expandCommonVariables( $tmplSearch, $topicName, $webName);
    $tmplNumber = TWiki::Func::expandCommonVariables( $tmplNumber, $topicName, $webName);
    $tmplTail   = TWiki::Func::expandCommonVariables( $tmplTail,   $topicName, $webName);

    # do we have all the SPLIT parts?
    if( ! $tmplTail ) {
        $result .= "<html><body>";
        $result .= "<h1>TWiki Installation Error</h1>";
        $result .= "Incorrect format of kinosearch.tmpl (missing %SPLIT% parts)";
        $result .= "</body></html>";
        return;
    }

    # print page heading
    $tmplHead = TWiki::Func::renderText( $tmplHead );
    $tmplHead =~ s|</*nop/*>||goi;   # remove <nop> tags (PTh 06 Nov 2000)
    if( $rss ){
       $tmplHead =~ s|<p />||goi;   # remove <p /> tag
    }
    $result .= $tmplHead;

    # if configured, show only attachments option
    my $searchAttachmentsOnly = TWiki::Func::getPreferencesValue( "KINOSEARCHSEARCHATTACHMENTSONLY" ) || 0;
    # if only attachments are displayed, even if configured, then the message is not shown
    if (($searchAttachmentsOnly)&&($usersearch !~ "attachment:yes")) {
	$tempVal = $usersearch;
	$tempVal =~ s/\+/\%2B/go; # just for the above URL
	$tempVal =~ s/\"/\%22/go; # just for the above URL
	my $attachmentsOnlyLabel = TWiki::Func::getPreferencesValue( "KINOSEARCHATTACHMENTSONLYLABEL" ) || "Show only attachments";
	$tmplSearch =~ s/%SEARCHATTACHMENTSONLY%/<a href="%SCRIPTURLPATH%\/kinosearch\/$webName\/?search=$tempVal\%20\%2Battachment:yes">$attachmentsOnlyLabel<\/a>/go;
	$tmplSearch = TWiki::Func::expandCommonVariables ( $tmplSearch, $topicName, $webName );
    }
    # just for cleaning if the preference isn't set, or already displaying only attachments
    $tmplSearch =~ s/%SEARCHATTACHMENTSONLY%/ /go;

    # TWiki::Func::writeDebug( "tmp: $tmplSearch\n");

    $result .= $self->renderSearchHeader($usersearch, $tmplSearch );

    # prepare for the result list
    my( $beforeText, $repeatText, $afterText ) = split( /%REPEAT%/, $tmplTable );

    if( ! $noheader ) {
       my $bgcolor = TWiki::Func::getPreferencesValue( "WEBBGCOLOR", $webName ) || "#FFFFFF";
       $beforeText =~ s/%WEBBGCOLOR%/$bgcolor/go;
       if ( $webName eq $websStr) {
	   $beforeText =~ s/%WEB%/$webName/go;
       }
       $beforeText =~ s/%WEB%/ /go;
       $beforeText = TWiki::Func::expandCommonVariables( $beforeText, $topicName,  $webName );
       $beforeText = TWiki::Func::renderText( $beforeText, $webName );            
       $beforeText =~ s|</*nop/*>||goi;   # remove <nop> tag                      
       if( $rss ){
       $beforeText =~ s|<p />||goi;   # remove <p /> tag
       }
       $result .= $beforeText;
     }

    my $docs = $self->docsForQuery($search);

    my $ntopics = 0;

    # output the list of hits
    while ( my $hit = $docs->fetch_hit_hashref ) {
	my $resweb   = $hit->{web};
	my $restopic = $hit->{topic};

	# For partial name search of topics, just hold the first part of the string
	if($restopic =~ m/(\w+)/) { $restopic =~ s/ .*//; }
	
	# topics moved away maybe are still indexed on old web
	next unless &TWiki::Func::topicExists( $resweb, $restopic );

	# read topic
	#my( $meta, $text ) = TWiki::Func::readTopic( $resweb, $restopic );
	# Why these changes to the text?
	#$text =~ s/%WEB%/$resweb/gos;
	#$text =~ s/%TOPIC%/$restopic/gos;
	my $text;
	
	# Check thath the topic can be viewed.
	if (! $self->topicAllowed($restopic, $resweb,  $text, $remoteUser)) {
	    next;
	}
    
    my $outString;
    if( $rss ) {
        $outString = $self->renderRssStringFor($hit, $repeatText, $nosummary, $showlock);
    } else {
        $outString = $self->renderHtmlStringFor($hit, $repeatText, $nosummary, $showlock);
    }
	$result .= $outString;
	
	# one more in the bag
	$ntopics += 1;
	# just go for another if limit not reached
	last if $ntopics >= $limit;
    }

    # print footer
    $afterText  = TWiki::Func::expandCommonVariables( $afterText, $topicName, $webName );
    $afterText = TWiki::Func::renderText( $afterText, $webName );
    $afterText =~ s|</*nop/*>||goi;   # remove <nop> tag
    if( $rss ){
        $afterText =~ s|<p />||goi;   # remove <p /> tag
    }
    $result .= $afterText;

    # print "Number of topics:" part
    if( ! $nototal ) {
	my $thisNumber = $tmplNumber;
	$thisNumber =~ s/%NTOPICS%/$ntopics/go;
	$thisNumber = TWiki::Func::renderText( $thisNumber, $webName );
	$thisNumber =~ s|</*nop/*>||goi;   # remove <nop> tag
	$result .= $thisNumber;
    if( $rss ){
        $thisNumber =~ s|<p />||goi;   # remove <p /> tag
    }
    }

    # print last part of the HTML page
    $tmplTail = TWiki::Func::renderText( $tmplTail );
    $tmplTail =~ s|</*nop/*>||goi;   # remove <nop> tag
    if( $rss ){
        $tmplTail =~ s|<p />||goi;   # remove <p /> tag
    }
    $result .= $tmplTail;

    return $result;
}

sub websStr {
    my ($self, $query) = (@_);
    
    # The following lines are just 'reused' from the search script
    # Note that mod_perl/cgi appears to use ';' as separator, whereas plain cgi uses '&'
    my $websStr       = join ' ',
                        grep { s/^web=(.*)$/$1/ }
                        split(/[&;]/, $query->query_string);

    # need to unescape URL-encoded data since we use the raw query_string
    # suggested by JeromeBouvattier
    $websStr =~ tr/+/ /;       # pluses become spaces
    $websStr =~ s/%([0-9a-fA-F]{2})/pack("c",hex($1))/ge;  # %20 becomes space

    return $websStr;
}

sub limit {
    my ($self, $query) = (@_);
    my $limit = $query->param( "limit" )  || "";
    
    # again, 'reused' from the search script
    if ($limit =~ /(^\d+$)/o) { # only digits, all else is the same as
        $limit = $1;            # an empty string.  "+10" won't work.
    } else {
        $limit = 32000;         # change "all" to very big number
    }

    # Defines an absolute limit
    my $maxlimit = TWiki::Func::getPreferencesValue("KINOSEARCHMAXLIMIT") || 2000;
    if ($maxlimit < $limit) {
        $limit = $maxlimit;
    }

    return $limit;
}

# I extend the search string $search depending on $websStr with additional 
# things for limiting to the defined webs.
sub searchStringForWebs {
    my ($self, $search, $websStr) = (@_);

    # A value of 'all' or 'on' by itself gets all webs,
    # otherwise ignored (unless there is a web called "All".)
    my $searchAllFlag = ( $websStr =~ /(^|[\,\s])(all|on)([\,\s]|$)/i );
			  
    # ok, if we have web parameters, just make them part of the Kino query
    # i.e. 'search=x&web=TWiki&web=Main', then query becomes 'x and (web:TWiki web:Main)'
    if ((! $searchAllFlag ) && ($websStr)) {
	 my $searchStr = join ' web:',
		         split(/[ ]+/, $websStr);
	 $search = "$search AND web:$searchStr";
    }
    return $search;
}

# I retrieve all docs for a given query string
# QS
sub docsForQuery {
    my ($self, $search) = (@_);

    my $analyser = $self->analyser( $self->analyserLanguage() );

    my $parser = KinoSearch::QueryParser::QueryParser->new(
		  analyzer => $analyser,
		  fields   => [ 'topic', 'bodytext', 'author' ],
		  default_boolop => 'AND'					   
    );

    if (! $search ) {
       $search="\"Something very unlikely to happen. Nothing to search for!\"";
    }

    my $kinoquery = $parser->parse($search); 

    my $searcher = KinoSearch::Searcher->new(
                                invindex => $self->indexPath(),
				analyzer => $analyser
					     );

    my $docs = $searcher->search(query => $kinoquery);

    my $highlighter = KinoSearch::Highlight::Highlighter->new( 
        excerpt_field  => 'bodytext',
	excerpt_length => $self->summaryLength(),
	);

    $docs->create_excerpts( highlighter => $highlighter );

    # $hits->seek( $offset, $hits_per_page );
    $docs->seek( 0, $docs->total_hits );

    return $docs;
}

# I return the HTML string to render the given hit.
sub renderHtmlStringFor {
    my ($self, $hit, $repeatText, $nosummary, $showlock) = (@_);

    my $mainWebname = TWiki::Func::getMainWebname();

    my $tempVal = $repeatText;
    my $resweb = $hit->{web};
    my $restopic = $hit->{topic};
    # For partial name search of topics, just hold the first part of the string
    if($restopic =~ m/(\w+)/) { $restopic =~ s/ .*//; }

    my $revUser = "";
    my $revDate = "";
    my $revNum = "";
    my $locked = "";
    my $lockinguser = "";
    my $name = "";
    my $icon = "";
    my $comment = "";

    # is the hit an attachment ?
    my $fieldattachment = $hit->{attachment};
    if ( $fieldattachment ) {
	$name = $hit->{name};
	$comment = $hit->{comment} || ""; 
	if ($comment) {
	    $comment = " - $comment";
	    
	    # Don't know, why this was in. 
	    # If I do this, I remove also special characters like "�", "�" etc.
	    #$comment =~ s/([\x{80}-\x{FFFF}])/'.'/gse; # FIXME bt now just get rid of UTF8
	}
    } else {
	$name = "";
    }

    # read topic
    #my( $meta, $text ) = TWiki::Func::readTopic( $resweb, $restopic );
    #$text =~ s/%WEB%/$resweb/gos;
    #$text =~ s/%TOPIC%/$restopic/gos;

    # recover data from the hit so it can be displayed
    if ( $hit->{author} ) {
	$revUser = $hit->{author};
	$revUser = TWiki::Func::userToWikiName($revUser);

	if ($revUser !~ "$mainWebname.") { $revUser = "$mainWebname.$revUser"; }
	$revNum = $hit->{version};
	$revDate = $hit->{date};
    }

    $tempVal =~ s/%WEB%/$resweb/go;
    $tempVal =~ s/%SCORE%//go;
    
    # field $name only is present if the hit is an attachment
    if ($name) {
	# icon for attachment based on filename
	$icon = $TWiki::Plugins::SESSION->mapToIconFileName($name);
	$icon = "%ICON{\"$icon\"}%";
	# URL for the file
	$tempVal =~ s/%MATCH%/<a href="%PUBURLPATH%\/$resweb\/$restopic\/$name">$name<\/a>/go;
	# no locking information for attachments
	$locked = ""; $lockinguser = "";
    } else {
	# no icon for topics
	$icon = "";
	# URL for the topic
	$tempVal =~ s/%MATCH%/\[\[$resweb\.$restopic\]\]/go;
	# if locks are to be displayed, then find it out for each hit
	if ($showlock) {
	    ($url, $lockinguser, $locked) = TWiki::Func::checkTopicEditLock($resweb, $restopic);
	    if ($lockinguser) { $lockinguser = TWiki::Func::userToWikiName( $lockinguser, "0" ); }
	}
    }
    # NEW icon for new topics and revision number for old ones
    if (($revNum eq "")||($revNum == 1)) {
	$revNum = "%N%";
    } else {
	$revNum = "r$revNum";
    }

    # now, just replace the template elements with values and render
    $tempVal =~ s/%ICON%/$icon/go;
    if ($locked) {
	$tempVal =~ s/%LOCKED%/$lockinguser ($locked)/o;
    }
    $tempVal =~ s/%LOCKED%/ /go;
    $tempVal =~ s/%TIME%/$revDate/go;
    $tempVal =~ s/%TOPICNAME%/$restopic/go;
    $tempVal =~ s/%REVISION%/$revNum/go;
    $tempVal =~ s/%AUTHOR%/$revUser/go;
    $tempVal = TWiki::Func::expandCommonVariables( $tempVal, $restopic, $resweb );
    $tempVal = TWiki::Func::renderText( $tempVal, $resweb );
    
    if( $nosummary ) {
	# no summaries
	$tempVal =~ s/%TEXTHEAD%//go;
	$tempVal =~ s/&nbsp;//go;
    } else {
	if ($name) {
	    # summaries for attachments
	    $tempVal =~ s/%TEXTHEAD%/\[\[$resweb\.$restopic\]\]$comment \[$hit->{excerpt}\]/go;
	} else {
	    # summaries for topics
	    $tempVal =~ s/%TEXTHEAD%/$hit->{excerpt}/go;
	}
    }
    $tempVal = TWiki::Func::renderText( $tempVal, $resweb );
    $tempVal =~ s|</*nop/*>||goi;   # remove <nop> tag
    
    return $tempVal;
}

# Return the RSS friendly string to render the given hit.
# AndrewRJones 17 Sep 2008
sub renderRssStringFor {
    my ($self, $hit, $repeatText, $nosummary, $showlock) = (@_);

    my $mainWebname = TWiki::Func::getMainWebname();

    my $tempVal = $repeatText;
    my $resweb = $hit->{web};
    my $restopic = $hit->{topic};
    # For partial name search of topics, just hold the first part of the string
    if($restopic =~ m/(\w+)/) { $restopic =~ s/ .*//; }

    my $revUser = "";
    my $revDate = "";
    my $revNum = "";
    my $locked = "";
    my $lockinguser = "";
    my $name = "";
    my $comment = "";

    # is the hit an attachment ?
    my $fieldattachment = $hit->{attachment};
    if ( $fieldattachment ) {
	$name = $hit->{name};
	$comment = $hit->{comment} || ""; 
	if ($comment) {
	    $comment = " - $comment";
	    
	    # Don't know, why this was in. 
	    # If I do this, I remove also special characters like "�", "�" etc.
	    #$comment =~ s/([\x{80}-\x{FFFF}])/'.'/gse; # FIXME bt now just get rid of UTF8
	}
    } else {
	$name = "";
    }

    # read topic
    #my( $meta, $text ) = TWiki::Func::readTopic( $resweb, $restopic );
    #$text =~ s/%WEB%/$resweb/gos;
    #$text =~ s/%TOPIC%/$restopic/gos;

    # recover data from the hit so it can be displayed
    if ( $hit->{author} ) {
	$revUser = $hit->{author};
	$revUser = TWiki::Func::userToWikiName($revUser);

	if ($revUser !~ "$mainWebname.") { $revUser = "$mainWebname.$revUser"; }
	$revNum = $hit->{version};
	$revDate = $hit->{date};
    }

    $tempVal =~ s/%WEB%/$resweb/go;
    $tempVal =~ s/%SCORE%//go;
    
    # field $name only is present if the hit is an attachment
    if ($name) {
	# URL for the file
	$tempVal =~ s/%MATCH%/<a href="%PUBURLPATH%\/$resweb\/$restopic\/$name">$name<\/a>/go;
	# no locking information for attachments
	$locked = ""; $lockinguser = "";
    } else {
	# HTML Link URL for the topic
	$tempVal =~ s/%MATCH%/\[\[$resweb\.$restopic\]\]/go;
    # Plain title
    $tempVal =~ s/%MATCHTITLE%/$resweb\.$restopic/go;
    # Plain URL
    $tempVal =~ s!%MATCHURL%!\%SCRIPTURL{"view"}\%/$resweb/$restopic!go;
    
	# if locks are to be displayed, then find it out for each hit
	if ($showlock) {
	    ($url, $lockinguser, $locked) = TWiki::Func::checkTopicEditLock($resweb, $restopic);
	    if ($lockinguser) { $lockinguser = TWiki::Func::userToWikiName( $lockinguser, "0" ); }
	}
    }

    # revision number
	$revNum = "r$revNum";

    # now, just replace the template elements with values and render
    if ($locked) {
	$tempVal =~ s/%LOCKED%/$lockinguser ($locked)/o;
    }
    $tempVal =~ s/%LOCKED%/ /go;
    $tempVal =~ s/%TIME%/$revDate/go;
    $tempVal =~ s/%TOPICNAME%/$restopic/go;
    $tempVal =~ s/%REVISION%/$revNum/go;
    $tempVal =~ s/%AUTHOR%/$revUser/go;
    $tempVal = TWiki::Func::expandCommonVariables( $tempVal, $restopic, $resweb );
    $tempVal = TWiki::Func::renderText( $tempVal, $resweb );
    
    if( $nosummary ) {
	# no summaries
	$tempVal =~ s/%TEXTHEAD%//go;
	$tempVal =~ s/&nbsp;//go;
    } else {
	if ($name) {
	    # summaries for attachments
	    $tempVal =~ s/%TEXTHEAD%/\[\[$resweb\.$restopic\]\]$comment \[$hit->{excerpt}\]/go;
	} else {
	    # summaries for topics
	    $tempVal =~ s/%TEXTHEAD%/$hit->{excerpt}/go;
	}
    }
    $tempVal = TWiki::Func::renderText( $tempVal, $resweb );
    $tempVal =~ s|</*nop/*>||goi;   # remove <nop> tag
    $tempVal =~ s|<p />||goi;   # remove <p /> tag
    
    return $tempVal;
}

# print "Search:" part
sub renderSearchHeader {
    my ($self, $usersearch, $tmplSearch ) = (@_);

    my $result = '';
    
    $tempVal = $usersearch;
    $tempVal =~ s/&/&amp;/go;
    $tempVal =~ s/</&lt;/go;
    $tempVal =~ s/>/&gt;/go;
    $tempVal =~ s/^\.\*$/Index/go;
    $tmplSearch =~ s/%SEARCHSTRING%/$tempVal/go;

    # This made some troble. I removed it and it seems to be not needed!?
    #$tmplSearch = &TWiki::Func::renderText( $tmplSearch );

    $tmplSearch =~ s|</*nop/*>||goi;   # remove <nop> tag
    $result .= $tmplSearch;    

    return $result;
}

# I check, if the the user is allowed to view the topic an if the web is searchable. 
sub topicAllowed { 

    my ($self, $restopic, $resweb,  $text, $remoteUser) = (@_);

    # security check - default mapping for user guest is TWikiGuest, so if web/topic
    # does not allow this user to view the hit, it will be discarded
    #my $allowView = TWiki::Func::checkAccessPermission( "view", TWiki::Func::userToWikiName($remoteUser) , $text, $restopic, $resweb );
    #print "remoteUser = $remoteUser\n";
    my $allowView = TWiki::Func::checkAccessPermission( "view", $remoteUser , $text, $restopic, $resweb );
    if( ! $allowView ) {
	return 0;
    }
    # another security check - is the web of the current result hidden ?
    $allowView = TWiki::Func::getPreferencesValue( "NOSEARCHALL", $resweb ) || "";
    if( $allowView eq "on" ) {
	return 0;
    }
    return 1;
}

1;
