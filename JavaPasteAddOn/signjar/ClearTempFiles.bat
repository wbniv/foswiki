cd c:\eclipse\workspace\JavaPasteAddOn\signjar\
call SetupEnv.bat

rmdir /S /Q %TEMPDIR%
mkdir %TEMPDIR%

del %JAVAPASTEDIR%/*.*