set SrcDir=build\windows\runner\Release
set DestDir=bin\windows\fehviewer

del /f /q %DestDir%
mkdir %DestDir%

xcopy /e /h /q /y %SrcDir% %DestDir%
xcopy /y windows\sqlite3.dll %SrcDir%\sqlite3.dll
