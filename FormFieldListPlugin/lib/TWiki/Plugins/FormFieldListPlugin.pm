# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2004 Rafael Alvarez, soronthar@flashmail.com
# Copyright (C) 2004 Bernd Raichle, bernd.raichle@gmx.de
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
#

package TWiki::Plugins::FormFieldListPlugin;

use strict;
use TWiki::Func;
use TWiki::Plugins::TopicDataHelperPlugin;
use TWiki::Plugins::FormFieldListPlugin::FormFieldData;

use vars qw($VERSION $RELEASE $pluginName
  $debug $defaultFormat $STORE_FILENAME
);

# This should always be $Rev: 17692 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 17692 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = '2.010';

$STORE_FILENAME = 'field_data.txt';

my %sortInputTable = (
    'none' => $TWiki::Plugins::TopicDataHelperPlugin::sortDirections{'NONE'},
    'ascending' =>
      $TWiki::Plugins::TopicDataHelperPlugin::sortDirections{'ASCENDING'},
    'descending' =>
      $TWiki::Plugins::TopicDataHelperPlugin::sortDirections{'DESCENDING'},
);

$pluginName = 'FormFieldListPlugin';

=pod

=cut

sub initPlugin {
    my ( $inTopic, $inWeb, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    $defaultFormat = '$value';

    # Get plugin preferences
    $defaultFormat =
         TWiki::Func::getPreferencesValue('FORMAT')
      || TWiki::Func::getPluginPreferencesValue('FORMAT')
      || $defaultFormat;
    $defaultFormat =~ s/^[\\n]+//;    # Strip off leading \n

    # Get plugin debug flag
    $debug = TWiki::Func::getPluginPreferencesFlag("DEBUG");

    TWiki::Func::registerTagHandler( 'FORMFIELDLIST', \&_handleFormFieldList );

    # Plugin correctly initialized
    TWiki::Func::writeDebug(
        "- TWiki::Plugins::${pluginName}::initPlugin( $inWeb.$inTopic ) is OK")
      if $debug;

    return 1;
}

=pod

=cut

sub _handleFormFieldList {
    my ( $inSession, $inParams, $inTopic, $inWeb ) = @_;

    my $webs   = $inParams->{'web'}   || $inWeb   || '';
    my $topics = $inParams->{'topic'} || $inTopic || '';
    my $excludeTopics = $inParams->{'excludetopic'} || '';
    my $excludeWebs   = $inParams->{'excludeweb'}   || '';

    # find all topics except for excluded topics
    my $topicData =
      TWiki::Plugins::TopicDataHelperPlugin::createTopicData( $webs,
        $excludeWebs, $topics, $excludeTopics );

    my $excludeEmptyValues = $inParams->{'excludeemptyvalue'} || 'off';
    $inParams->{'doExcludeEmptyValues'} =
      TWiki::Func::isTrue($excludeEmptyValues) ? 1 : 0;
    my $includeMissingFields = $inParams->{'includemissingfields'} || 'off';
    $inParams->{'doIncludeMissingFields'} =
      TWiki::Func::isTrue($includeMissingFields) ? 1 : 0;

    my $formFields = $inParams->{'field'} || $inParams->{_DEFAULT};

    # pass on the order of the form fields; the order will define how the fields
    # will be sorted and displayed
    # only if more fields are specified
    my $formFieldsHash =
      TWiki::Plugins::TopicDataHelperPlugin::makeHashFromString( $formFields,
        1 );
    my $properties = {};
    $properties->{includeMissingFields} = $inParams->{'doIncludeMissingFields'},
      $properties->{formFields}         = $formFieldsHash;

    TWiki::Plugins::TopicDataHelperPlugin::insertObjectData( $topicData,
        \&_createFormFieldData, $properties );

    _filterTopicData( $topicData, $inParams );

    my $fields =
      TWiki::Plugins::TopicDataHelperPlugin::getListOfObjectData($topicData);

    # always sort
    $fields = _sortFields( $fields, $inParams );

    # limit files if param limit is defined
    splice @$fields, $inParams->{'limit'}
      if defined $inParams->{'limit'};

    # format
    my $formatted = _formatFormFieldData( $fields, $inParams );

    return $formatted;
}

=pod

Called from TWiki::Plugins::TopicDataHelperPlugin::insertObjectData.
Called with every topic.
Creates a data object for each topic:

topic => {
	'name_of_field_1' => FormFieldData object,
	'name_of_field_2' => FormFieldData object,
	...,
}

=cut

sub _createFormFieldData {
    my ( $inTopicHash, $inWeb, $inTopic, $inProperties ) = @_;

    my $formFieldsHash       = $inProperties->{formFields};
    my $includeMissingFields = $inProperties->{includeMissingFields};

    # define value for topic key only if topic
    # has META:FIELD data
    my ( $fields, $meta ) = _getFormFieldsInTopic( $inWeb, $inTopic );
    if ( scalar @$fields ) {
        $inTopicHash->{$inTopic} = ();

        foreach my $field (@$fields) {
            my $fd =
              _createFormFieldDataObject( $inWeb, $inTopic, $field,
                $field->{name}, $formFieldsHash, $meta );
            $inTopicHash->{$inTopic}{ $field->{name} } = $fd;
        }
    }
    else {

        # no META:FIELD, so remove from hash
        delete $inTopicHash->{$inTopic};
    }

    if ($includeMissingFields) {

        # list empty values, even if they are not in the listed FIELDs
        # if so, create fields and mark as 'notfound'
        while ( ( my $expectedFieldName, my $expectedOrder ) =
            each %$formFieldsHash )
        {
            my $currentFd = $inTopicHash->{$inTopic}{$expectedFieldName};
            if ( !defined $currentFd ) {
                my $fd = _createFormFieldDataObject( $inWeb, $inTopic, undef,
                    $expectedFieldName, $inProperties, $meta );
                $$fd->{notfound}                             = 1;
                $inTopicHash->{$inTopic}                     = ();
                $inTopicHash->{$inTopic}{$expectedFieldName} = $fd;
            }
        }
    }
}

=pod

Returns a reference to a new FormFieldData object.

=cut

sub _createFormFieldDataObject {
    my ( $inWeb, $inTopic, $inField, $inName, $inFormFieldsHash, $inMeta ) = @_;

    my $fd =
      TWiki::Plugins::FormFieldListPlugin::FormFieldData->new( $inWeb, $inTopic,
        $inField, $inName );

    my $order = $$inFormFieldsHash{$inName} || 0;
    $fd->{order} = $order;

    my ( $revDate, $author, $rev, $comment ) = $inMeta->getRevisionInfo();
    my $wikiUserName = '';
    $wikiUserName = TWiki::Func::userToWikiName( $author, 1 );
    $fd->{user} = $wikiUserName;
    $fd->setTopicDate($revDate);

    return \$fd;
}

=pod

Filters topic data references in the $inTopicData hash.
Called function remove topic data references in the hash.

=cut

sub _filterTopicData {
    my ( $inTopicData, $inParams ) = @_;

    my %topicData = %$inTopicData;

    # ----------------------------------------------------
    # filter included/excluded field names
    my $fields = $inParams->{'field'} || $inParams->{_DEFAULT} || undef;
    if ( defined $fields || defined $inParams->{'excludefield'} ) {
        TWiki::Plugins::TopicDataHelperPlugin::filterTopicDataByProperty(
            \%topicData, 'name', 1, $fields, $inParams->{'excludefield'} );
    }
    if (   defined $inParams->{'includefieldpattern'}
        || defined $inParams->{'excludefieldpattern'} )
    {
        TWiki::Plugins::TopicDataHelperPlugin::filterTopicDataByRegexMatch(
            \%topicData, 'name',
            $inParams->{'includefieldpattern'},
            $inParams->{'excludefieldpattern'}
        );
    }

    # exclude fields with no value
    if ( $inParams->{'doExcludeEmptyValues'} ) {
        TWiki::Plugins::TopicDataHelperPlugin::filterTopicDataByProperty(
            \%topicData,
            'value',
            1,
            undef,
            $TWiki::Plugins::FormFieldListPlugin::FormFieldData::EMPTY_VALUE_PLACEHOLDER
        );
    }

    # ----------------------------------------------------
    # filter included/excluded field VALUES
    if (   defined $inParams->{'includevalue'}
        || defined $inParams->{'excludevalue'} )
    {
        TWiki::Plugins::TopicDataHelperPlugin::filterTopicDataByProperty(
            \%topicData, 'value', 1,
            $inParams->{'includevalue'},
            $inParams->{'excludevalue'}
        );
    }
    if (   defined $inParams->{'includevaluepattern'}
        || defined $inParams->{'excludevaluepattern'} )
    {
        TWiki::Plugins::TopicDataHelperPlugin::filterTopicDataByRegexMatch(
            \%topicData, 'value',
            $inParams->{'includevaluepattern'},
            $inParams->{'excludevaluepattern'}
        );
    }

    # ----------------------------------------------------
    # filter fields by user
    if ( defined $inParams->{'user'} || defined $inParams->{'excludeuser'} ) {
        TWiki::Plugins::TopicDataHelperPlugin::filterTopicDataByProperty(
            \%topicData, 'user', 1, $inParams->{'user'},
            $inParams->{'excludeuser'} );
    }

    # ----------------------------------------------------
    # filter fields by date range
    if ( defined $inParams->{'fromdate'} || defined $inParams->{'todate'} ) {
        TWiki::Plugins::TopicDataHelperPlugin::filterTopicDataByDateRange(
            \%topicData, $inParams->{'fromdate'},
            $inParams->{'todate'} );
    }

}

=pod

Only when sort="$fieldDate". Compares field values with cache. If a value has not been updated, uses the date of the cached version.

=cut

sub _updateFieldDatesWithCache {
    my ($inFields) = @_;

    my @fields = @$inFields;

    my @cacheList = split( "\n", _readWorkFile($STORE_FILENAME) );
    my $cacheNeedsUpdate = 0;
    if ( !scalar @cacheList ) {

        # no cache file exists yet
        TWiki::Func::writeDebug(
"FormFieldListPlugin::_updateFieldDatesWithCache: no cache file exists yet"
        ) if $debug;
        $cacheNeedsUpdate = 1;

        foreach my $field (@fields) {
            my $newFieldLine = $field->stringify();
            push @cacheList, $newFieldLine;
        }
    }
    else {

        # cache file exists
        # create quick lookup hash for cache
        my %lookup = ();
        my $index  = 0;
        foreach my $line (@cacheList) {
            my @parts      = split( "\t", $line );
            my $web        = $parts[1];
            my $topic      = $parts[2];
            my $fieldName  = $parts[3];
            my $fieldValue = $parts[4];
            my $topicDate  = $parts[5];
            $lookup{$web}{$topic}{$fieldName}{'value'} = $fieldValue;
            $lookup{$web}{$topic}{$fieldName}{'date'}  = $topicDate;

            # store array index for easy updating the cache
            $lookup{$web}{$topic}{$fieldName}{'index'} = $index;
            $index++;
        }

        # now compare fields with cache
        foreach my $field (@fields) {
            my $web       = $field->{web};
            my $topic     = $field->{topic};
            my $fieldName = $field->{name};

            my $cachedValue = $lookup{$web}{$topic}{$fieldName}{'value'};

            if ( !defined $cachedValue ) {

                # add entry to cache
                TWiki::Func::writeDebug(
"FormFieldListPlugin::_updateFieldDatesWithCache: add entry to cache for topic:$topic, field name:$fieldName"
                ) if $debug;
                $cacheNeedsUpdate = 1;
                my $newFieldLine = $field->stringify();
                push @cacheList, $newFieldLine;
            }
            else {

                # compare values
                if ( $cachedValue ne $field->{'value'} ) {

                    # value has changed, update cache
                    TWiki::Func::writeDebug(
"FormFieldListPlugin::_updateFieldDatesWithCache: value has changed, update cache for topic:$topic, field name:$fieldName, value:$cachedValue; new value:$field->{'value'}"
                    ) if $debug;
                    $field->setFieldDate( $field->{date} );
                    $cacheNeedsUpdate = 1;
                    my $updatedFieldLine = $field->stringify();
                    my $index = $lookup{$web}{$topic}{$fieldName}{'index'};
                    $cacheList[$index] = $updatedFieldLine;
                }
                else {

                    # value unchanged, use cached date
                    TWiki::Func::writeDebug(
"FormFieldListPlugin::_updateFieldDatesWithCache: value unchanged, use cached date for topic:$topic, field name:$fieldName, value:$cachedValue"
                    ) if $debug;
                    my $date = $lookup{$web}{$topic}{$fieldName}{'date'};
                    $field->{fieldDate} = $date;
                }
            }
        }
    }

    if ($cacheNeedsUpdate) {

        # save cache
        my $cacheText = join "\n", sort @cacheList;
        TWiki::Func::writeDebug(
"FormFieldListPlugin::_updateFieldDatesWithCache: save cache:\n$cacheText"
        ) if $debug;
        _saveWorkFile( $STORE_FILENAME, $cacheText );
    }
}

sub _readWorkFile {
    my ($inFileName) = @_;

    my $workarea = TWiki::Func::getWorkArea($pluginName);
    return TWiki::Func::readFile( $workarea . '/' . $inFileName );
}

sub _saveWorkFile {
    my ( $inFileName, $inText ) = @_;

    my $workarea = TWiki::Func::getWorkArea($pluginName);
    my $path     = $workarea . '/' . $inFileName;

    TWiki::Func::saveFile( $path, $inText );
}

=pod

=cut

sub _sortFields {
    my ( $inFields, $inParams ) = @_;

    my $fields = $inFields;
    my $sortMode = $inParams->{'sort'} || '$topicName';

    _updateFieldDatesWithCache($fields)
      if ( $sortMode eq '$fieldDate' );

    # get the sort key for the $inSortMode
    my $sortKey =
      &TWiki::Plugins::FormFieldListPlugin::FormFieldData::getSortKey(
        $sortMode);
    my $compareMode =
      &TWiki::Plugins::FormFieldListPlugin::FormFieldData::getCompareMode(
        $sortMode);

    # translate input to sort parameters
    my $sortOrderParam = $inParams->{'sortorder'} || 'none';
    my $sortOrder = $sortInputTable{$sortOrderParam}
      || $TWiki::Plugins::TopicDataHelperPlugin::sortDirections{'NONE'};

    # set default sort order for sort modes
    if ( $sortOrder ==
        $TWiki::Plugins::TopicDataHelperPlugin::sortDirections{'NONE'} )
    {
        if ( defined $sortKey
            && ( $sortKey eq 'date' || $sortKey eq 'fieldDate' ) )
        {

            # exception for dates: newest on top
            $sortOrder = $TWiki::Plugins::TopicDataHelperPlugin::sortDirections{
                'DESCENDING'};
        }
        else {

            # otherwise sort by default ascending
            $sortOrder = $TWiki::Plugins::TopicDataHelperPlugin::sortDirections{
                'ASCENDING'};
        }
    }

    $sortOrder = -$sortOrder
      if ( $sortOrderParam eq 'reverse' );

    # SMELL: order is numeric, while currently the secondary sort key can only
    # be alphabetical. This is bound to break something.
    # Will be fixed when proper sorting is available in TopicDataHelperPlugin.
    my $secondarySortKey = 'order';

    $fields =
      TWiki::Plugins::TopicDataHelperPlugin::sortObjectData( $fields,
        $sortOrder, $sortKey, $compareMode, $secondarySortKey )
      if defined $sortKey;

    return $fields;
}

=pod

Formats 
=cut

sub _formatFormFieldData {
    my ( $inFields, $inParams ) = @_;

    my @fields = @$inFields;

    # formatting parameters
    my $format = $inParams->{'format'} || $defaultFormat;
    my $header = $inParams->{'header'} || '';
    my $footer = $inParams->{'footer'} || '';
    my $default = $inParams->{'default'} || ''; # when no value is found
    my $alttext = $inParams->{'alttext'} || ''; # when no field is found in form
    my $alt     = $inParams->{'alt'}     || ''; # when no fields are found
    my $separator   = $inParams->{'separator'}   || "\n";
    my $topicHeader = $inParams->{'topicheader'} || undef;

    my @formattedData = ();
    my $topic         = '';    # keep track of topic if $topicHeader is defined

    my $count = 0;

    foreach my $field (@fields) {

        my $s     = "$format";
        my $value = $field->{value};
        $value =~
s/$TWiki::Plugins::FormFieldListPlugin::FormFieldData::EMPTY_VALUE_PLACEHOLDER/$default/g;

        if ( $field->{'notfound'} ) {
            if ($alttext) {
                $value = '$alttext';
            }
        }
        $s =~ s/\$value/$value/g;
        $s =~ s/\$alttext/$alttext/g;

        # substitution variables
        _substituteFormattingVariables( $field, $s );

        # topicHeader
        # add topic header if we are moving to a different topic
        if ( defined $topicHeader && $topic ne $field->{topic} ) {
            my $sep = $topicHeader;
            _substituteFormattingVariables( $field, $sep );
            push @formattedData, $sep;
            $topic = $field->{topic};
        }
        $topic = $field->{topic};

        push @formattedData, $s;
        $count++;
    }

    my $outText = join $separator, @formattedData;

    if ( $outText eq '' ) {
        $outText = $alt;
    }
    else {
        $header =~ s/(.+)/$1\n/;              # add newline if text
        $footer =~ s/(.+)/\n$1/;              # add newline if text
                                              # fileCount format param
        $header =~ s/\$fieldCount/$count/g;
        $footer =~ s/\$fieldCount/$count/g;

        $outText = "$header$outText$footer";
    }
    $outText = _decodeFormatTokens($outText);
    $outText =~ s/\$br/\<br \/\>/g;
    return $outText;
}

=pod

=cut

sub _substituteFormattingVariables {

    # $field = $_[0]
    # $text = $_[1]
    $_[1] =~ s/\$title/$_[0]->{title}/g;
    $_[1] =~ s/\$name/$_[0]->{name}/g;
    $_[1] =~ s/\$topicName/$_[0]->{topic}/g;
    $_[1] =~ s/\$webName/$_[0]->{web}/g;
    $_[1] =~ s/\$topicUser/$_[0]->{user}/g;
    $_[1] =~ s/\$topicDate/_formatDate($_[0]->{date})/ge;
    $_[1] =~ s/\$fieldDate/_formatDate($_[0]->{fieldDate})/ge;
}

=pod

Returns an array of tuples (FILEATTACHMENT object, $meta).

=cut

sub _getFormFieldsInTopic {
    my ( $inWeb, $inTopic ) = @_;

    my ( $meta, $text ) = TWiki::Func::readTopic( $inWeb, $inTopic );
    my @formFieldData = $meta->find("FIELD");
    return ( \@formFieldData, $meta );
}

=pod

Formats $epoch seconds to the date-time format specified in configure.

=cut

sub _formatDate {
    my ($epoch) = @_;

    return TWiki::Func::formatTime(
        $epoch,
        $TWiki::cfg{DefaultDateFormat},
        $TWiki::cfg{DisplayTimeValues}
    );
}

=pod

=cut

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
