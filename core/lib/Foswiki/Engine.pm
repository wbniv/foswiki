# See bottom of file for license and copyright information
=pod

---+!! package Foswiki::Engine

The engine class is a singleton that implements details about Foswiki's
execution mode. This is the base class and implements basic behavior.

Each engine should inherits from this and overload methods necessary
to achieve correct behavior.

=cut

package Foswiki::Engine;

use strict;
use Error qw( :try );
use Assert;
use Scalar::Util;

=begin twiki

---++ ObjectMethod CRLF() -> $crfl

Utility constant. Defined as sub thus can be used from
children objects.

=cut

sub CRLF { "\x0D\x0A" }

=begin twiki

---++ ClassMethod new() -> $engine

Constructs an engine object.

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $this  = {};
    return bless $this, $class;
}

=begin twiki

---++ ObjectMethod run()

Start point to Runtime Engines.

=cut

sub run {
    my $this = shift;
    my $req  = $this->prepare;
    if ( defined $req ) {
        my $res = Foswiki::UI::handleRequest($req);
        $this->finalize( $res, $req );
    }
}

=begin twiki

---++ ObjectMethod prepare() -> $req

Initialize a Foswiki::Request object by calling many preparation methods
and returns it, or a status code in case of error.

=cut

sub prepare {
    my $this = shift;
    my $req;
    try {
        $req = Foswiki::Request->new();
        $this->prepareConnection($req);
        $this->prepareQueryParameters($req);
        $this->prepareHeaders($req);
        $this->prepareCookies($req);
        $this->preparePath($req);
        $this->prepareBody($req);
        $this->prepareBodyParameters($req);
        $this->prepareUploads($req);
    }
    catch Foswiki::EngineException with {
        my $e   = shift;
        my $res = $e->{response};
        unless ( defined $res ) {
            $res = new Foswiki::Response();
            $res->header( -type => 'text/html', -status => $e->{status} );
            my $html = CGI::start_html( $e->{status} . ' Bad Request' );
            $html .= CGI::h1('Bad Request');
            $html .= CGI::p( $e->{reason} );
            $html .= CGI::end_html();
            $res->body($html);
        }
        $this->finalizeError($res);
        return $e->{status};
    }
    otherwise {
        my $e   = shift;
        my $res = Foswiki::Response->new();
        $res->header( -type => 'text/plain' );
        if (DEBUG) {

            # output the full message and stacktrace to the browser
            $res->body( $e->stringify() );
        }
        else {
            my $mess = $e->stringify();
            print STDERR $mess;

            # tell the browser where to look for more help
            my $text =
'Foswiki detected an internal error - please check your Foswiki logs and webserver logs for more information.'
              . "\n\n";
            $mess =~ s/ at .*$//s;

            # cut out pathnames from public announcement
            $mess =~ s#/[\w./]+#path#g;
            $text .= $mess;
            $res->body($text);
        }
        $this->finalizeError($res);
        return 500;    # Internal server error
    };
    return $req;
}

=begin twiki

---++ ObjectMethod prepareConnection( $req )

Abstract method, must be defined by inherited classes.
   * =$req= - Foswiki::Request object to populate

Should fill remoteAddr, method and secure fields of =$req= object.

=cut

sub prepareConnection { }

=begin twiki

---++ ObjectMethod prepareQueryParameters( $req, $queryString )

Should fill $req's query parameters field.

This method populates $req as it should if given $queryString parameter.
Subclasses may redefine this method and call SUPER with query string obtained.

=cut

sub prepareQueryParameters {
    my ( $this, $req, $queryString ) = @_;
    my @pairs = split /[&;]/, $queryString;
    my ( $param, $value, %params, @plist );
    foreach (@pairs) {
        ( $param, $value ) =
          map { tr/+/ /; s/%([0-9a-fA-F]{2})/chr(hex($1))/oge; $_ }
          split '=', $_, 2;
        push @{ $params{$param} }, $value;
        push @plist, $param;
    }
    foreach my $param (@plist) {
        $req->queryParam( $param, $params{$param} );
    }
}

=begin twiki

---++ ObjectMethod prepareHeaders( $req )

Abstract method, must be defined by inherited classes.
   * =$req= - Foswiki::Request object to populate

Should fill $req's headers and remoteUser fields.

=cut

sub prepareHeaders { }

=begin twiki

---++ ObjectMethod preparePath( $req )

Abstract method, must be defined by inherited classes.
   * =$req= - Foswiki::Request object to populate

Should fill $req's uri and pathInfo fields.

=cut

sub preparePath { }

=begin twiki

---++ ObjectMethod prepareCookies( $req )

   * =$req= - Foswiki::Request object to populate

Should fill $req's cookie field. This method take cookie data from
previously populated headers field and initializes from it. Maybe 
doesn't need to overload in children classes.

