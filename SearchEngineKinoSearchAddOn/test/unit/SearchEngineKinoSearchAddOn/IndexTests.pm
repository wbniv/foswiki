# Test for Index.pm
package IndexTests;
use base qw( TWikiFnTestCase );

use strict;


use TWiki::Contrib::SearchEngineKinoSearchAddOn::Index;
use TWiki::Contrib::SearchEngineKinoSearchAddOn::Search;

sub new {
    my $self = shift()->SUPER::new('Index', @_);
    
    $self->{attachmentDir} = 'attachement_examples/';
    if (! -e $self->{attachmentDir}) {
        #running from twiki/test/unit
        $self->{attachmentDir} = 'SearchEngineKinoSearchAddOn/attachement_examples/';
    }
    
    return $self;
}

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    # Use RcsLite so we can manually gen topic revs
    #$TWiki::cfg{StoreImpl} = 'RcsLite';

    #$this->registerUser("TestUser", "User", "TestUser", 'testuser@an-address.net');
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
}

sub test_newCreateIndex {
    my $this = shift;
    my $ind = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index->newCreateIndex();

    $this->assert(defined($ind), "Index exemplar not created.")
}

sub test_newUpdateIndex {
    my $this = shift;
    my $ind = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index->newUpdateIndex();

    $this->assert(defined($ind), "Index exemplar not created.")
}

sub test_createIndex {
    my $this = shift;
    $this->_createTopicWithoutAttachment();
    $this->_createTopicWithWordAttachment();

    my $ind = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index->newCreateIndex();

    $ind->createIndex();

    # I check the succuessful created index by doing some searches.
    $this->_indexOK();
}

# I test that I can index a web even if it has access control
# NOTE: There was a problem when a Form existed in an access controlled web.
sub test_createIndexWithAccessControl {
    my $this = shift;
    $this->_createTopicWithoutAttachment();
    $this->_createTopicWithWordAttachment();

    my $currUser = $TWiki::cfg{DefaultUserLogin};

    # No I set the ALLOWWEBVIEW stuff
    $this->{twiki}->{store}->saveTopic(
        $currUser, $this->{test_web}, $TWiki::cfg{WebPrefsTopicName},
        <<THIS
If ALLOWWEB is set to a list of wikinames
    * people in the list will be PERMITTED
    * everyone else will be DENIED
\t* Set ALLOWWEBVIEW = MrGreen MrYellow MrWhite
\t* Set WEBFORMS = TestForm
THIS
                                , undef);
    # Now the Form topic
    $this->{twiki}->{store}->saveTopic(
        $currUser, $this->{test_web}, "TestForm",
        <<THIS
| *Name* | *Type* | *Size* | *Values* | *Tooltip message* | *Attributes* | 
| TipoAttivita | select | 1 |  | Selezionare il tipo di attivita effettuata | |
| Autore | label | 40 | | |				       
THIS
                                , undef);

    # Let's try to do the index
    my $ind = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index->newCreateIndex();
    $ind->createIndex();

    # I check the succuessful created index by doing some searches.
    $this->_indexOK();
}

