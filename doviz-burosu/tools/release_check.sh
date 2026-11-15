#!/usr/bin/env bash
# Yayın (Google Play) kapısı: yapılandırma + (varsa) üretilmiş AAB. Sahibin yapacağı işler bitmeden
# BAŞARISIZ olması BEKLENİR; FAIL satırları yapılacakları söyler.
#
#   tools/release_check.sh                   # yalnız yapılandırma
#   tools/release_check.sh yol/uygulama.aab  # yapılandırma + o AAB (manifest, imza, 16 KB, ABI)
#   tools/release_check.sh --latest          # yapılandırma + build/release/*.aab içindeki en yeni
# Çıkış: 0 geçti, 1 denetim hatası, 2 araç hatası. Sır basmaz (yalnız "tanımlı/yok").
set -uo pipefail
GODOT="${GODOT_PATH:-$(command -v godot || echo /Applications/Godot.app/Contents/MacOS/Godot)}"
cd "$(dirname "$0")/.." || exit 2
ROOT="$(pwd)"
LOG_DIR="$ROOT/tests/results"
OUT_DIR="$ROOT/build/release"
mkdir -p "$LOG_DIR" "$OUT_DIR"

AAB="${1:-}"
if [ "$AAB" = "--latest" ]; then
  AAB="$(ls -t "$OUT_DIR"/*.aab 2>/dev/null | head -1 || true)"
  [ -n "$AAB" ] || { echo "hata: $OUT_DIR altında .aab yok" >&2; exit 2; }
fi

ARGS=()
if [ -n "$AAB" ]; then
  [ -f "$AAB" ] || { echo "hata: AAB yok: $AAB" >&2; exit 2; }
  INFO="$OUT_DIR/aab_info.json"
  if python3 -I "$ROOT/tools/aab_inspect.py" "$AAB" --json > "$INFO" 2> "$LOG_DIR/aab_inspect.err"; then
    ARGS=("--aab-info=$INFO")
  else
    echo "hata: AAB okunamadı ($AAB): $(head -c 300 "$LOG_DIR/aab_inspect.err")" >&2
    exit 2
  fi
fi

# class_name önbelleği (ReleaseGuard) güncel olsun; kullanıcı verisine dokunmasın (DV_SANDBOX).
DV_SANDBOX=1 "$GODOT" --headless --path "$ROOT" --import > /dev/null 2>&1
DV_SANDBOX=1 "$GODOT" --headless --path "$ROOT" -s res://tools/release_check.gd -- "${ARGS[@]+"${ARGS[@]}"}" > "$LOG_DIR/release_check.log" 2>&1
CODE=$?
grep -v -E "^Godot Engine|^$|WARNING: ObjectDB|at: cleanup" "$LOG_DIR/release_check.log"
if grep -qE "SCRIPT ERROR|Parse Error" "$LOG_DIR/release_check.log"; then
  echo "hata: release_check.gd betik hatası verdi (bkz. $LOG_DIR/release_check.log)" >&2
  exit 2
fi
exit $CODE
