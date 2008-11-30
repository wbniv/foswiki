#
# Copyright (C) 2004 Crawford Currie, http://c-dot.co.uk
#
# TWiki plugin-in module for Form Query Plugin
#
package TWiki::Plugins::FormQueryPlugin;

use strict;

use TWiki;
use TWiki::Func;
use TWiki::Attrs;
use Error qw( :try );
use Assert;

use vars qw(
            $web $topic $user $installWeb $VERSION $RELEASE
            %db $initialised $moan $quid
           );

$VERSION = '$Rev: 13528 $';
$RELEASE = 'TWiki-4';
$quid = 0;

$initialised = 0; # flag whether _lazyInit has been called
%db = (); # hash of loaded DBs, keyed on web name

sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    TWiki::Func::registerTagHandler(
        'FQPDEBUG',
        \&_FQPDEBUG,
        'context-free' );
    TWiki::Func::registerTagHandler(
        'DOANDSHOWQUERY',
        \&_DOQUERY, # Deprecated
        'context-free' );
    TWiki::Func::registerTagHandler(
        'DOQUERY',
        \&_DOQUERY,
        'context-free' );
    TWiki::Func::registerTagHandler(
        'FORMQUERY',
        \&_FORMQUERY,
        'context-free' );
    TWiki::Func::registerTagHandler(
        'SUMFIELD',
        \&_SUMFIELD,
        'context-free' );
    TWiki::Func::registerTagHandler(
        'MATCHCOUNT',
        \&_MATCHCOUNT,
        'context-free' );
    TWiki::Func::registerTagHandler(
        'TABLEFORMAT',
        \&_TABLEFORMAT,
        'context-free' );
    TWiki::Func::registerTagHandler(
        'SHOWQUERY',
        \&_SHOWQUERY,
        'context-free' );
    TWiki::Func::registerTagHandler(
        'QUERYTOCALC',
        \&_QUERYTOCALC,
        'context-free' );
    TWiki::Func::registerTagHandler(
        'SHOWCALC',
        \&_SHOWCALC,
        'context-free' );

    return 1;
}

sub _moan {
    my( $tag, $attrs, $mess ) = @_;
    my $whinge = $moan || 'on';
    $whinge = $attrs->{moan} if defined $attrs->{moan};
    if( lc( $whinge ) eq 'on' ) {
        return CGI::span({class => 'foswikiAlert'},
                         '%<nop>'.$tag.'{'.$attrs->stringify()."}% :$mess");
    }
    return '';
}

sub _original {
    my( $macro, $params ) = @_;
    return _moan($macro, $params, "Plugin initialisation failed");
}

sub _FQPDEBUG {
    return _original( 'FQPINFO', $_[1] ) unless ( _lazyInit() );

    my($session, $attrs, $topic, $web) = @_;

    my $limit = $attrs->{limit};
    $limit = undef if ($limit && $limit eq 'all');

    my $result;
    try {
        my $name = $attrs->{query};
        if ( $name ) {
            $result = TWiki::Plugins::FormQueryPlugin::WebDB::getQueryInfo(
                $name, $limit );
        } else {

            my $webName = $attrs->{web} || $web;

            if ( _lazyCreateDB($webName) ) {
                $result = $db{$webName}->getTopicInfo(
                    $attrs->{topic},
                    $attrs->{limit} );
            } else {
                $result = _original( 'FQPINFO', $_[1] );
            }
        }
    } catch Error::Simple with {
        $result = _moan( 'FQPINFO', $attrs, shift->{-text} );
        die $result if DEBUG;
    };
    return $result;
}

sub _DOQUERY {

    return _original( 'DOQUERY', $_[1] ) unless ( _lazyInit() );

    my($session, $attrs, $topic, $web) = @_;

    my $webName;
    my $result = '';
    try {
        my $casesensitive = $attrs->{casesensitive} || "0";
        $casesensitive = 0 if( $casesensitive =~ /^off$/oi );
        my $string = $attrs->{search};
        $string = $attrs->{"_DEFAULT"} unless $string;

        $webName = $attrs->{web} || $web;
        my @webs = split( /,\s*/, $webName );

        foreach $webName ( @webs ) {
            if ( _lazyCreateDB($webName) ) {
                # This should be done more efficiently, don't copy...
                $db{$webName}->formQueryOnDB(
                    '__query__'.$quid,
                    $string,
                    $attrs->{extract},
                    $casesensitive,
                    1 );

                $result .= TWiki::Plugins::FormQueryPlugin::WebDB::showQuery(
                    '__query__'.$quid,
                    $attrs->{format},
                    $attrs,
                    $topic, $web, $user, $installWeb );
                $quid++;
            } else {
                $result .= _original( 'DOANDSHOWQUERY', $_[1] );
            }
        }
    } catch Error::Simple with {
        $result = _moan( 'DOQUERY', $attrs, shift->{-text} );
    };
    return $result;

}