sub test_updateIndex {
    my $this = shift;
    my $ind = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index->newUpdateIndex();

    # First I create the index of the current state
    $ind->createIndex();

    my $search = TWiki::Contrib::SearchEngineKinoSearchAddOn::Search->newSearch();
    my $docs = $search->docsForQuery( "updatedpoint");
    my $hit  = $docs->fetch_hit_hashref;
    $this->assert(!defined($hit), "Hit for updatepoint found. Should be undefined!");

    # Now I do some changes
    $this->{twiki}->{store}->saveTopic($this->{twiki}->{user},$this->{users_web}, "NewOrChangedTopicUpdate", <<'HERE');
Just an example topic
Keyword: updatedpoint
HERE
    $this->{twiki}->{store}->saveTopic($this->{twiki}->{user},$this->{users_web}, "NewOrChangedTopicUpdate2", <<'HERE');
Just an example topic
Keyword: secondupdatedpoint
HERE

    # Now I update the index.
    $ind->updateIndex();

    # The new topics should be found now.
    $docs = $search->docsForQuery( "updatedpoint");
    $hit  = $docs->fetch_hit_hashref;
    $this->assert(defined($hit), "Hit for updatedpoint not found.");
    my $topic = $hit->{topic};
    $topic =~ s/ .*//;
    $this->assert_str_equals($topic, "NewOrChangedTopicUpdate", "Wrong topic for update topic.");

    
    $docs = $search->docsForQuery( "secondupdatedpoint");
    $hit  = $docs->fetch_hit_hashref;
    $this->assert(defined($hit), "Hit for secondupdatedpoint not found.");
    $topic = $hit->{topic};
    $topic =~ s/ .*//;
    $this->assert_str_equals($topic, "NewOrChangedTopicUpdate2", "Wrong topic for update2 topic.");

    # Lets delete a topic
    $this->{twiki}->{store}->moveTopic($this->{users_web}, "NewOrChangedTopicUpdate",
				       "Trash", "NewOrChangedTopicUpdate",
				       $this->{twiki}->{user});

    # Now I update the index. 
    $ind->updateIndex();
    $docs = $search->docsForQuery( "updatedpoint");
    $hit  = $docs->fetch_hit_hashref;
    $this->assert(!defined($hit), "Hit for deleted topic found. Should be undefined!");

    # Now let's add an attachment
    $this->{twiki}->{store}->saveAttachment($this->{users_web}, "NewOrChangedTopicUpdate2", "Simple_example.doc",
					    $this->{twiki}->{user}, {file => $this->{attachmentDir}."Simple_example.doc"});
    
    $ind->updateIndex();
    $docs = $search->docsForQuery( "dummy");
    $hit  = $docs->fetch_hit_hashref;
    $this->assert(defined($hit), "Attached doc not found");
    $this->assert_str_equals($topic, "NewOrChangedTopicUpdate2", "Wrong topic for attach.");

    # Now let't change the attachment
    $this->{twiki}->{store}->saveAttachment($this->{users_web}, "NewOrChangedTopicUpdate2", "Simple_example.doc",
					    $this->{twiki}->{user}, {file => $this->{attachmentDir}."Simple_example2.doc"});
    $ind->updateIndex();
    $docs = $search->docsForQuery( "additions");
    $hit  = $docs->fetch_hit_hashref;
    $this->assert(defined($hit), "Attached changed doc not found");
    $this->assert_str_equals($topic, "NewOrChangedTopicUpdate2", "Wrong topic for changed attach.");
}

sub test_indexer {
    my $this = shift;
    my $ind = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index->newCreateIndex();

    my $analyser = $ind->analyser('de');
    my $indexer  = $ind->indexer($analyser, 0, $ind->readFieldNames());

    $this->assert(defined($indexer), "Indexer not created.");
}

sub test_attachmentsOfTopic {
    my $this = shift;
    $this->_createTopicWithWordAttachment();
    my $ind = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index->newCreateIndex();

    my @atts;

    @atts = $ind->attachmentsOfTopic($this->{users_web}, "TopicWithoutAttachment");
    $this->assert(!@atts, "Atts should be undefined.");

    @atts = $ind->attachmentsOfTopic($this->{users_web}, "TopicWithWordAttachment");
    $this->assert(@atts, "Atts should be defined.");
    $this->assert_str_equals($atts[0]->{'name'}, "Simple_example.doc", "Attachment name not O.K.");
}

