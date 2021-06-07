#!/bin/bash

echo "Open map..."
bin/bba5.sh $1
echo "Done!"
exit 0

echo "Copy mapscript..."
cp $2 "$1.unpacked/maps/externalmap/mapscript.lua" > /dev/null 2>&1
if [ "$?" -ne "0" ]; then
	echo "Copying file $2 failed!"
	exit 1
fi
echo "Done!"

echo "Copy qsb files..."

oldPWD=$PWD
cd "$1.unpacked/maps/externalmap"
mkdir "qsb"
cd "$oldPWD"

cp lua/qsb/loader.lua "$1.unpacked/maps/externalmap/qsb/loader.lua" > /dev/null 2>&1
cp lua/qsb/multiplayermapscript.lua "$1.unpacked/maps/externalmap/qsb/multiplayermapscript.lua" > /dev/null 2>&1

cp -r lua/qsb/lib "$1.unpacked/maps/externalmap/qsb/lib" > /dev/null 2>&1
cp -r lua/qsb/ext "$1.unpacked/maps/externalmap/qsb/ext" > /dev/null 2>&1
cp -r lua/qsb/ext "$1.unpacked/maps/externalmap/qsb/s5c" > /dev/null 2>&1

rm -rf "$1.unpacked/maps/externalmap/qsb/s5c/.git" > /dev/null 2>&1

echo "Done!"

echo "Packing map..."
bin/bba5.sh "$1.unpacked"
rm -rf "$1.unpacked"
echo "Done!"

echo "Finished! :)"
