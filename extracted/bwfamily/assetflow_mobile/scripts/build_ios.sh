#!/usr/bin/env bash
# Builds AssetFlow Mobile for iOS. This ONLY works on macOS with Xcode
# installed -- that's an Apple platform restriction, not a project
# limitation, so this script checks for both up front and exits with a
# clear message rather than failing confusingly halfway through.
#
# Usage:
#   ./scripts/build_ios.sh                # unsigned build, runs in Simulator only
#   ./scripts/build_ios.sh --device       # signed build for a real iPhone (needs
#                                          # an Apple Developer account + signing
#                                          # configured in Xcode first, see below)
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_DIR="${FLUTTER_DIR:-$HOME/flutter}"
API_BASE_URL="${API_BASE_URL:-http://localhost:8000/api/v1}"
MODE="${1:-simulator}"

if [[ "$OSTYPE" != "darwin"* ]]; then
  echo "❌ iOS builds require macOS + Xcode. This machine is: $OSTYPE"
  echo ""
  echo "There is no workaround for this -- it's an Apple restriction, not a"
  echo "tooling gap. Options:"
  echo "  1. Run this script on an actual Mac."
  echo "  2. Use a cloud Mac build service (Codemagic, Bitrise, GitHub Actions"
  echo "     macos-latest runners) to build and sign the IPA remotely."
  exit 1
fi

if ! xcode-select -p &> /dev/null; then
  echo "❌ Xcode command-line tools not found. Install Xcode from the App"
  echo "   Store, then run: sudo xcode-select --switch /Applications/Xcode.app"
  exit 1
fi

echo "== AssetFlow Mobile: iOS build =="
echo "API_BASE_URL: $API_BASE_URL"
echo "Mode: $MODE"
echo ""

if ! command -v flutter &> /dev/null; then
  if [ -x "$FLUTTER_DIR/bin/flutter" ]; then
    export PATH="$FLUTTER_DIR/bin:$PATH"
  else
    echo "Flutter not found on PATH. Cloning stable channel into $FLUTTER_DIR ..."
    git clone https://github.com/flutter/flutter.git -b stable "$FLUTTER_DIR"
    export PATH="$FLUTTER_DIR/bin:$PATH"
  fi
fi

flutter --version
echo ""
flutter doctor
echo ""

cd "$PROJECT_DIR"
if [ ! -d ios ]; then
  echo "-- flutter create . (scaffolding ios/, android/, etc.) --"
  flutter create .
fi

echo "-- flutter pub get --"
flutter pub get

echo "-- pod install (CocoaPods) --"
(cd ios && pod install)

echo "-- flutter analyze --"
flutter analyze || {
  echo "flutter analyze reported issues (see above). Continuing in 5s..."
  sleep 5
}

if [ "$MODE" = "--device" ]; then
  echo "-- flutter build ipa (signed, for a real device) --"
  echo ""
  echo "NOTE: this requires signing to already be configured in Xcode:"
  echo "  1. Open ios/Runner.xcworkspace in Xcode"
  echo "  2. Select the Runner target -> Signing & Capabilities"
  echo "  3. Pick your Apple Developer team, let Xcode manage signing"
  echo "  4. Close Xcode, re-run this script"
  echo ""
  flutter build ipa --dart-define=API_BASE_URL="$API_BASE_URL"
  echo ""
  echo "✅ Signed IPA (if signing was configured) at:"
  echo "   $PROJECT_DIR/build/ios/ipa/"
else
  echo "-- flutter build ios --simulator (no signing needed) --"
  flutter build ios --simulator --dart-define=API_BASE_URL="$API_BASE_URL"
  echo ""
  echo "✅ Simulator build ready. Run it with:"
  echo "   flutter run -d \"iPhone 15\" --dart-define=API_BASE_URL=$API_BASE_URL"
  echo ""
  echo "This will NOT install on a real iPhone -- simulator builds are"
  echo "unsigned. For a real device, run: ./scripts/build_ios.sh --device"
fi
