# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
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

sub excel2topics {

  my $session = shift;
  $TWiki::Plugins::SESSION = $session;

  my $query = $session->{cgiQuery};
  my $webName = $session->{webName};
  my $topic = $session->{topicName};
  my $user = $session->{user};

  my $log='';

  my %config= (
	       "TEXTTOPIC" => "TEXT",
	       "DEBUG" => 0,
	       "TOPICCOLUMN" => "TOPIC",
	       "FORCCEOVERWRITE" => 0,
	       "UPLOADFILE" => "$topic.xls",
	      );

  foreach my $key (qw(FORM TOPICPARENT UPLOADFILE NEWTOPICTEMPLATE FORCCEOVERWRITE TOPICCOLUMN DEBUG)) {
    my $value=&TWiki::Func::getPreferencesValue( $key  ) || '';
    if (defined $value and $value !~ /^\s*$/) {
      $config{$key} =$value;
      $config{$key} =~ s/^\s*//go;
      $config{$key} =~ s/\s*$//go;
    }
    $log.="  $key=$config{$key}\n";
  }

  my $xlsfile = $TWiki::cfg{PubDir}."/$webName/$topic/$config{UPLOADFILE}";
  $xlsfile = TWiki::Sandbox::untaintUnchecked( $xlsfile );
  $log.="  attachment file=$webName/$topic/$config{UPLOADFILE}\n";

  my $Book = Spreadsheet::ParseExcel::Workbook->Parse($xlsfile);
  if (not defined $Book) {
    throw TWiki::OopsException( 'alert',
				def => 'generic',
				web => $_[2],
				topic => $_[1],
				params => [ 'Cannot read file ', $xlsfile, '', '' ] );

  }

  my %colname;
  foreach my $WorkSheet (@{$Book->{Worksheet}}) {
    TWiki::Func::writeDebug( "--------- SHEET:" . $WorkSheet->{Name} . "\n" ) if $config{DEBUG};
    for (my $col = $WorkSheet->{MinCol} ;	defined $WorkSheet->{MaxCol} && $col <= $WorkSheet->{MaxCol} ; $col++) {
      my $cell = $WorkSheet->{Cells}[0][$col];
      if (defined $cell and $cell->Value ne '') {
	$colname{$col}=$cell->Value if($cell);
	$colname{$col}=~s/\s*//g;
	$log.="  Column $col = $colname{$col}\n";
      }
    }
    for (my $row = $WorkSheet->{MinRow} +1 ; defined $WorkSheet->{MaxRow} && $row <= $WorkSheet->{MaxRow} ; $row++) {
      my %data;			# contains the row
      for (my $col = $WorkSheet->{MinCol} ; defined $WorkSheet->{MaxCol} && $col <= $WorkSheet->{MaxCol} ; $col++) {
	my $cell = $WorkSheet->{Cells}[$row][$col];
	if ($cell) {
	  TWiki::Func::writeDebug( "( $row , $col ) =>" . $cell->Value . "\n" ) if $config{DEBUG};
	  $data{$colname{$col}}=$cell->Value;
	}
      }
      my $newtopic=$data{$config{"TOPICCOLUMN"}};
      next if ($newtopic eq '') ; # Emtpy row

      # Writing the topic
      my $sourceTopic;
      my $changed=0;
      if ( TWiki::Func::topicExists( $webName, $newtopic )) {
	$sourceTopic=$newtopic;
      } else {
	$sourceTopic=$config{"NEWTOPICTEMPLATE"};
	my $msg="$webName/$newtopic: new topic created based on $config{NEWTOPICTEMPLATE}";
	$config{DEBUG} && TWiki::Func::writeWarning($msg);
	$log.="$msg\n";
	$changed=1;
      }

      my ( $meta, $text ) = TWiki::Func::readTopic( $webName, $sourceTopic );
      if (not defined $meta or not defined $text) {
	die "Can't find $sourceTopic";
      }

      for my $key (qw(FORM TOPICPARENT)) {
	if (not defined( ($meta->find("$key"))[0]  ) or
	    not defined(($meta->find("$key"))[0]->{"name"}) or
	    ($meta->find("$key"))[0]->{"name"} ne $config{$key}) {
	  my $msg="      $webName/$newtopic: $key     new value=$config{$key}";
	  $config{DEBUG} && TWiki::Func::writeWarning($msg);
	  $log.="$msg\n";
	  $changed=1;
	  my $elem={
		    "name" =>  $config{$key}
		   };
	  $meta->put($key,$elem);
	}
      }

      foreach my $colname (values %colname) {

	# Overwrite the text. As a safety measure only overwrite the text if it is not empty.
	if ($colname eq $config{"TEXTTOPIC"} 
	    and  not $data{$config{"TEXTTOPIC"}} =~ m/^\s*$/ 
	    and  $data{$config{"TEXTTOPIC"}} ne $text){
	  my $msg="      $webName/$newtopic: topic text has changed";
	  $config{DEBUG} && TWiki::Func::writeWarning($msg);
	  $log.="$msg\n";
	  $log.="vvvvvvvvvvvvvvvvvvv old vvvvvvvvvvvvvvvvvvv \n";
	  $log.="$text\n";
	  $log.="^^^^^^^^^^^^^^^^^^^ old ^^^^^^^^^^^^^^^^^^^ \n";
	  $log.="vvvvvvvvvvvvvvvvvvv new vvvvvvvvvvvvvvvvvvv \n";
	  $log.=$data{$config{"TEXTTOPIC"}}."\n";
	  $log.="^^^^^^^^^^^^^^^^^^^ new ^^^^^^^^^^^^^^^^^^^ \n";

	  $text=$data{$config{TEXTTOPIC}};
	  $changed=1;
	}


	my %field;
	# search through all fields and find the field with the name $colname
	foreach my $field ($meta->find("FIELD")) {
	  if ($$field{"name"} eq $colname) {
	    if ($$field{"value"} ne $data{$colname} ) {
	      my $msg="      $webName/$newtopic: $colname: old value=".$$field{"value"}." new value=$data{$colname}";
	      $config{DEBUG} && TWiki::Func::writeWarning($msg);
	      $log.="$msg\n";
	      $changed=1;
	      # replace CR/LF and "
	      #$data{$colname} =~ s/(\r*\n|\r)/%_N_%/g;
	      #$data{$colname} =~ s/\"/%_Q_%/g;
	      my $fld = {
			 name =>$colname,
			 title=>$colname,
			 value=>$data{$colname},
			};
	      $meta->putKeyed( "FIELD", $fld);
	    }
	    last; # found the field
	  }
	}
      }

      if ($changed) {		# only save if something has changed
	my ( $oopsUrl, $loginName, $unlockTime ) = TWiki::Func::checkTopicEditLock( $webName, $newtopic );
	if ($oopsUrl eq '' or $config{"FORCCEOVERWRITE"}) {
	  # Options chosen were "", 'unlock', 'Notify', "LogSave", ""
	  $newtopic = TWiki::Sandbox::untaintUnchecked( $newtopic );
	  $session->{store}->saveTopic( $user, $webName, $newtopic, $text, $meta, { } );
	  TWiki::Func::setTopicEditLock( $webName, $newtopic,0 );
	  my $msg="### $webName/$newtopic written ###";
	  $config{DEBUG} && TWiki::Func::writeWarning($msg);
	  $log.="$msg\n";
	} else {
	  my $msg="$webName/$newtopic locked and FORCCEOVERWRITE not on -> not overwritten";
	  $config{DEBUG} && TWiki::Func::writeWarning($msg);
	  $log.="$msg\n";
	}
      } else {
	my $msg="$webName/$newtopic not changed -> not written";
	$config{DEBUG} && TWiki::Func::writeWarning($msg);
	$log.="$msg\n";
      }
    }
    last; # only the first sheet
  }

  ## TW: Should use oops dialog
  print $query->header(-type=>'text/plain', -expire=>'now');
  print $log;

}

