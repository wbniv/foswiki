package TWiki::Plugins::SearchEngineKinoSearchPlugin;


# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $debug
        $webName $topicName $enableOnSaveUpdates
    );

$VERSION = '$Rev: 8749 $';
$RELEASE = '0.5';
$SHORTDESCRIPTION = 'Kino Search Plugin (mmm not sure if this will work)';
$NO_PREFS_IN_TOPIC = 1;
$pluginName = 'SearchEngineKinoSearchPlugin';

sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    if( $TWiki::Plugins::VERSION < 1.026  ) {
        &TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    $debug = $TWiki::cfg{Plugins}{SearchEngineKinoSearchPlugin}{Debug} || 0;
    $enableOnSaveUpdates = $TWiki::cfg{Plugins}{SearchEngineKinoSearchPlugin}{EnableOnSaveUpdates} || 0;

    TWiki::Func::registerTagHandler('KINOSEARCH', \&_KINOSEARCH);

    TWiki::Func::registerRESTHandler('search', \&_search);
    TWiki::Func::registerRESTHandler('index', \&_index);
    TWiki::Func::registerRESTHandler('update', \&_update);

    return 1;
}

sub _search {
    my $session = shift;
    
    require TWiki::Contrib::SearchEngineKinoSearchAddOn::Search;
    my $searcher = TWiki::Contrib::SearchEngineKinoSearchAddOn::Search->newSearch();
    return $searcher->search($debug, $session);
}
sub _index {
    my $session = shift;

    require TWiki::Contrib::SearchEngineKinoSearchAddOn::Index;
    my $indexer = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index->newCreateIndex();
    return $indexer->createIndex($debug, 1);
}
sub _update {
    my $session = shift;
    
    require TWiki::Contrib::SearchEngineKinoSearchAddOn::Index;
    my $indexer = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index->newUpdateIndex();
    return $indexer->updateIndex($debug);
}

sub _KINOSEARCH {
    my($session, $params, $theTopic, $theWeb) = @_;

    my $ret = "";
    my $format = $params->{format}||"\$icon <b>\$match</b> <span class='twikiAlert'>\$locked</span> <br />\$texthead<br /><hr />";
    $format =~ s/\$icon/%ICON%/go;
    $format =~ s/\$match/%MATCH%/go;
    $format =~ s/\$locked/%LOCKED%/go;
    $format =~ s/\$texthead/%TEXTHEAD%/go;

    require TWiki::Contrib::SearchEngineKinoSearchAddOn::Search;
    my $docs = TWiki::Contrib::SearchEngineKinoSearchAddOn::Search->docsForQuery($params->{_DEFAULT});

    while( my $hit = $docs->fetch_hit_hashref ) {
        my $resweb   = $hit->{web};
        my $restopic = $hit->{topic};

        # For partial name search of topics, just hold the first part of the string
        if($restopic =~ m/(\w+)/) { $restopic =~ s/ .*//; }

        # topics moved away maybe are still indexed on old web
        next unless &TWiki::Func::topicExists( $resweb, $restopic );

        my $wikiusername = TWiki::Func::getWikiName();
        if( ! TWiki::Func::checkAccessPermission('VIEW', $wikiusername, undef, $restopic, $resweb, undef) ) {
            next;
        }

        $ret .= TWiki::Contrib::SearchEngineKinoSearchAddOn::Search->renderHtmlStringFor($hit,$format,0,0);
    }

    return "$ret";
}

sub afterSaveHandler {
    return if ($enableOnSaveUpdates != 1);  #disabled - they can make save's take too long
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web, $error, $meta ) = @_;
    my $web = $_[2];
    my $topic = $_[1];

    require TWiki::Contrib::SearchEngineKinoSearchAddOn::Index;
    my $indexer = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index->newUpdateIndex();
    my @topicsToUpdate = ($topic);
    $indexer->removeTopics($web, @topicsToUpdate);
    $indexer->addTopics($web, @topicsToUpdate);
}

sub afterRenameHandler {
    return if ($enableOnSaveUpdates != 1);  #disabled - they can make save's take too long
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $oldWeb, $oldTopic, $oldAttachment, $newWeb, $newTopic, $newAttachment ) = @_;
    my $oldweb = $_[0];
    my $oldtopic = $_[1];
    my $newweb = $_[3];
    my $newtopic = $_[4];

    require TWiki::Contrib::SearchEngineKinoSearchAddOn::Index;
    my $indexer = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index->newUpdateIndex();
    my @topicsToUpdate = ($oldtopic);
    $indexer->removeTopics($oldweb, @topicsToUpdate);
    @topicsToUpdate = ($newtopic);
    $indexer->addTopics($newtopic, @topicsToUpdate);
}

sub afterAttachmentSaveHandler {
    return if ($enableOnSaveUpdates != 1);  #disabled - they can make save's take too long
    # do not uncomment, use $_[0], $_[1]... instead
    ###   my( $attrHashRef, $topic, $web ) = @_;
    my $web = $_[2];
    my $topic = $_[1];
    
    require TWiki::Contrib::SearchEngineKinoSearchAddOn::Index;
    my $indexer = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index->newUpdateIndex();
    my @topicsToUpdate = ($topic);
    $indexer->removeTopics($web, @topicsToUpdate);
    $indexer->addTopics($web, @topicsToUpdate);
}

1;
