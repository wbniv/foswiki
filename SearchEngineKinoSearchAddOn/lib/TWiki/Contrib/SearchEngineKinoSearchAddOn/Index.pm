#!/usr/bin/perl -w
#
# Copyright (C) 2007 Markus Hesse
#
# For licensing info read LICENSE file in the TWiki root.
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
# Set library paths in @INC, at compile time

package TWiki::Contrib::SearchEngineKinoSearchAddOn::Index;
use base TWiki::Contrib::SearchEngineKinoSearchAddOn::KinoSearch;

use KinoSearch::InvIndexer;
use KinoSearch::Analysis::PolyAnalyzer;

use TWiki::Contrib::SearchEngineKinoSearchAddOn::Stringifier;
use strict;

use TWiki::Form;

# New instance to create the index
# QS
sub newCreateIndex {
    my $self = shift;
    return $self->new("index");
}

# New instance to update the index
# QS
sub newUpdateIndex {
    my $self = shift;
    return $self->new("update");
}

# Do the indexing.
# QS
sub createIndex {
    my ( $self, $debug ) = (@_);

    # FIXME: Make it more clear.
    $self->{Debug} = $debug;

    $self->log( "Indexing started", 1 );

    # I read the Fieldnames from the forms and store them in file.
    my %fldNames = $self->formsFieldNames();
    $self->writeFieldNames(%fldNames);

    my $analyzer = $self->analyser( $self->analyserLanguage() );
    my $invindexer = $self->indexer( $analyzer, 1, %fldNames );

    my @webs = $self->websToIndex();

    foreach my $web (@webs) {
        $self->log("Indexing web | $web");

        my $start_time = time();

        foreach my $topic ( TWiki::Func::getTopicList($web) ) {
            $self->log("Indexing topic | $web.$topic");
            $self->indexTopic( $invindexer, $web, $topic, %fldNames );
        }

        $self->saveUpdateMarker( $web, $start_time );
        $self->log("$web .kinoupdate saved");
    }
    $invindexer->finish;
    $self->log( "Indexing finished", 1 );
}

# Do the update.
# QS
sub updateIndex {
    my ( $self, $debug ) = (@_);

    # FIXME: Make it more clear.
    $self->{Debug} = $debug;

    $self->log( "Update started", 1 );

    my @webs = $self->websToIndex();

    # the list of topics to update, by default empty
    my @topicsToUpdate = ();

    foreach my $web (@webs) {
        $self->log("Update web $web");

        my $start_time = time();

        my @topicsToUpdate = $self->changedTopics($web);

        if ( @topicsToUpdate > 0 ) {

            $self->log("remove topics changed");

            # remove topics changed
            $self->removeTopics( $web, @topicsToUpdate );

            # add topics changed
            $self->addTopics( $web, @topicsToUpdate );

        }
        else {

            $self->log("No index update necessary");
        }

        $self->saveUpdateMarker( $web, $start_time );
        $self->log("$web .kinoupdate saved");
    }

    $self->log( "Updating index finished", 1 );
}

# Returns an indexer
# QS
sub indexer {
    my ( $self, $analyzer, $create, %fieldNames ) = @_;

    my $invindexer = KinoSearch::InvIndexer->new(
        invindex => $self->indexPath(),
        create   => $create,
        analyzer => $analyzer,
    );

    $invindexer->spec_field(
        name  => 'topic',
        boost => 3
    );

# I need this unanalysed field to be able to delete documents
# (see http://www.rectangular.com/pipermail/kinosearch/2006-November/000604.html)
    $invindexer->spec_field(
        name     => 'id_topic',
        analyzed => 0
    );

    # Name of the file (only attachments)
    $invindexer->spec_field( name => 'name' );

    $invindexer->spec_field( name => 'bodytext' );

    $invindexer->spec_field( name => 'web' );

    $invindexer->spec_field( name => 'author' );

    $invindexer->spec_field(
        name     => 'version',
        analyzed => 0
    );

    $invindexer->spec_field(
        name     => 'date',
        analyzed => 0
    );

    # Fields specific for attachments:
    $invindexer->spec_field( name => 'comment' );
    $invindexer->spec_field( name => 'attachment' );
    $invindexer->spec_field( name => 'type' );

    # Name of the form, if a topic has one.
    $invindexer->spec_field( name => 'form_name' );

    # Now the fields from the forms:
    foreach my $fldName ( keys %fieldNames ) {
        $invindexer->spec_field( name => $fldName );
    }

    return $invindexer;
}

