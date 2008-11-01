

# ---+ Plugins
# ---++ TracQueryPlugin
# to use the TracQueryPlugin, you need to set the following settings
# **SELECT SQLite,MySQL**
# Type of data base
$TWiki::cfg{Plugins}{TracQueryPlugin}{TRAC_DB} = 'SQLite';
# **STRING 25**
# The path to the trac data base. For SQLite, this is a physical
# path on the machine; for MySQL, this is the portion of the URL
# following the host.
$TWiki::cfg{Plugins}{TracQueryPlugin}{TRAC_DB_NAME} = '/path/to/trac/db/trac.db';
# **STRING 25**
# Host on which the trac data base is running (not required for SQLite)
$TWiki::cfg{Plugins}{TracQueryPlugin}{TRAC_HOST} = '';
# **STRING 25**
# The port to access the trac db (not required for SQLite)
$TWiki::cfg{Plugins}{TracQueryPlugin}{TRAC_DB_PORT} = '';
# **STRING 25**
# The user to connect to the Trac Database. (not required for SQLite)
$TWiki::cfg{Plugins}{TracQueryPlugin}{TRAC_USER} = '';
# **PASSWORD**
# The password to connect to the Trac Database. (not required for SQLite)
$TWiki::cfg{Plugins}{TracQueryPlugin}{TRAC_PASSWD} = '';
