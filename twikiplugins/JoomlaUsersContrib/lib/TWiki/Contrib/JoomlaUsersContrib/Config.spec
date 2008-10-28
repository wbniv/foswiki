

# ---+ User Managers
# ---++ Joomla User Manager
# to use JoomlaUserMapping, you need to set the following settings in the "Security Setup" above
# <ol><li>
# UserMappingManager = 'TWiki::Users::JoomlaUserMapping';
# </li><li>
# SuperAdminGroup = 'Super Administrator';
# </li><li>
# LoginManager = 'TWiki::LoginManager::JoomlaLogin'; - (This setting will allow TWiki to use the 'stay logged in' cookie that Joomla makes.)
# </li></ol>
# **STRING 25**
# The DSN to connect to the Joomla Database.
$TWiki::cfg{Plugins}{JoomlaUser}{DBI_dsn} = 'dbi:mysql:joomla_db:localhost';
# **STRING 25**
# The user to connect to the Joomla Database.
$TWiki::cfg{Plugins}{JoomlaUser}{DBI_username} = 'mysqlpassword';
# **PASSWORD**
# The password to connect to the Joomla Database.
$TWiki::cfg{Plugins}{JoomlaUser}{DBI_password} = 'pwd';
