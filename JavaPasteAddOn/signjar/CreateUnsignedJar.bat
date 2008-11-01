@echo off
call SetupEnv.bat


copy %SOURCEFILES% %TEMPDIR%

jar cvf %UNSIGNEDJAR% -C %TEMPBASEDIR% %PACKAGE%
