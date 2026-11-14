#!/usr/bin/env bash
# Android emülatörünü (zaten açık değilse) başlatır ve açılışın bitmesini bekler.
# Kullanım: tools/emulator_start.sh [avd_adı]     (varsayılan: mobile_game_api36)
# GPU: SwiftShader (yazılımsal). Mac'te donanım GPU modu (host) Godot'ta siyah ekran veriyor.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
ADB="$SDK/platform-tools/adb"
AVD="${1:-mobile_game_api36}"

"$ADB" start-server > /dev/null 2>&1
if "$ADB" devices | grep -q "^emulator-.*device$"; then
  echo "Emülatör zaten açık: $("$ADB" devices | grep '^emulator-' | cut -f1)"
  exit 0
fi

mkdir -p "$ROOT/tests/results"
echo "Emülatör başlatılıyor: $AVD (log: tests/results/emulator.log)"
nohup "$SDK/emulator/emulator" -avd "$AVD" -gpu swiftshader_indirect -no-boot-anim -no-audio \
  > "$ROOT/tests/results/emulator.log" 2>&1 &

# En fazla 5 dakika bekle (macOS'ta `timeout` yok, perl alarm kullanılıyor).
if ! perl -e 'alarm 300; exec @ARGV' "$ADB" wait-for-device shell \
    'while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 2; done'; then
  echo "Emülatör 5 dakikada açılmadı. tests/results/emulator.log'a bak." >&2
  exit 1
fi
echo "Hazır: Android $("$ADB" shell getprop ro.build.version.release) (SDK $("$ADB" shell getprop ro.build.version.sdk))"
