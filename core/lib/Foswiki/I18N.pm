# Module of Foswiki - The Free Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 1999-2008 Foswiki Contributors.
# All Rights Reserved. Foswiki Contributors
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
# As per the GPL, removal of this notice is prohibited.

=pod

---+ package Foswiki::I18N

Support for strings translation and language detection.

=cut

package Foswiki::I18N;

use strict;
use Assert;

use vars qw( $initialised @initErrors );

=pod

---++ ClassMethod available_languages

Lists languages tags for languages available at Foswiki installation. Returns a
list containing the tags of the available languages.

__Note__: the languages available to users are determined in the =configure=
interface.

=cut

sub available_languages {

    my @available;

    while ( my ( $langCode, $langOptions ) = each %{ $Foswiki::cfg{Languages} } )
    {
        if ( $langOptions->{Enabled} ) {
            push( @available, _normalize_language_tag($langCode) );
        }
    }

    return @available;
}

# utility function: normalize language tags like ab_CD to ab-cd
# also renove any character there is not a letter [a-z] or a hyphen.
sub _normalize_language_tag {
    my $tag = shift;
    $tag = lc($tag);
    $tag =~ s/\_/-/g;
    $tag =~ s/[^a-z-]//g;
    return $tag;
}

# initialisation block
BEGIN {

    # we only need to proceed if user wants internationalisation support
    return unless $Foswiki::cfg{UserInterfaceInternationalisation};

# no languages enabled is the same as disabling {UserInterfaceInternationalisation}
    my @languages = available_languages();
    return unless ( scalar(@languages) );

    # we first assume it's ok
    $initialised = 1;

    eval "use base 'Locale::Maketext'";
    if ($@) {
        $initialised = 0;
        push( @initErrors,
                "I18N: Couldn't load required perl module Locale::Maketext: " 
              . $@
              . "\nInstall the module or turn off {UserInterfaceInternationalisation}"
        );
    }

    unless ( $Foswiki::cfg{LocalesDir} && -e $Foswiki::cfg{LocalesDir} ) {
        push( @initErrors,
'I18N: {LocalesDir} not configured. Define it or turn off {UserInterfaceInternationalisation}'
        );
        $initialised = 0;
    }

    # dynamically build languages to be loaded according to admin-enabled
    # languages.
    my $dependencies = "use Locale::Maketext::Lexicon{'en'=>['Auto'],";
    foreach my $lang (@languages) {
        $dependencies .=
          "'$lang'=>['Gettext'=>'$Foswiki::cfg{LocalesDir}/$lang.po' ], ";
    }
    $dependencies .= '};';

    eval $dependencies;
    if ($@) {
        $initialised = 0;
        push( @initErrors,
"I18N - Couldn't load required perl module Locale::Maketext::Lexicon: "
              . $@
              . "\nInstall the module or turn off {UserInterfaceInternationalisation}"
        );
    }
}

=pod

---++ ClassMethod new ( $session )

Constructor. Gets the language object corresponding to the current users
language. If $session is not a Foswiki object reference, just calls
Local::Maketext::new (the superclass constructor)

=cut

sub new {
    my $class = shift;
    my ($session) = @_;

    unless ( ref($session) && $session->isa('Foswiki') ) {

        # it's recursive
        return $class->SUPER::new(@_);
    }

    unless ($initialised) {
        foreach my $error (@initErrors) {
            $session->writeWarning($error);
        }
    }

    # guesses the language from the CGI environment
    # TODO:
    #   web/user/session setting must override the language detected from the
    #   browser.
    my $this;
    if ($initialised) {
        $session->enterContext('i18n_enabled');
        my $userLanguage = _normalize_language_tag(
            $session->{prefs}->getPreferencesValue('LANGUAGE') );
        if ($userLanguage) {
            $this = Foswiki::I18N->get_handle($userLanguage);
        }
        else {
            $this = Foswiki::I18N->get_handle();
        }
    }
    else {
        require Foswiki::I18N::Fallback;

        $this = new Foswiki::I18N::Fallback();

        # we couldn't initialise 'optional' I18N infrastructure, warn that we
        # can only use English if I18N has been requested with configure
        $session->writeWarning(
            'Could not load I18N infrastructure; falling back to English')
          if $Foswiki::cfg{UserInterfaceInternationalisation};
    }

    # keep a reference to the session object
    $this->{session} = $session;

    # languages we know about
    $this->{enabled_languages} = { en => 'English' };
    $this->{checked_enabled} = undef;

    # what to do with failed translations (only needed when already initialised
    # and language is not English);
    if ( $initialised and ( $this->language ne 'en' ) ) {
        my $fallback_handle = Foswiki::I18N->get_handle('en');
        $this->fail_with(
            sub {
                shift;    # get rid of the handle
                return $fallback_handle->maketext(@_);
            }
        );
    }

    # finally! :-p
    return $this;
}

