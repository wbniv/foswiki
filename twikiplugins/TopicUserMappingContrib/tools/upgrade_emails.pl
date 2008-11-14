#!perl
#
# This script will iterate over the list of users in the TWiki users
# topic, recovering the email for each user (which will get the email
# from the user topic if it isn't found in the secret DB) and then
# setting the email in the secret DB. This will *not* modify the
# user topics.
#
# A default admin e-mail address will be used for users without an
# e-mail address currently in their user topic.
#

use strict;

BEGIN {
    require 'setlib.cfg';
};

use TWiki;
use TWiki::Users::TopicUserMapping; # required to get email addresses

my $twiki = new TWiki();

my $admin_email = $TWiki::cfg{WebMasterEmail} || 'webmaster@example.com';
$/ = "\n";

print <<HERE;
Enter admin e-mail address to use as default, enter to confirm.
This address will be used for any user that I can't find an existing
address for.
HERE

while (1) {
    print "Admin e-mail address ['$admin_email']: ";
    my $n = <>;
    chomp $n;
    last if( !$n );
    $admin_email = $n;
};

my ($meta, $text) =
  $twiki->{store}->readTopic(
      undef, $TWiki::cfg{UsersWebName}, $TWiki::cfg{UsersTopicName} );

my $users = $twiki->{users};

foreach my $line ( split( /\r?\n/, $text )) {
    if( $line =~ /^\s*\* ($TWiki::regex{webNameRegex}\.)?(\w+)\s*(?:-\s*(\S+)\s*)?-\s*\d+ \w+ \d+\s*$/o ) {
        my $web = $1 || $TWiki::cfg{UsersWebName};
        my $wn = $2 || '';	# WikiName
        my $un = $3 || $wn;	# userid
        my $id = ($un eq $wn) ? $wn : "$un:$wn";

        my $cUID = $users->getCanonicalUserID($un);
        if ($cUID) {
            # Use an eval in case there is a problem setting the email
            eval {
                # Get emails *from the password manager*
                my @em = $users->getEmails($cUID);
                if (scalar(@em)) {
                    print "Already have an address for $id\n";
                } else {
                    # Get emails *from the TWiki user mapping manager*
                    @em = TWiki::Users::TopicUserMapping::mapper_getEmails(
                        $twiki, $cUID);
                    if( scalar( @em )) {
                        print "Secreting $id: ",join(';',@em),"\n";
                        $users->setEmails( $cUID, @em );
                    } else {
                        print "No email address found for $id, using $admin_email\n";
                        $users->setEmails( $cUID, $admin_email );
                    }
                }
            };
            print "Warning: $@" if $@;
        } else {
            print "User $id not found in users database\n"
        }
    }
}

