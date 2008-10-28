# Configuration file of CliRunnerContrib
#
# Copyright (C) 1999-2006 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# As per the GPL, removal of this notice is prohibited.

# ---+ Extensions
# ---++ CliRunnerContrib
# **PATH M**
# Path to the Perl executable.  Can be simply 'perl' if the perl interpreter is on the path.
$TWiki::cfg{Contrib}{CliRunnerContrib}{perl} = $^X;

# **PATH M**
# Library directory for TWiki, relative to its bin directory.
# <tt>../lib</tt> should work perfectly in a SVN environment.
$TWiki::cfg{Contrib}{CliRunnerContrib}{LibPath} = '../lib';

# **STRING 10**
# Parameters always to be passed to your Perl when running
# scripts. Usually includes <tt>-T</tt> for taint checking.
$TWiki::cfg{Contrib}{CliRunnerContrib}{PerlOptions} = '-T';

# **BOOLEAN**
# If true, show some debugging information on STDERR.
# Poorly documented, as of now :-(
$TWiki::cfg{Contrib}{CliRunnerContrib}{Debug} = '0';

1;
