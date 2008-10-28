package Parse::MediaWikiDump;
our $VERSION = '0.40';
#the POD is at the end of this file
#avoid shift() - it is computationally more expensive than pop
#and shifting values for subroutine input should be avoided in
#any subroutines that get called often, like the handlers

package Parse::MediaWikiDump::Pages;

#This parser works by placing all of the start, text, and end events into
#a buffer as they come out of XML::Parser. On each call to page() the function
#checks for a complete article in the buffer and calls for XML::Parser to add
#more tokens if a complete article is not found. Once a complete article is 
#found it is removed from the buffer, parsed, and an instance of the page
#object is returned. 

use strict;
use warnings;
use XML::Parser;

#tokens in the buffer are an array ref with the 0th element specifying
#its type; these are the constants for those types. 

sub new {
	my $class = shift;
	my $source = shift;
	my $self = {};

	bless($self, $class);

	$$self{PARSER} = XML::Parser->new(ProtocolEncoding => 'UTF-8');
	#$$self{PARSER} = XML::Parser->new(ProtocolEncoding => 'ISO-8859-1');
	$$self{PARSER}->setHandlers('Start', \&start_handler,
				    'End', \&end_handler);
        $$self{EXPAT} = $$self{PARSER}->parse_start(state => $self);
	$$self{BUFFER} = []; 
	$$self{CHUNK_SIZE} = 32768;
	$$self{BUF_LIMIT} = 10000;
	$$self{BYTE} = 0;
	$$self{GOOD_TAGS} = make_good_tags();

	$self->open($source);
	$self->init;

	return $self;
}

sub next {
	my $self = shift;
	my $buffer = $$self{BUFFER};
	my $offset;
	my @page;

	#look through the contents of our buffer for a complete article; fill
	#the buffer with more data if an entire article is not there
	while(1) {
		$offset = $self->search_buffer('/page');
		last if $offset != -1;

		#indicates EOF
		return undef unless $self->parse_more;
	}

	#remove the entire page from the buffer
	@page = splice(@$buffer, 0, $offset + 1);

	if ($page[0][0] ne 'page') {
		$self->dump($buffer);
		die "expected <page>; got " . token2text($page[0]);
	}

	my $data = $self->parse_page(\@page);

	return Parse::MediaWikiDump::page->new($data, $$self{CATEGORY_ANCHOR});
}

#outputs a nicely formated representation of the tokens on the buffer specified
sub dump {
	my $self = shift;
	my $buffer = shift || $$self{BUFFER};
	my $offset = 0;

	foreach my $i (0 .. $#$buffer) {
		my $token = $$buffer[$i];

		print STDERR "$i ";

		if (substr($$token[0], 0, 1) ne '/') {
			my $attr = $$token[1];
			print STDERR "  " x $offset;
			print STDERR "START $$token[0] ";

			foreach my $key (sort(keys(%$attr))) {
				print STDERR "$key=\"$$attr{$key}\" ";
			}

			print STDERR "\n";
			$offset++;
		} elsif (ref $token eq 'ARRAY') {
			$offset--;
			print STDERR "  " x $offset;
			print STDERR "END $$token[0]\n";
		} elsif (ref $token eq 'SCALAR') {
			my $ref = $token;
			print STDERR "  " x $offset;
			print STDERR "TEXT ";

			my $len = length($$ref);

			if ($len < 50) {
				print STDERR "'$$ref'\n";
			} else {
				print STDERR "$len characters\n";
			}
		}
	}
	
	return 1;
}

sub sitename {
	my $self = shift;
	return $$self{HEAD}{sitename};
}

sub base {
	my $self = shift;
	return $$self{HEAD}{base};
}

sub generator {
	my $self = shift;
	return $$self{HEAD}{generator};
}

sub case {
	my $self = shift;
	return $$self{HEAD}{case};
}

sub namespaces {
	my $self = shift;
	return $$self{HEAD}{namespaces};
}

sub current_byte {
	my $self = shift;
	return $$self{BYTE};
}

sub size {
	my $self = shift;
	
	return undef unless defined $$self{SOURCE_FILE};

	my @stat = stat($$self{SOURCE_FILE});

	return $stat[7];
}

#depreciated backwards compatibility methods

#replaced by next()
sub page {
	my $self = shift;
	return $self->next(@_);
}

