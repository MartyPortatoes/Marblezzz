#!/bin/sh
set -eu
marblezzz_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$marblezzz_root/Packages/MarblezzzCore"
swift test --scratch-path /tmp/marblezzz-package-tests
cd "$marblezzz_root"
xcodebuild -project Marblezzz.xcodeproj -scheme Marblezzz \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/marblezzz-derived CODE_SIGNING_ALLOWED=NO build
