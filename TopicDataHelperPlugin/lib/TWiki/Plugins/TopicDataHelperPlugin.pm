# Plugin for TWiki Collaboration Platform, http://TWiki.org/
# Copyright (C) 2008 Arthur Clemens, arthur@visiblearea.com
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

package TWiki::Plugins::TopicDataHelperPlugin;

use strict;
use TWiki::Func;

use vars qw($VERSION $RELEASE $pluginName $debug
);

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = '1.0';

$pluginName = 'TopicDataHelperPlugin';
our %sortDirections = ( 'ASCENDING', 1, 'NONE', 0, 'DESCENDING', -1 );

sub initPlugin {
    my ( $inTopic, $inWeb, $inUser, $inInstallWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPluginPreferencesFlag("DEBUG");

    # Plugin correctly initialized
    TWiki::Func::writeDebug(
        "- TWiki::Plugins::${pluginName}::initPlugin( $inWeb.$inTopic ) is OK")
      if $debug;

    return 1;
}

=pod

---+++ createTopicData( $webs, $excludewebs, $topics, $excludetopics ) -> \%hash

Creates a hash of web => topics, using this structure:

%topicData = (
	Web1 => {
		Topic1 => 1,
		Topic2 => 1,
		...
	}
	Web2 => {
		Topic1 => 1,
		Topic2 => 1,
		...
	}
)

The value '1' is temporary to define which topic are valid, and will be replaced by a data structure later on.

Use one paramater or all.
When no =inWebs= is passed, the current web is assumed.
When no =inTopics= is passed, the current topic is assumed.

Function parameters:
	* =$inWebs (string) - webs to include: either a web name, a comma-separated list of web names, or '*' for all webs the current user may see
	* =$inExcludeWebs= (string) - webs to exclude: either a web name, a comma-separated list of web names
	* =$inTopics= (string) - topics to include: either a topic name, a comma-separated list of topic names, or '*' for all topics
	* =$inExcludeTopics= (string) - topics to exclude: either a topic name, a comma-separated list of topic names

Returns a reference to a hash of webs->topics.
	
=cut

sub createTopicData {
    my ( $inWebs, $inExcludeWebs, $inTopics, $inExcludeTopics ) = @_;

    my %topicData = ();

    my $excludeTopics = makeHashFromString( $inExcludeTopics, 1 );
    my $excludeWebs   = makeHashFromString( $inExcludeWebs,   1 );

    my @topicsInWeb = ();
    my @webs =
      ( $inWebs eq '*' )
      ? TWiki::Func::getListOfWebs('allowed')
      : split( qr/[\s,]+/, $inWebs );
    foreach my $web (@webs) {
        next if $web =~ qr/^_.*?$/;    # do not list webs with underscore
        next if $topicData{$web};           # already done
        next if ( $$excludeWebs{$web} );    # skip if web is to be excluded

        # get this web's topics
        my @webTopics =
          ( $inTopics eq '*' )
          ? TWiki::Func::getTopicList($web)
          : split( qr/[\s,]+/, $inTopics );

        # prefix with web name
        foreach my $topic (@webTopics) {
            next
              if ( $$excludeTopics{$topic} );  # skip if topic is to be excluded
            next
              if ( $$excludeTopics{"$web.$topic"} )
              ;    # skip if web.topic is to be excluded
            $topicData{$web}{$topic} = 1;
        }

        # if ($debug) {
        #     use Data::Dumper;
        #     TWiki::Func::writeDebug("just added in web $web:");
        #     TWiki::Func::writeDebug( Dumper( $topicData{$web} ) );
        # }
    }
    return \%topicData;
}

=pod

---+++ insertObjectData( $topicData, $createObjectDataFunc, $properties )

Populates the topic data hash with custom data objects like this:

%topicData = (
	Web1 => {
		Topic1 => your data,
	}
)

The data object creation is done in your plugin in the function passed by $inCreateObjectDataFunc.

For example, AttachmentListPlugin creates this structure:

%topicData = (
	Web1 => {
		Topic1 => {
			picture.jpg => FileData object 1,
			me.PNG => FileData object 2,		
			...
		},
	},
)

... using this data creation function:

sub _createFileData {
    my ( $inTopicHash, $inWeb, $inTopic ) = @_;

    # define value for topic key only if topic
    # has META:FILEATTACHMENT data
    my $attachments = _getAttachmentsInTopic( $inWeb, $inTopic );

    if ( scalar @$attachments ) {
        $inTopicHash->{$inTopic} = ();

        foreach my $attachment (@$attachments) {
            my $fd =
              TWiki::Plugins::AttachmentListPlugin::FileData->new( $inWeb, $inTopic,
                $attachment );
            my $fileName = $fd->{name};
            $inTopicHash->{$inTopic}{$fileName} = \$fd;
        }
    }
    else {

        # no META:FILEATTACHMENT, so remove from hash
        delete $inTopicHash->{$inTopic};
    }
}

... and calls insertObjectData using:

TWiki::Plugins::TopicDataHelperPlugin::insertObjectData(
	$topicData, \&_createFileData
);

Function parameters:
   * =\%inTopicData= (hash reference) - topic data
   * =\$inCreateObjectDataFunc= (function reference) - function that will create a data object
   * =\%inProperties= (hash reference, optional) - properties to be passed to the function =$inCreateObjectDataFunc=
   
Returns nothing.

=cut

sub insertObjectData {
    my ( $inTopicData, $inCreateObjectDataFunc, $inProperties ) = @_;
    my %topicData = %$inTopicData;

    while ( ( my $web, my $topicHash ) = each %topicData ) {
        while ( ( my $topic ) = each %$topicHash ) {
            my $obj = $inCreateObjectDataFunc->(
                $topicHash, $web, $topic, $inProperties
            );
        }
    }
}

=pod

---+++ filterTopicDataByViewPermission( $topicData, $wikiUserName )

Filters topic data objects by checking if the user $inWikiUserName has view access permissions.

Removes topic data if the user does not have permission to view the topic.

Example:
my $user = TWiki::Func::getWikiName();
my $wikiUserName = TWiki::Func::userToWikiName( $user, 1 );
TWiki::Plugins::TopicDataHelperPlugin::filterTopicDataByViewPermission(
	\%topicData, $wikiUserName );
        
Function parameters:
   * =\%inTopicData= (hash reference) - topic data
   * =$inWikiUserName= (string) - name of user to check

Returns nothing.

=cut

sub filterTopicDataByViewPermission {
    my ( $inTopicData, $inWikiUserName ) = @_;

    my %topicData = %$inTopicData;

    # find object references in hash
    while ( ( my $web, my $topicHash ) = each %topicData ) {

        # {web} => hash of topics
        while ( ( my $topic ) = each %$topicHash ) {

            if (
                !TWiki::Func::checkAccessPermission(
                    'VIEW', $inWikiUserName, undef, $topic, $web
                )
              )
            {
                delete $inTopicData->{$web}{$topic};
            }
        }
    }
}

=pod

---+++ filterTopicDataByDateRange( $topicData, $fromDate, $toDate, $dateKey )

Filters topic data objects by date range, from $inFromDate to $inToDate.

Removes topic data if:
- the value of the object attribute $inDateKey is earlier than $inFromDate
- the value of the object attribute $inDateKey is later than $inToDate

Use either $inFromDate or inToDate, or both.

FormFieldListPlugin uses this function to show topics between =fromdate= and =todate= (for example: fromdate="2005/01/01" todate="2007/01/01").

From FormFieldListPlugin:
if ( defined $inParams->{'fromdate'} || defined $inParams->{'todate'} ) {
	TWiki::Plugins::TopicDataHelperPlugin::filterTopicDataByDateRange(
		\%topicData, $inParams->{'fromdate'},
		$inParams->{'todate'} );
}

Function parameters:
   * =\%inTopicData= (hash reference) - topic data
   * =$inFromDate= (int) - epoch seconds
   * =$inToDate= (int) - epoch seconds
   * =$inDateKey= (string, optional) - date key; if not defined: 'date'

Returns nothing.

=cut

sub filterTopicDataByDateRange {
    my ( $inTopicData, $inFromDate, $inToDate, $inDateKey ) = @_;

    my %topicData = %$inTopicData;

    my $fromEpoch =
      $inFromDate
      ? TWiki::Time::parseTime("$inFromDate 00.00.00")
      : 0;
    my $toEpoch =
      $inToDate
      ? TWiki::Time::parseTime("$inToDate 23.59.59")
      : 2**31;
    my $dateKey = $inDateKey || 'date';

    # find object references in hash
    while ( ( my $web, my $topicHash ) = each %topicData ) {

        # {web} => hash of topics
        while ( ( my $topic, my $objectDataHash ) = each %$topicHash ) {

            # {web}{topic} => values
            while ( ( my $key, my $object ) = each %$objectDataHash ) {

                my $epochDate = $$object->{$dateKey} || 0;
                if (   ( $epochDate > $fromEpoch )
                    && ( $epochDate < $toEpoch ) )
                {

                    # within range
                }
                else {
                    delete $inTopicData->{$web}{$topic}{$key};
                }
            }

            # Check if topic hash is empty. if so, remove topic hash altogether
            # CHECK: is this necessary? This must cost some performance...
            #my $ref = $inTopicData->{$web}{$topic};
            #if ( !keys %$ref ) {
            #    delete $inTopicData->{$web}{$topic};
            #}
        }
    }
}

=pod

---+++ filterTopicDataByProperty( $topicData, $propertyKey, $isCaseSensitive, $includeValues, $excludeValues )

Filters topic data objects by matching an object property with a list of possible values.

Removes topic data if:
- the object attribute $inPropertyKey is not in $inIncludeValues
- the object attribute $inPropertyKey is in $inExcludeValues

Use either $inIncludeValues or $inExcludeValues, or both.

For example, AttachmentListPlugin uses this function to filter attachments by extension.
=extension="gif, jpg"= will find all attachments with extension 'gif' OR 'jpg'. OR 'GIF' or 'JPG', therefore =$inIsCaseSensitive= is set to 0.

From AttachmentListPlugin:

my $extensions =
	 $inParams->{'extension'}
  || undef;
my $excludeExtensions = $inParams->{'excludeextension'} || undef;
if ( defined $extensions || defined $excludeExtensions ) {
	TWiki::Plugins::TopicDataHelperPlugin::filterTopicDataByProperty(
		\%topicData, 'extension', 0, $extensions, $excludeExtensions );
}

Function parameters:
   * =\%inTopicData= (hash reference) - topic data
   * =$inPropertyKey= (string) - key of object property
   * =$inIsCaseSensitive= (boolean int) - if 0, makes all hash values of =inIncludeValues= and =inExcludeValues= lowercase; for example, finding matches on file extension should not be case sensitive
   * =$inIncludeValues= (string) - comma-separated list of values that the object should have
   * =$inExcludeValues= (string) - comma-separated list of values that the object should not have

Returns nothing.

=cut

sub filterTopicDataByProperty {
    my (
        $inTopicData,     $inPropertyKey, $inIsCaseSensitive,
        $inIncludeValues, $inExcludeValues
    ) = @_;

    my %topicData = %$inTopicData;

    my $included = makeHashFromString( $inIncludeValues, $inIsCaseSensitive );
    my $excluded = makeHashFromString( $inExcludeValues, $inIsCaseSensitive );

    if ($debug) {
        TWiki::Func::writeDebug("filterTopicDataByProperty:");
        TWiki::Func::writeDebug("\t inPropertyKey=$inPropertyKey")
          if $inPropertyKey;
        TWiki::Func::writeDebug("\t inIncludeValues=$inIncludeValues")
          if $inIncludeValues;
        TWiki::Func::writeDebug("\t inExcludeValues=$inExcludeValues")
          if $inExcludeValues;
        TWiki::Func::writeDebug(
            "\t included hash keys = ("
              . scalar( keys %$included ) . ")"
              . join ",",
            keys %$included
        ) if %$included;
        TWiki::Func::writeDebug(
            "\t excluded hash keys = ("
              . scalar( keys %$excluded ) . ")"
              . join ",",
            keys %$excluded
        ) if %$excluded;
    }

    # find object references in hash
    while ( ( my $web, my $topicHash ) = each %topicData ) {

        # {web} => hash of topics
        while ( ( my $topic, my $objectDataHash ) = each %$topicHash ) {

            # {web}{topic} => object
            while ( ( my $key, my $object ) = each %$objectDataHash ) {
                my $isInValid = 0;
                $isInValid = 1
                  if ( keys %$included
                    && !$$included{ $$object->{$inPropertyKey} } );
                $isInValid = 1
                  if ( keys %$excluded
                    && $$excluded{ $$object->{$inPropertyKey} } );
                if ($debug) {
                    TWiki::Func::writeDebug("\t\t ---");
                    TWiki::Func::writeDebug("\t\t key=$key");
                    TWiki::Func::writeDebug("\t\t object=$object") if $object;
                    TWiki::Func::writeDebug(
                        "\t\t value=$$object->{$inPropertyKey}")
                      if $$object->{$inPropertyKey};
                    TWiki::Func::writeDebug(
                        "\t\t included=$$included{ $$object->{$inPropertyKey}}")
                      if $$included{ $$object->{$inPropertyKey} };
                    TWiki::Func::writeDebug(
                        "\t\t excluded=$$excluded{ $$object->{$inPropertyKey}}")
                      if $$excluded{ $$object->{$inPropertyKey} };
                    TWiki::Func::writeDebug("\t\t isInValid=$isInValid");
                }
                if ($isInValid) {
                    delete $inTopicData->{$web}{$topic}{$key};
                }
            }
        }
    }

 # use Data::Dumper;
 # TWiki::Func::writeDebug("After _filterTopicDataByIncludedAndExcludedFiles:");
 # TWiki::Func::writeDebug( Dumper( $inTopicData ) );
}

=pod

---+++ filterTopicDataByRegexMatch( $topicData, $propertyKey, $includeRegex, $excludeRegex )

Filters topic data objects by matching an object property with a regular expression.

Removes topic data if:
- the object attribute =$inPropertyKey= does not match =$inIncludeRegex=
- the object attribute =$inPropertyKey= matches =$inExcludeRegex=

Use either =$inIncludeRegex= or =$inExcludeRegex=, or both.

Function parameters:
   * =\%inTopicData= (hash reference) - topic data
   * =$inPropertyKey= (string) - key of object property that is matched with the regular expressions =inIncludeRegex= and =inExcludeValues=
   * =$inIncludeRegex= (string) - regular expression
   * =$inExcludeRegex= (string) - regular expression
   
Returns nothing.

=cut

sub filterTopicDataByRegexMatch {
    my ( $inTopicData, $inPropertyKey, $inIncludeRegex, $inExcludeRegex ) = @_;

    my %topicData = %$inTopicData;

    # find object references in hash
    while ( ( my $web, my $topicHash ) = each %topicData ) {

        # {web} => hash of topics
        while ( ( my $topic, my $objectDataHash ) = each %$topicHash ) {

            # {web}{topic} => object
            while ( ( my $key, my $object ) = each %$objectDataHash ) {
                my $isInValid = 0;

                $isInValid = 1
                  if ( defined $inIncludeRegex
                    && !( $$object->{$inPropertyKey} =~ /$inIncludeRegex/ ) );
                $isInValid = 1
                  if ( defined $inExcludeRegex
                    && $$object->{$inPropertyKey} =~ /$inExcludeRegex/ );

                if ($isInValid) {
                    delete $inTopicData->{$web}{$topic}{$key};
                }
            }
        }
    }
}

=pod

---+++ getListOfObjectData( $topicData ) -> \@objects

Creates an array of objects from topic data objects.

For instance:

For a data structure:

%topicData = (
	Web1 => {
		Topic1 => {
			'name_of_field_1' => FormFieldData object,
			'name_of_field_2' => FormFieldData object,
			...,
		},
	},
}

The call:
my $fields =
      TWiki::Plugins::TopicDataHelperPlugin::getListOfObjectData($topicData);
      
... returns a list of FormFieldData objects.

Function parameters:
   * =\%inTopicData= (hash reference) - topic data

Returns a reference to an unsorted array of data objects.

=cut

sub getListOfObjectData {
    my ($inTopicData) = @_;

    my %topicData = %$inTopicData;
    my @objects   = ();

    # find object references in hash
    while ( ( my $web, my $topicHash ) = each %topicData ) {

        # {web} => hash of topics
        while ( ( my $topic, my $objectDataHash ) = each %$topicHash ) {

            while ( ( my $key, my $value ) = each %$objectDataHash ) {

                push @objects, $$value;
            }
        }
    }
    return \@objects;
}

=pod

---+++ stringifyTopicData( $topicData ) -> \@objects

Creates an array of strings from topic data objects, where each string is generated by the object's method =stringify= (to be implemented by your object's data class). To be used for data serialization.

