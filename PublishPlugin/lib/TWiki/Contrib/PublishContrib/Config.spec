#---+ Publish Contrib
# **PERL H**
# Bin script registration - do not modify
$TWiki::cfg{SwitchBoard}{publish} = [ "TWiki::Contrib::Publish", "publish", { } ];
# **PATH**
# File path to the directory where published files will be generated.
# you will normally want this to be visible via a URL, so a subdirectory
# of the TWiki pub directory is a good choice.
$TWiki::cfg{PublishContrib}{Dir} = '$TWiki::cfg{PubDir}/publish/';
# **URL**
# URL path of the directory you defined above.
$TWiki::cfg{PublishContrib}{URL} = '$TWiki::cfg{DefaultUrlHost}$TWiki::cfg{PubUrlPath}/publish/';
# **COMMAND**
# Command-line for the PDF generator program.
# <ul><li>%FILES|F% will expand to the list of input files</li>
# <li>%FILE|F% will expand to the output file name </li>
# <li>%EXTRAS|U% will expand to any additional generator options entered
# in the publishing form.</li></ul>
$TWiki::cfg{PublishContrib}{PDFCmd} = 'htmldoc --webpage --links --linkstyle plain --outfile %FILE|F% %EXTRAS|U% %FILES|F%';
