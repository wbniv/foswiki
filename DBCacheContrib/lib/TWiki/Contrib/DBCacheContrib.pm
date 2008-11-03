#
# Copyright (C) Motorola 2003 - All rights reserved
# Copyright (C) Crawford Currie 2004 - All rights reserved
#
package TWiki::Contrib::DBCacheContrib;
use base 'TWiki::Contrib::DBCacheContrib::Map';

use strict;

use TWiki::Contrib::DBCacheContrib::Array;
use TWiki::Contrib::DBCacheContrib::FileTime;
use TWiki::Attrs;
use Assert;

#use Monitor;
#Monitor::MonitorMethod('TWiki::Contrib::DBCacheContrib');
#Monitor::MonitorMethod('TWiki::Contrib::DBCacheContrib::Search');
#Monitor::MonitorMethod('TWiki::Contrib::DBCacheContrib::Archive');

=pod

---++ class DBCacheContrib

General purpose cache that treats TWiki topics as hashes. Useful for
rapid read and search of the database. Only works on one web.

Typical usage:
<verbatim>
  use TWiki::Contrib::DBCacheContrib;

  $db = new TWiki::Contrib::DBCacheContrib( $web ); # always done
  $db->load(); # may be always done, or only on demand when a tag is parsed that needs it

  # the DB is a hash of topics keyed on their name
  foreach my $topic ($db->getKeys()) {
     my $attachments = $db->get($topic)->get("attachments");
     # attachments is an array
     foreach my $val ($attachments->getValues()) {
       my $aname = $attachments->get("name");
       my $acomment = $attachments->get("comment");
       my $adate = $attachments->get("date");
       ...
     }
  }
</verbatim>
As topics are loaded, the readTopicLine method gives subclasses an opportunity to apply special processing to indivual lines, for example to extract special syntax such as %ACTION lines, or embedded tables in the text. See FormQueryPlugin for an example of this.

=cut

use vars qw( $initialised $storable $VERSION $RELEASE );

$initialised = 0; # Not initialised until the first new

$VERSION = '$Rev: 16742 $';
$RELEASE = 'TWiki-4';

=pod

---+++ =new($web, $cacheName)=
   * =$web= name of web to create the object for.
   * =$cacheName= name of cache file (default "_DBCache")

Construct a new DBCache object.

=cut

sub new {
    my ( $class, $web, $cacheName ) = @_;
    $cacheName ||= '_DBCache';
    my $this = bless( $class->SUPER::new(), $class );
    $this->{_web} = $web;
    $this->{loaded} = 0;
    $this->{_cachename} = $cacheName;

    # Backward compatibility
    unless( $TWiki::cfg{DBCacheContrib}{Archivist} ) {
        eval 'use Storable';
        if ($@) {
            # Storable not available
            $TWiki::cfg{DBCacheContrib}{Archivist} =
              'TWiki::Contrib::DBCacheContrib::Archivist::File';
        } else {
            $TWiki::cfg{DBCacheContrib}{Archivist} =
              'TWiki::Contrib::DBCacheContrib::Archivist::Storable';
        }
    }

    eval "use $TWiki::cfg{DBCacheContrib}{Archivist}";
    die $@ if ( $@ );

    return $this;
}