sub test_changedTopics {
    my $this = shift;
    $this->_createTopicWithoutAttachment();  
    my $ind = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index->newCreateIndex();

    # The "+1" is a littel trick: The Topics created in set_up may have the same 
    # timestamp as time(). Wiht time()+1 I ensure, that the timestamp is bigger.
    my $start_time = time()+1;
    $ind->saveUpdateMarker($this->{users_web}, $start_time);

    my @changes;
    my $change;

    # No there should not be any changed topics after the mark I just set.
    @changes = $ind->changedTopics($this->{users_web});
    $this->assert(!@changes, "Changes found even if there are non.");
    
    # Now I do a change
    $this->{twiki}->{store}->saveTopic($this->{twiki}->{user},$this->{users_web}, "NewOrChangedTopic", <<'HERE');
Just an example topic
Keyword: startpoint
HERE

    @changes = $ind->changedTopics($this->{users_web});

    $this->assert(@changes, "Changed topics not returned.");

    # The first change should be the one I just did. 
    foreach $change (@changes ){
	$this->assert_str_equals($change, "NewOrChangedTopic", "Last change not detected.");
	last;
    }

    $start_time = time();
    $ind->saveUpdateMarker($this->{users_web}, $start_time);

    # Lets delete a topic
    $this->{twiki}->{store}->moveTopic($this->{users_web}, "TopicWithoutAttachment",
				       "Trash", "NewOrChangedTopic",
				       $this->{twiki}->{user});

    @changes = $ind->changedTopics($this->{users_web});

    $this->assert(@changes, "Changed topics not returned.");

    # The first change should be the one I just did. 
    foreach $change (@changes ){
	$this->assert_str_equals($change, "TopicWithoutAttachment", "Last change not detected.");
	last;
    }
}

sub test_removeTopics {
    my $this = shift;
    $this->_createTopicWithoutAttachment();  
    my $ind = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index->newCreateIndex();

    # First I create the index
    $ind->createIndex();

    # Let's check, that a certain topic exists.
    my $search = TWiki::Contrib::SearchEngineKinoSearchAddOn::Search->newSearch();
    my $docs = $search->docsForQuery( "startpoint");
    my $hit  = $docs->fetch_hit_hashref;
    $this->assert(defined($hit), "Hit for startpoint not found.");

    # Now I remove some of the topics
    my @topicsList = ( "TopicWithoutAttachment" );

    $ind->removeTopics($this->{users_web}, @topicsList);
    
    # Now the topic should not be found any more.
    $docs = $search->docsForQuery( "startpoint");
    $hit  = $docs->fetch_hit_hashref;
    $this->assert(!defined($hit), "Hit for startpoint found. Should be removed");
    
}

sub test_addTopics {
    my $this = shift;
    my $ind = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index->newCreateIndex();

    # First I create the index
    $ind->createIndex();

    my $search = TWiki::Contrib::SearchEngineKinoSearchAddOn::Search->newSearch();
    my $docs = $search->docsForQuery( "creatededpoint");
    my $hit  = $docs->fetch_hit_hashref;
    $this->assert(!defined($hit), "Hit for updatepoint found. Should be undefined!");

    # Now I create the topic
    $this->{twiki}->{store}->saveTopic($this->{twiki}->{user},$this->{users_web}, "NewTopic", <<'HERE');
Just an example topic
Keyword: creatededpoint
HERE

    # Now I add the topic to the index. 
    my @topicsList = ( "NewTopic" );
    $ind->addTopics($this->{users_web}, @topicsList);
    
    # Let's check
    $docs = $search->docsForQuery( "creatededpoint");
    $hit  = $docs->fetch_hit_hashref;
    $this->assert(defined($hit), "Hit for creatededpoint not found.");
    my $topic = $hit->{topic};
    $topic =~ s/ .*//;
    $this->assert_str_equals($topic, "NewTopic", "Wrong topic for update topic.");
}

sub test_websToIndex {
    my $this = shift;
    my $ind = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index->newCreateIndex();

    my @webs = $ind->websToIndex();
    $this->assert(@webs, "No webs given.");
    $this->assert(grep(/$this->{users_web}/,@webs), "User web not included.");
}

sub test_formsFieldNames {
    my $this = shift;
    my $ind = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index->newCreateIndex();

    my %fieldNames = $ind->formsFieldNames();
    $this->assert(%fieldNames, "No field names given.");
}

sub test_fieldNamesFileName {
    my $this = shift;
    my $ind = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index->newCreateIndex();

    my $fileName = $ind->fieldNamesFileName();
    
    $this->assert_str_equals($ind->indexPath()."/.formFieldNames", $fileName, "Bad file name");
}

sub test_writeFieldNames {
    my $this = shift;
    my $ind = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index->newCreateIndex();

    $ind->writeFieldNames();
}

