#!/usr/bin/env bash
# Yerelleştirme QA: tüm ekran/sayfa görüntülerini bir dil için alır (gerçek pencere; headless ÇALIŞMAZ).
#   tools/i18n_shots.sh <tr|en|es> <çıktı dizini> [GENxYÜK, varsayılan 810x1440] [filtre]
# Kayda yazmaz (araçlar Progress.persist=false kullanır). Pencere 810x1440 = 0.75 ölçek;
# dar ekran denemesi için 540x1260 (1080x2520 mantıksal) verilir.
set -u
LANG_CODE="${1:?dil}"; OUT="${2:?dizin}"; RES="${3:-810x1440}"; FILTER="${4:-}"
mkdir -p "$OUT"
run() { # ad araç argümanlar...
  local name="$1" tool="$2"; shift 2
  if [ -n "$FILTER" ] && [[ "$name" != *$FILTER* ]]; then return; fi
  godot --path . --resolution "$RES" -s "res://tools/$tool.gd" -- "$@" --lang="$LANG_CODE" --out="$OUT/$name.png" >"$OUT/$name.log" 2>&1
}
for s in home soon settings hud pause win lose lose_few lose_many lose_moves shop shop_skins shop_ropes shop_ads shop_owned; do
  run "ui_$s" ui_shot --shot=$s; done
run ui_game_skins ui_shot --shot=game_skins
run ui_home_skins ui_shot --shot=home_skins
# Yer/mevsim afişleri oyun sahnesinde çıkar (ana ekran set_level çağırmaz); 121: iki afiş art arda.
for lv in 31 41 61 81 91; do run "banner_$lv" ui_shot --shot=hud --level=$lv --wait=1600; done
run banner_121 ui_shot --shot=hud --level=121 --wait=5000
for s in machines settings booster boosterzero; do run "q_$s" q_ui_shot --shot=$s; done
for f in wet mystery lock sheet sock_pair dye joker big_basket stain chain wind slide mode_moves mode_short_rack mode_orders mode_boss undo pin_remover extra_slot washer dryer typed_basket birds rain cat dual sun_fade leaves frost pollen; do
  run "tc_$f" q_ui_shot --shot=tc_$f; done
for s in map_early map_35 map_85 map_600 map_f41 map_f61 map_f81 map_f91 card home zen zen_card offline; do run "map_$s" map_shot --shot=$s; done
for s in missions_fresh missions_progress missions_claim milestones_fresh milestones_progress milestones_claim weekly_fresh weekly_progress weekly_claim weekly_chain comeback streak entry locked; do
  run "ret_$s" retention_shot --shot=$s; done
for s in card card_done cal_fresh cal_day3 cal_day7 cal_claim win; do run "daily_$s" daily_shot --shot=$s; done
for s in laundry_empty laundry_half laundry_full laundry_poor collection collection_early collection_all; do run "meta_$s" meta_shot --shot=$s; done
for s in win1 win3; do run "mastery_$s" mastery_shot --shot=$s; done
run play_machines play_shot --level=70 --sheet=machines
run play_cards play_shot --level=14 --cards --taps=0
echo "tamam: $LANG_CODE"
