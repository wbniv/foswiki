cd c:\eclipse\workspace\JavaPasteAddOn\signjar\
call SetupEnv.bat

keytool -list -storepass %STOREPASS% -keystore %KEYSTORE%
pause

