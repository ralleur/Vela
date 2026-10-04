#!/bin/bash
# Prepare a local release archive; never exports or uploads it.
set -euo pipefail
cd "$(dirname "$0")/../.."
case "${1:-}" in
  ios) SCHEME=Swiftfin; DESTINATION='generic/platform=iOS' ;;
  tvos) SCHEME='Swiftfin tvOS'; DESTINATION='generic/platform=tvOS' ;;
  *) echo "Usage: $0 ios|tvos" >&2; exit 2 ;;
esac
PLATFORM="$1"
OUT="${KURTZ_ARCHIVE_DIR:-build/apple-release}"
mkdir -p "$OUT"
echo "Preparing local $PLATFORM archive. This is not App Store clearance."
echo "Release gates: docs/release/apple-release-plan.md"
xcodebuild -project Swiftfin.xcodeproj -scheme "$SCHEME" -configuration Release \
  -destination "$DESTINATION" -archivePath "$OUT/kurtz-$PLATFORM.xcarchive" \
  -derivedDataPath "$OUT/dd-$PLATFORM" -skipMacroValidation -skipPackagePluginValidation \
  -allowProvisioningUpdates archive > "$OUT/$PLATFORM-archive.log" 2>&1 || {
    tail -60 "$OUT/$PLATFORM-archive.log" >&2; exit 1;
  }
python3 Tools/kurtz/verify-apple-build.py "$PLATFORM" "$OUT/kurtz-$PLATFORM.xcarchive/Products/Applications/kurtz.app"
echo "Archive: $OUT/kurtz-$PLATFORM.xcarchive. Nothing uploaded."
