
# TWiki ($wikiversion has version info)
#
# Copyright (C) 2002 Slava Kozlov,
# Copyright (C) 2006-2008 Stéphane Lenclud,
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
  %FormatMap $RootLabel $AGdebugmsg $pluginName $workAreaDir
  $noCache
);

$pluginName = 'TreePlugin';
$VERSION = '1.7';
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
    #$debug = TWiki::Func::getPreferencesFlag( "\U$pluginName\E_DEBUG" );
    $debug = $TWiki::cfg{Plugins}{$pluginName}{Debug} || 0;
    $noCache = $TWiki::cfg{Plugins}{$pluginName}{NoCache} || 0;
    $workAreaDir = TWiki::Func::getWorkArea($pluginName);
    

    &TWiki::Func::writeDebug("installWeb: $installWeb") if $debug;

    my $cgi = &TWiki::Func::getCgiQuery();
    if ( !$cgi ) {
        return 0;
    }
    
    TWiki::Func::registerTagHandler( 'TREEVIEW', \&HandleTreeTag );
    TWiki::Func::registerTagHandler( 'TREE', \&HandleTreeTag );

    # Plugin correctly initialized
    &TWiki::Func::writeDebug("- TWiki::Plugins::TreePlugin::initPlugin( $gWeb.$gTopic ) is OK") if $debug;
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
    
    my $nodiv = $params->{'nodiv'} || '0';
    my $attrWeb = $params->{'web'} || $aWeb || '';
    #Get root topic id in the form =web.topic=
    my $rootTopicId = $params->{'topic'} ? "$attrWeb.".$params->{'topic'} : $RootLabel; 
  
    my $attrFormatting;
        
    my $attrHeader='';
    if (defined $params->{'header'})
        {
	    if ($nodiv>=2)
	    	{
		    $attrHeader = $params->{'header'};	
	    	}
	    else
	    	{
	        $attrHeader ='<div class="treePluginHeader">'. $params->{'header'}."</div>\n";
        	}
        }

    my $attrFooter='';
    if (defined $params->{'footer'})
        {
   	    if ($nodiv>=2)
	    	{
		    $attrFooter = $params->{'footer'};	
	    	}
	    else
	    	{
        	$attrFooter ='<div class="treePluginFooter">'. $params->{'footer'}."</div>\n";
    		}
        }
        
    my $attrZero='';
    if (defined $params->{'zero'})
        {
   	    if ($nodiv>=2)
	    	{
		    $attrZero = $params->{'zero'};	
	    	}
	    else
	    	{   
       		$attrZero ='<div class="treePluginZero">'. $params->{'zero'}."</div>\n";
   			}
        }

    if (defined $params->{'nocache'})
    	{
	    $noCache=$params->('nocache');	
    	}
        
                
    my $attrFormat = $params->{'format'} || "";   
    my $attrFormatBranch = $params->{'formatbranch'} || "";
    $attrFormatting = $params->{'formatting'} || "";
    
    my $attrSeparator = $params->{'separator'} || "\n";

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
        $formatter->data( 'format', $attrFormat ) if ($attrFormat);
        $formatter->data( 'branchformat', $attrFormatBranch ) if ($attrFormatBranch);
        $formatter->data( 'separator', $attrSeparator ) if ($attrSeparator);          

    }
    
    #Before doing the SEARCH, if no format was specified use formatter's default
    #SL: I know it's a bit mad what's going on between $attrFormat, $formatter->data('format') and $params->{'format'} but that will do for now
    $params->{'format'}=$formatter->data("format") if ($attrFormat eq "");
    
    #Shall we use our cache or not
    if ($params->{'topic'} && !$noCache)
    	{
	    #Get our includetopic from the cache
	    my $includeTopic=fetchCache($attrWeb,$params->{'topic'});
	    if ($includeTopic)
	    	{
		    #We hit the cache overide our including topic parameter	
	    	$params->{'includetopic'}=$includeTopic;		
    		}
    	}
    
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
        my ( $nodeWeb, $nodeTopic, $nodeParent, $nodeFormat ) = split (/\|/,$_,4);    # parse out node data
        &TWiki::Func::writeDebug("SEARCH LINE: $nodeWeb, $nodeTopic, $nodeFormat") if ($debug==2);  
        my $nodeId = "$nodeWeb.$nodeTopic";
        
        #If no node format default to the formatter's format     
        if (!$nodeFormat) {$nodeFormat=$formatter->data("format");}
       
        # create node object and add it to the hash
        my $node = createTWikiNode( $nodeId, \%nodes );        
        $node->data( 'web',     $nodeWeb );
        $node->data( 'topic',   $nodeTopic );
        $node->data( 'format',  $nodeFormat ) if defined $nodeFormat; 
        
        #Work out the parentid as web.topic
        if ($nodeParent eq '$parent')
        	{
	        #No parent property for that topic	
	        $node->data( 'parentid', undef );	
         	}
        else
        	{
	        #Now deal with the case where we have no web specified in the parent Codev.GetRidOfTheDot	
        	unless ($nodeParent=~/.+\.+/) #unless web.topic format
        		{
        		#Prepend the web 
        		$nodeParent="$nodeWeb.$nodeParent"; 
        		}
        	$node->data( 'parentid', $nodeParent);		
    		}
    }
    
    
    &TWiki::Func::writeDebug("Create root") if $debug;      
    #SL: to simplify we could even systematically create the web root, that would do no arm would save a few test... why not
    #If no root topic specified it means we are rendering web tree therefore create a fake web root object 
    my $webRoot = $rootTopicId eq $RootLabel ? createTWikiNode( $RootLabel, \%nodes ) : undef;      
    #At this stage the root must be in the hash, if not just quite (fake web root or actual topic root) 
    return '' unless $nodes{$rootTopicId};  # nope, the wanted node ain't here "<!-- No Topic -->"

    &TWiki::Func::writeDebug("Second loop") if $debug;    

    #Second loop:
    #   * Create nodes relationship
    foreach my $nodeId (sort keys %nodes) {
        my $node=$nodes{$nodeId};
        #Make sure we don't set a parent to the web root otherwise we just go in an infinite loop while rendering
        next if (defined $webRoot && $node == $webRoot);
        #Get parent node from parent id
        my $parentId = $node->data('parentid');
        my $parent = defined $parentId && defined $nodes{$parentId} ? $nodes{$parentId} : $webRoot; # otherwise root's my parent
        next unless (defined $parent);
        $node->data( 'parent', $parent );
        $parent->add_child($node); # hook me up
    }
    
    
	#Only create our cache if excludetopic and includetopic are not defined. 
	#In fact we only want to create cache if we were SEARCHing a whole web, otherwise we would create partial and inconsistent cache
	if (!defined $params->{'excludetopic'} && !defined $params->{'includetopic'})
    	{
		#Cache creation
    	createCache(\%nodes,$webRoot,$attrWeb) unless $noCache;
		}
    
    #### Tree rendering

    &TWiki::Func::writeDebug("Rendering..") if $debug;    

    $webRoot->name(" ") if (defined $webRoot);    # If using fake root change root's name so it don't show up, hack
    my $root= defined $webRoot ? $webRoot : $nodes{$rootTopicId}; #Get the root object fake web root or actual topic root 

    # format the tree & parse TWiki tags and rendering
    my $renderedTree = $root->toHTMLFormat($formatter);

    &TWiki::Func::writeDebug("Rendering done!") if $debug;    
    
    #Workaround for our issues of trailing new lines
    $renderedTree=~s/\s*$//so;
    
    if ($renderedTree eq '')
    	{
	    $renderedTree=$attrZero;
    	}
    else
    	{
	    #Add footer and header	    	
    	$renderedTree = $attrHeader . $renderedTree . $attrFooter 
    	}

	#Encapsulate in a div.
    $renderedTree ="<div class=\"treePlugin\">\n".$renderedTree."</div><!--//treePlugin-->" unless ($nodiv);    	
    	

    #SL: Substitute $index in the rendered tree, $index is most useful to implement menus in combination with TreeBrowserPlugin
    #SL Later: well actually TreeBrowserPlugin now supports =autotoggle= so TreeBrowserPlugin can get away without using that $index in most cases.
    if ( defined $formatter->data("format") ) {
        my $Index = 0;
        $renderedTree =~ s/\$Index/$Index++;$Index/egi;
    }
    
    &TWiki::Func::writeDebug($renderedTree) if ($debug==2);    
    
    return $renderedTree;
}