sub test_readFieldNames {
    my $this = shift;
    my $ind = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index->newCreateIndex();

    # I fist write a file, to ensure that it exists
    $ind->writeFieldNames();

    my %fieldNames = $ind->readFieldNames();
    $this->assert(%fieldNames, "No field names returned.");
}

sub test_indexTopic {
    my $this = shift;
    my $ind = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index->newCreateIndex();

    # I check the succuessful created index by doing some searches.
    my $search = TWiki::Contrib::SearchEngineKinoSearchAddOn::Search->newSearch();

    # First I create the index of the current situation.
    $ind->createIndex();

    # Now I create a topic with all elements.
    $this->{twiki}->{store}->saveTopic($this->{twiki}->{user},$this->{users_web}, "TopicWithExcelAttachment", <<'HERE');
Just an example topic with MS Excel
Keyword: spreadsheet
HERE
    $this->{twiki}->{store}->saveAttachment($this->{users_web}, "TopicWithExcelAttachment", "Simple_example.xls",
                                            $this->{twiki}->{user}, {file => $this->{attachmentDir}."Simple_example.xls"});
    # FIXME: How can I add a Form?

    # Let's index the topic
    # Preparations
    my %fldNames = $ind->formsFieldNames();
    my $analyzer = $ind->analyser( $ind->analyserLanguage() );
    my $indexer  = $ind->indexer($analyzer, 1, %fldNames);
    # Indexing
    $ind->indexTopic($indexer, $this->{users_web}, "TopicWithExcelAttachment", %fldNames);
    # And finish
    $indexer->finish;

    # Seach for the topic title.
    my $docs = $search->docsForQuery( "Excel");
    my $hit  = $docs->fetch_hit_hashref;
    $this->assert(defined($hit), "No hit found for Excel.");
    my $topic = $hit->{topic};
    $topic =~ s/ .*//;
    $this->assert_str_equals($topic, "TopicWithExcelAttachment", "Wrong topic for tile.");

    # Seach for the topic body
    $docs = $search->docsForQuery( "spreadsheet");
    $hit  = $docs->fetch_hit_hashref;
    $this->assert(defined($hit), "No hit found for spreadsheet.");
    $topic = $hit->{topic};
    $topic =~ s/ .*//;
    $this->assert_str_equals($topic, "TopicWithExcelAttachment", "Wrong topic for body.");

    # Search for string in Excel: "calculator"
    $docs = $search->docsForQuery( "calculator");
    $hit  = $docs->fetch_hit_hashref;
    $this->assert(defined($hit), "No hit found for calculator.");
    $topic = $hit->{topic};
    $topic =~ s/ .*//;
    $this->assert_str_equals($topic, "TopicWithExcelAttachment", "Wrong topic for attachment.");
    # FIXME: How about form name and form fields?
}

sub test_indexAttachment {
    my $this = shift;
    my $ind = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index->newCreateIndex();

    # I check the succuessful created index by doing some searches.
    my $search = TWiki::Contrib::SearchEngineKinoSearchAddOn::Search->newSearch();

    # First I create the index of the current situation.
    $ind->createIndex();

    # Now I create a topic with an attachment.
    $this->{twiki}->{store}->saveTopic($this->{twiki}->{user},$this->{users_web}, "TopicWithPdfAttachment", <<'HERE');
Just an example topic with PDF
Keyword: spreadsheet
HERE
    $this->{twiki}->{store}->saveAttachment($this->{users_web}, "TopicWithPdfAttachment", "Simple_example.pdf",
                                            $this->{twiki}->{user}, {file => $this->{attachmentDir}."Simple_example.pdf"});

    # Let's index the atachment
    # Preparations
    my %fldNames = $ind->formsFieldNames();
    my $analyzer = $ind->analyser( $ind->analyserLanguage() );
    my $indexer  = $ind->indexer($analyzer, 1, %fldNames);
    # Indexing
    my @allAttachments = $ind->attachmentsOfTopic($this->{users_web}, "TopicWithPdfAttachment");
    my $attachment = $allAttachments[0];
    $ind->indexAttachment($indexer, $this->{users_web}, "TopicWithPdfAttachment", $attachment);
    # And finish
    $indexer->finish;

    # Let's search for that attachment and check all values.
    my $docs = $search->docsForQuery( "Adobe");
    my $hit  = $docs->fetch_hit_hashref;
    $this->assert(defined($hit), "No hit found for Adobe.");
    my $topic = $hit->{topic};
    $topic =~ s/ .*//;
    $this->assert_str_equals($topic, "TopicWithPdfAttachment", "Wrong topic for tile.");
    $this->assert_str_equals($this->{users_web}."TopicWithPdfAttachment".$attachment->{'name'}, 
			     $hit->{'id_topic'},   "ID topic not O.K.");
    $this->assert_str_equals($hit->{'name'},       $attachment->{'name'}, "Name not O.K.");
    $this->assert_str_equals($hit->{'author'},     $attachment->{'user'}, "User not O.K.");
    $this->assert_str_equals($hit->{'version'},    $attachment->{'version'}, "Version not O.K.");
    $this->assert_str_equals($hit->{'attachment'}, "yes", "Attachment not set to yes.");
    $this->assert_str_equals($hit->{'type'},       "pdf", "Type not O.K.");   
}

