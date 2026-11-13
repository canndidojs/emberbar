#!/bin/bash
# Builds EmberBar.app (sandboxed, hardened runtime, ad-hoc signed) and EmberBar-mac.zip + SHA-256.
# Run on macOS from the mac/ directory. Output goes to mac/dist/.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/EmberBar"

rm -rf dist
APP="dist/EmberBar.app"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/EmberBar"
cp packaging/Info.plist "$APP/Contents/Info.plist"

# Ad-hoc signature (free). Hardened runtime + App Sandbox come from the flag and the entitlements.
codesign --force --options runtime --timestamp=none \
  --entitlements packaging/EmberBar.entitlements --sign - "$APP"

# Fail the build if the protections are not actually present.
codesign --verify --strict --verbose=2 "$APP"
FLAGS=$(codesign -d --verbose=2 "$APP" 2>&1)
echo "$FLAGS" | grep -q "runtime" || { echo "hardened runtime missing"; exit 1; }
ENT=$(codesign -d --entitlements - "$APP" 2>&1)
echo "$ENT" | grep -q "com.apple.security.app-sandbox" || { echo "sandbox entitlement missing"; exit 1; }

ditto -c -k --keepParent "$APP" dist/EmberBar-mac.zip
( cd dist && shasum -a 256 EmberBar-mac.zip | tee EmberBar-mac.zip.sha256 )
