#!/bin/bash
set -e

# Increase Dart heap limit to prevent dart2js out-of-memory on Vercel VMs
export DART_VM_OPTIONS="--old_gen_heap_size=2560"

echo "=== 1. Setting up Flutter SDK ==="
if [ ! -d "$HOME/flutter" ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
fi

export PATH="$PATH:$HOME/flutter/bin"

echo "=== 2. Flutter Version ==="
flutter --version

echo "=== 3. Enabling Web & Dependencies ==="
flutter config --enable-web
flutter pub get

echo "=== 4. Building Flutter Web ==="
# --no-source-maps: Prevents generating large source map files that exhaust Vercel RAM
# --no-tree-shake-icons: Skips heavy icon tree-shaking that spikes CPU & RAM
BUILD_FLAGS="--release --no-source-maps --no-tree-shake-icons"

if [ -n "$BASE_URL" ]; then
  echo "Building with BASE_URL=$BASE_URL"
  flutter build web $BUILD_FLAGS --dart-define=BASE_URL="$BASE_URL"
else
  flutter build web $BUILD_FLAGS
fi

echo "=== 5. Build Complete ==="
test -f build/web/index.html
echo "Flutter web compiled successfully to build/web!"
