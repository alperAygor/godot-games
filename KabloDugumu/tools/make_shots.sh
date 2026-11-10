#!/usr/bin/env bash
# Faz B kabul yardımcısı: akış görüntülerini alır ve tek kontak sayfasına birleştirir.
#
#   bash tools/make_shots.sh                        # /tmp/kablo_shots + /tmp/kablo_sheet.png
#   bash tools/make_shots.sh --out-dir=/tmp/foo     # kareler buraya
#   GODOT=/yol/godot bash tools/make_shots.sh
#
# Headless ÇALIŞMAZ: gerçek pencere/ekran gerekir (flow_shot.gd headless'ta çıkar).
# stdout'a yalnızca montaj dosyasının yolu yazılır (GOTCHAS.md #13); diğer her şey stderr.

set -uo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
OUT_DIR="/tmp/kablo_shots"
SHEET="/tmp/kablo_sheet.png"

for arg in "$@"; do
    case "$arg" in
        --out-dir=*) OUT_DIR="${arg#--out-dir=}" ;;
        --sheet=*) SHEET="${arg#--sheet=}" ;;
        -h|--help) sed -n '2,10p' "$0" >&2; exit 0 ;;
        *) echo "hata: bilinmeyen argüman: $arg" >&2; exit 2 ;;
    esac
done

if ! command -v "$GODOT" >/dev/null 2>&1; then
    echo "hata: godot bulunamadı — GODOT=/yol/godot ile ver" >&2
    exit 2
fi

MONTAGE="${MONTAGE:-$PROJECT_DIR/../../studio-kit/tools/montage.py}"
if [ ! -f "$MONTAGE" ]; then
    echo "hata: montage.py bulunamadı: $MONTAGE (MONTAGE=... ile ver)" >&2
    exit 2
fi

mkdir -p "$OUT_DIR"
echo "== flow_shot (pencere açılacak) ==" >&2
"$GODOT" --path "$PROJECT_DIR" -s res://tools/flow_shot.gd -- --out-dir="$OUT_DIR" >&2
FLOW_CODE=$?
if [ "$FLOW_CODE" -ne 0 ]; then
    echo "uyarı: flow_shot çıkışı $FLOW_CODE; üretilen kareler yine montajlanır" >&2
fi

shopt -s nullglob
SHOTS=("$OUT_DIR"/*.png)
shopt -u nullglob
if [ "${#SHOTS[@]}" -eq 0 ]; then
    echo "hata: hiç PNG üretilmedi ($OUT_DIR)" >&2
    exit 1
fi

echo "== montage (${#SHOTS[@]} kare) ==" >&2
python3 "$MONTAGE" --out "$SHEET" --cols 3 --width 380 "${SHOTS[@]}" >&2

# Makinenin okuyacağı tek değer: kontak sayfası yolu.
echo "$SHEET"
exit "$FLOW_CODE"
