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
