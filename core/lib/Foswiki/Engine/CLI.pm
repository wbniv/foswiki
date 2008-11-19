# Module of Foswiki - The Free Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
# and Foswiki Contributors. All Rights Reserved. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This module is based/inspired on Catalyst framework. Refer to
#
# http://search.cpan.org/~mramberg/Catalyst-Runtime-5.7010/lib/Catalyst.pm
#
# for credits and liscence details.
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

=begin twiki

---+!! package Foswiki::Engine::CLI

Class that implements CGI scripts functionality when called from
command line or cron job

Refer to Foswiki::Engine documentation for explanation about methos below.

=cut

package Foswiki::Engine::CLI;

use strict;
use base 'Foswiki::Engine';
use Foswiki::Request;
use Foswiki::Request::Upload;
use Foswiki::Response;

sub run {
    my $this = shift;
    my @args = @ARGV;    # Copy, so original @ARGV doesn't get modified
    while ( scalar @args ) {
        my $arg = shift @args;
        if ( $arg =~ /^-?([A-Za-z0-9_]+)(?:=(.*))?$/o ) {
            my $name = $1;
            my $arg  = Foswiki::Sandbox::untaintUnchecked(
                defined $2 ? $2 : ( shift @args ) );
            if ( $name eq 'user' ) {
                $this->{user} = $arg;
            }
            else {
                push @{ $this->{plist} }, $name
                  unless exists $this->{params}->{$name};
                push @{ $this->{params}->{$name} }, $arg;
            }
        }
        else {
            $this->{path_info} = Foswiki::Sandbox::untaintUnchecked($arg);
        }
    }
    my $req = $this->prepare;
    if ( UNIVERSAL::isa( $req, 'Foswiki::Request' ) ) {
        my $res = Foswiki::UI::handleRequest($req);
        $this->finalize( $res, $req );
    }
}

sub prepareConnection {
    my ( $this, $req ) = @_;
    $req->remoteAddress('127.0.0.1');
}

sub prepareQueryParameters {
    my ( $this, $req ) = @_;
    foreach my $name ( @{ $this->{plist} } ) {
        $req->param( -name => $name, -value => $this->{params}->{$name} );
    }
    delete $this->{plist};
    delete $this->{params};
}

sub prepareHeaders {
    my ( $this, $req ) = @_;
    if ( defined $this->{user} ) {
        $req->remoteUser( $this->{user} );
        delete $this->{user};
    }
    else {
        $req->remoteUser( $Foswiki::cfg{SuperAdminGroup} );
    }
}

sub preparePath {
    my ( $this, $req ) = @_;
    $req->action( $ENV{TWIKI_ACTION} );
    delete $ENV{TWIKI_ACTION};
    if ( exists $this->{path_info} ) {
        $req->pathInfo( $this->{path_info} );
        delete $this->{path_info};
    }
}

sub prepareCookies { }

sub finalizeHeaders { }

sub write {
    my ( $this, $buffer ) = @_;
    print $buffer;
}

1;
