#!/bin/bash
# Builds the fork (Release by default) and installs + launches it on a paired Apple TV.
#   Tools/vela/install-device.sh                 # first paired Apple TV
#   Tools/vela/install-device.sh "Wohnzimmer"    # by device name (substring)
# Pairing works as for Vela: xcrun devicectl manage pair --device "<Apple TV name>".
set -euo pipefail
cd "$(dirname "$0")/../.."
NAME="${1:-}"
DERIVED="${DERIVED_DATA:-build/dd-device}"
CONFIGURATION="${CONFIGURATION:-Release}"
BUNDLE_ID=$(sed -n 's/^PRODUCT_BUNDLE_IDENTIFIER = //p' XcodeConfig/DevelopmentTeam.xcconfig)
UDID=$(xcrun devicectl list devices --json-output /dev/stdout 2>/dev/null | python3 -c "
import json,sys
d=json.load(sys.stdin)
devs=[x for x in d['result']['devices'] if 'AppleTV' in (x.get('hardwareProperties',{}).get('productType','')) and x.get('hardwareProperties',{}).get('reality')!='simulated' and x.get('deviceProperties',{}).get('name')]
name='$NAME'.lower()
for x in devs:
    if not name or name in x['deviceProperties']['name'].lower():
        print(x['identifier']); break
")
[ -n "$UDID" ] || { echo "No paired physical Apple TV found." >&2; exit 1; }
echo "Building $CONFIGURATION for device…"
BUILD_LOG="$DERIVED/install-device-build.log"
mkdir -p "$DERIVED"
# -skipMacroValidation: Swiftfin's packages use Swift macros that would otherwise need a one-time approval in Xcode.
if ! xcodebuild -project Swiftfin.xcodeproj -scheme "Swiftfin tvOS" -configuration "$CONFIGURATION" -destination "platform=tvOS,id=$UDID" \
  -derivedDataPath "$DERIVED" -skipMacroValidation -skipPackagePluginValidation \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration build > "$BUILD_LOG" 2>&1; then
  grep -E "error:|\*\* BUILD" "$BUILD_LOG" | grep -v SwiftFormat | head -20 >&2
  echo "Build failed; full log: $BUILD_LOG" >&2
  exit 1
fi
APP="$DERIVED/Build/Products/$CONFIGURATION-appletvos/Swiftfin.app"
[ -d "$APP" ] || { echo "Build produced no $APP" >&2; exit 1; }
echo "Installing $BUNDLE_ID on ${UDID}…"
xcrun devicectl device install app --device "$UDID" "$APP"
# A sleeping Apple TV refuses foreground launches; the app is installed either way.
if xcrun devicectl device process launch --device "$UDID" "$BUNDLE_ID" > /dev/null 2>&1; then
  echo "Installed and running on the Apple TV."
else
  echo "Installed. Not launched (the Apple TV is probably asleep)."
fi
