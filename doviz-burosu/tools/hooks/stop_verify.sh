#!/usr/bin/env bash
# Claude Code Stop hook'u: Claude turu bitirirken, son başarılı doğrulamadan beri proje dosyası değiştiyse
# tools/verify.sh çalıştırır (~5 sn). Başarısızsa çıkış kodu 2 → Claude durmaz, hatayı görür ve düzeltir.
# Sonsuz döngü olmasın diye: Claude zaten bir kez bu hook yüzünden devam ettiyse (stop_hook_active=true)
# ve doğrulama yine başarısızsa, Claude'u tutmaz; sadece kullanıcıya uyarı gösterir.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
STAMP="$ROOT/tests/results/.last_verified"
active="$(jq -r '.stop_hook_active // false' 2>/dev/null || echo false)"

changed() {
  [ -f "$STAMP" ] || return 0
  [ -n "$(find "$ROOT" \( -path "$ROOT/.godot" -o -path "$ROOT/.git" -o -path "$ROOT/android" \
      -o -path "$ROOT/build" -o -path "$ROOT/tests/results" -o -path "$ROOT/tools/screenshots" \) -prune \
      -o -type f -newer "$STAMP" -print -quit)" ]
}

changed || exit 0

if output="$("$ROOT/tools/verify.sh" 2>&1)"; then
  touch "$STAMP"
  exit 0
fi

if [ "$active" = "true" ]; then
  jq -n '{systemMessage: "tools/verify.sh hâlâ başarısız (ayrıntı: tests/results/). Claude bir kez düzeltmeyi denedi."}'
  exit 0
fi

echo "tools/verify.sh başarısız — turu bitirmeden düzelt:" >&2
echo "$output" | tail -30 >&2
exit 2
