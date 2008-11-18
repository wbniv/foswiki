# Plugin for Foswiki - The Free Open Source Wiki, http://foswiki.org/
#
# (c) 2006 Motorola, thomas.weigert@motorola.com
# (c) 2006 TWiki:Main.ClausLanghans
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

package TWiki::Plugins::ExcelImportExportPlugin::Export;

use strict;
use TWiki;
use TWiki::Func;
use TWiki::Form;
use Spreadsheet::WriteExcel;
use Date::Manip;

## SMELL: Check which settings should be read from preferences.

sub topics2excel {

    my $session = shift;
    $TWiki::Plugins::SESSION = $session;

    my $query = $session->{cgiQuery};
## SMELL: The spreadsheet _must_ be attached to the same topic where the map is
    my $web       = $session->{webName};
    my $basetopic = $session->{topicName};
    my $userName  = $session->{user};

    my @sortorder;
    my %shortname;
    my %type;
    my %width;
    my %orientation;
    my %format;    # format of columns

    my %config = (
        VERTICALCOLWIDTH =>
          2.66,    # width of a column that is turn by 90 degree, i.e. one line
        TOPICTEXT      => "TEXT",
        LINECOLUMN     => "Line",
        DEBUG          => 0,
        TOPICCOLUMN    => "TOPIC",
        PAGEWIDTH      => 215,
        DATETIMEFORMAT => "dd mmm yyyy",
        FILENAME       => "$basetopic.xls",    # not used
        TEMPLATETOPIC  => "Template"
        , # topic name ending that will be excluded e.g. BugTemplate or FeatureTemplate
        MAPPING => '',
        FORM    => '',
    );

    foreach my $key (
        qw(FORM TOPICPARENT UPLOADFILE NEWTOPICTEMPLATE FORCCEOVERWRITE TOPICCOLUMN DEBUG DATETIMEFORMAT)
      )
    {
        my $value = &TWiki::Func::getPreferencesValue($key);
        if ( defined $value and $value !~ /^\s*$/ ) {
            $config{$key} = $value;
            $config{$key} =~ s/^\s*//go;
            $config{$key} =~ s/\s*$//go;
        }
    }

## SMELL: Need to sort out the preferences between setting and parameters....
    $config{MAPPING} = $query->param('map')      || $config{MAPPING};
    $config{FORM}    = $query->param('template') || $config{FORM};
    $config{DEBUG} = $TWiki::Plugins::ExcelImportExportPlugin::debug;

    if ( $config{FORM} eq '' ) {
        ## SMELL: Should we throw an oops alert instead?
        TWiki::Func::writeDebug(
"ExcelImportExportPlugin: No form definition given. No data will be exported."
        );
        TWiki::Func::redirectCgiQuery( $query,
            &TWiki::Func::getScriptUrl( $web, $basetopic, "view" ) );
    }

    my $xlsfile = "-";

    # Create a new Excel workbook
    my $workbook = Spreadsheet::WriteExcel->new($xlsfile)
      or die "Problems creating new Excel $xlsfile file: $!";

    # Add a worksheet
    my $worksheet   = $workbook->add_worksheet();
    my $configsheet = $workbook->add_worksheet();

    #$configsheet->hide();

    # Set parameters of the worksheet
    $worksheet->freeze_panes( 1, 0 );
    $worksheet->set_margins(0);    #
                                   #$worksheet->set_margin_bottom(0.3);
    $worksheet->set_footer( '&L&D &T &R&P of  &N', 0 );    # page N of M
    $worksheet->repeat_rows(0);    # Repeat the first row when printing
    $worksheet->fit_to_pages( 1, 12 )
      ;    # ToDo This should take into account how many issues are printed
    $worksheet->set_landscape();

    #  Add and define a formats
    my $normalformat = $workbook->add_format(
        text_wrap => 1,
        shrink    => 1,
        valign    => "top",
    );
    my $normalformat90 = $workbook->add_format();
    $normalformat90->copy($normalformat);
    $normalformat90->set_rotation(90);

    my $headerformat = $workbook->add_format();
    $headerformat->copy($normalformat);
    $headerformat->set_bold(1);
    $headerformat->set_valign("bottom");

    my $headerformat90 = $workbook->add_format();
    $headerformat90->copy($headerformat);
    $headerformat90->set_rotation(90);

    my $dateformat = $workbook->add_format();
    $dateformat->copy($normalformat);
    $dateformat->set_num_format( $config{DATETIMEFORMAT} );

    my $dateformat90 = $workbook->add_format();
    $dateformat90->copy($dateformat);
    $dateformat90->set_rotation(90);

    my $urlformat = $workbook->add_format();
    $urlformat->copy($normalformat);
    $urlformat->set_underline();
    $urlformat->set_color('blue');

    my $urlformat90 = $workbook->add_format();
    $urlformat90->copy($urlformat);
    $urlformat90->set_rotation(90);

    my $countvertical = 0;    # number of vertical columns

## SMELL: should normalize web/topic names
    # Get export information from form
    my $form = new TWiki::Form( $session, $web, $config{FORM} );
    my $fieldDefs = $form->{fields};
    foreach my $field ( @{$fieldDefs} ) {

        # NAME
        my $name = $field->{title};
        $name =~ s/^\s*//go;
        $name =~ s/\s*$//go;
        push( @sortorder, $name );

        # TYPE
        my $type = $field->{type};
        $type =~ s/^\s*//go;
        $type =~ s/\s*$//go;
        if ( $type =~ m/date/ ) {
            $type{$name} = 'date';
        }
        else {
            $type{$name} = "text";
        }

    }
    push( @sortorder, $config{TOPICTEXT} );
    push( @sortorder, $config{TOPICCOLUMN} );

    # Read in the mapping data to configure the upload fields (if present)
    if ( $config{MAPPING} ) {
        my ( $meta, $text ) = &TWiki::Func::readTopic( $web, $config{MAPPING} );

        # used code from TWiki::Forms
        $text =~
          s/\\\r?\n//go;    # remove trailing '\' and join continuation lines
        my $inBlock = 0;
        foreach ( split( /\n/, $text ) ) {
            if (
/^\s*\|.*?Name.*?\|.*?Short\s*Name.*?\|.*?Width.*?\|.*?Orientation.*?\|.*?Data\s*Type.*?\|/
              )
            {
                $inBlock = 1;
            }
            else {
                if ( $inBlock && s/^\s*\|//o ) {
                    my ( $name, $shortname, $width, $orientation, $type ) =
                      split(/\|/);

                    # NAME
                    $name =~ s/^\s*//go;
                    $name =~ s/\s*$//go;

                    # TYPE
                    $type =~ s/^\s*//go;
                    $type =~ s/\s*$//go;
                    unless ( $type{$name} ) {
                        if ( $type =~ m/\s*(text|date|number)\s*/ ) {
                            $type{$name} = $1;
                        }
                        else {
                            $type{$name} = "text";
                        }
                    }

                    # WIDTH
                    $width =~ s/^\s*//go;
                    $width =~ s/\s*$//go;
                    $width =~ s/[^\d+\.]//go;
                    if ( $width ne '' ) {
                        $width{$name} = $width;
                    }

                    # ORIENTATION
                    if ( $orientation =~ m/(v|h)/ and $1 eq 'v' ) {
                        $orientation{$name} = "v";
                        if ( $type{$name} =~ m/^date/ ) {
                            $format{$name} = $dateformat90;
                        }
                        else {
                            $format{$name} = $normalformat90;
                        }
                        $countvertical++;
                    }
                    else {
                        $orientation{$name} = "h";
                        if ( $type{$name} =~ m/^date/ ) {
                            $format{$name} = $dateformat;
                        }
                        else {
                            $format{$name} = $normalformat;
                        }
                    }

                    # SHORTNAME
                    $shortname{$name} = $name;
                    $shortname =~ s/^\s*//go;
                    $shortname =~ s/\s*$//go;
                    if ( $shortname ne '' ) {
                        $shortname{$name} = $shortname;
                    }
                }
                else {
                    $inBlock = 0;
                }
            }
        }
    }

    # Create the header row and the configuration sheet
    my $horizontalcolwidth =
      ( $config{PAGEWIDTH} - ( $countvertical * $config{VERTICALCOLWIDTH} ) ) /
      ( $#sortorder - $countvertical );
    my $col = 0;
    my $row = 0;
    foreach my $name (@sortorder) {
        if ( defined($orientation{$name}) && $orientation{$name} eq 'v' ) {
            $worksheet->write( $row, $col, ($shortname{$name}||$name), $headerformat90 );
            $worksheet->write_comment( $row, $col, $name, height => 10 );
            if ( defined( $width{$name} ) ) {
                $worksheet->set_column( $col, $col, $width{$name} );
            }
            else {
                $worksheet->set_column( $col, $col, 2.66 );
            }
        }
        else {
            $worksheet->write( $row, $col, ($shortname{$name}||$name), $headerformat );
            $worksheet->write_comment( $row, $col, $name, height => 10 );
            if ( defined( $width{$name} ) ) {
                $worksheet->set_column( $col, $col, $width{$name} );
            }
            else {
                $worksheet->set_column( $col, $col, $horizontalcolwidth );
            }
        }
        $configsheet->write( $row,     $col, $name,             $headerformat );
        $configsheet->write( $row + 1, $col, $shortname{$name}, $normalformat );
        $configsheet->write( $row + 2, $col, $orientation{$name},
            $normalformat );
        $configsheet->write( $row + 3, $col, $width{$name}, $normalformat );
        $configsheet->write( $row + 4, $col, $type{$name},  $normalformat );
        $col++;
    }

    # read all meta values and write them in the Excel sheet
    $col = 0;
    $row++;
    foreach my $topic ( &TWiki::Func::getTopicList($web) ) {

        # BUG: first read the topic and that check the permissions
        if (
            &TWiki::Func::checkAccessPermission(
                'VIEW', &TWiki::Func::getWikiUserName(),
                '', $topic, $web
            )
          )
        {
            my ( $meta, $text ) = &TWiki::Func::readTopic( $web, $topic );
            if ( defined($meta->{FORM}[0]{name}) && $meta->{FORM}[0]{name} eq $config{FORM}
                and not $topic =~ /$config{TEMPLATETOPIC}$/ )
            {    # Exclude the template topcic
                my %value;
                $value{ $config{TOPICCOLUMN} } = $topic;
                $value{ $config{TOPICTEXT} } =
                  $text;    # capture the raw text without metadata
                $value{ $config{LINECOLUMN} } = $row;
                foreach my $field ( @{ $meta->{'FIELD'} } )
                {           # TODO:  this should be $meta->find('FIELD')
                    $value{ $field->{'title'} } = $field->{'value'};
                }
                foreach my $name (@sortorder)
                {           # create an entry in the sheet for each column
                    if ( $name eq $config{TOPICCOLUMN} )
                    { # Special handling of the topic column as it needs to be clickable link
                        if ( $orientation{$name} eq 'v' ) {
                            $worksheet->write(
                                $row, $col,
                                &TWiki::Func::getScriptUrl(
                                    $web, $topic, "edit"
                                ),
                                $topic,
                                $urlformat90
                            );
                        }
                        else {
                            $worksheet->write(
                                $row, $col,
                                &TWiki::Func::getScriptUrl(
                                    $web, $topic, "edit"
                                ),
                                $topic,
                                $urlformat
                            );
                        }
                    }
                    elsif ( $type{$name} eq 'date' ) {

                        # yyyy-mm-ddThh:mm:ss.sss
                        my $datestring =
                          UnixDate( $value{$name}, '%Y-%m-%dT%H:%M:%S' );
                        $worksheet->write_date_time( $row, $col, $datestring,
                            $format{$name} );
                    }
                    elsif ( $type{$name} eq 'number' ) {
                        $worksheet->write_number( $row, $col, $value{$name},
                            $format{$name} );
                    }
                    elsif ( $type{$name} eq 'text' ) {
                        if (!defined($value{$name})) {
                            #print STDERR "value of $name undefined - defaulting to ''\n";
                            $value{$name} = '';
                        }
                        $worksheet->write_string( $row, $col, $value{$name},
                            $format{$name} );
                    }
                    else {
                        $worksheet->write( $row, $col, $value{$name},
                            $format{$name} );
                    }
                    $col++;
                }
                $row++;
                $col = 0;
            }
        }
    }

    print $query->header( -type => 'application/vnd.ms-excel',
        -expire => 'now' );

 #print "Content-type: application/vnd.ms-excel\n";
 # The Content-Disposition will generate a prompt to save  the file. If you want
 # to stream the file to the browser, comment out the following line.
 #print "Content-Disposition: attachment; filename=$xlsfile\n";
 #print "\n";

    # The contents of the Excel file is returned to STDOUT
    $workbook->close() or die "Error closing file: $!";

}

sub table2excel {

    my $session = shift;
    $TWiki::Plugins::SESSION = $session;

    my $query     = $session->{cgiQuery};
    my $web       = $session->{webName};
    my $basetopic = $session->{topicName};
    my $userName  = $session->{user};

    my @sortorder;
    my %shortname;
    my %type;
    my %width;
    my %orientation;
    my %format;    # format of columns

    my %config = (
        VERTICALCOLWIDTH =>
          2.66,    # width of a column that is turn by 90 degree, i.e. one line
        TOPICTEXT      => "TEXT",
        LINECOLUMN     => "Line",
        DEBUG          => 0,
        TOPICCOLUMN    => "TOPIC",
        PAGEWIDTH      => 215,
        DATETIMEFORMAT => "dd mmm yyyy",
        FILENAME       => "$basetopic.xls",    # not used
        TEMPLATETOPIC  => "Template"
        , # topic name ending that will be excluded e.g. BugTemplate or FeatureTemplate
        UPLOADFILE  => $basetopic,
        UPLOADTOPIC => $basetopic,
        MAPPING     => '',
        FORM        => '',
    );

    foreach my $key (
        qw(FORM TOPICPARENT UPLOADFILE NEWTOPICTEMPLATE FORCCEOVERWRITE TOPICCOLUMN DEBUG DATETIMEFORMAT)
      )
    {
        my $value = &TWiki::Func::getPreferencesValue($key);
        if ( defined $value and $value !~ /^\s*$/ ) {
            $config{$key} = $value;
            $config{$key} =~ s/^\s*//go;
            $config{$key} =~ s/\s*$//go;
        }
    }

## SMELL: Need to sort out the preferences between setting and parameters....
    $config{UPLOADFILE}  = $query->param('file')        || $config{UPLOADFILE};
    $config{UPLOADTOPIC} = $query->param('uploadtopic') || $config{UPLOADTOPIC};
    $config{MAPPING}     = $query->param('map')         || $config{MAPPING};
    $config{FORM}        = $query->param('template')    || $config{FORM};
    $config{DEBUG} = $TWiki::Plugins::ExcelImportExportPlugin::debug;

    ( $config{UPLOADWEB}, $config{UPLOADTOPIC} ) =
      $session->normalizeWebTopicName( $web, $config{UPLOADTOPIC} );

## SMELL: If we later find out we cannot infer the header, we have already started writing the spreadsheet which sends that to the screen. We never get a chance to throw the exception. Either insist that form is defined or move the checking earlier.
    if ( $config{FORM} eq '' ) {
        TWiki::Func::writeDebug(
"ExcelImportExportPlugin: No form definition given. Headers will be derived from table."
        );
## SMELL: Not a nice alert
        #    throw TWiki::OopsException( 'alerts',
        #				def => 'generic',
        #				web => $_[2],
        #				topic => $_[1],
        #				params => [ 'Form not defined in ', $web.$basetopic, '', '' ] );

    }

    my $xlsfile = "-";

#  my $xlsfile = $TWiki::cfg{PubDir}."/$config{UPLOADWEB}/$config{UPLOADTOPIC}/$config{UPLOADFILE}.xls";
#  $xlsfile = TWiki::Sandbox::untaintUnchecked( $xlsfile );

    # Create a new Excel workbook
    my $workbook = Spreadsheet::WriteExcel->new($xlsfile)
      or die "Problems creating new Excel $xlsfile file: $!";

    # Add a worksheet
    my $worksheet   = $workbook->add_worksheet();
    my $configsheet = $workbook->add_worksheet();

    #$configsheet->hide();

    # Set parameters of the worksheet
    $worksheet->freeze_panes( 1, 0 );
    $worksheet->set_margins(0);    #
                                   #$worksheet->set_margin_bottom(0.3);
    $worksheet->set_footer( '&L&D &T &R&P of  &N', 0 );    # page N of M
    $worksheet->repeat_rows(0);    # Repeat the first row when printing
    $worksheet->fit_to_pages( 1, 12 )
      ;    # ToDo This should take into account how many issues are printed
    $worksheet->set_landscape();

    #  Add and define a formats
    my $normalformat = $workbook->add_format(
        text_wrap => 1,
        shrink    => 1,
        valign    => "top",
    );
    my $normalformat90 = $workbook->add_format();
    $normalformat90->copy($normalformat);
    $normalformat90->set_rotation(90);

    my $headerformat = $workbook->add_format();
    $headerformat->copy($normalformat);
    $headerformat->set_bold(1);
    $headerformat->set_valign("bottom");

    my $headerformat90 = $workbook->add_format();
    $headerformat90->copy($headerformat);
    $headerformat90->set_rotation(90);

    my $dateformat = $workbook->add_format();
    $dateformat->copy($normalformat);
    $dateformat->set_num_format( $config{DATETIMEFORMAT} );

    my $dateformat90 = $workbook->add_format();
    $dateformat90->copy($dateformat);
    $dateformat90->set_rotation(90);

    my $urlformat = $workbook->add_format();
    $urlformat->copy($normalformat);
    $urlformat->set_underline();
    $urlformat->set_color('blue');

    my $urlformat90 = $workbook->add_format();
    $urlformat90->copy($urlformat);
    $urlformat90->set_rotation(90);

    my $countvertical = 0;    # number of vertical columns

## SMELL: should normalize web/topic names
    if ( $config{FORM} ) {

        # Get export information from form
        my $form = new TWiki::Form( $session, $web, $config{FORM} );
        my $fieldDefs = $form->{fields};
        foreach my $field ( @{$fieldDefs} ) {

            # NAME
            my $name = $field->{title};
            $name =~ s/^\s*//go;
            $name =~ s/\s*$//go;
            push( @sortorder, $name );
            $shortname{$name} = $name;

            # TYPE
            my $type = $field->{type};
            $type =~ s/^\s*//go;
            $type =~ s/\s*$//go;
            if ( $type =~ m/date/ ) {
                $type{$name}   = 'date';
                $format{$name} = $dateformat;
            }
            else {
                $type{$name}   = "text";
                $format{$name} = $normalformat;
            }

        }
    }

    # Read in the mapping data to configure the upload fields (if present)
    if ( $config{MAPPING} ) {
        my ( $meta, $text ) = &TWiki::Func::readTopic( $web, $config{MAPPING} );

        # used code from TWiki::Forms
        $text =~
          s/\\\r?\n//go;    # remove trailing '\' and join continuation lines
        my $inBlock = 0;
        foreach ( split( /\n/, $text ) ) {
            if (
/^\s*\|.*?Name.*?\|.*?Short\s*Name.*?\|.*?Width.*?\|.*?Orientation.*?\|.*?Data\s*Type.*?\|/
              )
            {
                $inBlock = 1;
            }
            else {
                if ( $inBlock && s/^\s*\|//o ) {
                    my ( $name, $shortname, $width, $orientation, $type ) =
                      split(/\|/);

                    # NAME
                    $name =~ s/^\s*//go;
                    $name =~ s/\s*$//go;
                    push( @sortorder, $name ) unless $config{FORM};

                    # TYPE
                    $type =~ s/^\s*//go;
                    $type =~ s/\s*$//go;
                    unless ( $type{$name} ) {
                        if ( $type =~ m/\s*(text|date|number)\s*/ ) {
                            $type{$name} = $1;
                        }
                        else {
                            $type{$name} = "text";
                        }
                    }

                    # WIDTH
                    $width =~ s/^\s*//go;
                    $width =~ s/\s*$//go;
                    $width =~ s/[^\d+\.]//go;
                    if ( $width ne '' ) {
                        $width{$name} = $width;
                    }

                    # ORIENTATION
                    if ( $orientation =~ m/(v|h)/ and $1 eq 'v' ) {
                        $orientation{$name} = "v";
                        if ( $type{$name} =~ m/^date/ ) {
                            $format{$name} = $dateformat90;
                        }
                        else {
                            $format{$name} = $normalformat90;
                        }
                        $countvertical++;
                    }
                    else {
                        $orientation{$name} = "h";
                        if ( $type{$name} =~ m/^date/ ) {
                            $format{$name} = $dateformat;
                        }
                        else {
                            $format{$name} = $normalformat;
                        }
                    }

                    # SHORTNAME
                    $shortname{$name} = $name unless $config{FORM};
                    $shortname =~ s/^\s*//go;
                    $shortname =~ s/\s*$//go;
                    if ( $shortname ne '' ) {
                        $shortname{$name} = $shortname;
                    }
                }
                else {
                    $inBlock = 0;
                }
            }
        }
    }

    # Create the header row and the configuration sheet
    my $horizontalcolwidth =
      ( $config{PAGEWIDTH} - ( $countvertical * $config{VERTICALCOLWIDTH} ) ) /
      ( $#sortorder - $countvertical );
    my $col = 0;
    my $row = 0;
    foreach my $name (@sortorder) {
        if ( $orientation{$name} eq 'v' ) {
            $worksheet->write( $row, $col, $shortname{$name}, $headerformat90 );
            $worksheet->write_comment( $row, $col, $name, height => 10 );
            if ( defined( $width{$name} ) ) {
                $worksheet->set_column( $col, $col, $width{$name} );
            }
            else {
                $worksheet->set_column( $col, $col, 2.66 );
            }
        }
        else {
            $worksheet->write( $row, $col, $shortname{$name}, $headerformat );
            $worksheet->write_comment( $row, $col, $name, height => 10 );
            if ( defined( $width{$name} ) ) {
                $worksheet->set_column( $col, $col, $width{$name} );
            }
            else {
                $worksheet->set_column( $col, $col, $horizontalcolwidth );
            }
        }
        $configsheet->write( $row,     $col, $name,             $headerformat );
        $configsheet->write( $row + 1, $col, $shortname{$name}, $normalformat );
        $configsheet->write( $row + 2, $col, $orientation{$name},
            $normalformat );
        $configsheet->write( $row + 3, $col, $width{$name}, $normalformat );
        $configsheet->write( $row + 4, $col, $type{$name},  $normalformat );
        $col++;
    }

    # read the table and write them in the Excel sheet
    my ( $meta, $text ) = &TWiki::Func::readTopic( $web, $basetopic );

    # Need to expand searches to handle tables generated from search.
    ## SMELL: Need to expand FormQueryPlugin based searches also...
    ## SMELL: What if there are tags in the search?
    $text =~
s/%SEARCH{(.*)}%/$session->_SEARCH( new TWiki::Attrs($1), $basetopic, $web )/geo;

    my $insideTable = 0;
    my $beforeTable = 0;
    my @labels;
    foreach ( split( /\r?\n/, "$text\n<nop>\n" ) ) {
        if ( m/\%TABLE2EXCEL/o || m/table2excel/o ) {
            $beforeTable = 1;
            next;
        }
        next unless $beforeTable;
        if (/^\s*\|\s*(.*)\s*\|\s*$/) {

            # found table row
            my $tablerow = $1;

            # if first row, store columns
            unless ($insideTable) {
                @labels = split( /\s*\|\s*/, $tablerow );
                if ( $labels[0] =~ m/\*.*\*/ ) {

                    # first row is header row
                    unless ( $config{FORM} ) {
                        foreach my $name (@labels) {
                            $name =~ s/^\*(.*)\*$/$1/o;
                            push( @sortorder, $name );
                        }
                        $tablerow = join( "|", @labels )
                          ; # There is probably a better way to remove the * around the entries...
                    }
                    else {
                        $insideTable = 1;
                        $row++;
                        $col = 0;
                        next;
                    }
                }
                else {
                    unless ( $config{FORM} || $config{MAPPING} ) {
## SMELL: Not a nice alert
                        throw TWiki::OopsException(
                            'alerts',
                            def    => 'generic',
                            web    => $_[2],
                            topic  => $_[1],
                            params => [
                                'Form not defined in ', $web . $basetopic,
                                '',                     ''
                            ]
                        );
                    }

                    # there was no header row, we are inside table
                    $insideTable = 1;
                    $row++;
                }
            }
            my @fields = split( /\s*\|\s*/, $tablerow );
            $col = 0;
            my %value;
            foreach my $fld (@fields) {

                # process fields
                $value{ $config{LINECOLUMN} } = $row;
                $value{ $sortorder[$col] } = $fld;
                $col++;
            }
            $col = 0;
            foreach my $name (@sortorder)
            { # Create an entry in the sheet for each column, note that the labels are all 'text'.
                if ( $insideTable && ( $type{$name} eq 'date' ) ) {

                    # yyyy-mm-ddThh:mm:ss.sss
                    my $datestring =
                      UnixDate( $value{$name}, '%Y-%m-%dT%H:%M:%S' );
                    $worksheet->write_date_time( $row, $col, $datestring,
                        $format{$name} );
                }
                elsif ( $insideTable && ( $type{$name} eq 'number' ) ) {
                    $worksheet->write_number( $row, $col, $value{$name},
                        $format{$name} );
                }
                elsif ( $type{$name} eq 'text' ) {
                    if (!defined($value{$name})) {
                        #print STDERR "value of $name undefined - defaulting to ''\n";
                        $value{$name} = '';
                    }
                    $worksheet->write_string( $row, $col, $value{$name},
                        $format{$name} );
                }
                else {
                    ## Should only happen for header row
                    $worksheet->write( $row, $col, $value{$name},
                        $format{$name} );
                }
                $col++;
            }
            $insideTable = 1;
            $row++;
            $col = 0;
        }
        elsif ($insideTable) {

            # end of table
            last;
        }
    }

    TWiki::Func::writeDebug( "Exported " . ( $row - 2 ) . " rows." )
      if $config{DEBUG};

    print $query->header( -type => 'application/vnd.ms-excel',
        -expire => 'now' );

 # The Content-Disposition will generate a prompt to save  the file. If you want
 # to stream the file to the browser, comment out the following line.
 #print "Content-Disposition: attachment; filename=$xlsfile\n";
 #print "\n";

    # The contents of the Excel file
    $workbook->close() or die "Error closing file: $!";

    ## If we store the file in pub, why not create an attachment?
#  my $url = TWiki::Func::getScriptUrl( $web, $basetopic, "viewfile" ) . "?rev=;filename=$config{UPLOADFILE}.xls";
#  TWiki::Func::redirectCgiQuery( $query, $url );

}

1;
