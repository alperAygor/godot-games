extends RefCounted
class_name Loadout
## Toplanan kartlar ve bunların türettiği oyuncu çarpanları; kart sunumu (ağırlık, acıma), evrim, yasaklama, lanet.
##
## Veri: kartlar `data/cards.json`, kurallar `data/card_rules.json` (ağırlıklar, sınırlar, acıma, yasaklama, sayılar).
## Kademeler (tier): common/rare/epic (normal havuz), synergy (gereken kartlar `requires` alınınca havuza girer),
## evolution (`evolve` = {kart: seviye}; hepsi tamamlanınca bir sonraki sunumda garanti), cursed (havuzda YOK; yalnız
## `apply_curse` ile — C1 sektör kapısı).
##
## LANETLİ KART API'si (C1 için; saf, sahnesiz):
##   cursed_cards() -> Array            alınmamış lanetli kart sözlükleri (sırası veri sırası)
##   curse_info(card) -> Dictionary     {id, name, desc, drawback, reward_mult} — arayüz için (metinler Türkçe anahtar; tr() ile çevir)
##   apply_curse(id) -> bool            etkiyi uygular + `core_mult`'u reward_mult ile çarpar (koşu sonu çekirdek ödülü
##                                      RunFlow'da zaten loadout.m("core_mult") ile hesaplanır: İKİNCİ KEZ ÇARPMAYIN)
##   curse_reward_mult() -> float       alınan lanetlerin ödül çarpanı çarpımı (gösterim için)
##   curses: Array[String]              alınan lanet kimlikleri
## Oyun sahnesinde lanet uygulandıktan sonra gemi istatistikleri yenilenmeli: `ctx.effects.apply_curse(id)` bunu yapar
## (scripts/game/card_effects.gd); doğrudan Loadout kullanılırsa ardından `ctx.control.apply_loadout()` çağrılmalı.

const RULES_PATH := "res://data/card_rules.json"
## Bilinen kademeler (içerik doğrulaması bunu kullanır). Gerçek sunum ağırlıkları data/card_rules.json → tier_weight.
const TIER_WEIGHT := {"common": 60.0, "rare": 30.0, "epic": 15.0, "synergy": 130.0, "evolution": 200.0, "cursed": 0.0}

static var _rules_cache: Dictionary = {}

var pool: Array = []
var taken: Array[String] = []
var mods: Dictionary = _defaults()
var rules: Dictionary = {}
var banished: Array[String] = []
var banishes_left := 0
var curses: Array[String] = []
var synergy_miss := 0              ## hazır sinerjinin art arda sunulmadığı çekiliş sayısı (acıma)

var _limits: Dictionary = {}
var _raises: Dictionary = {}
var _weights: Dictionary = {}
var _counts: Dictionary = {}       ## id -> alınma sayısı (taken ile eş)
var _recipes: Array = []           ## [{card, need: {id: seviye}}] sinerji + evrim
var _by_id: Dictionary = {}

func _init(cards: Array, rules_override: Dictionary = {}) -> void:
	pool = cards
	rules = rules_override if not rules_override.is_empty() else load_rules()
	_limits = rules.get("limits", {})
	_raises = rules.get("limit_raises", {})
	_weights = rules.get("tier_weight", TIER_WEIGHT)
	for card in pool:
		_by_id[str(card.get("id", ""))] = card
		var need := recipe_of(card)
		if not need.is_empty():
			_recipes.append({"card": card, "need": need})
	reset()

static func load_rules() -> Dictionary:
	## data/card_rules.json (bir kez okunur). Okunamazsa boş sözlük: varsayılan sınır/ağırlıklar devrede kalır.
	if _rules_cache.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
		if parsed is Dictionary:
			_rules_cache = parsed
	return _rules_cache

static func param(key: String, fallback := 0.0) -> float:
	## data/card_rules.json → params içinden sayı (kurulumda okunur; kare başına çağrılmaz).
	return float((load_rules().get("params", {}) as Dictionary).get(key, fallback))

static func recipe_of(card: Dictionary) -> Dictionary:
	## Sinerji: requires → her biri 1 seviye; evrim: evolve → {kart: seviye}. Normal kart: boş.
	var need := {}
	var evolve: Variant = card.get("evolve", {})
	if evolve is Dictionary:
		for id in evolve:
			need[str(id)] = int(evolve[id])
	for id in card.get("requires", []):
		need[str(id)] = maxi(1, int(need.get(str(id), 1)))
	return need

