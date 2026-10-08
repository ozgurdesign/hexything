#!/usr/bin/env bash
set -euo pipefail

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

cd "$(dirname "$0")/.."
ROOT="$PWD"
APP="$ROOT/HexyThing.app"
BIN_NAME="HexyThing"

echo "==> swift build -c release"
swift build -c release
BIN="$ROOT/.build/release/$BIN_NAME"
[ -f "$BIN" ] || { echo "missing binary: $BIN"; exit 1; }

echo "==> assembling bundle"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$BIN_NAME"
cp "$ROOT/Info.plist.template" "$APP/Contents/Info.plist"
cp "$ROOT/assets/AppIcon.icns" "$APP/Contents/Resources/"
# Trailing slash makes find follow the .build/release symlink.
# SwiftPM resource bundles from dependencies (KeyboardShortcuts localizations).
find "$ROOT/.build/release/" -maxdepth 1 -name '*.bundle' -exec cp -R {} "$APP/Contents/Resources/" \;

# Screen Recording permission is tied to the app's signature. Ad-hoc signatures change on every
# build, so macOS forgets the permission. A self-signed "Code Signing" certificate keeps it stable
# (see README). Self-signed certificates are untrusted, so look them up without -v (valid only).
SIGN_IDENTITY="${HEXYTHING_SIGN_IDENTITY:-HexyThing Dev}"
if security find-identity -p codesigning | grep -q "\"$SIGN_IDENTITY\""; then
  echo "==> signing with \"$SIGN_IDENTITY\""
  codesign --force --deep --sign "$SIGN_IDENTITY" "$APP" >/dev/null
else
  echo "==> ad-hoc signing (no \"$SIGN_IDENTITY\" certificate; Screen Recording permission resets on each build)"
  codesign --force --deep --sign - "$APP" >/dev/null
fi

echo "built: $APP"
