# Plugin for Foswiki - The Free Open Source Wiki, http://foswiki.org/
#
# Copyright (c) 2007, 2008 by Arthur Clemens
# All Rights Reserved. TWiki Contributors
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

package TWiki::Plugins::FormPlugin;

# Always use strict to enforce variable scoping
use strict;

use TWiki::Func;
use CGI qw( :all );

#use TWiki::Plugins::FormPlugin::Validate qw(CheckFormData);
#use CGI::Validate qw(:vars);

# $VERSION is referred to by TWiki, and is the only global variable that
# *must* exist in this package
use vars qw( $VERSION $RELEASE $debug $pluginName $installWeb);
use vars
  qw( $currentTopic $currentWeb $defaultFormat $defaultHiddenFieldFormat $defaultTitleFormat %expandedForms %substitutedForms %uncheckedForms %validatedForms %errorForms %noErrorForms %errorFields $headerDone
  %currentForm $elementcssclass);

# This should always be $Rev: 11069$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 11069$';
$RELEASE = '1.2';

# Name of this Plugin, only used in this module
$pluginName = 'FormPlugin';

$headerDone               = 0;
$defaultTitleFormat       = ' $t <br />';
$defaultFormat            = '<p>$titleformat $e $m $h </p>';
$defaultHiddenFieldFormat = '$e';
%expandedForms            = ();
%validatedForms           = ();
%errorForms               = ();
%noErrorForms             = ();
%uncheckedForms           = ();
%substitutedForms         = ()
  ; # hash of forms names that have their field tokens substituted by the corresponding field values
%errorFields = ();    # for each field entry: ...

# constants
my $STATUS_NO_ERROR  = 'noerror';
my $STATUS_ERROR     = 'error';
my $STATUS_UNCHECKED = 'unchecked';
my $DEFAULT_METHOD   = 'GET';
my $FORM_SUBMIT_TAG  = 'FP_submit';
my $ACTION_URL_TAG   = 'FP_actionurl';
my $VALIDATE_TAG     = 'FP_validate';
my $CONDITION_TAG    = 'FP_condition';
my $FIELDTITLE_TAG   = 'FP_title';
my $MULTIPLE_TAG_ID  = '=m';
my %MULTIPLE_TYPES   = (
    'radio'    => 1,
    'select'   => 1,
    'checkbox' => 1
);
my %ERROR_STRINGS = (
    'invalid'     => '- enter a different value',
    'invalidtype' => '- enter a different value',
    'blank'       => '- please enter a value',
    'missing'     => '- please enter a value',
);
my %ERROR_TYPE_HINTS = (
    'integer' => '(a rounded number)',
    'float'   => '(a floating number)',
    'email'   => '(an e-mail address)',
);

# translate from user-friendly names to Validate.pm input
my %REQUIRED_TYPE_TABLE = (
    'int'      => 'i',
    'float'    => 'f',
    'email'    => 'e',
    'nonempty' => 's',
    'string'   => 's',
);
my %CONDITION_TYPE_TABLE = (
    'int'      => 'i',
    'float'    => 'f',
    'email'    => 'e',
    'nonempty' => 's',
    'string'   => 's',
);
my $NOTIFICATION_ANCHOR_NAME     = 'FormPluginNotification';
my $ELEMENT_ANCHOR_NAME          = 'FormElement';
my $NOTIFICATION_CSS_CLASS       = 'formPluginNotification';
my $ELEMENT_GROUP_CSS_CLASS      = 'formPluginGroup';
my $ELEMENT_GROUP_HINT_CSS_CLASS = 'formPluginGroupWithHint';
my $ERROR_CSS_CLASS              = 'formPluginError';
my $TITLE_CSS_CLASS              = 'formPluginTitle';
my $HINT_CSS_CLASS               = 'formPluginHint';
my $MANDATORY_CSS_CLASS          = 'formPluginMandatory';
my $MANDATORY_STRING             = '*';
my $BEFORE_CLICK_CSS_CLASS       = 'twikiInputFieldBeforeClick';

=pod

=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    $currentTopic = $topic if !$currentTopic;
    $currentWeb   = $web   if !$currentWeb;

    $debug = TWiki::Func::getPluginPreferencesFlag("DEBUG")
      || TWiki::Func::getPreferencesFlag("DEBUG");

    TWiki::Func::registerTagHandler( 'STARTFORM',   \&_startForm );
    TWiki::Func::registerTagHandler( 'ENDFORM',     \&_endForm );
    TWiki::Func::registerTagHandler( 'FORMELEMENT', \&_formElement );
    TWiki::Func::registerTagHandler( 'FORMSTATUS',  \&_formStatus );

    # Plugin correctly initialized
    return 1;
}

=pod

Process form before any %STARTFORM{}% is expanded:
- substitute tokens
- validate form

Because beforeCommonTagsHandler is called multiple times while rendering, the processed forms are stored and checked each time.

=cut

sub beforeCommonTagsHandler {

    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web ) = @_;

    my $query = TWiki::Func::getCgiQuery();
    my $submittedFormName =
      $query->param($FORM_SUBMIT_TAG);    # form name is stored in submit
    if ($submittedFormName) {
        return
          if $substitutedForms{$submittedFormName}
              && $validatedForms{$submittedFormName};
    }

    # substitute dynamic values
    if ( $submittedFormName && !$substitutedForms{$submittedFormName} ) {
        _substituteFieldTokens();
        $substitutedForms{$submittedFormName} = $submittedFormName;
    }

    # validate form
    if ( $submittedFormName && !$validatedForms{$submittedFormName} ) {

        my $error = !_validateForm();
        if ($error) {
            $errorForms{$submittedFormName}   = 1;
            $noErrorForms{$submittedFormName} = 0;
        }
        else {
            $errorForms{$submittedFormName}   = 0;
            $noErrorForms{$submittedFormName} = 1;
        }
        $validatedForms{$submittedFormName} = 1;
    }

}

sub _initValues {
    $elementcssclass = '';

    # form attributes we want to retrieve while parsing FORMELEMENT tags:
    undef %currentForm;
    %currentForm = (
        'name'          => 'untitled',
        'elementformat' => $defaultFormat,
        'noFormHtml'    => '',
    );
}

=pod

