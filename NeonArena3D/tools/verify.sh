#!/usr/bin/env bash
# Doğrulama kapısı v2: içe aktarma (×2) + betik-hata taraması + birim testleri + açılış + probeler (meta, synergy, touch, ads = reklam akışı) + kısa bot oyunu
# + denge simülasyonu + PCK denetimi + oyuncu kaydının dokunulmadığının kanıtı. Herhangi biri kırmızıysa çıkış kodu 1.
#
#   tools/verify.sh                  # tam kapı (~1-2 dk)
#   VERIFY_FAST=1 tools/verify.sh    # hızlı tur: simülasyon, bot oyunu ve PCK atlanır (geliştirirken)
#   VERIFY_FULL_SIM=1 tools/verify.sh  # simülasyon tam ızgara (20 tohum; ~1 dk) ve rapor dosyası
#   GODOT=/yol/godot  VERIFY_STEP_TIMEOUT=120  VERIFY_PCK_MAX_MB=10  VERIFY_STRICT=1 (ERROR: satırları da hata sayılır)
#
# Neden ayrı tarama: Godot betik hatasında bile 0 ile çıkar; günlükte SCRIPT ERROR / Parse Error aranır.
# Neden zaman aşımı: asılı kalan bir Godot kapıyı sonsuza kadar kilitlemesin. Zaman aşımı YALNIZ kendi
#   başlattığı süreci öldürür (pkill/killall yok). Oyuncu kaydı: araçlar --no-save/--demo ile çalışır; kapı,
#   gerçek user:// kayıt dosyalarının önce/sonra aynı olduğunu doğrular.
set -uo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
GODOT="${GODOT:-godot}"
LOG="$ROOT/tests/results"
STEP_TIMEOUT="${VERIFY_STEP_TIMEOUT:-120}"
IMPORT_TIMEOUT="${VERIFY_IMPORT_TIMEOUT:-180}"
SIM_TIMEOUT="${VERIFY_SIM_TIMEOUT:-300}"
PCK_MAX_MB="${VERIFY_PCK_MAX_MB:-10}"
FAST="${VERIFY_FAST:-0}"
mkdir -p "$LOG" "$ROOT/build/verify"
touch "$ROOT/build/.gdignore"   # build/ içeriği kaynak sayılıp PCK'ya sızmasın
status=0
SECONDS=0

ERR_PATTERN='SCRIPT ERROR|Parse Error|Failed to load script|Failed to instantiate|Invalid call|Invalid access|Nonexistent function|PROBE HATA|SIM HATA'
[ "${VERIFY_STRICT:-0}" = "1" ] && ERR_PATTERN="$ERR_PATTERN|ERROR: "

fail() { echo "  ✗ $1"; status=1; }
ok() { echo "  ✓ $1"; }

# Taşınabilir zaman aşımı (macOS'ta 'timeout' yok). Kullanım: run_godot <log> <sn> <komut...>
run_godot() {
  local log="$1" limit="$2"; shift 2
  "$@" >"$log" 2>&1 &
  local pid=$! waited=0
  while kill -0 "$pid" 2>/dev/null; do
    sleep 1; waited=$((waited + 1))
    if [ "$waited" -ge "$limit" ]; then
      kill -9 "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
      echo "  ✗ zaman aşımı (${limit} sn): $(basename "$log" .log) — süreç $pid öldürüldü"
      return 124
    fi
  done
  wait "$pid"
}

scan() {  # scan <log> <etiket>: betik hatası varsa kırmızı
  local hits
  hits=$(grep -cE "$ERR_PATTERN" "$1" 2>/dev/null || true)
  if [ "${hits:-0}" -gt 0 ]; then
    fail "$2: $hits hata satırı"
    grep -m5 -E "$ERR_PATTERN" "$1" | sed 's/^/      /'
    return 1
  fi
  return 0
}

# --- Oyuncu kaydı koruması: gerçek user:// dosyalarının anlık görüntüsü ---------------------------------
proj_name=$(sed -n 's/^config\/name="\(.*\)"/\1/p' project.godot | head -1)
user_dirs=("$HOME/Library/Application Support/Godot/app_userdata/$proj_name" "$HOME/.local/share/godot/app_userdata/$proj_name")
snapshot_user() {
  for d in "${user_dirs[@]}"; do
    for f in neon_arena_3d.cfg neon_arena_3d.cfg.bak neon_arena_3d.cfg.tmp neon_arena_3d.cfg.corrupt; do
      if [ -e "$d/$f" ]; then
        local sum; sum=$( (md5 -q "$d/$f" 2>/dev/null || md5sum "$d/$f" 2>/dev/null | cut -d' ' -f1) )
        echo "$f mtime=$( (stat -f %m "$d/$f" 2>/dev/null || stat -c %Y "$d/$f") ) size=$( (stat -f %z "$d/$f" 2>/dev/null || stat -c %s "$d/$f") ) md5=$sum"
      else
        echo "$f yok"
      fi
    done
  done
}
USER_BEFORE=$(snapshot_user)

