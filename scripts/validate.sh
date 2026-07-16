#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-/home/john/.local/bin/godot4}"
REPORT="$ROOT/tests/latest_report.txt"

if [[ ! -x "$GODOT_BIN" ]]; then
  echo "Godot executable not found: $GODOT_BIN" >&2
  exit 1
fi

{
  echo "Wasteland Protocol validation"
  echo "Godot: $($GODOT_BIN --version)"
  echo "Date: $(date --iso-8601=seconds)"
  echo
  echo "[1/4] Import and parse"
  "$GODOT_BIN" --headless --editor --path "$ROOT" --quit
  echo
  echo "[2/4] Logic and scene smoke tests"
  "$GODOT_BIN" --headless --path "$ROOT" --script res://tests/test_runner.gd
  echo
  echo "[3/4] Export preset checks"
  "$GODOT_BIN" --headless --path "$ROOT" --script res://tests/export_presets_test.gd
  echo
  echo "[4/4] Main scene boot smoke"
  "$GODOT_BIN" --headless --path "$ROOT" --quit-after 10
} 2>&1 | tee "$REPORT"

if grep -Eq "SCRIPT ERROR|ERROR:|Parse Error|Compile Error" "$REPORT"; then
  echo "VALIDATION_RESULT: FAIL (Godot reported an error)" | tee -a "$REPORT"
  exit 1
fi

echo "VALIDATION_RESULT: PASS" | tee -a "$REPORT"