sub test_updateMarkerFile {
    my $this = shift;
    my $ind = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index->newCreateIndex();

    my $file = $ind->updateMarkerFile('Main');
    my $expected_file = $TWiki::cfg{DataDir}."/Main/.kinoupdate";
    $this->assert_str_equals($expected_file, $file, "File not O.K.")
}

sub test_saveUpdateMarker{
    my $this = shift;
    my $ind = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index->newCreateIndex();
    my $start_time = time();
    $ind->saveUpdateMarker($this->{users_web}, $start_time);

    my $red_time = $ind->readUpdateMarker($this->{users_web});
    $this->assert_str_equals($start_time, $red_time, "Red time does not fit saved time.");
}

sub test_readChanges {
    my $this = shift;
    my $ind = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index->newCreateIndex();

    $this->{twiki}->{store}->saveTopic($this->{twiki}->{user},$this->{users_web}, "NewOrChangedTopic", <<'HERE');
Just an example topic
Keyword: startpoint
HERE
    $this->{twiki}->{store}->saveTopic($this->{twiki}->{user},$this->{users_web}, "NewOrChangedTopic", <<'HERE');
Just an example topic: Updated
Keyword: startpoint
HERE

    my @changes = $ind->readChanges($this->{users_web});
    my $change;

    $this->assert(@changes, "Changes not returned.");

    # The first change should be the one I just did. 
    foreach $change (reverse @changes ){
	my ($topicName, $userName, $changeTime, $revision) = split( /\t/, $change);
	$this->assert_str_equals($topicName, "NewOrChangedTopic", "Last change not detected.");
	last;
    }
}

sub test_tripFirstchar {
    my $this = shift;

    my $result = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index::tripFirstchar("TTTTheTopic");
    $this->assert_str_equals($result, "TheTopic");

    $result = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index::tripFirstchar("Überschrift");
    $this->assert_str_equals($result, "Überschrift");

    $result = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index::tripFirstchar("Ècole");
    $this->assert_str_equals($result, "Ècole");
}

sub test_splitTheTopicName {
    my $this = shift;

    my $result = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index::splitTheTopicName("TheTopic--NNNName");
    $this->assert_str_equals("The Topic Name ", $result);

    $result = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index::splitTheTopicName("Ècole_ÜTheTopic--NNNName");
    $this->assert_str_equals("Ècole ÜThe Topic Name ", $result);
}

sub test_splitTopicName {
    my $this = shift;

    my $result = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index::splitTopicName("TheTopicName   IsKnown");
    $this->assert_str_equals("The Topic Name   Is Known", $result);

    $result = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index::splitTopicName("GroßeÄnderungsÜbergänge");
    $this->assert_str_equals("Große Änderungs Übergänge", $result);
}

###############################################################################
# 
# Test for Umlaute
# 

