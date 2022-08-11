@REM Pack release
set SrcDir=build\windows\runner\Release
set DestDir=build\windows\fehviewer

del /f /q %DestDir%
mkdir %DestDir%

xcopy /e /h /q /y %SrcDir% %DestDir%
xcopy /y windows\*.dll %DestDir%\*.dll

cd build/windows/ && 7z a ../windows.zip fehviewer/*
