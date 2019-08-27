bin/bba5.exe %1

xcopy /S %2 %1 and ".unpacked/maps/externalmap/mapscript.lua"

set oldPWD=%CD%
cd %1 and ".unpacked/maps/externalmap"
if not exist "qsb" mkdir qsb
cd %oldPWD%

xcopy /S lua/qsb/oop.lua %1 and ".unpacked/maps/externalmap/qsb/oop.lua"
xcopy /S lua/qsb/interaction.lua %1 and ".unpacked/maps/externalmap/qsb/interaction.lua"
xcopy /S lua/qsb/questsystem.lua %1 and ".unpacked/maps/externalmap/qsb/questsystem.lua"
xcopy /S lua/qsb/questbehavior.lua %1 and ".unpacked/maps/externalmap/qsb/questbehavior.lua"
xcopy /S lua/qsb/questdebug.lua %1 and ".unpacked/maps/externalmap/qsb/questdebug.lua"
xcopy /S lua/qsb/extraloader.lua %1 and ".unpacked/maps/externalmap/qsb/extraloader.lua"
xcopy /S lua/qsb/information_ex2.lua %1 and ".unpacked/maps/externalmap/qsb/information_ex2.lua"
xcopy /S lua/qsb/information_ex3.lua %1 and ".unpacked/maps/externalmap/qsb/information_ex3.lua"
xcopy /S lua/qsb/timer_ex2.lua %1 and ".unpacked/maps/externalmap/qsb/timer_ex2.lua"
xcopy /S lua/qsb/timer_ex3.lua %1 and ".unpacked/maps/externalmap/qsb/timer_ex3.lua"
xcopy /S lua/qsb/treasure.lua %1 and ".unpacked/maps/externalmap/qsb/treasure.lua"
xcopy /S lua/qsb/s5hook_ex2.lua %1 and ".unpacked/maps/externalmap/qsb/s5hook_ex2.lua"

bin/bba5.exe %1 and "$.unpacked"
RMDIR /S /Q %1 and "$.unpacked"

echo "Done!"
pause