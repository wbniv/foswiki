# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
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

package TWiki::Plugins::ExcelImportExportPlugin::Import;

use strict;
use Spreadsheet::ParseExcel;
use TWiki;
use TWiki::Func;
use TWiki::Render;
use TWiki::Meta;
use TWiki::Form;

sub excel2topics {

    my $session = shift;
    $TWiki::Plugins::SESSION = $session;

    my $query   = $session->{cgiQuery};
    my $webName = $session->{webName};
    my $topic   = $session->{topicName};
    my $user    = $session->{user};

    my $log = '';

    my %config = (
        "TOPICTEXT"       => "TEXT",
        "DEBUG"           => 0,
        "TOPICCOLUMN"     => "TOPIC",
        "FORCCEOVERWRITE" => 0,
        "UPLOADFILE"      => "$topic.xls",
    );

    foreach my $key (
        qw(FORM TOPICPARENT UPLOADFILE NEWTOPICTEMPLATE FORCCEOVERWRITE TOPICCOLUMN DEBUG)
      )
    {
        my $value = &TWiki::Func::getPreferencesValue($key) || '';
        if ( defined $value and $value !~ /^\s*$/ ) {
            $config{$key} = $value;
            $config{$key} =~ s/^\s*//go;
            $config{$key} =~ s/\s*$//go;
        }
    }

    $config{UPLOADFILE}  = $query->param('file')        || $config{UPLOADFILE};
    $config{FORM}        = $query->param('template')    || $config{FORM};
    $config{TOPICCOLUMN} = $query->param('topiccolumn') || $config{TOPICCOLUMN};
    $config{TOPICTEXT}   = $query->param('topictext')   || $config{TOPICTEXT};
    $config{NEWTOPICTEMPLATE} = $query->param('newtopictemplate')
      || $config{NEWTOPICTEMPLATE};
    $config{DEBUG} = $TWiki::Plugins::ExcelImportExportPlugin::debug;

    #use the current definition of the TWikiForm
    my $formDef = new TWiki::Form( $session, $webName, $config{FORM} );
    unless ($formDef) {
        throw TWiki::OopsException(
            'attention',
            def    => 'no_form_def',
            web    => $session->{webName},
            topic  => $session->{topicName},
            params => [ $webName, $config{FORM} ]
        );
    }

    foreach my $key (
        qw(FORM TOPICPARENT UPLOADFILE NEWTOPICTEMPLATE FORCCEOVERWRITE TOPICCOLUMN TOPICTEXT DEBUG)
      )
    {
        $log .= "  $key=" . ( $config{$key} || 'undef' ) . "\n";
    }

    my $xlsfile = $TWiki::cfg{PubDir} . "/$webName/$topic/$config{UPLOADFILE}";
    $xlsfile = TWiki::Sandbox::untaintUnchecked($xlsfile);
    $log .= "  attachment file=$webName/$topic/$config{UPLOADFILE}\n";

    my $Book = Spreadsheet::ParseExcel::Workbook->Parse($xlsfile);
    if ( not defined $Book ) {
        throw TWiki::OopsException(
            'alert',
            def    => 'generic',
            web    => $_[2],
            topic  => $_[1],
            params => [ 'Cannot read file ', $xlsfile, '', '' ]
        );

    }

    my %colname;
    foreach my $WorkSheet ( @{ $Book->{Worksheet} } ) {
        TWiki::Func::writeDebug(
            "--------- SHEET:" . $WorkSheet->{Name} . "\n" )
          if $config{DEBUG};
        for (
            my $col = $WorkSheet->{MinCol} ;
            defined $WorkSheet->{MaxCol} && $col <= $WorkSheet->{MaxCol} ;
            $col++
          )
        {
            my $cell = $WorkSheet->{Cells}[0][$col];
            if ( defined $cell and $cell->Value ne '' ) {
                $colname{$col} = cleanField( $cell->Value ) if ($cell);
                $log .= "  Column $col = $colname{$col}\n";
            }
        }
        my $ct = 0;
        for (
            my $row = $WorkSheet->{MinRow} + 1 ;
            defined $WorkSheet->{MaxRow} && $row <= $WorkSheet->{MaxRow} ;
            $row++
          )
        {
            my %data;    # contains the row
            for (
                my $col = $WorkSheet->{MinCol} ;
                defined $WorkSheet->{MaxCol} && $col <= $WorkSheet->{MaxCol} ;
                $col++
              )
            {
                my $cell = $WorkSheet->{Cells}[$row][$col];
                if ($cell) {
                    TWiki::Func::writeDebug(
                        "( $row , $col ) =>" . $cell->Value . "\n" )
                      if $config{DEBUG};
                    $data{ $colname{$col} } = $cell->Value;
                }
            }
            my $newtopic;
            if ( defined( $data{ $config{TOPICCOLUMN} } ) ) {
                $newtopic = $data{ $config{TOPICCOLUMN} };
            }
            else {
## SMELL: Make default topic name configurable
                $newtopic = 'ExcelRow' . $ct++;
            }
            next if ( $newtopic eq '' );    # Emtpy row

            # Writing the topic
            my $sourceTopic;
            my $changed = 0;
            if ( TWiki::Func::topicExists( $webName, $newtopic ) ) {
                $sourceTopic = $newtopic;
            }
            else {
                $sourceTopic = $config{"NEWTOPICTEMPLATE"};
                my $msg =
"$webName/$newtopic: new topic created based on $config{NEWTOPICTEMPLATE}";
                $config{DEBUG} && TWiki::Func::writeWarning($msg);
                $log .= "$msg\n";
                $changed = 1;
            }

            my ( $meta, $text ) =
              TWiki::Func::readTopic( $webName, $sourceTopic );
            if ( not defined $meta or not defined $text ) {
                die "Can't find $sourceTopic";
            }

            for my $key (qw(FORM TOPICPARENT)) {
                if (   not defined( ( $meta->find("$key") )[0] )
                    or not defined( ( $meta->find("$key") )[0]->{"name"} )
                    or ( $meta->find("$key") )[0]->{"name"} ne $config{$key} )
                {
                    my $msg =
"      $webName/$newtopic: $key     new value=$config{$key}";
                    $config{DEBUG} && TWiki::Func::writeWarning($msg);
                    $log .= "$msg\n";
                    $changed = 1;
                    my $elem = { "name" => $config{$key} };
                    $meta->put( $key, $elem );
                }
            }

            foreach my $colname ( values %colname ) {

# Overwrite the text. As a safety measure only overwrite the text if it is not empty.
                if (    $colname eq $config{TOPICTEXT}
                    and not $data{ $config{TOPICTEXT} } =~ m/^\s*$/
                    and $data{ $config{TOPICTEXT} } ne $text )
                {
                    my $msg =
"      $webName/$newtopic: topic text has changed in column named: ["
                      . $config{TOPICTEXT}
                      . " / $colname]";
                    $config{DEBUG} && TWiki::Func::writeWarning($msg);
                    $log .= "$msg\n";
                    $log .= "vvvvvvvvvvvvvvvvvvv old vvvvvvvvvvvvvvvvvvv \n";
                    $log .= "$text\n";
                    $log .= "^^^^^^^^^^^^^^^^^^^ old ^^^^^^^^^^^^^^^^^^^ \n";
                    $log .= "vvvvvvvvvvvvvvvvvvv new vvvvvvvvvvvvvvvvvvv \n";
                    $log .= $data{ $config{TOPICTEXT} } . "\n";
                    $log .= "^^^^^^^^^^^^^^^^^^^ new ^^^^^^^^^^^^^^^^^^^ \n";

                    $text    = $data{ $config{TOPICTEXT} };
                    $changed = 1;
                }

                my %field;
## SMELL: Only copies the entries that are in the topic template. Should
## SMELL: this be the topics listed in the form/map instead?
           # search through all fields and find the field with the name $colname
                my $foundField;
                foreach my $field ( $meta->find("FIELD") ) {

                    #        $log .= "....$field?\n";
                    if ( $$field{"title"} eq $colname ) {

#$log .= $$field{"title"}." eq $colname ... ".$$field{"value"}." ne ".$data{$colname}."\n";
#print STDERR join(', ', ($newtopic, ($colname||'undef'), ($data{$colname}||'undef'), ($$field{"value"}||'undef'),  "\n"));
                        if (
                            ( defined( $data{$colname} ) )
                            && #undefined incoming value == don't change the value in the topic.
                            (
                                ( $$field{"value"} || 'undef' ) ne
                                $data{$colname}
                            )
                          )
                        { #undefined value in the topic == do change the value if we can.
                            $log .=
                              ( $$field{"value"} || 'undef' ) . " ne "
                              . $data{$colname} . "\n";
                            my $msg =
                                "      $webName/$newtopic: $colname: old value="
                              . $$field{"value"}
                              . " new value=$data{$colname}";
                            $config{DEBUG} && TWiki::Func::writeWarning($msg);
                            $log .= "$msg\n";
                            $changed = 1;

                            my $fld = {
                                name  => cleanField($colname),
                                title => $colname,
                                value => $data{$colname},
                            };
                            $meta->putKeyed( "FIELD", $fld );
                        }
                        $foundField = 1;
                        last;    # found the field
                    }
                }

                #if the field was not in the topic, see if it should
                unless ($foundField) {
                    if ( grep { $colname eq $_->{name} }
                        @{ $formDef->getFields() } )
                    {
                        $log .= "adding missing $colname\n";
                        my $fld = {
                            name  => cleanField($colname),
                            title => $colname,
                            value => $data{$colname},
                        };
                        $meta->putKeyed( "FIELD", $fld );
                        $changed = 1;
                    }
                }

            }

            if ($changed) {    # only save if something has changed
                my ( $oopsUrl, $loginName, $unlockTime ) =
                  TWiki::Func::checkTopicEditLock( $webName, $newtopic );
                if ( $oopsUrl eq '' or $config{"FORCCEOVERWRITE"} ) {

                    # Options chosen were "", 'unlock', 'Notify', "LogSave", ""
                    $newtopic = TWiki::Sandbox::untaintUnchecked($newtopic);
                    $session->{store}
                      ->saveTopic( $user, $webName, $newtopic, $text, $meta,
                        {} );
                    TWiki::Func::setTopicEditLock( $webName, $newtopic, 0 );
                    my $msg = "### $webName/$newtopic written ###";
                    $config{DEBUG} && TWiki::Func::writeWarning($msg);
                    $log .= "$msg\n";
                }
                else {
                    my $msg =
"$webName/$newtopic locked and FORCCEOVERWRITE not on -> not overwritten";
                    $config{DEBUG} && TWiki::Func::writeWarning($msg);
                    $log .= "$msg\n";
                }
            }
            else {
                my $msg = "$webName/$newtopic not changed -> not written";
                $config{DEBUG} && TWiki::Func::writeWarning($msg);
                $log .= "$msg\n";
            }
        }
        last;    # only the first sheet
    }

    ## TW: Should use oops dialog
    print $query->header( -type => 'text/plain', -expire => 'now' );
    print $log;

}

