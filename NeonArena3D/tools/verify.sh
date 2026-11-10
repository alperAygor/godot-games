#!/usr/bin/env bash
# İçe aktarma + testler + açılış kontrolü. Hata varsa sıfırdan farklı döner.
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p tests/results
status=0

echo "▸ içe aktarma"
godot --headless --path . --import > tests/results/import.log 2>&1 || status=1
if grep -Eq "SCRIPT ERROR|Parse Error" tests/results/import.log; then
  echo "  ✗ içe aktarmada betik hatası"; grep -E "SCRIPT ERROR|Parse Error" tests/results/import.log | head -10; status=1
else
  echo "  ✓ betikler derlendi"
fi

echo "▸ testler"
if godot --headless --path . -s res://tests/run_tests.gd > tests/results/tests.log 2>&1; then
  tail -2 tests/results/tests.log | sed 's/^/  /'
else
  echo "  ✗ testler başarısız"; tail -20 tests/results/tests.log | sed 's/^/  /'; status=1
fi

echo "▸ açılış (300 kare)"
godot --headless --path . --quit-after 300 > tests/results/boot.log 2>&1
if grep -Eq "SCRIPT ERROR|ERROR: " tests/results/boot.log; then
  echo "  ✗ açılışta hata"; grep -E "SCRIPT ERROR|ERROR: " tests/results/boot.log | head -10 | sed 's/^/  /'; status=1
else
  echo "  ✓ temiz açılış"
fi

[ $status -eq 0 ] && echo "\n✓ doğrulama geçti" || echo "\n✗ doğrulama başarısız"
exit $status
