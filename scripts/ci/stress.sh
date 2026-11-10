#!/bin/bash
# Test de anduranță: aplicația pornită cu -stress joacă sute de partide și scrie rezultatul.
set -e
OUT_DIR="${OUT_DIR:-$PWD/ci-out}"; BUNDLE_ID="${BUNDLE_ID:-ro.draghicioiu.whist}"
bash scripts/ci/simulator.sh
UDID=$(cat "$OUT_DIR/udid")
xcrun simctl launch "$UDID" "$BUNDLE_ID" -stress
DATA=$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data)
for i in $(seq 1 150); do
  [ -f "$DATA/Documents/stress.txt" ] && break
  xcrun simctl spawn "$UDID" launchctl list | grep -q "$BUNDLE_ID" || { echo "Aplicația s-a oprit înainte de final"; break; }
  sleep 5
done
echo "======== REZULTAT ========"
cat "$DATA/Documents/stress.txt" 2>/dev/null || { echo "Fără rezultat (crash)";
  find ~/Library/Logs/DiagnosticReports -name "Whist*" -mmin -30 -exec head -80 {} \; ; exit 1; }
grep -q "STRESS OK" "$DATA/Documents/stress.txt"