=cut

sub prepareCookies {
    my ( $this, $req ) = @_;
    eval { require CGI::Cookie };
    throw Error::Simple($@) if $@;
    $req->cookies( scalar CGI::Cookie->parse( $req->header('Cookie') ) )
      if $req->header('Cookie');
}

=begin twiki

---++ ObjectMethod prepareBody( $req )

Abstract method, must be defined by inherited classes.
   * =$req= - Foswiki::Request object to populate

Should perform any initialization tasks related to body processing.

=cut

sub prepareBody { }

=begin twiki

---++ ObjectMethod prepareBodyParameters( $req )

Abstract method, must be defined by inherited classes.
   * =$req= - Foswiki::Request object to populate

Should fill $req's body parameters.

=cut

sub prepareBodyParameters { }

=begin twiki

---++ ObjectMethod prepareUploads( $req )

Abstract method, must be defined by inherited classes.
   * =$req= - Foswiki::Request object to populate

Should fill $req's uploads field. Its a hashref whose keys are
parameter names and values Foswiki::Request::Upload objects.

=cut

sub prepareUploads { }

=begin twiki

---++ ObjectMethod finalize($res, $req)

Finalizes the request by calling many methods to send response to client and 
take any appropriate finalize actions, such as delete temporary files.
   * =$res= is the Foswiki::Response object
   * =$req= it the Foswiki::Request object.

=cut

sub finalize {
    my ( $this, $res, $req ) = @_;
    $this->finalizeUploads($res, $req);
    $this->finalizeHeaders( $res, $req );
    $this->finalizeBody($res);
}

=begin twiki

---++ ObjectMethod finalizeUploads( $res, $req )

Abstract method, must be defined by inherited classes.
   * =$res= - Foswiki::Response object to get data from
   * =$req= - Foswiki::Request object to get data from

Should delete any temp files created in preparation phase.

=cut

sub finalizeUploads { }

=begin twiki

---++ ObjectMethod finalizeError( $res )

Called if some engine especific error happens.

   * =$res= - Foswiki::Response object to get data from

=cut

sub finalizeError {
    my ( $this, $res ) = @_;
    $this->finalizeHeaders($res);
    $this->finalizeBody($res);
}

=begin twiki

---++ ObjectMethod finalizeHeaders( $res, $req )

Base method, must be redefined by inherited classes. For convenience
this method deals with HEAD requests related stuff. Children classes
should call SUPER.
   * =$res= - Foswiki::Response object to get data from
   * =$req= - Foswiki::Request object to get data from

Should call finalizeCookies and then send $res' headers to client.

=cut

sub finalizeHeaders {
    my ( $this, $res, $req ) = @_;
    $this->finalizeCookies($res);
    if ( $req && $req->method() eq 'HEAD' ) {
        $res->body('');
        $res->deleteHeader('Content-Length');
    }
}

=begin twiki

---++ ObjectMethod finalizeCookies( $res )

   * =$res= - Foswiki::Response object to both get data from and populate

Should populate $res' headers field with cookies, if any.

=cut

sub finalizeCookies {
    my ( $this, $res ) = @_;

    # SMELL: Review comment below, from CGI:
    #    if the user indicates an expiration time, then we need
    #    both an Expires and a Date header (so that the browser is
    #    uses OUR clock)
    $res->pushHeader( 'Set-Cookie',
        Scalar::Util::blessed $_
          && $_->isa('CGI::Cookie') ? $_->as_string : $_ )
      foreach $res->cookies;
}

=begin twiki

---++ ObjectMethod finalizeBody( $res )

   * =$res= - Foswiki::Response object to get data from

Should send $res' body to client. This method calls =write()=
as needed, sou engines should redefine that method insted of this one.

=cut

sub finalizeBody {
    my ( $this, $res ) = @_;
    my $body = $res->body;
    return unless $body;
    $this->prepareWrite($res);
    if ( Scalar::Util::blessed($body) && $body->can('read')
        or ref $body eq 'GLOB' )
    {
        while ( !eof $body ) {
            read $body, my $buffer, 4096;
            last unless $this->write($buffer);
        }
        close $body;
    }
    else {
        $this->write($body);
    }
}

=begin twiki

---++ ObjectMethod prepareWrite( $res )

Abstract method, must be defined by inherited classes.
   * =$res= - Foswiki::Response object to get data from

Shold perform any task needed before writing.
That's ok if none needed ;-)

=cut

sub prepareWrite { }

=begin twiki

---++ ObjectMethod write( $buffer )

Abstract method, must be defined by inherited classes.
   * =$buffer= - chunk of data to be sent

Should send $buffer to client.

=cut

sub write {
    ASSERT('Pure virtual method - should never be called');
}

1;
__DATA__
# Module of Foswiki - The Free Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008 Foswiki Contributors. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
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
