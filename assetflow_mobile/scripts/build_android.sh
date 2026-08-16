#!/usr/bin/env bash
# Builds a release APK for AssetFlow Mobile.
#
# Usage:
#   ./scripts/build_android.sh                          # release APK, default API_BASE_URL
#   API_BASE_URL=http://192.168.1.20:8000/api/v1 ./scripts/build_android.sh
#   BUILD_MODE=debug ./scripts/build_android.sh          # debug APK instead of release
#
# Requires (not installed by this script): a JDK, and either Android Studio
# or the standalone Android command-line tools with licenses accepted
# (`flutter doctor --android-licenses`). If Flutter itself isn't installed,
# this script clones the stable channel into ~/flutter and uses that.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_DIR="${FLUTTER_DIR:-$HOME/flutter}"
BUILD_MODE="${BUILD_MODE:-release}"
API_BASE_URL="${API_BASE_URL:-http://10.0.2.2:8000/api/v1}"

echo "== AssetFlow Mobile: Android build ($BUILD_MODE) =="
echo "API_BASE_URL: $API_BASE_URL"
echo ""

# --- 1. Ensure Flutter is on PATH ---
if ! command -v flutter &> /dev/null; then
  if [ -x "$FLUTTER_DIR/bin/flutter" ]; then
    export PATH="$FLUTTER_DIR/bin:$PATH"
  else
    echo "Flutter not found on PATH. Cloning stable channel into $FLUTTER_DIR ..."
    git clone https://github.com/flutter/flutter.git -b stable "$FLUTTER_DIR"
    export PATH="$FLUTTER_DIR/bin:$PATH"
  fi
fi

echo "-- flutter --version --"
flutter --version
echo ""

# --- 2. Sanity-check the toolchain (don't hard-fail on warnings) ---
echo "-- flutter doctor --"
set +e
DOCTOR_OUTPUT="$(flutter doctor 2>&1)"
set -e
echo "$DOCTOR_OUTPUT"
echo ""

if ! echo "$DOCTOR_OUTPUT" | grep -q "Android toolchain.*✓"; then
  echo "WARNING: Android toolchain not fully set up."
  echo "Install Android Studio (or the standalone cmdline-tools), then run:"
  echo "  flutter doctor --android-licenses"
  echo "and re-run this script."
  echo ""
fi

# --- 3. Scaffold native platform folders if this is a fresh checkout ---
cd "$PROJECT_DIR"
if [ ! -d android ]; then
  echo "-- flutter create . (scaffolding android/, ios/, etc.) --"
  flutter create .
  echo ""
fi

# --- 4. Dependencies ---
echo "-- flutter pub get --"
flutter pub get
echo ""

# --- 5. Analyze first -- catch real errors before spending build time ---
echo "-- flutter analyze --"
if ! flutter analyze; then
  echo ""
  echo "flutter analyze reported issues above. Fix them before building, or"
  echo "re-run with ANALYZE_ONLY=1 to inspect without attempting a build:"
  echo "  ANALYZE_ONLY=1 ./scripts/build_android.sh"
  if [ "${ANALYZE_ONLY:-0}" = "1" ]; then
    exit 1
  fi
  echo "Continuing to build anyway in 5s (Ctrl+C to abort) ..."
  sleep 5
fi
echo ""

if [ "${ANALYZE_ONLY:-0}" = "1" ]; then
  echo "ANALYZE_ONLY=1 set, stopping after analyze."
  exit 0
fi

# --- 6. Build ---
echo "-- flutter build apk --$BUILD_MODE --"
flutter build apk "--$BUILD_MODE" --dart-define=API_BASE_URL="$API_BASE_URL"

APK_PATH="$PROJECT_DIR/build/app/outputs/flutter-apk/app-$BUILD_MODE.apk"
if [ -f "$APK_PATH" ]; then
  echo ""
  echo "✅ APK built successfully:"
  echo "   $APK_PATH"
  echo ""
  echo "Install on a connected device/emulator with:"
  echo "   flutter install"
  echo "or copy the APK to a phone and tap it to install (enable 'install"
  echo "from unknown sources' first if prompted)."
else
  echo ""
  echo "❌ Build finished but the APK wasn't found at the expected path."
  echo "   Check the output above for the actual error."
  exit 1
fi
