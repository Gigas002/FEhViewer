#!/bin/bash

#source para.sh

export scripts_path=`pwd`

apk_build_path="$scripts_path/../build/app/outputs/flutter-apk/";
apk_build_tmp="$scripts_path/../build/app/outputs/tmp/";

flutter build apk
mkdir $apk_build_tmp
cp -R $apk_build_path $apk_build_tmp
flutter build apk --split-per-abi
cp -i $apk_build_tmp/*.apk $apk_build_path/*
