package Email::Delete::IMAP;

use strict;

use vars qw[$VERSION];
$VERSION = sprintf "%d.%02d", split m/\./, (qw$Revision: 1.1$)[1];

use Email::Folder;
use Net::IMAP::Simple;

sub delete_message {
    my %args = @_;

    my $folder = new Email::Folder( $args{from} );
    my @trash;

    my $num = 1;
    while( my $mail = $folder->next_message() ) {
        if( $args{matching}->($mail) ) {
            push( @trash, $num );
        }
        $num++;
    }

    # SMELL: assumes internals of Email::Folder
    my $server = $folder->{_folder}->{_server};
    foreach my $id ( reverse @trash ) {
        $server->delete( $id );
    }
    # must quit, otherwise the object will go out of scope and the
    # folder will be reset before the connection is closed.
    $server->quit();
}

1;

__END__

=head1 NAME

Email::Delete::IMAP - Delete Messages from an IMAP Folder

=head1 SYNOPSIS

  use Email::Delete qw[delete_message];
  
  my $message_id = shift @ARGV;
  
  delete_messages from     => 'imap://folder',
                  matching => sub {
                      my $message = shift;
                      $message->header('Message-ID') =~ $message_id;
                  };

=head1 DESCRIPTION

This software will delete messages from a given IMAP folder.

=head1 SEE ALSO

L<Email::Delete>,
L<perl>.

=head1 AUTHOR

Crawford Currie, <F<cpan@c-dot.co.uk>>.

=head1 COPYRIGHT

  Copyright (c) 2006 Crawford Currie.  All rights reserved.
  This module is free software; you can redistribute it and/or modify it
  under the same terms as Perl itself.

=cut
