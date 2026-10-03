#!/bin/bash
# Build qualification only. Does not install, archive, upload, or change git history.
set -euo pipefail
cd "$(dirname "$0")/../.."
PLATFORM="${1:-all}"
case "$PLATFORM" in all|ios|tvos|mac) ;; *) echo "Usage: $0 [all|ios|tvos|mac]" >&2; exit 2 ;; esac
OUT="${VELA_VALIDATION_DIR:-build/apple-validation}"
mkdir -p "$OUT"
swift test --package-path Tools/VelaLogicTests > "$OUT/logic.log" 2>&1 || {
  tail -60 "$OUT/logic.log" >&2; exit 1;
}

build_platform() {
  local platform="$1" scheme="$2" destination="$3"
  local container=(-project Swiftfin.xcodeproj)
  if [ "$platform" = mac ]; then
    Tools/vela/prepare-mac-packages.sh
    container=(-workspace Vela.xcworkspace)
  fi
  echo "Building $platform; log: $OUT/$platform.log"
  if ! xcodebuild "${container[@]}" -scheme "$scheme" -configuration Debug \
    -destination "$destination" -derivedDataPath "$OUT/dd-$platform" \
    -skipMacroValidation -skipPackagePluginValidation build > "$OUT/$platform.log" 2>&1; then
    tail -60 "$OUT/$platform.log" >&2
    return 1
  fi
}

if [ "$PLATFORM" = all ] || [ "$PLATFORM" = ios ]; then
  build_platform ios Swiftfin 'generic/platform=iOS Simulator'
  python3 Tools/vela/verify-apple-build.py ios "$OUT/dd-ios/Build/Products/Debug-iphonesimulator/Swiftfin.app"
fi
if [ "$PLATFORM" = all ] || [ "$PLATFORM" = tvos ]; then
  build_platform tvos 'Swiftfin tvOS' 'generic/platform=tvOS Simulator'
  python3 Tools/vela/verify-apple-build.py tvos "$OUT/dd-tvos/Build/Products/Debug-appletvsimulator/Swiftfin.app"
fi
if [ "$PLATFORM" = all ] || [ "$PLATFORM" = mac ]; then
  build_platform mac Swiftfin 'platform=macOS,variant=Mac Catalyst'
fi
echo "Logic tests and requested builds passed. Device/playback and distribution checks remain separate."
