call SetupEnv.bat

keytool -export -keystore %KEYSTORE% -storepass %STOREPASS% -alias %KEYSTOREALIAS% -file %CERTIFICATEFILE%