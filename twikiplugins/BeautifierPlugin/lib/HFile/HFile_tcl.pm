package HFile::HFile_tcltk;

###############################
#
# Beautifier Perl HFile
# Language: Tcl/Tk
#
###############################

use Beautifier::HFile;
@ISA = qw(HFile);
sub new
{
    my( $class ) = @_;
    my $self = {};
    bless $self, $class;

    # Flags:
    $self->{nocase}             = "0";
    $self->{notrim}             = "1";
    $self->{perl}               = "0";
    $self->{indent}             = ();
    $self->{unindent}           = ();
    $self->{stringchars}        = ["\""];
    $self->{delimiters}         = ["~", "!", "@", "%", "^", "&", "*", "(", ")", "-", "+", "=", "|", "\\", "/", "{", "}", "[", "]", ":", ";", "\"", "\'", "<", ">", " ", ",", "  ", "?"];
    $self->{escchar}            = "";
    $self->{linecommenton}      = ["#"];
    $self->{blockcommenton}     = [""];
    $self->{blockcommentoff}    = [""];
    $self->{keywords}           = {
            # Nebula specific
            "new" => "1",
            "sel" => "1",
            "n3dnode" => "5",
            "nanimnode" => "5",
            "naudioserver" => "5",
            "nchannelserver" => "5",
            "nchnmodulator" => "5",
            "nchnreader" => "5",
            "nchnsplitter" => "5",
            "ncollidenode" => "5",
            "ncollideserver" => "5",
            "nconserver" => "5",
            "ncurvearraynode" => "5",
	    "ndi8server" => "5",
            "nenv" => "5",
            "nfileserver" => "5",
            "nfileserver2" => "5",
            "nflatterrainnode" => "5",
            "nflipflop" => "5",
            "nfognode" => "5",
            "ngfxserver" => "5",
            "nhypermixer2" => "5",
            "ninputserver" => "5",
            "nipol" => "5",
            "njoint" => "5",
            "njoint2" => "5",
            "njointanim" => "5",
            "nlenseflare" => "5",
            "nlightnode" => "5",
            "nlinknode" => "5",
            "nlistenernode" => "5",
            "nmeshcluster" => "5",
            "nmeshcluster2" => "5",
            "nmesheffect" => "5",
            "nmeshemitter" => "5",
            "nmeshipol" => "5",
            "nmeshmixer" => "5",
            "nmeshnode" => "5",
            "nmixer" => "5",
            "nobserver" => "5",
            "noctree" => "5",
            "noverlayplane" => "5",
            "nparticleserver" => "5",
            "npemitter" => "5",
            "npointemitter" => "5",
            "nprender" => "5",
            "nprofileserver" => "5",
            "npservemitter" => "5",
            "nroot" => "5",
            "nscenegraph2" => "5",
            "nscriptlet" => "5",
            "nshadernode" => "5",
            "nshadowcontrol" => "5",
            "nshadowserver" => "5",
            "nsoundnode" => "5",
            "nspecialfxserver" => "5",
            "nspriterender" => "5",
            "nstaticmeshemitter" => "5",
            "ntclscriptlet" => "5",
            "nterrainnode" => "5",
            "ntexarraynode" => "5",
            "nthreshnode" => "5",
            "ntimeserver" => "5",
            "ntrailrender" => "5",
            "nvisnode" => "5",
            "nweighttree" => "5",
            "nzipfileserver" => "5",
            # Tcl
            "after" => "1", 
            "append" => "1", 
            "array" => "1", 
            "auto_execok" => "1", 
            "auto_load" => "1", 
            "auto_mkindex" => "1", 
            "auto_reset" => "1", 
            "bgerror" => "1", 
            "break" => "1", 
            "case" => "1", 
            "catch" => "1", 
            "cd" => "1", 
            "clock" => "1", 
            "close" => "1", 
            "concat" => "1", 
            "continue" => "1", 
            "eof" => "1", 
            "error" => "1", 
            "eval" => "1", 
            "exec" => "1", 
            "exit" => "1", 
            "expr" => "1", 
            "else" => "1", 
            "elseif" => "1", 
            "fblocked" => "1", 
            "fconfigure" => "1", 
            "file" => "1", 
            "fileevent" => "1", 
            "flush" => "1", 
            "for" => "1", 
            "foreach" => "1", 
            "format" => "1", 
            "gets" => "1", 
            "glob" => "1", 
            "global" => "1", 
            "history" => "1", 
            "if" => "1", 
            "incr" => "1", 
            "info" => "1", 
            "interp" => "1", 
            "join" => "1", 
            "lappend" => "1", 
            "lindex" => "1", 
            "linsert" => "1", 
            "list" => "1", 
            "llength" => "1", 
            "load" => "1", 
            "lrange" => "1", 
            "lreplace" => "1", 
            "lsearch" => "1", 
            "lsort" => "1", 
            "open" => "1", 
            "package" => "1", 
            "parray" => "1", 
            "pid" => "1", 
            "proc" => "1", 
            "puts" => "1", 
            "pwd" => "1", 
            "read" => "1", 
            "regexp" => "1", 
            "regsub" => "1", 
            "rename" => "1", 
            "return" => "1", 
            "scan" => "1", 
            "seek" => "1", 
            "set" => "1", 
            "socket" => "1", 
            "source" => "1", 
            "split" => "1", 
            "string" => "1", 
            "subst" => "1", 
            "switch" => "1", 
            "tell" => "1", 
            "time" => "1", 
            "trace" => "1", 
            "tcl_endOfWord" => "1", 
            "tcl_startOfNextWord" => "1", 
            "tcl_startOfPreviousWord" => "1", 
            "tcl_wordBreakAfter" => "1", 
            "tcl_wordBreakBefore" => "1", 
            "unknown" => "1", 
            "unset" => "1", 
            "update" => "1", 
            "uplevel" => "1", 
            "upvar" => "1", 
            "vwait" => "1", 
            "while" => "1", 
            "auto_execs" => "2", 
            "auto_index" => "2", 
            "auto_noexec" => "2", 
            "auto_noload" => "2", 
            "auto_path" => "2", 
            "env" => "2", 
            "ErrorCode" => "2", 
            "ErrorInfo" => "2", 
            "tcl_library" => "2", 
            "tcl_patchLevel" => "2", 
            "tcl_pkgPath" => "2", 
            "tcl_platform" => "2", 
            "tcl_precision" => "2", 
            "tcl_rcFileName" => "2", 
            "tcl_rcRsrcName" => "2", 
            "tcl_version" => "2", 
            "tcl_nonwordchars" => "2", 
            "tcl_wordchars" => "2", 
            "unknown_active" => "2", 
            "bell" => "3", 
            "bind" => "3", 
            "bindtags" => "3", 
            "bitmap" => "3", 
            "button" => "3", 
            "canvas" => "3", 
            "checkbutton" => "3", 
            "clipboard" => "3", 
            "destroy" => "3", 
            "entry" => "3", 
            "event" => "3", 
            "focus" => "3", 
            "frame" => "3", 
            "grab" => "3", 
            "grid" => "3", 
            "image" => "3", 
            "label" => "3", 
            "listbox" => "3", 
            "lower" => "3", 
            "menu" => "3", 
            "menubutton" => "3", 
            "message" => "3", 
            "option" => "3", 
            "pack" => "3", 
            "photo" => "3", 
            "place" => "3", 
            "radiobutton" => "3", 
            "raise" => "3", 
            "scale" => "3", 
            "scrollbar" => "3", 
            "selection" => "3", 
            "send" => "3", 
            "text" => "3", 
            "tk" => "3", 
            "tk_bindForTraversal" => "3", 
            "tk_bisque" => "3", 
            "tk_chooseColor" => "3", 
            "tk_dialog" => "3", 
            "tk_focusFollowsMouse" => "3", 
            "tk_focusNext" => "3", 
            "tk_focusPrev" => "3", 
            "tk_getOpenFile" => "3", 
            "tk_getSaveFile" => "3", 
            "tk_menuBar" => "3", 
            "tk_messageBox" => "3", 
            "tk_optionMenu" => "3", 
            "tk_popup" => "3", 
            "tk_setPalette" => "3", 
            "tkerror" => "3", 
            "tkvars" => "3", 
            "tkwait" => "3", 
            "toplevel" => "3", 
            "winfo" => "3", 
            "wm" => "3", 
            "**" => "4", 
            "\$" => "4",
            };

# Each category can specify a Perl function that takes in the function name, and returns a string
# to put in its place. This can be used to generate links, images, etc.

$self->{linkscripts}        = {
            "1" => "donothing", 
            "2" => "donothing",
            "3" => "donothing",
            "4" => "donothing",
            "5" => "mknebulalink"};

    return $self;
}


# DoNothing link function

sub donothing
{
my ( $self ) = @_;
return;
}

sub mknebulalink
{
    my ( $self, $keyword ) = @_;
    return "<a target=\"$keyword\" onClick='open(\"http://nebuladevice.sourceforge.net/doc/autodoc/classes/$keyword.html\",\"$keyword\",\"titlebar=0,width=600,height=480,resizable,scrollbars\");' href=\"http://nebuladevice.sourceforge.net/doc/autodoc/classes/$keyword.html\">$keyword</a>"
}

1;