=pod

---++ cleanField(string) => string
clean the field name - remove spaces, and nop's


=cut

sub cleanField {
    my $val = shift;

    # replace CR/LF and "
    ## SMELL: Need to use new format
    #$data{$colname} =~ s/(\r*\n|\r)/%_N_%/g;
    #$data{$colname} =~ s/\"/%_Q_%/g;

    $val =~ s/<\/?(nop|noautolink)\/?>//go;
    $val =~ s/\s//g;

    return $val;
}

=pod

---++ sub excel2table ( $session, $params, $theWeb, $theTopic )

Generate a TWiki ML table from an Excel attachment.

=cut

sub excel2table {
    my ( $session, $params, $topic, $webName ) = @_;

    my %config = ();
    $config{UPLOADFILE}  = $params->{"_DEFAULT"} || $params->{file} || $topic;
    $config{UPLOADTOPIC} = $params->{topic}      || $topic;
    $config{FORM}        = $params->{template}   || '';
    $config{DEBUG} = $TWiki::Plugins::ExcelImportExportPlugin::debug;

    ( $config{UPLOADWEB}, $config{UPLOADTOPIC} ) =
      $TWiki::Plugins::SESSION->normalizeWebTopicName( $webName,
        $config{UPLOADTOPIC} );

    my $log = '';

    my $xlsfile = $TWiki::cfg{PubDir}
      . "/$config{UPLOADWEB}/$config{UPLOADTOPIC}/$config{UPLOADFILE}.xls";
    $log .=
"  attachment file=$config{UPLOADWEB}/$config{UPLOADTOPIC}/$config{UPLOADFILE}\n";

    my $Book = Spreadsheet::ParseExcel::Workbook->Parse($xlsfile);
    if ( not defined $Book ) {
        throw TWiki::OopsException(
            'alert',
            def    => 'generic',
            web    => $_[2],
            topic  => $_[1],
            params => [ 'Cannot read file ', $xlsfile, '', '' ]
        );

    }

    my $form      = new TWiki::Form( $session, $webName, $config{FORM} );
    my $fieldDefs = $form->{fields};
    my $table     = '|';
    foreach my $field ( @{$fieldDefs} ) {
        $table .= '*' . $field->{title} . '*|';
    }
    $table .= "\n";

    my %colname;
    foreach my $WorkSheet ( @{ $Book->{Worksheet} } ) {
        TWiki::Func::writeDebug(
            "--------- SHEET:" . $WorkSheet->{Name} . "\n" )
          if $config{DEBUG};
        for (
            my $col = $WorkSheet->{MinCol} ;
            defined $WorkSheet->{MaxCol} && $col <= $WorkSheet->{MaxCol} ;
            $col++
          )
        {
            my $cell = $WorkSheet->{Cells}[0][$col];
            if ( defined $cell and $cell->Value ne '' ) {
                $colname{$col} = $cell->Value if ($cell);
                $log .= "  Column $col = $colname{$col}\n";
            }
        }

        for (
            my $row = $WorkSheet->{MinRow} + 1 ;
            defined $WorkSheet->{MaxRow} && $row <= $WorkSheet->{MaxRow} ;
            $row++
          )
        {
            my %data;    # contains the row
            my $line = '|';
            for (
                my $col = $WorkSheet->{MinCol} ;
                defined $WorkSheet->{MaxCol} && $col <= $WorkSheet->{MaxCol} ;
                $col++
              )
            {
                my $cell = $WorkSheet->{Cells}[$row][$col];
                if ($cell) {
                    TWiki::Func::writeDebug(
                        "( $row , $col ) =>" . $cell->Value . "\n" )
                      if $config{DEBUG};
                    $data{ $colname{$col} } = $cell->Value;
                }
            }

            # Generating the table

            foreach my $field ( @{$fieldDefs} ) {
                my $foundIt = 0;

           # search through all columns and find that with the name of the field
                foreach my $colname ( values %colname ) {

                    if ( $field->{title} eq $colname ) {
                        my $msg =
                          "      ( $row , $colname ) => $data{$colname}";
                        TWiki::Func::writeDebug($msg) if $config{DEBUG};
                        $log .= "$msg\n";

                        # replace CR/LF and "
                        $data{$colname} =~ s/(\r*\n|\r)/<br \/>/gos;
                        $data{$colname} =~ s/\|/\&\#124;/gos;
                        $line .= ' ' . $data{$colname} . ' |';
                        $foundIt = 1;
                        last;    # found the field
                    }
                }
                $line .= ' |' unless $foundIt;
            }

            $line  .= "\n";
            $table .= $line;
        }
        last;                    # only the first sheet
    }

    return $table;
}

