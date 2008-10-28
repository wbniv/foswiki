#---+ Extension Settings
#---++ Publish Contrib
# **PATH**
# File path to the directory where published files will be generated.
# you will normally want this to be visible via a URL, so the TWiki
# pub directory is a good choice.
$TWiki::cfg{PublishContrib}{Dir} = '$TWiki::cfg{PubDir}/publish/';
# **URL**
# URL path of the directory you defined above.
$TWiki::cfg{PublishContrib}{URL} = '$TWiki::cfg{PubUrl}/publish/';
# **COMMAND**
# Command-line for the PDF generator program
$TWiki::cfg{PublishContrib}{PDFCmd} = 'htmldoc --webpage --links --linkstyle plain --outfile %FILE|F% %EXTRAS|U% %FILES|F%';
