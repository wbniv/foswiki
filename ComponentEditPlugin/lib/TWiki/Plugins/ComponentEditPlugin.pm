# Plugin for Foswiki - The Free Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2005 Sven Dowideit SvenDowideit@wikiring.com
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

=pod

---+ package ComponentEditPlugin

By default it will pop up a floating div window containing a simple textarea, but in combination with registered tag syntax, can generate tag specific UI's (!%SEARCH% is the demo example)

The tag specific UI's require a round trip to the server, but the default can be used without.

=cut

use strict;

package TWiki::Plugins::ComponentEditPlugin;

use vars qw( $VERSION $pluginName $debug  $currentWeb %vars %sectionIds $templateText $WEB $TOPIC %syntax);
use vars qw( $MODERN %TWikiCompatibility %TWikiCompatibilityHEAD );

$VERSION = '0.100';
$pluginName = 'ComponentEditPlugin';  # Name of this Plugin

my %syntax = ( SEARCH => {
		DOCUMENTATION => {type=>'DOCCO', DOCCO=>'Inline search, shows a search result embedded in a topic'},
		search => {type=>'text', defaultparameter=>1, default=>'', DOCCO=>'Search term. Is a keyword search, literal search or regular expression search, depending on the type parameter. SearchHelp has more'},
		web => {type=>'text', default=>'', DOCCO=>'Comma-separated list of webs to search. The special word all means all webs that doe not have the NOSEARCHALL variable set to on in their WebPreferences. You can specifically exclude webs from an all search using a minus sign - for example, web="all,-Secretweb".'},
		topic => {type=>'text', default=>'', DOCCO=>'Limit search to topics: A topic, a topic with asterisk wildcards, or a list of topics separated by comma.'},
		excludetopic => {type=>'text', default=>'', DOCCO=>'Exclude topics from search: A topic, a topic with asterisk wildcards, or a list of topics separated by comma.'},
        header => {type=>'text', default=>'', DOCCO=>'Custom format results: see FormattedSearch for usage, variables & examples'},
        format => {type=>'text', default=>'', DOCCO=>'Expand variables before applying a FormattedSearch on a search hit. Useful to show the expanded text, e.g. to show the result of a SpreadSheetPlugin %CALC{}% instead of the formula'},
        seperator => {type=>'text', default=>'', DOCCO=>'Line separator between hits'},
        type => {type=>'options', option=> ['keyword', 'literal', 'regex'], default=>'', DOCCO=>'Do a keyword search like soap "web service" -shampoo; a literal search like web service; or RegularExpression search like soap;web service;!shampoo'},
		scope => {type=>'options', option=> ['topic', 'text', 'all'], default=>'text', DOCCO=>'Search topic name (title); the text (body) of topic; or all (both)'},
		order => {type=>'text', default=>'', DOCCO=>'Sort the results of search by the topic names, topic creation time, last modified time, last editor, or named field of DataForms. The sorting is done web by web; if you want to sort across webs, create a formatted table and sort it with TablePlugin\'s initsort. Note that dates are sorted most recent date last (i.e at the bottom of the table).'},
		limit => {type=>'text', default=>'', DOCCO=>'Limit the number of results returned. This is done after sorting if order is specified'},
		date => {type=>'text', default=>'', DOCCO=>'limits the results to those pages with latest edit time in the given TimeInterval.'},
		reverse => {type=>'onoff', default=>'off', DOCCO=>'Reverse the direction of the search'},
		casesensitive => {type=>'onoff', default=>'off', DOCCO=>'Case sensitive search'},
		bookview => {type=>'onoff', default=>'off', DOCCO=>'show complete topic text'},
		nosummary => {type=>'onoff', default=>'off', DOCCO=>'Show topic title only'},
		nosearch => {type=>'onoff', default=>'off', DOCCO=>'Suppress search string'},
		noheader => {type=>'onoff', default=>'off', DOCCO=>'Suppress search header '},
		nototal => {type=>'onoff', default=>'off', DOCCO=>'Do not show number of topics found'},
		zeroresults => {type=>'onoff', default=>'off', DOCCO=>'Suppress all output if there are no hits'},
		noempty => {type=>'onoff', default=>'off', DOCCO=>'Suppress results for webs that have no hits.'},
		expandvariables => {type=>'onoff', default=>'off', DOCCO=>'Expand variables before applying a FormattedSearch on a search hit. Useful to show the expanded text, e.g. to show the result of a SpreadSheetPlugin %CALC{}% instead of the formula'},
		multiple => {type=>'onoff', default=>'off', DOCCO=>'Multiple hits per topic. Each hit can be formatted. The last token is used in case of a regular expression ";" and search'},
		nofinalnewline => {type=>'onoff', default=>'off', DOCCO=>'If on, the search variable does not end in a line by itself. Any text continuing immediately after the search variable on the same line will be rendered as part of the table generated by the search, if appropriate.'},
        recurse => {type=>'onoff', default=>'on', DOCCO=>'Recurse into subwebs, if subwebs are enabled.'},
		}
	);

