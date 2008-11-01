# /usr/bin/perl -w
use strict;

package TWiki::Plugins::OoPlugin;
use strict;
use vars qw( @ISA $VERSION $RELEASE );

use Exporter;

# This should always be $Rev: 7916 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 7916 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

@ISA = qw( Exporter );

sub whoami { (caller(1))[3] }

sub new
{
    my $classname = shift;
    my $self  = { };
    bless($self, $classname);
#    $self->_init( @_ );
    return $self;
}

sub DESTROY
{
    my $self = shift;
}

sub debug
{
    my ( $self, $val ) = @_;
    $self->{debug} = $val if defined( $val );
    return $self->{debug};
}

sub _init
{
    my $self = shift;
    if (@_) 
    {
	my %extra = @_;
	@$self{keys %extra} = values %extra;
    }

    $self->debug( $self->getPreferencesFlag( 'debug' ) );	# Get plugin debug flag

    die "name parameter required" unless $self->{name};
    $self->_name( $self->{name} );

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning( "Version mismatch between EmptyPlugin and Plugins.pm" );
        return 0;
    }

    $self->writeDebug( 'x' x 100 );
    # this installs the TWiki plugin subroutines (for which there are like functions in the derived class)
    #  into the symbol space of the plugin's module; note that this code will only work if the plugin class
    #  is directly derived from the base OoPlugin class
    # a _workaround_ would be to simple declare the commonTagsHandler, startRenderingHandler, etc.
    #  subroutines in your plugin module and insert the simple glue code $self->_commonTagsHandler( @_ ), etc.
    my @fns = qw( commonTagsHandler startRenderingHandler outsidePREHandler insidePREHandler endRenderingHandler );
    no strict 'refs';
    map { 
	my $fn = caller(1) . "::$_";
	my $meth = "_$_";
	my $full = caller(1) . "::$meth";
#	$self->writeDebug( "EmptyOoPlugin::_init( $full ), fn=[$fn]" );
	*{$fn} = sub { $self->$meth( @_ ) } if ( eval "defined &$full" );
    } @fns;
}

sub init_
{
    my $self = shift;
    $self->{web} ||= '';		# why is there sometimes no web variable?
    $self->writeDebug( "- TWiki::Plugins::$self->{name}Plugin::initPlugin( $self->{web}.$self->{topic} ) is OK" );
}

sub _name
{
    my ( $self, $name ) = @_;
    $self->{ucname} = "\U$name";
}


sub getPreferencesValue
{
    my ( $self, $var ) = @_;
    return &TWiki::Func::getPreferencesValue( "\U$self->{name}PLUGIN_$var" );
}

sub getPreferencesFlag
{
    my ( $self, $var ) = @_;
    return &TWiki::Func::getPreferencesFlag( "\U$self->{name}PLUGIN_$var" );
}

sub writeDebug
{
    my $self = shift;
    &TWiki::Func::writeDebug( @_ ) if $self->debug();
}

#-------------------------------------------------------------------------------

sub _commonTagsHandler
{
    my $self = shift;
#    print STDERR "base::commonTagsHandler()\n";
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead
    $self->writeDebug( "- $self->{name}Plugin::commonTagsHandler( $_[2].$_[1] )" );
}

# =========================
sub _startRenderingHandler
{
    my $self = shift;
### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead
    $self->writeDebug( "- $self->{name}Plugin::startRenderingHandler( $_[1].$self->{topic} )" );
}

# =========================
sub _outsidePREHandler
{
    my $self = shift;
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead
    $self->writeDebug( "- $self->{name}Plugin::outsidePREHandler( $self->{web}.$self->{topic} )" );
}

# =========================
sub _insidePREHandler
{
    my $self = shift;
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead
    $self->writeDebug( "- $self->{name}Plugin::insidePREHandler( $self->{web}.$self->{topic} )" );
}

# =========================
sub _endRenderingHandler
{
    my $self = shift;
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead
    $self->writeDebug( "- $self->{name}Plugin::endRenderingHandler( $self->{web}.$self->{topic} )" );
}

1;
