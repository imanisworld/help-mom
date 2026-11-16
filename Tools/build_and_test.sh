#!/usr/bin/env bash
# Native simulator build and XCTest; no signing or third-party packages.
set -euo pipefail
cd "$(dirname "$0")/.."
if ! xcodebuild -version; then
  echo 'BLOCKED: Install full Xcode and its iOS Simulator runtime, then open Xcode once.' >&2
  echo 'Select it with DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer or xcode-select.' >&2
  exit 2
fi
args=(-project CreativeMoments.xcodeproj -scheme CreativeMoments -configuration Debug -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO)
xcodebuild "${args[@]}" -destination 'generic/platform=iOS Simulator' build
if [[ -z "${DESTINATION:-}" ]]; then
  DESTINATION="$(xcodebuild -project CreativeMoments.xcodeproj -scheme CreativeMoments -showdestinations | sed -nE '/platform:iOS Simulator/ { /placeholder/d; s/.*id:([^,}]+).*/platform=iOS Simulator,id=\1/p; }' | sed -n '1p')"
fi
if [[ -z "$DESTINATION" ]]; then
  echo 'BLOCKED: No eligible iOS simulator. Install a runtime/device in Xcode or set DESTINATION.' >&2
  exit 2
fi
printf 'Testing on %s\n' "$DESTINATION"
xcodebuild "${args[@]}" -destination "$DESTINATION" test