=pod

---++ sub uploadexcel2table ( $session )

Generate a TWiki ML table from an Excel attachment.

=cut

sub uploadexcel2table {
    my $session = shift;
    $TWiki::Plugins::SESSION = $session;
    my $query     = $session->{cgiQuery};
    my $webName   = $session->{webName};
    my $topicName = $session->{topicName};
    my $userName  = $session->{user};

    my %config = ();
    $config{UPLOADTOPIC} = $query->param('uploadtopic') || $topicName;
    $config{FORM}        = $query->param('template')    || '';
    $config{DEBUG} = $TWiki::Plugins::ExcelImportExportPlugin::debug;

    ( $config{UPLOADWEB}, $config{UPLOADTOPIC} ) =
      $session->normalizeWebTopicName( $webName,
        TWiki::Sandbox::untaintUnchecked( $config{UPLOADTOPIC} ) );

    my $log = '';

    # Copied from TWiki::UI::Upload.pm
    my $filePath = $query->param('filepath') || '';
    my $fileName = $query->param('filename') || '';
    if ( $filePath && !$fileName ) {
        $filePath =~ m|([^/\\]*$)|;
        $fileName = $1;
    }

    my $stream;

    # SMELL: Does $stream get closed in all throws?
    my $xlsfile = $query->upload('filepath');

    my $Book = Spreadsheet::ParseExcel::Workbook->Parse($xlsfile);
    if ( not defined $Book ) {
        throw TWiki::OopsException(
            'alert',
            def    => 'generic',
            web    => $_[2],
            topic  => $_[1],
            params => [ 'Cannot read file ', $xlsfile, '', '' ]
        );

    }

    my $form      = new TWiki::Form( $session, $webName, $config{FORM} );
    my $fieldDefs = $form->{fields};
    my $table     = '|';
    foreach my $field ( @{$fieldDefs} ) {
        $table .= '*' . $field->{title} . '*|';
    }
    $table .= "\n";

    my %colname;
    foreach my $WorkSheet ( @{ $Book->{Worksheet} } ) {
        TWiki::Func::writeDebug(
            "--------- SHEET:" . $WorkSheet->{Name} . "\n" )
          if $config{DEBUG};
        for (
            my $col = $WorkSheet->{MinCol} ;
            defined $WorkSheet->{MaxCol} && $col <= $WorkSheet->{MaxCol} ;
            $col++
          )
        {
            my $cell = $WorkSheet->{Cells}[0][$col];
            if ( defined $cell and $cell->Value ne '' ) {
                $colname{$col} = $cell->Value if ($cell);
                $log .= "  Column $col = $colname{$col}\n";
            }
        }

        for (
            my $row = $WorkSheet->{MinRow} + 1 ;
            defined $WorkSheet->{MaxRow} && $row <= $WorkSheet->{MaxRow} ;
            $row++
          )
        {
            my %data;    # contains the row
            my $line = '|';
            for (
                my $col = $WorkSheet->{MinCol} ;
                defined $WorkSheet->{MaxCol} && $col <= $WorkSheet->{MaxCol} ;
                $col++
              )
            {
                my $cell = $WorkSheet->{Cells}[$row][$col];
                if ($cell) {
                    TWiki::Func::writeDebug(
                        "( $row , $col ) =>" . $cell->Value . "\n" )
                      if $config{DEBUG};
                    $data{ $colname{$col} } = $cell->Value;
                }
            }

            # Generating the table
            foreach my $field ( @{$fieldDefs} ) {
                my $foundIt = 0;

           # search through all columns and find that with the name of the field
                foreach my $colname ( values %colname ) {

                    if ( $field->{title} eq $colname ) {
                        my $msg =
                          "      ( $row , $colname ) => $data{$colname}";
                        TWiki::Func::writeDebug($msg) if $config{DEBUG};
                        $log .= "$msg\n";

                        # replace CR/LF and "
                        $data{$colname} =~ s/(\r*\n|\r)/<br \/>/gos;
                        $data{$colname} =~ s/\|/\&\#124;/gos;

                        #$line .= ' ' . $data{$colname} . ' |';
                        $line .= $data{$colname} . '|';
                        $foundIt = 1;
                        last;    # found the field
                    }
                }
                $line .= ' |' unless $foundIt;
            }

            $line  .= "\n";
            $table .= $line;
        }
        last;                    # only the first sheet
    }

    my $insideTable = 0;
    my $enableForm  = 0;
    my $result      = '';
    my $enabled     = 1;         # Only deal with the first table in a topic

    foreach (
        split(
            /\r?\n/,
            &TWiki::Func::readTopicText( $config{UPLOADWEB},
                $config{UPLOADTOPIC}, "", 1 )
              . "\n<nop>\n"
        )
      )
    {
        if ( $enabled && /^(\s*)\|.*\|\s*$/ ) {

            # found table row
            $insideTable = 1;
        }
        elsif ($insideTable) {

            # end of table
            $insideTable = 0;
            $enabled     = 0;
            ## Fix arguments
            $result .= $table;
        }
        $result .= "$_\n" unless $insideTable;
    }

    $result =~ s|\n?<nop>\n$||o
      ;    # clean up hack that handles EDITTABLE correctly if at end

    doEnableEdit( $config{UPLOADWEB}, $config{UPLOADTOPIC}, 0 );
    my $error =
      TWiki::Func::saveTopicText( $config{UPLOADWEB}, $config{UPLOADTOPIC},
        $result, '', 1 );
    TWiki::Func::setTopicEditLock( $config{UPLOADWEB}, $config{UPLOADTOPIC},
        0 );    # unlock Topic
    my $url =
      TWiki::Func::getViewUrl( $config{UPLOADWEB}, $config{UPLOADTOPIC} );
    if ($error) {
        $url = TWiki::Func::getOopsUrl( $webName, $topicName, 'oopssaveerr',
            $error );
    }

    # and finally display topic, and move to edited line
    TWiki::Func::redirectCgiQuery( $query, $url );

}

