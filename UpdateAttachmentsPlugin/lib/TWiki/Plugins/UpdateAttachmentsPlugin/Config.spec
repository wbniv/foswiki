#---+ Update Attachments Plugin
# **STRING**
# To attribute attachments to a known user, set this to their WikiName. This user should exist,
# and be mappable to a login. (in 4.2 and above)
$TWiki::cfg{Plugins}{UpdateAttachmentsPlugin}{AttachAsUser} = '';
# **BOOLEAN**
# remove references to attachments that no longer exist in pub
$TWiki::cfg{Plugins}{UpdateAttachmentsPlugin}{RemoveMissing} = $FALSE;
# **BOOLEAN**
# use the _internal_ _noHandlersSave - this may break in future if the internal method is changed
# not recomended unless you know the code.
$TWiki::cfg{Plugins}{UpdateAttachmentsPlugin}{UseDangerousNoHandlersSave} = $FALSE;