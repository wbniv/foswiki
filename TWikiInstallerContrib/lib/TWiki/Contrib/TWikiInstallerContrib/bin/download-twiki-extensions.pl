#! /usr/bin/perl -w
################################################################################
# download-twiki-plugins.pl
# Copyright 2004 Will Norris.  All Rights Reserved.
# License: GPL
#
# mirrors plugins locally from their distribution/topic pages
# prints out a report (suitable for inclusion as a twiki page)
#
################################################################################
use strict;
use diagnostics;
++$|;
use Data::Dumper qw( Dumper );

use lib( "$ENV{TWIKIDEV}/CPAN/lib" ); # good enough because this only uses pure perl cpan modules

use LWP::Simple qw( mirror RC_OK RC_NOT_MODIFIED );
use File::Path qw( mkpath );
use HTML::TokeParser;

################################################################################
# config
my $Config = {
    plugins => {
	local_cache => 'downloads/plugins/',
	twiki => {
	    pub => 'http://twiki.org/p/pub/',
	},
	searchTerm => '%5BT%5DopicClassification.*value%5C%3D%5C%22%5BP%5DluginPackage',
	ExtType => 'Plugin',
    },
    contribs => {
	local_cache => 'downloads/contribs/',
	twiki => {
	    pub => 'http://twiki.org/p/pub/',
	},
	searchTerm => '%5BT%5DopicClassification.*value%5C%3D%5C%22%5BC%5DontribPackage',
	ExtType => 'Contrib',
    },
    addons => {
        local_cache => 'downloads/addons/',
	twiki => {
	    pub => 'http://twiki.org/p/pub/',
	},
	searchTerm => '%5BT%5DopicClassification.*value%5C%3D%5C%22%5BA%5DddOnPackage',
	ExtType => 'AddOn',
    },
};

################################################################################

my @configs = @ARGV ? @ARGV : keys %$Config;
foreach my $k ( @configs )
{
    my $iConfig = $Config->{$k} or die qq{No Config named "$k"\n};
    print STDERR Dumper( $iConfig ) . "\n" if $Config->{debug};
    my $ext = DownloadTWikiExtension( $iConfig );
    print STDERR Dumper( $ext ) if $Config->{debug};
    print GenerateSummaryReport( $ext );
    SaveXML( $iConfig, $ext );
}

################################################################################
################################################################################

sub GenerateSummaryReport
{
    my $ext = shift;
    my $text = '';

    # print summary results (suitable for inclusion as a TWiki page)
    $text .= "| *Plugins Processed* | $ext->{nDownloadedPlugins}/$ext->{nPlugins} |";
    $text .= "\n\n";
    local $, = "\n   * TWiki:Plugins.";
    $text .= "Missing/Error plugin topics: @{ $ext->{errors} }";
    $text .= "\n";

    return $text;
}

################################################################################

sub SaveXML
{
    my ( $Config, $ext ) = @_;

    use XML::Simple;
    my $xs = new XML::Simple() or die $!;
    open( XML, ">$Config->{local_cache}/" . lc($Config->{ExtType}) . "s.xml" ) or die $!;
    print XML $xs->XMLout( { lc($Config->{ExtType}) => $ext->{plugins} }, NoAttr => 1 );
    close( XML ) or warn $!;
}

################################################################################

sub DownloadTWikiExtension
{
    my ( $Config ) = @_;

    mkpath $Config->{local_cache} or die $! unless -d $Config->{local_cache};
    my $self = {
	nPlugins => 0,
	nDownloadedPlugins => 0,
	errors => [],
	plugins => getCatalogueList({ Config => $Config }),
    };

    print "| *Plugin* | *Download Status* |\n";
    foreach my $pluginS ( @{ $self->{plugins} } )
    {
	my $plugin = $pluginS->{name} or die "no name?";
	
	print "| TWiki:Plugins.$plugin ";
	++$self->{nPlugins};
	
	# download plugin
	my $status = mirror( 
			     my $remote_uri = "$Config->{twiki}->{pub}/Plugins/$plugin/$plugin.zip",
			     my $local_file = "$Config->{local_cache}/$plugin.zip"
			     );
	
	if ($status == RC_OK) {
	    ++$self->{nDownloadedPlugins};
	    print "| downloaded |\n";
#	    $pluginS->{file} = $local_file;
	} elsif ($status != RC_NOT_MODIFIED) {
	    print "| $!: $remote_uri |\n";
	    push @{ $self->{errors} }, "Plugins.$plugin";
	} else {
	    ++$self->{nDownloadedPlugins};
	    print "| up-to-date |\n";
#?	    $pluginS->{file} = $local_file;
	}
	
	# read SHORTDESCRIPTION from the plugin (configuration) topic file
	if ( -e $local_file && ( my @shortDescription = `unzip -c $local_file "*/$plugin.txt" | grep "\* Set SHORTDESCRIPTION"` ) )
#	    "*/data/*/$plugin.txt" doesn't always work (but probably should)
	{
	    #[match:]* Set SHORTDESCRIPTION = Dynamic generation of TWiki topic trees 
	    #ASSERT( @shortDescription == 1 );
	    ( $pluginS->{description} ) = $shortDescription[0] =~ /Set\s+?SHORTDESCRIPTION\s+?=\s+?(.+?)\r?$/;
	}

    }

    return $self;
}

################################################################################

sub getCatalogueList
{
    my $p = shift;
    my $Config = $p->{Config};

    my $urlCatalogue = qw( http://twiki.org/cgi-bin/search/Plugins/?scope=text&web=Plugins&order=topic&search= ) . $Config->{searchTerm} . qw( &casesensitive=on&regex=on&nosearch=on&nosummary=on&limit=all&skin=plain );
    my $local_catalogue = "$Config->{local_cache}/TWiki$Config->{ExtType}s.html";

    # get (plugins) catalogue page
    mirror( $urlCatalogue, $local_catalogue );
    my $pluginsCataloguePage = LWP::Simple::get( "file:$local_catalogue" ) or die qq{Can't get plugins catalogue "$local_catalogue": $!};

    # get list of plugins (from the links)
    my @plugins = qw();

    my $stream = new HTML::TokeParser( \$pluginsCataloguePage ) or die $!;
    while ( my $tag = $stream->get_tag('a'))
    {
	next unless $tag->[1]{href};
	my ( $plugin ) = $tag->[1]{href} =~ m|/view/Plugins/(.+$Config->{ExtType})$|;
	next unless $plugin;

	push @plugins, { 
	    name => $plugin,
	    homepage => "http://twiki.org/cgi-bin/view/Plugins/$plugin",
	};
    }

    return \@plugins;
}

################################################################################
