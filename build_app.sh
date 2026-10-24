#!/bin/bash
# Builds Bazaar Books.app — a self-contained macOS app around index.html.
set -e
cd "$(dirname "$0")"

APP="Bazaar Books.app"
NAME="BazaarBooks"
VERSION="1.0"

echo "▸ cleaning"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "▸ icon"
if [ ! -f AppIcon.icns ] || [ src/makeicon.swift -nt AppIcon.icns ]; then
  swiftc -O -o /tmp/bz_makeicon src/makeicon.swift -framework Cocoa
  /tmp/bz_makeicon "$PWD/icon_1024.png"
  rm -rf /tmp/bz.iconset && mkdir -p /tmp/bz.iconset
  for s in 16 32 64 128 256 512; do
    sips -z $s $s icon_1024.png --out /tmp/bz.iconset/icon_${s}x${s}.png >/dev/null
    sips -z $((s*2)) $((s*2)) icon_1024.png --out /tmp/bz.iconset/icon_${s}x${s}@2x.png >/dev/null
  done
  cp icon_1024.png /tmp/bz.iconset/icon_512x512@2x.png
  iconutil -c icns /tmp/bz.iconset -o AppIcon.icns
fi
cp AppIcon.icns "$APP/Contents/Resources/"

echo "▸ compiling"
swiftc -O -o "$APP/Contents/MacOS/$NAME" src/main.swift \
  -framework Cocoa -framework WebKit \
  -target arm64-apple-macosx11.0 2>&1 | grep -v "deprecated" || true
[ -f "$APP/Contents/MacOS/$NAME" ] || { echo "✗ compile failed"; exit 1; }

echo "▸ bundling the web app"
cp index.html config.js "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Bazaar Books</string>
  <key>CFBundleDisplayName</key><string>Bazaar Books</string>
  <key>CFBundleIdentifier</key><string>com.mixel.bazaarbooks</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleExecutable</key><string>$NAME</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>LSMinimumSystemVersion</key><string>11.0</string>
  <key>NSHumanReadableCopyright</key><string>Bazaar Books — till and ledger</string>
</dict>
</plist>
PLIST

echo "▸ signing (ad-hoc)"
codesign --force --deep --sign - "$APP" 2>/dev/null || echo "  (unsigned — still runs)"
echo "✓ built $APP"
