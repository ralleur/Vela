#!/bin/bash
# Moves the fork's commits onto newer Swiftfin code and checks that it still builds and tests pass.
#   Tools/vela/update-upstream.sh          # upstream main
#   Tools/vela/update-upstream.sh 1.7      # a release tag (only newer than the fork's current base)
# The fork started on main because release 1.6.1 no longer builds with Xcode 27 (CoreStore).
# Rebases the current branch; on conflicts it stops so they can be resolved by hand
# (git status, fix, git rebase --continue), then run the script again.
set -euo pipefail
cd "$(dirname "$0")/../.."
[ -z "$(git status --porcelain --untracked-files=no)" ] || { echo "Uncommitted changes; commit or stash first." >&2; exit 1; }
git fetch --tags upstream
TARGET="${1:-upstream/main}"
[ "$TARGET" = "main" ] && TARGET="upstream/main"
echo "Rebasing $(git branch --show-current) onto $TARGET…"
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
