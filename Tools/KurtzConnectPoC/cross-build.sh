#!/bin/bash
# SPDX-License-Identifier: MPL-2.0
# Probe archive + Swift link, with stock Go. Success is NOT app/device validation.
set -euo pipefail
cd "$(dirname "$0")"
target="${1:?usage: bash cross-build.sh tvos|catalyst}"
case "$target" in
  tvos) sdk=appletvos; triple=arm64-apple-tvos26.1 ;;
  catalyst) sdk=macosx; triple=arm64-apple-ios18.6-macabi ;;
  *) exit 2 ;;
esac
mkdir -p "build/$target"
export KURTZ_POC_APPLE_TARGET="$target"
export GOOS=ios GOARCH=arm64 CGO_ENABLED=1
export CC="$PWD/apple-clang.sh"
# Go's build cache does not include environment variables read by CC wrappers.
# Make the target part of the hashed cgo flags to prevent reusing tvOS objects
# for Catalyst (both use GOOS=ios/GOARCH=arm64).
export CGO_CFLAGS="-target $triple" CGO_LDFLAGS="-target $triple"
go build -trimpath -buildmode=c-archive -o "build/$target/bridge.a" ./cmd/bridge
cat > "build/$target/anchor.swift" <<'SWIFT'
// Force linkage of the Go runtime and bridge; do not execute this function.
@_cdecl("KurtzConnectLinkAnchor")
public func KurtzConnectLinkAnchor() { VCStop() }
SWIFT
xcrun --sdk "$sdk" swiftc -emit-library -target "$triple" \
  -sdk "$(xcrun --sdk "$sdk" --show-sdk-path)" \
  -import-objc-header "build/$target/bridge.h" "build/$target/anchor.swift" \
  "build/$target/bridge.a" -framework Foundation -framework Security \
  -framework CoreFoundation -framework Network -lresolv \
  -o "build/$target/link-probe.dylib"
xcrun vtool -show-build "build/$target/link-probe.dylib"
