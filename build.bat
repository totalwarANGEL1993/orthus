run bin/bba5.exe %1

xcopy /S %2 %1 and ".unpacked/maps/externalmap/mapscript.lua"

echo "Open map..."
set oldPWD=%CD%
cd %1 and ".unpacked/maps/externalmap"
if not exist "qsb" mkdir qsb
cd %oldPWD%
echo "Done!"

echo "Copy qsb files..."

xcopy /S lua/qsb/loader.lua %1 and ".unpacked/maps/externalmap/qsb/loader.lua"
xcopy /S lua/qsb/multiplayermapscript.lua %1 and ".unpacked/maps/externalmap/qsb/multiplayermapscript.lua"

xcopy lua/qsb/lib %1 and ".unpacked/maps/externalmap/qsb/lib" /E
xcopy lua/qsb/ext %1 and ".unpacked/maps/externalmap/qsb/ext" /E
xcopy lua/qsb/ext %1 and ".unpacked/maps/externalmap/qsb/s5c" /E

RMDIR /S /Q %1 and "$.unpacked/maps/externalmap/qsb/s5c/.git"

echo "Done!"

echo "Packing map..."
bin/bba5.exe %1 and "$.unpacked"
RMDIR /S /Q %1 and "$.unpacked"
echo "Done!"

echo "Finished! :)"
pause