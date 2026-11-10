#!/usr/bin/env bash
# Godot projesi doğrulaması: içe aktarma + açılış dumanı + birim testleri.
#
#   tools/verify.sh                    # proje kökünde
#   tools/verify.sh /yol/proje         # başka bir proje
#   GODOT=/yol/godot tools/verify.sh
#   VERIFY_STRICT=1 tools/verify.sh    # ERROR: satırlarını da hata say
#
# Neden ayrı tarama: Godot script hatasında bile 0 döndürür (GOTCHAS.md #1).
# Neden zaman aşımı: asılı kalan bir Godot süreci tüm doğrulamayı kilitler (GOTCHAS.md #14).

set -uo pipefail

GODOT="${GODOT:-godot}"
PROJECT_ARG="${1:-.}"
PROJECT_DIR="$(cd "$PROJECT_ARG" 2>/dev/null && pwd)" || { echo "hata: proje dizini yok: $PROJECT_ARG" >&2; exit 2; }
LOG_DIR="$PROJECT_DIR/build/verify"
IMPORT_TIMEOUT="${VERIFY_IMPORT_TIMEOUT:-180}"
STEP_TIMEOUT="${VERIFY_STEP_TIMEOUT:-120}"

FAILED=0
mkdir -p "$LOG_DIR"

scan_errors() {
    local log="$1" label="$2" pattern
    pattern='SCRIPT ERROR|Parse Error|Failed to load script|Failed to instantiate|Cannot open file'
    if [ "${VERIFY_STRICT:-0}" = "1" ]; then
        pattern="$pattern|ERROR:"
    fi
    local hits
    hits=$(grep -cE "$pattern" "$log" 2>/dev/null || true)
    if [ "${hits:-0}" -gt 0 ]; then
        echo "  x $label: $hits hata satiri"
        grep -m3 -E "$pattern" "$log" | sed 's/^/    /'
        FAILED=1
        return 1
    fi
    return 0
}

# Taşınabilir zaman aşımı (macOS'ta 'timeout' yok).
run_godot() {
    local name="$1" limit="$2"
    shift 2
    local log="$LOG_DIR/$name.log"
    "$@" >"$log" 2>&1 &
    local pid=$!
    local waited=0
    while kill -0 "$pid" 2>/dev/null; do
        sleep 1
        waited=$((waited + 1))
        if [ "$waited" -ge "$limit" ]; then
            kill -9 "$pid" 2>/dev/null
            echo "  x $name: zaman asimi (${limit}s) — log: $log"
            FAILED=1
            return 124
        fi
    done
    wait "$pid"
    return $?
}

if ! command -v "$GODOT" >/dev/null 2>&1; then
    echo "hata: godot bulunamadi — GODOT=/yol/godot ile ver" >&2
    exit 2
fi

echo "proje: $PROJECT_DIR"
echo "godot: $($GODOT --version 2>/dev/null | head -1)"

echo "== 1/4 ice aktarma =="
# İki geçiş: ilk geçişte henüz içe aktarılmamış bir varlığa (font/glb/ses) referans
# veren .tres çözülemez ve "non-existent resource" hatası basar (GOTCHAS.md #15).
# İkinci geçiş otoritedir; hata taraması onun üzerinden yapılır.
run_godot "import-first" "$IMPORT_TIMEOUT" "$GODOT" --headless --path "$PROJECT_DIR" --import >/dev/null 2>&1
if run_godot "import" "$IMPORT_TIMEOUT" "$GODOT" --headless --path "$PROJECT_DIR" --import; then
    echo "  + import tamam"
else
    echo "  x import basarisiz"
    FAILED=1
fi
scan_errors "$LOG_DIR/import.log" "import"

if [ -f "$PROJECT_DIR/scenes/Boot.tscn" ] || [ -n "$(ls "$PROJECT_DIR"/scenes/*.tscn 2>/dev/null | head -1)" ]; then
    echo "== 2/4 acilis dumani =="
    if run_godot "smoke" "$STEP_TIMEOUT" "$GODOT" --headless --path "$PROJECT_DIR" --quit; then
        echo "  + sahne yuklendi"
    else
        echo "  x acilis basarisiz"
        FAILED=1
    fi
    scan_errors "$LOG_DIR/smoke.log" "acilis"
else
    echo "== 2/4 acilis dumani = atlandi (scenes/*.tscn yok) =="
fi

if [ -f "$PROJECT_DIR/tests/run_tests.gd" ]; then
    echo "== 3/4 birim testleri =="
    run_godot "tests" "$STEP_TIMEOUT" "$GODOT" --headless --path "$PROJECT_DIR" -s res://tests/run_tests.gd
    tests_code=$?
    grep -E "^(PASS|FAIL)|^[0-9]+ test|^(YÜKLENEMEDİ|ÖRNEKLENEMEDİ)" "$LOG_DIR/tests.log" 2>/dev/null | sed 's/^/  /'
    if [ "$tests_code" -ne 0 ]; then
        echo "  x testler basarisiz (cikis $tests_code)"
        FAILED=1
    else
        echo "  + testler gecti"
    fi
    scan_errors "$LOG_DIR/tests.log" "testler"
else
    echo "== 3/4 birim testleri = atlandi (tests/run_tests.gd yok) =="
fi

# Oyun sahnesi dumanı: Game.tscn/game.gd hazır olduğunda debug_state + force_snap
# sözleşmesini headless doğrular (signal-qa). Dosya yoksa adım atlanır; probe
# API henüz yoksa kendisi SKIP döner (Game.tscn gelmeden verify'ı kırmaz).
if [ -f "$PROJECT_DIR/tools/game_probe.gd" ]; then
    echo "== 4/4 oyun dumani =="
    if run_godot "game_probe" "$STEP_TIMEOUT" "$GODOT" --headless --path "$PROJECT_DIR" -s res://tools/game_probe.gd; then
        echo "  + oyun sahnesi dogrulandi"
    else
        echo "  x oyun dumani basarisiz"
        FAILED=1
    fi
    grep -E "^PROBE " "$LOG_DIR/game_probe.log" 2>/dev/null | sed 's/^/  /'
    scan_errors "$LOG_DIR/game_probe.log" "oyun dumani"
else
    echo "== 4/4 oyun dumani = atlandi (tools/game_probe.gd yok) =="
fi

echo
if [ "$FAILED" -eq 0 ]; then
    echo "SONUC: gecti"
else
    echo "SONUC: basarisiz (loglar: $LOG_DIR)"
fi
exit $FAILED