Read form field tokens and replace them by the field values.
For instance: if a field contains the value '$about', this string is substituted
by the value of the field with name 'about'.

=cut

sub _substituteFieldTokens {

    my $query = TWiki::Func::getCgiQuery();

    # create quick lookup hash
    my @names = $query->param;
    my %keyValues;
    my %conditionFields = ();
    foreach (@names) {
        my $name = $_;
        next if !$name;
        $keyValues{$name} = $query->param($name);
    }
    foreach ( keys %keyValues ) {
        my $name = $_;
        next if $conditionFields{$name};    # value already set with a condition
        my $value = $keyValues{$_};
        my ( $referencedField, $meetsCondition ) =
          _meetsCondition( $name, $value );
        if ($meetsCondition) {
            $value =~ s/(\$(\w+))/$keyValues{$2}/go;
            $query->param( -name => $_, -value => $value );
        }
        else {
            $value = '';
            $query->param( -name => $referencedField, -value => $value );
            $conditionFields{$referencedField} = 1;
        }
    }
}

=pod

Checks if a field value meets the condition of a referenced field.
For instance:

User input is:
%FORMELEMENT{
name="comment_from_date"
condition="$comment_from_date_input=nonempty"
}%

This has been parsed to:
(hidden) field name: FP_condition_comment_from_date
(hidden) field value: =comment_from_date=s

=cut

sub _meetsCondition {
    my ( $fieldName, $nameAndValidationType ) = @_;

    if ( !( $fieldName =~ m/^$CONDITION_TAG\_(.+?)$/go ) ) {
        return ( $fieldName, 1 );    # no condition, so pass
    }

    my $referencedField = $1;

    my %validateFields = ();
    _createValidationFieldEntry( $referencedField, $nameAndValidationType, 0,
        \%validateFields );

    _validateFormFields(%validateFields);
    if (@TWiki::Plugins::FormPlugin::Validate::ErrorFields) {
        return ( $referencedField, 0 );
    }
    return ( $referencedField, 1 );
}

=pod

Retrieves the status of the form. Usage:

%FORMSTATUS{"form_name"}%

or

%FORMSTATUS{"form_name" status="noerror"}%
%FORMSTATUS{"form_name" status="error"}%
%FORMSTATUS{"form_name" status="unchecked"}%

=cut

sub _formStatus {
    my ( $session, $params, $topic, $web ) = @_;

    my $name = $params->{'_DEFAULT'};
    return '' if !$name;

    my $statusFormat = $params->{'status'};
    my %status       = _status($name);

    return $status{$statusFormat} || "0" if $statusFormat;
    return $STATUS_NO_ERROR if ( $noErrorForms{$name} );
    return $STATUS_ERROR    if ( $errorForms{$name} );

    # else
    return $STATUS_UNCHECKED;
}

=pod

=cut

sub _status {
    my ($formName) = @_;
    return (
        $STATUS_NO_ERROR  => $noErrorForms{$formName},
        $STATUS_ERROR     => $errorForms{$formName},
        $STATUS_UNCHECKED => !$noErrorForms{$formName}
          && !$errorForms{$formName},
    );
}

=pod

=cut

sub _addHeader {

    return if $headerDone;

    my $header = <<'END';
<style type="text/css" media="all">
@import url("%PUBURL%/%SYSTEMWEB%/FormPlugin/formplugin.css");
</style>
<script type="text/javascript" src="%PUBURL%/%SYSTEMWEB%/JavascriptFiles/foswikilib.js"></script>
<script type="text/javascript" src="%PUBURL%/%SYSTEMWEB%/JavascriptFiles/foswikiCSS.js"></script>
<script type="text/javascript" src="%PUBURL%/%SYSTEMWEB%/JavascriptFiles/foswikiForm.js"></script>
<script type="text/javascript" src="%PUBURL%/%SYSTEMWEB%/JavascriptFiles/foswikiString.js"></script>
END

    TWiki::Func::addToHEAD( 'FORMPLUGIN', $header );
    $headerDone = 1;
}

=pod

Order of actions:
- Check if this is the form that has been submitted
- Returns if the form did not validate (has been validated before this call)
- Redirects if an action url has been passed in the form

=cut

sub _startForm {
    my ( $session, $params, $topic, $web ) = @_;

    _initValues();
    _addHeader();

    my $name = $params->{'name'} || '';
    return '' if $expandedForms{$name};

    # else
    $expandedForms{$name} = 1;

    # check if the submitted form is the form at hand
    my $query             = TWiki::Func::getCgiQuery();
    my $submittedFormName = $query->param($FORM_SUBMIT_TAG);

    if ( $submittedFormName && $name eq $submittedFormName ) {
        if ( $errorForms{$submittedFormName} ) {

            # show validation error feedback above form
            return _displayErrors(@_) . _displayForm(@_);
        }

        # redirectto if an action url has been passed in the form
        my $actionUrl = $query->param($ACTION_URL_TAG);
        if ($actionUrl) {

            # delete temporary parameters
            $query->delete($ACTION_URL_TAG);

# do not delete param $FORM_SUBMIT_TAG as we might want to know if this form is validated
            my $method = _method( $params->{'method'} );
            if ( $method eq 'POST' && $TWiki::Plugins::VERSION < 1.2 ) {

                # on previous versions redirecting a POST does not work
                # because the request is changed to a GET
                # to not loose the parameters we will convert all key-values
                # to a parameter string
                $actionUrl .= '?' . _postDataToUrlParamString();

                # we now have a url param
                # delete original POST data
                $query->delete_all();
                TWiki::Func::writeDebug(
"FormPlugin - POST and Plugins::VERSION < 1.2 -- converting all key-values to a parameter string: actionUrl="
                      . $actionUrl )
                  if $debug;
                TWiki::Func::redirectCgiQuery( undef, $actionUrl );
                return;
            }

            # else
            TWiki::Func::redirectCgiQuery( undef, $actionUrl, 1 );
            return '';
        }
    }

    # else
    return _displayForm(@_);
}

=pod

Code taken from TWiki.pm

=cut