#private functions with OO interface
sub open {
	my $self = shift;
	my $source = shift;

	if (ref($source) eq 'GLOB') {
		$$self{SOURCE} = $source;
	} else {
		if (! open($$self{SOURCE}, $source)) {
			die "could not open $source: $!";
		}

		$$self{SOURCE_FILE} = $source;
	}

	binmode($$self{SOURCE}, ':utf8');

	return 1;
}

sub init {
	my $self = shift;
	my $offset;
	my @head;

	#parse more XML until the entire siteinfo section is in the buffer
	while(1) {
		die "could not init" unless $self->parse_more;

		$offset = $self->search_buffer('/siteinfo');

		last if $offset != -1;
	}

	#pull the siteinfo section out of the buffer
	@head = splice(@{$$self{BUFFER}}, 0, $offset + 1);

	$self->parse_head(\@head);

	return 1;
}

#feed data into expat and have it put more tokens onto the buffer
sub parse_more {
	my ($self) = @_;
	my $buf;

	my $read = read($$self{SOURCE}, $buf, $$self{CHUNK_SIZE});

	if (! defined($read)) {
		die "error during read: $!";
	} elsif ($read == 0) {
		$$self{FINISHED} = 1;
		$$self{EXPAT}->parse_done();
		return 0;
	}

	$$self{BYTE} += $read;
	$$self{EXPAT}->parse_more($buf);

	my $buflen = scalar(@{$$self{BUFFER}});

	die "buffer length of $buflen exceeds $$self{BUF_LIMIT}" unless
		$buflen < $$self{BUF_LIMIT};

	return 1;
}

#searches through a buffer for a specified token
sub search_buffer {
	my ($self, $search, $list) = @_;

	$list = $$self{BUFFER} unless defined $list;

	return -1 if scalar(@$list) == 0;

	foreach my $i (0 .. $#$list) {
		return $i if ref $$list[$i] eq 'ARRAY' && $list->[$i][0] eq $search;
	}

	return -1;
}

#this function is very frightning =)
sub parse_head {
	my $self = shift;
	my $buffer = shift;
	my $state = 'start';
	my %data = (namespaces => []);

	for (my $i = 0; $i <= $#$buffer; $i++) {
		my $token = $$buffer[$i];

		if ($state eq 'start') {
			my $version;
			die "$i: expected <mediawiki> got " . token2text($token) unless
				$$token[0] eq 'mediawiki';

			die "$i: version is a required attribute" unless
				defined($version = $$token[1]->{version});

			die "$i: version $version unsupported" unless $version eq '0.3';

			$token = $$buffer[++$i];

			die "$i: expected <siteinfo> got " . token2text($token) unless
				$$token[0] eq 'siteinfo';

			$state = 'in_siteinfo';
		} elsif ($state eq 'in_siteinfo') {
			if ($$token[0] eq 'namespaces') {
				$state = 'in_namespaces';
				next;
			} elsif ($$token[0] eq '/siteinfo') {
				last;
			} elsif ($$token[0] eq 'sitename') {
				$token = $$buffer[++$i];

				if (ref $token ne 'SCALAR') {
					die "$i: expected TEXT but got " . token2text($token);
				}

				$data{sitename} = $$token;

				$token = $$buffer[++$i];

				if ($$token[0] ne '/sitename') {
					die "$i: expected </sitename> but got " . token2text($token);
				}
			} elsif ($$token[0] eq 'base') {
				$token = $$buffer[++$i];

				if (ref $token ne 'SCALAR') {
					$self->dump($buffer);
					die "$i: expected TEXT but got " . token2text($token);
				}

				$data{base} = $$token;

				$token = $$buffer[++$i];

				if ($$token[0] ne '/base') {
					$self->dump($buffer);
					die "$i: expected </base> but got " . token2text($token);
				}

			} elsif ($$token[0] eq 'generator') {
				$token = $$buffer[++$i];

				if (ref $token ne 'SCALAR') {
					$self->dump($buffer);
					die "$i: expected TEXT but got " . token2text($token);
				}

				$data{generator} = $$token;

				$token = $$buffer[++$i];

				if ($$token[0] ne '/generator') {
					$self->dump($buffer);
					die "$i: expected </generator> but got " . token2text($token);
				}

			} elsif ($$token[0] eq 'case') {
				$token = $$buffer[++$i];

				if (ref $token ne 'SCALAR') {
					$self->dump($buffer);
					die "$i: expected </case> but got " . token2text($token);
				}

				$data{case} = $$token;

				$token = $$buffer[++$i];

				if ($$token[0] ne '/case') {
					$self->dump($buffer);
					die "$i: expected </case> but got " . token2text($token);
				}
			}

		} elsif ($state eq 'in_namespaces') {
			my $key;
			my $name;

			if ($$token[0] eq '/namespaces') {
				$state = 'in_siteinfo';
				next;
			} 

			if ($$token[0] ne 'namespace') {
				die "$i: expected <namespace> or </namespaces>; got " . token2text($token);
			}

			die "$i: key is a required attribute" unless
				defined($key = $$token[1]->{key});

			$token = $$buffer[++$i];

			#the default namespace has no text associated with it
			if (ref $token eq 'SCALAR') {
				$name = $$token;
			} elsif ($$token[0] eq '/namespace') {
				$name = '';
				$i--; #move back one for below
			} else {
				die "$i: should never happen";	
			}

			push(@{$data{namespaces}}, [$key, $name]);

			$token = $$buffer[++$i];

			if ($$token[0] ne '/namespace') {
				$self->dump($buffer);
				die "$i: expected </namespace> but got " . token2text($token);
			}

		} else {
			die "$i: unknown state '$state'";
		}
	}

	$$self{HEAD} = \%data;

	#locate the anchor that indicates what looks like a link is really a 
	#category assignment ([[foo]] vs [[Category:foo]])
	#fix for bug #16616
	foreach my $ns (@{$data{namespaces}}) {
		#namespace 14 is the category namespace
		if ($$ns[0] == 14) {
			$$self{CATEGORY_ANCHOR} = $$ns[1];
			last;
		}
	}

	if (! defined($$self{CATEGORY_ANCHOR})) {
		die "Could not locate category indicator in namespace definitions";
	}

	return 1;
}

