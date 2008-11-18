# Plugin for Foswiki - The Free Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006 Koen Martens, kmartens@sonologic.nl
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
# For licensing info read LICENSE file in the TWiki root.

package TWiki::Plugins::MostPopularPlugin;

use strict;

use vars qw( $VERSION $RELEASE $debug $pluginName );

$VERSION = '0.02';

$RELEASE = 'Dakar';

$pluginName = 'MostPopularPlugin';


sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Get plugin preferences, variables defined by:
    #   * Set EXAMPLE = ...
#    my $exampleCfgVar = TWiki::Func::getPreferencesValue( "\U$pluginName\E_EXAMPLE" );

#    $exampleCfgVar ||= 'default'; # make sure it has a value

    TWiki::Func::registerTagHandler( 'MOSTPOPULAR', \&_MOSTPOPULAR );

    return 1;
}

sub _MOSTPOPULAR {
    my($session, $params, $theTopic, $theWeb) = @_;

    my $limit = $params->{limit} || 10;
    my $format = $params->{format} || "| \$web | \$topic | \$views |";
    my $header = $params->{header} || "| *Web* | *Topic* | *Views* |";
    my $noheader = TWiki::isTrue( $params->{noheader} );
    my $groupbyweb = TWiki::isTrue( $params->{groupbyweb} );
    my $excludedRaw = $params->{excluded} || "";
    my $excludedtopicRaw = $params->{excludetopic} || "";

    my @excluded = split(",",$excludedRaw);
    my @excludedtopic = split(",",$excludedtopicRaw);

    # strip leading & trailing whitespace
    for (0..$#excluded) {
      $excluded[$_]=~s/^\s+//g;
      $excluded[$_]=~s/\s+$//g;
    }

    my $dir = TWiki::Func::getWorkArea("MostPopularPlugin");

    my  $rv=$noheader?"":($header."\n");
    my  $used=0;
    if($groupbyweb) {

      my @lines=split("\n",TWiki::Func::readFile("$dir/statfileweb.txt"));

      my $idx=0;
      while($idx<=$#lines && $used<$limit) {
        my ($web,$views) = split(" ",$lines[$idx]);

        if(not (grep { /^$web$/ } @excluded) ) {
          my $entry=$format;
          $entry=~s/\$web/$web/g;
          $entry=~s/\$views/$views/g;
          $rv.=$entry."\n";
	  $used++;
        }

        $idx++;
      }
    } else {

      # how would this perform if there are say thousands of topics?
      my @lines=split("\n",TWiki::Func::readFile("$dir/statfile.txt"));

      $rv=$noheader?"":($header."\n");
      $used=0;
      my $idx=0;
      while($idx<=$#lines && $used<$limit) {
        my ($web,$topic,$views) = split(" ",$lines[$idx]);

        if(not (grep { /^$web$/ } @excluded) && not (grep { /^$topic$/ } @excludedtopic) ) {
          my $entry=$format;
          $entry=~s/\$web/$web/g;
          $entry=~s/\$topic/$topic/g;
          $entry=~s/\$views/$views/g;
          $rv.=$entry."\n";
	  $used++;
        }

        $idx++;
      }
    }

    chomp($rv);

    return $rv;
}

1;
