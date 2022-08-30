#!/bin/bash

#source para.sh

export scripts_path=`pwd`

apk_build_path="$scripts_path/../build/app/outputs/flutter-apk/";
apk_build_tmp="$scripts_path/../build/app/outputs/tmp/";

flutter build apk
mkdir $apk_build_tmp

echo "Test1"
ls -lR $apk_build_path
ls -lR $apk_build_tmp

cp -R $apk_build_path $apk_build_tmp

echo "Test2"
ls -lR $apk_build_path
ls -lR $apk_build_tmp

flutter build apk --split-per-abi

echo "Test3"
ls -lR $apk_build_path
ls -lR $apk_build_tmp

cp -i $apk_build_tmp/* $apk_build_path/*

echo "Test4"
ls -lR $apk_build_path
ls -lR $apk_build_tmp
