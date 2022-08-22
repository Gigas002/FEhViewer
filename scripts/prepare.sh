#!/bin/sh

# Only for ios/macos build

flutter clean
flutter pub get
pod update
pod install
