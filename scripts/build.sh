#!/bin/sh
# Builds a universal (Apple Silicon + Intel) Heads Up.app into build/ and zips it,
# together with the hook script, to dist/HeadsUp.zip. Needs the Xcode Command Line Tools.
#   sh scripts/build.sh
# The version comes from VERSION, or HEADSUP_VERSION when set (release builds).
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
VERSION="${HEADSUP_VERSION:-$(tr -d '[:space:]' < VERSION)}"
BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
PKG="build/package"
APP="$PKG/Heads Up.app"

rm -rf build dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" dist
for ARCH in arm64 x86_64; do
  swiftc -O -target "$ARCH-apple-macos12" -o "build/HeadsUp-$ARCH" Sources/HeadsUp/main.swift
done
lipo -create -output "$APP/Contents/MacOS/HeadsUp" build/HeadsUp-arm64 build/HeadsUp-x86_64

# The icon is drawn from code at build time (scripts/make-icon.swift).
swiftc -O -o build/make-icon scripts/make-icon.swift
build/make-icon build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Heads Up</string>
  <key>CFBundleDisplayName</key><string>Heads Up</string>
  <key>CFBundleIdentifier</key><string>com.fonmarketing.headsup</string>
  <key>CFBundleExecutable</key><string>HeadsUp</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key><string>12.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHumanReadableCopyright</key><string>Made by Caleb Cody, Five One Nine Marketing. MIT License.</string>
</dict>
</plist>
PLIST
codesign --force --sign - "$APP"

cp Resources/heads-up-notify.py "$PKG/heads-up-notify.py"
ditto -c -k --norsrc --noextattr --noqtn "$PKG" dist/HeadsUp.zip
echo "Built Heads Up $VERSION ($(lipo -archs "$APP/Contents/MacOS/HeadsUp")) at dist/HeadsUp.zip"
