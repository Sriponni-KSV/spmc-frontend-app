#!/bin/bash
set -e

if [ ! -d "_flutter" ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable _flutter
fi
export PATH="$PATH:$(pwd)/_flutter/bin"

flutter config --no-analytics
flutter config --enable-web
flutter pub get
flutter build web --release