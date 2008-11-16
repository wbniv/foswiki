# /usr/bin/perl -w
use strict;
#
# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2003 Will Norris, wbniv@saneasylumstudios.com
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
################################################################################
package TWiki::Plugins::IrcLogPlugin;
use vars qw( @ISA $VERSION );

use TWiki::Plugins::OoPlugin;
$VERSION = '1.00';
@ISA = ( 'TWiki::Plugins::OoPlugin' );

my %prefs_colours = (
	"part"			=>	"#000099",
	"join"			=>	"#009900",
	"server"		=>	"#009900",
	"nickchange"	=>	"#009900",
	"action"		=>	"#CC00CC",
);


sub new
{
    my $classname = shift;
    my $self = $classname->SUPER::new( @_ );
    $self->_init( @_ );
    return $self;
}

sub DESTROY
{
    my $self = shift;
}

sub _init
{
    my $self = shift;
    $self->SUPER::_init( @_ );

#    my $key = 'action';
#    $prefs_colours{$key} = $self->SUPER::getPreferencesValue( "colour_action" );# || '#c0c';
#    print STDERR "'$key' = [", $prefs_colours{$key}, "]\n";

#    $prefs_colours{'part'} = $thePlugin->getPreferencesValue( 'COLOUR_PART' ) || '#009';

    $self->init_();
    return 1;
}

################################################################################

sub handleIrcLog 
{ 
    my ( $attributes ) = @_;

    my $topic = scalar TWiki::Func::extractNameValuePair( $attributes, "topic" );
    my $web = scalar TWiki::Func::extractNameValuePair( $attributes, "web" );
    my $href = scalar TWiki::Func::extractNameValuePair( $attributes, 'href' );

    my $text;
    if ( $href )
    {
        # This block replaces a call to: wget -O - $href
        # Don't use wget, use LWP instead
        require LWP;
	my $ua = new LWP::UserAgent;
	# Load proxy settings
	$ua->env_proxy;
	my $request = HTTP::Request->new( 'GET' );
	$request->url( $href );
	my response = $ua->request( $request );
	$text = $response->content;
    }
    elsif ( $topic || $web )
    {
	$topic ||= $TWiki::topicName;
	$web ||= $TWiki::webName;
	( undef, $text ) = TWiki::Func::readTopic( $web, $topic );
    }
    else
    {
	$text = &TWiki::Func::extractNameValuePair( $attributes, "" );
    }

#    print STDERR "web=[$web]\n",
#    "topic=[$topic]\n",
#    "href=[$href]\n",
#    "text=[$text]\n",
#    '';
	
    return irclog2html( $text );
}


sub _commonTagsHandler
{
    my $self = shift;
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead
    $self->SUPER::_commonTagsHandler( @_ );

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%
    $_[0] =~ s|%IRCLOG%|handleIrcLog()|geo;
    $_[0] =~ s|%IRCLOG{(.+?)}%|handleIrcLog($1)|geos;
}

################################################################################

use vars qw( $thePlugin ); 

sub initPlugin
{
    my ( $topic, $web, $user, $installWeb ) = @_;
    $thePlugin =  __PACKAGE__->new( topic => $topic, web => $web, user => $user, installWeb => $installWeb,
				    name => 'IrcLog',
				    );
    return 1;
}

################################################################################



################################################################################
################################################################################
# irclog2html.pl Version 2.1 - 27th July, 2001
# Copyright (C) 2000, Jeffrey W. Waugh

# Author:
#   Jeff Waugh <jdub@perkypants.org>

# Contributors:
#   Rick Welykochy <rick@praxis.com.au>
#   Alexander Else <aelse@uu.net>

# Released under the terms of the GNU GPL
# http://www.gnu.org/copyleft/gpl.html
################################################################################
# modified by Will Norris, 07 Nov 2003
################################################################################

my $txtLog;

my $VERSION = "2.1";
my $RELEASE = "27th July, 2001";


# Colouring stuff
my $a = 0.95;			# tune these for the starting and ending concentrations of R,G,B
my $b = 0.5;
my $rgb = [ [$a,$b,$b], [$b,$a,$b], [$b,$b,$a], [$a,$a,$b], [$a,$b,$a], [$b,$a,$a] ];

my $rgbmax = 125;		# tune these two for the outmost ranges of colour depth
my $rgbmin = 240;


####################################################################################
# Preferences

# Comment out the "table" assignment to use the plain version

my %prefs_colour_nick = (
	"jdub"			=>	"#993333",
	"cantanker"		=>	"#006600",
	"chuckd"		=>	"#339999",
);

my %prefs_styles = (
	"simplett"		=>	"Text style with little use of colour",
	"tt"			=>	"Text style using colours for each nick",
	"simpletable"	=>	"Table style, without heavy use of colour",
	"table"			=>	"Default style, using a table with bold colours",
);

my $STYLE = "table";


####################################################################################
# Utility Functions & Variables

sub output_nicktext {
	my ($nick, $text, $htmlcolour) = @_;

	if ($STYLE eq "table") {
		$txtLog .= "<tr><th bgcolor=\"$htmlcolour\"><font color=\"#ffffff\"><tt>$nick</tt></font></th>";
		$txtLog .= "<td width=\"100%\" bgcolor=\"#eeeeee\"><tt><font color=\"$htmlcolour\">$text<\/font></tt></td></tr>\n";
	} elsif ($STYLE eq "simpletable") {
		$txtLog .= "<tr bgcolor=\"#eeeeee\"><th><font color=\"$htmlcolour\"><tt>$nick</tt></font></th>";
		$txtLog .= "<td width=\"100%\"><tt>$text</tt></td></tr>\n";
	} elsif ($STYLE eq "simplett") {
		$txtLog .= "&lt\;$nick&gt\; $text<br />\n";
	} else {
		$txtLog .= "<font color=\"$htmlcolour\">&lt\;$nick&gt\;<\/font> <font color=\"#000000\">$text<\/font><br />\n";
	}
}

