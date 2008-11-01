package HFile::HFile_makefile;

###############################
#
# Beautifier Perl HFile
# Language: makefile
#
###############################

use Beautifier::HFile;
@ISA = qw(HFile);
sub new
{
	my( $class ) = @_;
	my $self = {};
	bless $self, $class;

	# Flags:
	$self->{nocase}         	= "0";
	$self->{notrim}         	= "0";
	$self->{perl}           	= "0";
	$self->{indent}         	= [];
	$self->{unindent}       	= [];
	$self->{stringchars}    	= ["\"", "'"];
	$self->{delimiters}     	= ["~", "!", "\$", "%", "^", "&", "-", "+", "=", "|", "\\", "/", "{", "}", "[", "]", ";", "\"", "'", "(", ")", "<", ">", " ", ",", "	"];
	$self->{escchar}        	= "";
	$self->{linecommenton}  	= ["#"];
	$self->{blockcommenton} 	= [""];
	$self->{blockcommentoff}	= [""];
	$self->{keywords}       	= {
			".DEFAULT:" => "1", 
			".IGNORE:" => "1", 
			".PRECIOUS:" => "1", 
			".SILENT:" => "1", 
			".SUFFIXES" => "1", 
			"?" => "2", 
			"@" => "2", 
			"\$" => "2", 
			"\$@" => "2", 
			"<" => "2", 
			"*" => "2", 
			"%" => "2", 
			"()" => "2"};

# Each category can specify a Perl function that takes in the function name, and returns a string
# to put in its place. This can be used to generate links, images, etc.

$self->{linkscripts}		= {
			"1"	=> "donothing", 
			"2"	=> "donothing"};

	return $self;
}


# DoNothing link function

sub donothing
{
my ( $self ) = @_;
return;
}
1;
