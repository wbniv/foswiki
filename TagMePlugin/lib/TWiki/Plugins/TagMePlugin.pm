# Plugin for Foswiki - The Free Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006 Peter Thoeny, peter@thoeny.org
# Copyright (c) 2006 Fred Morris, m3047-twiki@inwa.net
# Copyright (c) 2007 Crawford Currie, http://c-dot.co.uk
# Copyright (c) 2007 Sven Dowideit, SvenDowideit@DistributedINFORMATION.com
# Copyright (c) 2007 Arthur Clemens, arthur@visiblearea.com
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
# This Plugin implements tags in TWiki.

# =========================
package TWiki::Plugins::TagMePlugin;

use strict;

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $pluginName $debug
  $initialized $workAreaDir $attachUrl $logAction $tagLinkFormat 
  $tagQueryFormat $alphaNum $doneHeader $normalizeTagInput $lineRegex
  $topicsRegex $action $style $label $header $footer $button
);

$VERSION    = '1.049';
$RELEASE    = 'TWiki 4';
$pluginName = 'TagMePlugin';    # Name of this Plugin

$initialized = 0;
$lineRegex   = "^0*([0-9]+), ([^,]+), (.*)";
my $tagChangeRequestTopic = 'TagMeChangeRequests';
my $tagChangeRequestLink =
  "[[$tagChangeRequestTopic][Tag change requests]]";

BEGIN {

    # I18N initialization
    if ( $TWiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.024 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag('TAGMEPLUGIN_DEBUG');
    $normalizeTagInput = TWiki::Func::getPreferencesFlag('TAGMEPLUGIN_NORMALIZE_TAG_INPUT');
    
    _writeDebug("initPlugin( $web.$topic ) is OK");
    $initialized = 0;
    $doneHeader  = 0;

    return 1;
}

# =========================
sub _initialize {
    return if ($initialized);

    # Initialization
    $workAreaDir = TWiki::Func::getWorkArea($pluginName);
    $attachUrl = TWiki::Func::getPubUrlPath() . "/$installWeb/$pluginName";
    $logAction = TWiki::Func::getPreferencesFlag("\U$pluginName\E_LOGACTION");
    $tagLinkFormat =
        '<a href="%SCRIPTURL{view}%/'
      . $installWeb
      . '/TagMeSearch?tag=$tag;by=$by">$tag</a>';
    $tagQueryFormat =
'<table class="tagmeResultsTable tagmeResultsTableHeader" cellpadding="0" cellspacing="0" border="0"><tr>$n'
      . '<td class="tagmeTopicTd"> <b>[[$web.$topic][<nop>$topic]]</b> '
      . '<span class="tagmeTopicTdWeb">in <nop>$web web</span></td>$n'
      . '<td class="tagmeDateTd">'
      . '[[%SCRIPTURL{rdiff}%/$web/$topic][$date]] - r$rev </td>$n'
      . '<td class="tagmeAuthorTd"> $wikiusername </td>$n'
      . '</tr></table>$n'
      . '<p class="tagmeResultsDetails">'
      . '<span class="tagmeResultsSummary">$summary</span>%BR% $n'
      . '<span class="tagmeResultsTags">Tags: $taglist</span>' . '</p>';
    $alphaNum = TWiki::Func::getRegularExpression('mixedAlphaNum');

    _addHeader();

    $initialized = 1;
}

# =========================
sub afterSaveHandler {
### my ( $text, $topic, $web, $error, $meta ) = @_;

    _writeDebug("afterSaveHandler( $_[2].$_[1] )");

    my $newTopic = $_[1];
    my $newWeb   = $_[2];
    if ( "$newWeb.$newTopic" ne "$web.$topic"
        && $topic ne $TWiki::cfg{HomeTopicName} )
    {

        # excluding WebHome due to TWiki 4 bug on statistics viewed as WebHome
        # and saved as WebStatistics
        _writeDebug(" - topic renamed from $web.$topic to $newWeb.$newTopic");
        _initialize();
        renameTagInfo( "$web.$topic", "$newWeb.$newTopic" );
    }
}

# =========================
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    _writeDebug("commonTagsHandler( $_[2].$_[1] )");
    $_[0] =~ s/%TAGME{(.*?)}%/_handleTagMe($1)/ge;
}

# =========================
sub _addHeader {
    return if $doneHeader;

    my $header =
"\n<style type=\"text/css\" media=\"all\">\n\@import url(\"$attachUrl/tagme.css\");\n</style>\n";
    TWiki::Func::addToHEAD( 'TAGMEPLUGIN', $header );
    $doneHeader = 1;
}

# =========================
sub _handleTagMe {
    my ($attr) = @_;
    $action = TWiki::Func::extractNameValuePair( $attr, 'tpaction' );
    $style = TWiki::Func::extractNameValuePair( $attr, 'style' );
    $label = TWiki::Func::extractNameValuePair( $attr, 'label' );
    $button = TWiki::Func::extractNameValuePair( $attr, 'button' );
    $header = TWiki::Func::extractNameValuePair( $attr, 'header' );
    $header =~ s/\$n/\n/go;
    $footer = TWiki::Func::extractNameValuePair( $attr, 'footer' );
    $footer =~ s/\$n/\n/go;
    my $text = '';
    _initialize();

    if ( $action eq 'show' ) {
	$text = _showDefault();
    }
    elsif ( $action eq 'showalltags' ) {
        $text = _showAllTags($attr);
    }
    elsif ( $action eq 'query' ) {
        $text = _queryTag($attr);
    }
    elsif ( $action eq 'newtag' ) {
        $text = _newTag($attr);
    }
    elsif ( $action eq 'newtagsandadd' ) {
        $text = _newTagsAndAdd($attr);
    }
    elsif ( $action eq 'autonewadd' ) {
        $text = _newTag($attr, 'silent', 1);
        $text = _addTag($attr) unless $text =~ /twikiAlert/; 
    }
    elsif ( $action eq 'add' ) {
        $text = _addTag($attr);
    }
    elsif ( $action eq 'remove' ) {
        $text = _removeTag($attr);
    }
    elsif ( $action eq 'removeall' ) {
        $text = _removeAllTag($attr);
    }
    elsif ( $action eq 'renametag' ) {
        $text = _renameTag($attr);
    }
    elsif ( $action eq 'renametaginit' ) {
        $text = _modifyTagInit( 'rename', $attr );
    }
    elsif ( $action eq 'deletetag' ) {
        $text = _deleteTag($attr);
    }
    elsif ( $action eq 'deletethetag' ) {
        $text = _deleteTheTag($attr);
    }
    elsif ( $action eq 'deletetaginit' ) {
        $text = _modifyTagInit( 'delete', $attr );
    }
    elsif ( $action eq 'nop' ) {

        # no operation
    }
    elsif ($action) {
        $text = 'Unrecognized action';
    }
    else {
	$text = _showDefault();
    }
    return $text;
}