=begin TML

---++ ObjectMethod finish()
Break circular references.

=cut

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub finish {
    my $this = shift;
    undef $this->{enabled_languages};
    undef $this->{checked_enabled};
    undef $this->{session};
}

=pod

---++ ObjectMethod maketext( $text ) -> $translation

Translates the given string (assumed to be written in English) into the
current language, as detected in the constructor, and converts it into
the site charset.

Wraps around Locale::Maketext's maketext method, adding charset conversion and checking

Return value: translated string, or the argument itself if no translation is
found for thet argument.

=cut

sub maketext {
    my ( $this, $text, @args ) = @_;

    # these can be user-supplied data. They can be in {Site}{CharSet}. Convert
    # into "internal representation" as expected by Foswiki::I18N::maketext
    @args = map { $this->fromSiteCharSet($_) } @args;

    if ( $text =~ /^_/ && $text ne '_language_name' ) {
        require CGI;
        import CGI();

        return CGI::span(
            { -style => 'color:red;' },
            "Error: MAKETEXT argument's can't start with an underscore (\"_\")."
        );
    }

    my $result = $this->SUPER::maketext( $text, @args );
    if ( $result && $this->{session} ) {

        # external calls get the resultant text in the right charset:
        $result = $this->toSiteCharSet($result);
    }

    return $result;
}

=pod

---++ ObjectMethod language() -> $language_tag

Indicates the language tag of the current user's language, as detected from the
information sent by the browser. Returns the empty string if the language
could not be determined.

=cut

sub language {
    my $this = shift;

    return $this->language_tag();
}

=pod

---++ ObjectMethod enabled_languages() -> %languages

Returns an array with language tags as keys and language (native) names as
values, for all the languages enabled in this site. Useful for
listing available languages to the user.

=cut

sub enabled_languages {
    my $this = shift;

    unless ( $this->{checked_enabled} ) {
        _discover_languages($this);
    }

    $this->{checked_enabled} = 1;
    return $this->{enabled_languages};

}

# discovers the available language.
sub _discover_languages {
    my $this = shift;

    #use the cache, if available
    if ( open LANGUAGE, "<$Foswiki::cfg{LocalesDir}/languages.cache" ) {
        foreach my $line (<LANGUAGE>) {
            my ( $key, $name ) = split( '=', $line );
            chop($name);
            _add_language( $this, $key, $name );
        }
    }
    else {

#TODO: if the cache file don't exist, perhaps a warning should be issued to the logs?
        open LANGUAGE, ">$Foswiki::cfg{LocalesDir}/languages.cache";
        foreach my $tag ( available_languages() ) {
            my $h    = Foswiki::I18N->get_handle($tag);
            my $name = $h->maketext("_language_name");
            $name = $this->toSiteCharSet($name);
            _add_language( $this, $tag, $name );
            print LANGUAGE "$tag=$name\n";
        }
    }

    close LANGUAGE;
    $this->{checked_enabled} = 1;

}

=pod

---++ ObjectMethod fromSiteCharSet ( $text ) -> $encoded

This method receives =$text=, assumed to be encoded in {Site}{CharSet}, and
converts it to a internal representation.

