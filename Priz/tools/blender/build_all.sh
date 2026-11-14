#!/usr/bin/env bash
# Priz — tüm varlıkları baştan üretir: dokular → malzemeler → oda → cihazlar → sigorta kutusu → .import.
#
#   tools/blender/build_all.sh            # her şey (AO pişirmeli, ~1.5 dk)
#   tools/blender/build_all.sh --no-bake  # hızlı önizleme (AO yok)
#   BLENDER=/yol/Blender tools/blender/build_all.sh
#
# Ardından: godot --headless --path . --import (iki kez).
set -euo pipefail
cd "$(dirname "$0")/../.."
BLENDER="${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}"
BPY="$(dirname "$BLENDER")/../Resources/5.2/python/bin/python3.13"
[ -x "$BPY" ] || BPY="$(ls "$(dirname "$BLENDER")"/../Resources/*/python/bin/python3* | head -1)"
EXTRA=()
[ "${1:-}" = "--no-bake" ] && EXTRA=(-- --no-bake)

run_blender() {
    local script="$1"; shift
    local log; log="$(mktemp)"
    if ! "$BLENDER" -b --factory-startup -P "tools/blender/$script" "$@" >"$log" 2>&1; then
        cat "$log"; echo "HATA: $script"; exit 1
    fi
    if grep -q "Traceback" "$log"; then
        cat "$log"; echo "HATA: $script (Python istisnası)"; exit 1
    fi
    grep -E "üçgen|GLB:" "$log" || true
    rm -f "$log"
}

echo "== dokular"
PYTHONDONTWRITEBYTECODE=1 "$BPY" tools/blender/make_textures.py | tail -1
echo "== malzemeler"
PYTHONDONTWRITEBYTECODE=1 "$BPY" tools/blender/priz_mats.py
echo "== oda"
run_blender make_room.py ${EXTRA[@]+"${EXTRA[@]}"}
echo "== cihazlar"
run_blender make_appliances.py ${EXTRA[@]+"${EXTRA[@]}"}
echo "== sigorta kutusu"
run_blender make_fusebox.py ${EXTRA[@]+"${EXTRA[@]}"}
echo "== .import dosyaları"
PYTHONDONTWRITEBYTECODE=1 "$BPY" tools/blender/write_imports.py
echo "tamam — şimdi: godot --headless --path . --import (iki kez)"
