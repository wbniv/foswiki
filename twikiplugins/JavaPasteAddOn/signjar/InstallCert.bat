call SetupEnv.bat

keytool -delete -alias user -keystore %KEYSTORE% -storepass %STOREPASS%
pause

keytool -import -alias user -file %CERTIFICATEFILE% -keystore %KEYSTORE% -storepass %STOREPASS%
pause
	