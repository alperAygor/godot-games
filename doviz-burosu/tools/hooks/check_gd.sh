#!/usr/bin/env bash
# Claude Code PostToolUse hook'u (Edit|Write): düzenlenen .gd dosyasını Godot ile ayrıştırır (~0.2 sn).
# Hata varsa çıkış kodu 2 ile Claude'a bildirir; Claude aynı turda düzeltir.
# Not: --check-only autoload'ları başlatmaz; "Compile Error: Identifier not found: <Autoload>" yanlış alarm
# olduğundan sadece "Parse Error" satırları sayılır (tanımsız isim, sözdizimi, tip hataları bunlardır).
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT_PATH:-$(command -v godot || echo /Applications/Godot.app/Contents/MacOS/Godot)}"

file="$(jq -r '.tool_input.file_path // .tool_response.filePath // empty')"
[[ "$file" == *.gd ]] || exit 0
case "$file" in "$ROOT"/*) ;; *) exit 0 ;; esac
[ -f "$file" ] || exit 0
rel="${file#"$ROOT"/}"

parse_errors() {
  "$GODOT" --headless --path "$ROOT" --check-only --script "res://$rel" 2>&1 | grep -A1 "SCRIPT ERROR: Parse Error"
}

errors="$(parse_errors)"
if [ -n "$errors" ]; then
  # Yeni class_name'ler sınıf önbelleğine henüz girmemiş olabilir: içe aktar ve bir kez daha dene.
  "$GODOT" --headless --path "$ROOT" --import > /dev/null 2>&1
  errors="$(parse_errors)"
fi

if [ -n "$errors" ]; then
  echo "GDScript ayrıştırma hatası: $rel" >&2
  echo "$errors" >&2
  exit 2
fi
exit 0
