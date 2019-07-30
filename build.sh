#!/bin/bash

echo "Open map..."
bin/bba5.sh $1
echo "Done!"

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

copyQsbFileFailed=0
cp lua/qsb/oop.lua "$1.unpacked/maps/externalmap/qsb/oop.lua" > /dev/null 2>&1
if [ "$?" -ne "0" ]; then
	$copyQsbFileFailed=1
fi
cp lua/qsb/interaction.lua "$1.unpacked/maps/externalmap/qsb/interaction.lua" > /dev/null 2>&1
if [ "$?" -ne "0" ]; then
	$copyQsbFileFailed=1
fi
cp lua/qsb/questsystem.lua "$1.unpacked/maps/externalmap/qsb/questsystem.lua" > /dev/null 2>&1
if [ "$?" -ne "0" ]; then
	$copyQsbFileFailed=1
fi
cp lua/qsb/questbehavior.lua "$1.unpacked/maps/externalmap/qsb/questbehavior.lua" > /dev/null 2>&1
if [ "$?" -ne "0" ]; then
	$copyQsbFileFailed=1
fi
cp lua/qsb/questdebug.lua "$1.unpacked/maps/externalmap/qsb/questdebug.lua" > /dev/null 2>&1
if [ "$?" -ne "0" ]; then
	$copyQsbFileFailed=1
fi

cp lua/qsb/extraloader.lua "$1.unpacked/maps/externalmap/qsb/extraloader.lua" > /dev/null 2>&1
if [ "$?" -ne "0" ]; then
	$copyQsbFileFailed=1
fi
cp lua/qsb/information_ex2.lua "$1.unpacked/maps/externalmap/qsb/information_ex2.lua" > /dev/null 2>&1
if [ "$?" -ne "0" ]; then
	$copyQsbFileFailed=1
fi
cp lua/qsb/information_ex3.lua "$1.unpacked/maps/externalmap/qsb/information_ex3.lua" > /dev/null 2>&1
if [ "$?" -ne "0" ]; then
	$copyQsbFileFailed=1
fi
cp lua/qsb/treasure.lua "$1.unpacked/maps/externalmap/qsb/treasure.lua" > /dev/null 2>&1
if [ "$?" -ne "0" ]; then
	$copyQsbFileFailed=1
fi

if [ "$copyQsbFileFailed" -ne "0" ]; then
	echo "Failed to copy files!"
	exit 1
fi
echo "Done!"

echo "Packing map..."
bin/bba5.sh "$1.unpacked"
rm -rf "$1.unpacked"
echo "Done!"

echo "Finished! :)"
