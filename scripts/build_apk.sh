#!/bin/sh

source para.sh
apk_build_path="$scripts_path/../build/app/outputs/apk/release/";
apk_build_path_universal="$scripts_path/../build/app/outputs/apk/releaseUniversal/";

#flutter build apk --target-platform android-arm,android-arm64,android-x64 --split-per-abi
flutter build apk
cp -R $apk_build_path $apk_build_path_universal
flutter build apk --split-per-abi
cp $apk_build_path_universal/*.apk $apk_build_path/*