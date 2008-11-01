package Beautifier::MagicConfig;

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

use warnings;
sub new
{
	my( $class ) = @_;
	my $self = {};
	bless $self, $class;

	$self->{separator} = ".";

	$self->{descriptions} =
	{
		"parent"=> "Parent Directory",
		"dir"	=> "Directory",
		"ascii"	=> "ASCII File",
		"tar"	=> "Tar Archive",
		"pdf"	=> "Acrobat PDF Document",
		"binary"=> "Binary File",
		"perl"	=> "Perl Source",
		"scheme"=> "Scheme Source",
		"html"	=> "HTML Document",
		
	};

	$self->{extensions} =
	{
		"a"	=> "ada95",
		"ada"	=> "ada95",
		"adb"	=> "ada95",
		"ads"	=> "ada95",
		"asm"	=> "asm_x86",
		"asp"	=> "jscript|vb|vbdotnet",
		"awk"	=> "awk",
		"bas"	=> "vb|vbdotnet",
		"c"	=> "c",
		"cbl"	=> "cobol",
		"cls"	=> "vb|vbdotnet",
		"cob"	=> "cobol",
		"cpy"	=> "cobol",
		"cpp"	=> "cpp",
		"cs"	=> "csharp",
		"css"	=> "css",
		"cxx"	=> "cpp",
		"dpr"	=> "delphi",
		"e"	=> "eiffel|euphoria",
		"ew"	=> "euphoria",
		"eu"	=> "euphoria",
		"ex"	=> "euphoria",
		"exw"	=> "euphoria",
		"exu"	=> "euphoria",
		"fig"	=> "fig",
		"frm"	=> "vb|vbdotnet",
		"gif"	=> "gif",
		"gz"	=> "compressed",
		"h"	=> "c",
		"hpp"	=> "cpp",
		"htm"	=> "html",
		"html"	=> "html",
		"inc"	=> "turbopascal|vb|vbdotnet",
		"java"	=> "javaswing",
		"jpg"	=> "jpeg",
		"jpeg"	=> "jpeg",
		"js"	=> "jscript|javascript",
		"lsp"	=> "lisp",
		"m"	=> "mumps",
		"pas"	=> "delphi|turbopascal",
		"php"	=> "php3",
		"php3"	=> "php3",	
		"php4"	=> "php3",
		"phps"	=> "php3",
		"pl"	=> "perl",
		"pm"	=> "perl",
		"png"	=> "png",
		"py"	=> "python",
		"pyc"	=> "python",
		"rpm"	=> "compressed",
		"rtn"	=> "mumps",
		"scm"	=> "scheme",
		"sh"	=> "sh",
		"tar"	=> "tar",
		"tex"	=> "latex",
		"txt"	=> "ascii",
		"vb"	=> "vb|vbdotnet",
		"vbs"	=> "vb|vbdotnet|vbscript",
		"wsf"	=> "vbscript",
		"xml"	=> "xml",
		"zip"	=> "compressed"
	};
	$self->{functionmap} =
	[
		# Languages
		"csharp",
		"java",
		"euphoria",
		"latex",
		"ada95",
		"delphi",
		"perl",
		"4dos4nt",
		"4gl",
		"vbdotnet",
		"vb",
		"python",
		"awk",
		"bash",
		"rc",
		"env",
		"sh",
		"diff",
		"xdiff",
		"swf",
		"psfont",
		"lex",
		"magic",
		"mime",
		# Markup
		"postscript",
		"css",
		"rtf",
		"html",
		"xml",
		"sgml",
		"pdf",
		# Weak checks (only one or two characters, or common words)
		"eiffel",
		"cpp",
		"lisp",
		# Generics
		"genericshell",
		# Binaries
		"gif",
		"jpeg",
		"bmp",
		"tif",
		"png",
		"fig",
		"tar",
		# Catch-alls
		"ascii",
		"binary"
	];
	return $self;
}