#this function is very frightning =)
sub parse_page {
	my $self = shift;
	my $buffer = shift;
	my %data;
	my $state = 'start';

	for (my $i = 0; $i <= $#$buffer; $i++) {
		my $token = $$buffer[$i];


		if ($state eq 'start') {
			if ($$token[0] ne 'page') {
				$self->dump($buffer);
				die "$i: expected <page>; got " . token2text($token);
			}

			$state = 'in_page';
		} elsif ($state eq 'in_page') {
			next unless ref $token eq 'ARRAY';
			if ($$token[0] eq 'revision') {
				$state = 'in_revision';
				next;
			} elsif ($$token[0] eq '/page') {
				last;
			} elsif ($$token[0] eq 'title') {
				$token = $$buffer[++$i];

				if (ref $token eq 'ARRAY' && $$token[0] eq '/title') {
					$data{title} = '';
					next;
				}

				if (ref $token ne 'SCALAR') {
					$self->dump($buffer);
					die "$i: expected TEXT; got " . token2text($token);
				}

				$data{title} = $$token;

				$token = $$buffer[++$i];

				if ($$token[0] ne '/title') {
					$self->dump($buffer);
					die "$i: expected </title>; got " . token2text($token);
				}
			} elsif ($$token[0] eq 'id') {
				$token = $$buffer[++$i];
	
				if (ref $token ne 'SCALAR') {
					$self->dump($buffer);
					die "$i: expected TEXT; got " . token2text($token);
				}

				$data{id} = $$token;

				$token = $$buffer[++$i];

				if ($$token[0] ne '/id') {
					$self->dump($buffer);
					die "$i: expected </id>; got " . token2text($token);
				}
			}
		} elsif ($state eq 'in_revision') {
			if ($$token[0] eq '/revision') {
				#If a comprehensive dump file is parsed
				#it can cause uncontrolled stack growth and the
				#parser only returns one revision out of
				#all revisions - if we run into a 
				#comprehensive dump file, indicated by more
				#than one <revision> section inside a <page>
				#section then die with a message

				#just peeking ahead, don't want to update
				#the index
				$token = $$buffer[$i + 1];

				if ($$token[0] eq 'revision') {
					die "unable to properly parse comprehensive dump files";
				}

				$state = 'in_page';
				next;	
			} elsif ($$token[0] eq 'contributor') {
				$state = 'in_contributor';
				next;
			} elsif ($$token[0] eq 'id') {
				$token = $$buffer[++$i];
	
				if (ref $token ne 'SCALAR') {
					$self->dump($buffer);
					die "$i: expected TEXT; got " . token2text($token);
				}

				$data{revision_id} = $$token;

				$token = $$buffer[++$i];

				if ($$token[0] ne '/id') {
					$self->dump($buffer);
					die "$i: expected </id>; got " . token2text($token);
				}

			} elsif ($$token[0] eq 'timestamp') {
				$token = $$buffer[++$i];

				if (ref $token ne 'SCALAR') {
					$self->dump($buffer);
					die "$i: expected TEXT; got " . token2text($token);
				}

				$data{timestamp} = $$token;

				$token = $$buffer[++$i];

				if ($$token[0] ne '/timestamp') {
					$self->dump($buffer);
					die "$i: expected </timestamp>; got " . token2text($token);
				}
			} elsif ($$token[0] eq 'minor') {
				$data{minor} = 1;
				$token = $$buffer[++$i];

				if ($$token[0] ne '/minor') {
					$self->dump($buffer);
					die "$i: expected </minor>; got " . token2text($token);
				}
			} elsif ($$token[0] eq 'comment') {
				$token = $$buffer[++$i];

				#account for possible null-text 
				if (ref $token eq 'ARRAY' && $$token[0] eq '/comment') {
					$data{comment} = '';
					next;
				}

				if (ref $token ne 'SCALAR') {
					$self->dump($buffer);
					die "$i: expected TEXT; got " . token2text($token);
				}

				$data{comment} = $$token;

				$token = $$buffer[++$i];

				if ($$token[0] ne '/comment') {
					$self->dump($buffer);
					die "$i: expected </comment>; got " . token2text($token);
				}

			} elsif ($$token[0] eq 'text') {
				my $token = $$buffer[++$i];

				if (ref $token eq 'ARRAY' && $$token[0] eq '/text') {
					${$data{text}} = '';
					next;
				} elsif (ref $token ne 'SCALAR') {
					$self->dump($buffer);
					die "$i: expected TEXT; got " . token2text($token);
				}

				$data{text} = $token;

				$token = $$buffer[++$i];

				if ($$token[0] ne '/text') {
					$self->dump($buffer);
					die "$i: expected </text>; got " . token2text($token);
				}
			
			}

		} elsif ($state eq 'in_contributor') {
			next unless ref $token eq 'ARRAY';
			if ($$token[0] eq '/contributor') {
				$state = 'in_revision';
				next;
			} elsif (ref $token eq 'ARRAY' && $$token[0] eq 'username') {
				$token = $$buffer[++$i];

				if (ref $token ne 'SCALAR') {
					$self->dump($buffer);
					die "$i: expecting TEXT; got " . token2text($token);
				}

				$data{username} = $$token;

				$token = $$buffer[++$i];

				if ($$token[0] ne '/username') {
					$self->dump($buffer);
					die "$i: expected </username>; got " . token2text($token);
				}

			} elsif ($$token[0] eq 'id') {
				$token = $$buffer[++$i];
				
				if (ref $token ne 'SCALAR') {
					$self->dump($buffer);
					die "$i: expecting TEXT; got " . token2text($token);
				}

				$data{userid} = $$token;

				$token = $$buffer[++$i];

				if ($$token[0] ne '/id') {
					$self->dump($buffer);
					die "$i: expecting </id>; got " . token2text($token);
				}
			}
		} else {
			die "unknown state: $state";
		}
	}

	$data{minor} = 0 unless defined($data{minor});

	return \%data;
}

