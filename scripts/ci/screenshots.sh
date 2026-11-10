#!/bin/bash
# Capturile App Store: 10 ecrane × 7 limbi pe iPhone 6.9" → fastlane/screenshots/<limbă>/NN_jocuri.png
set -e
OUT_DIR="${OUT_DIR:-$PWD/ci-out}"; BUNDLE_ID="${BUNDLE_ID:-ro.draghicioiu.whist}"
SHOTS="${SHOTS:-1 2 3 4 5 6 7 8 9 10}"
bash scripts/ci/simulator.sh
UDID=$(cat "$OUT_DIR/udid")
xcrun simctl ui "$UDID" appearance dark
xcrun simctl status_bar "$UDID" override --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
# notificările de sistem de după prima pornire („Ready for Apple Intelligence” etc.) trec înainte de capturi
xcrun simctl launch "$UDID" "$BUNDLE_ID" -shot 1; sleep 60; xcrun simctl terminate "$UDID" "$BUNDLE_ID" || true
OUT="$PWD/fastlane/screenshots"; rm -rf "$OUT"; mkdir -p "$OUT_DIR/screenshots"
for SPEC in ro:ro:ro_RO en-US:en:en_US de-DE:de:de_DE fr-FR:fr:fr_FR it:it:it_IT es-ES:es:es_ES hu:hu:hu_HU; do
  IFS=: read -r DIR LANG REGION <<< "$SPEC"
  mkdir -p "$OUT/$DIR"
  for N in $SHOTS; do
    xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
    xcrun simctl launch "$UDID" "$BUNDLE_ID" -shot $N -AppleLanguages "($LANG)" -AppleLocale "$REGION" >/dev/null
    sleep 9
    xcrun simctl io "$UDID" screenshot "$OUT/$DIR/$(printf %02d $N)_jocuri.png" >/dev/null
  done
  for f in "$OUT/$DIR/"*.png; do cp "$f" "$OUT_DIR/screenshots/${DIR}_$(basename "$f")"; done
  echo "Capturi $DIR: $(ls "$OUT/$DIR" | wc -l)"
done
sips -g pixelWidth -g pixelHeight "$OUT/ro/01_jocuri.png" | tail -2