# PRIVATE load a single topic from the given data directory. This
# ought to be replaced by TWiki::Func::readTopic -> {$meta, $text) but
# this implementation is more efficient for just now.
# returns 1 if the topic was loaded successfully, 0 otherwise
sub _loadTopic {
    my ( $this, $dataDir, $topic ) = @_;
    my $filename = "$dataDir/$topic.txt";
    my $fh;

    #print STDERR "DBCacheContrib::_loadTopic($filename)\n";

    unless (open( $fh, "<$filename" )) {
        print STDERR "WARNING: Failed to open $filename\n";
        return 0;
    }

    my $meta = new TWiki::Contrib::DBCacheContrib::Map();
    $meta->set( 'name', $topic );
    $meta->set( 'topic', $topic );
    $meta->set( '.cache_time',
                new TWiki::Contrib::DBCacheContrib::FileTime( $filename ));

    my $line;
    my $text = '';
    my $all = '';
    my $form;
    my $tailMeta = 0;
    local $/ = "\n";
    while ( $line = <$fh> ) {
	$all .= $line;
        if ( $line =~ m/^%META:FORM{name=\"([^\"]*)\"}%/o ) {
            $form = new TWiki::Contrib::DBCacheContrib::Map() unless $form;
            my( $web, $topic ) = TWiki::Func::normalizeWebTopicName('', $1);
            $form->set( 'name', $web.'.'.$topic );
            $form->set( '_up', $meta );
            $form->set( '_web', $this );
            $meta->set( 'form', $topic );
            $meta->set( $topic, $form );
            $tailMeta = 1;
        } elsif ( $line =~ m/^%META:TOPICPARENT{name=\"([^\"]*)\"}%/o ) {
            $meta->set( 'parent', $1 );
            $tailMeta = 1;
        } elsif ( $line =~ m/^%META:TOPICINFO{(.*)}%/o ) {
            my $att = new TWiki::Contrib::DBCacheContrib::Map($1);
            $att->set( '_up', $meta );
            $att->set( '_web', $this );
            $meta->set( 'info', $att );
        } elsif ( $line =~ m/^%META:TOPICMOVED{(.*)}%/o ) {
            my $att = new TWiki::Contrib::DBCacheContrib::Map($1);
            $att->set( '_up', $meta );
            $att->set( '_web', $this );
            $meta->set( 'moved', $att );
            $tailMeta = 1;
        } elsif ( $line =~ m/^%META:FIELD{(.*)}%/o ) {
            my $fs = new TWiki::Attrs($1);
            $form = new TWiki::Contrib::DBCacheContrib::Map() unless $form;
            $form->set( '_web', $this );
            $form->set( $fs->get('name'), $fs->get('value'));
            $tailMeta = 1;
        } elsif ( $line =~ m/^%META:FILEATTACHMENT{(.*)}%/o ) {
            my $att = new TWiki::Contrib::DBCacheContrib::Map($1);
            $att->set( '_up', $meta );
            $att->set( '_web', $this );
            my $atts = $meta->get( 'attachments' );
            if ( !defined( $atts )) {
                $atts = new TWiki::Contrib::DBCacheContrib::Array();
                $meta->set( 'attachments', $atts );
            }
            $atts->add( $att );
            $tailMeta = 1;
        } elsif ( $line =~ m/^%META:PREFERENCE{(.*)}%/o ) {
            my $pref = new TWiki::Contrib::DBCacheContrib::Map($1);
            $pref->set( '_up', $meta);
            $pref->set( '_web', $this);
            my $prefs = $meta->get('preferences');
            if (!defined($prefs)) {
                $prefs = new TWiki::Contrib::DBCacheContrib::Array();
                $meta->set('preferences', $prefs);
            }
            $prefs->add($pref);
            $tailMeta = 1;
        } else {
            if ($this->can('readTopicLine')) {
                $line = $this->readTopicLine( $topic, $meta, $line, $fh );
	    }
	    $text .= $line if $line && $line !~ /%META:[A-Z].*?}%/o;
        }
    }
    close( $fh );
    $text =~ s/\n$//s if $tailMeta;
    $meta->set( 'text', $text );
    $meta->set( 'all', $all);
    $this->set( $topic, $meta );

    return $meta;
}

=pod

---+++ readTopicLine($topic, $meta, $line, $fh) --> text
   * $topic - name of the topic being read
   * $meta - reference to the hash object for this topic
   * line - the line being read
   * $fh - the file handle of the file
   * __return__ text to insert in place of _line_ in the text field of the topic
Called when reading a topic that is being cached, this method is invoked on each line
in the topic. It is designed to be overridden by subclasses; the default implementation
does nothing. The sort of expected activities will be (for example) reading tables and
adding them to the hash for the topic.

=cut

#sub readTopicLine {
#    #my ( $this, $topic, $meta, $line, $fh ) = @_;
#    return $_[3];
#}

=pod

---+++ onReload($topics)
   * =$topics= - perl array of topic names that have just been loaded (or reloaded)
Designed to be overridden by subclasses. Called when one or more topics had to be
read from disc rather than from the cache. Passed a list of topic names that have been read.

=cut

sub onReload {
    #my ( $this, @$topics) = @_;
}

sub _onReload {
    my $this = shift;

    foreach my $topic ( $this->getValues() ) {
        # Fill in parent relations
        unless ($topic->fastget('parent')) {
          $topic->set('parent', $TWiki::cfg{HomeTopicName});
          # last parent is WebHome
        }
        unless ( $topic->fastget( '_up' )) {
            my $parent = $topic->fastget( 'parent' );
            $parent = $this->fastget( $parent ) if $parent;

            # prevent the _up to be undefined in case of
            # a parent info to a non-existing topic;
            # the parent chain ends at the web hash
            if ($parent) {
              $topic->set( '_up', $parent );
            } else {
              $topic->set( '_up', $this ); 
            }
        }

        # set pointer to web
        $topic->set( '_web', $this );
        $topic->set( 'web', $this->{_web} );
    }


    $this->onReload(@_);
}

=pod

---+++ load( [updateCache]  ) -> ($readFromCache, $readFromFile, $removed)

Load the web into the database.
Returns a list containing 3 numbers that give the number of topics
read from the cache, the number read from file, and the number of previously
cached topics that have been removed.

if  $TWiki::cfg{DBCache}{AlwaysUpdateCache}  is set to FALSE (defaults to TRUE for compatibility)
then avoid calling _updateCache unless requested. DBCachePlugin now only asked for it from
the afterSaveHandler and from the new REST updateCache handler

=cut

sub load {
    my $this = shift;
    my $updateCache = shift || $TWiki::cfg{DBCache}{AlwaysUpdateCache};
    $updateCache = 1 unless (defined($updateCache));
    #print STDERR "called load($updateCache)\n";

    return (0, 0, 0) if ( $this->{loaded} );

    my $web = $this->{_web};
    $web =~ s/\./\//g;
    my $dataDir = TWiki::Func::getDataDir()."/$web";
    $web =~ s/\//\./g;
    my $workDir = TWiki::Func::getWorkArea('DBCacheContrib');
    my $cacheFile = "$workDir/$web.$this->{_cachename}";

    my $time;

    my $writeCache = 0;

    my $cache;

    eval {
        $cache = $TWiki::cfg{DBCacheContrib}{Archivist}->retrieve(
            $cacheFile );
    };

    my $readFromCache = 0;
    my $readFromFile = 0;
    my $removed = 0;

    if ( $cache && $updateCache ) {
        eval {
            ( $readFromCache, $readFromFile, $removed ) =
              $this->_updateCache( $cache, $dataDir );
        };

        if ( $@ ) {
            TWiki::Func::writeWarning("DBCache: Cache read failed: $@");
            $cache = undef;
        }

        if ( $readFromFile || $removed ) {
            $writeCache = 1;
        }
    } elsif ( $cache ) {
        $this->{keys} = $cache->{keys};        
        $readFromCache = $cache->size();
    }

    if ( !$cache ) {
        my @readTopic;
        opendir(D, $dataDir) || return (0, 0, 0);
        foreach my $topic ( readdir(D) ) {
            next unless $topic =~ s/\.txt$//;
            if ($this->_loadTopic( $dataDir, $topic )) {
              $readFromFile++;
              push( @readTopic, $topic );
            }
        }
        closedir(D);
        $this->_onReload( \@readTopic );
        $writeCache = 1;
    }

    if ( $writeCache ) {
        $TWiki::cfg{DBCacheContrib}{Archivist}->store( $this, $cacheFile );
    }

    $this->{loaded} = 1;

    #print STDERR "DBCacheContrib::load read $readFromFile files,  $readFromCache topics read from cache , $removed topics removed from cache\n";
    return ($readFromCache, $readFromFile, $removed);
}

# PRIVATE update the cache from files
# return the number of files changed in a tuple
sub _updateCache {
    my ( $this, $cache, $dataDir ) = @_;

    my $readFromCache = $cache->size();
    foreach my $cached ( $cache->getValues()) {
        $cached->set( '.fresh', 0 );
    }

    my $readFromFile = 0;
    my @readTopic;

    # load topics that are missing from the cache
    opendir(D, $dataDir) || return (0, 0, 0);
    foreach my $topic ( readdir(D) ) {
        next unless $topic =~ s/\.txt$//;
        my $topcache = $cache->fastget( $topic );
        if ($topcache && !$topcache->fastget( '.cache_time' )->uptodate()) {
            $cache->remove( $topic );
            $readFromCache--;
            $topcache = undef;
        }
        if ( !$topcache ) {
            # Not in cache
            $topcache = $cache->_loadTopic( $dataDir, $topic );
            if ($topcache) {
                $readFromFile++;
                push( @readTopic, $topic );
            }
        }
        $topcache->set( '.fresh', 1 ) if $topcache;

        #don't disadvantage users just because the cache is off
	last if defined($TWiki::cfg{DBCache}{LoadFileLimit}) && 
            ( $TWiki::cfg{DBCache}{LoadFileLimit} > 0 ) && 
            ( $readFromFile > $TWiki::cfg{DBCache}{LoadFileLimit} ); 
    }
    closedir(D);

    # Find smelly topics in the cache
    my $removed = 0;
    foreach my $cached ( $cache->getValues()) {
        if( $cached->fastget( '.fresh' )) {
            $cached->remove( '.fresh' );
        } else {
            $cache->remove( $cached->fastget( 'name' ) );
            $readFromCache--;
            $removed++;
        }
    }

    $this->{keys} = $cache->{keys};

    if ( $readFromFile || $removed ) {
        # refresh relations
        $this->_onReload( \@readTopic );
    }

    return ( $readFromCache, $readFromFile, $removed );
}

1;