#private functions with out OO interface
sub make_good_tags {
	return {
		sitename => 1,
		base => 1,
		generator => 1,
		case => 1,
		namespace => 1,
		title => 1,
		id => 1,
		timestamp => 1,
		username => 1,
		comment => 1,
		text => 1
	};
}

sub token2text {
	my $token = shift;

	if (ref $token eq 'ARRAY') {
		return "<$$token[0]>";
	} elsif (ref $token eq 'SCALAR') {
		return "!text_token!";
	} else {
		return "!unknown!";
	}
}

#this function is where the majority of time is spent in this software
#sub token_compare {
#	my ($toke1, $toke2) = @_;
#
#	foreach my $i (0 .. $#$toke2) {
#		if ($$toke1[$i] ne $$toke2[$i]) {
#			return 0;
#		}
#	}
#
#	return 1;
#}

sub start_handler {
	my ($p, $tag, %atts) = @_;	
	my $self = $p->{state};
	my $good_tags = $self->{GOOD_TAGS};

	push @{ $self->{BUFFER} }, [$tag, \%atts];

	if (defined($good_tags->{$tag})) {
		$p->setHandlers(Char => \&char_handler);
	}

	return 1;
}

sub end_handler {
	my ($p, $tag) = @_;
	my $self = $p->{state};

	push @{ $self->{BUFFER} }, ["/$tag"];

	$p->setHandlers(Char => undef);
	
	return 1;
}

