# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2007 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root of
# this distribution.
# NOTE: Please extend that file, not this notice.
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

=pod twiki

---+ package TWiki::EngineException

Exception used to raise an engine related error. This exception has the
following fields:
   * =status= - status code to send to client
   * =reason= a text string giving the reason for the refusal.

=cut

package TWiki::EngineException;
use base 'Error';

use strict;

=pod

---+ ClassMethod new( $status, $reason [, $response] )

   * =$status= - status code to send to client
   * =$reason= - string reason for failure
   * =$response= - custom TWiki::Response object to be sent to client. Optional.

All the above fields are accessible from the object in a catch clause
in the usual way e.g. =$e->{status}= and =$e->{reason}=

=cut

sub new {
    my ( $class, $status, $reason, $response ) = @_;

    return $class->SUPER::new( status => $status, reason => $reason, response => $response );
}

=pod

---++ ObjectMethod stringify() -> $string

Generate a summary string. This is mainly for debugging.

=cut

sub stringify {
    my $this = shift;
    return qq(EngineException: Status code "$this->{status}" defined because of "$this->{reason}".);
}

1;

