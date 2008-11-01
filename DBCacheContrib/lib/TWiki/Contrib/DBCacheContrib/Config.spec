#---+ DBCacheContrib
# This extension is a performance cache used by the DBCachePlugin
# and FormQueryPlugin.
# **SELECTCLASS TWiki::Contrib::DBCacheContrib::Archivist::* **
# The extension can one of use a number of different implementations for
# storing the cache. Which one you should choose depends mainly on what you
# have installed. If you have the CPAN 'Storable' module installed you
# should use that. Only use File if you have no other choice (it is
# relatively slow and insecure).
$TWiki::cfg{DBCacheContrib}{Archivist} =
    'TWiki::Contrib::DBCacheContrib::Archivist::Storable';


# **BOOLEAN**
# if  $TWiki::cfg{DBCache}{AlwaysUpdateCache}  is set to FALSE (defaults to TRUE for compatibility)
# then avoid calling _updateCache unless requested. DBCachePlugin now only asked for it from
# the afterSaveHandler and from the new REST updateCache handler
$TWiki::cfg{DBCache}{AlwaysUpdateCache} = $TRUE;

# **NUMBER**
# $TWiki::cfg{DBCache}{loadFileLimit} can be used to prevent the _updateCache from parsing all of the changed and new files in one hit.
# thus reducing the impact on individual topic views, or spreading the upadte over several UpdateCache rest requests.
# default of 0 removes the limit
$TWiki::cfg{DBCache}{LoadFileLimit} = 0;
