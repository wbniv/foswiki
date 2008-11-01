# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (c) 2006 by Meredith Lesly, Kenneth Lavrsen
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
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the TWiki root.

package TWiki::Plugins::RenderTableDataPlugin;

use Time::Local;

# Always use strict to enforce variable scoping
use strict;

# $VERSION is referred to by TWiki, and is the only global variable that
# *must* exist in this package
use vars qw( $VERSION $RELEASE $debug $pluginName
  $VARIABLES_TO_REMOVE
  $format $shouldRenderTableData @isoMonth %mon2num %columnType
  %regex );

# This should always be $Rev: 11069$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 11069$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = '1.2.1';

# Name of this Plugin, only used in this module
$pluginName = 'RenderTableDataPlugin';

$VARIABLES_TO_REMOVE = '(EDITCELL|CALC)';

BEGIN {
    @isoMonth = (
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    );
    {
        my $count = 0;
        %mon2num = map { $_ => $count++ } @isoMonth;
    }
    %columnType = (
        'TEXT',   'text',   'DATE',      'date',
        'NUMBER', 'number', 'UNDEFINED', 'undefined'
    );
    %regex = ();
    $regex{table_plugin} = '%TABLE(?:{(.*?)})?%';
}

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    $debug = TWiki::Func::getPluginPreferencesFlag("DEBUG");
    TWiki::Func::registerTagHandler( 'TABLEDATA', \&_parseTableRows );

    # Plugin correctly initialized
    return 1;
}

=pod

Reads in a topic text.
Finds the table data in that text.
Creates a nested array (tableMatrix) from the text cells.
Optionally sorts the array.
Renders out the rows and cells.

----
|  |
|  |-------- rowStart: start reading here
|  |                |
|  |                -------- showStart: start displaying from here
|  |
|  |
|  |                -------- showEnd: end displaying from here
|  |                |
|  |-------- rowEnd: end reading here
----

rowStart, rowEnd, showStart, showEnd are all 1-based indexed
i.e. value 1 refers to the first element in the array
=cut