=pod
Build up our cache if needed.
TODO: find away to do this asynchronously? fork or AJAX? It's probably good enough like that
@param Hash reference containing all our nodes by id
@param Node object of the web root just to make sure we don't try caching it
@param The Web to creat the cache for
=cut

sub createCache
	{
	my $nodesRef=$_[0];
	my $webRoot=$_[1];
	my $aWeb=$_[2];
	
	my $cache='';
	
	TWiki::Func::writeDebug( "- ${pluginName} Creating cache...")  if $debug;

	#Create our file cache if needed
    $aWeb =~ s/\//./g;
    my $cacheFileName = "$workAreaDir/$aWeb.tree";
    if (-e $cacheFileName)
    	{
		TWiki::Func::writeDebug( "- ${pluginName} Cache already exists!")  if $debug;
	    return;
    	}	
		
	foreach my $nodeId (sort keys %$nodesRef)
		{        
		my $node = $nodesRef->{$nodeId};	
        #TWiki::Func::writeDebug( "- ${pluginName} Building cache for: " . $node->data('topic') ) if $debug;
		if (!defined $webRoot || $node!=$webRoot) #no point creating cache for the fake web root
			{
			$cache.=$node->data('topic');
            $node->data($node->data('topic'),1); #Mark it as cached to prevent infinite loop
			my $children=allChildren($node,$node->data('topic'));
			if ($children)
				{
				$cache.=$children;
				}
			$cache.="\n";	
    		}	
		}
		
    TWiki::Func::saveFile( $cacheFileName, $cache );			
	TWiki::Func::writeDebug( "- ${pluginName} Cache created!")  if $debug;
	}

