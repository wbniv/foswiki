# ---+ ToPDF Settings
# This is the configuration used by the <b>ToPDFPlugin</b> and the
# <h2>Environment</h2>

# **STRING**
# normaly your Foswiki encoding 
$Foswiki::cfg{Plugins}{ToPDFPlugin}{DefaultEncoding} = "iso-8859-1";

# **STRING**
#  path to Ghostscript
$Foswiki::cfg{Plugins}{ToPDFPlugin}{GhostscriptPath} = "/usr/bin/gs";

# **STRING**
# path to your fonts reporsitory
$Foswiki::cfg{Plugins}{ToPDFPlugin}{FontsPath} = "/usr/share/fonts/default/ghostscript/";


# **STRING**
# what is the URL of the page. Important! Its needed to define what can be fetched
# locally and what is remote
$Foswiki::cfg{Plugins}{ToPDFPlugin}{BaseUrl} = "foswiki.org";

# <h2>PDF format and style</h2>
# **STRING**
# template to use for rendering the topic with, before creating the PDF
$Foswiki::cfg{Plugins}{ToPDFPlugin}{PrintTemplate} = "pattern";

# **BOOLEAN**
# Create a tobel of contents
$Foswiki::cfg{Plugins}{ToPDFPlugin}{CreateTOC} = 0;

# **BOOLEAN**
# render and show images
$Foswiki::cfg{Plugins}{ToPDFPlugin}{RenderImages} = 1;

# **BOOLEAN**
# render forms
$Foswiki::cfg{Plugins}{ToPDFPlugin}{RenderForms} = 0;

# **BOOLEAN**
# render links and make them clickable
$Foswiki::cfg{Plugins}{ToPDFPlugin}{RenderLinks} = 1;

# **NUMBER**
# width of the page, important if linebreaks should be exact 
$Foswiki::cfg{Plugins}{ToPDFPlugin}{PageWidth} = 755;

# **STRING**
#  Media format
$Foswiki::cfg{Plugins}{ToPDFPlugin}{MediaType} = "A4";

# **STRING**
#  date format to use when filling in header/footer
$Foswiki::cfg{Plugins}{ToPDFPlugin}{DateFormat} = "d.m.y";
