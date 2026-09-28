#!/bin/bash
# Moves the fork onto the newest Swiftfin release (or a given ref) and checks that it still builds.
#   Tools/vela/update-upstream.sh          # newest release tag
#   Tools/vela/update-upstream.sh main     # upstream main instead
# Rebases the current branch; on conflicts it stops so they can be resolved by hand
# (git status, fix, git rebase --continue), then run the script again.
set -euo pipefail
cd "$(dirname "$0")/../.."
[ -z "$(git status --porcelain --untracked-files=no)" ] || { echo "Uncommitted changes; commit or stash first." >&2; exit 1; }
git fetch --tags upstream
TARGET="${1:-$(git tag --list --sort=-v:refname | grep -E '^v?[0-9]+(\.[0-9]+)+$' | head -1)}"
[ "$TARGET" = "main" ] && TARGET="upstream/main"
echo "Rebasing $(git branch --show-current) onto $TARGET…"
BASE=$(git merge-base HEAD "$TARGET")
# Only the fork's own commits move; everything already in the target stays.
FORK_BASE=$(git merge-base HEAD upstream/main)
git rebase --onto "$TARGET" "$FORK_BASE"
echo "Building…"
LOG=build/update-upstream-build.log
mkdir -p build
if ! xcodebuild -project Swiftfin.xcodeproj -scheme "Swiftfin tvOS" -destination 'generic/platform=tvOS Simulator' \
  -derivedDataPath build/dd -skipMacroValidation -skipPackagePluginValidation CODE_SIGNING_ALLOWED=NO build > "$LOG" 2>&1; then
  grep -E "error:" "$LOG" | grep -v SwiftFormat | sort -u | head -20 >&2
  echo "Build failed after the rebase; full log: $LOG" >&2
  exit 1
fi
(cd Tools/VelaLogicTests && swift test 2>&1 | tail -1)
echo "Up to date with $TARGET. Install with Tools/vela/install-device.sh."
