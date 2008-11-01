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

# <h2>Connection settings</h2>

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
# Base DN to use in searches
$TWiki::cfg{Ldap}{Base} = 'dc=my,dc=domain,dc=com';

# **STRING**
# The DN to use when binding to the LDAP server; if undefined anonymous binding
# will be used. Example 'cn=proxyuser,dc=my,dc=domain,dc=com'
$TWiki::cfg{Ldap}{BindDN} = '';

# **PASSWORD**
# The password used when binding to the LDAP server
$TWiki::cfg{Ldap}{BindPassword} = 'secret';

# **BOOLEAN**
# Use SASL authentication when binding to the server; Note, when using SASL the 
# BindDN and BindPassword setting are used to configure the SASL access.
$TWiki::cfg{Ldap}{UseSASL} = 0;

# **STRING**
# List of SASL authentication mechanism to try; defaults to 'PLAIN CRAM-MD5
# EXTERNAL ANONYMOUS'
$TWiki::cfg{Ldap}{SASLMechanism} = 'PLAIN CRAM-MD5 EXTERNAL ANONYMOUS';

# **BOOLEAN**
# Enable/disable debug output to STDERR. This will end up in your web server's log files.
# But you are adviced to redirect STDERR of TWiki to a separate file. This can be done by
# commenting out the prepaired command in the <code>lib/TWiki/UI.pm</code> file. See the 
# comments there.
$TWiki::cfg{Ldap}{Debug} = 0;

# **STRING**
# <h2>User settings</h2>
# The options below configure how TWiki will extract account records from LDAP.
#
# <!-- work around broken configure -->
# </td></tr><tr><td colspan="2" class="docdata info">
#
# The distinguished name of the users tree. All user accounts will
# be searched for in the subtree under UserBase.
$TWiki::cfg{Ldap}{UserBase} = 'ou=people,dc=my,dc=domain,dc=com';

# **STRING**
# Filter to be used to find login accounts. Compare to GroupFilter below
$TWiki::cfg{Ldap}{LoginFilter} = 'objectClass=posixAccount';

# **STRING**
# The user login name attribute. This is the attribute name that is
# used to login.
$TWiki::cfg{Ldap}{LoginAttribute} = 'uid';

# **STRING**
# The user's wiki name attribute. This is the attribute to generate
# the WikiName from. 
$TWiki::cfg{Ldap}{WikiNameAttribute} = 'cn';

# **BOOLEAN**
# Enable/disable normalization of WikiUserNames as they come from LDAP
# If the WikiNameAttribute is set to 'mail' a trailing @my.domain.com
# is stripped. WARNING: if you switch this off you have to garantee that the WikiNames
# in the WikiNameAttribute are a proper WikiWord (camel-case, no spaces, no umlauts etc).
$TWiki::cfg{Ldap}{NormalizeWikiNames} = 1;

# **BOOLEAN**
# Enable/disable normalization of login names
$TWiki::cfg{Ldap}{NormalizeLoginNames} = 0;

# **STRING**
# Alias old !WikiNames to new account. This is a comma separated list of
# "OldName=NewName" values.
$TWiki::cfg{Ldap}{WikiNameAliases} = '';

# **BOOLEAN**
# Allow/disallow changing the LDAP password using TWiki's ChangePassword feature
$TWiki::cfg{Ldap}{AllowChangePassword} = 0;

# **SELECTCLASS none,TWiki::Users::*User**
# Define a secondary password manager used to authenticate users that are 
# registered to TWiki natively. Note, that <b>this must not be TWiki::Users::LdapUser again!</b>
$TWiki::cfg{Ldap}{SecondaryPasswordManager} = 'none';

# **STRING**
# <h2>Group settings</h2>
# The settings below configures the mapping and processing of LoginNames and WikiNames as
# well as the use of LDAP groups in TWiki. 
# In any case you have to select the LdapUserMapping as the UserMappingManager in the
# Security Section section above.
#
# <!-- work around broken configure -->
# </td></tr><tr><td colspan="2" class="docdata info">
#
# The distinguished name of the groups tree. All group definitions
# are used in the subtree under GroupBase. 
$TWiki::cfg{Ldap}{GroupBase} = 'ou=group,dc=my,dc=domain,dc=com';

# **STRING**
# Filter to be used to find groups. Compare to LoginFilter.
$TWiki::cfg{Ldap}{GroupFilter} = 'objectClass=posixGroup';

# **STRING**
# This is the name of the attribute that holds the name of the 
# group in a group record.
$TWiki::cfg{Ldap}{GroupAttribute} = 'cn';

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

# **BOOLEAN**
# Flag indicating wether we fallback to TWikiGroups. If this is switched on, 
# standard TWiki groups will be used as a fallback if a group definition of a given
# name was not found in the LDAP database.
$TWiki::cfg{Ldap}{TWikiGroupsBackoff} = 1;

# **BOOLEAN**
# Enable/disable normalization of group names as they come from LDAP:
$TWiki::cfg{Ldap}{NormalizeGroupNames} = 0;

# **BOOLEAN**
# Enable use of LDAP groups in TWiki. If you switch this off the group-related settings
# have no effect. This flag is of use if you don't want to define groups in LDAP
# but still want to map LoginNames to WikiNames on the base of LDAP data.
$TWiki::cfg{Ldap}{MapGroups} = 1;

# **NUMBER** 
# <h2>Performance settings</h2>
# The following settings are used to optimize performance in your environment. Please take care.
#
# <!-- work around broken configure -->
# </td></tr><tr><td colspan="2" class="docdata info">
#
# Time in seconds when cache data expires and is reloaded anew, defaults to one day.
$TWiki::cfg{Ldap}{MaxCacheAge} = 86400;

# **NUMBER**
# Number of user objects to fetch in one paged result when building the username mappings;
# this is a speed optimization option, use this value with caution.
$TWiki::cfg{Ldap}{PageSize} = 500; 

# **STRING 50**
# Prevent certain names from being looked up in LDAP
$TWiki::cfg{Ldap}{Exclude} = 'TWikiGuest, TWikiContributor, TWikiRegistrationAgent, TWikiAdminGroup, NobodyGroup';
