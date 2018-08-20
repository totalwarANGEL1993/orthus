bin/bba5.exe %1

xcopy /S %2 %1 and ".unpacked/maps/externalmap/mapscript.lua"

set oldPWD=%CD%
cd %1 and ".unpacked/maps/externalmap"
if not exist "qsb" mkdir qsb
cd %oldPWD%

xcopy /S lua/qsb/oop.lua %1 and ".unpacked/maps/externalmap/qsb/oop.lua"
xcopy /S lua/qsb/oop.lua %1 and ".unpacked/maps/externalmap/qsb/interaction.lua"
xcopy /S lua/qsb/oop.lua %1 and ".unpacked/maps/externalmap/qsb/questsystem.lua"
xcopy /S lua/qsb/oop.lua %1 and ".unpacked/maps/externalmap/qsb/questbehavior.lua"
xcopy /S lua/qsb/oop.lua %1 and ".unpacked/maps/externalmap/qsb/questdebug.lua"

bin/bba5.exe %1 and "$.unpacked"
RMDIR /S /Q %1 and "$.unpacked"

pause