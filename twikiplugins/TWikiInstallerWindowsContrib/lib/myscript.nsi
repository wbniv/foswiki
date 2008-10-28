!include "ReplaceSubStr.nsh"
;Uses the ReplacesString macro from http://nsis.sourceforge.net/wiki/Replace_Sub_String_%28macro%29
;Uses the ZipDLL plugin from 
Outfile twinst.exe
Name 'Twiki Installer For Windows'
ShowInstDetails show
var twikiInstall
var download
var installPerl
var perlDir
var installPerlPackages
var cfg
var cfg_tmp
var str
var pubDir
var dataDir
var templateDir
var twikiVirtualDir
var twinst
var perlinst

var repository
var libnet_zip
var libnet_ppd
var sha_zip
var sha_ppd
var twiki_site
var twiki_name
var perl_site
var perl_name
Section ""
ClearErrors
ReadRegDWORD $0 HKLM "SOFTWARE\Microsoft\InetStp" "MajorVersion"
ReadRegDWORD $1 HKLM "SOFTWARE\Microsoft\InetStp" "MinorVersion"
IfErrors +1 +2
ExecWait '"sysocmgr" /i:sysoc.inf /u:"$EXEDIR\unattended.txt" /r'
ReadINIStr $twikiInstall "$EXEDIR\install.ini" "settings" "twikiTargetDir"
ReadINIStr $download "$EXEDIR\install.ini" "settings" "download"
ReadINIStr $installPerl "$EXEDIR\install.ini" "settings" "installPerl"
ReadINIStr $perlDir "$EXEDIR\install.ini" "settings" "perlDir"
ReadINIStr $installPerlPackages "$EXEDIR\install.ini" "settings" "installPerlPackages"
ReadINIStr $twikiVirtualDir "$EXEDIR\install.ini" "settings" "twikiVirtualDir"

ReadINIStr $repository "$EXEDIR\install.ini" "settings" "repository"
ReadINIStr $libnet_zip "$EXEDIR\install.ini" "settings" "libnet_zip"
ReadINIStr $libnet_ppd "$EXEDIR\install.ini" "settings" "libnet_ppd"
ReadINIStr $sha_zip "$EXEDIR\install.ini" "settings" "sha_zip"
ReadINIStr $sha_ppd "$EXEDIR\install.ini" "settings" "sha_ppd"
ReadINIStr $twiki_site "$EXEDIR\install.ini" "settings" "twiki_site"
ReadINIStr $twiki_name "$EXEDIR\install.ini" "settings" "twiki_name"
ReadINIStr $perl_site "$EXEDIR\install.ini" "settings" "perl_site"
ReadINIStr $perl_name "$EXEDIR\install.ini" "settings" "perl_name"

StrCpy $1 $twikiInstall
!insertmacro ReplaceSubStr $1 '\' '\\'
StrCpy $twinst $MODIFIED_STR
StrCpy $1 $perlDir
!insertmacro ReplaceSubStr $1 '\' '\\'
StrCpy $perlinst $MODIFIED_STR

StrCmp $download true +1 endDownload
IfFileExists UnxUtils.zip +2 +1
NSISdl::download http://unxutils.sourceforge.net/UnxUtils.zip UnxUtils.zip
IfFileExists $twiki_name +2 +1
NSISdl::download '$twiki_site/$twiki_name' $twiki_name
IfFileExists $perl_name +2 +1
NSISdl::download $perl_site/$perl_name $perl_name
IfFileExists $libnet_ppd +2 +1
NSISdl::download $repository/$libnet_ppd $libnet_ppd
IfFileExists $libnet_zip +2 +1
NSISdl::download $repository/$libnet_zip $libnet_zip
IfFileExists $sha_zip +2 +1
NSISdl::download $repository/$sha_zip $sha_zip
IfFileExists $sha_ppd +2 +1
NSISdl::download $repository/$sha_ppd $sha_ppd
endDownload:
ifFileExists $twikiInstall\lib +2
ZipDLL::extractAll $twiki_name $twikiInstall
StrCmp $installPerl true +1 +3
IfFileExists $PerlDir\Perl\bin +2
ExecWait '"msiexec.exe" /i "$EXEDIR\$perl_name" TARTGETDIR="$PerlDir" /quiet'

StrCmp $installPerlPackages true +1 +3
nsExec::ExecToLog '"$perlDir\Perl\bin\ppm.bat" install "$EXEDIR\$libnet_ppd"'
nsExec::ExecToLog '"$perlDir\Perl\bin\ppm.bat" install "$EXEDIR\$sha_ppd"'
ZipDLL::extractFile "$EXEDIR\UnxUtils.zip" "$EXEDIR\TEMP" "usr\local\wbin\ls.exe"
ZipDLL::extractFile "$EXEDIR\UnxUtils.zip" "$EXEDIR\TEMP" "usr\local\wbin\grep.exe"
ZipDLL::extractFile "$EXEDIR\UnxUtils.zip" "$EXEDIR\TEMP" "usr\local\wbin\diff.exe"
ZipDLL::extractFile "$EXEDIR\UnxUtils.zip" "$EXEDIR\TEMP" "usr\local\wbin\sdiff.exe"
ZipDLL::extractFile "$EXEDIR\UnxUtils.zip" "$EXEDIR\TEMP" "usr\local\wbin\cmp.exe"
ZipDLL::extractFile "$EXEDIR\UnxUtils.zip" "$EXEDIR\TEMP" "usr\local\wbin\diff3.exe"
CopyFiles "$EXEDIR\TEMP\usr\local\wbin\*.exe" "$perlDir\Perl\bin"