sub test_UmlauteInDoc {
    my $this = shift;

    $this->_testForWordInAttachment("Simple_example.doc", "Größer");
}

sub test_UmlauteInXLS {
    my $this = shift;

    $this->_testForWordInAttachment("Simple_example.xls", "Übergroß");
    $this->_testForWordInAttachment("Portuguese_example.xls", "Formatação");
}

sub test_UmlauteInHTML {
    my $this = shift;

    $this->_testForWordInAttachment("Simple_example.html", "geöffnet");
}

sub test_UmlauteInTXT {
    my $this = shift;

    $this->_testForWordInAttachment("Simple_example.txt", "Änderung");
}

sub test_UmlauteInPPT {
    my $this = shift;

    $this->_testForWordInAttachment("Simple_example.ppt", "Übergang");
}

sub test_UmlauteInPDF {
    my $this = shift;

    $this->_testForWordInAttachment("Simple_example.pdf", "Überflieger");
    $this->_testForWordInAttachment("Simple_example.pdf", "Äußerung");
}

sub _testForWordInAttachment {
    my ($this, $file, $word) = (@_);

    my $ind = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index->newCreateIndex();

    $this->{twiki}->{store}->saveTopic($this->{twiki}->{user},$this->{users_web}, "TopicWithSpecialFile", <<'HERE');
Just an example topic.
Keyword: Superspecific
HERE
    $this->{twiki}->{store}->saveAttachment($this->{users_web}, "TopicWithSpecialFile", $file,
                                            $this->{twiki}->{user}, {file => $this->{attachmentDir}.$file});

    TWiki::Func::setPreferencesValue( "KINOSEARCHINDEXSKIPWEBS", "Main, Sandbox, TWiki, TestCases, Trash");
    $ind->createIndex();

    my $search = TWiki::Contrib::SearchEngineKinoSearchAddOn::Search->newSearch();

    # Now search for the word
    my $docs = $search->docsForQuery( $word );
    my $hit  = $docs->fetch_hit_hashref;
    $this->assert(defined($hit), "Hit for $word in file $file not found.");
    my $topic = $hit->{topic};
    $topic =~ s/ .*//;
    $this->assert_str_equals($topic, "TopicWithSpecialFile", "Wrong topic for $word: Is = $topic but should be TopicWithSpecialFile");
}

sub _createTopicWithoutAttachment {
    my $this = shift;

    $this->{twiki}->{store}->saveTopic($this->{twiki}->{user},$this->{users_web}, "TopicWithoutAttachment", <<'HERE');
Just an example topic
Keyword: startpoint
HERE
}

sub _createTopicWithWordAttachment {
    my $this = shift;

    $this->{twiki}->{store}->saveTopic($this->{twiki}->{user},$this->{users_web}, "TopicWithWordAttachment", <<'HERE');
Just an example topic with MS Word
Keyword: redmond
HERE

    $this->{twiki}->{store}->saveAttachment($this->{users_web}, "TopicWithWordAttachment", "Simple_example.doc",
                                            $this->{twiki}->{user}, {file => $this->{attachmentDir}."Simple_example.doc"})
}

sub _indexOK {
    my $this = shift;
    # I check, that the index is created correctly.
    # I check the succuessful created index by doing some searches.
    my $search = TWiki::Contrib::SearchEngineKinoSearchAddOn::Search->newSearch();

    # Now I search for something.
    my $docs = $search->docsForQuery( "startpoint");
    my $hit  = $docs->fetch_hit_hashref;
    $this->assert(defined($hit), "Hit for startpoint not found.");
    my $topic = $hit->{topic};
    $topic =~ s/ .*//;
    $this->assert_str_equals($topic, "TopicWithoutAttachment", "Wrong topic for startpoint.");

    # Lets seach for the MS Word attachment
    $docs = $search->docsForQuery( "dummy");
    $hit  = $docs->fetch_hit_hashref;
    $this->assert(defined($hit), "Hit for MS Word not found.");
    $topic = $hit->{topic};
    $topic =~ s/ .*//;
    $this->assert_str_equals($topic, "TopicWithWordAttachment", "Wrong topic for MS word.");
}

1;
