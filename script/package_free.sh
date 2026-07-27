#!/usr/bin/env bash
# Builds a FREE, ad-hoc-signed release DMG — no Apple Developer account required.
# The app is NOT notarized, so first-time users must "Open Anyway" once (see docs/INSTALL.md).
# Ad-hoc signing is what keeps macOS from showing the un-bypassable "app is damaged" error.
set -euo pipefail

APP_NAME="MediaDownloader"            # internal executable / SwiftPM product name
DISPLAY_NAME="Download It"            # user-facing app name (bundle + Finder)
ARTIFACT_NAME="DownloadIt"           # slug for the DMG filename (no spaces)
BUNDLE_ID="${BUNDLE_ID:-com.arnabbagxd.downloadit}"
MIN_SYSTEM_VERSION="14.0"
APP_VERSION="${APP_VERSION:-1.1.1}"
APP_BUILD="${APP_BUILD:-1}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() { printf 'error: %s\n' "$1" >&2; exit 1; }
require_command() { command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"; }

require_command swift
require_command codesign
require_command hdiutil
require_command lipo

RELEASE_DIR="$ROOT_DIR/dist/release"
APP_BUNDLE="$RELEASE_DIR/$DISPLAY_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
APP_ICON="$ROOT_DIR/Resources/AppIcon.icns"
RELEASE_DMG="$RELEASE_DIR/$ARTIFACT_NAME-macos-universal.dmg"

# Universal build without full Xcode: build each arch separately, then merge with lipo.
# One binary that runs on both Apple-chip (arm64) and Intel (x86_64) Macs.
ARM_TRIPLE="arm64-apple-macosx${MIN_SYSTEM_VERSION}"
INTEL_TRIPLE="x86_64-apple-macosx${MIN_SYSTEM_VERSION}"

printf 'Building arm64 (Apple chip)...\n'
swift build -c release --triple "$ARM_TRIPLE"
ARM_BINARY="$(swift build -c release --triple "$ARM_TRIPLE" --show-bin-path)/$APP_NAME"

printf 'Building x86_64 (Intel)...\n'
swift build -c release --triple "$INTEL_TRIPLE"
INTEL_BINARY="$(swift build -c release --triple "$INTEL_TRIPLE" --show-bin-path)/$APP_NAME"

UNIVERSAL_BINARY="$RELEASE_DIR/$APP_NAME-universal"
mkdir -p "$RELEASE_DIR"
printf 'Merging into a universal binary...\n'
lipo -create "$ARM_BINARY" "$INTEL_BINARY" -output "$UNIVERSAL_BINARY"
BUILD_BINARY="$UNIVERSAL_BINARY"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
[[ -f "$APP_ICON" ]] && cp "$APP_ICON" "$APP_RESOURCES/AppIcon.icns"

printf 'Architectures in binary: %s\n' "$(lipo -archs "$APP_BINARY" 2>/dev/null || echo unknown)"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$DISPLAY_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$DISPLAY_NAME</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$APP_BUILD</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

printf 'Ad-hoc signing (free, no Apple account)...\n'
codesign --force --deep --sign - "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

printf 'Creating DMG...\n'
"$ROOT_DIR/script/create_dmg.sh" "$APP_BUNDLE" "$RELEASE_DMG" "$DISPLAY_NAME" >/dev/null

printf '\nDone. Upload this file to your GitHub release / landing page:\n'
printf '%s\n' "$RELEASE_DMG"
printf '\nNote: users must "Open Anyway" once — see docs/INSTALL.md.\n'
