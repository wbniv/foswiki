# ---+ LDAP settings
# This is the configuration used by the <b>LdapContrib</b> and the
# <b>LdapNgPlugin</b>. Please have a look at the
# <a href="http://twiki.org/cgi-bin/view/Plugins/LdapContrib">the
# LdapContrib documentation</a> for more information.
# <p>
# To use an LDAP server for authentication you have to use the PasswordManager
# <b>LdapUser</b>.
# To Use groups defined in LDAP enable the UserMappingManager <b>LdapUserMapping</b>.
# (see the Security Setting section)

# <h2>General Settings</h2>

# **STRING**
# IP address (or hostname) of the LDAP server
$TWiki::cfg{Ldap}{Host} = 'my.domain.com';

# **NUMBER**
# Port used when binding to the LDAP server
$TWiki::cfg{Ldap}{Port} = 389;

# **NUMBER**
# Ldap protocol version to use when querying the server; 
# Possible values are: 2, 3
$TWiki::cfg{Ldap}{Version} = '3';

# **STRING**
# The base to be use in default searches
$TWiki::cfg{Ldap}{Base} = 'dc=my,dc=domain,dc=com';

# **STRING**
# The DN to use when binding to the LDAP server; if undefined anonymous binding
# will be used. Example 'cn=proxyuser,dc=my,dc=domain,dc=com'
$TWiki::cfg{Ldap}{BindDN} = '';

# **PASSWORD**
# The password used when binding to the LDAP server
$TWiki::cfg{Ldap}{BindPassword} = 'secret';

# **BOOLEAN**
# Negotiate ssl when binding to the server
# TODO: not implemented yet
$TWiki::cfg{Ldap}{SSL} = 0;


# **STRING**
# <h2>User Settings</h2>
# The options below configure how TWiki will extract account records from LDAP.
#
# <!-- work around broken configure -->
# </td></tr><tr><td colspan="2" class="docdata info">
#
# The distinguished name of the users tree. All user accounts will
# be searched for in the subtree under UserBase.
$TWiki::cfg{Ldap}{UserBase} = 'ou=people,dc=my,dc=domain,dc=com';

# **STRING**
# The user login name attribute. This is the attribute name that is
# used to login.
$TWiki::cfg{Ldap}{LoginAttribute} = 'uid';

# **STRING**
# The user's wiki name attribute. This is the attribute to generate
# the WikiName from. 
$TWiki::cfg{Ldap}{WikiNameAttribute} = 'cn';

# **BOOLEAN**
# Flag to remove non-wikiname chars in the WikiNameAttribute. 
# If the WikiNameAttribute is set to 'mail' a trailing @my.domain.com
# is stripped. WARNING: if you switch this off you have to garantee that the WikiNames
# in the WikiNameAttribute are a proper WikiWord (camel-case, no spaces, no umlauts etc).
$TWiki::cfg{Ldap}{NormalizeWikiNames} = 1;

# **STRING**
# Filter to be used to find login accounts. Compare to GroupFilter below
$TWiki::cfg{Ldap}{LoginFilter} = 'objectClass=posixAccount';

# **BOOLEAN**
# <h2>Group Settings</h2>
# The settings below configures the mapping and processing of LoginNames to WikiNames as
# well as the use of LDAP groups in TWiki. 
# In any case you have to select the LdapUserMapping as the UserMappingManager in the
# Security Section section above.
#
# <!-- work around broken configure -->
# </td></tr><tr><td colspan="2" class="docdata info">
#
# Enable use of LDAP groups in TWiki. If you switch this off the group-related settings
# below have no effect. This flag is of use if you don't want to define groups in LDAP
# but still want to map LoginNames to WikiNames on the base of LDAP data.
$TWiki::cfg{Ldap}{MapGroups} = 1;

# **STRING**
# The distinguished name of the groups tree. All group definitions
# are used in the subtree under GroupBase. 
$TWiki::cfg{Ldap}{GroupBase} = 'ou=group,dc=my,dc=domain,dc=com';

# **STRING**
# This is the name of the attribute that holds the name of the 
# group in a group record.
$TWiki::cfg{Ldap}{GroupAttribute} = 'cn';

# **STRING**
# Filter to be used to find groups. Compare to LoginFilter.
$TWiki::cfg{Ldap}{GroupFilter} = 'objectClass=posixGroup';

# **BOOLEAN**
# Flag indicating wether we fallback to TWikiGroups. If this is switched on, 
# standard TWiki groups will be used as a fallback if a group definition of a given
# name was not found in the LDAP database.
$TWiki::cfg{Ldap}{TWikiGroupsBackoff} = 1;

# **STRING**
# The attribute that should be used to collect group members. This is the name of the
# attribute in a group record used to point to the user record. For example, in a possix setting this
# is the uid of the relevant posixAccount. If groups are implemented using the object class
# 'groupOfNames' the MemberAttribute will store a literal DN pointing to the account record. In this
# case you have to switch on the MemberIndirection flag below.
$TWiki::cfg{Ldap}{MemberAttribute} = 'memberUid';

# **BOOLEAN**
# Flag indicating wether the MemberAttribute of a group stores a DN. 
$TWiki::cfg{Ldap}{MemberIndirection} = 0;

# **NUMBER** 
# <h2>Expert settings</h2>
# The following settings are used to optimize performance in your environment. Please take care.
#
# <!-- work around broken configure -->
# </td></tr><tr><td colspan="2" class="docdata info">
#
# Refresh rate when the ldap cache is fetched from the LDAP server; 
# a value of -1 means unlimitted caching; 
# default is -1. Note, that this will only take effect if you use a perl accelerator like speedy-cgi, mod-perl
# or fastcgi.
$TWiki::cfg{Ldap}{MaxCacheHits} = -1;

# **NUMBER**
# Time in seconds when cache data expires and is reloaded anew.
$TWiki::cfg{Ldap}{MaxCacheAge} = 600;

# **STRING 50**
# Prevent certain names from being looked up in LDAP
$TWiki::cfg{Ldap}{Exclude} = 'TWikiGuest, TWikiContributor, TWikiRegistrationAgent, TWikiAdminGroup, NobodyGroup';

# **NUMBER**
# Number of user objects to fetch in one paged result when building the username mappings;
# this is a speed optimization option, use this value with caution.
$TWiki::cfg{Ldap}{PageSize} = 200; 

# **BOOLEAN**
# Flag to switch on debug output to STDERR. This will end up in your web server's log files.
# But you are adviced to redirect STDERR of TWiki to a separate file. This can be done by
# commenting out the prepaired command in the <code>lib/TWiki/UI.pm</code> file. See the 
# comments there.
$TWiki::cfg{Ldap}{Debug} = 0;
