
# TWiki ($wikiversion has version info)
#
# Copyright (C) 2002 Slava Kozlov,
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

# =========================
package TWiki::Plugins::TreePlugin;

use strict;
use warnings;

use TWiki::Func;

use TWiki::Plugins::TreePlugin::TWikiNode;
use TWiki::Plugins::TreePlugin::ListNodeFormatter;
use TWiki::Plugins::TreePlugin::ColorNodeFormatter;
use TWiki::Plugins::TreePlugin::FormatOutlineNodeFormatter;
use TWiki::Plugins::TreePlugin::HOutlineNodeFormatter;
use TWiki::Plugins::TreePlugin::ImgNodeFormatter;

# =========================
use vars qw(
  $gWeb $gTopic $user $installWeb $VERSION $debug $INTREE
  %FormatMap $RootLabel $AGdebugmsg $pluginName
);

$pluginName = 'TreePlugin';
$VERSION = '1.3';
$RootLabel = "_RootLabel_";    # what we use to label the root of a tree if not a topic

# =========================
sub initPlugin {
    ( $gTopic, $gWeb, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning("Version mismatch between TreePlugin and Plugins.pm");
        return 0;
    }

# Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
# $exampleCfgVar = &TWiki::Prefs::getPreferencesValue( "TreePlugin_EXAMPLE" ) || "default";

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag( "\U$pluginName\E_DEBUG" );


    &TWiki::Func::writeDebug("installWeb: $installWeb") if $debug;

    my $cgi = &TWiki::Func::getCgiQuery();
    if ( !$cgi ) {
        return 0;
    }
    
    TWiki::Func::registerTagHandler( 'TREEVIEW', \&HandleTreeTag );
    TWiki::Func::registerTagHandler( 'TREE', \&HandleTreeTag );

    # Plugin correctly initialized
    &TWiki::Func::writeDebug(
        "- TWiki::Plugins::TreePlugin::initPlugin( $gWeb.$gTopic ) is OK")
      if $debug;
    return 1;
}

=pod
Tag handler for TREE and TREEVIEW
=cut 

# bugs re recursion:
#	1) doesn't remember webs so: recursion across webs is problematic
#	2) if two topics with identical names in different webs AND
#		both have a TREEVIEW tag -> the second will be excluded

$AGdebugmsg = "<br \/>AG debug message<br \/>";