sub char_handler {
	my ($p, $chars) = @_;
	my $self = $p->{state};
	my $buffer = $$self{BUFFER};
	my $curent = $$buffer[-1];

	if (ref $curent eq 'SCALAR') {
		$$curent .= $chars;
	} elsif (substr($$curent[0], 0, 1) ne '/') {
		push(@$buffer, \$chars);
	} 

	return 1;
}

package Parse::MediaWikiDump::page;

use strict;
use warnings;

sub new {
	my ($class, $data, $category_anchor, $case_setting) = @_; 
	my $self = {};

	bless($self, $class);

	$$self{DATA} = $data;
	$$self{CACHE} = {};
	$$self{CATEGORY_ANCHOR} = $category_anchor;

	return $self;
}

sub namespace {
	my $self = shift;

	return $$self{CACHE}{namespace} if defined($$self{CACHE}{namespace});

	my $title = $$self{DATA}{title};

	if ($title =~ m/^([^:]+)\:/) {
		$$self{CACHE}{namespace} = $1;
		return $1;
	} else {
		$$self{CACHE}{namespace} = '';
		return '';
	}
}

sub categories {
	my $self = shift;
	my $anchor = $$self{CATEGORY_ANCHOR};

	return $$self{CACHE}{categories} if defined($$self{CACHE}{categories});

	my $text = $$self{DATA}{text};
	my @cats;
	
	while($$text =~ m/\[\[$anchor:\s*([^\]]+)\]\]/gi) {
		my $buf = $1;

		#deal with the pipe trick
		$buf =~ s/\|.*$//;
		push(@cats, $buf);
	}

	return undef if scalar(@cats) == 0;

	$$self{CACHE}{categories} = \@cats;

	return \@cats;
}

sub redirect {
	my $self = shift;
	my $text = $$self{DATA}{text};

	return $$self{CACHE}{redirect} if exists($$self{CACHE}{redirect});

	if ($$text =~ m/^#redirect\s*:?\s*\[\[([^\]]*)\]\]/i) {
		$$self{CACHE}{redirect} = $1;
		return $1;
	} else {
		$$self{CACHE}{redirect} = undef;
		return undef;
	}
}

sub title {
	my $self = shift;
	return $$self{DATA}{title};
}

sub id {
	my $self = shift;
	return $$self{DATA}{id};
}

sub revision_id {
	my $self = shift;
	return $$self{DATA}{revision_id};
}

sub timestamp {
	my $self = shift;
	return $$self{DATA}{timestamp};
}

sub username {
	my $self = shift;
	return $$self{DATA}{username};
}

sub userid {
	my $self = shift;
	return $$self{DATA}{userid};
}

sub minor {
	my $self = shift;
	return $$self{DATA}{minor};
}

sub text {
	my $self = shift;
	return $$self{DATA}{text};
}

package Parse::MediaWikiDump::Links;

use strict;
use warnings;

sub new {
	my $class = shift;
	my $source = shift;
	my $self = {};
	$$self{BUFFER} = [];

	bless($self, $class);

	$self->open($source);
	$self->init;

	return $self;
}

sub next {
	my $self = shift;
	my $buffer = $$self{BUFFER};
	my $link;

	while(1) {
		if (defined($link = pop(@$buffer))) {
			last;
		}

		#signals end of input
		return undef unless $self->parse_more;
	}

	return Parse::MediaWikiDump::link->new($link);
}

