#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

VERSION="$(tr -d '[:space:]' < VERSION)"
BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null || echo 1)"

swift build -c release
APP="build/TypeClipboard.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/TypeClipboard" "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"

# Archivio distribuibile
(cd build && rm -f "TypeClipboard-$VERSION.zip" && ditto -c -k --keepParent TypeClipboard.app "TypeClipboard-$VERSION.zip")

echo "✅ Creato $APP (v$VERSION, build $BUILD_NUMBER)"
echo "   Archivio: build/TypeClipboard-$VERSION.zip"
echo "   Installa con: cp -R $APP /Applications/"