sub detect_cpp
{
	my( $self ) = @_;
	return ($self->{file} =~ /\/\//);
}

# Homemade ones :-)

sub detect_makefile
{
	my( $self ) = @_;
	return ($self->{file} =~ /\b(.+?):/);
}

sub detect_latex
{
	my( $self ) = @_;
	return ($self->{file} =~ /\\begin{(.*?)}/ || 
		$self->{file} =~ /\\section{(.*?)}/);
}

sub detect_fig
{
	my( $self ) = @_;
	return ($self->{file} =~ /^flf/ || 
		$self->{file} =~ /^flc/ ||
		$self->{file} =~ /^#FIG/);
}

sub detect_tar
{
	my( $self ) = @_;
	return ($self->{file} =~ /ustar/);
}

sub detect_python
{
	my( $self ) = @_;
	return ($self->{file} =~ /\bdef\s+(.*?):/);
}

sub detect_php3
{
	my( $self ) = @_;
	return ($self->{file} =~ /<\?/);
}

sub detect_euphoria
{
	my( $self ) = @_;
	return ($self->{file} =~ /^--/ || $self->{file} =~ /sequence/);
}

sub detect_delphi
{
	my( $self ) = @_;
	return ($self->{file} =~ /unit\s+\w+/ || $self->{file} =~ /:=(.+?);/);
}

sub detect_eiffel
{
	my( $self ) = @_;
	return ($self->{file} =~ /\bcreation\b/ || $self->{file} =~ /\bfeature\b/);
}

sub detect_csharp
{
	my( $self ) = @_;
	return ($self->{file} =~ /\Wusing\s+(.+?);/);
}

sub detect_vbdotnet
{
	my( $self ) = @_;
	return ($self->{file} =~ /Public Module/ || $self->{file} =~ /Class/);
}

sub detect_vb
{
	my( $self ) = @_;
	return ($self->{file} =~ /End\s+Sub/);
}

sub detect_ada95
{
	my( $self ) = @_;
	return ($self->{file} =~ /^\s*(function|type)\s+(.*?)\bis\b/);
}

sub detect_java
{
	my( $self ) = @_;
	$_ = $self->{file};
	return (/import\s+java/ || /public\s+class/);
}

sub detect_4gl
{
	my( $self ) = @_;
	$_ = $self->{file};
	return (/INCLUDE/ || /VARIABLE/);
}

sub detect_4dos4nt
{
	my( $self ) = @_;
	$_ = $self->{file};
	return (/ENDIFF/ || /IFF/); 
}

sub detect_sh
{
	my( $self ) = @_;
	return ($self->{file} =~ /^#!\/bin\/sh/);
}

sub detect_css
{
	my( $self ) = @_;
	return ($self->{file} =~ /font-family:/ || 
		$self->{file} =~ /text-decoration:/);
}

# End homemade

sub detect_awk
{
	my( $self ) = @_;
	$_ = $self->{file};;	
	return (/^#!\s+\/bin\/nawk/ 		||
		/^#!\s+\/usr\/bin\/nawk/	||
		/^#!\s+\/usr\/local\/bin\/nawk/	||
		/^#!\s+\/bin\/gawk/		||
		/^#!\s+\/usr\/bin\/gawk/	||
		/^#!\s+\/usr\/local\/bin\/gawk/	||
		/^#!\s+\/bin\/awk/		||
		/^#!\s+\/usr\/bin\/awk/		||
		/^BEGIN\s+/);
}

sub detect_bash
{
	my( $self ) = @_;
	$_ = $self->{file};
	return (/^#!\s+\/bin\/bash/ || /^#!\s+\/usr\/local\/bin\/bash/);
}

sub detect_perl
{
	my( $self ) = @_;
	$_ = $self->{file};
	return (/^#!\s*\/bin\/perl/			||
		/^eval\s+"exec\s+\/bin\/perl/		||
		/^#!\s*\/usr\/bin\/perl/		||
		/^eval\s+"exec\s+\/usr\/bin\/perl/	||
		/^#!\s*\/usr\/local\/bin\/perl/		||
		/^eval\s+"exec\s+\/usr\/local\/bin\/perl/ ||
		/my\s+[\@\$\%\*]/);
}


sub detect_rc
{
	my( $self ) = @_;
	return ($self->{file} =~ /^#!\s*\/bin\/rc/);
}

sub detect_env
{
	my( $self ) = @_;
	return ($self->{file} =~ /^#!\s*\/usr\/bin\/env/);
}

sub detect_genericshell
{
	my( $self ) = @_;
	return ($self->{file} =~ /^#!/);
}

sub detect_diff
{
	my( $self ) = @_;
	$_ = $self->{file};
	return (/^diff\s+/	||
		/^\*\*\*\s+/	||
		/^Only\s+in\s+/	||
		/^Common\s+subdirectories:\s+/);
}

sub detect_xdiff
{
	my( $self ) = @_;
	return ($self->{file} =~ /^%XDZ/);
}

sub detect_swf
{
	my( $self ) = @_;
	return ($self->{file} =~ /^FWS/);
}

sub detect_psfont
{
	my( $self ) = @_;
	return ($self->{file} =~ /^(.*?)PS-AdobeFont-1\.0/);
}

sub detect_lex
{
	my( $self ) = @_;
	my $file = $self->{file};
	
	return ((length($file) > 63 && substr($file, 53, 10) eq "yyprevious") || (length($file)>38 && substr($file, 21, 17) eq "generated by flex"));
}

sub detect_lisp
{
	my( $self ) = @_;
	return ($self->{file} =~ /;;/);
}

sub detect_magic
{
	my( $self ) = @_;
	return ($self->{file} =~ /^\s+Magic/);
}

sub detect_mime
{
	my( $self ) = @_;
	return ($self->{file} =~ /^Content-Type:/);
}

sub detect_postscript
{
	my( $self ) = @_;
	$_ = $self->{file};
	return (/^%!/ || /^\004%!/);
}

sub detect_rtf
{
	my( $self ) = @_;
	$_ = $self->{file};
	return (/{\\\\rtf/);
}

sub detect_html
{
	my( $self ) = @_;
	$_ = $self->{file};
	return (/\s*<!doctype\s+html/	||
		/\s*<head/		||
		/\s*<title/		||
		/\s*<html/);
}

sub detect_xml
{
	my( $self ) = @_;
	$_ = $self->{file};
	return (/\s*<\?xml/);
}

sub detect_sgml
{
	my( $self ) = @_;
	$_ = $self->{file};
	return (/\s*<!doctype/	||
		/\s*<!subdoc/	||
		/\s*<!--/);
}

sub detect_pdf
{
	my( $self ) = @_;
	return ($self->{file} =~ /^%PDF-/);
}

sub detect_gif
{
	my( $self ) = @_;
	$_ = $self->{file};
	return (/GIF89a/);
}

sub detect_jpeg
{
	my( $self ) = @_;
	$_ = substr($self->{file}, 0, 16);
	return (/JFIF/);
}

sub detect_png
{
	my( $self ) = @_;
	my @toparse = unpack("C*", substr($self->{file}, 0, 16));
	return 0 if (@toparse<9);
	return ($toparse[0] == 0x89	&& $toparse[1] == 0x50 &&
		$toparse[2] == 0x4E	&& $toparse[3] == 0x47 &&
		$toparse[4] == 0x0D	&& $toparse[5] == 0x0A &&
		$toparse[6] == 0x1A	&& $toparse[7] == 0x0A);
}

sub detect_bmp
{
	my( $self ) = @_;
	$_ = $self->{file};
	return (/^BM/);
}

sub detect_tif
{
	my( $self ) = @_;
	$_ = $self->{file};
	return (/^MM/ || /^II/);
}

sub detect_ascii
{
	my( $self ) = @_;
	my @toparse = unpack("C*", $self->{file});
	foreach(@toparse)
	{
		return 0 if(ord($_)<32);
	}
	return 1;
}

sub detect_binary
{
	return !detect_ascii(@_);
}

1;
