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
package Foswiki::Configure::Checkers::UseLocale;

use strict;

use Foswiki::Configure::Checker;

use base 'Foswiki::Configure::Checker';

my @required = (
    {
        name  => 'Locale::Maketext::Lexicon',
        usage => 'I18N translations',
    },
    {
        name            => 'locale',
        usage           => "Standard Perl locales module",
        requiredVersion => 1,
    },
    {
        name            => 'POSIX',
        usage           => "Standard Perl POSIX module",
        requiredVersion => 1,
    },
);

my @perl56 = (
    {
        name            => 'Unicode::String',
        usage           => 'I18N conversions',
        requiredVersion => 1,
    },
    {
        name            => 'Unicode::MapUTF8',
        usage           => "I18N conversions",
        requiredVersion => 1,
    },
    {
        name            => 'Unicode::Map',
        usage           => "I18N conversions",
        requiredVersion => 1,
    },
    {
        name            => 'Unicode::Map8',
        usage           => "I18N conversions",
        requiredVersion => 1,
    },
    {
        name            => 'Jcode',
        usage           => "I18N conversions",
        requiredVersion => 1,
    },
);

my @perl58 = (
    {
        name            => 'Encode',
        usage           => "I18N conversions (core module in Perl 5.8)",
        requiredVersion => 1,
    },
    {
        name => 'Unicode::Normalize',
        usage =>
"I18N conversions (Replace 8-bit chars in uploaded files by US-ASCII equivalents)",
        requiredVersion => 1,
    },
);

sub check {
    my $this = shift;

    return '' unless $Foswiki::cfg{UseLocale};

    my $n = $this->checkPerlModules( \@required );

    if ( $] >= 5.008 ) {
        $n .= $this->checkPerlModules( \@perl58 );
    }
    else {
        $n .= $this->checkPerlModules( \@perl56 );
    }

    if ( $Foswiki::cfg{OS} eq 'WINDOWS' ) {

        # Warn re known broken locale setup
        $n .= $this->WARN(
            <<HERE
Using Perl on Windows, which may have missing or incorrect locales (in Cygwin
or ActiveState Perl, respectively) - turning off {Site}{LocaleRegexes} is
recommended unless you know your version of Perl has working locale support.
HERE
        );
    }

    # Warn against Perl 5.6 or lower for UTF-8
    if ( $] < 5.008 ) {
        $n .= $this->WARN( "Perl 5.8 is required if you are using TWiki's",
            "experimental UTF-8 support\n" );
    }

    # Check for 'useperlio' in Config on Perl 5.8 or higher - required
    # for use of ':utf8' layer.
    if (
        $] >= 5.008
        and not( exists $Config::Config{useperlio}
            and $Config::Config{useperlio} eq 'define' )
      )
    {
        $n .= $this->WARN(
            <<HERE
This version of Perl was not compiled to use PerlIO by default ('useperlio'
not set in Config.pm, see <i>Perl's Unicode Model</i> in 'perldoc
perluniintro') - re-compilation of Perl will be required before it can be
used to enable TWiki's experimental UTF-8 support.
HERE
        );
    }

    # Check for d_setlocale in Config (same as 'perl -V:d_setlocale')
    eval "use Config";
    if (
        !(
            exists $Config::Config{d_setlocale}
            && $Config::Config{d_setlocale} eq 'define'
        )
      )
    {
        $n .= $this->WARN(
            <<HERE
This version of Perl was not compiled with locale support ('d_setlocale' not
set in Config.pm) - re-compilation of Perl will be required before it can be
used to support TWiki internationalisation.
HERE
        );
    }
    return $n;
}

1;