static func _defaults() -> Dictionary:
	return {
		"damage_mult": 1.0, "fire_rate_mult": 1.0, "speed_mult": 1.0,
		"max_hp_bonus": 0.0, "dash_cd_mult": 1.0, "projectiles": 1,
		"pierce": 0, "crit": 0.0, "vampire": 0.0, "magnet": 1.0,
		"regen": 0.0, "thorns": 0.0, "drones": 0, "bullet_size": 1.0,
		"chain": 0, "explosive": 0, "dash_damage": 0.0, "nova_rate_mult": 1.0,
		"shield_regen": 0, "revive": 0,
		# Kalıcı (atölye / gemi) etkileri
		"xp_mult": 1.0, "core_mult": 1.0, "nova_start": 0.0, "rerolls": 0.0, "start_shield": 0.0, "banishes": 0.0,
		# Sinerjiler
		"storm": 0, "harvest": 0, "doom_nova": 0, "blitz": 0, "hive": 0, "fortress": 0,
		# C3: denge anahtarları
		"projectile_damage_mult": 1.0, "chain_power": 0.0, "dash_nova": 0.0,
		# C3: yeni kartlar
		"orbit_blades": 0, "turret": 0, "rear_guns": 0, "ricochet": 0, "execute": 0.0, "crit_shards": 0,
		"momentum": 0.0, "nova_vortex": 0, "dash_trail": 0, "adrenaline": 0, "reflect": 0, "kill_shield": 0,
		"steady": 0.0, "pickup_blast": 0, "hunter": 0.0, "combo_power": 0.0, "nova_shell": 0, "split_shot": 0,
		"static_field": 0, "overdrive_plus": 0, "dash_blast": 0, "plating": 0.0, "missile_pod": 0, "shield_bash": 0,
		# C3: evrimler
		"evo_starfall": 0, "evo_swarm": 0, "evo_thunder": 0, "evo_bloodmoon": 0, "evo_comet": 0, "evo_singularity": 0,
		# C3: lanet bedelleri
		"heal_mult": 1.0, "hurt_mult": 1.0, "offer_size": 0.0,
	}

func reset() -> void:
	taken.clear()
	_counts.clear()
	banished.clear()
	curses.clear()
	synergy_miss = 0
	mods = _defaults()
	banishes_left = int((rules.get("banish", {}) as Dictionary).get("per_run", 0))

# --- Sunum --------------------------------------------------------------------------
func offer_size(count: int) -> int:
	var offer: Dictionary = rules.get("offer", {})
	return maxi(int(offer.get("min_offer", 1)), count + i("offer_size"))

func roll(count: int, rng: RandomNumberGenerator) -> Array:
	## `count` kart (lanet `offer_size` ile azalabilir) — aynı kart iki kez yok, dolmuş/yasaklı/lanetli yok.
	## Sıra: hazır evrim (garanti) → acıması dolmuş hazır sinerji (garanti) → ağırlıklı çekiliş (iadesiz).
	var offer: Dictionary = rules.get("offer", {})
	var n := offer_size(count)
	var choices: Array = []
	var available: Array = []
	var weights: Array[float] = []
	var ready_synergy: Array = []
	for card in pool:
		if not offerable(card):
			continue
		var tier := str(card.get("tier", "common"))
		if tier == "evolution" and bool(offer.get("evolution_guaranteed", true)):
			if choices.size() < n:
				choices.append(card)
			continue
		if tier == "synergy":
			ready_synergy.append(card)
		available.append(card)
		weights.append(card_weight(card))
	if not ready_synergy.is_empty() and synergy_miss >= int(offer.get("synergy_pity_rolls", 999)) and choices.size() < n:
		var forced: Dictionary = ready_synergy[0]
		choices.append(forced)
		var at := available.find(forced)
		available.remove_at(at)
		weights.remove_at(at)
	while choices.size() < n and not available.is_empty():
		var total := 0.0
		for w in weights:
			total += w
		if total <= 0.0:
			break
		var roll_value := rng.randf() * total
		var idx := available.size() - 1
		for k in available.size():
			roll_value -= weights[k]
			if roll_value <= 0.0:
				idx = k
				break
		choices.append(available[idx])
		available.remove_at(idx)
		weights.remove_at(idx)
	if ready_synergy.is_empty():
		synergy_miss = 0
	else:
		var shown := false
		for c in choices:
			if str(c.get("tier", "")) == "synergy":
				shown = true
				break
		synergy_miss = 0 if shown else synergy_miss + 1
	return choices

