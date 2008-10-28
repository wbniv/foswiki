
@echo on

keytool -delete -alias %KEYSTOREALIAS% -keystore %KEYSTORE% -keypass %KEYPASS% -storepass %STOREPASS%

keytool -genkey -alias %KEYSTOREALIAS% -keystore %KEYSTORE% -keypass %KEYPASS% -dname "cn=MRJC.COM" -storepass %STOREPASS%

jarsigner -keystore %KEYSTORE% -storepass %STOREPASS% -keypass %KEYPASS% -signedjar %SIGNEDJAR% %UNSIGNEDJAR% %KEYSTOREALIAS%
pause
