#!/bin/zsh
# shellcheck disable=SC2034

export macos_build_path="${scripts_path}/../build/macos"

dmg(){
  echo "hdiutil create -fs HFS+ -srcfolder $1 -volname $2 $3.dmg"
  hdiutil create -fs HFS+ -srcfolder "$1" -volname "$2" "$3.dmg"
}

version=$1

if [ $# -eq 0 ];
then
    echo "version empty"
    exit
fi

macos_temp_dir="macos_temp"
macos_temp_file_name="feh_$version"
macos_temp_path="${macos_build_path}/$macos_temp_dir";

version_dir="$macos_build_path/macos_$version";

temp_file_path="$macos_temp_path/$macos_temp_file_name"

echo $macos_temp_path
echo $version_dir

rm -rf $macos_temp_path
mkdir $macos_temp_path

rm -rf $version_dir
mkdir $version_dir

cp -a $macos_archiver_path $macos_temp_path

cd $version_dir || exit
echo "cd $version_dir"
dmg $macos_temp_path "fehviewer" $macos_temp_file_name