func card_weight(card: Dictionary) -> float:
	## Kademe ağırlığı × kartın kendi `weight`i; elinde parçası olan sinerji/evrimin eksik parçasıysa × piece_mult
	## (en az piece_min_weight: destansı parça da yaygın parça kadar sık gelir → sinerjiler benzer sıklıkta).
	var w := float(_weights.get(str(card.get("tier", "common")), 10.0)) * float(card.get("weight", 1.0))
	if is_missing_piece(str(card.get("id", ""))):
		var offer: Dictionary = rules.get("offer", {})
		w = maxf(w * float(offer.get("piece_mult", 1.0)), float(offer.get("piece_min_weight", 0.0)))
	return w

func is_missing_piece(id: String) -> bool:
	## Bu kart, başka bir parçası elde olan (ve kendisi henüz alınmamış) bir sinerji/evrimin eksik parçası mı?
	for r in _recipes:
		var card: Dictionary = r["card"]
		var rid := str(card.get("id", ""))
		if count(rid) > 0 or banished.has(rid):
			continue
		var need: Dictionary = r["need"]
		if not need.has(id) or count(id) >= int(need[id]):
			continue
		for other in need:
			if str(other) != id and count(str(other)) > 0:
				return true
	return false

func offerable(card: Dictionary) -> bool:
	var tier := str(card.get("tier", "common"))
	if not (tier in (rules.get("offer", {}) as Dictionary).get("pool_tiers", ["common", "rare", "epic", "synergy", "evolution"])):
		return false
	if banished.has(str(card.get("id", ""))):
		return false
	return not _is_maxed(card)

func limit(key: String) -> int:
	## Veri sınırı (card_rules.json → limits) + açık olan sınır yükselticiler (limit_raises; ör. Kovan Zihni drone +1).
	var base := int(_limits.get(key, 999))
	for raiser in _raises:
		if int(mods.get(raiser, 0)) > 0:
			base += int((_raises[raiser] as Dictionary).get(key, 0))
	return base

func requirements_met(card: Dictionary) -> bool:
	var need := recipe_of(card)
	for id in need:
		if count(str(id)) < int(need[id]):
			return false
	return true

func _is_maxed(card: Dictionary) -> bool:
	if not requirements_met(card):
		return true
	var id := str(card.get("id", ""))
	var tier := str(card.get("tier", ""))
	if (tier == "synergy" or tier == "evolution" or tier == "cursed") and count(id) > 0:
		return true
	if int(card.get("max", 0)) > 0 and count(id) >= int(card["max"]):
		return true
	var effect: Dictionary = card.get("effect", {})
	for key in effect:
		if _limits.has(key) and int(mods.get(key, 0)) >= limit(key):
			# Sınırı aynı kartta yükselten anahtar varsa (Kovan Zihni + drone) takılmasın.
			var raised := false
			for other in effect:
				if _raises.has(other) and (_raises[other] as Dictionary).has(key):
					raised = true
			if raised:
				continue
			return true
	return false

func synergies_ready() -> Array:
	## Gereksinimleri tamam, henüz alınmamış sinerji kartları.
	var out: Array = []
	for card in pool:
		if str(card.get("tier", "")) == "synergy" and offerable(card):
			out.append(card)
	return out

func evolutions_ready() -> Array:
	var out: Array = []
	for card in pool:
		if str(card.get("tier", "")) == "evolution" and offerable(card):
			out.append(card)
	return out

func evolution_progress() -> Array:
	## Arayüz için: en az bir parçası elde olan, alınmamış evrimler. [{card, need, have, done, total, ready}]
	## done/total = tamamlanan seviye / gereken seviye toplamı; en yakın olan önce.
	var out: Array = []
	for r in _recipes:
		var card: Dictionary = r["card"]
		if str(card.get("tier", "")) != "evolution" or count(str(card.get("id", ""))) > 0:
			continue
		var need: Dictionary = r["need"]
		var have := {}
		var done := 0
		var total := 0
		for id in need:
			var c := mini(count(str(id)), int(need[id]))
			have[id] = c
			done += c
			total += int(need[id])
		if done <= 0:
			continue
		out.append({"card": card, "need": need, "have": have, "done": done, "total": total, "ready": done >= total})
	out.sort_custom(func(a, b): return float(a["done"]) / float(a["total"]) > float(b["done"]) / float(b["total"]))
	return out

# --- Alma -----------------------------------------------------------------------------
func apply(card: Dictionary) -> void:
	var id := str(card.get("id", "?"))
	taken.append(id)
	_counts[id] = int(_counts.get(id, 0)) + 1
	apply_effects(card.get("effect", {}))