=pod

---++ initPlugin($topic, $web, $user, $installWeb) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin is installed in

not used for plugins specific functionality at present

=cut

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    setupTWiki4Compatibility();
    registerRESTHandler('getEdit', \&getEdit);

    $WEB = $web;
    $TOPIC= $topic;
    $templateText = '';

    # Plugin correctly initialized
    return 1;
}

# DEPRECATED in Dakar (postRenderingHandler does the job better)
# This handler is required to re-insert blocks that were removed to protect
# them from TWiki rendering, such as TWiki variables.
$TWikiCompatibility{endRenderingHandler} = 1.1;
sub endRenderingHandler {
  return postRenderingHandler( @_ );
}

sub postRenderingHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    #my $text = shift;
#    return unless (pluginApplies('view'));

   my $pluginPubUrl = TWiki::Func::getPubUrlPath().'/'.
            TWiki::Func::getTwikiWebname().'/'.$pluginName;

    #add the ComponentEdit JavaScript
    my $jscript = TWiki::Func::readTemplate ( 'componenteditplugin', 'javascript' );
    $jscript =~ s/%PLUGINPUBURL%/$pluginPubUrl/g;
    addToHEAD($pluginName, $jscript);

    #TODO: evaluate the MAKETEXT's, and the variables....
    $templateText = TWiki::Func::readTemplate ( 'componenteditplugin', 'popup' );
    $templateText = TWiki::Func::expandCommonVariables( $templateText, $TOPIC, $WEB );

    $_[0] =~ s/(<\/body>)/$templateText $1/g;
}

#a rest method
sub getEdit {
	my ($session) = shift;
    my $tml = $session->{cgiQuery}->param('tml');

#HARDCODED to SEARCH
    my $search = $tml;
    my $type = 'SEARCH';
    $search =~ s/%SEARCH{(.*)}%/$1/m;
	my $attrs = new TWiki::Attrs($search);

	my $helperform  = CGI::start_table( { border => 1, class => 'twikiTable' } );
#put DOCCO and defaultparameter first
    $helperform .= CGI::Tr(
                        CGI::Th($type),
                        CGI::Th('Value'),
#                        CGI::Th($syntax{$type}->{DOCUMENTATION}->{DOCCO}),
                        );

	$helperform .= CGI::hidden( -name=>'twikitagname', -default=>$type);

    foreach my $param_keys (keys (%{$syntax{$type}})) {
        next if ($param_keys eq 'DOCUMENTATION');

        my $value = getHtmlControlFor($type, $param_keys, $attrs);

        my @docco_attrs;
        push( @docco_attrs, title => $syntax{$type}->{$param_keys}->{DOCCO} );

	    $helperform .= CGI::Tr(
    		CGI::Td( { @docco_attrs }, $param_keys),
	    	CGI::Td($value),
#            CGI::Td($syntax{$type}->{$param_keys}->{DOCCO}),
		);
    }
	$helperform .= CGI::end_table();

    #TODO: evaluate the MAKETEXT's, and the variables....
    my $textarea = TWiki::Func::readTemplate ( 'componenteditplugin', 'popup' );
    $textarea = TWiki::Func::expandCommonVariables( $textarea, $TOPIC, $WEB );

    #unhide div
    $textarea =~ s/display:none;/display:inline;/g;

    $textarea =~ s/COMPONENTEDITPLUGINCUSTOM/$helperform/e;
    $textarea =~ s/COMPONENTEDITPLUGINTML/$tml/e;

    return $textarea;
}