StrCpy $pubDir "$twinst\\pub"
StrCpy $dataDir "$twinst\\data"
StrCpy $templateDir "$twinst\\templates"

ClearErrors
FileOpen $cfg "$twikiInstall\lib\twiki.cfg" r
FileOpen $cfg_tmp "$twikiInstall\lib\twiki_tmp.cfg" w
DetailPrint 'Configuring "$twikiInstall\lib\twiki.cfg"'
IfErrors done
readcfg1:
FileRead $cfg $1
IfErrors done
StrCpy $str $1 7
StrCmp $str "$$pubDir" +1 +3
StrCpy $1 '$$pubDir="$pubDir";$\n'
Goto endprocess

StrCpy $str $1 12
StrCmp $str "$$templateDir" +1 +3
StrCpy $1 '$$templateDir="$templateDir";$\n'
Goto endprocess

StrCpy $str $1 8
StrCmp $str "$$dataDir" +1 +3
StrCpy $1 '$$dataDir="$dataDir";$\n'
Goto endprocess

StrCpy $str $1 6
StrCmp $str "$$lsCmd" +1 +3
StrCpy $1 '$$lsCmd="$perlinst\\Perl\\bin\\ls";$\n'
Goto endprocess

StrCpy $str $1 9
StrCmp $str "$$egrepCmd" +1 +3
StrCpy $1 '$$egrepCmd="$perlinst\\Perl\\bin\\grep.exe -E";$\n'
Goto endprocess

StrCpy $str $1 9
StrCmp $str "$$fgrepCmd" +1 +3
StrCpy $1 '$$fgrepCmd="$perlinst\\Perl\\bin\\grep.exe -F";$\n'
Goto endprocess

StrCpy $str $1 9
StrCmp $str "$$fgrepCmd" +1 +3
StrCpy $1 '$$fgrepCmd="$perlinst\\Perl\\bin\\grep.exe -F";$\n'
Goto endprocess

StrCpy $str $1 15
StrCmp $str "$$storeTopicImpl" +1 +3
StrCpy $1 '$$storeTopicImpl = "RcsLite";$\n'
Goto endprocess

StrCpy $str $1 12
StrCmp $str "$$wikiHomeUrl" +1 +3
StrCpy $1 '$$wikiHomeUrl="http://localhost/$twikiVirtualDir";$\n'
Goto endprocess

StrCpy $str $1 13
StrCmp $str "$$scriptSuffix" +1 +3
StrCpy $1 '$$scriptSuffix=".pl";$\n'
Goto endprocess

endprocess:
FileWrite $cfg_tmp $1
goto readcfg1
done:
FileClose $cfg
FileClose $cfg_tmp
Delete "$twikiInstall\lib\twiki.cfg"
Rename "$twikiInstall\lib\twiki_tmp.cfg" "$twikiInstall\lib\twiki.cfg"


ClearErrors
FileOpen $cfg "$twikiInstall\bin\setlib.cfg" r
FileOpen $cfg_tmp "$twikiInstall\bin\setlib_tmp.cfg" w
DetailPrint 'Configuring "$twikiInstall\bin\setlib.cfg"'
IfErrors done2
readcfg2:
FileRead $cfg $1
IfErrors done2
StrCpy $str $1 13
StrCmp $str "$$twikiLibPath" +1 +2
StrCpy $1 '$$twikiLibPath="$twinst\\lib";$\n'

FileWrite $cfg_tmp $1
goto readcfg2
done2:
FileClose $cfg
FileClose $cfg_tmp
Delete "$twikiInstall\bin\setlib.cfg";
Rename "$twikiInstall\bin\setlib_tmp.cfg" "$twikiInstall\bin\setlib.cfg"

ClearErrors
FileOpen $cfg "$EXEDIR\myscript.vbs" r
FileOpen $cfg_tmp "$EXEDIR\TEMP\myscript.vbs" w
DetailPrint 'Configuring Site'
IfErrors done2
readcfg3:
FileRead $cfg $1
IfErrors done3

!insertmacro ReplaceSubStr $1 '$$Twiki$$' $twikiInstall
StrCpy $1 $MODIFIED_STR

!insertmacro ReplaceSubStr $1 '$$Perl$$' $perlDir
StrCpy $1 $MODIFIED_STR

!insertmacro ReplaceSubStr $1 '$$Virtual$$' $twikiVirtualDir
StrCpy $1 $MODIFIED_STR

FileWrite $cfg_tmp $1
goto readcfg3
done3:
FileClose $cfg
FileClose $cfg_tmp
nsExec::ExecToLog '"cscript" $EXEDIR\TEMP\myscript.vbs'

DetailPrint 'Configuring Access Control for $twikiInstall'
FileOpen $cfg "$EXEDIR\TEMP\mybat.bat" w
FileWrite $cfg 'echo y|cacls.exe "$twikiInstall" /T /G Everyone:F$\n'
FileWrite $cfg 'ren "$twikiInstall\bin\*." *.pl'
FileClose $cfg 
nsExec::ExecToLog $EXEDIR\TEMP\mybat.bat

RMDir /r "$EXEDIR\TEMP"
SectionEnd