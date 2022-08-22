#!/bin/sh
# shellcheck disable=SC2034

source para.sh

# dmg.sh

macos_archiver_path="${scripts_path}/../build/macos/Build/Products/Release/fehviewer.app"
macos_build_path="$scripts_path/../build/macos"

dmg(){
  echo "hdiutil create -fs HFS+ -srcfolder $version -volname $2 $3.dmg"
  hdiutil create -fs HFS+ -srcfolder "$version" -volname "$2" "$3.dmg"
}

macos_temp_dir="macos_temp"
macos_temp_file_name="feh_$version"
macos_temp_path="$macos_build_path/$macos_temp_dir";

bin_dir="$macos_build_path/fehviewer";

rm -rf $macos_temp_path
mkdir $macos_temp_path

rm -rf $bin_dir
mkdir $bin_dir

cp -a $macos_archiver_path $macos_temp_path

cd $bin_dir || exit
dmg $macos_temp_path "fehviewer" $macos_temp_file_name

# Pack release
cd "$scripts_path/../build/macos/" && 7z a ../macos.zip fehviewer/*