sub output_servermsg {
	my ($line) = @_;

	if ($STYLE =~ /table/) {
		$txtLog .= "<tr><td colspan=2><tt>$line</tt></td></tr>\n";
	} else {
		$txtLog .= "$line<br />\n";
	}
}

sub html_rgb
{
	my ($i,$ncolours) = @_;
	$ncolours = 1 if $ncolours == 0;

	my $n = $i % @$rgb;
	my $m = $rgbmin + ($rgbmax - $rgbmin) * ($ncolours - $i) / $ncolours;

	my $r = $rgb->[$n][0] * $m;
	my $g = $rgb->[$n][1] * $m;
	my $b = $rgb->[$n][2] * $m;
	sprintf("#%02x%02x%02x",$r,$g,$b);
}


################################################################################
# Main

sub irclog2html
{
    $txtLog = '';
    my ( $log ) = @_;

	my $inputfile;

	my $nick;
	my $time;
	my $text;

	my $htmlcolour;
	my $nickcount = 0;
	my $NICKMAX = 30;

	my %colours = %prefs_colours;
	my %colour_nick = %prefs_colour_nick;
	my %styles = %prefs_styles;

	if ($STYLE =~ /table/) {
		$txtLog .= "<table cellspacing=3 cellpadding=2 border=0>\n";
	}

    my @logs = split( /\n/, $log );
    foreach my $line ( @logs )
    {
		chomp $line;

		if ($line ne "") {

			# Replace ampersands, pointies, control characters #
			$line =~ s/&/&amp\;/g;
			$line =~ s/</&lt\;/g;
			$line =~ s/>/&gt\;/g;
			$line =~ s/[\x00-\x1f]+//g;

			# Replace possible URLs with links #
#			$line =~ s/((http|https|ftp|gopher|news):\/\/\S*)/<a href="$1">$1<\/a>/g;

			# Rip out the time #
			if ($line =~ /^\[?\d\d:\d\d(:\d\d)?\]? .*$/) {
				$time = $line;
				$time =~ s/^\[?(\d\d:\d\d(:\d\d)?)\]? .*$/$1/;
				$line =~ s/^\[?\d\d:\d\d(:\d\d)?\]? (.*)$/$2/;
#				print $time if $debug;
			}

			# Colourise the comments
			if ($line =~ /^&lt\;.*?&gt\;\s.*/) {

				# Split $nick and $line
				$nick = $line;
				$nick =~ s/^&lt\;(.*?)&gt\;\s.*$/$1/;

				# $nick =~ tr/[A-Z]/[a-z]/;
				# <======= move this into another function when getting nick colour

				$text = $line;
				$text =~ s/^&lt\;.*?&gt\;\s(.*)$/$1/;
				$text =~ s/  /&nbsp\;&nbsp\;/g;

				$htmlcolour = $colour_nick{$nick};
				if (!defined($htmlcolour)) {
					# new nick
					$nickcount++;

					# if we've exceeded our estimate of the number of nicks, double it
					$NICKMAX *= 2 if $nickcount >= $NICKMAX;

					$htmlcolour = $colour_nick{$nick} = html_rgb($nickcount, $NICKMAX);
				}
				output_nicktext($nick, $text, $htmlcolour);
				
			} else {
				# Colourise the /me's #
				if ($line =~ /^\* .*$/) {
					$line =~ s/^(\*.*)$/<font color=\"$colours{"action"}\">$1<\/font>/;
				}

				# Colourise joined/left messages #
				elsif ($line =~ /^(\*\*\*|--&gt;) .*joined/) {
					$line =~ s/(^(\*\*\*|--&gt;) .*)/<font color=\"$colours{"join"}\">$1<\/font>/;
				}
				elsif ($line =~ /^(\*\*\*|&lt;--) .*left|quit/) {
					$line =~ s/(^(\*\*\*|&lt;--) .*)/<font color=\"$colours{"part"}\">$1<\/font>/;
				}
				
				# Process changed nick results, and remember colours accordingly #
				elsif ($line =~ /^(\*\*\*|---) (.*?) are|is now known as (.*)/) {
					my $nick_old;
					my $nick_new;
					
					$nick_old = $line;
					$nick_old =~ s/^(\*\*\*|---) (.*?) (are|is) now known as .*/$1/;

					$nick_new = $line;
					$nick_new =~ s/^(\*\*\*|---) .*? (are|is) now known as (.*)/$2/;

					$colour_nick{$nick_new} = $colour_nick{$nick_old};
					$colour_nick{$nick_old} = undef;

					$line =~ s/^((\*\*\*|---) .*)/<font color=\"$colours{"nickchange"}\">$1<\/font>/
				}
				# server messages
				elsif ($line =~ /^(\*\*\*|---) /) {
					$line =~ s/^((\*\*\*|---) .*)$/<font color=\"$colours{"server"}\">$1<\/font>/;
				}

				output_servermsg($line);
			}
		}
	}

	if ($STYLE =~ /table/) {
		$txtLog .= "</table>\n";
	}

	$txtLog .= qq{</tt>};

    return $txtLog;
}

1;
