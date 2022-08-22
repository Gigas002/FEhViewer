#!/bin/sh

source para.sh

cd $scripts_path/..
flutter build macos --release