=pod
Get a comma separated list of children from a node

@param The Node from which we need the list of children
=cut

sub allChildren
	{
	my $node=$_[0];	
   	my $cacheId=$_[1];
	my $res='';
		
	if ( scalar( @{ $node->children() } ) )
		{
       	my $count = 0;
       	foreach my $child ( @{ $node->children() } )
           	{
            return $res if (defined $child->data($cacheId)); #prevent endless recursion            
            $child->data($cacheId,1); #Mark it as cached to prevent infinite loop
        	$res.=',' . $child->data('topic');  	        		
	        my $children=allChildren($child,$cacheId); #recurse
	        if ($children)
	        	{ 
	        	$res.= $children;
        		}   	
    		}    		    	
		}
	return $res;		
	}


=pod
Fetch the cache for the given Topic in the specified Web cache

@param The Web for which to fetch the cache
@param The Topic root cache we are interrested in
=cut

sub fetchCache
	{
	my $aWeb=$_[0];
	my $aTopic=$_[1];	
	
    $aWeb =~ s/\//./g;
    my $cacheFileName = "$workAreaDir/$aWeb.tree";
    TWiki::Func::writeDebug( "- ${pluginName} Checking cache file: $cacheFileName" ) if $debug;
    unless (-e $cacheFileName)
    	{
	    #no cache yet, try again next time	
	    return '';
    	}	
			
    my @lines=split /\n/, TWiki::Func::readFile( $cacheFileName);
    foreach my $line(@lines)
    	{
	    #TWiki::Func::writeDebug( "- ${pluginName} Checking cache line" ) if $debug;	
	    if ($line=~ /^$aTopic/)
	    	{
		    TWiki::Func::writeDebug( "- ${pluginName} Hit the cache" ) if $debug;
		    return $line;
	    	}	    		
    	}
    
    TWiki::Func::writeDebug( "- ${pluginName} Won't hit the cache, something is very wrong!" ) if $debug;	
    return '';		
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
    my $searchTmpl = "\$web|\$topic|\$parent";
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

sub afterSaveHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::beforeSaveHandler( $_[2].$_[1] )" ) if $debug;
    
    #Invalidate our cache for that web
    my $aWeb = $_[2];
    $aWeb =~ s/\//./g;
    my $cacheFileName = "$workAreaDir/$aWeb.tree";
    if (-e $cacheFileName)
    	{
	    unlink $cacheFileName;
    	}	    
    
}


1;