#private functions with OO interface
sub parse_more {
	my $self = shift;
	my $source = $$self{SOURCE};
	my $need_data = 1;
	
	while($need_data) {
		my $line = <$source>;

		last unless defined($line);

		while($line =~ m/\((\d+),(-?\d+),'(.*?)'\)[;,]/g) {
			push(@{$$self{BUFFER}}, [$1, $2, $3]);
			$need_data = 0;
		}
	}

	#if we still need data and we are here it means we ran out of input
	if ($need_data) {
		return 0;
	}
	
	return 1;
}

sub open {
	my $self = shift;
	my $source = shift;

	if (ref($source) ne 'GLOB') {
		die "could not open $source: $!" unless
			open($$self{SOURCE}, $source);
	} else {
		$$self{SOURCE} = $source;
	}

	binmode($$self{SOURCE}, ':utf8');

	return 1;
}

sub init {
	my $self = shift;
	my $source = $$self{SOURCE};
	my $found = 0;
	
	while(<$source>) {
		if (m/^LOCK TABLES `.*pagelinks` WRITE;/) {
			$found = 1;
			last;
		}
	}

	die "not a MediaWiki link dump file" unless $found;
}

#depreciated backwards compatibility methods

#replaced by next()
sub link {
	my $self = shift;
	$self->next(@_);
}

package Parse::MediaWikiDump::link;

#you must pass in a fully populated link array reference
sub new {
	my $class = shift;
	my $self = shift;

	bless($self, $class);

	return $self;
}

sub from {
	my $self = shift;
	return $$self[0];
}

sub namespace {
	my $self = shift;
	return $$self[1];
}

sub to {
	my $self = shift;
	return $$self[2];
}


1;

__END__

=head1 NAME

Parse::MediaWikiDump - Tools to process MediaWiki dump files

=head1 SYNOPSIS

  use Parse::MediaWikiDump;

  $source = 'dump_filename.ext';
  $source = \*FILEHANDLE;

  $pages = Parse::MediaWikiDump::Pages->new($source);
  $links = Parse::MediaWikiDump::Links->new($source);

  #get all the records from the dump files, one record at a time
  while(defined($page = $pages->next)) {
    print "title '", $page->title, "' id ", $page->id, "\n";
  }

  while(defined($link = $links->next)) {
    print "link from ", $link->from, " to ", $link->to, "\n";
  }

  #information about the page dump file
  $pages->sitename;
  $pages->base;
  $pages->generator;
  $pages->case;
  $pages->namespaces;
  $pages->current_byte;
  $pages->size;

  #information about a page record
  $page->redirect;
  $page->categories;
  $page->title;
  $page->namespace;
  $page->id;
  $page->revision_id;
  $page->timestamp;
  $page->username;
  $page->userid;
  $page->minor;
  $page->text;

  #information about a link
  $link->from;
  $link->to;
  $link->namespace;

=head1 DESCRIPTION

This module provides the tools needed to process the contents of various 
MediaWiki dump files. 

=head1 USAGE

To use this module you must create an instance of a parser for the type of
dump file you are trying to parse. The current parsers are:

=over 4

=item Parse::MediaWikiDump::Pages

Parse the contents of the page archive.

=item Parse::MediaWikiDump::Links

Parse the contents of the links dump file. 

=back

=head2 General

Both parsers require an argument to new that is a location of source data
to parse; this argument can be either a filename or a reference to an already
open filehandle. This entire software suite will die() upon errors in the file,
inconsistencies on the stack, etc. If this concerns you then you can wrap
the portion of your code that uses these calls with eval().

=head2 Parse::MediaWikiDump::Pages

It is possible to create a Parse::MediaWikiDump::Pages object two ways:

=over 4

=item $pages = Parse::MediaWikiDump::Pages->new($filename);

=item $pages = Parse::MediaWikiDump::Pages->new(\*FH);

=back

After creation the folowing methods are avalable:

=over 4

=item $pages->next

Returns the next available record from the dump file if it is available,
otherwise returns undef. Records returned are instances of 
Parse::MediaWikiDump::page; see below for information on those objects.

=item $pages->sitename

Returns the plain-text name of the instance the dump is from.

=item $pages->base

Returns the base url to the website of the instance.

=item $pages->generator

Returns the version of the software that generated the file.