sub _FORMQUERY {
    return _original( 'FORMQUERY', $_[1] ) unless ( _lazyInit() );

    my($session, $attrs, $topic, $web) = @_;

    my $query = $attrs->{query};
    my $casesensitive = $attrs->{casesensitive} || "0";
    $casesensitive = 0 if( $casesensitive =~ /^off$/oi );
    my $string = $attrs->{search};
    $string = $attrs->{"_DEFAULT"} || "" unless $string;

    my $result = '';
    try {
        if ( $query ) {
            $result = TWiki::Plugins::FormQueryPlugin::WebDB::formQueryOnQuery(
                $attrs->{name},
                $string,
                $query,
                $attrs->{extract},
                $casesensitive );
        } else {
            my $webName = $attrs->{web} || $web;
            my @webs = split /,\s*/, $webName;

            my $result;
            foreach $webName ( @webs ) {
                if ( _lazyCreateDB($webName) ) {
                    # This should be done more efficiently, don't copy every time...
                    $result .= $db{$webName}->formQueryOnDB(
                        $attrs->{name},
                        $string,
                        $attrs->{extract},
                        $casesensitive,
                        1 );
                } else {
                    $result .= _original( 'FORMQUERY', $_[1] );
                }
            }
        }
    } catch Error::Simple with {
        $result = _moan( 'FORMQUERY', $attrs, shift->{-text} );
    };
    return $result;
}

sub _TABLEFORMAT {
    return _original( 'TABLEFORMAT', $_[1] ) unless ( _lazyInit() );

    my($session, $attrs, $topic, $web) = @_;

    my $result;
    try {
        $result = TWiki::Plugins::FormQueryPlugin::WebDB::tableFormat(
						$attrs->{name},
						$attrs->{format},
						$attrs );
    } catch Error::Simple with {
        $result = _moan( 'TABLEFORMAT', $attrs, shift->{-text} );
    };
    return $result;
}

sub _SHOWQUERY {
    return _original( 'SHOWQUERY', $_[1] ) unless ( _lazyInit() );

    my($session, $attrs, $topic, $web) = @_;

    my $result;
    try {
        $result = TWiki::Plugins::FormQueryPlugin::WebDB::showQuery(
            $attrs->{query},
            $attrs->{format},
            $attrs,
            $topic, $web, $user, $installWeb);
    } catch Error::Simple with {
        $result = _moan( 'SHOWQUERY', $attrs, shift->{-text} );
    };
    return $result;
}

sub _QUERYTOCALC {
    return _original( 'QUERYTOCALC', $_[1] ) unless ( _lazyInit() );

    my($session, $attrs, $topic, $web) = @_;

    my $result;
    try {
        $result = TWiki::Plugins::FormQueryPlugin::WebDB::toTable(
            $attrs->{query},
            $attrs->{format},
            $attrs,
            $topic, $web, $user, $installWeb);
    } catch Error::Simple with {
        $result = _moan( 'QUERYTOCALC', $attrs, shift->{-text} );
    };
    return $result;
}

sub _SHOWCALC {
    return _original( 'SHOWCALC', $_[1] ) unless ( _lazyInit() );

    my($session, $attrs, $topic, $web) = @_;

    my $calcline = $attrs->{"_DEFAULT"};

    # Not required but for safety, as we are not in the table...
    $TWiki::Plugins::SpreadSheetPlugin::cPos = -1;

    my $result;
    try {
        $result = TWiki::Plugins::SpreadSheetPlugin::Calc::doCalc($calcline);
    } catch Error::Simple with {
        $result = _moan( 'SHOWCALC', $attrs, shift->{-text} );
    };
    return $result;
}

sub _SUMFIELD {
    return _original( 'SUMFIELD', $_[1] ) unless ( _lazyInit() );

    my($session, $attrs, $topic, $web) = @_;

    my $result;
    try {
        $result = TWiki::Plugins::FormQueryPlugin::WebDB::sumQuery(
            $attrs->{query},
            $attrs->{field} );
    } catch Error::Simple with {
        $result = _moan( 'SUMFIELD', $attrs, shift->{-text} );
    };
    return $result;
}

sub _MATCHCOUNT {
    return _original( 'MATCHCOUNT', $_[1] ) unless ( _lazyInit() );

    my($session, $attrs, $topic, $web) = @_;

    my $result;
    try {
        $result = TWiki::Plugins::FormQueryPlugin::WebDB::matchCount(
					       $attrs->{query} );
    } catch Error::Simple with {
        $result = _moan( 'MATCHCOUNT', $attrs,shift->{-text});
    };
    return $result;
}

sub _lazyInit {

    # Problem: %SEARCH% with scope=text changes the current directory, thus 
    # the subsequent loads do not work.

    return 1 if ( $initialised );

    # FQP_ENABLE must be set globally or in this web!
    return 0 unless TWiki::Func::getPreferencesFlag(
        "FORMQUERYPLUGIN_ENABLE" );

    # Check for diagostic output
    $moan = TWiki::Func::getPreferencesValue( "FORMQUERYPLUGIN_MOAN" );

    require TWiki::Plugins::FormQueryPlugin::WebDB;
    die $@ if $@;

    $initialised = 1;

    return 1;

}

sub _lazyCreateDB {
    my ( $webName ) = @_;

    return 1 if $db{$webName};

    $db{$webName} = new TWiki::Plugins::FormQueryPlugin::WebDB( $webName );

    return 0 unless ref($db{$webName});

    return 1;
}

1;