command -v "$GODOT" >/dev/null 2>&1 || { echo "hata: godot bulunamadı (GODOT=/yol/godot)"; exit 2; }
echo "proje: $ROOT · $("$GODOT" --version 2>/dev/null | head -1) · hızlı=$FAST"

# 1. İçe aktarma: iki geçiş. İlk geçişte henüz içe aktarılmamış varlık (font/ses) için "açılamadı" gürültüsü olabilir;
#    ikinci geçiş otoritedir ve betik hatası taraması onun üzerinden yapılır.
echo "▸ 1. içe aktarma (×2)"; t0=$SECONDS
run_godot "$LOG/import1.log" "$IMPORT_TIMEOUT" "$GODOT" --headless --path . --import || true
if run_godot "$LOG/import.log" "$IMPORT_TIMEOUT" "$GODOT" --headless --path . --import; then
  scan "$LOG/import.log" "içe aktarma" && ok "betikler derlendi (ikinci geçiş temiz) · $((SECONDS - t0)) sn"
else
  fail "içe aktarma başarısız"
fi

# 2. Birim testleri (tests/unit + tests/sim) + kayıt koruması testi
echo "▸ 2. testler"; t0=$SECONDS
if run_godot "$LOG/tests.log" "$STEP_TIMEOUT" "$GODOT" --headless --path . -s res://tests/run_tests.gd -- --no-save; then
  summary=$(grep -E "^[0-9]+ test geçti" "$LOG/tests.log" | tail -1)
  ok "$summary · $((SECONDS - t0)) sn"
else
  fail "testler başarısız"; grep -E "✗|başarısız" "$LOG/tests.log" | head -12 | sed 's/^/      /'
fi
scan "$LOG/tests.log" "testler"
n_tests=$(grep -cE "^  ✓ test_" "$LOG/tests.log" || true)
[ "${n_tests:-0}" -lt 80 ] && fail "test sayısı beklenenden az ($n_tests < 80): bir test dosyası yüklenmemiş olabilir"

# 3. Açılış
echo "▸ 3. açılış (300 kare)"; t0=$SECONDS
if run_godot "$LOG/boot.log" "$STEP_TIMEOUT" "$GODOT" --headless --path . --quit-after 300 -- --no-save; then
  if grep -Eq "$ERR_PATTERN|ERROR: " "$LOG/boot.log"; then
    fail "açılışta hata"; grep -E "$ERR_PATTERN|ERROR: " "$LOG/boot.log" | head -5 | sed 's/^/      /'
  else
    ok "temiz açılış · $((SECONDS - t0)) sn"
  fi
else
  fail "açılış başarısız"
fi

# 4. Probeler (--no-save): SONUÇ: geçti satırı + çıkış kodu 0 + betik hatası yok
echo "▸ 4. probeler"; t0=$SECONDS
for probe in meta synergy touch ads; do
  if run_godot "$LOG/probe_$probe.log" "$STEP_TIMEOUT" "$GODOT" --headless --path . -s "res://tools/dev/${probe}_probe.gd" -- --no-save \
     && grep -q "SONUÇ: geçti" "$LOG/probe_$probe.log"; then
    ok "${probe}_probe"
  else
    fail "${probe}_probe başarısız"; grep -E "✗|SONUÇ" "$LOG/probe_$probe.log" | head -6 | sed 's/^/      /'
  fi
  scan "$LOG/probe_$probe.log" "${probe}_probe"
done
# lang_probe doğrulama basmaz (yalnız bilgi): betiğin hatasız bitmesi yeterli.
if run_godot "$LOG/probe_lang.log" "$STEP_TIMEOUT" "$GODOT" --headless --path . -s res://tools/dev/lang_probe.gd -- --no-save; then
  ok "lang_probe (hatasız bitti)"
else
  fail "lang_probe başarısız"
fi
scan "$LOG/probe_lang.log" "lang_probe"
echo "    probeler: $((SECONDS - t0)) sn"

