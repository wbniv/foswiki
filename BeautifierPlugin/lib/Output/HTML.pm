package Output::HTML;

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

sub new
{
	my( $class ) = @_;
	my $self = {};
	bless $self, $class;
	$self->{html}		= 1;
	$self->{code} 		= '<pre>_WORD_</pre>';
	$self->{linecomment} 	= '<font color="green">_WORD_</font>';
	$self->{blockcomment} 	= '<font color="green">_WORD_</font>';
	$self->{prepro} 	= '<font color="purple">_WORD_</font>';
	$self->{select} 	= '<b>_WORD_</b>';
	$self->{quote} 		= '<font color="blue">_WORD_</font>';
	$self->{category_1} 	= '<font color="brown">_WORD_</font>';
	$self->{category_2} 	= '<font color="maroon">_WORD_</font>';
	$self->{category_3} 	= '<font color="navy">_WORD_</font>';
	$self->{category_4} 	= '<font color="purple">_WORD_</font>';
	$self->{category_5} 	= '<font color="teal">_WORD_</font>';
	return $self;
}

1;
