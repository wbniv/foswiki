package HFile::HFile_lua;

###############################
#
# Beautifier Perl HFile
# Language: lua
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
	$self->{notrim}         	= "1";
	$self->{perl}           	= "0";
	$self->{indent}         	= ();
	$self->{unindent}       	= ();
	$self->{stringchars}    	= ["'"];
	$self->{delimiters}     	= ["~", "!", "@", "%", "^", "&", "*", "(", ")", "-", "+", "=", "|", "\\", "/", "{", "}", "[", "]", ":", ";", "\"", "\'", "<", ">", " ", "..", ",", "	", "?"];
	$self->{escchar}        	= "";
	$self->{linecommenton}  	= ["--"];
	$self->{blockcommenton} 	= ["--[["];
	$self->{blockcommentoff}	= ["]]"];
	$self->{keywords}       	= {
                        # Keywords
			"function" => "1", 
			"end" => "1", 
			"if" => "1", 
			"then" => "1", 
			"else" => "1", 
			"elseif" => "1", 
			"do" => "1", 
			"repeat" => "1", 
			"until" => "1", 
			"while" => "1", 
			"return" => "1", 
			"local" => "1", 
			"and" => "1", 
			"or" => "1", 
			"not" => "1", 
			"nil" => "1", 
			"break" => "1", 
			"true" => "1", 
			"false" => "1", 
                        # Internal functions
                        "assert" => "2",
                        "call" => "2",
                        "collectgarbage" => "2",
                        "dofile" => "2",
                        "copytagmethods" => "2",
                        "dostring" => "2",
                        "error" => "2",
                        "foreach" => "2",
                        "foreachvar" => "2",
                        "getglobal" => "2",
                        "newtag" => "2",
                        "next" => "2",
                        "nextvar" => "2",
                        "print" => "2",
                        "rawgetglobal" => "2",
                        "rawgettable" => "2",
                        "rawsetglobal" => "2",
                        "rawsettable" => "2",
                        "seterrormethod" => "2",
                        "setglobal" => "2",
                        "settagmethod" => "2",
                        "gettagmethod" => "2",
                        "settag" => "2",
                        "tonumber" => "2",
                        "tostring" => "2",
                        "tag" => "2",
                        "type" => "2",
                        # Standard libraries
                        "setlocale" => "3",
                        "execute" => "3",
                        "remove" => "3",
                        "rename" => "3",
                        "tmpname" => "3",
                        "getenv" => "3",
                        "date" => "3",
                        "clock" => "3",
                        "exit" => "3",
                        "debug" => "3",
                        "print_stack" => "3",
                        "readfrom" => "3",
                        "writeto" => "3",
                        "appendto" => "3",
                        "read" => "3",
                        "write" => "3",
                        "abs" => "3",
                        "sin" => "3",
                        "cos" => "3",
                        "tan" => "3",
                        "asin" => "3",
                        "acos" => "3",
                        "atan" => "3",
                        "atan2" => "3",
                        "ceil" => "3",
                        "floor" => "3",
                        "mod" => "3",
                        "frexp" => "3",
                        "ldexp" => "3",
                        "sqrt" => "3",
                        "min" => "3",
                        "max" => "3",
                        "log" => "3",
                        "log10" => "3",
                        "exp" => "3",
                        "deg" => "3",
                        "rad" => "3",
                        "random" => "3",
                        "randomseed" => "3",
                        "strlen" => "3",
                        "strsub" => "3",
                        "strlower" => "3",
                        "strupper" => "3",
                        "strchar" => "3",
                        "strrep" => "3",
                        "ascii" => "3",
                        "strbyte" => "3",
                        "format" => "3",
                        "strfind" => "3",
                        "gsub" => "3",
                        # Nebula specific
                        "sel" => "4",
                        "psel" => "4",
                        "new" => "4",
                        "delete" => "4",
                        "exit" => "4",
                        "get" => "4",
                        "puts" => "4",
                        "ls" => "4",
                        "call" => "4",
                        "lookup" => "4",
                        "mangle" => "4",
			};

# Each category can specify a Perl function that takes in the function name, and returns a string
# to put in its place. This can be used to generate links, images, etc.

$self->{linkscripts}		= {
			"1"	=> "donothing", 
			"2"	=> "donothing", 
			"3"	=> "donothing",
			"4"     => "donothing"};

	return $self;
}


# DoNothing link function

sub donothing
{
my ( $self ) = @_;
return;
}
1;