=item $pages->case

Returns the case-sensitivity configuration of the instance.

=item $pages->namespaces

Returns an array reference to the list of namespaces in the instance. Each
namespace is stored as an array reference which has two items; the first is the
namespace number and the second is the namespace name. In the case of namespace
0 the text stored for the name is ''.

=item $pages->current_byte

Returns the number of bytes parsed so far.

=item $pages->size

Returns the size of the dump file in bytes.

=back

=head3 Parse::MediaWikiDump::page

The Parse::MediaWikiDump::page object represents a distinct MediaWiki page, 
article, module, what have you. These objects are returned by the next() method
of a Parse::MediaWikiDump::Pages instance. The scalar returned is a reference
to a hash that contains all the data of the page in a straightforward manor. 
While it is possible to access this hash directly, and it involves less overhead
than using the methods below, it is beyond the scope of the interface and is
undocumented. 

Some of the methods below require additional processing, such as namespaces,
redirect, and categories, to name a few. In these cases the returned result
is cached and stored inside the object so the processing does not have to be
redone. This is transparent to you; just know that you don't have to worry about
optimizing calls to these functions to limit processing overhead. 

The following methods are available:

=over 4

=item $page->id

=item $page->title

=item $page->namespace

Returns an empty string (such as '') for the main namespace or a string 
containing the name of the namespace.

=item $page->text

A reference to a scalar containing the plaintext of the page.

=item $page->redirect

The plain text name of the article redirected to or undef if the page is not
a redirect.

=item $page->categories

Returns a reference to an array that contains a list of categories or undef
if there are no categories. This method does not understand templates and may
not return all the categories the article actually belongs in. 

=item $page->revision_id

=item $page->timestamp

=item $page->username

=item $page->userid

=item $page->minor

=back

=head2 Parse::MediaWikiDump::Links

This module also takes either a filename or a reference to an already open 
filehandle. For example:

  $links = Parse::MediaWikiDump::Links->new($filename);
  $links = Parse::MediaWikiDump::Links->new(\*FH);

It is then possible to extract the links a single link at a time using the
next method, which returns an instance of Parse::MediaWikiDump::link or undef
when there is no more data. For instance: 

  while(defined($link = $links->next)) {
    print 'from ', $link->from, ' to ', $link->to, "\n";
  }

=head3 Parse::MediaWikiDump::link

Instances of this class are returned by the link method of a 
Parse::MediaWikiDump::Links instance. The following methods are available:

=over 4

=item $link->from

The numerical id the link was in. 

=item $link->to

The plain text name the link is to, minus the namespace.

=item $link->namespace

The numerical id of the namespace the link points to. 

=back

=head1 EXAMPLES

=head2 Extract the article text for a given title

  #!/usr/bin/perl
  
  use strict;
  use warnings;
  use Parse::MediaWikiDump;
  
  my $file = shift(@ARGV) or die "must specify a MediaWiki dump of the current pages";
  my $title = shift(@ARGV) or die "must specify an article title";
  my $dump = Parse::MediaWikiDump::Pages->new($file);
  
  binmode(STDOUT, ':utf8');
  binmode(STDERR, ':utf8');
  
  #this is the only currently known value but there could be more in the future
  if ($dump->case ne 'first-letter') {
    die "unable to handle any case setting besides 'first-letter'";
  }
  
  $title = case_fixer($title);
  
  while(my $page = $dump->next) {
    if ($page->title eq $title) {
      print STDERR "Located text for $title\n";
      my $text = $page->text;
      print $$text;
      exit 0;
    }
  }
  
  print STDERR "Unable to find article text for $title\n";
  exit 1;
  
  #removes any case sensativity from the very first letter of the title
  #but not from the optional namespace name
  sub case_fixer {
    my $title = shift;
  
    #check for namespace
    if ($title =~ /^(.+?):(.+)/) {
      $title = $1 . ':' . ucfirst($2);
    } else {
      $title = ucfirst($title);
    }
  
    return $title;
  }