For example, FormFieldData's =stringify= method looks like this:

sub stringify {
    my $this = shift;

    return
"1.0\t$this->{web}\t$this->{topic}\t$this->{name}\t$this->{value}\t$this->{date}";
}

Call this method with:
my $list = TWiki::Plugins::TopicDataHelperPlugin::stringifyTopicData($inTopicData);
my $text = join "\n", @$list;

Function parameters:
   * =\%inTopicData= (hash reference) - topic data

Returns a reference to an unsorted array of data objects.

=cut

sub stringifyTopicData {
    my ($inTopicData) = @_;

    my %topicData = %$inTopicData;
    my @objects   = ();

    # find object references in hash
    while ( ( my $web, my $topicHash ) = each %topicData ) {

        # {web} => hash of topics
        while ( ( my $topic, my $objectDataHash ) = each %$topicHash ) {

            while ( ( my $key, my $value ) = each %$objectDataHash ) {

                push @objects, $$value->stringify();
            }
        }
    }
    return \@objects;
}

=pod

---+++ sortObjectData( $objectData, $sortOrder, $sortKey, $compareMode, $nameKey ) -> \@objects

Sort objects by property (sort key). Calls _sortObjectsByProperty.

Function parameters:
   * =\@inObjectData= (array reference) - list of data objects (NOT the topic data!)
   * =$inSortOrder= (int) - value of %sortDirections: either $TWiki::Plugins::TopicDataHelperPlugin::sortDirections{'ASCENDING'}, $TWiki::Plugins::TopicDataHelperPlugin::sortDirections{'DESCENDING'} or $TWiki::Plugins::TopicDataHelperPlugin::sortDirections{'NONE'}
   * =$inSortKey= (string) - primary sort key; this will be a property of your data object
   * =$inCompareMode= (string) - sort mode of primary key, either 'numeric' or 'alphabetical'
   * =$inNameKey= (string) - to be used as secondary sort key; must be alphabetical; this will be a property of your data object

