#!/usr/bin/env bash
# Yayın (Google Play) denetimi: yapılandırma + (varsa) üretilmiş AAB. Sahibin yapacağı işler
# bitmeden BAŞARISIZ olması BEKLENİR; hata satırları yapılacakları söyler.
#
#   tools/release_check.sh                      # build/release/ altındaki en yeni .aab (yoksa yalnız yapılandırma)
#   tools/release_check.sh yol/uygulama.aab     # belirli AAB
#   GODOT=/yol/godot tools/release_check.sh
# Çıkış: 0 geçti, 1 denetim hatası, 2 araç hatası. Sır basmaz (yalnız "tanımlı/değil").

set -uo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.." || exit 2
ROOT="$(pwd)"
LOG_DIR="$ROOT/build/verify"
mkdir -p "$LOG_DIR" "$ROOT/build/release"

AAB="${1:-}"
if [ -z "$AAB" ]; then
    AAB="$(ls -t "$ROOT"/build/release/*.aab 2>/dev/null | head -1 || true)"
fi

ARGS=()
if [ -n "$AAB" ] && [ -f "$AAB" ]; then
    INFO="$ROOT/build/release/aab_info.json"
    if python3 -I "$ROOT/tools/aab_inspect.py" "$AAB" --json > "$INFO" 2>"$LOG_DIR/aab_inspect.err"; then
        ARGS=("--aab-info=$INFO")
    else
        echo "hata: AAB okunamadi ($AAB): $(head -c 300 "$LOG_DIR/aab_inspect.err")" >&2
        exit 2
    fi
fi

# --import gerekmez ama class_name önbelleği (ReleaseGuard) güncel olmalı.
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1
"$GODOT" --headless --path "$ROOT" -s res://tools/release_check.gd -- "${ARGS[@]+"${ARGS[@]}"}" > "$LOG_DIR/release_check.log" 2>&1
CODE=$?
cat "$LOG_DIR/release_check.log" | grep -v -E "^Godot Engine|^$|WARNING: ObjectDB|at: cleanup" 
if grep -qE "SCRIPT ERROR|Parse Error" "$LOG_DIR/release_check.log"; then
    echo "hata: release_check.gd betik hatasi verdi (bkz. $LOG_DIR/release_check.log)" >&2
    exit 2
fi
exit $CODE