=pod

---++ sub excel2table ( $session, $params, $theWeb, $theTopic )

Generate a TWiki ML table from an Excel attachment.

=cut

sub excel2table
{
  my( $session, $params, $topic, $webName ) = @_;

  my %config= ( );
  $config{UPLOADFILE} = $params->{"_DEFAULT"} || $params->{file} || $topic;
  $config{UPLOADTOPIC}= $params->{topic} || $topic;
  $config{FORM}       = $params->{template} || $topic;
  $config{DEBUG}      = $TWiki::Plugins::ExcelImportExportPlugin::debug;

  ( $config{UPLOADWEB}, $config{UPLOADTOPIC} ) =
      $TWiki::Plugins::SESSION->normalizeWebTopicName( $webName, $config{UPLOADTOPIC} );


  my $log='';

  my $xlsfile = $TWiki::cfg{PubDir}."/$config{UPLOADWEB}/$config{UPLOADTOPIC}/$config{UPLOADFILE}.xls";
  $log.="  attachment file=$config{UPLOADWEB}/$config{UPLOADTOPIC}/$config{UPLOADFILE}\n";

  my $Book = Spreadsheet::ParseExcel::Workbook->Parse($xlsfile);
  if (not defined $Book) {
    throw TWiki::OopsException( 'alert',
				def => 'generic',
				web => $_[2],
				topic => $_[1],
				params => [ 'Cannot read file ', $xlsfile, '', '' ] );

  }

  my $form = new TWiki::Form( $session, $webName, $config{FORM} );
  my $fieldDefs = $form->{fields};
  my $table = '|';
  foreach my $field ( @{$fieldDefs} ) {
    $table .= '*' . $field->{name} . '*|';
  }
  $table .= "\n";
  

  my %colname;
  foreach my $WorkSheet (@{$Book->{Worksheet}}) {
    TWiki::Func::writeDebug( "--------- SHEET:" . $WorkSheet->{Name} . "\n" ) if $config{DEBUG};
    for (my $col = $WorkSheet->{MinCol} ;	defined $WorkSheet->{MaxCol} && $col <= $WorkSheet->{MaxCol} ; $col++) {
      my $cell = $WorkSheet->{Cells}[0][$col];
      if (defined $cell and $cell->Value ne '') {
	$colname{$col}=$cell->Value if($cell);
	$colname{$col}=~s/\s*//g;
	$log.="  Column $col = $colname{$col}\n";
      }
    }

    for (my $row = $WorkSheet->{MinRow} +1 ; defined $WorkSheet->{MaxRow} && $row <= $WorkSheet->{MaxRow} ; $row++) {
      my %data;			# contains the row
      my $line = '|';
      for (my $col = $WorkSheet->{MinCol} ; defined $WorkSheet->{MaxCol} && $col <= $WorkSheet->{MaxCol} ; $col++) {
	my $cell = $WorkSheet->{Cells}[$row][$col];
	if ($cell) {
	  TWiki::Func::writeDebug( "( $row , $col ) =>" . $cell->Value . "\n" ) if $config{DEBUG};
	  $data{$colname{$col}}=$cell->Value;
	}
      }

      # Generating the table

      foreach my $field ( @{$fieldDefs} ) {
	my $foundIt = 0;
	
	# search through all columns and find that with the name of the field
	foreach my $colname (values %colname) {

	  if ($field->{name} eq $colname) {
	    my $msg="      ( $row , $colname ) => $data{$colname}";
	    TWiki::Func::writeDebug( $msg ) if $config{DEBUG};
	    $log.="$msg\n";
	    # replace CR/LF and "
	    $data{$colname} =~ s/(\r*\n|\r)/<br \/>/gos;
	    $data{$colname} =~ s/\|/\&\#124;/gos;
	    $line .= ' ' . $data{$colname} . ' |';
	    $foundIt = 1;
	    last; # found the field
	  }
	}
	$line .= ' |' unless $foundIt;
      }

      $line .= "\n";
      $table .= $line;
    }
    last; # only the first sheet
  }

  return $table;
}

1;