# Returns the list of attachments for the given topic.
# QS
sub attachmentsOfTopic {
    my ( $self, $web, $topic ) = @_;

    my ( $meta, $text ) = TWiki::Func::readTopic( $web, $topic, undef );

    my @attachments;
    if ($meta) {
        @attachments = $meta->find('FILEATTACHMENT');
    }

    return @attachments;
}

# Yields a list of topics in the given web that were changed since the last update.
# QS
sub changedTopics {
    my ( $self, $web ) = (@_);

    my @changes = $self->readChanges($web);
    my $change;
    my $prevLastmodify = $self->readUpdateMarker($web) || "0";
    my $currLastmodify = "";
    my @topicsToUpdate;

    # do not process the same topic twice
    my %exclude;

    # process the web changes
    foreach $change ( reverse @changes ) {

        # Parse lines from .changes:
        # <topic>	<user>		<change time>	<revision>
        my ( $topicName, $userName, $changeTime, $revision ) =
          split( /\t/, $change );

        if ( ( !%exclude ) || ( !$exclude{$topicName} ) ) {

            if ( !defined($topicName) ) {
                next;
            }

            if ( $prevLastmodify > $changeTime ) {

                # found item of last update
                last;
            }

            $exclude{$topicName} = "1";
            push( @topicsToUpdate, $topicName );
        }
    }
    return @topicsToUpdate;
}