Returns a reference to an sorted array of data objects.

=cut

sub sortObjectData {
    my ( $inObjectData, $inSortOrder, $inSortKey, $inCompareMode, $inNameKey ) =
      @_;
    my @objectData = @$inObjectData;

    my $sortOrder = $inSortOrder || $sortDirections{'NONE'};

    my $tmpSortedObjects =
      _sortObjectsByProperty( \@objectData, $sortOrder, $inSortKey,
        $inCompareMode, $inNameKey );

    my @sortedObjects = @$tmpSortedObjects;

    return \@sortedObjects;
}

=pod

---+++ _sortObjectData( $objectData, $sortOrder, $sortKey, $compareMode, $secondaryKey ) -> \@objects

Private function. Sort objects by property (sort key).

Function parameters:
   * =\@inObjectData= (array reference) - list of data objects (NOT the topic data!)
   * =$inSortOrder= (int) - value of %sortDirections: either $TWiki::Plugins::TopicDataHelperPlugin::sortDirections{'ASCENDING'}, $TWiki::Plugins::TopicDataHelperPlugin::sortDirections{'DESCENDING'} or $TWiki::Plugins::TopicDataHelperPlugin::sortDirections{'NONE'}
   * =$inSortKey= (string) - primary sort key; this will be a property of your data object
   * =$inCompareMode= (string) - sort mode of primary key, either 'numeric' or 'alphabetical'
   * =$inSecondaryKey= (string) - to be used as secondary sort key; must be alphabetical; this will be a property of your data object

