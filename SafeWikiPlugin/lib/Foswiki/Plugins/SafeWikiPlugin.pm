# See bottom of file for notices
package Foswiki::Plugins::SafeWikiPlugin;

use strict;
use Assert;

require Foswiki::Plugins::SafeWikiPlugin::Parser;

our $VERSION = '$Rev$';
our $RELEASE = '1.0';
our $SHORTDESCRIPTION = 'Secure your Foswiki so it can\'t be used for mounting phishing attacks';
our $NO_PREFS_IN_TOPIC = 1;

our $URIFILTER;
our $CODEFILTER;
our $parser;

sub initPlugin {
    #my( $topic, $web, $user, $installWeb ) = @_;

    unless( $parser ) {
        $parser = new Foswiki::Plugins::SafeWikiPlugin::Parser();
    }

    return $parser ? 1 : 0;
}

# Handle the complete HTML page about to be sent to the browser
sub completePageHandler {
    #my($html, $httpHeaders) = @_;

    return unless $_[1] =~ m#^Content-type: text/html#mi;

    # Parse the HTML and generate a parse tree
    # This handler can be patched into pre-4.2 revs of Foswiki
    my $tree = $parser->parseHTML( $_[0] );

    # Now re-generate HTML, applying security constraints as we go.
    $_[0] = $tree->generate(\&_filterURI, \&_filterHandler);

    # For debugging the HTML parser, use a null filter
    #$_[0] = $tree->generate(\&dummyFilter, sub { $_[0]; });
}

sub _filterURI {
    my $uri = shift;
    return '' unless $uri;
    unless (defined($URIFILTER)) {
        # the eval expands $Foswiki::cfg vars
        $URIFILTER =
          join('|', map {s/(\$Foswiki::cfg({.*?})+)/eval($1)/ge; "($_)" }
                 @{$Foswiki::cfg{Plugins}{SafeWikiPlugin}{SafeURI}});
    }
    return $uri if $uri =~ /$URIFILTER/o;
    Foswiki::Func::writeWarning("SafeWikiPlugin: Disarmed URI '$uri' on "
                                .$ENV{REQUEST_URI}.$ENV{QUERY_STRING});
    return $Foswiki::cfg{Plugins}{SafeWikiPlugin}{DisarmURI} ||
      'URI filtered by SafeWikiPlugin';
}

sub _filterHandler {
    my $code = shift;
    return '' unless $code;
    unless (defined($CODEFILTER)) {
        # the eval expands $Foswiki::cfg vars
        $CODEFILTER =
          join('|', map { s/(\$Foswiki::cfg({.*?})+)/eval($1)/ge; qr/($_)/ }
                 @{$Foswiki::cfg{Plugins}{SafeWikiPlugin}{SafeHandler}});
    }
    return $code if $code =~ /$CODEFILTER/o;
    Foswiki::Func::writeWarning("SafeWikiPlugin: Disarmed on* '$code' on "
                                .$ENV{REQUEST_URI}.$ENV{QUERY_STRING});
    return $Foswiki::cfg{Plugins}{SafeWikiPlugin}{DisarmHandler};
}

1;
__DATA__

Copyright (C) 2007-2008 C-Dot Consultants http://c-dot.co.uk
All rights reserved
Author: Crawford Currie

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details, published at
http://www.gnu.org/copyleft/gpl.html

This notice must be retained in all copies or derivatives of this
code.
