#!/bin/zsh
# shellcheck disable=SC2034
version=$1

if [ $# -eq 0 ];
then
    echo "version empty"
    exit
fi

export ios_build_path="${scripts_path}/../build/ios"

ipa_name="feh_$version.ipa"
ipa_temp_dir="$ios_build_path/temp";
ipa_payload_dir="$ios_build_path/temp/Payload";

output_version_dir="$ios_build_path/$version";

ipa_path="$ipa_temp_dir/$ipa_name"

rm -rf $ipa_temp_dir
mkdir $ipa_temp_dir
mkdir $ipa_payload_dir
rm -rf $output_version_dir
mkdir $output_version_dir

cp -r $ios_archiver_path $ipa_payload_dir

cd $ipa_temp_dir || exit
zip -qro $ipa_path "Payload" && mv $ipa_path $output_version_dir