## SMELL the following code is copied from EditTablerowPlugin
sub doEnableEdit {
    my ( $theWeb, $theTopic, $doCheckIfLocked ) = @_;

    TWiki::Func::writeDebug(
        "- ExcelImportExportPlugin::doEnableEdit( $theWeb, $theTopic )")
      if $TWiki::Plugins::ExcelImportExportPlugin::debug;

    my $wikiUserName = TWiki::Func::getWikiUserName();
    if (
        !TWiki::Func::checkAccessPermission(
            'change', $wikiUserName, '', $theTopic, $theWeb
        )
      )
    {

        # user has no permission to change the topic
        throw TWiki::OopsException(
            'accessdenied',
            def    => 'topic_access',
            web    => $theWeb,
            topic  => $theTopic,
            params => [ 'change', 'denied' ]
        );
    }

    my ( $oopsUrl, $lockUser ) =
      TWiki::Func::checkTopicEditLock( $theWeb, $theTopic );
    if ( ($doCheckIfLocked) && ($lockUser) ) {

        # warn user that other person is editing this topic
        TWiki::Func::redirectCgiQuery( $TWiki::Plugins::SESSION->{cgiQuery},
            $oopsUrl );
        return 0;
    }
    TWiki::Func::setTopicEditLock( $theWeb, $theTopic, 1 );

    return 1;
}

1;
