#!/bin/sh
# SPDX-License-Identifier: MPL-2.0
# Compile-only experiment, not a supported XCFramework recipe.
set -eu
case "${KURTZ_POC_APPLE_TARGET:?}" in
  tvos) sdk=appletvos; triple=arm64-apple-tvos26.1 ;;
  catalyst) sdk=macosx; triple=arm64-apple-ios18.6-macabi ;;
  *) exit 2 ;;
esac
exec xcrun --sdk "$sdk" clang -target "$triple" \
  -isysroot "$(xcrun --sdk "$sdk" --show-sdk-path)" "$@"