Returns a reference to an sorted array of data objects.

=cut

sub _sortObjectsByProperty {
    my (
        $inObjectData,  $inSortOrder, $inSortKey,
        $inCompareMode, $inSecondaryKey
    ) = @_;

    my @objectData    = @$inObjectData;
    my @sortedObjects = ();

    if ( defined $inCompareMode && $inCompareMode eq 'integer' ) {
        if ( $inSortOrder == $sortDirections{'ASCENDING'} ) {
            @sortedObjects =
              sort {
                lc( $a->{$inSortKey} ) <=> lc( $b->{$inSortKey} )
                  ||    # secondary key hardcoded
                  lc( $a->{$inSecondaryKey} ) cmp lc( $b->{$inSecondaryKey} )
              } @objectData;
        }
        else {
            @sortedObjects =
              sort {
                lc( $b->{$inSortKey} ) <=> lc( $a->{$inSortKey} )
                  ||    # secondary key hardcoded
                  lc( $b->{$inSecondaryKey} ) cmp lc( $a->{$inSecondaryKey} )
              } @objectData;
        }
    }
    else {

        # compare alphabetically
        if ( $inSortOrder == $sortDirections{'ASCENDING'} ) {
            @sortedObjects =
              sort {
                lc( $a->{$inSortKey} ) cmp lc( $b->{$inSortKey} )
                  ||    # secondary key hardcoded
                  lc( $a->{$inSecondaryKey} ) cmp lc( $b->{$inSecondaryKey} )
              } @objectData;
        }
        else {
            @sortedObjects =
              sort {
                lc( $b->{$inSortKey} ) cmp lc( $a->{$inSortKey} )
                  ||    # secondary key hardcoded
                  lc( $b->{$inSecondaryKey} ) cmp lc( $a->{$inSecondaryKey} )
              } @objectData;
        }
    }
    return \@sortedObjects;
}