##############################################################
#supporting functions

#return false if this plugin should not be active for this call
sub pluginApplies {
    my $scriptContext = shift;

    if ($TWiki::Plugins::VERSION > 1.025) {
        return 0 unless( TWiki::Func::getContext()->{$scriptContext} );
    } else {
        return 0 unless (TWiki::getPageMode() eq 'html');
        if( $ENV{"SCRIPT_FILENAME"} && $ENV{"SCRIPT_FILENAME"} =~ /^(.+)\/([^\/]+)$/ ) {
            my $script = $2;
            return 0 unless ($script eq $scriptContext);
        }
    }

    #lets only apply to the skins i've tested on (nat, pattern, classic, koala)
    return 0 unless (grep {TWiki::Func::getSkin() eq $_ } ('nat', 'pattern', 'classic', 'koala'));

    my $cgiQuery = TWiki::Func::getCgiQuery();
    #lets only work in text/html....
    #and not with any of the 'special' options (rev=, )
    my $getViewRev = $cgiQuery->param('rev');
    my $getViewRaw = $cgiQuery->param('raw');
    my $getViewContentType = $cgiQuery->param('contenttype');
    my $getViewTemplate = $cgiQuery->param('template');
    return 0 if ( (defined($getViewRev)) ||
                                    (defined($getViewRaw)) ||
                                    (defined($getViewContentType)) ||
                                    (defined($getViewTemplate)) );

    return 1;   #TRUE
}

sub getHtmlControlFor {
    my ($TMLtype, $param_key, $attrs) = @_;

    my $value;
    if (defined($syntax{$TMLtype}->{$param_key}->{defaultparameter}) &&
        $syntax{$TMLtype}->{$param_key}->{defaultparameter} eq 1) {
        $value = $attrs->{_DEFAULT} || $attrs->{$param_key} || '';
    } else {
        $value = $attrs->{$param_key} || '';
    }

##SPECIAL TYPE Shortcuts    
    if ($syntax{$TMLtype}->{$param_key}->{type} eq 'onoff') {
        $syntax{$TMLtype}->{$param_key}->{type}  = 'options';
        $syntax{$TMLtype}->{$param_key}->{option} = ['on', 'off'];
    }

    my $control;
    if ($syntax{$TMLtype}->{$param_key}->{type} eq 'text') {
        $control = CGI::textfield( -class=>'twikiEditFormError',
                                 -name=>$param_key,
                                 -size=>80,
                                 -value=>$value,
                                 -title=>$syntax{$TMLtype}->{$param_key}->{default},
                                 -onchange=>'TWiki.ComponentEditPlugin.inputFieldModified(event)',
                                 -onkeyup=>'TWiki.ComponentEditPlugin.inputFieldModified(event)',
                                 -twikidefault=>$syntax{$TMLtype}->{$param_key}->{default}
                    );
    } elsif ($syntax{$TMLtype}->{$param_key}->{type} eq 'dropdown') {
#        ASSERT( ref( $options )) if DEBUG;
        my $choices = '';
        foreach my $item ( $syntax{$TMLtype}->{$param_key}->{option} ) {
            my $selected = ( $item eq $value );
            $item =~ s/<nop/&lt\;nop/go;
            if( $selected ) {
                $choices .= CGI::option({ selected=>'selected' }, $item );
            } else {
                $choices .= CGI::option( $item );
            }
        }
        $control = CGI::Select( 
            {
                name=>$param_key,
                title=>$syntax{$TMLtype}->{$param_key}->{default},
                onchange=>'TWiki.ComponentEditPlugin.inputFieldModified(event)',
                twikidefault=>$syntax{$TMLtype}->{$param_key}->{default}
            },
            $choices );

    } elsif ($syntax{$TMLtype}->{$param_key}->{type} eq 'options') {
        my $options = $syntax{$TMLtype}->{$param_key}->{option};
#        ASSERT( ref( $options )) if DEBUG;
        my $selected = '';
        my %radio_attrs;
        foreach my $item ( @$options ) {
            $radio_attrs{$item} =
              { class=>'twikiEditFormRadioField twikiRadioButton',
                label=>$item,
                twikidefault=>$syntax{$TMLtype}->{$param_key}->{default}
                };     #$session->handleCommonTags( $item, $web, $topic ) };

            $selected = $item if( $item eq $value );
        }

        $control = CGI::radio_group( -name => $param_key,
                                   -values => $options,
                                   -default => $value || $syntax{$TMLtype}->{$param_key}->{default},
#                                   -columns => $size,
                                   -attributes => \%radio_attrs,
                                -onchange=>'TWiki.ComponentEditPlugin.inputFieldModified(event)',
                        );
    } else {
        $control = $value;
    }

    return $control;
}


