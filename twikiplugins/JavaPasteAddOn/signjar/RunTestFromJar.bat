cd c:\eclipse\workspace\JavaPasteAddOn\signjar\

rem call RunInstallCertEclipse.bat

call SetupEnv.bat

copy %TESTFILESSRCDIR%\*.htm %JAVAPASTEDIR%
cd %JAVAPASTEDIR%
start testFromJar.htm
