#!/usr/bin/env bash
# APK'yi derler, bağlı emülatöre/cihaza yükler, başlatır; logcat ve ekran görüntüsü toplar, hataları tarar.
# Kullanım:
#   tools/android_run.sh                      # derle + yükle + çalıştır, hazır işaretini 30 sn bekle
#   tools/android_run.sh --wait 60 --no-export
#   tools/android_run.sh --ready "[Oyun] başladı"   # farklı hazır işareti (logcat'te aranan print metni)
#   tools/android_run.sh --preset "Android"   # Vulkan sürümünü zorla (gerçek cihaz için varsayılan)
# Preset varsayılanı: emülatörde "Android Emulator" (OpenGL/Compatibility), gerçek cihazda "Android" (Vulkan).
# Çıktılar: tests/results/logcat.txt, tools/screenshots/android_latest.png
# Çıkış kodu: 0 sorun yok, 1 derleme/yükleme hatası, çökme veya logcat'te Godot hatası, 2 cihaz yok.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
ADB="$SDK/platform-tools/adb"
GODOT="${GODOT_PATH:-$(command -v godot || echo /Applications/Godot.app/Contents/MacOS/Godot)}"
PKG="$(grep -m1 '^package/unique_name=' export_presets.cfg | cut -d'"' -f2)"
WAIT=30
READY_MARKER="[Main] hazır"
PRESET=""
DO_EXPORT=1

while [ $# -gt 0 ]; do
  case "$1" in
    --wait) WAIT="$2"; shift 2 ;;
    --ready) READY_MARKER="$2"; shift 2 ;;
    --preset) PRESET="$2"; shift 2 ;;
    --no-export) DO_EXPORT=0; shift ;;
    *) echo "Bilinmeyen argüman: $1" >&2; exit 2 ;;
  esac
done

mkdir -p tests/results tools/screenshots
touch tools/screenshots/.gdignore

"$ADB" start-server > /dev/null 2>&1
if ! "$ADB" devices | tail -n +2 | grep -q "device$"; then
  echo "Bağlı cihaz yok. Emülatör için: tools/emulator_start.sh" >&2
  exit 2
fi

if [ -z "$PRESET" ]; then
  if [ "$("$ADB" shell getprop ro.kernel.qemu | tr -d '\r')" = "1" ]; then PRESET="Android Emulator"; else PRESET="Android"; fi
fi
APK="$(awk -v n="name=\"$PRESET\"" '$0==n{f=1} f&&/^export_path=/{gsub(/export_path=|"/,""); print; exit}' export_presets.cfg)"
[ -n "$APK" ] || { echo "export_presets.cfg içinde '$PRESET' yok." >&2; exit 2; }
echo "== Preset: $PRESET → $APK"

if [ "$DO_EXPORT" -eq 1 ]; then
  mkdir -p "$(dirname "$APK")"
  if ! "$GODOT" --headless --path . --export-debug "$PRESET" "$APK" > tests/results/android_export.log 2>&1 \
     || grep -q -E "SCRIPT ERROR|^ERROR: .*export" tests/results/android_export.log; then
    echo "✗ Export başarısız (tests/results/android_export.log)" >&2
    grep -E "ERROR" tests/results/android_export.log | head -10 >&2
    exit 1
  fi
  echo "✓ Export"
fi

# Godot export'u adb sunucusunu yeniden başlatabiliyor; cihazın geri gelmesini bekle.
perl -e 'alarm 60; exec @ARGV' "$ADB" wait-for-device
if ! "$ADB" install -r "$APK" > tests/results/android_install.log 2>&1; then
  echo "✗ Yükleme başarısız" >&2; cat tests/results/android_install.log >&2; exit 1
fi
echo "✓ Yüklendi"

"$ADB" shell am force-stop "$PKG"
"$ADB" logcat -c
"$ADB" shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 > /dev/null 2>&1

# Hazır işaretini (ana sahnenin print'i) en fazla WAIT saniye bekle; sonra 2 sn daha çizim için.
ready=0
for _ in $(seq "$WAIT"); do
  sleep 1
  if "$ADB" logcat -d -s godot:I | grep -q -F "$READY_MARKER"; then ready=1; break; fi
done
sleep 2

PID="$("$ADB" shell pidof "$PKG" | tr -d '\r')"
if [ -z "$PID" ]; then
  "$ADB" logcat -d > tests/results/logcat.txt
  echo "✗ Uygulama çalışmıyor (çöktü veya kapandı). Tüm logcat: tests/results/logcat.txt" >&2
  grep -E "FATAL|AndroidRuntime: |E godot" tests/results/logcat.txt | head -20 >&2
  exit 1
fi

"$ADB" logcat -d --pid="$PID" > tests/results/logcat.txt
"$ADB" exec-out screencap -p > tools/screenshots/android_latest.png
echo "✓ Çalışıyor (pid $PID). Ekran: tools/screenshots/android_latest.png"
grep -E "I godot   : (OpenGL|Vulkan)" tests/results/logcat.txt | sed 's/.*I godot   : /   renderer: /' | head -1

# Godot Android'de uyarıları da "E" seviyesinde yazar; sadece ERROR/SCRIPT ERROR başarısızlık sayılır.
warnings="$(grep -E "godot +: WARNING:" tests/results/logcat.txt)"
if [ -n "$warnings" ]; then
  echo "! $(echo "$warnings" | wc -l | tr -d ' ') Godot uyarısı (başarısızlık sayılmaz):"
  echo "$warnings" | sed 's/.*godot *: /   /' | sort -u | head -5
fi
status=0
errors="$(grep -E -A1 "godot +: (ERROR|SCRIPT ERROR):" tests/results/logcat.txt)"
if [ -n "$errors" ]; then
  echo "✗ logcat'te Godot hatası:" >&2
  echo "$errors" | head -20 >&2
  status=1
else
  echo "✓ logcat'te Godot hatası yok (tests/results/logcat.txt)"
fi
if [ "$ready" -eq 1 ]; then
  echo "✓ Hazır işareti görüldü: \"$READY_MARKER\""
else
  echo "✗ $WAIT sn içinde hazır işareti gelmedi: \"$READY_MARKER\" (yavaş açılış için --wait artır)" >&2
  status=1
fi
echo "  Ekranı kontrol et (siyahsa renderer sorunu): tools/screenshots/android_latest.png"
exit "$status"