func apply_effects(effect: Dictionary) -> void:
	## Kart, atölye veya gemi etkisini uygular. *_mult anahtarları çarpılır, diğerleri eklenir.
	## Sınır yükselten anahtarlar (hive, evo_*) önce işlenir ki aynı karttaki drone/mermi doğru sınıra tabi olsun.
	var keys: Array = effect.keys()
	var raisers := _raises
	keys.sort_custom(func(a, b): return raisers.has(str(a)) and not raisers.has(str(b)))
	for key in keys:
		var value := float(effect[key])
		if not mods.has(key):
			mods[key] = 1.0 if str(key).ends_with("_mult") else 0.0
		if str(key).ends_with("_mult"):
			mods[key] = maxf(0.3, float(mods[key]) * (1.0 + value))
		elif _limits.has(key):
			mods[key] = mini(limit(key), int(mods[key]) + int(value))
		else:
			mods[key] = float(mods[key]) + value

func count(id: String) -> int:
	return int(_counts.get(id, 0))

# --- Yasaklama ------------------------------------------------------------------------
func can_banish(id: String) -> bool:
	if banishes_left + i("banishes") <= 0 or banished.has(id) or not _by_id.has(id):
		return false
	return str((_by_id[id] as Dictionary).get("tier", "")) != "cursed"

func banish(id: String) -> bool:
	## Kartı koşu boyunca havuzdan çıkarır (sınırlı hak). Elde olan kopyalar kalır; yalnız yeniden sunulmaz.
	if not can_banish(id):
		return false
	if banishes_left > 0:
		banishes_left -= 1
	else:
		mods["banishes"] = float(mods.get("banishes", 0.0)) - 1.0
	banished.append(id)
	return true

func banishes_total() -> int:
	return banishes_left + i("banishes")

# --- Lanetli kartlar (C1 kapısı) ------------------------------------------------------------
func cursed_cards() -> Array:
	var out: Array = []
	for card in pool:
		if str(card.get("tier", "")) == "cursed" and count(str(card.get("id", ""))) == 0:
			out.append(card)
	return out

static func curse_info(card: Dictionary) -> Dictionary:
	var curse: Dictionary = card.get("curse", {})
	return {
		"id": str(card.get("id", "")), "name": str(card.get("name", "")), "desc": str(card.get("desc", "")),
		"drawback": str(curse.get("drawback", "")), "reward_mult": float(curse.get("reward_mult", 1.0)),
	}

func apply_curse(id: String) -> bool:
	if not _by_id.has(id):
		return false
	var card: Dictionary = _by_id[id]
	if str(card.get("tier", "")) != "cursed" or count(id) > 0:
		return false
	apply(card)
	curses.append(id)
	var mult := float((card.get("curse", {}) as Dictionary).get("reward_mult", 1.0))
	if mult != 1.0:
		apply_effects({"core_mult": mult - 1.0})
	return true

func curse_reward_mult() -> float:
	var out := 1.0
	for id in curses:
		out *= float(((_by_id[id] as Dictionary).get("curse", {}) as Dictionary).get("reward_mult", 1.0))
	return out

# --- Kayıt (koşu sürdürme için) ----------------------------------------------------------
func to_dict() -> Dictionary:
	return {"taken": Array(taken), "banished": Array(banished), "banishes_left": banishes_left, "curses": Array(curses), "synergy_miss": synergy_miss}

func from_dict(d: Dictionary, base_effects: Array = []) -> void:
	## Koşuyu geri yükler: kalıcı etkiler (atölye/gemi: `base_effects`, sırayla) + kartlar aynı sırayla yeniden uygulanır.
	reset()
	for effect in base_effects:
		apply_effects(effect)
	var cursed_ids: Array = d.get("curses", [])
	for id in d.get("taken", []):
		var sid := str(id)
		if not _by_id.has(sid):
			continue
		if cursed_ids.has(sid):
			apply_curse(sid)
		else:
			apply(_by_id[sid])
	for id in d.get("banished", []):
		banished.append(str(id))
	banishes_left = int(d.get("banishes_left", banishes_left))
	synergy_miss = int(d.get("synergy_miss", 0))

func summary() -> Array:
	## Alınan kartlar: [{card, count}] — arayüzde yapı özeti için.
	var out: Array = []
	var seen := {}
	for id in taken:
		if seen.has(id):
			continue
		seen[id] = true
		if _by_id.has(id):
			out.append({"card": _by_id[id], "count": count(id)})
	return out

func m(key: String) -> float:
	return float(mods.get(key, 0.0))

func i(key: String) -> int:
	return int(mods.get(key, 0))
