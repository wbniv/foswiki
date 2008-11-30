# See bottom of file for license and copyright details
# This packages subclasses Foswiki::Form::FieldDefinition to implement
# the =date= type

package Foswiki::Form::Date;
use base 'Foswiki::Form::FieldDefinition';

use strict;

use Foswiki::Contrib::JSCalendarContrib;

sub new {
    my $class = shift;
    my $this = $class->SUPER::new( @_ );
    my $size = $this->{size} || '';
    $size =~ s/[^\d]//g;
    $size = 20 if( !$size || $size < 1 ); # length(31st September 2007)=19
    $this->{size} = $size;
    return $this;
}

sub renderForEdit {
    my( $this, $web, $topic, $value ) = @_;

    $value = CGI::textfield(
        { name => $this->{name},
          id => 'id'.$this->{name},
          size=> $this->{size},
          value => $value,
          class => $this->can('cssClasses') ?
            $this->cssClasses('foswikiInputField', 'foswikiEditFormDateField') :
              'foswikiInputField foswikiEditFormDateField'});
    my $ifFormat = $Foswiki::cfg{JSCalendarContrib}{format} || '%e %b %Y';
    Foswiki::Contrib::JSCalendarContrib::addHEAD( 'foswiki' );
    my $button .= CGI::image_button(
        -name => 'calendar',
        -onclick =>
          "return showCalendar('id$this->{name}','$ifFormat')",
        -src=> $Foswiki::cfg{PubUrlPath} . '/' .
          $Foswiki::cfg{SystemWebName} .
            '/JSCalendarContrib/img.gif',
        -alt => 'Calendar',
        -class => 'foswikiButton foswikiEditFormCalendarButton' );
    $value .= CGI::span(
        { -class => 'foswikiMakeVisible' },
        '&nbsp;' . $button
    );
    my $session = $this->{session};
    $value = $session->renderer->getRenderedVersion(
        $session->handleCommonTags( $value, $web, $topic ));

    return ( '', $value );
}

1;
__DATA__

Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/, http://Foswiki.org/

# Copyright (C) 2008 Foswiki Contributors. All Rights Reserved.
# Foswiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 2001-2007 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# Copyright (C) 2008 Foswiki Contributors
This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

