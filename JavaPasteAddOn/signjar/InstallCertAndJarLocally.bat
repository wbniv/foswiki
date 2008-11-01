call SetupEnv.bat

cd %TEMPBASEDIR%

call %SCRIPTDIR%\ClearTempFiles.bat

call %SCRIPTDIR%\CreateUnsignedJar.bat

call %SCRIPTDIR%\SignJar.bat

call %SCRIPTDIR%\GenerateCertificate.bat

call %SCRIPTDIR%\InstallCert.bat

cd %SCRIPTDIR% 

