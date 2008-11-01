#---+ DatabasePlugin
# Database access information can either be configured here,
# or it can be recovered from a remote database.
# <p />
# If a remote database is used, it must contain a table with the
# following fields:
# <ul>
# <li>description - A symbolic name for the database.</li>
# <li>driver - Database driver</li>
# <li>db_name - The name of the database</li>
# <li>db_sid - The SID of the database (optional: required for Oracle)</li>
# <li>ro_username - The user name to use</li>
# <li>ro_password - The password for the specified ro_username</li>
# <li>hostname - The name of the host on which the specified db_name lives</li>
# </ul>
# The table specifies all the available databases.
# <p />
# **SELECT Local,Remote**
# Specifies where to get database configuration information from. 'Local'
# gets it here, 'Remote' looks up a database.
$TWiki::cfg{Plugins}{DatabasePlugin}{ConfigSource} = 'Local';
# **STRING 30**
# <h2> Setup for Remote database table</h2>
# If {ConfigSource} is Remote, specifies the name of the host that
# serves the database info table
$TWiki::cfg{Plugins}{DatabasePlugin}{ConfigHost} = '';
# **STRING 30**
# If {ConfigSource} is Remote, specifies the driver for the DB that
# serves the database info table
$TWiki::cfg{Plugins}{DatabasePlugin}{ConfigDriver} = '';
# **STRING 30**
# If {ConfigSource} is Remote, specifies the name of the database that
# contains the database info table
$TWiki::cfg{Plugins}{DatabasePlugin}{ConfigDB} = '';
# **STRING 30**
# If {ConfigSource} is Remote, specifies the sid of the database that
# contains the database info table (not required for MySQL)
$TWiki::cfg{Plugins}{DatabasePlugin}{ConfigSID} = '';
# **STRING 30**
# If {ConfigSource} is Remote, specifies the name of the database info table
$TWiki::cfg{Plugins}{DatabasePlugin}{ConfigTable} = '';
# **STRING 30**
# If {ConfigSource} is Remote, specifies the username for the database that
# contains the database info table
$TWiki::cfg{Plugins}{DatabasePlugin}{ConfigUsername} = '';
# **STRING 30**
# If {ConfigSource} is Remote, specifies the password to the database that
# contains the database info table
$TWiki::cfg{Plugins}{DatabasePlugin}{ConfigPassword} = '';
# **STRING 30**
# <h2> Setup for DATABASE_EDIT (optional)</h2>
$TWiki::cfg{Plugins}{DatabasePlugin}{EditURLPrefix} = 'https';
# **STRING 50**
# This can either be a relative path or absolute.  If absolute, then it
# would look something like machine.com/path_to_place_for/phpMyAdmin
$TWiki::cfg{Plugins}{DatabasePlugin}{EditURLPath} = 'phpMyAdmin-2.2.2-rc1';
# **PERL**
# <h2>Setup for Local databases table</h2>
# Table of configuration info for all the databases you might access.
# Used if {ConfigSource} is Local.
# This structure is an array of database definitions. Each database
# is defined using a hash where the fields of the array are:
# <ol>
# <li> description - Symbolic name for this database</li>
# <li> driver - DB driver - values like: mysql, Oracle, etc.</li>
# <li> hostname - DB host</li>
# <li> database - DB name</li>
# <li> sid - DB sid (Oracle, ignore for MySQL)</li>
# <li> username - DB username</li>
# <li> password - DB password</li>
# <li> table_name - optional table name, used with DATABASE_TABLE and DATABASE_REPEAT to predefine which table to look up
# </ol>
$TWiki::cfg{Plugins}{DatabasePlugin}{Databases} =
[
   {
       description => 'description',
       driver => 'mysql',
       hostname => 'localhost',
       database => 'my_database',
       sid => 'sid',
       username => 'user',
       password => 'pass',
       table_name => '',
   },
];
