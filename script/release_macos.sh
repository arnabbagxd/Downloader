#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MediaDownloader"            # internal executable / SwiftPM product name
DISPLAY_NAME="Download It"            # user-facing app name (bundle + Finder)
ARTIFACT_NAME="DownloadIt"           # slug for release archive filenames (no spaces)
BUNDLE_ID="${BUNDLE_ID:-com.arnabbagxd.downloadit}"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -f ".env" ]]; then
  set -a
  source ".env"
  set +a
fi

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

resolve_repo_slug() {
  if [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
    printf '%s\n' "$GITHUB_REPOSITORY"
    return
  fi

  local remote_url
  remote_url="$(git remote get-url origin 2>/dev/null || true)"

  case "$remote_url" in
    git@github.com:*.git)
      printf '%s\n' "${remote_url#git@github.com:}" | sed 's/\.git$//'
      ;;
    https://github.com/*)
      printf '%s\n' "${remote_url#https://github.com/}" | sed 's/\.git$//'
      ;;
    *)
      fail "could not determine GitHub repository. Set GITHUB_REPOSITORY=owner/repo or add an origin remote"
      ;;
  esac
}

notarytool_args() {
  if [[ -n "${APPLE_API_KEY_ID:-}" && -n "${APPLE_API_ISSUER_ID:-}" && -n "${APPLE_API_KEY_PATH:-}" ]]; then
    [[ -f "$APPLE_API_KEY_PATH" ]] || fail "APPLE_API_KEY_PATH does not exist: $APPLE_API_KEY_PATH"
    printf '%s\n' "--key" "$APPLE_API_KEY_PATH" "--key-id" "$APPLE_API_KEY_ID" "--issuer" "$APPLE_API_ISSUER_ID"
    return
  fi

  if [[ -n "${APPLE_ID:-}" && -n "${APPLE_ID_PASSWORD:-}" && -n "${APPLE_TEAM_ID:-}" ]]; then
    printf '%s\n' "--apple-id" "$APPLE_ID" "--password" "$APPLE_ID_PASSWORD" "--team-id" "$APPLE_TEAM_ID"
    return
  fi

  fail "provide App Store Connect API key envs or Apple ID notarization envs"
}

version_from_tag() {
  printf '%s\n' "${1#v}"
}

require_command git
require_command gh
require_command swift
require_command codesign
require_command xcrun
require_command hdiutil

gh auth status >/dev/null 2>&1 || fail "gh is not authenticated. Run: gh auth login"
[[ -n "${MEDIA_DOWNLOADER_DEVELOPER_ID:-}" ]] || fail "MEDIA_DOWNLOADER_DEVELOPER_ID is required"

TAG="${1:-}"
[[ -n "$TAG" ]] || fail "usage: $0 v<version>"
VERSION="$(version_from_tag "$TAG")"
REPO_SLUG="$(resolve_repo_slug)"
ARCH="$(uname -m)"
RELEASE_DIR="$ROOT_DIR/dist/release"
APP_BUNDLE="$RELEASE_DIR/$DISPLAY_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
APP_ICON="$ROOT_DIR/Resources/AppIcon.icns"
NOTARY_ZIP="$RELEASE_DIR/$ARTIFACT_NAME-notary.zip"
RELEASE_ZIP="$RELEASE_DIR/$ARTIFACT_NAME-macos-$ARCH.zip"
RELEASE_DMG="$RELEASE_DIR/$ARTIFACT_NAME-macos-$ARCH.dmg"

if [[ "${ALLOW_DIRTY_RELEASE:-false}" != "true" && -n "$(git status --porcelain)" ]]; then
  fail "working tree is dirty. Commit or stash changes first, or set ALLOW_DIRTY_RELEASE=true"
fi

swift test
swift build -c release
BUILD_BINARY="$(swift build -c release --show-bin-path)/$APP_NAME"

rm -rf "$RELEASE_DIR"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
cp "$APP_ICON" "$APP_RESOURCES/AppIcon.icns"

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
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>${APP_BUILD:-1}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

codesign --force --deep --options runtime --timestamp --sign "$MEDIA_DOWNLOADER_DEVELOPER_ID" "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

/usr/bin/ditto -c -k --keepParent "$APP_BUNDLE" "$NOTARY_ZIP"
NOTARY_ARGS=()
while IFS= read -r arg; do
  NOTARY_ARGS+=("$arg")
done < <(notarytool_args)
xcrun notarytool submit "$NOTARY_ZIP" "${NOTARY_ARGS[@]}" --wait
xcrun stapler staple "$APP_BUNDLE"
xcrun stapler validate "$APP_BUNDLE"
spctl -a -vvv --type exec "$APP_BUNDLE"

rm -f "$RELEASE_ZIP"
/usr/bin/ditto -c -k --keepParent "$APP_BUNDLE" "$RELEASE_ZIP"
"$ROOT_DIR/script/create_dmg.sh" "$APP_BUNDLE" "$RELEASE_DMG" "$DISPLAY_NAME"
codesign --force --timestamp --sign "$MEDIA_DOWNLOADER_DEVELOPER_ID" "$RELEASE_DMG"
codesign --verify --verbose=2 "$RELEASE_DMG"
xcrun notarytool submit "$RELEASE_DMG" "${NOTARY_ARGS[@]}" --wait
xcrun stapler staple "$RELEASE_DMG"
xcrun stapler validate "$RELEASE_DMG"
spctl -a -vvv -t open --context context:primary-signature "$RELEASE_DMG"
rm -f "$NOTARY_ZIP"

if ! git rev-parse "$TAG" >/dev/null 2>&1; then
  git tag "$TAG"
fi

if ! git ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null 2>&1; then
  git push origin "$TAG"
fi

if gh release view "$TAG" --repo "$REPO_SLUG" >/dev/null 2>&1; then
  gh release upload "$TAG" "$RELEASE_ZIP" "$RELEASE_DMG" --repo "$REPO_SLUG" --clobber
else
  gh release create "$TAG" "$RELEASE_ZIP" "$RELEASE_DMG" \
    --repo "$REPO_SLUG" \
    --title "$TAG" \
    --generate-notes
fi

printf 'released %s to https://github.com/%s/releases/tag/%s\n' "$TAG" "$REPO_SLUG" "$TAG"
