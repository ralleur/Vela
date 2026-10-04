#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build
go build -trimpath -o build/lab ./cmd/lab
MACOSX_DEPLOYMENT_TARGET=15.6 CGO_CFLAGS="-mmacosx-version-min=15.6" \
  CGO_LDFLAGS="-mmacosx-version-min=15.6" CGO_ENABLED=1 \
  go build -trimpath -buildmode=c-archive -o build/kurtz-connect.a ./cmd/bridge
xcrun swiftc -parse-as-library -O -target arm64-apple-macos15.6 \
  -import-objc-header build/kurtz-connect.h Probe.swift build/kurtz-connect.a \
  -framework Foundation -framework AVFoundation -framework Security \
  -framework CoreFoundation -framework SystemConfiguration -framework CoreServices \
  -framework Network -lresolv -o build/probe
