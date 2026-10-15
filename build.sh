#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
stage=$(mktemp -d /private/tmp/pdf417-build.XXXXXX)
trap 'rm -rf "$stage"' EXIT
output="${PDF417_OUTPUT_DIR:-$PWD/dist}"
mkdir -p "$output"
for arch in arm64 x86_64; do
  xcrun swiftc main.swift -O -target "$arch-apple-macos13.0" -module-cache-path "$stage/cache-$arch" -framework AppKit -framework CoreImage -framework Network -framework UniformTypeIdentifiers -framework Vision -o "$stage/PDF417-$arch"
done
app="$stage/PDF417 Creator.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
lipo -create "$stage/PDF417-arm64" "$stage/PDF417-x86_64" -output "$app/Contents/MacOS/PDF417 Creator"
cp Info.plist "$app/Contents/Info.plist"
cp Assets/AppIcon.icns LICENSE "$app/Contents/Resources/"
codesign --force --deep --sign - "$app"
codesign --verify --deep --strict "$app"
ditto -c -k --norsrc --noextattr --keepParent "$app" "$output/PDF417-Creator-2.7-macOS-universal.zip"
print "Creado $output/PDF417-Creator-2.7-macOS-universal.zip"