##########################################################
#Cairo compat gumpf
sub registerRESTHandler {
    if ($TWiki::Plugins::VERSION eq 1.025) {
        my ($name, $funcRef) = @_;
        $TWikiCompatibility{RESTHandlers}{$pluginName.'.'.$name} = $funcRef;
    } else {
        TWiki::Func::registerRESTHandler(@_);
    }
}

#to fake TWiki4 restHanders in Cairo, use the view script (url is different too :( view/WEB/TOPIC?rest=InlineEditPlugin.restHandlerFuncName)
#and add this sub to your beforeCommonTagsHandler
sub fakeTWiki4RestHandlers {
    my ( $text, $topic, $web ) = @_;   #params passed on from beforeCommonTagsHandler
    #This is the view script based REST Handler cludge
   my $query = TWiki::Func::getCgiQuery();
   my $restCall = $query->param('rest');
    if (defined ($restCall) && defined($TWikiCompatibility{RESTHandlers}{$restCall})) {
        my $function = $TWikiCompatibility{RESTHandlers}{$restCall};
        print $query->header(
                    -content_type => 'text',
             );
        no strict 'refs';
        my $session = {};
        $session->{cgiQuery} = $query;
        my $result='';
        $result=&$function($session,$web,$topic);
        print $result;
        exit 1;
    }
}


sub addToHEAD {
    if ($TWiki::Plugins::VERSION eq 1.025) {
        my ($name, $text) = @_;
        $TWikiCompatibility{HEAD}{$name} = $text;
    } else {
        TWiki::Func::addToHEAD( @_ );
    }
}

#TODO:can i make this TWikiCompat too?
#this is only there to support the addition of HEAD sections
sub commonTagsHandler {
#    my ( $text, $topic, $web ) = @_;

    return unless ($_[0] =~ /<\/head>/);
     return unless (keys(%{$TWikiCompatibility{HEAD}}) > 0);

        #fake up addToHead for cairo
    if ($TWiki::Plugins::VERSION eq 1.025) {
        my $htmlHeader = join(
            "\n",
            map { '<!--'.$_.'-->'.$TWikiCompatibility{HEAD}{$_} }
                keys %{$TWikiCompatibility{HEAD}});
        $_[0] =~ s/([<]\/head[>])/$htmlHeader$1/i if $htmlHeader;
        chomp($_[0]);

        %{$TWikiCompatibility{HEAD}} = ();
    }
}

sub setupTWiki4Compatibility {
    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.025 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm (tested on Cairo and TWiki-4.0))" );
        return 0;
    } elsif ($TWiki::Plugins::VERSION eq 1.025) {
        #Cairo
        %{$TWikiCompatibility{HEAD}} = ();
        %{$TWikiCompatibility{HEAD}} = ();
    } else {
        #TWiki-4.0 and above
    }
}
1;
