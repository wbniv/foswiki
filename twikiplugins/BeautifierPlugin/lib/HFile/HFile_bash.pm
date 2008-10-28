package HFile::HFile_bash;

###############################
#
# Beautifier Perl HFile
# Language: Bash
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
	$self->{indent}         	= ["{("];
	$self->{unindent}       	= ["})"];
	$self->{stringchars}		= ["'"];
	$self->{delimiters}     	= ["~", "!", "@", "\$", "%", "^", "*", "(", ")", "+", "=", "/", "\\", "[", "]", "{", "}", ":", ";", "\"", "<", ">", "'", "´", "`", " ", ",", "	", ".", "?"];
	$self->{escchar}        	= "";
	$self->{linecommenton}  	= ["#"];
	$self->{blockcommenton} 	= [""];
	$self->{blockcommentoff}	= [""];
	$self->{keywords}       	= {
			"'" => "1", 
			"{" => "1", 
			"}" => "1", 
			"&&" => "1", 
			"||" => "1", 
			"\$" => "1", 
			"alias" => "1", 
			"break" => "1", 
			"case" => "1", 
			"continue" => "1", 
			"do" => "1", 
			"done" => "1", 
			"elif" => "1", 
			"else" => "1", 
			"esac" => "1", 
			"exit" => "1", 
			"export" => "1", 
			"fi" => "1", 
			"for" => "1", 
			"if" => "1", 
			"in" => "1", 
			"return" => "1", 
			"set" => "1", 
			"then" => "1", 
			"unalias" => "1", 
			"unset" => "1", 
			"while" => "1", 
			"halt" => "2", 
			"ifconfig" => "2", 
			"init" => "2", 
			"initlog" => "2", 
			"insmod" => "2", 
			"linuxconf" => "2", 
			"lsmod" => "2", 
			"modprobe" => "2", 
			"reboot" => "2", 
			"rmmod" => "2", 
			"route" => "2", 
			"shutdown" => "2", 
			"traceroute" => "2", 
			"]" => "3", 
			"[" => "3", 
			"awk" => "3", 
			"basename" => "3", 
			"cat" => "3", 
			"cp" => "3", 
			"echo" => "3", 
			"egrep" => "3", 
			"fgrep" => "3", 
			"gawk" => "3", 
			"grep" => "3", 
			"gzip" => "3", 
			"kill" => "3", 
			"killall" => "3", 
			"less" => "3", 
			"md" => "3", 
			"mkdir" => "3", 
			"mv" => "3", 
			"nice" => "3", 
			"pidof" => "3", 
			"ps" => "3", 
			"rd" => "3", 
			"read" => "3", 
			"rm" => "3", 
			"rmdir" => "3", 
			"sed" => "3", 
			"sleep" => "3", 
			"test" => "3", 
			"touch" => "3", 
			"ulimit" => "3", 
			"uname" => "3", 
			"usleep" => "3", 
			"zcat" => "3", 
			"zless" => "3", 
			"`" => "4", 
			"-a" => "4", 
			"-b" => "4", 
			"-c" => "4", 
			"-d" => "4", 
			"-e" => "4", 
			"-f" => "4", 
			"-g" => "4", 
			"-h" => "4", 
			"-i" => "4", 
			"-j" => "4", 
			"-k" => "4", 
			"-l" => "4", 
			"-m" => "4", 
			"-n" => "4", 
			"-o" => "4", 
			"-p" => "4", 
			"-q" => "4", 
			"-r" => "4", 
			"-s" => "4", 
			"-t" => "4", 
			"-u" => "4", 
			"-v" => "4", 
			"-w" => "4", 
			"-x" => "4", 
			"-z" => "4", 
			"-eq" => "5", 
			"-ge" => "5", 
			"-gt" => "5", 
			"-le" => "5", 
			"-lt" => "5", 
			"=" => "5", 
			"!=" => "5"};

# Each category can specify a Perl function that takes in the function name, and returns a string
# to put in its place. This can be used to generate links, images, etc.

$self->{linkscripts}		= {
			"1"	=> "donothing", 
			"2"	=> "donothing", 
			"3"	=> "donothing", 
			"4"	=> "donothing",
			"5" => "donothing"};

	return $self;
}


# DoNothing link function

sub donothing
{
my ( $self ) = @_;
return;
}
1;
