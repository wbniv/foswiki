# Copyright (C) 2006-2007 Michael Daum http://wikiring.de
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

package TWiki::Contrib::MediaWikiToTWikiAddOn;

use strict;
use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION );

$VERSION = '$Rev$';
$RELEASE = 'v1.0';
$SHORTDESCRIPTION = 'MediaWiki 2 TWiki Conversion Tool';

use Getopt::Long;
use Pod::Usage;
use TWiki::Contrib::MediaWikiToTWikiAddOn::Converter;

##############################################################################
sub main {
  my $help = 0;
  my %args = (
    debug => 0,
    defaultWeb=>'_default',
    dry => 0,
    excludePattern => '',
    fileName => '',
    images=>'',
    includePattern => '',
    language => 'en',
    match=> '',
    maxPages => 0,
    namespace => '',
    plugin=>'',
    targetWeb => 'MediaWiki',
    topicMapString => '',
    webMapString => '',
  );

  GetOptions(
    "debug|d+" => \$args{debug},
    "dry" => \$args{dry},
    "file|f:s" => \$args{fileName},
    "help|?" => \$help,
    "max|m:i" => \$args{maxPages},
    "web:s" => \$args{targetWeb},
    "exclude:s" => \$args{excludePattern},
    "include:s" => \$args{includePattern},
    "match:s" => \$args{matchPattern},
    "lang:s" => \$args{language},
    "namespace|n:s" => \$args{namespace},
    "webmap:s" => \$args{webMapString},
    "topicmap:s" => \$args{topicMapString},
    "language:s" => \$args{language},
    "images:s" => \$args{images},
    "defaultweb:s" => \$args{defaultWeb},
    "plugin:s" => \$args{plugin},
  ) or pod2usage(2);

  unless (defined
    $TWiki::Contrib::MediaWikiToTWikiAddOn::Converter::language{$args{language}}) {
    print STDERR "ERROR: unknown language $args{language}. Known languages are: ".
      join(', ', sort keys %TWiki::Contrib::MediaWikiToTWikiAddOn::language).
      "\n";
    exit;
  }

  pod2usage(-exitval =>1, 
    -verbose=>2,
    -message => "\nThe MEDIAWIKI 2 TWiki Conversion Tool\n"
  ) if $help;

  my $converter = TWiki::Contrib::MediaWikiToTWikiAddOn::Converter->new(%args);
  #$converter->writeInfo();
  $converter->convert();
}

1;
