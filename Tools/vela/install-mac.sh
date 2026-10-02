#!/bin/bash
# Builds the Mac app (Mac Catalyst build of Swiftfin's iOS target, Release by default)
# and installs it as /Applications/Vela.app.
#   Tools/vela/install-mac.sh
#   CONFIGURATION=Debug Tools/vela/install-mac.sh     # Debug build, stays in build/dd-mac
# The first build registers this Mac with the team (automatic signing).
set -euo pipefail
cd "$(dirname "$0")/../.."
DERIVED="${DERIVED_DATA:-build/dd-mac}"
CONFIGURATION="${CONFIGURATION:-Release}"
TARGET_APP="${TARGET_APP:-/Applications/Vela.app}"
BUNDLE_ID=$(sed -n 's/^PRODUCT_BUNDLE_IDENTIFIER\[sdk=macosx\*\] = //p' XcodeConfig/DevelopmentTeam.xcconfig)

Tools/vela/prepare-mac-packages.sh

echo "Building $CONFIGURATION for the Mac…"
BUILD_LOG="$DERIVED/install-mac-build.log"
APP="$DERIVED/Build/Products/$CONFIGURATION-maccatalyst/Swiftfin.app"
mkdir -p "$DERIVED"
# An incremental build copies a new provisioning profile (e.g. after registering another Mac)
# without signing the app again; building the app bundle from scratch avoids a broken signature.
rm -rf "$APP"
# -skipMacroValidation: Swiftfin's packages use Swift macros that would otherwise need a one-time approval in Xcode.
if ! xcodebuild -workspace Vela.xcworkspace -scheme "Swiftfin" -configuration "$CONFIGURATION" \
  -destination 'platform=macOS,variant=Mac Catalyst' -derivedDataPath "$DERIVED" \
  -skipMacroValidation -skipPackagePluginValidation \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration build > "$BUILD_LOG" 2>&1; then
  grep -E "error:|\*\* BUILD" "$BUILD_LOG" | grep -v SwiftFormat | head -20 >&2
  echo "Build failed; full log: $BUILD_LOG" >&2
  exit 1
fi
[ -d "$APP" ] || { echo "Build produced no $APP" >&2; exit 1; }
codesign --verify --deep --strict "$APP" || { echo "$APP is not validly signed" >&2; exit 1; }
[ "$CONFIGURATION" = Release ] || { echo "Built $APP"; exit 0; }

# Only ever replace our own app.
if [ -d "$TARGET_APP" ]; then
  existing=$(defaults read "$TARGET_APP/Contents/Info" CFBundleIdentifier 2>/dev/null || true)
  [ "$existing" = "$BUNDLE_ID" ] || { echo "$TARGET_APP belongs to $existing, not replacing it." >&2; exit 1; }
  osascript -e "tell application id \"$BUNDLE_ID\" to quit" 2>/dev/null || true
  sleep 1
  rm -rf "$TARGET_APP"
fi
ditto "$APP" "$TARGET_APP"
echo "Installed $TARGET_APP."
open "$TARGET_APP"