# I remove all topic given in @topicsList from the index.
# QS
sub removeTopics {
    my ( $self, $web, @topicsList ) = @_;

    my $idxpath = $self->indexPath();

    $self->log("Removing old topics from index");

    my $analyzer = $self->analyser( $self->analyserLanguage() );
    my $invindexer = $self->indexer( $analyzer, 0, $self->readFieldNames() );

    # get the list of attachments not to be indexed
    my %skipattachments = $self->skipAttachments;

    # get attachments extension list
    my %indexextensions = $self->indexExtensions;

    foreach my $topic (@topicsList) {
        $self->log("Remove Topic $topic");

        my $term = KinoSearch::Index::Term->new( 'id_topic', $web . $topic );
        $invindexer->delete_docs_by_term($term);

        my @attachments = $self->attachmentsOfTopic( $web, $topic );

        if (@attachments) {
            $self->log("Attachments to delete for: $web, $topic");

            foreach my $attachment (@attachments) {
                my $name = $attachment->{'name'};

                # the attachment extension has to be checked
                my @bits = ( split( /\./, $name ) );
                my $extension = lc $bits[$#bits];

                # also, is the attachment is the skip list?
                if (   ( $indexextensions{".$extension"} )
                    && ( !$skipattachments{"$web.$topic.$name"} ) )
                {

                    $self->log("Removing attachment $web.$topic.$name");
                    my $term = KinoSearch::Index::Term->new( 'id_topic',
                        $web . $topic . $name );

                    $invindexer->delete_docs_by_term($term);
                }
            }
        }
    }

    $invindexer->finish( optimize => 1 );

    undef $invindexer;

    $self->log("Old topics removed succesfully");
}

# Add the topic in @topicsList to the index.
# QS
sub addTopics {
    my ( $self, $web, @topicsList ) = @_;

    my $idxpath = $self->indexPath();

    $self->log("Indexing new/changed topics");

    #my @attachmentList = ();

    my %fldNames   = $self->readFieldNames();
    my $analyzer   = $self->analyser( $self->analyserLanguage() );
    my $invindexer = $self->indexer( $analyzer, 0, %fldNames );

    # get the list of attachments not to be indexed
    my %skipattachments = $self->skipAttachments;

    # get attachments extension list
    my %indexextensions = $self->indexExtensions;

    # get variable names to be indexed
    #my $vars2beIdxd = $self->indexeVariables;
    #$self->log("Variables to be indexed: $vars2beIdxd");

    foreach my $topic (@topicsList) {
        $self->log("Reindexing topic | $web.$topic");

        $self->indexTopic( $invindexer, $web, $topic, %fldNames );
    }

    $invindexer->finish;
    undef $invindexer;

    $self->log("New/changed topics indexed succesfully");

    return 1;
}

# Yields the list of webs to be indexed
# QS
sub websToIndex {
    my $self = shift;

    my @userWebList = TWiki::Func::getListOfWebs("user");
    my %skipwebs    = $self->skipWebs();
    my @webList;

    foreach my $web (@userWebList) {
        if ( $skipwebs{$web} ) {

            #print "Skipping $web topics\n";
            $self->log("Skipping $web topics");
        }
        else {

            #print "Indexing $web topics\n";
            $self->log("adding $web topics");
            push( @webList, $web );
        }
    }
    return @webList;
}

# Yields a hash table keyed on the names of all existing field
# names with the value 1.
# QS
sub formsFieldNames {
    my $self = shift;
    my %fieldNames;
    my @webs = $self->websToIndex();

    my $prefs = $TWiki::Plugins::SESSION->{prefs};

    foreach my $web (@webs) {
        my $legalForms = $prefs->getWebPreferencesValue( 'WEBFORMS', $web );
        if ( !defined($legalForms) ) { next }
        $legalForms =~ s/^\s*//;
        $legalForms =~ s/\s*$//;
        my @forms = split( /[,\s]+/, $legalForms );

        foreach my $formName (@forms) {

# NOTE: I use a new TWiki session with the admin user so that I can access any topic
# even when an access control is defined
#TODO: SMELL: this is a horrible waste of resources, creating _ONE_ TWiki object may be justified
            my $form =
              TWiki::Form->new( new TWiki( $TWiki::cfg{AdminUserLogin} ),
                $web, $formName );
            foreach my $fieldDef ( @{ $form->{fields} } ) {
                my $fldName = $fieldDef->{name};
                $fieldNames{$fldName} = 1 unless $fldName eq "";
            }
        }
    }

    return %fieldNames;
}

# The file, where I want to store the names of fields.
# QS
sub fieldNamesFileName {
    my $self = shift;
    return $self->indexPath() . "/.formFieldNames";
}

# I write the list of form fields in a file
# QS
sub writeFieldNames {
    my ( $self, %fieldNames ) = (@_);
    my $fName = $self->fieldNamesFileName();

    my $FILE;
    if ( open( $FILE, ">$fName" ) ) {
        foreach my $name ( keys %fieldNames ) {
            print $FILE $name, "\n";
        }
        close($FILE);
    }
}

# Yields a hash table keyed on the names of all existing field
# names with the value 1.
# This is the same as formsFieldNames but here I don't read the
# the forms but read the file that was written with writeFieldNames.
# QS
sub readFieldNames {
    my $self  = shift;
    my $fName = $self->fieldNamesFileName();
    my %fieldNames;

    my $FILE;
    if ( open( $FILE, "<$fName" ) ) {
        my @names = <$FILE>;
        close($FILE);
        
        foreach my $name (@names) {
            $name =~ s/\n//;
            $fieldNames{$name} = 1;
        }
    }

    return %fieldNames;
}

# I add the given topic to the index
# QS
sub indexTopic {
    my ( $self, $invindexer, $web, $topic, %fldNames ) = @_;

    my ( $meta, $text ) = TWiki::Func::readTopic( $web, $topic, undef );

    # Eliminate TWiki Makup Language elements and newlines.
    # This is a trick to geht the renderer in 4.0/4.1 as well as in 4.2:
    #  In 4.0/4.1 I can use TWiki->{renderer}. In 4.2 this can give undef.
    #  Thus I have to use TWiki->renderer.
    #  NOTE: In 4.0/4.1 the method TWiki->renderer does not exist, but I
    # should never come there.
    my $renderer;
    if ( !defined( $renderer = $TWiki::Plugins::SESSION->{renderer} ) ) {
        $renderer = $TWiki::Plugins::SESSION->renderer;
    }
    $text = $renderer->TML2PlainText( $text, $web, $topic, "" );
    $text =~ s/\n/ /g;

    # "TheTopic--NNNName" will return the "The Topic Name" string
    my $topicname = splitTheTopicName($topic);
    $topicname = $topic . " " . $topicname;

    # new Kino document for the current topic
    my $doc = $invindexer->new_doc;

    # web can be used as a search criteria
    $doc->set_value( web => $web );

    # topic can be used as a search criteria
    $doc->set_value( topic    => $topicname );
    $doc->set_value( id_topic => $web . $topic );
    $doc->set_value( bodytext => $text );

    # processing the topic meta info
    my ( $date, $author, $rev ) = TWiki::Func::getRevisionInfo( $web, $topic );

    $date = TWiki::Func::formatTime($date);

    # the author can be used as a search criteria
    $doc->set_value( author => $author );

    # version and date are stored as meta data in the doc
    # just for showing them when displaying the hits collection
    $doc->set_value( version => $rev );
    $doc->set_value( date    => $date );

    # Lets see, if we can index some fields:
    if ($meta) {
        my $form = $meta->get('FORM');
        if ($form) {
            $doc->set_value( form_name => $form->{name} );
        }
        my @fields = $meta->find('FIELD');
        if (@fields) {
            foreach my $field (@fields) {
                my $name = $field->{"name"};
                if ( $fldNames{$name} ) {
                    my $value = $field->{"value"};
                    next if (!defined($value)); #field not there.
                    $doc->set_value( $name => $value );
                }
            }
        }
    }

    # add the document to the index
    $invindexer->add_doc($doc);

    # Now I pic up the attachments and store them in @attachmentList
    my @attachments = $self->attachmentsOfTopic( $web, $topic );

    my %indexextensions = $self->indexExtensions();
    my %skipattachments = $self->skipAttachments();

    if (@attachments) {
        $self->log("Attachments available for: $web, $topic");

        foreach my $attachment (@attachments) {
            my $name = $attachment->{'name'};

            # the attachment extension has to be checked
            my @bits = ( split( /\./, $name ) );
            my $extension = lc $bits[$#bits];

            # also, is the attachment is the skip list?
            if (   ( $indexextensions{".$extension"} )
                && ( !$skipattachments{"$web.$topic.$name"} ) )
            {

                #print "Indexing attachment $web.$topic.$name\n";

                $self->indexAttachment( $invindexer, $web, $topic,
                    $attachment );
            }
            else {
                $self->log("Skipping attachment | $web.$topic | $name");
            }
        }
    }
}

# I add the given attachment to the index.
# QS
sub indexAttachment {
    my ( $self, $invindexer, $web, $topic, $attachment ) = @_;

    my $name   = $attachment->{'name'};
    my $author = $attachment->{'user'};
    my $rev    = $attachment->{'version'};

    my @bits = ( split( /\./, $name ) );
    my $extension = lc $bits[$#bits];

    #my $date = $attachment->{'date'};
    #print "#2######## $date ###########\n";
    #my $date    = TWiki::Func::formatTime( $attachment->{'date'} );
    my $comment = $attachment->{'comment'};

    my $pubpath  = $self->pubPath();
    my $filename = "$pubpath/$web/$topic/$name";
    #untaint..
    $filename =~ /(.*)/;
    $filename = $1;
    my $attText =
      TWiki::Contrib::SearchEngineKinoSearchAddOn::Stringifier->stringFor(
        $filename);
        
    return if (!defined($attText)); #attachment may not be there.

    # new Kino document for the current topic
    my $doc = $invindexer->new_doc;

    # web can be used as a search criteria
    $doc->set_value( web => $web );

    # topic can be used as a search criteria
    # FIXME: Is it necessary to modify the topic (see indexTopic)?
    $doc->set_value( topic    => $topic );
    $doc->set_value( id_topic => $web . $topic . $name );
    $doc->set_value( name     => $name );
    $doc->set_value( type     => $extension );
    $doc->set_value( bodytext => $attText );

    # processing the topic meta info
    # the author can be used as a search criteria
    if (defined($author)) {
        $doc->set_value( author => $author );
    }

    # version and date are stored as meta data in the doc
    # just for showing them when displaying the hits collection
    $doc->set_value( version => $rev );

    #if (defined($date)) {
    #	$doc->set_value( date => $date);}

    # This makes the document as an attachment.
    $doc->set_value( attachment => "yes" );
    if ( defined($comment) ) {
        $doc->set_value( comment => $comment );
    }

    # add the document to the index
    $invindexer->add_doc($doc);
}

# Removing the first repeated character. e.g. TTTTheTopic input will return TheTopic
# QS
sub tripFirstchar {
    my $string = shift;
    return "" unless $string;
    my @fields = split //, $string;
    my $firstchar = shift @fields;
    $string =~ s/^$firstchar+/$firstchar/;
    return $string;
}

# Spliting the topic Names e.g. "TheTopic" will return "The Topic"
# QS
sub splitTopicName {
    my $string = shift;

# I replace each capital letter with a space and the letter itself as long as it follows a lower letter.
# FIXME: I also want to work with all special characters but this looks quite agly. Is there a better solution?
    $string =~
s/(ä|ö|ü|ß|á|à|â|ç|é|è|ê|ó|ò|ô|ú|ù|û|[a-z]|[1-9])(Ä|Ö|Ü|Á|À|Â|Ç|É|È|Ê|Ó|Ò|Ô|Ú|Ù|Û|[A-Z])/$1 $2/g;

    return $string;

    #  my @topicfields = split//, $string;
    #  my $flag = 1; my $seccap = 0;
    #  my $str = "";
    #  foreach (@topicfields) {
    #    if (/[A-Z]/){ $flag=1; } else { $flag =0; }
    #    if($flag == 1) {
    #	if (/[A-Z]/) {
    #	    $flag=0;
    #	    if ($seccap==1){$str = $str." ";}
    #	    $str = $str . $_;
    #	    $seccap=0;
    #	}
    #    }
    #    else {$str = $str . $_; $seccap = 1; }
    #  }
    #  my $topicname = $str;
    #  return $topicname;
}

# Spliting the topic Name e.g. "TheTopic--NNNName" will return the "The Topic Name " string
# QS
sub splitTheTopicName {
    my $string = shift;
    my @fields = split //, $string;
    my $newstr = "";

# Fist I strip ut things like "_", ".", ...
# FIXME: I want to keep special chars but this looks quite agly. Is there a better solution?
    foreach (@fields) {
        if (
/Ä|Ö|Ü|ä|ö|ü|ß|á|Á|à|À|â|Â|ç|Ç|é|É|è|È|ê|Ê|ó|Ó|ò|Ò|ô|Ô|ú|Ú|ù|Ù|û|Û|[A-Z]|[a-z]|[0-9]/
          )
        {
            $newstr = $newstr . $_;
        }
        else { $newstr = $newstr . " "; }
    }

    # I remove all double spaces
    $newstr =~ s/\s+/ /g;

    # Now I split the topic name on each capital letter
    my @newfields = split / /, $newstr;
    my $finalstr = "";
    foreach (@newfields) {
        my $str = splitTopicName($_);
        $finalstr = $finalstr . $str . " ";
    }

    # Now I remove double characters at the beginning of a word.
    @newfields = split / /, $finalstr;
    $finalstr = "";
    foreach (@newfields) {
        my $str = tripFirstchar($_);
        $finalstr = $finalstr . $str . " ";
    }
    return $finalstr;
}

# QS
sub updateMarkerFile {
    my ( $self, $web ) = @_;

    my $file = $TWiki::cfg{DataDir} . "/$web/.kinoupdate";

    return $file;
}

# QS
sub saveUpdateMarker {
    my ( $self, $web, $start_time ) = @_;

    my $file = $self->updateMarkerFile($web);

    my $FILE;
    if (open( $FILE, ">$file" )) {
        print $FILE $start_time;
        close($FILE);
    }
}

# QS
sub readUpdateMarker {
    my ( $self, $web ) = @_;

    my $file = $self->updateMarkerFile($web);

    if ( -e $file ) {
        my $FILE;
        if (open( $FILE, "<$file" )) {
            my $data = <$FILE>;
            close($FILE);
            return $data;
        }
    }
    return '';
}

# QS
sub readChanges {
    my ( $self, $web ) = @_;

    my $changes_file = $TWiki::cfg{DataDir} . "/$web/.changes";

    if ( -e $changes_file ) {
        my $FILE;
        if (open( $FILE, "<$changes_file" )) {
            my @data = <$FILE>;
            close($FILE);
            return @data;
        }
    }
    return '';
}

1;
