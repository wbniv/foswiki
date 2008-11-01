# ---+ MailInContrib
# **PERL**
# The configuration is in the form of an (perl) array of mailbox
# specifications. Each specification defines a number of fields:
# <ul>
#  <li> onError - what you want TWiki to do if an error occurs while processing
#   a mail (comma-separated list of options). Available options:
#   <ul>
#    <li> reply - reply to the sender</li>
#    <li> delete - delete the mail from the inbox</li>
#    <li> log - log the error to the TWiki warning log</li>
#   </ul>
#   Note: if you don't specify delete, TWiki will continue to try to process the
#   mail each time the cron job runs.
#  </li>
#  <li> topicPath - where you want TWiki to look for the name of the target
#   topic (comma-separated list of options). Available options:
#   <ul>
#    <li> to - look in the To: e.g. <code>Web.TopicName@example.com</code> or
#     <code>"Web TopicName" &lt;web.topicname@example.com&gt;</code> </li>
#    <li> subject - look in the Subject: e.g "Web.TopicName: mail for TWiki"
#     If "to" and "subject" are both enabled, but a valid topic name is not
#     found in the To:, the Subject: will still be parsed to try and get the
#     topic.</li>
#   </ul>
#  <li> folder - name of the mail folder<br />
#      Note: support for POP3 requires that the Email::Folder::POP3
#      module is installed. Support for IMAP requires
#      Email::Folder::IMAP etc.
#      Folder names are as described in the documentation for the
#      relevant Email::Folder type e.g. for POP3, the folder name might be:
#      <code>pop://me:123@mail.isp.com:110/</code></li>
#  <li> user - name of the default user.<br />
#      The From: in the mail is parsed to extract the senders email
#      address. This is then be looked up in the TWiki users database
#      to find the wikiname. If the user is not found, then this default
#      user will be used. If the default user is left blank, then the
#      user *must* be found from the mail.
#      The identity of the sending user is important for access controls.
#      This must be a user *login* name.e.g. 'guest'
#  </li>
#  <li> onSuccess - what  you want TWiki to do with messages that have been successfully added to a TWiki topic
#     (comma-separated list of options)
#     Available options:
#   <ul>
#    <li> reply - reply to the sender</li>
#    <li> delete - delete the mail from the inbox</li>
#   </ul>
#  <li> defaultWeb - name of the web to save mails in if the web name isn't
#   specified in the mail. If this is undefined or left blank, then mails must
#   contain a full web.topicname or the mail will be rejected.</li>
#  <li> onNoTopic - what do you want TWiki to do if it can't find a valid
#   topic name in the mail (one option). Available options:
#   <ul>
#    <li> error - treat this as an error (overrides all other options)</li>
#    <li> spam - save the mail in the spambox topic.
#    Note: if you clear this, then TWiki will simply ignore the mail..</li>
#   </ul>
#  </li>
#  <li> spambox - optional required of onNoTopic = spam. Name of the topic
#   where you want to save mails that don't have a valid web.topic. You must
#   specify a full web.topicname
#  </li>
# </ul>
$TWiki::cfg{MailInContrib} = [
 {
   folder => 'pop://example_user:password@example.com/Inbox',
   onError => 'log',
   onNoTopic => 'error',
   onSuccess => 'log delete',
   topicPath => 'to subject',
 },
];

1;