sub _isRedirectSafe {
    my $redirect = shift;

    #TODO: this should really use URI
    if (   ( !$TWiki::cfg{AllowRedirectUrl} )
        && ( $redirect =~ m!^([^:]*://[^/]*)/*(.*)?$! ) )
    {
        my $host = $1;

        #remove trailing /'s to match
        $TWiki::cfg{DefaultUrlHost} =~ m!^([^:]*://[^/]*)/*(.*)?$!;
        my $expected = $1;

        if ( defined( $TWiki::cfg{PermittedRedirectHostUrls} )
            && $TWiki::cfg{PermittedRedirectHostUrls} ne '' )
        {
            my @permitted =
              map { s!^([^:]*://[^/]*)/*(.*)?$!$1!; $1 }
              split( /,\s*/, $TWiki::cfg{PermittedRedirectHostUrls} );
            return 1 if ( grep ( { uc($host) eq uc($_) } @permitted ) );
        }
        return ( uc($host) eq uc($expected) );
    }
    return 1;
}

=pod

Returns 1 when validation is ok; 0 if an error has been found.

=cut

sub _validateForm {

    eval 'use TWiki::Plugins::FormPlugin::Validate';

    # Some fields might need to be validated
    # this is set with parameter =validate="s"= in %FORMELEMENT%
    # during parsing of %FORMELEMENT% this has been converted to
    # a new hidden field $VALIDATE_TAG_fieldname
    my $query = TWiki::Func::getCgiQuery();

    my @names          = $query->param;
    my %validateFields = ();
    my $order          = 0;
    foreach (@names) {
        my $name = $_;
        next if !$name;

        # the (hidden) field that has set the validation type
        # can be recognized by $VALIDATE_TAG_fieldname
        my $isSettingField = $name =~ m/^$VALIDATE_TAG\_(.+?)$/go;
        if ($isSettingField) {
            my $referencedField       = $1;
            my $nameAndValidationType = $query->param($name);
            _createValidationFieldEntry( $referencedField,
                $nameAndValidationType, $order++, \%validateFields );
        }
    }

    # return all fine if nothing to be done
    return 1 if !keys %validateFields;

    _validateFormFields(%validateFields);
    if (@TWiki::Plugins::FormPlugin::Validate::ErrorFields) {

        # store field name refs
        for my $href (@TWiki::Plugins::FormPlugin::Validate::ErrorFields) {
            my $fieldNameForRef = $href->{'field'};
            $errorFields{$fieldNameForRef} = 1;
        }
        return 0;
    }
    return 1;
}

sub _createValidationFieldEntry {
    my ( $fieldName, $nameAndValidationType, $order, $validateFields ) = @_;

    # create hash entry:
    # string_fieldname+validation_type => reference_field
    $nameAndValidationType =~ s/^(.*?)(\=m)*$/$1/go;

    # append order argument
    $nameAndValidationType .= '=' . $order;

    my $isMultiple = $2 if $2;
    if ($isMultiple) {
        my @fieldNameRef;
        $validateFields->{$nameAndValidationType} = \@fieldNameRef
          if $nameAndValidationType;
    }
    else {
        my $fieldNameRef;
        $validateFields->{$nameAndValidationType} = \$fieldNameRef
          if $nameAndValidationType;
    }
}

=pod

Use Validator to check fields.

Returns 1 when validation is ok; 0 if an error has been found.

=cut

sub _validateFormFields {
    my (%fields) = @_;

    eval 'use TWiki::Plugins::FormPlugin::Validate';

    # allow some fields not to be validated
    # otherwise we get errors on hidden fields we have inserted ourselves
    $TWiki::Plugins::FormPlugin::Validate::IgnoreNonMatchingFields = 1;

    # not need to check for all form elements
    $TWiki::Plugins::FormPlugin::Validate::Complete = 1;

    # test fields
    TWiki::Plugins::FormPlugin::Validate::GetFormData(%fields);

    if ($TWiki::Plugins::FormPlugin::Validate::Error) {
        return 0;
    }

    return 1;
}

=pod

=cut

sub _displayErrors {
    my ( $session, $params, $topic, $web ) = @_;

    if (@TWiki::Plugins::FormPlugin::Validate::ErrorFields) {
        my $note = " *Some fields are not filled in correctly:* ";
        my @sortedErrorFields =
          sort { $a->{order} cmp $b->{order} }
          @TWiki::Plugins::FormPlugin::Validate::ErrorFields;
        for my $href (@sortedErrorFields) {
            my $errorType   = $href->{'type'};
            my $fieldName   = $href->{'field'};
            my $errorString = $ERROR_STRINGS{$errorType} || '';
            my $expected    = $href->{'expected'};
            my $expectedString =
              $expected ? ' ' . $ERROR_TYPE_HINTS{$expected} : '';
            $errorString .= $expectedString;
            my $anchor = '#' . _anchorLink($fieldName);

            # preserve state information
            my $currentUrl = _currentUrl(@_);
            $note .=
"\n   * <a href=\"$currentUrl$anchor\">$fieldName</a> $errorString";
        }
        return _wrapHtmlError($note) if scalar @sortedErrorFields;
    }
    return '';
}

=pod

With GET, retrieves the url parameters if any.
With POST, ignores url parameters.

=cut

sub _currentUrl {
    my ( $session, $params, $topic, $web ) = @_;

    my $query      = TWiki::Func::getCgiQuery();
    my $currentUrl = $query->url() . $query->path_info();
    return $currentUrl;
}

=pod

=cut

sub _method {
    my ($method) = @_;

    $method ||= $DEFAULT_METHOD;
    return $method;
}

=pod


=cut

sub _displayForm {
    my ( $session, $params, $topic, $web ) = @_;

    my $name = $params->{'name'} || '';

    my $actionParam = $params->{'action'} || '';
    my $method = _method( $params->{'method'} || '' );
    my $redirectto = $params->{'redirectto'} || '';
    $elementcssclass = $params->{'elementcssclass'} || '';
    my $formcssclass = $params->{'formcssclass'} || '';
    my $webParam     = $params->{'web'}          || '';
    my $topicParam   = $params->{'topic'}        || '';

    # store for element rendering
    $currentForm{'name'} = $name;
    $currentForm{'elementformat'} = $params->{'elementformat'} || '';

    my $noFormHtml = TWiki::Func::isTrue( $params->{'noformhtml'} || '' );
    if ($noFormHtml) {
        $currentForm{'noFormHtml'} = 1;
        return '';
    }

    if ($topicParam) {
        ( $web, $topic ) =
          TWiki::Func::normalizeWebTopicName( $webParam, $topicParam );
    }
    else {
        $web   = $currentWeb;
        $topic = $currentTopic;
    }

    my $anchor = $params->{'anchor'} || $NOTIFICATION_ANCHOR_NAME;

    my $actionUrl = '';
    if ( $actionParam eq 'save' ) {
        $actionUrl = "%SCRIPTURL{save}%/$web/$topic";
    }
    elsif ( $actionParam eq 'edit' ) {
        $actionUrl = "%SCRIPTURL{edit}%/$web/$topic";
    }
    elsif ( $actionParam eq 'upload' ) {
        $actionUrl = "%SCRIPTURL{upload}%/$web/$topic";
    }
    elsif ( $actionParam eq 'view' ) {
        $actionUrl = "%SCRIPTURL{view}%/$web/$topic";
    }
    elsif ( $actionParam eq 'viewauth' ) {
        $actionUrl = "%SCRIPTURL{viewauth}%/$web/$topic";
    }
    else {
        $actionUrl = $actionParam;
    }

    my $currentUrl = _currentUrl(@_);
    $currentUrl .= '#' . $anchor if ( defined $anchor );

    my $onSubmit = $params->{'onSubmit'} || undef;

    my %startFormParameters = ();
    $startFormParameters{'-name'}     = $name;
    $startFormParameters{'-method'}   = $method;
    $startFormParameters{'-onSubmit'} = $onSubmit if $onSubmit;

    my $disableValidation = $params->{'validate'} eq 'off'
      if ( defined $params->{'validate'} );

    $startFormParameters{'-action'} =
      $disableValidation ? $actionUrl : $currentUrl;

    # multi-part is needed for upload. Why not always use it?
    #my $formStart = CGI::start_form(%startFormParameters);
    my $formStart = CGI::start_multipart_form(%startFormParameters);
    my $formClassAttr = $formcssclass ? " class=\"$formcssclass\"" : '';
    $formStart .= "<div$formClassAttr>\n<!--FormPlugin form start-->";

    $formStart .= "\n"
      . CGI::hidden(
        -name    => $ACTION_URL_TAG,
        -default => $actionUrl
      ) if $actionUrl;

    # store name reference in form so it can be retrieved after submitting
    $formStart .= "\n"
      . CGI::hidden(
        -name    => $FORM_SUBMIT_TAG,
        -default => $name
      );

    $formStart .= "\n"
      . CGI::hidden(
        -name    => 'redirectto',
        -default => $redirectto
      ) if $redirectto;

    return $formStart;
}

=pod

=cut

sub _endForm {
    my ( $session, $params, $topic, $web ) = @_;

    my $endForm = '</div><!--/FormPlugin form end-->' . CGI::end_form();
    $endForm = '' if ( $currentForm{'noFormHtml'} );
    _initValues();
    return $endForm;
}

=pod

Lifted out:
# needs to be tested more
    my $formcondition = $params->{'formcondition'};

    if ($formcondition) {
        $formcondition =~ m/^(.*?)\.(.*?)$/;
        my ( $formName, $conditionStatus ) = ( $1, $2 );
        my %status = _status($formName);
        return '' unless isTrue( $status{$conditionStatus} );
        
        my $query = TWiki::Func::getCgiQuery();
        my $default          = $params->{'default'};
        $query->param( -name => $name, -value => $default );
    }

| =formcondition= | Display only if the form condition is true. Condition syntax: =form_name.contition_status=, where =contition_status= is one of =unchecked=, =error= or =noerror= |- |- | =formcondition="Mailform.noerror"= |
=cut

sub _formElement {
    my ( $session, $params, $topic, $web ) = @_;

    _addHeader();

    my $element = _getFormElementHtml(@_);

    $element =
        '<noautolink>' 
      . $element
      . '</noautolink>';    # prevent wiki words inside form fields
    my $type = $params->{'type'};
    my $name = $params->{'name'};

    my $format =
         $params->{'format'}
      || $currentForm{'elementformat'}
      || $defaultFormat;
    $format = $defaultHiddenFieldFormat if ( $type eq 'hidden' );

    my $javascriptCalls = '';
    my $focus           = $params->{'focus'};
    if ($focus) {
        my $focusCall =
            '<script type="text/javascript">foswiki.Form.setFocus("'
          . $currentForm{'name'} . '", "'
          . $name
          . '");</script>';
        $javascriptCalls .= $focusCall;
    }
    my $beforeclick = $params->{'beforeclick'};
    if ($beforeclick) {
        my $formName        = $currentForm{'name'};
        my $beforeclickCall = '';
        $beforeclickCall .= '<script type="text/javascript">';
        if ( $formName eq '' ) {
            $beforeclickCall .=
                'var field=document.getElementsByName("' 
              . $name
              . '")[0]; var formName=field.form.name;';
        }
        else {
            $beforeclickCall .= 'var formName="' . $formName . '";';
        }
        $beforeclickCall .=
            'var el=foswiki.Form.getFormElement(formName, "' 
          . $name
          . '"); foswiki.Form.initBeforeFocusText(el,"'
          . $beforeclick . '");';
        $beforeclickCall .= '</script>';
        $javascriptCalls .= $beforeclickCall;
    }

    $format =~ s/(\$e\b)/$1$javascriptCalls/go;

    my $mandatoryParam = $params->{'mandatory'};
    my $isMandatory = isTrue( $mandatoryParam, 0 );
    my $mandatory =
      $isMandatory ? _wrapHtmlMandatoryContainer($MANDATORY_STRING) : '';

    my $validationTypeParam = $params->{'validate'};
    my $validationType =
      $validationTypeParam ? $REQUIRED_TYPE_TABLE{$validationTypeParam} : '';
    if ( !$validationTypeParam && $mandatoryParam ) {
        $validationType = 's';    # non-empty
    }
    if ($validationType) {
        my $validate = '=' . $validationType;
        my $multiple = $MULTIPLE_TYPES{$type} ? $MULTIPLE_TAG_ID : '';
        $format .= "\n"
          . CGI::hidden(
            -name    => $VALIDATE_TAG . '_' . $name,
            -default => "$name$validate$multiple"
          );
    }

    my $conditionParam = $params->{'condition'};
    if ($conditionParam) {
        $conditionParam =~ m/^\$(.*)?\=(.*)$/go;
        my $conditionReferencedField = $1;
        my $conditionValue           = $2;
        my $conditionType =
          $conditionValue ? $CONDITION_TYPE_TABLE{$conditionValue} : '';
        if ($conditionType) {
            my $condition = '=' . $conditionType;
            $format .= "\n"
              . CGI::hidden(
                -name    => $CONDITION_TAG . '_' . $name,
                -default => "$conditionReferencedField$condition"
              );
        }
    }

    my $title = $params->{'title'} || '';
    my $hint  = $params->{'hint'}  || '';

    $title = _wrapHtmlTitleContainer($title) if $title;

    my $titleformat = $params->{'titleformat'} || $defaultTitleFormat;
    $format =~ s/\$titleformat/$titleformat/go if $title;
    $format =~ s/\$e\b/$element/go;
    $format =~ s/\$t\b/$title/go;
    $format =~ s/\$m\b/$mandatory/go;

    return $format if ( $type eq 'hidden' );    # do not draw any more html

    $hint = _wrapHtmlHintContainer($hint) if $hint;
    $format =~ s/\$h\b/$hint/go;
    my $hintCssClass = $hint ? ' ' . $ELEMENT_GROUP_HINT_CSS_CLASS : '';
    $format =~ s/\$_h/$hintCssClass/go;

    # clean up tokens if no title
    $format =~ s/\$titleformat//go;
    $format = _renderFormattingTokens($format);

    if ($elementcssclass) {

        # not for hidden classes, but these are returned earlier in sub
        my $classAttr = ' class="' . $elementcssclass . '"';
        $format = '<div class="' . $elementcssclass . '">' . $format . '</div>';
    }

    # error?
    my %formStatus = _status( $currentForm{'name'} );
    if ( $formStatus{$STATUS_ERROR} && $name && $errorFields{$name} ) {
        $format = _wrapHtmlErrorContainer($format);
    }

    # add anchor so individual fields can be targeted from any
    # error feedback
    $format = '<a name="' . _anchorLink($name) . '"></a>' . "\n" . $format;

    return $format;
}

=pod

=cut

sub _getFormElementHtml {
    my ( $session, $params, $topic, $web ) = @_;

    my $name           = $params->{'name'} || '';
    my $type           = $params->{'type'};
    my $hasMultiSelect = $type =~ m/^(.*?)multi$/;
    $type =~ s/^(.*?)multi$/$1/;
    my $value =
         $params->{'default'}
      || $params->{'value'}
      || $params->{'buttonlabel'};

    my $size = $params->{'size'} || ( $type eq 'date' ? '15' : '40' );
    my $maxlength = $params->{'maxlength'};
    $size = $maxlength if defined $maxlength && $maxlength < $size;

    my ( $options, $labels ) =
      _parseOptions( $params->{'options'}, $params->{'labels'} );

    my $itemformat = $params->{'fieldformat'};
    my $cssClass = $params->{'cssclass'} || '';
    $cssClass = _normalizeCssClassName($cssClass);

    my $selectedoptions = $params->{'default'} || undef;
    my $isMultiple = $MULTIPLE_TYPES{$type};
    if ($isMultiple) {
        my @values = param($name);
        $selectedoptions ||= join( ",", @values );
    }
    else {
        $selectedoptions ||= param($name);
    }

    my $disabled = $params->{'disabled'} ? 'disabled' : undef;
    my $readonly = $params->{'readonly'} ? 'readonly' : undef;

    my ( $onFocus, $onBlur, $onClick, $onChange, $onSelect, $onMouseOver,
        $onMouseOut, $onKeyUp );
    my $beforeclick = $params->{'beforeclick'};
    if ($beforeclick) {
        $value   = $beforeclick;
        $onFocus = 'foswiki.Form.clearBeforeFocusText(this)';
        $onBlur  = 'foswiki.Form.restoreBeforeFocusText(this)';

        # additional init function in _formElement
    }

    $onFocus     ||= $params->{'onFocus'};
    $onBlur      ||= $params->{'onBlur'};
    $onClick     ||= $params->{'onClick'};
    $onChange    ||= $params->{'onChange'};
    $onSelect    ||= $params->{'onSelect'};
    $onMouseOver ||= $params->{'onMouseOver'};
    $onMouseOut  ||= $params->{'onMouseOut'};
    $onKeyUp     ||= $params->{'onKeyUp'};

    my %extraAttributes = ();
    $extraAttributes{'class'}    = $cssClass if $cssClass;
    $extraAttributes{'disabled'} = $disabled if $disabled;
    $extraAttributes{'readonly'} = $readonly if $readonly;

    # javascript parameters
    $extraAttributes{'-onFocus'}     = $onFocus     if $onFocus;
    $extraAttributes{'-onBlur'}      = $onBlur      if $onBlur;
    $extraAttributes{'-onClick'}     = $onClick     if $onClick;
    $extraAttributes{'-onChange'}    = $onChange    if $onChange;
    $extraAttributes{'-onSelect'}    = $onSelect    if $onSelect;
    $extraAttributes{'-onMouseOver'} = $onMouseOver if $onMouseOver;
    $extraAttributes{'-onMouseOut'}  = $onMouseOut  if $onMouseOut;
    $extraAttributes{'onkeyup'}      = $onKeyUp     if $onKeyUp;

    my $element = '';
    if ( $type eq 'text' ) {
        $element =
          _getTextFieldHtml( $session, $name, $value, $size, $maxlength,
            %extraAttributes );
    }
    elsif ( $type eq 'password' ) {
        $element =
          _getPasswordFieldHtml( $session, $name, $value, $size, $maxlength,
            %extraAttributes );
    }
    elsif ( $type eq 'upload' ) {
        $element = _getUploadHtml( $session, $name, 'starting value',
            $size, $maxlength, %extraAttributes );
    }
    elsif ( $type eq 'submit' ) {
        $element =
          _getSubmitButtonHtml( $session, $name, $value, %extraAttributes );
    }
    elsif ( $type eq 'radio' ) {
        $element = _getRadioButtonGroupHtml( $session, $name, $options, $labels,
            $selectedoptions, $itemformat, %extraAttributes );
    }
    elsif ( $type eq 'checkbox' ) {
        $element =
          _getCheckboxButtonGroupHtml( $session, $name, $options, $labels,
            $selectedoptions, $itemformat, %extraAttributes );
    }
    elsif ( $type eq 'select' ) {
        $element =
          _getSelectHtml( $session, $name, $options, $labels, $selectedoptions,
            $size, $hasMultiSelect, %extraAttributes );
    }
    elsif ( $type eq 'dropdown' ) {

        # just a select box with size of 1 and no multiple
        $element =
          _getSelectHtml( $session, $name, $options, $labels, $selectedoptions,
            '1', undef, %extraAttributes );
    }
    elsif ( $type eq 'textarea' ) {
        my $rows = $params->{'rows'};
        my $cols = $params->{'cols'};
        $element = _getTextareaHtml( $session, $name, $value, $rows, $cols,
            %extraAttributes );
    }
    elsif ( $type eq 'hidden' ) {
        $element = _getHiddenHtml( $session, $name, $value );
    }
    elsif ( $type eq 'date' ) {
        my $dateFormat = $params->{'dateformat'};
        $element =
          _getDateFieldHtml( $session, $name, $value, $size, $maxlength,
            $dateFormat, %extraAttributes );
    }
    return $element;
}

=pod

=cut

sub _anchorLink {
    my ($name) = @_;

    my $anchorName = $name || '';
    $anchorName =~ s/[[:punct:][:space:]]//go;
    return $ELEMENT_ANCHOR_NAME . $anchorName;
}

=pod

=cut

sub _parseOptions {
    my ( $inOptions, $inLabels ) = @_;

    return ( '', '' ) if !$inOptions;

    my @optionPairs = split( /\s*,\s*/, $inOptions ) if $inOptions;
    my @optionList;
    my @labelList;
    foreach my $item (@optionPairs) {
        my $label;
        if ( $item =~ m/^(.*?[^\\])=(.*)$/ ) {
            ( $item, $label ) = ( $1, $2 );
        }
        $item =~ s/\\=/=/g;
        push( @optionList, $item );
        push( @labelList, $label ) if $label;
    }
    my $options = join( ",", @optionList );
    my $labels  = join( ",", @labelList );

    $labels ||= $inLabels;

    return ( $options, $labels );
}

=pod

=cut

sub _renderFormattingTokens {
    my ($text) = @_;

    $text =~ s/\$nop//go;
    $text =~ s/\$n/\n/go;
    $text =~ s/\$percnt/%/go;
    $text =~ s/\$dollar/\$/go;
    $text =~ s/\$quot/\"/go;

    return $text;
}

=pod

=cut

sub _getTextFieldHtml {
    my ( $session, $name, $value, $size, $maxlength, %extraAttributes ) = @_;

    my %attributes = _textfieldAttributes(@_);

    return CGI::textfield(%attributes);
}

=pod

=cut

sub _getPasswordFieldHtml {
    my ( $session, $name, $value, $size, $maxlength, %extraAttributes ) = @_;

    my %attributes = _textfieldAttributes(@_);
    return CGI::password_field(%attributes);
}

=pod

=cut

sub _getUploadHtml {
    my ( $session, $name, $value, $size, $maxlength, %extraAttributes ) = @_;

    my %attributes = _textfieldAttributes(@_);
    return CGI::filefield(%attributes);
}

=pod

=cut

sub _textfieldAttributes {
    my ( $session, $name, $value, $size, $maxlength, %extraAttributes ) = @_;

    my %attributes = (
        -name      => $name,
        -value     => $value,
        -size      => $size,
        -maxlength => $maxlength
    );
    %attributes = ( %attributes, %extraAttributes );

    my $cssClass = $attributes{'class'} || '';
    $cssClass = 'twikiInputFieldDisabled'
      if ( !$cssClass && $attributes{'disabled'} );
    $cssClass = 'twikiInputFieldReadOnly'
      if ( !$cssClass && $attributes{'readonly'} );
    $cssClass ||= 'twikiInputField';
    $cssClass = _normalizeCssClassName($cssClass);
    $attributes{'class'} = $cssClass if $cssClass;

    return %attributes;
}

=pod

=cut

sub _getHiddenHtml {
    my ( $session, $name, $value ) = @_;

    return CGI::hidden( -name => $name, -value => $value );
}

=pod

=cut

sub _getSubmitButtonHtml {
    my ( $session, $name, $value, %extraAttributes ) = @_;

    my $id = $name || undef;

    my %attributes = (
        -name  => $name,
        -value => $value
    );
    %attributes = ( %attributes, %extraAttributes );

    my $cssClass = $attributes{'class'} || '';
    $cssClass = 'twikiSubmitDisabled'
      if ( !$cssClass && $attributes{'disabled'} );
    $cssClass ||= 'twikiSubmit';
    $cssClass = _normalizeCssClassName($cssClass);
    $attributes{'class'} = $cssClass if $cssClass;
    return CGI::submit(%attributes);
}

=pod

=cut

sub _getTextareaHtml {
    my ( $session, $name, $value, $rows, $cols, %extraAttributes ) = @_;

    my %attributes = (
        -name    => $name,
        -default => $value,
        -rows    => $rows,
        -columns => $cols
    );
    %attributes = ( %attributes, %extraAttributes );

    my $cssClass = $attributes{'class'} || '';
    $cssClass = 'twikiInputFieldDisabled'
      if ( !$cssClass && $attributes{'disabled'} );
    $cssClass = 'twikiInputFieldReadOnly'
      if ( !$cssClass && $attributes{'readonly'} );
    $cssClass ||= 'twikiInputField';
    $cssClass = _normalizeCssClassName($cssClass);
    $attributes{'class'} = $cssClass if $cssClass;

    return CGI::textarea(%attributes);
}

=pod

=cut

sub _getCheckboxButtonGroupHtml {
    my ( $session, $name, $options, $labels, $selectedoptions, $itemformat,
        %extraAttributes )
      = @_;

    my @optionList = split( /\s*,\s*/, $options ) if $options;
    $labels = $options if !$labels;
    my @selectedValueList = split( /\s*,\s*/, $selectedoptions )
      if $selectedoptions;
    my @labelList = split( /\s*,\s*/, $labels ) if $labels;
    my %labels;
    @labels{@optionList} = @labelList if @labelList;

    # ideally we would use CGI::checkbox_group, but this does not
    # generate the correct labels
    # my @checkboxes = CGI::checkbox_group(-name=>$name,
    #                            -values=>\@optionList,
    #                            -default=>\@selectedValueList,
    #                            -linebreak=>'false',
    #                            -labels=>\%labels);

    # so we roll our own while keeping the same interface
    my %attributes = (
        -name      => $name,
        -values    => \@optionList,
        -default   => \@selectedValueList,
        -linebreak => 'false',
        -labels    => \%labels
    );
    %attributes = ( %attributes, %extraAttributes );

    my $cssClass = $attributes{'class'} || '';
    $cssClass = 'twikiCheckbox ' . $cssClass;
    $cssClass = _normalizeCssClassName($cssClass);
    $attributes{'-class'} = $cssClass if $cssClass;

    my @items = _checkbox_group(%attributes);

    return _wrapHtmlGroupContainer(
        _mapToItemFormatString( \@items, $itemformat ) );
}

=pod

=cut

sub _checkbox_group {
    my (%options) = @_;

    $options{-type} = 'checkbox';
    return _group(%options);
}

=pod

=cut

sub _getRadioButtonGroupHtml {
    my ( $session, $name, $options, $labels, $selectedoptions, $itemformat,
        %extraAttributes )
      = @_;

    return "" if !$options;
    my @optionList = split( /\s*,\s*/, $options ) if $options;
    $labels = $options if !$labels;
    my @selectedValueList = split( /\s*,\s*/, $selectedoptions )
      if $selectedoptions;
    my @labelList = split( /\s*,\s*/, $labels ) if $labels;
    my %labels;
    @labels{@optionList} = @labelList if @labelList;
    my %attributes = (
        -name      => $name,
        -values    => \@optionList,
        -default   => \@selectedValueList,
        -linebreak => 'false',
        -labels    => \%labels
    );
    %attributes = ( %attributes, %extraAttributes );

    my $cssClass = $attributes{'class'} || '';
    $cssClass = 'twikiInputFieldDisabled'
      if ( !$cssClass && $attributes{'disabled'} );
    $cssClass = 'twikiRadioButton ' . $cssClass;
    $cssClass = _normalizeCssClassName($cssClass);
    $attributes{'-class'} = $cssClass if $cssClass;

    my @items = _radio_group(%attributes);
    return _wrapHtmlGroupContainer(
        _mapToItemFormatString( \@items, $itemformat ) );
}

=pod

=cut

sub _radio_group {
    my (%options) = @_;

    { $options{-type} = 'radio' };
    return _group(%options);
}

=pod

=cut

sub _mapToItemFormatString {
    my ( $list, $itemformat ) = @_;

    my $format = $itemformat || '$e';
    my $str = join "\n", map {
        my $formatted = $format;
        $formatted =~ s/\$e/$_/go;
        $_ = $formatted;
        $_;
    } @$list;
    return $str;
}

=pod

=cut

sub _getSelectHtml {
    my ( $session, $name, $options, $labels, $selectedoptions, $size,
        $hasMultiSelect, %extraAttributes )
      = @_;

    my @optionList = split( /\s*,\s*/, $options ) if $options;
    $labels = $options if !$labels;
    my @selectedValueList = split( /\s*,\s*/, $selectedoptions )
      if $selectedoptions;
    my @labelList = split( /\s*,\s*/, $labels ) if $labels;
    my %labels;
    @labels{@optionList} = @labelList if @labelList;

    my $multiple = $hasMultiSelect ? 'true' : undef;
    my %attributes = (
        -name     => $name,
        -values   => \@optionList,
        -default  => \@selectedValueList,
        -labels   => \%labels,
        -size     => $size,
        -multiple => $multiple
    );
    %attributes = ( %attributes, %extraAttributes );

    my $cssClass = $attributes{'class'} || '';
    $cssClass = 'twikiSelectDisabled'
      if ( !$cssClass && $attributes{'disabled'} );
    $cssClass = 'twikiSelect ' . $cssClass;
    $cssClass = _normalizeCssClassName($cssClass);
    $attributes{'-class'} = $cssClass if $cssClass;

    my @items = CGI::scrolling_list(%attributes);
    return _mapToItemFormatString( \@items );
}

=pod

=cut

sub _getDateFieldHtml {
    my ( $session, $name, $value, $size, $maxlength, $dateFormat,
        %extraAttributes )
      = @_;

    my %attributes =
      _textfieldAttributes( $session, $name, $value, $size, $maxlength,
        %extraAttributes );
    my $id = $attributes{'id'} || 'cal' . $currentForm{'name'} . $name;
    $attributes{'id'} |= $id;

    my $text = CGI::textfield(%attributes);

    eval 'use TWiki::Contrib::JSCalendarContrib';
    {
        if ($@) {
            my $mess = "WARNING: JSCalendar not installed: $@";
            print STDERR "$mess\n";
            TWiki::Func::writeWarning($mess);
        }
        else {
            TWiki::Contrib::JSCalendarContrib::addHEAD('twiki');

            my $format =
                 $dateFormat
              || $TWiki::cfg{JSCalendarContrib}{format}
              || "%e %B %Y";

            $text .= ' <span class="twikiMakeVisible">';
            my $control = CGI::image_button(
                -class   => 'editTableCalendarButton',
                -name    => 'calendar',
                -onclick => "return showCalendar('$id','$format')",
                -src     => TWiki::Func::getPubUrlPath() . '/'
                  . TWiki::Func::getTwikiWebname()
                  . '/JSCalendarContrib/img.gif',
                -alt   => 'Calendar',
                -align => 'middle'
            );

            #fix generated html
            $control =~ s/MIDDLE/middle/go;
            $text .= $control;
            $text .= '</span>';
        }
    };
    return $text;
}

=pod

=cut

sub _group {
    my (%options) = @_;

    my $type       = $options{-type};
    my $name       = $options{-name};
    my $size       = $options{-size};
    my $values     = $options{-values};
    my $default    = $options{-default};
    my %defaultSet = map { $_ => 1 } @$default;

    my $labels    = $options{-labels};
    my $linebreak = $options{-linebreak};

    my $optionFormat   = '';
    my $selectedFormat = '';
    if ( $type eq 'radio' ) {
        $optionFormat = '<input $attributes /><label for="$id">$label</label>';
        $selectedFormat = 'checked="checked"';
    }
    elsif ( $type eq 'checkbox' ) {
        $optionFormat = '<input $attributes /><label for="$id">$label</label>';
        $selectedFormat = 'checked="checked"';
    }
    elsif ( $type eq 'select' ) {
        $optionFormat   = '<option $attributes>$label</option>';
        $selectedFormat = 'selected="selected"';
    }
    my $disabledFormat = $options{-disabled} ? ' disabled="disabled"' : '';
    my $readonlyFormat = $options{-readonly} ? ' readonly="readonly"' : '';
    my $cssClassFormat =
      $options{-class} ? ' class="' . $options{-class} . '"' : '';

    my $scriptFormat = '';
    $scriptFormat .= ' onclick="' . $options{-onClick} . '" '
      if $options{-onClick};
    $scriptFormat .= ' onfocus="' . $options{-onFocus} . '" '
      if $options{-onFocus};
    $scriptFormat .= ' onblur="' . $options{-onBlur} . '" '
      if $options{-onBlur};
    $scriptFormat .= ' onchange="' . $options{-onChange} . '" '
      if $options{-onChange};
    $scriptFormat .= ' onselect="' . $options{-onSelect} . '" '
      if $options{-onSelect};
    $scriptFormat .= ' onmouseover="' . $options{-onMouseOver} . '" '
      if $options{-onMouseOver};
    $scriptFormat .= ' onmouseout="' . $options{-onMouseOut} . '" '
      if $options{-onMouseOut};

    my @elements;
    foreach (@$values) {
        my $value = $_;
        my $label = $labels->{$value};

        my %attributes = ();
        if ( $type eq 'radio' || $type eq 'checkbox' ) {
            $attributes{'type'} = $type;
        }
        if ( $type eq 'radio' || $type eq 'checkbox' ) {
            $attributes{'name'} = $name;
        }
        $attributes{'value'} = $value;
        my $id = $name . '_' . $value;    # use group name to prevent doublures
        $id =~ s/ /_/go;
        $attributes{'id'} = $id;
        my $attributeString = _getAttributeString(%attributes);

        my $selected = '';
        $selected = $selectedFormat if $defaultSet{$value};

        my $selectedAttributeString =
"$attributeString $selected $disabledFormat $readonlyFormat $scriptFormat $cssClassFormat";
        $selectedAttributeString =~ s/ +/ /go;    # remove extra spaces

        my $element = $optionFormat;
        $element =~ s/\$attributes/$selectedAttributeString/go;
        $element =~ s/\$label/$label/go;
        $element =~ s/\$id/$id/go;

        push( @elements, $element );
    }

    return @elements;
}

=pod

=cut

sub _normalizeCssClassName {
    my ($cssString) = @_;
    return '' if !$cssString;
    $cssString =~ s/^\s*(.*?)\s*$/$1/go;    # strip surrounding spaces
    $cssString =~ s/\s+/ /go;               # remove double spaces
    return $cssString;
}

=pod

=cut

sub _getAttributeString {
    my (%attributes) = @_;

    my @propertyList = map "$_=\"$attributes{$_}\"", sort keys %attributes;
    return join( " ", @propertyList );
}

=pod

=cut

sub _wrapHtmlError {
    my ($text) = @_;

    my $errorIconUrl = "%PUBURL%/%SYSTEMWEB%/FormPlugin/error.gif";
    my $errorIconImgTag =
      '<img src="' . $errorIconUrl . '" alt="" width="16" height="16" />';
    return
        "#$NOTIFICATION_ANCHOR_NAME\n"
      . '<div id="'
      . $ERROR_CSS_CLASS
      . '" class="'
      . $NOTIFICATION_CSS_CLASS . '">'
      . $errorIconImgTag
      . $text
      . '</div>' . "\n";
}

=pod

=cut

sub _wrapHtmlGroupContainer {
    my ($text) = @_;

    return
        '<fieldset class="'
      . $ELEMENT_GROUP_CSS_CLASS . '$_h">'
      . $text
      . '</fieldset>';
}

=pod

=cut

sub _wrapHtmlErrorContainer {
    my ($text) = @_;

    return '<div class="' . $ERROR_CSS_CLASS . '">' . $text . '</div>';
}

=pod

=cut

sub _wrapHtmlTitleContainer {
    my ($text) = @_;

    return '<span class="' . $TITLE_CSS_CLASS . '">' . $text . '</span>';
}

=pod

=cut

sub _wrapHtmlHintContainer {
    my ($text) = @_;

    return '<span class="' . $HINT_CSS_CLASS . '">' . $text . '</span>';
}

=pod

=cut

sub _wrapHtmlMandatoryContainer {
    my ($text) = @_;

    return '<span class="' . $MANDATORY_CSS_CLASS . '">' . $text . '</span>';
}

=pod

Shorthand function call.

=cut

sub _debug {
    TWiki::Func::writeDebug(@_);
}

=pod

Copied from TWiki.pm. Interface is available in Func.pm but is too new yet.

=cut

sub isTrue {
    my ( $value, $default ) = @_;

    $default ||= 0;

    return $default unless defined($value);

    $value =~ s/^\s*(.*?)\s*$/$1/gi;
    $value =~ s/off//gi;
    $value =~ s/no//gi;
    $value =~ s/false//gi;
    return ($value) ? 1 : 0;
}

=pod

Creates a url param string from POST data.

=cut

sub _postDataToUrlParamString {
    my $out   = '';
    my $query = TWiki::Func::getCgiQuery();
    my @names = $query->param;
    foreach (@names) {
        my $name = $_;
        next if !$name;
        $out .= ';' if $out;
        my $value = $query->param($name);
        $value = _urlEncode($value);
        $out .= "$name=" . $value;
    }
    return $out;
}

=pod

Copied from TWiki.pm

=cut

sub _urlEncode {
    my $text = shift;

    $text =~ s/([^0-9a-zA-Z-_.:~!*'()\/%])/'%'.sprintf('%02x',ord($1))/ge;

    return $text;
}
1;
