package Beautifier::Magic;

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

use Beautifier::MagicConfig;
use warnings;
use strict;

sub new
{
	my( $class ) = @_;
	my $self = {};
	bless $self, $class;
	$self->{config} = new Beautifier::MagicConfig;
	return $self;
}

sub load_file
{
	my( $self, $filename ) = @_;
	return if (! -e $filename || ! -f $filename);
	my $outstr = "";
	open(FILEIN, $filename)	or return;
	while(<FILEIN>)
	{
		$outstr .= $_;	
	}
	close(FILEIN);
	return $outstr;
}

sub get_description
{
	my( $self, $language ) = @_;
	if ($self->{config}->{descriptions}{$language})
	{
		return $self->{config}->{descriptions}{$language};
	}
	else
	{
		return $language;
	}
}

sub get_language
{
	my( $self, $filename ) = @_;
	my @extensionspl = split(/\Q$self->{config}->{separator}\E/, $filename);
	my $extension 	= $extensionspl[-1];

	my $langstr	= $self->{config}->{extensions}{$extension};
	my @langarr	= ();
	my @checkarray	= ();

	@langarr = defined $langstr ? split(/\|/, $langstr) : ();
	# One language is good :-)
	return $langstr 	if (@langarr ==1 && $langarr[0] ne "");

	# Magic time! If we have a choice of extensions, the process is a little
	# shorter, otherwise we have to do a fairly big chunking process.

	# This bit is nasty... I don't like storing such big strings :-)
	$self->{config}->{file} = $self->load_file($filename);
	return 	unless defined($self->{config}->{file});
	$self->{is_ascii} = (-T $filename);

	if (defined($langstr))
	{
		# Filter out any types that aren't supported.
		foreach(@langarr)
		{
			if (in_array($_, $self->{config}->{functionmap}))
			{
				push(@checkarray, $_);
			}
		}
	}
	else
	{
		@checkarray = @{$self->{config}->{functionmap}};
	}
	foreach my $lang (@checkarray)
	{
		my $func = "detect_$lang";
		return $lang if ($self->{config}->$func());
	}

	return "unknown";
}

sub in_array
{
	my( $to_find, $array ) = @_;
	foreach(@$array)
	{
		return 1 if ($to_find eq $_);
	}
	return 0;
}

1;
