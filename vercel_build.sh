#!/bin/bash
set -e

git clone https://github.com/flutter/flutter.git --depth 1 -b stable _flutter
export PATH="$PATH:$(pwd)/_flutter/bin"

flutter config --enable-web
flutter doctor -v
flutter pub get
flutter build web --release
