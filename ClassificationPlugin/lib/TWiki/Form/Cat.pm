# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
# 
# Copyright (C) 2007 Michael Daum http://michaeldaumconsulting.com
#
# TWiki Contributors are listed in the AUTHORS file in the root of
# this distribution. NOTE: Please extend that file, not this notice.
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

package TWiki::Form::Cat;
use base 'TWiki::Form::ListFieldDefinition';

use TWiki::Plugins::ClassificationPlugin;
use TWiki::Attrs;
use strict;

sub new {
    my $class = shift;
    my $this = $class->SUPER::new( @_ );

    return $this;
}

sub isMultiValued { 
  return 1;
}

sub getOptions {
  my $this = shift;

  my $session = $this->{session};
  my $baseWeb = $session->{SESSION_TAGS}{BASEWEB};

  my $params = new TWiki::Attrs($this->{value});
  my $web = $params->{web} || $baseWeb;
  $this->{value} = '';

  my $hierarchy = TWiki::Plugins::ClassificationPlugin::getHierarchy($web);
  my @options = $hierarchy->getCategoryNames();

  return \@options;
}

1;
