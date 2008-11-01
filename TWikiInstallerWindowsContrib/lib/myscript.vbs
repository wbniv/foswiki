Set rt = GetObject("IIS://localhost/W3SVC/1/Root")
Set root = rt.Create("IIsWebVirtualDir","$Virtual$")
root.Path="$Twiki$"
root.AppCreate2(True)
root.AppIsolated=2
root.EnableDirBrowsing=True
root.DirBrowseShowLongDate=True
root.ScriptMaps=".pl,""$Perl$\Perl\bin\perl.exe"" -T -I""$Twiki$\bin"" -I""$Twiki$\lib"" ""%s"" ""%s"",1"
root.setInfo
Set serv = GetObject("IIS://localhost/W3SVC/1")
serv.Stop
serv.Start