=head2 Scan the dump file for double redirects

  #!/usr/bin/perl
  
  #progress information goes to STDERR, a list of double redirects found
  #goes to STDOUT
  
  binmode(STDOUT, ":utf8");
  binmode(STDERR, ":utf8");
  
  use strict;
  use warnings;
  use Parse::MediaWikiDump;
  
  my $file = shift(@ARGV);
  my $pages;
  my $page;
  my %redirs;
  my $artcount = 0;
  my $file_size;
  my $start = time;
  
  if (defined($file)) {
  	$file_size = (stat($file))[7];
  	$pages = Parse::MediaWikiDump::Pages->new($file);
  } else {
  	print STDERR "No file specified, using standard input\n";
  	$pages = Parse::MediaWikiDump::Pages->new(\*STDIN);
  }
  
  #the case of the first letter of titles is ignored - force this option
  #because the other values of the case setting are unknown
  die 'this program only supports the first-letter case setting' unless
  	$pages->case eq 'first-letter';
  
  print STDERR "Analyzing articles:\n";
  
  while(defined($page = $pages->next)) {
    update_ui() if ++$artcount % 500 == 0;
  
    #main namespace only
    next unless $page->namespace eq '';
    next unless defined($page->redirect);
  
    my $title = case_fixer($page->title);
    #create a list of redirects indexed by their original name
    $redirs{$title} = case_fixer($page->redirect);
  }
  
  my $redir_count = scalar(keys(%redirs));
  print STDERR "done; searching $redir_count redirects:\n";
  
  my $count = 0;
  
  #if a redirect location is also a key to the index we have a double redirect
  foreach my $key (keys(%redirs)) {
    my $redirect = $redirs{$key};
  
    if (defined($redirs{$redirect})) {
      print "$key\n";
      $count++;
    }
  }
  
  print STDERR "discovered $count double redirects\n";
  
  #removes any case sensativity from the very first letter of the title
  #but not from the optional namespace name
  sub case_fixer {
    my $title = shift;
  
    #check for namespace
    if ($title =~ /^(.+?):(.+)/) {
      $title = $1 . ':' . ucfirst($2);
    } else {
      $title = ucfirst($title);
    }
  
    return $title;
  }
  
  sub pretty_bytes {
    my $bytes = shift;
    my $pretty = int($bytes) . ' bytes';
  
    if (($bytes = $bytes / 1024) > 1) {
      $pretty = int($bytes) . ' kilobytes';
    }
  
    if (($bytes = $bytes / 1024) > 1) {
      $pretty = sprintf("%0.2f", $bytes) . ' megabytes';
    }
  
    if (($bytes = $bytes / 1024) > 1) {
      $pretty = sprintf("%0.4f", $bytes) . ' gigabytes';
    }
  
    return $pretty;
  }
  
  sub pretty_number {
    my $number = reverse(shift);
    $number =~ s/(...)/$1,/g;
    $number = reverse($number);
    $number =~ s/^,//;
  
    return $number;
  }
  
  sub update_ui {
    my $seconds = time - $start;
    my $bytes = $pages->current_byte;
  
    print STDERR "  ", pretty_number($artcount),  " articles; "; 
    print STDERR pretty_bytes($bytes), " processed; ";
  
    if (defined($file_size)) {
      my $percent = int($bytes / $file_size * 100);
  
      print STDERR "$percent% completed\n"; 
    } else {
      my $bytes_per_second = int($bytes / $seconds);
      print STDERR pretty_bytes($bytes_per_second), " per second\n";
    }
  }

=head1 TODO

=over 4

=item Support comprehensive dump files

Currently the full page dump files (such as 20050909_pages_full.xml.gz) 
are not supported.

=item Optimization

It would be nice to increase the processing speed of the XML files. Current
ideas:

=over 4

=item Move to arrays instead of hashes for base objects 

Currently the base types for the majority of the classes are hashes. The 
majority of these could be changed to arrays and numerical constants instead
of using hashes. 

=item Stackless parsing

placing each XML token on the stack is probably quite time consuming. It may be
beter to move to a stackless system where the XML parser is given a new set
of callbacks to use when it encounters each specific token.

=back

=back

=head1 AUTHOR

This module was created and documented by Tyler Riddle E<lt>triddle@gmail.comE<gt>. 

=head1 BUGS

Please report any bugs or feature requests to
C<bug-parse-mediawikidump@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Parse-MediaWikiDump>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head2 Known Bugs

No known bugs at this time. 

=head1 COPYRIGHT & LICENSE

Copyright 2005 Tyler Riddle, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