=pod

---+++ makeHashFromString( $text, $isCaseSensitive ) -> \%hash

Creates a reference to a key-value hash of a string of words, where each word is turned into a key with a non-zero (growing) number (to keep the original order of the items).

For example:
my $excludeTopicsList = 'WebHome, WebPreferences';
my $excludeTopics = makeHashFromString( $excludeTopicsList, 1 );

... will create:

$hashref = {
	'WebHome'        => 1,
	'WebPreferences' => 2,
};

Function parameters:
   * =$inText= (string) - comma-delimited string of values
   * =$inIsCaseSensitive= (boolean int) - if 0, makes all hash values lowercase; for example, finding matches on file extension should not be case sensitive

Returns a reference to a key-value hash.

=cut

sub makeHashFromString {
    my ( $inText, $inIsCaseSensitive ) = @_;
    my %hash = ();
    return \%hash if !defined $inText || !$inText;

    # remove spaces
    $inText =~ s/\s*,\s*/,/g;
    $inText =~ s/^\s*//g;
    $inText =~ s/\s*$//g;

    my @elems = split( ',', $inText );
    my $count = 1;
    for (@elems) {
        $_ = lc $_ if !$inIsCaseSensitive;
        $hash{$_} = $count++;
    }
    return \%hash;
}

1;
