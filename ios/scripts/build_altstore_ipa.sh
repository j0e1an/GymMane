#!/usr/bin/env bash
# Build an unsigned GymMane IPA for AltStore / AltServer (free Apple ID).
# AltStore resigns the IPA with your Apple ID (7-day cert on free accounts).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v flutter >/dev/null 2>&1; then
  if [[ -x "$HOME/development/flutter/bin/flutter" ]]; then
    export PATH="$HOME/development/flutter/bin:$PATH"
  else
    echo "error: flutter not found on PATH" >&2
    exit 1
  fi
fi

echo "==> flutter pub get"
flutter pub get

# Enable SPM (required by app_settings). Generate ephemeral Package.swift
# files, then bump plugin iOS floors so FlutterFramework (min 13) resolves.
flutter config --enable-swift-package-manager >/dev/null 2>&1 || true
echo "==> prepare iOS / patch SPM platforms"
flutter build ios --config-only --release --no-codesign >/dev/null 2>&1 || true
if [[ -x "$ROOT/scripts/patch_spm_ios_floor.sh" ]]; then
  "$ROOT/scripts/patch_spm_ios_floor.sh"
fi

echo "==> flutter build ios --release --no-codesign"
flutter build ios --release --no-codesign

APP="$ROOT/build/ios/iphoneos/Runner.app"
if [[ ! -d "$APP" ]]; then
  echo "error: missing $APP after build" >&2
  exit 1
fi

OUT_DIR="$ROOT/build/ios/ipa"
STAGE="$OUT_DIR/_payload"
IPA="$OUT_DIR/GymMane.ipa"
rm -rf "$STAGE"
mkdir -p "$STAGE/Payload"
cp -R "$APP" "$STAGE/Payload/Runner.app"

rm -f "$IPA"
(
  cd "$STAGE"
  zip -qry "$IPA" Payload
)
rm -rf "$STAGE"

echo
echo "Built: $IPA"
echo
echo "Next (free Apple ID):"
echo "  1. Install AltServer on this Mac and AltStore on your iPhone."
echo "  2. In AltStore: My Apps → + → select GymMane.ipa"
echo "  3. Refresh in AltStore at least every 7 days while AltServer is reachable."
echo
echo "Limits on a free Apple ID: App Groups, home-screen widgets, Live Activity,"
echo "and the Share extension often do not work after resign. Core logging should."
echo "See docs/SIDELOAD.md for details."