sub HandleTreeTag
    {
    my($session, $params, $aTopic, $aWeb) = @_;    
    
    #### Initializations 

    my $cgi   = &TWiki::Func::getCgiQuery();
    my $plist = $cgi->query_string();
    $plist .= "\&" if $plist;
    my $CurrUrl = $cgi->url . $cgi->path_info() . "?" . $plist;
    
    my $nodiv = $params->{'nodiv'} || "0";
    my $attrWeb = $params->{'web'} || $aWeb || "";
    #Get root topic id in the form =web.topic=
    my $rootTopicId = $params->{'topic'} ? "$attrWeb.".$params->{'topic'} : $RootLabel; 
  
    my $attrFormatting;
        
    my $attrHeader='';
    if (defined $params->{'header'})
        {
        $attrHeader ='<div class="treePluginHeader">'. $params->{'header'}."</div>\n";
        }
    else
        {
        #Make sure the tree starts on a new line and get formatted correctly
        $attrHeader=""; 
        }

    my $attrFormat = $params->{'format'} || "";
    
    my $attrFormatBranch =
      $params->{'formatbranch'} || "";
    $attrFormatting =
      $params->{'formatting'} || "";
    my $attrStartlevel =
      $params->{'startlevel'} || -1; # -1 means not defined
    #SL: If no =topic= and =startlevel= parameter was given then set =startlevel= to 1
    #This workaround get ride of the empty root line when rendering a tree for an entire Web
    if (($rootTopicId eq $RootLabel) && ($attrStartlevel==-1)) { $attrStartlevel=1; } #
    my $attrStoplevel =
      $params->{'stoplevel'} || 999;
    my $doBookView =
      $params->{'bookview'} || "";
    my $attrLevelPrefix =
      $params->{'levelprefix'} || "";
    
    # set the type of formatting
    my $formatter = setFormatter($attrFormatting);

    $formatter->data( "startlevel", $attrStartlevel );
    $formatter->data( "stoplevel",  $attrStoplevel );
    $formatter->data( "url",        $CurrUrl );
    $formatter->data( "levelprefix", $attrLevelPrefix );
        
    # if bookView, read bookview file as format
    if ($doBookView) {
        #SL: disable bookview until we fix it 
        return "%RED%bookview is broken in this version of $installWeb.TreePlugin.%ENDCOLOR%"
        #$formatter->data( "format", &TWiki::Func::readTemplate("booktree") );
    }
    else {

        # else set the format(s), if any
        $formatter->data( "format", $attrFormat ) if ($attrFormat);
        $formatter->data( "branchformat", $attrFormatBranch )
          if ($attrFormatBranch);

    }
    
    #Before doing the SEARCH, if no format was specified use formatter's default
    #SL: I know it's a bit mad what's going on between $attrFormat, $formatter->data('format') and $params->{'format'} but that will do for now
    $params->{'format'}=$formatter->data("format") if ($attrFormat eq "");

    #### Get SEARCH results 
    my $search = doSEARCH( $attrWeb, $params, $formatter );

    my %nodes = ();

    &TWiki::Func::writeDebug("First loop") if $debug;    
    
    #### Parse SEARCH results and build up tree structure    

    #First loop:
    #   * Parse the SEARCH output
    #   * Create TWikiNode objects 
    #   * Populate hash of nodes/topics
    foreach ( split /\n/, $search ) {
        my ( $nodeWeb, $nodeTopic, $nodeFormat ) = split (/\|/,$_,3);    # parse out node data
        &TWiki::Func::writeDebug("SEARCH LINE: $nodeWeb, $nodeTopic, $nodeFormat") if $debug;  
        my $nodeId = "$nodeWeb.$nodeTopic";
        
        #If no node format default to the formatter's format     
        if (!$nodeFormat) {$nodeFormat=$formatter->data("format");}
       
        # create node object and add it to the hash
        my $node = createTWikiNode( $nodeId, \%nodes );        
        $node->data( "web",     $nodeWeb );
        $node->data( "topic",   $nodeTopic );
        $node->data( "format",  "$nodeFormat\n" ) if defined $nodeFormat; 
    }
    
    &TWiki::Func::writeDebug("Create root") if $debug;    
    
    #SL: to simplify we could even systematically create the web root, that would do no arm would save a few test... why not
    #If no root topic specified it means we are rendering web tree therefore create a fake web root object 
    my $webRoot = $rootTopicId eq $RootLabel ? createTWikiNode( $RootLabel, \%nodes ) : undef;  
    #At this stage the root must be in the hash, if not just quite (fake web root or actual topic root) 
    return "<!-- No Topic -->" unless $nodes{$rootTopicId};  # nope, the wanted node ain't here

    &TWiki::Func::writeDebug("Second loop") if $debug;    

    #Second loop:
    #   * Create nodes relationship
    foreach my $nodeId (sort keys %nodes) {
        my $node=$nodes{$nodeId};
        #Make sure we don't set a parent to the web root otherwise we just go in an infinite loop while rendering
        next if (defined $webRoot && $node == $webRoot);
        #Get parent
        #SL: We could get the parent from the SEARCH
        #I wonder if that would give us any performance gain
        #...since we would need to make the scope="text" 
        my $parentId = getParentId($node->data('web'),$node->data('topic'));
        my $parent = defined $parentId && defined $nodes{$parentId} ? $nodes{$parentId} : $webRoot; # otherwise root's my parent
        next unless (defined $parent);
        $node->data( "parent", $parent );
        $parent->add_child($node); # hook me up
    }
    
    #### Tree rendering

    &TWiki::Func::writeDebug("Rendering..") if $debug;    

    $webRoot->name(" ") if (defined $webRoot);    # If using fake root change root's name so it don't show up, hack
    my $root= defined $webRoot ? $webRoot : $nodes{$rootTopicId}; #Get the root object fake web root or actual topic root 

    # format the tree & parse TWiki tags and rendering
    my $renderedTree = $attrHeader . $root->toHTMLFormat($formatter);

    &TWiki::Func::writeDebug("Rendering done!") if $debug;    
    
    #Workaround for our issues of trailing new lines
    $renderedTree=~s/\s*$//so;

    #Encapsulate in a div.
    $renderedTree ="<div class=\"treePlugin\">\n".$renderedTree."</div><!--//treePlugin-->" unless ($nodiv);

    #SL: Substitute $index in the rendered tree, $index is most useful to implement menus in combination with TreeBrowserPlugin
    #SL Later: well actually TreeBrowserPlugin now supports =autotoggle= so TreeBrowserPlugin can get away without using that $index in most cases.
    if ( defined $formatter->data("format") ) {
        my $Index = 0;
        $renderedTree =~ s/\$Index/$Index++;$Index/egi;
    }
    
    &TWiki::Func::writeDebug($renderedTree) if $debug;    
    
    return $renderedTree;
}

=pod
Create a new node object and add it to the given hash 
@param [in] scalar node id
@param [in] scalar hash reference
@return Pointer to TWiki::Plugins::TreePlugin::TWikiNode object
=cut

sub createTWikiNode {
    my ( $id, $hash ) = @_;
    my $node = TWiki::Plugins::TreePlugin::TWikiNode->new($id);
    $hash->{$id} = $node;
    return $node;
}


