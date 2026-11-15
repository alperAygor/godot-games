#!/usr/bin/env bash
# İmzalı release AAB üretimi — kapı geçmeden AAB ÜRETMEZ.
#   export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=... _USER=... _PASSWORD=...   (docs/store/SIGNING.md)
#   tools/release_build.sh              # kapı (yapılandırma) -> export-release -> kapı (AAB)
#   tools/release_build.sh --debug-aab  # İŞ HATTI DENEMESİ: kapıyı atlar, hata ayıklama şablonuyla imzasız AAB (Play'e YÜKLENEMEZ)
# Gradle daemon'ları iş bitince durdurulur. Çıkış: 0 başarı, 1 kapı/derleme hatası, 2 araç hatası.
set -uo pipefail
GODOT="${GODOT_PATH:-$(command -v godot || echo /Applications/Godot.app/Contents/MacOS/Godot)}"
cd "$(dirname "$0")/.." || exit 2
ROOT="$(pwd)"
PRESET="Android Release"
OUT_DIR="$ROOT/build/release"
mkdir -p "$OUT_DIR"
export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
[ -x "$JAVA_HOME/bin/java" ] || { echo "hata: JDK 17 yok (JAVA_HOME=$JAVA_HOME)" >&2; exit 2; }

stop_gradle() { [ -x "$ROOT/android/build/gradlew" ] && (cd "$ROOT/android/build" && ./gradlew --stop > /dev/null 2>&1); }
trap stop_gradle EXIT

ensure_template() {
  if [ ! -f "$ROOT/android/build/build.gradle" ]; then
    echo "== Gradle şablonu kuruluyor (yerel android_source.zip; indirme yok)"
    DV_SANDBOX=1 "$GODOT" --headless --path "$ROOT" --install-android-build-template --export-debug "$PRESET" "$OUT_DIR/_template_probe.aab" > /dev/null 2>&1
    rm -f "$OUT_DIR/_template_probe.aab"
  fi
}

scan_log() {  # $1 = log
  if grep -a -E "SCRIPT ERROR|Parse Error|^ERROR:|FAILED|BUILD FAILED" "$1" | grep -v -E "adb|tcp:5037" > /dev/null; then
    echo "hata: derleme çıktısında hata (bkz. $1)" >&2
    grep -a -E "SCRIPT ERROR|Parse Error|^ERROR:|FAILED" "$1" | head -10 >&2
    return 1
  fi
  return 0
}

if [ "${1:-}" = "--debug-aab" ]; then
  OUT="$OUT_DIR/doviz-burosu-debug.aab"
  ensure_template
  DV_SANDBOX=1 "$GODOT" --headless --path "$ROOT" --export-debug "$PRESET" "$OUT" > "$OUT_DIR/export_debug.log" 2>&1
  [ -f "$OUT" ] && scan_log "$OUT_DIR/export_debug.log" || { echo "hata: debug AAB üretilemedi" >&2; exit 1; }
  echo "== debug AAB (imzasız, YALNIZ iş hattı kanıtı): $OUT"
  python3 -I "$ROOT/tools/aab_inspect.py" "$OUT"
  exit 0
fi

echo "== 1/3 Kapı: yapılandırma"
bash "$ROOT/tools/release_check.sh" || { echo "KAPI GEÇMEDİ: AAB üretilmedi. Yukarıdaki FAIL satırlarını gider." >&2; exit 1; }
ensure_template
OUT="$OUT_DIR/doviz-burosu-release.aab"
rm -f "$OUT"
echo "== 2/3 Derleme (export-release)"
DV_SANDBOX=1 "$GODOT" --headless --path "$ROOT" --export-release "$PRESET" "$OUT" > "$OUT_DIR/export_release.log" 2>&1
[ -f "$OUT" ] || { echo "hata: release AAB üretilemedi (bkz. $OUT_DIR/export_release.log)" >&2; exit 1; }
scan_log "$OUT_DIR/export_release.log" || exit 1
echo "== 3/3 Kapı: üretilen AAB"
bash "$ROOT/tools/release_check.sh" "$OUT" || { echo "AAB kapıyı geçemedi: Play'e yükleme." >&2; exit 1; }
echo "AAB: $OUT"
ls -l "$OUT" | awk '{print "boyut (bayt):", $5}'
shasum -a 256 "$OUT"
