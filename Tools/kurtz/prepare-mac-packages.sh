#!/bin/bash
# Prepares the two packages the Mac build needs in a fixed form (kurtz.xcworkspace uses them
# in place of the remote ones, at the revisions Swiftfin.xcodeproj pins):
# - BlurHashKit treats Mac Catalyst as AppKit and does not compile there.
# - The Mac Catalyst slice of MPVUI's Libmpv.xcframework is an iOS-style (shallow) bundle,
#   which Xcode refuses to embed in a Mac app; it is turned into a versioned bundle.
# Run by install-mac.sh; run it by hand before opening kurtz.xcworkspace in Xcode.
set -euo pipefail
cd "$(dirname "$0")/../.."
OUT=build/mac-packages
RESOLVED=Swiftfin.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
mkdir -p "$OUT"

pin() {
  python3 -c "
import json,sys
pins=json.load(open('$RESOLVED'))['pins']
p=next(p for p in pins if p['identity']=='$1')
print(p['location'], p['state']['revision'])"
}

# checkout <identity> <dir>: the pinned revision of a package, unless already prepared
# (done_ <dir> marks it prepared).
checkout() {
  local dir="$OUT/$2" url rev
  read -r url rev < <(pin "$1")
  if [ "$(cat "$dir/.kurtz-revision" 2>/dev/null)" = "$rev" ]; then
    return 1
  fi
  echo "Fetching $2 at ${rev:0:7}…"
  rm -rf "$dir"
  git init -q "$dir"
  git -C "$dir" fetch -q --depth 1 "$url" "$rev"
  git -C "$dir" checkout -q FETCH_HEAD
}

done_() {
  git -C "$OUT/$1" rev-parse HEAD > "$OUT/$1/.kurtz-revision"
}

# BlurHashKit: use UIKit on Mac Catalyst.
if checkout blurhashkit BlurHashKit; then
  sed -i '' 's/#if canImport(AppKit)$/#if canImport(AppKit) \&\& !targetEnvironment(macCatalyst)/' \
    "$OUT/BlurHashKit/Sources/BlurHashKit/"*.swift
  done_ BlurHashKit
fi

# MPVUI: local copy of Libmpv.xcframework with a versioned Mac Catalyst slice.
if checkout mpvui MPVUI; then
  dir="$OUT/MPVUI"
  url=$(sed -n 's/.*binaryTarget(name: "Libmpv-GPL", url: "\([^"]*\)".*/\1/p' "$dir/Package.swift")
  sum=$(sed -n 's/.*binaryTarget(name: "Libmpv-GPL", url: .*checksum: "\([^"]*\)".*/\1/p' "$dir/Package.swift")
  [ -n "$url" ] && [ -n "$sum" ] || { echo "MPVUI: Libmpv binary target not found in Package.swift" >&2; exit 1; }
  zip="$OUT/Libmpv-$sum.zip"
  # SwiftPM's cache usually has the archive already.
  cached="$HOME/Library/Caches/org.swift.swiftpm/artifacts/$(echo "$url" | sed 's/[^A-Za-z0-9]/_/g')"
  [ -f "$zip" ] || { [ -f "$cached" ] && cp "$cached" "$zip"; } || true
  if [ ! -f "$zip" ] || [ "$(shasum -a 256 "$zip" | cut -d' ' -f1)" != "$sum" ]; then
    echo "Downloading Libmpv.xcframework…"
    curl -fL --retry 3 -o "$zip" "$url"
  fi
  [ "$(shasum -a 256 "$zip" | cut -d' ' -f1)" = "$sum" ] || { echo "Libmpv archive checksum mismatch" >&2; exit 1; }
  ditto -x -k "$zip" "$dir"
  sed -i '' "s|binaryTarget(name: \"Libmpv-GPL\", url: .*)|binaryTarget(name: \"Libmpv-GPL\", path: \"Libmpv.xcframework\")|" "$dir/Package.swift"

  fw=$(find "$dir/Libmpv.xcframework" -maxdepth 2 -path '*maccatalyst/Libmpv.framework')
  [ -n "$fw" ] || { echo "No Mac Catalyst slice in Libmpv.xcframework" >&2; exit 1; }
  (
    cd "$fw"
    mkdir -p Versions/A/Resources
    for entry in *; do
      [ "$entry" = Versions ] && continue
      if [ "$entry" = Info.plist ]; then mv Info.plist Versions/A/Resources/; else mv "$entry" Versions/A/; fi
    done
    ln -s A Versions/Current
    for entry in Versions/A/*; do ln -s "Versions/Current/$(basename "$entry")" "$(basename "$entry")"; done
  )
  done_ MPVUI
fi

# The workspace resolves on its own; start it from the project's pins.
mkdir -p kurtz.xcworkspace/xcshareddata/swiftpm
cp "$RESOLVED" kurtz.xcworkspace/xcshareddata/swiftpm/Package.resolved
echo "Mac packages ready in $OUT."
