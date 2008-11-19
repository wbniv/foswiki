#
# Foswiki - The Free Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2006 Foswiki Contributors.
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
package Foswiki::Configure::Checkers::Site::Locale;
use base 'Foswiki::Configure::Checker';

use strict;

my @required = (

);

sub check {
    my $this = shift;

    my $e = '';
    if ( $Foswiki::cfg{UseLocale} ) {
        eval "use locale;use POSIX";
        if ($@) {
            $Foswiki::cfg{UseLocale} = 0;
            return $this->WARN( 'Disabling locales. Error was: ' . $@ );
        }
        my $locale = $Foswiki::cfg{Site}{Locale};
        POSIX::setlocale( &POSIX::LC_CTYPE, $locale );
        my $currentLocale = POSIX::setlocale(&POSIX::LC_CTYPE);
        if ( $currentLocale ne $locale ) {
            $e .= $this->WARN(<<HERE);
Unable to set locale to '$locale'. The actual locale is '$currentLocale'
- please test your locale settings. This warning can be ignored if you are
not planning to use locales (e.g. your site uses English only) - or you can
set  {Site}{Locale} to 'C', which should always work.
HERE
        }
        if ( $locale !~ /[a-z]/i && $Foswiki::cfg{UseLocale} ) {
            $e = $this->WARN(<<HERE);
UseLocale set but {Site}{Locale} '$locale' has no alphabetic characters
HERE
        }
    }

    # Set the default site charset
    unless ( defined( $Foswiki::cfg{Site}{CharSet} ) ) {
        $Foswiki::cfg{Site}{CharSet} = 'iso-8859-1';
    }

    # Check for unusable multi-byte encodings as site character set
    # - anything that enables a single ASCII character such as '[' to be
    # matched within a multi-byte character cannot be used for TWiki.
    # Refuse to work with character sets that allow TWiki syntax
    # to be recognised within multi-byte characters.
    # FIXME: match other problematic multi-byte character sets
    if (   $Foswiki::cfg{UseLocale}
        && $Foswiki::cfg{Site}{CharSet} =~
m/^(?:iso-?2022-?|hz-?|gb2312|gbk|gb18030|.*big5|.*shift_?jis|ms.kanji|johab|uhc)/i
      )
    {

        $e .= $this->ERROR(
            <<HERE
Cannot use this multi-byte encoding ('$Foswiki::cfg{Site}{CharSet}') as site character
encoding. Please set a different character encoding in the {Site}{Locale}
setting.
HERE
        );
    }

    return $e;
}

1;
