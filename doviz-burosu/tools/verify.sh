#!/usr/bin/env bash
# Her değişiklikten sonra çalıştır: içe aktarma + açılış + testler, hepsi headless.
# Godot script hatalarında bile çıkış kodu 0 döndürebilir; bu yüzden çıktı ayrıca taranır.
# Kullanım: tools/verify.sh            (proje kökünden)
set -uo pipefail

GODOT="${GODOT_PATH:-$(command -v godot || echo /Applications/Godot.app/Contents/MacOS/Godot)}"
cd "$(dirname "$0")/.."
LOG_DIR="tests/results"
mkdir -p "$LOG_DIR"
status=0

scan() {  # $1 = adım adı, $2 = log dosyası
  if grep -E "SCRIPT ERROR|^ERROR:|Parse Error|Failed to load script" "$2" | grep -v -E "adb|tcp:5037" > /dev/null; then
    echo "✗ $1: hata bulundu ($2)"
    grep -n -E -A2 "SCRIPT ERROR|^ERROR:|Parse Error|Failed to load script" "$2" | head -30
    status=1
  else
    echo "✓ $1"
  fi
}

echo "== Godot: $("$GODOT" --headless --version)"

"$GODOT" --headless --path . --import > "$LOG_DIR/import.log" 2>&1
scan "içe aktarma" "$LOG_DIR/import.log"

"$GODOT" --headless --path . --quit-after 10 > "$LOG_DIR/boot.log" 2>&1
scan "açılış (10 kare)" "$LOG_DIR/boot.log"

"$GODOT" --headless --path . -s res://tests/run_tests.gd "$@" > "$LOG_DIR/tests.log" 2>&1
test_exit=$?
scan "test çıktısı" "$LOG_DIR/tests.log"
tail -1 "$LOG_DIR/tests.log"
if [ "$test_exit" -ne 0 ]; then
  echo "✗ testler (çıkış kodu $test_exit)"
  grep -E "KALDI|YÜKLENEMEDİ|^\s+- " "$LOG_DIR/tests.log"
  status=1
fi

[ "$status" -eq 0 ] && echo "== DOĞRULAMA BAŞARILI" || echo "== DOĞRULAMA BAŞARISIZ"
exit "$status"
