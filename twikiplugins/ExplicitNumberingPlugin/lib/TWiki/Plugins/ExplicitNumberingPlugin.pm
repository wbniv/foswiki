# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2003 Peter Thoeny, peter@thoeny.com
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

# =========================
package TWiki::Plugins::ExplicitNumberingPlugin; 

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $pluginName
        $debug
    );

# This should always be $Rev: 12029 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 12029 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'ExplicitNumberingPlugin';  # Name of this Plugin


my $maxLevels = 6;		# Maximum number of levels
my %Sequences;			# Numberings, addressed by the numbering name
my $lastLevel = $maxLevels - 1;	# Makes the code more readable
my @alphabet = ('a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z');

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }


    $debug = TWiki::Func::getPreferencesFlag( "\U$pluginName\E_DEBUG" );

    # Plugin correctly initialized
    ##TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;

    return 1;
}

# =========================
# Need to move =makeExplicitNumber= into =commonTagsHandler= to support
# auto-numbering of heading levels, otherwise the TOC lines will have
# different number than the heading line (must be done before TOC).

sub commonTagsHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    ##TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $web.$topic )" ) if $debug;

    return if $_[3];   # Called in an include; do not number yet.

    %Sequences = ();

    $_[0] =~ s/\-\-\-(\#\#*) /&makeHeading(length($1))/geo;
    $_[0] =~ s/\#\#(\w+\#)?([0-9]+)?\.(\.*)([a-z]?)/&makeExplicitNumber($1,$2,length($3),$4)/geo;
}

# =========================

sub makeHeading {
    my $headerlvl = shift || 0;
    my $headerlevel = ($headerlvl)?'---':'';
    my $numlevel = '##';
    for (my $i=0;$i<$headerlvl;$i++) {
      $headerlevel .= '+';
      $numlevel .= '.';
    }
    return $headerlevel . $numlevel . ' ';
}

# Build the explicit outline number
sub makeExplicitNumber
{

    ##TWiki::Func::writeDebug( "- ${pluginName}::makeExplicitNumber( $_[0], $_[1], $_[2], $_[3] )" ) if $debug;

    my $name = '-default-';
    my $init = '';
    my $level = $_[2];
    my $alist = '';
    $name = $_[0] if defined $_[0];
    $init = $_[1] if defined $_[1];
    $alist = $_[3] if defined $_[3];
    if ( $alist ne '' ) {
        $level++;
    }

    my $text = '';

    #...Truncate the level count to maximum allowed
    if ($level > $lastLevel) { $level = $lastLevel; }

    #...Initialize a new, or get the current, numbering from the Sequences
    my @Numbering = ();
    if ( ! defined( $Sequences{$name} ) ) {
        for $i ( 0 .. $lastLevel ) { $Numbering[$i] = 0; }
    } else {
        @Numbering = split(':', $Sequences{$name} );
	#...Re-initialize the sequence
	if ( defined $_[1] ) {
	  $init = (int $init);
	  if ( $init ) {
	    $Numbering[$level] = $init - 1;
	  } else {
	    for $i ( 0 .. $lastLevel ) { $Numbering[$i] = 0; }
	}
	}
    }

    #...Increase current level number
    $Numbering[ $level ] += 1;

    #...Reset all higher level counts
    if ( $level < $lastLevel ) {
        for $i ( ($level+1) .. $lastLevel ) { $Numbering[$i] = 0; }
    }

    #...Save the altered numbering
    $Sequences{$name} =  join( ':', @Numbering );

    #...Construct the number
    if ( $alist eq '' ) {
	for $i ( 0 .. $level ) {
	    $text .= "$Numbering[$i]";
	    $text .= '.' if ( $i < $level );
	}
    } else {
	#...Level is 1-origin, indexing is 0-origin
	$text .= $alphabet[$Numbering[$level]-1]
    }

    return $text;
}

# =========================

1;
