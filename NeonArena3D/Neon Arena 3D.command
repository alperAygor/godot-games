#!/bin/bash
# NEON ARENA 3D başlatır (macOS'ta çift tıklanabilir).
cd "$(dirname "$0")" || exit 1
if ! command -v godot >/dev/null 2>&1; then
  echo "godot bulunamadı. Godot 4.7'yi kur ve PATH'e ekle."
  read -r -p "Kapatmak için Enter..."
  exit 1
fi
exec godot --path . --resolution 1280x720
