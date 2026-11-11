#!/usr/bin/env bash
# Gerçek pencereyi ekran sınırının altında tutmak OS kaynaklı farklı kırpmaları önler.
set -euo pipefail
PROJECT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-godot}"
for style in a b c; do
  for frame in wide close; do
    "$GODOT" --path "$PROJECT" --resolution 720x1280 \
      --log-file "$PROJECT/docs/art/style_${style}_${frame}.log" \
      -s res://tools/scene_shot.gd -- \
      --scene="res://scenes/styles/style_${style}.tscn" \
      --out="res://docs/art/style_${style}_${frame}.png" \
      --frames=48 --frame="$frame"
  done
done
python3 "$PROJECT/docs/art/build_style_lab_sheet.py"
