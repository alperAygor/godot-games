#!/usr/bin/env bash
# Play Store ekran görüntüleri (1080x1920) — gerçek oynanıştan, gerçek pencerede (headless ÇALIŞMAZ).
#   tools/store_shots.sh [çıktı dizini, varsayılan build/store/shots] [dil, varsayılan en]
# Ekran yüksekliği 1920'ye yetmediği için pencere 810x1440 (9:16, 0.75 ölçek) açılır; sonda
# Lanczos ile 1080x1920'ye büyütülür (Play 9:16, 320-3840 px kabul eder; 810x1440 de tek başına geçerlidir).
# Her çekim sert zaman aşımıyla çalışır (başka pencere öndeyse gerçek pencere araçları takılabilir).
# Araçlar Progress.persist=false kullanır: oyuncu kaydına yazılmaz.
set -u
cd "$(dirname "$0")/.." || exit 2
OUT="${1:-build/store/shots}"; LANG_CODE="${2:-en}"; LIMIT="${SHOT_TIMEOUT:-150}"
mkdir -p "$OUT"
shot() { # ad araç argümanlar...
  local name="$1" tool="$2"; shift 2
  local file="$OUT/${LANG_CODE}_$name.png"
  godot --path . --resolution 810x1440 -s "res://tools/$tool.gd" -- "$@" --lang="$LANG_CODE" --out="$file" >"$OUT/${LANG_CODE}_$name.log" 2>&1 &
  local pid=$! waited=0
  while kill -0 "$pid" 2>/dev/null; do
    sleep 1; waited=$((waited + 1))
    if [ "$waited" -ge "$LIMIT" ]; then kill -9 "$pid" 2>/dev/null; echo "zaman asimi: $name"; return; fi
  done
  [ -f "$file" ] && echo "tamam: $file" || echo "BASARISIZ: $name (bkz. $OUT/${LANG_CODE}_$name.log)"
}
# Bahçe / sahil / çatı / farklı mevsimler: seviye numarası yer-mevsim döngüsünü belirler (docs/ARCHITECTURE).
shot garden_early   play_shot --level=6  --taps=4
shot garden_mid     play_shot --level=22 --taps=6
shot beach          play_shot --level=41 --taps=5
shot rooftop        play_shot --level=61 --taps=5
shot late_season    play_shot --level=95 --taps=6
shot home           ui_shot   --shot=home
shot shop           ui_shot   --shot=shop
shot win            ui_shot   --shot=win
python3 - "$OUT" "$LANG_CODE" <<'PY'
import glob, sys
from PIL import Image
out, lang = sys.argv[1], sys.argv[2]
for f in sorted(glob.glob("%s/%s_*.png" % (out, lang))):
    im = Image.open(f).convert("RGB")
    if im.size != (1080, 1920):
        im.resize((1080, 1920), Image.LANCZOS).save(f, optimize=True)
PY
echo "bitti: $OUT"
