# ---+ Extensions
# ---++ SearchEngineKinoSearchAddOn
# **BOOLEAN**
#If using Wiki::Store::SearchAlgorithms::Kino, enable this for SEARCH to also show attachments (Default is false)
$TWiki::cfg{SearchEngineKinoSearchAddOn}{showAttachments} = 0;


# **BOOLEAN**
#Enable Automatic index updating when topics are modified (Default is false)
# warning: this will slow down save, rename and attach operations.
$TWiki::cfg{SearchEngineKinoSearchPlugin}{EnableOnSaveUpdates} = 0;


# **SELECT antiword,wv,abiword**
# Select which MS Word indexer to use (you need to have antiword, abiword or wvHtml installed)
# <dl>
# <dt>antiword</dt><dd>is the default, and should be used on Linux/Unix.</dd>
# <dt>wvHtml</dt><dd> is recommended for use on Windows.</dd>
# <dt>abiword</dt><dd></dd>
# </dl>
$TWiki::cfg{SearchEngineKinoSearchAddOn}{WordIndexer} = 'antiword';

# **PATH**
# Where KinoSearh logs are stored
$TWiki::cfg{KinoSearchLogDir} = '$TWiki::cfg{PubDir}/../kinosearch/logs';


# **PATH**
# Where KinoSearh index is stored
$TWiki::cfg{KinoSearchIndexDir} = '$TWiki::cfg{PubDir}/../kinosearch/index';