# =========================
sub _showDefault {
    my (@tagInfo) = @_;

    return '' unless ( TWiki::Func::topicExists( $web, $topic ) );
    
    # overriden by the relevant "show" functions for each style
    if ($style eq 'blog') {
	return _showStyleBlog(@tagInfo);
    }

    my $query = TWiki::Func::getCgiQuery();
    my $tagMode = $query->param('tagmode') || '';

    my $webTopic = "$web.$topic";
    @tagInfo = _readTagInfo($webTopic) unless ( scalar(@tagInfo) );
    my $text  = '';
    my $tag   = '';
    my $num   = '';
    my $users = '';
    my $line  = '';
    my %seen  = ();
    foreach (@tagInfo) {

        # Format:  3 digit number of users, tag, comma delimited list of users
        # Example: 004, usability, UserA, UserB, UserC, UserD
        # SMELL: This format is a quick hack for easy sorting, parsing, and
        # for fast rendering
        if (/$lineRegex/) {
            $num   = $1;
            $tag   = $2;
            $users = $3;
            $line =
              _printTagLink( $tag, '' )
              . "<span class=\"tagMeVoteCount\">$num</span>";
            if ( $users =~ /\b$user\b/ ) {
                $line .= _imgTag( 'tag_remove', 'Remove my vote on this tag',
                    'remove', $tag, $tagMode );
            }
            else {
                $line .= _imgTag( 'tag_add', 'Add my vote for this tag',
                    'add', $tag, $tagMode );
            }
            $seen{$tag} = _wrapHtmlTagControl($line);
        }
    }
    if ($normalizeTagInput) {

        # plain sort can be used and should be just a little faster
        $text .= join( ' ', map { $seen{$_} } sort keys(%seen) );
    }
    else {

        # uppercase characters are possible, so sort with lowercase comparison
        $text .=
          join( ' ', map { $seen{$_} } sort { lc $a cmp lc $b } keys(%seen) );
    }
    my @allTags = _readAllTags();
    my @notSeen = ();
    foreach (@allTags) {
        push( @notSeen, $_ ) unless ( $seen{$_} );
    }
    if ( scalar @notSeen ) {
        if ( $tagMode eq 'nojavascript' ) {
            $text .= _createNoJavascriptSelectBox(@notSeen);
        }
        else {
            $text .= _createJavascriptSelectBox(@notSeen);
        }
    }
    $text .= ' '.
      _wrapHtmlTagControl("<a href=\"%SCRIPTURL{viewauth}%/$installWeb/TagMeCreateNewTag".
        "?from=$web.$topic\">create new tag</a>");

    return _wrapHtmlTagMeShowForm($text);
}

# =========================
# displays a comprehensive tag management frame, with a common UI
sub _showStyleBlog {
    my (@tagInfo) = @_;
    my $text  = '';

    # View mode
    if (!$action) {
	if ($button) {
	    $text .= $button;
	} elsif ($label) {
	    $text = "<a href='%SCRIPTURL{viewauth}%/%WEB%/%TOPIC%?tpaction=show' title='Open tag edit menu'>" . $label . "</a>" if $label;
	}
	return $text;
    }
    return _htmlErrorFeedbackChangeMessage('edit', '') unless (_canChange());

    my $query = TWiki::Func::getCgiQuery();
    my $tagMode = $query->param('tagmode') || '';

    my $webTopic = "$web.$topic";
    @tagInfo = _readTagInfo($webTopic) unless ( scalar(@tagInfo) );
    my @allTags = _readAllTags();
    my $tag   = '';
    my $num   = '';
    my $users = '';
    my $line  = '';
    my %seen = ();
    my %seen_my  = ();
    my %seen_others  = ();
    my %tagCount = ();
    # header
    $text .= $header."<fieldset class='tagmeEdit'><legend class='tagmeEdit'>Edit Tags - <a href='".
	$topic . "' name='tagmeEdit'>Done</a></legend>";

    # My tags on this topic + Tags from others on this topic
    foreach (@tagInfo) {
        # Format:  3 digit number of users, tag, comma delimited list of users
        # Example: 004, usability, UserA, UserB, UserC, UserD
        # SMELL: This format is a quick hack for easy sorting, parsing, and
        # for fast rendering
        if (/$lineRegex/) {
            $num   = $1;
            $tag   = $2;
            $users = $3;
            $seen{$tag} = lc $1;
            if ( $users =~ /\b$user\b/ ) { # we tagged this topic
	        $line = "<a class='tagmeTag' href='" . $topic .
  	        "?tpaction=remove;tag=" . &_urlEncode($tag) . "'>". $tag .
		"</a> ";
		$seen_my{$tag} = _wrapHtmlTagControl($line);
            } else {                       # others tagged it
	        $line = "<a class='tagmeTag' href='" . $topic .
  	        "?tpaction=add;tag=" . &_urlEncode($tag) . "'>". $tag .
		"</a> ";
		$line .= _imgTag( 'tag_remove', 'Force untagging',
				  'removeall', $tag, $tagMode );
		$seen_others{$tag} = _wrapHtmlTagControl($line);
            }
        }
    }

    if ($normalizeTagInput) {
        # plain sort can be used and should be just a little faster
        $text .= "<p class='tagmeBlog'><b>My Tags on this topic: </b>" . 
	    join( ' ', map { $seen_my{$_} } sort keys(%seen_my) ) . 
	        "<br /><i>click to untag</i></p>";
        $text .= "<p class='tagmeBlog'><b>Tags on this topic by others: </b>". 
	    join( ' ', map { $seen_others{$_} } sort keys(%seen_others) ) . 
	        "<br /><i>click tag to also tag with, click delete icon to force untag by all</i></p>" if %seen_others;
    } else {
        # uppercase characters are possible, so sort with lowercase comparison
        $text .= "<p class='tagmeBlog'><b>My Tags on this topic: </b>" . 
            join( ' ', map { $seen_my{$_} } sort { lc $a cmp lc $b } keys(%seen_my) ) .
	        "<br /><i>click to untag</i></p>";
        $text .= "<p class='tagmeBlog'><b>Tags on this topic by others: </b>" . 
            join( ' ', map { $seen_others{$_} } sort { lc $a cmp lc $b } keys(%seen_others) ) .
	        "<br /><i>click tag to also tag with, click delete icon to force untag by all</i></p>" if %seen_others;
    }

    # Related tags (and we compute counts)
    my %related   = ();
    my $tagWebTopic = '';
    foreach $tagWebTopic ( _getTagInfoList() ) {
	my @tagInfo = _readTagInfo($tagWebTopic);
	my @seenTopic = ();
	my $topicIsRelated = 0;
	foreach my $line (@tagInfo) {
	    if ( $line =~ /$lineRegex/ ) {
		$num   = $1;
                $tag   = $2;
		push (@seenTopic, $tag);
		$topicIsRelated = 1 if $seen{$tag};
		if ($tagCount{$tag}) {
		    $tagCount{$tag} += $num;
		} else {
		    $tagCount{$tag} = 1;
		}
	    }
	}
	if ($topicIsRelated) {
	    foreach my $tag (@seenTopic) {
		$related{$tag} = 1 unless ($seen{$tag});
	    }
	}
    }
    if ( %related ) {
        $text .= "<p class='tagmeBlog'><b>Related tags:</b> ";
	foreach my $tag (keys %related) {
	    $text .= "<a class='tagmeTag' href='" . $topic .
  	        "?tpaction=add;tag=" . &_urlEncode($tag) . "'>". $tag .
		    "</a> ";
	}
	$text .= "<br /><i>click to tag with</i></p>"
    }

    # Bundles, space or commas-seprated of titles: and tags
    my $bundles = TWiki::Func::getPluginPreferencesValue('BUNDLES');
    if ( defined($bundles) && $bundles =~ /\S/ ) {
	my $tagsep = ( $bundles =~ /[^,]*/ ) ? qr/[\,\s]+/ :  qr/\s*\,+\s*/;
	my $listsep = '';
	$text .= "<p class='tagmeBlog'><b>Bundles:</b><ul><li> ";
	foreach my $tag ( split( $tagsep, $bundles )) {
	    if ( $tag =~ /:$/ ) {
		$text .= $listsep . "<b>$tag</b> ";
	    } else {
		if ( $seen{lc $tag} ) {
		    $text .= "<span class='tagmeTagNoclick'>" . $tag . 
			"</span> ";
		} else {
		    $text .= "<a class='tagmeTag' href='" . $topic .
			"?tpaction=autonewadd;tag=" . &_urlEncode($tag) . 
			    "'>". $tag . "</a> ";
		}
	    }
	    $listsep ="</li><li>";
	}
	$text .= "</li></ul></p>";
    }

    # Unused, available, tags in the system
    my @notSeen = ();
    foreach (@allTags) {
        push( @notSeen, $_ ) unless ( $seen_my{$_} || $seen_others{$_} );
    }

    if ( @notSeen ) {
        $text .= "<p class='tagmeBlog'><b>Available known tags:</b> ";
	foreach my $tag (@notSeen) {
	    $text .= "<a class='tagmeTag' href='" . $topic .
  	        "?tpaction=add;tag=" . &_urlEncode($tag) . "'>". $tag .
		"</a>";
	    if ($tagCount{$tag}) {
		$text .= "<span class=\"tagMeVoteCount\">($tagCount{$tag})</span>";
	    } else {
		$text .= _imgTag( 'tag_remove', 'Delete tag',
				  'deletethetag', $tag, $tagMode );
	    }
	    $text .= " ";
	}
	$text .= "<br /><i>click to tag with, click delete icon to delete unused tags</i></p>"
    }

    # create and add tag
    $text .= "<p class='tagmeBlog'><b>Tag with a new tag:</b>
        <form name='createtag' style='display:inline'>
	<input type='text' class='twikiInputField' name='tag' size='64' />
	<input type='hidden' name='tpaction' value='newtagsandadd' />
	<input type='submit' class='twikiSubmit' value='Create and Tag' />
	</form>
        <br /><i>You can enter multiple tags separated by spaces</i></p>";

    # more
    $text .= "<p class='tagmeBlog'><b>Tags management:</b> 
        [[%SYSTEMWEB%.TagMeCreateNewTag][create tags]] -
        [[%SYSTEMWEB%.TagMeRenameTag][rename tags]] -
	[[%SYSTEMWEB%.TagMeDeleteTag][delete tags]] -
	[[%SYSTEMWEB%.TagMeViewAllTags][view all tags]] -
	[[%SYSTEMWEB%.TagMeViewMyTags][view my tags]] -
	[[%SYSTEMWEB%.TagMeSearch][search with tags]]
        </p>";
    # footer
    $text .= "</fieldset>".$footer;
    return $text;
}