Currently this representation will be a UTF-8 string, but this may change in
the future. This way, you can't assume any property on the returned value, and
should only use the returned value of this function as input to toSiteCharSet.
If you change the returnd value, either by removing, updating or appending
characters, be sure to touch only ASCII characters (i.e., characters that have
ord() less than 128).

=cut

sub fromSiteCharSet {
    my ( $this, $text ) = @_;

    return $text
      if ( !defined $Foswiki::cfg{Site}{CharSet}
        || $Foswiki::cfg{Site}{CharSet} =~ m/^utf-?8$/i );

    if ( $] < 5.008 ) {

        # use Unicode::MapUTF8 for Perl older than 5.8
        require Unicode::MapUTF8;
        my $encoding = $Foswiki::cfg{Site}{CharSet};
        if ( Unicode::MapUTF8::utf8_supported_charset($encoding) ) {
            return Unicode::MapUTF8::to_utf8(
                {
                    -string  => $text,
                    -charset => $encoding
                }
            );
        }
        else {
            $this->{session}
              ->writeWarning( 'Conversion from $encoding no supported, '
                  . 'or name not recognised - check perldoc Unicode::MapUTF8' );
            return $text;
        }
    }
    else {

        # good Perl version, just use Encode
        require Encode;
        import Encode;
        my $encoding = Encode::resolve_alias( $Foswiki::cfg{Site}{CharSet} );
        if ( not $encoding ) {
            $this->{session}->writeWarning( 'Conversion to "'
                  . $Foswiki::cfg{Site}{CharSet}
                  . '" not supported, or name not recognised - check '
                  . '"perldoc Encode::Supported"' );
            return undef;
        }
        else {
            my $octets =
              Encode::decode( $encoding, $text, &Encode::FB_PERLQQ() );
            return Encode::encode( 'utf-8', $octets );
        }
    }
}

=pod


---++ ObjectMethod toSiteCharSet ( $encoded ) -> $text

This method receives a string, assumed to be encoded in Foswiki's internal string
representation (as generated by the fromSiteCharSet method, and converts it
into {Site}{CharSet}.

When converting into {Site}{CharSet}, characters that are not present at that
charset are represented as HTML numerical character entities (NCR's), in the
format <code>&amp;#NNNN;</code>, where NNNN is the character's Unicode
codepoint.

See also: the =fromSiteCharSet= method.

=cut

sub toSiteCharSet {
    my ( $this, $encoded ) = @_;

    return $encoded
      if ( !defined $Foswiki::cfg{Site}{CharSet}
        || $Foswiki::cfg{Site}{CharSet} =~ m/^utf-?8$/i );

    if ( $] < 5.008 ) {

        # use Unicode::MapUTF8 for Perl older than 5.8
        require Unicode::MapUTF8;
        my $encoding = $Foswiki::cfg{Site}{CharSet};
        if ( Unicode::MapUTF8::utf8_supported_charset($encoding) ) {
            return Unicode::MapUTF8::from_utf8(
                {
                    -string  => $encoded,
                    -charset => $encoding
                }
            );
        }
        else {
            $this->{session}
              ->writeWarning( 'Conversion to $encoding no supported, '
                  . 'or name not recognised - check perldoc Unicode::MapUTF8' );
            return $encoded;
        }
    }
    else {
        require Encode;
        import Encode;
        my $encoding = Encode::resolve_alias( $Foswiki::cfg{Site}{CharSet} );
        if ( not $encoding ) {
            $this->{session}->writeWarning( 'Conversion from "'
                  . $Foswiki::cfg{Site}{CharSet}
                  . '" not supported, or name not recognised - check '
                  . '"perldoc Encode::Supported"' );
            return $encoded;
        }
        else {

            # converts to {Site}{CharSet}, generating HTML NCR's when needed
            my $octets = Encode::decode( 'utf-8', $encoded );
            return Encode::encode( $encoding, $octets, &Encode::FB_HTMLCREF() );
        }
    }
}

# private utility method: add a pair tag/language name
sub _add_language {
    my ( $this, $tag, $name ) = @_;
    ${ $this->{enabled_languages} }{$tag} = $name;
}

1;
