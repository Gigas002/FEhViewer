#!/bin/sh
# shellcheck disable=SC2034

ios_archiver_path="$scripts_path/../build/ios/archive/fehviewer.xcarchive/Products/Applications/FEhViewer.app"
ipa_plist_path="$ios_archiver_path/Info.plist"
release_bundle_identifier='cn.honjow.fehv'
ios_build_path="$scripts_path/../build/ios"

echo $version
if [ $version -eq 0 ];
then
    echo "version empty"
    exit
fi

# reid.sh

plist_key="CFBundleIdentifier"

/usr/libexec/PlistBuddy -c "Set :$plist_key $release_bundle_identifier" $ipa_plist_path

# zip.sh

# TODO: $version
ipa_name="feh_$1.ipa"
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
# zip -qro $ipa_path "Payload" && mv $ipa_path $output_version_dir
7z a $ipa_path "Payload" && mv $ipa_path $output_version_dir

# dsym.sh

# $scripts_path/../ios/Pods/FirebaseCrashlytics/upload-symbols -gsp $scripts_path/../ios/Runner/GoogleService-Info.plist -p ios $scripts_path/../build/ios/archive/fehviewer.xcarchive/dSYMs
