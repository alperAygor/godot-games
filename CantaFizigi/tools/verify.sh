#!/usr/bin/env bash
# CantaFizigi doğrulama: içe aktarma + açılış dumanı + birim testleri.
# Godot script hatasında da 0 dönebildiği için çıktı ayrıca taranır.
#
#   tools/verify.sh            # hepsi
#   GODOT=/path/to/godot tools/verify.sh

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

GODOT="${GODOT:-godot}"
OUT="tests/results"
mkdir -p "$OUT"
status=0

scan_errors() {
    local log="$1" label="$2" hits
    hits=$(grep -cE "SCRIPT ERROR|Parse Error|Failed to load script" "$log" || true)
    if [ "${hits:-0}" -gt 0 ]; then
        echo "  x $label: $hits script hatasi"
        grep -m3 -E "SCRIPT ERROR|Parse Error|Failed to load script" "$log" | sed 's/^/    /'
        status=1
        return 1
    fi
    return 0
}

echo "== 1/3 ice aktarma =="
if "$GODOT" --headless --path . --import > "$OUT/import.log" 2>&1; then
    echo "  + import tamam"
else
    echo "  x import basarisiz (cikis $?)"
    status=1
fi
scan_errors "$OUT/import.log" "import"

echo "== 2/3 acilis dumani =="
if "$GODOT" --headless --path . --quit > "$OUT/smoke.log" 2>&1; then
    echo "  + sahne yuklendi"
else
    echo "  x acilis basarisiz"
    status=1
fi
scan_errors "$OUT/smoke.log" "acilis"

echo "== 3/3 birim testleri =="
"$GODOT" --headless --path . -s res://tests/run_tests.gd > "$OUT/tests.log" 2>&1
tests_code=$?
grep -E "^(PASS|FAIL)|^[0-9]+ test|^(YÜKLENEMEDİ|ÖRNEKLENEMEDİ)" "$OUT/tests.log" | sed 's/^/  /'
if [ $tests_code -ne 0 ]; then
    echo "  x testler basarisiz (cikis $tests_code)"
    status=1
else
    echo "  + testler gecti"
fi
scan_errors "$OUT/tests.log" "testler"

echo
if [ $status -eq 0 ]; then
    echo "SONUC: gecti"
else
    echo "SONUC: basarisiz (loglar: $OUT)"
fi
exit $status