# =========================
# Used as fallback for noscript
sub _createNoJavascriptSelectBox {
    my (@notSeen) = @_;

    my $selectControl = '';
    $selectControl .= '<select class="twikiSelect" name="tag"> <option></option> ';
    foreach (@notSeen) {
        $selectControl .= "<option>$_</option> ";
    }
    $selectControl .= '</select>';
    $selectControl .= _addNewButton();
    $selectControl = _wrapHtmlTagControl($selectControl);

    return $selectControl;
}

# =========================
# The select box plus contents is written using Javascript to prevent the tags
# getting indexed by search engines
sub _createJavascriptSelectBox {
    my (@notSeen) = @_;

    my $random          = int( rand(1000) );
    my $selectControlId = "tagMeSelect$random";
    my $selectControl   = "<span id=\"$selectControlId\"></span>";
    my $script          = <<'EOF';
<script type="text/javascript" language="javascript">
//<![CDATA[
function createSelectBox(inText, inElemId) {
	var selectBox = document.createElement('SELECT');
	selectBox.name = "tag";
	selectBox.className = "twikiSelect";
	document.getElementById(inElemId).appendChild(selectBox);
	var items = inText.split("#");
	var i, ilen = items.length;
	for (i=0; i<ilen; ++i) {
		selectBox.options[i] = new Option(items[i], items[i]);
	}
}
EOF
    $script .= 'var text="#' . join( "#", @notSeen ) . '";';
    $script .=
"\nif (text.length > 0) {createSelectBox(text, \"$selectControlId\"); document.getElementById(\"tagmeAddNewButton\").style.display=\"inline\";}\n//]]>\n</script>";

    my $noscript .=
'<noscript><a href="%SCRIPTURL{viewauth}%/%BASEWEB%/%BASETOPIC%?tagmode=nojavascript">tag this topic</a></noscript>';

    $selectControl .=
        '<span id="tagmeAddNewButton" style="display:none;">'
      . _addNewButton()
      . '</span>';
    $selectControl .= $script;

    $selectControl = _wrapHtmlTagControl($selectControl);
    $selectControl .= $noscript;

    return $selectControl;
}

# =========================
sub _addNewButton {

    my $input = '<input type="hidden" name="tpaction" value="add" />';
    $input .=
        '<input type="image"' . ' src="'
      . $attachUrl
      . '/tag_addnew.gif"'
      . ' class="tag_addnew"'
      . ' name="add"'
      . ' alt="Select tag and add to topic"'
      . ' value="Select tag and add to topic"'
      . ' title="Select tag and add to topic"' . ' />';
    return $input;
}

