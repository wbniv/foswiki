package HFile::HFile_cpp;

###############################
#
# Beautifier Perl HFile
# Language: c++
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
	$self->{indent}         	= ["{"];
	$self->{unindent}       	= ["}"];
	$self->{stringchars}    	= ["\""];
	$self->{delimiters}     	= ["~", "!", "@", "%", "^", "&", "*", "(", ")", "-", "+", "=", "|", "\\", "/", "{", "}", "[", "]", ":", ";", "\"", "\'", "<", ">", " ", ",", "	", "?"];
	$self->{escchar}        	= "";
	$self->{linecommenton}  	= ["//"];
	$self->{blockcommenton} 	= ["/*"];
	$self->{blockcommentoff}	= ["*/"];
	$self->{keywords}       	= {
			"auto"	=> "1", 
			"bool"	=> "1", 
			"break"	=> "1", 
			"case"	=> "1", 
			"catch"	=> "1", 
			"char"	=> "1", 
			"class"	=> "1", 
			"const"	=> "1", 
			"const_const"	=> "1", 
			"continue"	=> "1", 
			"default"	=> "1", 
			"delete"	=> "1", 
			"do"	=> "1", 
			"double"	=> "1", 
			"dynamic_cast"	=> "1", 
			"else"	=> "1", 
			"enum"	=> "1", 
			"extern"	=> "1", 
			"explicit"	=> "1", 
			"false"	=> "1", 
			"float"	=> "1", 
			"friend"	=> "1", 
			"for"	=> "1", 
			"goto"	=> "1", 
			"if"	=> "1", 
			"inline"	=> "1", 
			"int"	=> "1", 
			"long"	=> "1", 
			"mutable"	=> "1", 
			"new"	=> "1", 
			"namespace"	=> "1", 
			"operator"	=> "1", 
			"register"	=> "1", 
			"private"	=> "1", 
			"protected"	=> "1", 
			"public"	=> "1", 
			"reinterpret_cast"	=> "1", 
			"return"	=> "1", 
			"short"	=> "1", 
			"signed"	=> "1", 
			"sizeof"	=> "1", 
			"static"	=> "1", 
			"static_cast"	=> "1", 
			"struct"	=> "1", 
			"switch"	=> "1", 
			"template"	=> "1", 
			"this"	=> "1", 
			"throw"	=> "1", 
			"true"	=> "1", 
			"try"	=> "1", 
			"typedef"	=> "1", 
			"typename"	=> "1", 
			"typeid"	=> "1", 
			"union"	=> "1", 
			"unsigned"	=> "1", 
			"using"	=> "1", 
			"void"	=> "1", 
			"volatile"	=> "1", 
			"while"	=> "1", 
			"#define" => "3", 
			"#error" => "3", 
			"#include" => "3", 
			"#elif" => "3", 
			"#if" => "3", 
			"#line" => "3", 
			"#else" => "3", 
			"#ifdef" => "3", 
			"#pragma" => "3", 
			"#endif" => "3", 
			"#ifndef" => "3", 
			"#undef" => "3",
			};

# Each category can specify a Perl function that takes in the function name, and returns a string
# to put in its place. This can be used to generate links, images, etc.

$self->{linkscripts}		= {
			"1"	=> "donothing", 
			"2"	=> "donothing",
			"3"     => "donothing"};

	return $self;
}


# DoNothing link function

sub donothing
{
my ( $self ) = @_;
return;
}
1;