=pod
Return web.topic of the parent topic for the specified topic or undef if no parent
@param [in] web 
@param [in] topic
@return web.topic for the parent or undef 
=cut

sub getParentId {
    my ($aWeb, $aTopic) = @_;
    my ( $meta, $text ) = &TWiki::Func::readTopic( $aWeb, $aTopic );
    my $ref = $meta->get("TOPICPARENT");
    return undef unless (defined $ref); 
    #my %par = (defined $ref ? %$ref : ()); #cast
    my $parent = $ref->{'name'};
    return undef unless (defined $parent); #Handle the case where META:TOPICPARENT does not specify a name !?!
    #Now deal with the case where we have no web specified in the parent Codev.GetRidOfTheDot
    unless ($parent=~/.+\.+/) #unless web.topic format
        {
        #Prepend the web 
        $parent="$aWeb.$parent"; 
        }
    return $parent;
}


=pod
Just do a %SEARCH%

given attribute and formatter
returns \n-seperated list of topics,
each topic line is composed of
topicname|modtime|author|summary (if applicable)

@param [in] scalar. The web to search for.
@param [in] hash reference. The tag parameters.
@param [in] reference to a formatter object.
@return The output of our %SEARCH%
=cut

sub doSEARCH {
    my ( $attrWeb, $params, $formatter ) = @_;

    my $excludetopic=$params->{'excludetopic'} || "";
    my $includetopic=$params->{'includetopic'} || "";

    my $searchVal   = ".*";
    my $searchScope = "topic";

    my $searchWeb = ($attrWeb) ? $attrWeb : "all";

    #We build up our SEARCH format parameter
    #   * First comes our topic identifier 
    #   * Next comes our topic format
    my $searchTmpl = "\$web|\$topic";
    $searchTmpl .= "|" . $params->{'format'} if defined $params->{'format'}; 
    
    #	ok. make the topic list and return it  (use this routine for now)
    #   hopefully there'll be an optimized one later    
    my $search="%SEARCH{search=\"$searchVal\" web=\"$searchWeb\" format=\"$searchTmpl\" scope=\"$searchScope\" regex=\"on\" nosearch=\"on\" nototal=\"on\" noempty=\"on\" excludetopic=\"$excludetopic\" topic=\"$includetopic\"}%";
    &TWiki::Func::writeDebug($search) if $debug;    

    return TWiki::Func::expandCommonVariables($search);
}

=pod
Used by some formater.
Useless really :)
=cut
sub getLinkName {
    my ( $node ) = @_;
    return $node->name(); # SL: just return the name which is in fact the id now in format web.topic    
    #return $node->name() unless $node->data("web");
    #return $node->data("web") . "." . $node->data('topic');
}

sub _findParent {
    my $node = shift;
    $AGdebugmsg = $AGdebugmsg
      . "findParent("
      . $node->name() . ")" . "="
      . ( $node->data("parent") ? $node->data("parent")->name() : "no-parent" )
      . "<br \/>";
    return $node->data("parent");
}

# lazy variable init
# ned to abstract this at some point

sub setFormatter {
    my ($name) = @_;

    # my $formatter = $FormatMap{$name};
    # return $formatter if $formatter;
    my $formatter;

    # -- look up how to do case in Perl! :) SL: lol, I have no idea myself
    if ( $name eq "ullist" ) {
        $formatter =
          new TWiki::Plugins::TreePlugin::ListNodeFormatter( "<ul> ",
            " </ul>" );
    }
    elsif ( $name =~ m/coloroutline(.*)/ ) {
        my $attrs = $1;
        $attrs =~ s/^://;
        $formatter = new TWiki::Plugins::TreePlugin::ColorNodeFormatter($attrs);
    }
    elsif ( $name =~ m/imageoutline(.*)/ ) {
        my $attrs = $1;
        $attrs =~ s/^://;
        $formatter =
          new TWiki::Plugins::TreePlugin::ImgNodeFormatter(
            split( /:/, $attrs ) );
    }
    elsif ( $name eq "ollist" ) {
        $formatter =
          new TWiki::Plugins::TreePlugin::ListNodeFormatter( "<ol> ",
            " </ol>" );
    }
    elsif ( $name eq "hlist" ) {
        $formatter =
          new TWiki::Plugins::TreePlugin::HOutlineNodeFormatter(
            "<h\$level> \$outnum \$web.\$topic </h\$level> \$summary");
    }
    else {
        $name = "outline";
        $formatter =
          new TWiki::Plugins::TreePlugin::FormatOutlineNodeFormatter(
            "\$outnum \$web.\$topic <br \/>");
    }

    # remember and return
    return $formatter;

    # $FormatMap{$name} = $formatter;
}

# allow other classes to see the installation web
sub installWeb {
    return $installWeb;
}


1;