if [ "$FAST" != "1" ]; then
  # 5. Kısa bot oyunu (gerçek sahne): 20 gerçek sn × 3 hız = 60 oyun sn; en az 3 öldürme, 2. dalga, seviye atlama, nova.
  echo "▸ 5. bot oyunu (gerçek sahne, 60 oyun sn)"; t0=$SECONDS
  if run_godot "$LOG/smoke.log" "$STEP_TIMEOUT" "$GODOT" --headless --path . -s res://tools/smoke_test.gd -- --demo --ship=sahin --seconds=20; then
    ok "$(grep -m1 '^SONUÇ' "$LOG/smoke.log") · $((SECONDS - t0)) sn"
  else
    fail "bot oyunu başarısız"; grep -E "SONUÇ|Yetersiz|ulaşılamadı|Hiç|Nova" "$LOG/smoke.log" | head -5 | sed 's/^/      /'
  fi
  scan "$LOG/smoke.log" "bot oyunu"

  # 6. Denge simülasyonu (başsız, tohumlu): hızlı ızgara; VERIFY_FULL_SIM=1 ile tam ızgara
  echo "▸ 6. denge simülasyonu"; t0=$SECONDS
  if [ "${VERIFY_FULL_SIM:-0}" = "1" ]; then sim_args="--seeds=20 --careers=3"; else sim_args="--quick"; fi
  if run_godot "$LOG/sim.log" "$SIM_TIMEOUT" "$GODOT" --headless --path . -s res://tools/sim/balance_sim.gd -- $sim_args --out=build/sim/balance_report.json \
     && grep -q "SİM SONUÇ: geçti" "$LOG/sim.log"; then
    ok "$(grep -m1 '^medyan dalga' "$LOG/sim.log") · $((SECONDS - t0)) sn"
    command -v python3 >/dev/null 2>&1 && python3 tools/sim/report.py build/sim/balance_report.json -o build/sim/balance_report.md >/dev/null 2>&1 && echo "    rapor: build/sim/balance_report.md"
  else
    fail "simülasyon doğrulaması başarısız"; grep -E "SIM HATA|SİM SONUÇ" "$LOG/sim.log" | head -8 | sed 's/^/      /'
  fi
  scan "$LOG/sim.log" "simülasyon"

  # 7. PCK: paketle, eksik/sızıntı/boyut denetimi
  echo "▸ 7. PCK denetimi (≤ ${PCK_MAX_MB} MB)"; t0=$SECONDS
  rm -f build/verify/na.pck
  if grep -q 'name="Android"' export_presets.cfg && run_godot "$LOG/export.log" "$STEP_TIMEOUT" "$GODOT" --headless --path . --export-pack "Android" build/verify/na.pck && [ -f build/verify/na.pck ]; then
    if command -v python3 >/dev/null 2>&1; then
      if python3 tools/pck_check.py build/verify/na.pck --max-mb "$PCK_MAX_MB" > "$LOG/pck.log" 2>&1; then
        ok "$(head -1 "$LOG/pck.log") · $((SECONDS - t0)) sn"
      else
        fail "PCK denetimi"; sed 's/^/      /' "$LOG/pck.log" | head -20
      fi
    else
      fail "python3 yok: PCK denetimi yapılamadı"
    fi
  else
    fail "PCK üretilemedi (export_presets.cfg 'Android' ön ayarı / --export-pack)"; tail -5 "$LOG/export.log" | sed 's/^/      /'
  fi
else
  echo "▸ 5-7. bot oyunu, simülasyon, PCK: atlandı (VERIFY_FAST=1)"
fi

# 8. Oyuncu kaydı dokunulmadı mı?
echo "▸ 8. oyuncu kaydı koruması"
USER_AFTER=$(snapshot_user)
if [ "$USER_BEFORE" = "$USER_AFTER" ]; then
  ok "gerçek kayıt dosyaları değişmedi:"; echo "$USER_AFTER" | grep -v "yok$" | sed 's/^/      /'
else
  fail "gerçek kayıt dosyaları DEĞİŞTİ"; echo "      önce:"; echo "$USER_BEFORE" | sed 's/^/        /'; echo "      sonra:"; echo "$USER_AFTER" | sed 's/^/        /'
fi

echo
if [ $status -eq 0 ]; then printf '✓ doğrulama geçti (%d sn)\n' "$SECONDS"; else printf '✗ doğrulama BAŞARISIZ (%d sn) — günlükler: tests/results/\n' "$SECONDS"; fi
exit $status