sub _parseTableRows {
    my ( $session, $params, $inTopic, $inWeb ) = @_;

    TWiki::Func::writeDebug("- RenderTableDataPlugin::_parseTableRows")
      if $debug;

    $shouldRenderTableData = 0;

    my $format            = $params->{'format'}            || '';
    my $topic             = $params->{'topic'}             || $inTopic;
    my $web               = $params->{'web'}               || $inWeb;
    my $tableId           = $params->{'id'}                || undef;
    my $preserveSpaces    = $params->{'preservespaces'}    || 'off';
    my $escapeQuotes      = $params->{'escapequotes'}      || 'on';
    my $sortCol           = $params->{'sortcolumn'}        || undef;
    my $sortDirection     = $params->{'sortdirection'}     || 'ascending';
    my $beforeText        = $params->{'beforetext'}        || '';
    my $afterText         = $params->{'aftertext'}         || '';
    my $separator         = $params->{'separator'}         || '';
    my $preserveVariables = $params->{'preservevariables'} || 'off';

    my $rowStart   = 1;
    my $rowEnd     = undef;
    my $rowsParams = $params->{'rows'} || '';
    if ($rowsParams) {
        $rowsParams =~ /([0-9\-]*)(\.\.)*([0-9\-]*)/;
        if ($1) {
            $rowStart = $1;
        }
        if ($2) {
            $rowEnd =
                $3
              ? $3
              : undef;
        }
        else {
            $rowEnd = $rowStart;
        }
    }
    my $colStart   = 1;
    my $colEnd     = undef;
    my $colsParams = $params->{'cols'} || '';
    if ($colsParams) {
        $colsParams =~ /([0-9\-]*)(\.\.)*([0-9\-]*)/;
        if ($1) {
            $colStart = $1;
        }
        if ($2) {
            $colEnd =
                $3
              ? $3
              : undef;
        }
        else {
            $colEnd = $colStart;
        }
    }

    my $showSetStart = 1;
    my $showSetEnd   = undef;
    my $showParams   = $params->{'show'} || '';
    if ($showParams) {
        $showParams =~ /([0-9\-]*)(\.\.)*([0-9\-]*)/;
        if ($1) {
            $showSetStart = $1;
        }
        if ($2) {
            $showSetEnd =
                $3
              ? $3
              : undef;
        }
        else {
            $showSetEnd = $showSetStart;
        }
    }
    $showSetStart = $rowStart if !defined $showSetStart;
    $showSetEnd   = $rowEnd   if !defined $showSetEnd;

    my $filter = $params->{'filter'} || $params->{'condition'} || '';

    my $text = TWiki::Func::readTopicText( $web, $topic );

    my $result      = '';
    my $tableResult = '';
    my $insidePRE   = 0;
    my $insideTABLE = 0;
    my $line        = "";
    my $rPos        = 1;
    my @tableMatrix = ();
    my $atTableToParse =
      defined $tableId
      ? 0
      : 1
      ; # assume we will parse the first table unless we are looking for a specific table

    $text =~ s/\r//go;
    $text =~ s/\\\n//go;                            # Join lines ending in "\"
    $text =~ s/%$VARIABLES_TO_REMOVE({.*?})*%//go
      unless TWiki::Func::isTrue($preserveVariables);   # Remove TWiki variables
    $text .= '\n'
      ; # Help to find the end of the table if the table is the last item in the topic

    foreach ( split( /\n/, $text ) ) {

        # change state:
        m|<pre>|i       && ( $insidePRE = 1 );
        m|<verbatim>|i  && ( $insidePRE = 1 );
        m|</pre>|i      && ( $insidePRE = 0 );
        m|</verbatim>|i && ( $insidePRE = 0 );

        if ( !$insidePRE ) {

            if (/$regex{table_plugin}/) {

                # match with a TablePlugin line
                my %tablePluginParams = TWiki::Func::extractParameters($1);
                my $currentTableId = $tablePluginParams{'id'} || '';
                if ( defined $tableId ) {
                    $atTableToParse = 0 if ( $tableId ne $currentTableId );
                    $atTableToParse = 1 if ( $tableId eq $currentTableId );
                }
                next;
            }
            if ( /^\s*\|.*\|\s*$/ && $atTableToParse ) {

                # inside | table |
                if ( !$insideTABLE ) {
                    $insideTABLE = 1;
                    $rPos        = 1;
                }

                if ( defined $rowStart && $rowStart > $rPos ) {
                    $rPos++;
                    next;
                }
                if ( defined $rowEnd && $rowEnd < $rPos ) {
                    $shouldRenderTableData = 1;
                    $rPos++;
                    next;
                }
                if ( defined $rowEnd && $rPos > $rowEnd ) {
                    last;
                }
                $line = $_;
                $line =~ s/^(\s*\|)(.*)\|\s*$/$2/o;
                my @row = ();
                my @rowValues = split( /\|/o, $line, -1 );
                for my $value (@rowValues) {
                    if ( $preserveSpaces ne 'on' ) {
                        $value =~ s/^\s*//;    # trim spaces at start
                        $value =~ s/\s*$//;    # trim spaces at end
                    }
                    if ( $escapeQuotes ne 'off' ) {
                        $value =~ s/\"/\\"/go;    # escape double quotes
                        $value =~ s/\'/\\'/go;    # escape single quotes
                    }
                    push @row, { text => $value, type => 'text' };
                }
                $colEnd = @row if !defined $colEnd;    # 1-based indexing
                push @tableMatrix, [@row]
                  ;   # we must add the complete row to be able to sort later on
                $rPos++;
            }
            else {

                # outside | table |
                if ($insideTABLE) {
                    $insideTABLE           = 0;
                    $shouldRenderTableData = 1;
                    $atTableToParse        = 0
                      ; # assume we will parse next table unless we will find out otherwise
                }
            }
        }

        if ( $shouldRenderTableData && $colEnd ) {

            if ( defined $sortCol ) {
                my $type =
                  _guessColumnType( $sortCol - 1, $rowStart, @tableMatrix );
                if ( $type eq $columnType{'TEXT'} ) {
                    @tableMatrix = map { $_->[0] }
                      sort { $a->[1] cmp $b->[1] }
                      map { [ $_, _stripHtml( $_->[ $sortCol - 1 ]->{text} ) ] }
                      @tableMatrix;
                }
                elsif ( $type eq $columnType{'UNDEFINED'} ) {

                    # nothing
                }
                else {
                    @tableMatrix = sort {
                        $a->[ $sortCol - 1 ]->{$type} <=> $b->[ $sortCol - 1 ]
                          ->{$type}
                    } @tableMatrix;
                }
            }
            if ( $sortDirection eq 'descending' ) {
                @tableMatrix = reverse @tableMatrix;
            }

            my $resultSetStart = ( defined $showSetStart ) ? $showSetStart : 1;
            my $resultSetEnd =
              ( defined $showSetEnd ) ? $showSetEnd : @tableMatrix;

            if ( $resultSetStart < 0 ) {
                $resultSetStart += @tableMatrix + 1;
                $resultSetEnd = @tableMatrix;
            }
            if ( $resultSetEnd < 0 ) {
                $resultSetEnd += @tableMatrix + 1;
                $resultSetStart = 1;
            }

            $resultSetStart -= 1;
            $resultSetEnd   -= 1;

            if ( $filter eq 'random' ) {

                my $resultCount = ( $resultSetEnd - $resultSetStart ) + 1;

                my $random = int( rand($resultCount) );
                $resultSetStart += $random;
                $resultSetEnd = $resultSetStart;
            }

            for my $rowPos ( $resultSetStart .. $resultSetEnd ) {
                my $row = $tableMatrix[$rowPos];
                next if !$row;
                my $rowResult = $format;
                for my $colPos ( $colStart - 1 .. $colEnd - 1 ) {
                    my $cell = $row->[$colPos]->{text};
                    if ( $format eq '' ) {

                        # no format passed, so return the complete cell text
                        $rowResult .= $cell;
                        next;
                    }
                    my $cellNum = $colPos + 1;

                    # if statement
                    $rowResult =~
s/\$C$cellNum(\(\"([^\"]*)\"(\s*then\=\"([^\"]*)\")*(\s*else\=\"([^\"]*)\")*\))/_handleIfStatement($cell,$2,$4,$6)/ges;

                    $rowResult =~
s/\$C$cellNum(\(([0-9]*),*(.*?)\))*/_getCellContents($cell,$2,$3)/ges;
                }
                $tableResult .= $rowResult . $separator;
            }

            # remove last separator
            $tableResult =~ s/$separator$//g;

            $tableResult = $beforeText . $tableResult if $tableResult ne '';
            $tableResult .= $afterText if $tableResult ne '';
            $tableResult = _decodeFormatTokens($tableResult);

            # feedback variables
            $showSetStart = '' if !defined $showSetStart;
            $showSetEnd   = '' if !defined $showSetEnd;
            my $set = "$showSetStart..$showSetEnd";
            $tableResult =~ s/\$set/$set/go;
            $tableResult =~ s/\$set/$set/go;

            TWiki::Func::writeDebug(
"- RenderTableDataPlugin::_parseTableRows - result A=$tableResult"
            ) if $debug;

            return $result . $tableResult;
        }
    }
    TWiki::Func::writeDebug(
        "- RenderTableDataPlugin::_parseTableRows - result B=$tableResult")
      if $debug;

    return $result . $tableResult;
}

=pod

Evaluate an 'if' statement. Currently supported:
cell("isempty" then="true" else="false")
cell("='value'" then="true" else="false")

=cut

sub _handleIfStatement {
    my ( $cell, $ifStatement, $then, $else ) = @_;

    if ( $ifStatement =~ m/\s*isempty\s*/ ) {
        return ( $cell eq '' ) ? $then : $else;
    }
    if ( $ifStatement =~ m/\s*\=\s*\'(.*?)\'\s*/ ) {
        return ( $cell eq $1 ) ? $then : $else;
    }
    return $cell;
}

=pod

If a limit is passed, return a number characters of a cell.

=cut

sub _getCellContents {
    my ( $cellText, $limit, $placeholder ) = @_;
    if ( !$limit ) {
        return $cellText;
    }

    # if limit:
    $cellText =~ s/\<br\s*\/*\>/\$_BR/go
      ;    # temporarily remove HTML linebreaks put in by EditTablePlugin
    my $limitedText = substr( $cellText, 0, $limit );
    $limitedText .= $placeholder if length $cellText > length $limitedText;
    $limitedText =~ s/\$_BR/<br \/>/go;    # change temp back
    return $limitedText;
}

=pod

Guess if column is a date, number or plain text.
Code copied from TablePlugin (Core.pm) and modified slightly.

=cut

sub _guessColumnType {
    my ( $col, $rowStart, @tableMatrix ) = @_;

    my $isDate        = 1;
    my $isNum         = 1;
    my $num           = '';
    my $date          = '';
    my $columnIsValid = 0;

    foreach my $row (@tableMatrix) {
        next if ( !$row->[$col]->{text} );

        $columnIsValid = 1;
        ( $num, $date ) = _convertToNumberAndDate( $row->[$col]->{text} );
        $isDate = 0 if ( !defined($date) );
        $isNum  = 0 if ( !defined($num) );
        last if ( !$isDate && !$isNum );
        $row->[$col]->{date}   = $date;
        $row->[$col]->{number} = $num;
    }
    return $columnType{'UNDEFINED'} if ( !$columnIsValid );
    my $type = $columnType{'TEXT'};
    if ($isDate) {
        $type = $columnType{'DATE'};
    }
    elsif ($isNum) {
        $type = $columnType{'NUMBER'};
    }
    return $type;
}

=pod

Convert text to number and date if syntactically possible.
Code copied from TablePlugin (Core.pm).

=cut

sub _convertToNumberAndDate {
    my ($text) = @_;

    $text =~ s/&nbsp;/ /go;

    my $num  = undef;
    my $date = undef;
    if ( $text =~ /^\s*$/ ) {
        $num  = 0;
        $date = 0;
    }

    if ( $text =~
m|^\s*([0-9]{1,2})[-\s/]*([A-Z][a-z][a-z])[-\s/]*([0-9]{4})\s*-\s*([0-9][0-9]):([0-9][0-9])|
      )
    {

        # "31 Dec 2003 - 23:59", "31-Dec-2003 - 23:59",
        # "31 Dec 2003 - 23:59 - any suffix"
        $date = timegm( 0, $5, $4, $1, $mon2num{$2}, $3 - 1900 );
    }
    elsif ( $text =~
        m|^\s*([0-9]{1,2})[-\s/]([A-Z][a-z][a-z])[-\s/]([0-9]{2,4})\s*$| )
    {

        # "31 Dec 2003", "31 Dec 03", "31-Dec-2003", "31/Dec/2003"
        my $year = $3;
        $year += 1900 if ( length($year) == 2 && $year > 80 );
        $year += 2000 if ( length($year) == 2 );
        $date = timegm( 0, 0, 0, $1, $mon2num{$2}, $year - 1900 );
    }
    elsif ( $text =~ /^\s*[0-9]+(\.[0-9]+)?\s*$/ ) {
        $num = $text;
    }
    return ( $num, $date );
}

=pod

Remove HTML from text so it can be sorted.
Code copied from TablePlugin (Core.pm).

=cut

sub _stripHtml {
    my ($text) = @_;
    $text ||= '';
    $text =~ s/\&nbsp;/ /go;    # convert space
    $text =~
      s/\[\[[^\]]+\]\[([^\]]+)\]\]/$1/go; # extract label from [[...][...]] link
    $text =~ s/<[^>]+>//go;               # strip HTML
    $text =~ s/^ *//go;                   # strip leading space space
    $text = lc($text);                    # convert to lower case
    return $text;
}

sub _decodeFormatTokens {
    my $text = shift;
    return
      defined(&TWiki::Func::decodeFormatTokens)
      ? TWiki::Func::decodeFormatTokens($text)
      : _expandStandardEscapes($text);
}

=pod

For TWiki versions that do not implement TWiki::Func::decodeFormatTokens.

=cut

sub _expandStandardEscapes {
    my $text = shift;
    $text =~ s/\$n\(\)/\n/gos;    # expand '$n()' to new line
    my $alpha = TWiki::Func::getRegularExpression('mixedAlpha');
    $text =~ s/\$n([^$alpha]|$)/\n$1/gos;    # expand '$n' to new line
    $text =~ s/\$nop(\(\))?//gos;      # remove filler, useful for nested search
    $text =~ s/\$quot(\(\))?/\"/gos;   # expand double quote
    $text =~ s/\$percnt(\(\))?/\%/gos; # expand percent
    $text =~ s/\$dollar(\(\))?/\$/gos; # expand dollar
    return $text;
}

1;