# =========================
sub _showAllTags {
    my ($attr) = @_;
    
    my @allTags = _readAllTags();
    return '' if scalar @allTags == 0;
    
    my $qWeb      = TWiki::Func::extractNameValuePair( $attr, 'web' );
    my $qTopic    = TWiki::Func::extractNameValuePair( $attr, 'topic' );
    my $exclude   = TWiki::Func::extractNameValuePair( $attr, 'exclude' );
    my $by        = TWiki::Func::extractNameValuePair( $attr, 'by' );
    my $format    = TWiki::Func::extractNameValuePair( $attr, 'format' );
    my $header    = TWiki::Func::extractNameValuePair( $attr, 'header' );
    my $separator = TWiki::Func::extractNameValuePair( $attr, 'separator' );
    my $footer    = TWiki::Func::extractNameValuePair( $attr, 'footer' );
    my $minSize   = TWiki::Func::extractNameValuePair( $attr, 'minsize' );
    my $maxSize   = TWiki::Func::extractNameValuePair( $attr, 'maxsize' );
    my $minCount  = TWiki::Func::extractNameValuePair( $attr, 'mincount' );

    $minCount = 1 if !defined($minCount) || $qWeb || $qTopic || $exclude || $by;

    # a comma separated list of 'selected' options (for html forms)
    my $selection = TWiki::Func::extractNameValuePair( $attr, 'selection' )
      || '';
    my %selected = map { $_ => 1 } split( /,\s*/, $selection );

    $topicsRegex = '';
    if ($qTopic) {
        $topicsRegex = $qTopic;
        $topicsRegex =~ s/, */\|/go;
        $topicsRegex =~ s/\*/\.\*/go;
        $topicsRegex = '^.*\.(' . $topicsRegex . ')$';
    }
    my $excludeRegex = '';
    if ($exclude) {
        $excludeRegex = $exclude;
        $excludeRegex =~ s/, */\|/go;
        $excludeRegex =~ s/\*/\.\*/go;
        $excludeRegex = '^(' . $excludeRegex . ')$';
    }
    my $hasSeparator = $separator ne '';
    my $hasFormat    = $format    ne '';

    $separator = ', ' unless ( $hasSeparator || $hasFormat );
    $separator =~ s/\$n/\n/go;

    $format = '$tag' unless $hasFormat;
    $format .= "\n" unless $separator;
    $format =~ s/\$n/\n/go;

    $by = $user if ( $by eq 'me' );
    $by = ''    if ( $by eq 'all' );
    $maxSize = 180 unless ($maxSize);    # Max % size of font
    $minSize = 90  unless ($minSize);
    my $text = '';
    my $line = '';
    unless ( $format =~ /\$(size|count|order)/ || $by || $qWeb || $qTopic || $exclude ) {

        # fast processing
        $text = join(
            $separator,
            map {
                my $tag = $_;
                $line = $format;
                $line =~ s/\$tag/$tag/go;
                my $marker = '';
                $marker = ' selected="selected" ' if ( $selected{$tag} );
                $line =~ s/\$marker/$marker/g;
                $line;
              } @allTags
        );
    }
    else {

        # slow processing
        # SMELL: Quick hack, should be done with nice data structure
        my %tagCount = ();
        my %allTags  = map {$_=>1} @allTags;
        my %myTags   = ();
        my $webTopic = '';

        foreach (keys %allTags) {
          $tagCount{$_} = 0;
        }

        foreach $webTopic ( _getTagInfoList() ) {
            next if ( $qWeb        && $webTopic !~ /^$qWeb\./ );
            next if ( $topicsRegex && $webTopic !~ /$topicsRegex/ );
            my @tagInfo = _readTagInfo($webTopic);
            my $tag     = '';
            my $num     = '';
            my $users   = '';
            foreach $line (@tagInfo) {
                if ( $line =~ /$lineRegex/ ) {
                    $num   = $1;
                    $tag   = $2;
                    $users = $3;
                    unless ( $excludeRegex && $tag =~ /$excludeRegex/ ) {
                        $tagCount{$tag} += $num
                          unless ( $by && $users !~ /$by/ );
                        $myTags{$tag} = 1 if ( $users =~ /$by/ );
                    }
                }
            }
        }
        
        if ($minCount) {

            # remove items below the threshold
            foreach my $item ( keys %allTags ) {
                delete $allTags{$item} if ( $tagCount{$item} < $minCount );
            }
        }

        my @tags = ();
        if ($by) {
            if ($normalizeTagInput) {
                @tags = sort keys(%myTags);
            }
            else {
                @tags = sort { lc $a cmp lc $b } keys(%myTags);
            }
        }
        else {
            if ($normalizeTagInput) {
                @tags = sort keys(%allTags);
            }
            else {
                @tags = sort { lc $a cmp lc $b } keys(%allTags);
            }
        }
        if ( $by && !scalar @tags ) {
            return
              "__Note:__ You haven't yet added any tags. To add a tag, go to "
              . "a topic of interest, and add a tag from the list, or put your "
              . "vote on an existing tag.";
        }

#        my @ordered = sort { $tagCount{$a} <=> $tagCount{$b} } @tags;
        my @ordered = sort { $tagCount{$a} <=> $tagCount{$b} } keys(%tagCount);
        my %order = map { ( $_, $tagCount{$_} ) }
          @ordered;
        my $smallestItem = $ordered[0];
        my $largestItem = $ordered[$#ordered];
        my $smallest = $order{$smallestItem};
        my $largest = $order{$largestItem};
        my $div = ($largest - $smallest) || 1; # prevent division by zero
        my $sizingFactor = ($maxSize - $minSize) / $div;
        my $size   = 0;
        my $tmpSep = '_#_';
        $text = join(
            $separator,
            map {
                $size = int( $minSize + ( $order{$_} * $sizingFactor ) );
                $size = $minSize if ( $size < $minSize );
                $line = $format;
                $line =~ s/(tag\=)\$tag/$1$tmpSep\$tag$tmpSep/go;
                $line =~ s/$tmpSep\$tag$tmpSep/&_urlEncode($_)/geo;
                $line =~ s/\$tag/$_/go;
                $line =~ s/\$size/$size/go;
                $line =~ s/\$count/$tagCount{$_}/go;
                $line =~ s/\$order/$order{$_}/go;
                $line;
              } @tags
        );
    }
    return $text ? $header.$text.$footer : $text;
}

# =========================
sub _queryTag {
    my ($attr) = @_;

    my $qWeb   = TWiki::Func::extractNameValuePair( $attr, 'web' );
    my $qTopic = TWiki::Func::extractNameValuePair( $attr, 'topic' );
    my $qTag = _urlDecode( TWiki::Func::extractNameValuePair( $attr, 'tag' ) );
    my $refine = TWiki::Func::extractNameValuePair( $attr, 'refine' )
      || TWiki::Func::getPluginPreferencesFlag('ALWAYS_REFINE');
    my $qBy       = TWiki::Func::extractNameValuePair( $attr, 'by' );
    my $noRelated = TWiki::Func::extractNameValuePair( $attr, 'norelated' );
    my $noTotal   = TWiki::Func::extractNameValuePair( $attr, 'nototal' );
    my $sort = TWiki::Func::extractNameValuePair( $attr, 'sort' ) || 'tagcount';
    my $format = TWiki::Func::extractNameValuePair( $attr, 'format' )
      || $tagQueryFormat;
    my $separator = TWiki::Func::extractNameValuePair( $attr, 'separator' )
      || "\n";
    my $minSize      = TWiki::Func::extractNameValuePair( $attr, 'minsize' );
    my $maxSize      = TWiki::Func::extractNameValuePair( $attr, 'maxsize' );
    my $resultLimit  = TWiki::Func::extractNameValuePair( $attr, 'limit' );
    my $formatHeader = TWiki::Func::extractNameValuePair( $attr, 'header' )
      || '---+++ $web';
    my $formatFooter = TWiki::Func::extractNameValuePair( $attr, 'footer' )
      || 'Showing $limit out of $count results $showmore';

    return '__Note:__ Please select a tag' unless ($qTag);

    my $topicsRegex = '';
    if ($qTopic) {
        $topicsRegex = $qTopic;
        $topicsRegex =~ s/, */\|/go;
        $topicsRegex =~ s/\*/\.\*/go;
        $topicsRegex = '^.*\.(' . $topicsRegex . ')$';
    }
    $qBy = '' unless ($qBy);
    $qBy = '' if ( $qBy eq 'all' );
    my $by = $qBy;
    $by = $user if ( $by eq 'me' );
    $format    =~ s/([^\\])\"/$1\\\"/go;
    $separator =~ s/\$n\b/\n/go;
    $separator =~ s/\$n\(\)/\n/go;
    $maxSize = 180 unless ($maxSize);    # Max % size of font
    $minSize = 90  unless ($minSize);

    my @qTagsA = split( /,\s*/, $qTag );
    my $qTagsRE = join( '|', @qTagsA );

    # SMELL: Quick hack, should be done with nice data structure
    my $text      = '';
    my %tagVotes  = ();
    my %topicTags = ();
    my %related   = ();
    my %sawTag;
    my $tag   = '';
    my $num   = '';
    my $users = '';
    my @tags;
    my $webTopic = '';

    foreach $webTopic ( _getTagInfoList() ) {
        next if ( $qWeb        && $webTopic !~ /^$qWeb\./ );
        next if ( $topicsRegex && $webTopic !~ /$topicsRegex/ );
        my @tagInfo = _readTagInfo($webTopic);
        @tags   = ();
        %sawTag = ();
        foreach my $line (@tagInfo) {
            if ( $line =~ /$lineRegex/ ) {
                $num   = $1;
                $tag   = $2;
                $users = $3;
                push( @tags, $tag );
                if ( $tag =~ /^($qTagsRE)$/ ) {
                    $sawTag{$tag}        = 1;
                    $tagVotes{$webTopic} = $num
                      unless ( $by && $users !~ /$by/ );
                }
            }
        }
        if ( scalar keys %sawTag < scalar @qTagsA ) {

            # Not all tags seen, skip this topic
            delete $tagVotes{$webTopic};
        }
        elsif ( $tagVotes{$webTopic} ) {
            $topicTags{$webTopic} = [ sort { lc $a cmp lc $b } @tags ];
            foreach $tag (@tags) {
                unless( $tag =~ /^($qTagsRE)$/ ) {
                    $num = $related{$tag} || 0;
                    $related{$tag} = $num + 1;
                }
            }
        }
    }

    return "__Note:__ No topics found tagged with \"$qTag\""
      unless ( scalar keys(%tagVotes) );

    # related tags
    unless ($noRelated) {

        # TODO: should be conditional sort
        my @relatedTags = map { _printTagLink( $_, $qBy, undef, $refine ) }
          grep { !/^\Q$qTagsRE\E$/ }
          sort { lc $a cmp lc $b } keys(%related);
        if (@relatedTags) {
            $text .= '<span class="tagmeRelated">%MAKETEXT{"Related tags"}%';
            $text .= ' (%MAKETEXT{"Click to refine the search"}%)' if $refine;
            $text .= ': </span> ' . join( ', ', @relatedTags ) . "\n\n";
        }
    }

    # SMELL: Commented out by CC. This code does nothing useful.
    #if ($normalizeTagInput) {
    #    @tags = sort keys(%allTags);
    #}
    #else {
    #    @tags = sort { lc $a cmp lc $b } keys(%allTags);
    #}
    my @topics = ();
    if ( $sort eq 'tagcount' ) {

        # Sort topics by tag count
        @topics = sort { $tagVotes{$b} <=> $tagVotes{$a} } keys(%tagVotes);
    }
    elsif ( $sort eq 'topic' ) {

        # Sort topics by topic name
        @topics = sort {
            substr( $a, rindex( $a, '.' ) ) cmp substr( $b, rindex( $b, '.' ) )
          }
          keys(%tagVotes);
    }
    else {

        # Sort topics by web, then topic
        @topics = sort keys(%tagVotes);
    }
    if ( $format =~ /\$size/ ) {

        # handle formatting with $size (slower)
        my %order = ();
        my $max   = 1;
        my $size  = 0;
        %order = map { ( $_, $max++ ) }
          sort { $tagVotes{$a} <=> $tagVotes{$b} }
          keys(%tagVotes);
        foreach $webTopic (@topics) {
            $size = int( $maxSize * ( $order{$webTopic} + 1 ) / $max );
            $size = $minSize if ( $size < $minSize );
            $text .=
              _printWebTopic( $webTopic, $topicTags{$webTopic}, $qBy, $format,
                $tagVotes{$webTopic}, $size );
            $text .= $separator;
        }
    }
    else {

        # normal formatting without $size (faster)
        if ( $qWeb =~ /\|/ ) {

            #multiple webs selected
            my %webText;
            my %resultCount;
            foreach $webTopic (@topics) {
                my ( $thisWeb, $thisTopic ) =
                  TWiki::Func::normalizeWebTopicName( '', $webTopic );

                #initialise this new web with the header
                unless ( defined( $webText{$thisWeb} ) ) {
                    $webText{$thisWeb}     = '';
                    $resultCount{$thisWeb} = 0;
                    if ( defined($formatHeader) ) {
                        my $header = $formatHeader;
                        $header =~ s/\$web/$thisWeb/g;
                        $webText{$thisWeb} .= "\n$header\n";
                    }
                }
                $resultCount{$thisWeb}++;

                #limit by $resultLimit
                next
                  if ( ( defined($resultLimit) )
                    && ( $resultLimit ne '' )
                    && ( $resultLimit < $resultCount{$thisWeb} ) );

                $webText{$thisWeb} .=
                  _printWebTopic( $webTopic, $topicTags{$webTopic}, $qBy,
                    $format, $tagVotes{$webTopic} );
                $webText{$thisWeb} .= $separator;
            }
            my @webOrder = split( /[)(|]/, $qWeb );
            foreach my $thisWeb (@webOrder) {
                if ( defined( $webText{$thisWeb} ) ) {
                    if ( defined($formatFooter) ) {
                        my $footer = $formatFooter;
                        $footer =~ s/\$web/$thisWeb/g;
                        my $c =
                          ( $resultLimit < $resultCount{$thisWeb} )
                          ? $resultLimit
                          : $resultCount{$thisWeb};
                        $footer =~ s/\$limit/$c/g;
                        my $morelink = '';

                        #TODO: make link
                        $morelink =
"\n %BR%<div class='tagShowMore'> *Show All results*: "
                          . _printTagLink( $qTag, $qBy, $thisWeb )
                          . "</div>\n"
                          if ( $c < $resultCount{$thisWeb} );
                        $footer =~ s/\$showmore/$morelink/g;
                        $footer =~ s/\$count/$resultCount{$thisWeb}/g;
                        $webText{$thisWeb} .= "\n$footer\n";
                    }
                    $text .= $webText{$thisWeb} . "\n";
                }
            }
        }
        else {
            foreach $webTopic (@topics) {
                $text .=
                  _printWebTopic( $webTopic, $topicTags{$webTopic}, $qBy,
                    $format, $tagVotes{$webTopic} );
                $text .= $separator;
            }
        }
    }
    $text =~ s/\Q$separator\E$//s;
    $text .= "\n%MAKETEXT{\"Number of topics\"}%: " . scalar( keys(%tagVotes) )
      unless ($noTotal);
    _handleMakeText($text);
    return $text;
}

# =========================
sub _printWebTopic {
    my ( $webTopic, $tagsRef, $qBy, $format, $voteCount, $size ) = @_;
    $webTopic =~ /^(.*)\.(.)(.*)$/;
    my $qWeb = $1;
    my $qT1  = $2
      ; # Workaround for core bug Bugs:Item2625, fixed in SVN 11484, hotfix-4.0.4-4
    my $qTopic = quotemeta("$2$3");
    my $text   = '%SEARCH{ '
      . "\"^$qTopic\$\" scope=\"topic\" web=\"$qWeb\" topic=\"$qT1\*\" "
      . 'regex="on" limit="1" nosearch="on" nototal="on" '
      . "format=\"$format\"" . ' }%';
    $text = TWiki::Func::expandCommonVariables( $text, $qTopic, $qWeb );

    # TODO: should be conditional sort
    $text =~
s/\$taglist/join( ', ', map{ _printTagLink( $_, $qBy ) } sort { lc $a cmp lc $b} @{$tagsRef} )/geo;
    $text =~ s/\$size/$size/go if ($size);
    $text =~ s/\$votecount/$voteCount/go;
    return $text;
}

# =========================
sub _printTagLink {
    my ( $qTag, $by, $web, $refine ) = @_;
    $web = '' unless ( defined($web) );

    my $links = '';

    foreach my $tag ( split( /,\s*/, $qTag ) ) {
        my $text = $tagLinkFormat;
        if ($refine) {
            $text = '[['
              . TWiki::Func::getCgiQuery()->url( -path_info => 1 ) . '?'
              . TWiki::Func::getCgiQuery()->query_string();
            $text .= ";tag=" . _urlEncode($tag) . '][' . $tag . ']]';
        }

        # urlencode characters
        # in 2 passes
        my $tmpSep = '_#_';
        $text =~ s/(tag=)\$tag/$1$tmpSep\$tag$tmpSep/go;
        $text =~ s/$tmpSep\$tag$tmpSep/&_urlEncode($tag)/geo;
        $text =~ s/\$tag/$tag/go;
        $text =~ s/\$by/$by/go;
        $text =~ s/\$web/$web/go;
        $links .= $text;
    }
    return $links;
}

# =========================
# Add new tag to system
sub _newTag {
    my ($attr) = @_;

    my $tag = TWiki::Func::extractNameValuePair( $attr, 'tag' );
    my $note = TWiki::Func::extractNameValuePair( $attr, 'note' ) || '';
    my $silent = TWiki::Func::extractNameValuePair( $attr, 'silent' );

    return _wrapHtmlErrorFeedbackMessage( "<nop>$user cannot add new tags",
        $note )
      if ( $user =~ /^(WikiGuest|guest)$/ );

    $tag = _makeSafeTag($tag);

    return _wrapHtmlErrorFeedbackMessage( "Please enter a tag", $note )
      unless ($tag);
    my @allTags = _readAllTags();
    if ( grep( /^\Q$tag\E$/, @allTags ) ) {
	return _wrapHtmlErrorFeedbackMessage("Tag \"$tag\" already exists", $note ) unless (defined $silent) ;
    }
    else {
        push( @allTags, $tag );
        writeAllTags(@allTags);
        _writeLog("New tag '$tag'");
        my $query = TWiki::Func::getCgiQuery();
        my $from  = $query->param('from');
        if ($from) {
            $note =
'<a href="%SCRIPTURL{viewauth}%/%URLPARAM{"from"}%?tpaction=add;tag=%URLPARAM{newtag}%">Add tag "%URLPARAM{newtag}%" to %URLPARAM{"from"}%</a>%BR%'
              . $note;
        }
        return _wrapHtmlFeedbackMessage( "Tag \"$tag\" is successfully added",
            $note );
    }
    return "";
}

# =========================
# Normalize tag, strip illegal characters, limit length
sub _makeSafeTag {
    my ($tag) = @_;
    if ($normalizeTagInput) {
        $tag =~ s/[- \/]/_/go;
        $tag = lc($tag);
        $tag =~ s/[^${alphaNum}_]//go;
        $tag =~ s/_+/_/go;              # replace double underscores with single
    }
    else {
        $tag =~ s/[\x01-\x1f^\#\,\'\"\|\*]//go;    # strip #,'"|*
    }
    $tag =~ s/^(.{30}).*/$1/;                      # limit to 30 characters
    $tag =~ s/^\s*//;                              # trim spaces at start
    $tag =~ s/\s*$//;                              # trim spaces at end
    return $tag;
}

# =========================
# Add tag to topic
# The tag must already exist
sub _addTag {
    my ( $attr ) = @_;

    my $addTag = TWiki::Func::extractNameValuePair( $attr, 'tag' );
    my $noStatus = TWiki::Func::extractNameValuePair( $attr, 'nostatus' );

    my $webTopic = "$web.$topic";
    my @tagInfo  = _readTagInfo($webTopic);
    my $text     = '';
    my $tag      = '';
    my $num      = '';
    my $users    = '';
    my @result   = ();
    if ( TWiki::Func::topicExists( $web, $topic ) ) {
        foreach my $line (@tagInfo) {
            if ( $line =~ /$lineRegex/ ) {
                $num   = $1;
                $tag   = $2;
                $users = $3;
                if ( $tag eq $addTag ) {
                    if ( $users =~ /\b$user\b/ ) {
                        $text .=
                          _wrapHtmlFeedbackErrorInline(
                            "you already added this tag");
                    }
                    else {

                        # add user to existing tag
                        $line = _tagDataLine( $num + 1, $tag, $users, $user );
                        $text .=
                          _wrapHtmlFeedbackInline("added tag vote on \"$tag\"");
                        _writeLog("Added tag vote on '$tag'");
                    }
                }
            }
            push( @result, $line );
        }
        unless ($text) {

            # tag does not exist yet
            if ($addTag) {
                push( @result, "001, $addTag, $user" );
                $text .= _wrapHtmlFeedbackInline(" added tag \"$addTag\"");
                _writeLog("Added tag '$addTag'");
            }
            else {
                $text .= _wrapHtmlFeedbackInline(" (please select a tag)");
            }
        }
        @tagInfo = reverse sort(@result);
        _writeTagInfo( $webTopic, @tagInfo );
    }
    else {
        $text .=
          _wrapHtmlFeedbackErrorInline("tag not added, topic does not exist");
    }

    # Suppress status? FWM, 03-Oct-2006
    return _showDefault(@tagInfo) . ( ($noStatus) ? '' : $text );
}

# =========================
# Create and tag with multiple tags
sub _newTagsAndAdd {
    my ( $attr ) = @_;
    my $text;
    my $args;
    my $tags = TWiki::Func::extractNameValuePair( $attr, 'tag' );
    $tags =~ s/^\s+//o;
    $tags =~ s/\s+$//o;
    $tags =~ s/\s\s+/ /go;
    foreach my $tag ( split( ' ', $tags )) {
	$tag = _makeSafeTag($tag);
	if ($tag) {
	    $args = 'tag="' . $tag . '"';
	    $text = _newTag($args);
	    $text = _addTag($args) unless $text =~ /twikiAlert/;
	}
    }
    return $text;
}

# =========================
# Remove my tag vote from topic
sub _removeTag {
    my ( $attr ) = @_;

    my $removeTag = TWiki::Func::extractNameValuePair( $attr, 'tag' );
    my $noStatus = TWiki::Func::extractNameValuePair( $attr, 'nostatus' );

    my $webTopic = "$web.$topic";
    my @tagInfo  = _readTagInfo($webTopic);
    my $text     = '';
    my $tag      = '';
    my $num      = '';
    my $users    = '';
    my $found    = 0;
    my @result   = ();
    foreach my $line (@tagInfo) {

        if ( $line =~ /^0*([0-9]+), ([^,]+)(, .*)/ ) {
            $num   = $1;
            $tag   = $2;
            $users = $3;
            if ( $tag eq $removeTag ) {
                if ( $users =~ s/, $user\b// ) {
                    $found = 1;
                    $num--;
                    if ($num) {
                        $line = _tagDataLine( $num, $tag, $users );
                        $text .=
                          _wrapHtmlFeedbackInline(
                            "removed my tag vote on \"$tag\"");
                        _writeLog("Removed tag vote on '$tag'");
                        push( @result, $line );
                    }
                    else {
                        $text .=
                          _wrapHtmlFeedbackInline("removed tag \"$tag\"");
                        _writeLog("Removed tag '$tag'");
                    }
                }
            }
            else {
                push( @result, $line );
            }
        }
        else {
            push( @result, $line );
        }
    }
    if ($found) {
        @tagInfo = reverse sort(@result);
        _writeTagInfo( $webTopic, @tagInfo );
    }
    else {
        $text .= _wrapHtmlFeedbackErrorInline("Tag \"$removeTag\" not found");
    }

    # Suppress status? FWM, 03-Oct-2006
    return _showDefault(@tagInfo) . ( ($noStatus) ? '' : $text );
}

# =========================
# Force remove tag  from topic (clear all users votes)
sub _removeAllTag {
    my ( $attr ) = @_;

    my $removeTag = TWiki::Func::extractNameValuePair( $attr, 'tag' );
    my $noStatus = TWiki::Func::extractNameValuePair( $attr, 'nostatus' );

    my $webTopic = "$web.$topic";
    my @tagInfo  = _readTagInfo($webTopic);
    my $text     = '';
    my $tag      = '';
    my $num      = '';
    my $users    = '';
    my $found    = 0;
    my @result   = ();
    foreach my $line (@tagInfo) {

        if ( $line =~ /^0*([0-9]+), ([^,]+)(, .*)/ ) {
            $num   = $1;
            $tag   = $2;
            $users = $3;
            if ( $tag eq $removeTag ) {
		$text .= _wrapHtmlFeedbackInline("removed tag \"$tag\"");
		_writeLog("Removed tag '$tag'");
		$found = 1;
            } else {
                push( @result, $line );
            }
        } else {
            push( @result, $line );
        }
    }
    if ($found) {
        @tagInfo = reverse sort(@result);
        _writeTagInfo( $webTopic, @tagInfo );
    } else {
        $text .= _wrapHtmlFeedbackErrorInline("Tag \"$removeTag\" not found");
    }

    # Suppress status? FWM, 03-Oct-2006
    return _showDefault(@tagInfo) . ( ($noStatus) ? '' : $text );
}

# =========================
sub _tagDataLine {
    my ( $num, $tag, $users, $user ) = @_;

    my $line = sprintf( '%03d', $num );
    $line .= ", $tag, $users";
    $line .= ", $user" if $user;
    return $line;
}

# =========================
sub _imgTag {
    my ( $image, $title, $action, $tag, $tagMode ) = @_;
    my $text = '';

    #my $tagMode |= '';

    if ($tag) {
        $text =
"<a class=\"tagmeAction $image\" href=\"%SCRIPTURL{viewauth}%/%BASEWEB%/%BASETOPIC%?"
          . "tpaction=$action;tag="
          . _urlEncode($tag)
          . ";tagmode=$tagMode\">";
    }
    $text .=
        "<img src=\"$attachUrl/$image.gif\""
      . " alt=\"$title\" title=\"$title\""
      . " width=\"11\" height=\"10\""
      . " align=\"middle\""
      . " border=\"0\"" . " />";
    $text .= "</a>" if ($tag);
    return $text;
}

# =========================
sub _getTagInfoList {
    my @list = ();
    if ( opendir( DIR, "$workAreaDir" ) ) {
        my @files =
          grep { !/^_tags_all\.txt$/ } grep { /^_tags_.*\.txt$/ } readdir(DIR);
        closedir DIR;
        @list = map { s/^_tags_(.*)\.txt$/$1/; $_ } @files;
    }
    return sort @list;
}

# =========================
sub _readTagInfo {
    my ($webTopic) = @_;

    $webTopic =~ s/[\/\\]/\./g;
    my $text = TWiki::Func::readFile("$workAreaDir/_tags_$webTopic.txt");
    my @info = grep { /^[0-9]/ } split( /\n/, $text );
    return @info;
}

# =========================
sub _writeTagInfo {
    my ( $webTopic, @info ) = @_;
    $webTopic =~ s/[\/\\]/\./g;
    my $file = "$workAreaDir/_tags_$webTopic.txt";
    if ( scalar @info ) {
        my $text =
          "# This file is generated, do not edit\n"
          . join( "\n", reverse sort @info ) . "\n";
        TWiki::Func::saveFile( $file, $text );
    }
    elsif ( -e $file ) {
        unlink($file);
    }
}

# =========================
sub renameTagInfo {
    my ( $oldWebTopic, $newWebTopic ) = @_;

    $oldWebTopic =~ s/[\/\\]/\./g;
    $newWebTopic =~ s/[\/\\]/\./g;
    my $oldFile = "$workAreaDir/_tags_$oldWebTopic.txt";
    my $newFile = "$workAreaDir/_tags_$newWebTopic.txt";
    if ( -e $oldFile ) {
        my $text = TWiki::Func::readFile($oldFile);
        TWiki::Func::saveFile( $newFile, $text );
        unlink($oldFile);
    }
}

# =========================
sub _readAllTags {
    my $text = TWiki::Func::readFile("$workAreaDir/_tags_all.txt");

    #my @tags = grep{ /^[${alphaNum}_]/ } split( /\n/, $text );
    # we assume that this file has been written by TagMe, so tags should be
    # valid, and we only need to filter out the comment line
    my @tags = grep { !/^\#.*/ } split( /\n/, $text );
    return @tags;
}

# =========================
# Sorting of tags (lowercase comparison) is done just before writing of
# the _tags_all file.
sub writeAllTags {
    my (@tags) = @_;
    my $text =
      "# This file is generated, do not edit\n"
      . join( "\n", sort { lc $a cmp lc $b } @tags ) . "\n";
    TWiki::Func::saveFile( "$workAreaDir/_tags_all.txt", $text );
}

# =========================
sub _modifyTag {
    my ( $oldTag, $newTag, $changeMessage, $note ) = @_;

    return _htmlErrorFeedbackChangeMessage( 'modify', $note ) if !_canChange();

    my @allTags = _readAllTags();

    if ($oldTag) {
        if ( !grep( /^\Q$oldTag\E$/, @allTags ) ) {
            return _wrapHtmlErrorFeedbackMessage(
                "Tag \"$oldTag\" does not exist", $note );
        }
    }
    if ($newTag) {
        if ( grep( /^\Q$newTag\E$/, @allTags ) ) {
            return _wrapHtmlErrorFeedbackMessage(
                "Tag \"$newTag\" already exists", $note );
        }
    }

    my @newAllTags = grep( !/^\Q$oldTag\E$/, @allTags );
    push( @newAllTags, $newTag ) if ($newTag);
    writeAllTags(@newAllTags);

    my $webTopic = '';
    foreach $webTopic ( _getTagInfoList() ) {
        next if ( $topicsRegex && $webTopic !~ /$topicsRegex/ );
        my @tagInfo = _readTagInfo($webTopic);
        my $tag     = '';
        my $num     = '';
        my $users   = '';
        my $tagChanged = 0;    # only save new file if content should be updated
        my @result     = ();
        foreach my $line (@tagInfo) {

            if ( $line =~ /^($lineRegex)$/ ) {
                $line  = $1;
                $num   = $2;
                $tag   = $3;
                $users = $4;
                if ($newTag) {

                    # rename
                    if ( $tag eq $oldTag ) {
                        $line = _tagDataLine( $num, $newTag, $users );
                        $tagChanged = 1;
                    }
                    push( @result, $line );
                }
                else {

                    # delete
                    if ( $tag eq $oldTag ) {
                        $tagChanged = 1;
                    }
                    else {
                        push( @result, $line );
                    }
                }
            }
        }
        if ($tagChanged) {
            @result = reverse sort(@result);
            $webTopic =~ /(.*)/;
            $webTopic = $1;    # untaint
            _writeTagInfo( $webTopic, @result );
        }
    }

    _writeLog($changeMessage);
    return _wrapHtmlFeedbackMessage( $changeMessage, $note );
}

# =========================
sub _canChange {

    my $allowModifyPrefNames =
         TWiki::Func::getPluginPreferencesValue('ALLOW_TAG_CHANGE')
      || TWiki::Func::getPluginPreferencesValue('ALLOW_TAG_CHANGE');

    return 1 if !$allowModifyPrefNames;    # anyone is allowed to change

    $allowModifyPrefNames =~ s/ //g;
    my @groupsAndUsers = split( ",", $allowModifyPrefNames );
    foreach (@groupsAndUsers) {
        my $name = $_;
        $name =~ s/(Main\.|\%MAINWEB\%\.)//go;
        return 1 if ( $name eq TWiki::Func::getWikiName(undef) ); # user is listed
        return 1 if _isGroupMember( $name );
    }

    # this user is not in list
    return 0;
}

# =========================
sub _renameTag {
    my ($attr) = @_;

    my $oldTag = TWiki::Func::extractNameValuePair( $attr, 'oldtag' );
    my $newTag = TWiki::Func::extractNameValuePair( $attr, 'newtag' );
    my $note   = TWiki::Func::extractNameValuePair( $attr, 'note' ) || '';

    my $query = TWiki::Func::getCgiQuery();
    my $postChangeRequest = $query->param('postChangeRequest') || '';
    if ($postChangeRequest) {
        return _handlePostChangeRequest( 'rename', $oldTag, $newTag, $note );
    }
    return _htmlErrorFeedbackChangeMessage( 'rename', $note ) if !_canChange();

    $newTag = _makeSafeTag($newTag);

    return _wrapHtmlErrorFeedbackMessage( "Please select a tag to rename",
        $note )
      unless ($oldTag);

    return _wrapHtmlErrorFeedbackMessage( "Please enter a new tag name", $note )
      unless ($newTag);

    my $changeMessage =
      "Tag \"$oldTag\" is successfully renamed to \"$newTag\"";
    return _modifyTag( $oldTag, $newTag, $changeMessage, $note );
}

# =========================
sub _handlePostChangeRequest {
    my ( $mode, $oldTag, $newTag, $note ) = @_;

    my $userName    = TWiki::Func::getWikiUserName();
    my $requestLine = '';
    my $message     = '';
    my $logMessage  = '';
    if ( $mode eq 'rename' ) {
        $requestLine = "| Rename | $oldTag | $newTag | $userName | %DATE% |";
        $message .=
"Your request to rename \"$oldTag\" to \"$newTag\" is added to $tagChangeRequestLink";
        $logMessage .=
"Posted tag rename request: from '$oldTag' to '$newTag' (requested by $userName)";
    }
    elsif ( $mode eq 'delete' ) {
        $requestLine =
"| %RED% Delete %ENDCOLOR% | %RED% $oldTag %ENDCOLOR%  | | $userName | %DATE% |";
        $message .=
"Your request to delete \"$oldTag\" is added to $tagChangeRequestLink";
        $logMessage .=
          "Posted tag delete request: '$oldTag' (requested by $userName)";
    }

    my ( $meta, $text ) =
      TWiki::Func::readTopic( $installWeb, $tagChangeRequestTopic );
    $text .= $requestLine;
    TWiki::Func::saveTopic( $installWeb, $tagChangeRequestTopic, $meta, $text,
        { comment => 'posted tag change request' } );

    $message .= "%BR%$note" if $note;
    $message .= _htmlPostChangeRequestFormField();

    _writeLog($logMessage);

    return _wrapHtmlFeedbackMessage( $message, $note );
}

# =========================
# Default (starting) modify action so we can post a useful feedback message if
# this user is not allowed to change tags.
# Is he can change no feedback message will be shown.
sub _modifyTagInit {
    my ( $mode, $attr ) = @_;

    my $note = TWiki::Func::extractNameValuePair( $attr, 'note' ) || '';

    return _htmlErrorFeedbackChangeMessage( $mode, $note ) if !_canChange();

    return $note;
}

# =========================
sub _deleteTag {
    my ($attr) = @_;
    my $deleteTag = TWiki::Func::extractNameValuePair( $attr, 'oldtag' );
    my $note = TWiki::Func::extractNameValuePair( $attr, 'note' ) || '';

    my $query = TWiki::Func::getCgiQuery();
    my $postChangeRequest = $query->param('postChangeRequest') || '';
    if ($postChangeRequest) {
        return _handlePostChangeRequest( 'delete', $deleteTag, undef, $note );
    }
    return _htmlErrorFeedbackChangeMessage( 'delete', $note ) if !_canChange();

    return _wrapHtmlErrorFeedbackMessage( "Please select a tag to delete",
        $note )
      unless ($deleteTag);

    my $changeMessage = "Tag \"$deleteTag\" is successfully deleted";
    return _modifyTag( $deleteTag, '', $changeMessage, $note );
}

# =========================
# same as above but to be used inlinr on a topic, for some styles
sub _deleteTheTag {
    my ($attr) = @_;
    my $deleteTag = TWiki::Func::extractNameValuePair( $attr, 'tag' );
    my $note = TWiki::Func::extractNameValuePair( $attr, 'note' ) || '';

    return _htmlErrorFeedbackChangeMessage( 'delete', $note ) if !_canChange();

    return _wrapHtmlErrorFeedbackMessage( "Please select a tag to delete",
        $note )
      unless ($deleteTag);

    my $changeMessage = "Tag \"$deleteTag\" is successfully deleted";
    $note = _modifyTag( $deleteTag, '', $changeMessage, $note );
    return _showDefault() . $note;
}

# =========================
sub _wrapHtmlFeedbackMessage {
    my ( $text, $note ) = @_;
    return "<div class=\"tagMeNotification\">$text<div>$note</div></div>";
}

# =========================
sub _wrapHtmlErrorFeedbackMessage {
    my ( $text, $note ) = @_;
    return _wrapHtmlFeedbackMessage( "<span class=\"twikiAlert\">$text</span>",
        $note );
}

# =========================
sub _wrapHtmlFeedbackInline {
    my ($text) = @_;
    return " <span class=\"tagMeNotification\">$text</span>";
}

# =========================
sub _wrapHtmlFeedbackErrorInline {
    my ($text) = @_;
    return _wrapHtmlFeedbackInline("<span class=\"twikiAlert\">$text</span>");
}

# =========================
sub _wrapHtmlTagControl {
    my ($text) = @_;
    return "<span class=\"tagMeControl\">$text</span>";
}

# =========================
sub _wrapHtmlTagMeShowForm {
    my ($text) = @_;
    return
"<form name=\"tagmeshow\" action=\"%SCRIPTURL{viewauth}%/%BASEWEB%/%BASETOPIC%\" method=\"post\">$text</form>";
}

# =========================
sub _htmlErrorFeedbackChangeMessage {
    my ( $changeMode, $note ) = @_;

    my $errorMessage = '%ICON{"warning"}%';
    if ( $changeMode eq 'rename' ) {
        $errorMessage .= ' You are not allowed to rename tags';
    }
    elsif ( $changeMode eq 'delete' ) {
        $errorMessage .= ' You are not allowed to delete tags';
    }
    else {
        $errorMessage .= ' You are not allowed to modify tags';
    }

    my $extraNote =
"But you may use this form to post a change request to $tagChangeRequestLink";
    $note = '%BR%' . $note if $note;
    $note = $extraNote . $note;
    $note .= _htmlPostChangeRequestFormField();
    return _wrapHtmlErrorFeedbackMessage( $errorMessage, $note );
}

# =========================
sub _htmlPostChangeRequestFormField {
    return '<input type="hidden" name="postChangeRequest" value="on" />';
}

# =========================
sub _urlEncode {
    my $text = shift;
    $text =~ s/([^0-9a-zA-Z-_.:~!*'()\/%])/'%'.sprintf('%02x',ord($1))/ge;
    return $text;
}

# =========================
sub _urlDecode {
    my $text = shift;
    $text =~ s/%([\da-f]{2})/chr(hex($1))/gei;
    return $text;
}

# =========================
sub _handleMakeText {
### my( $text ) = @_; # do not uncomment, use $_[0] instead

    # for compatibility with TWiki 3
    return unless ( $TWiki::Plugins::VERSION < 1.1 );

    # very crude hack to remove MAKETEXT{"...."}
    # Note: parameters are _not_ supported!
    $_[0] =~ s/[%]MAKETEXT{ *\"(.*?)." *}%/$1/go;
}

# =========================
sub _writeDebug {
    my ($text) = @_;
    TWiki::Func::writeDebug("- ${pluginName}: $text") if $debug;
}

# =========================
sub _writeLog {
    my ($theText) = @_;
    if ($logAction) {
        $TWiki::Plugins::SESSION
          ? $TWiki::Plugins::SESSION->writeLog( "tagme", "$web.$topic",
            $theText )
          : TWiki::Store::writeLog( "tagme", "$web.$topic", $theText );
        _writeDebug("TAGME action, $web.$topic, $theText");
    }
}

# =========================
sub _isGroupMember {
    my $group = shift;
    
    return TWiki::Func::isGroupMember ( $group, undef ) if $TWiki::Plugins::VERSION >= 1.2;
    return $TWiki::Plugins::SESSION->{user}->isInList($group);
}

# =========================
1;
