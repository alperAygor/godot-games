extends RefCounted
class_name Loadout
## Toplanan kartlar ve bunların türettiği oyuncu çarpanları.

const TIER_WEIGHT := {"common": 60.0, "rare": 30.0, "epic": 10.0, "synergy": 130.0}
const LIMITS := {
	"projectiles": 3, "drones": 2, "pierce": 4, "chain": 3,
	"explosive": 3, "shield_regen": 1, "revive": 1,
	"storm": 1, "harvest": 1, "doom_nova": 1, "blitz": 1, "hive": 1, "fortress": 1,
}

var pool: Array = []
var taken: Array[String] = []
var mods: Dictionary = _defaults()

func _init(cards: Array) -> void:
	pool = cards

static func _defaults() -> Dictionary:
	return {
		"damage_mult": 1.0, "fire_rate_mult": 1.0, "speed_mult": 1.0,
		"max_hp_bonus": 0.0, "dash_cd_mult": 1.0, "projectiles": 1,
		"pierce": 0, "crit": 0.0, "vampire": 0.0, "magnet": 1.0,
		"regen": 0.0, "thorns": 0.0, "drones": 0, "bullet_size": 1.0,
		"chain": 0, "explosive": 0, "dash_damage": 0.0, "nova_rate_mult": 1.0,
		"shield_regen": 0, "revive": 0,
		# Kalıcı (atölye / gemi) etkileri
		"xp_mult": 1.0, "core_mult": 1.0, "nova_start": 0.0, "rerolls": 0.0, "start_shield": 0.0,
		# Sinerjiler
		"storm": 0, "harvest": 0, "doom_nova": 0, "blitz": 0, "hive": 0, "fortress": 0,
	}

func reset() -> void:
	taken.clear()
	mods = _defaults()

func roll(count: int, rng: RandomNumberGenerator) -> Array:
	var choices: Array = []
	var available: Array = []
	for card in pool:
		if not _is_maxed(card):
			available.append(card)
	if available.is_empty():
		return choices
	var guard := 0
	while choices.size() < count and guard < 200:
		guard += 1
		var total := 0.0
		for card in available:
			total += float(TIER_WEIGHT.get(str(card.get("tier", "common")), 10.0))
		var roll_value := rng.randf() * total
		var picked: Dictionary = available[0]
		for card in available:
			roll_value -= float(TIER_WEIGHT.get(str(card.get("tier", "common")), 10.0))
			if roll_value <= 0.0:
				picked = card
				break
		if not choices.has(picked):
			choices.append(picked)
		if choices.size() >= available.size():
			break
	return choices

func limit(key: String) -> int:
	## Kovan Zihni drone sınırını 3'e çıkarır.
	var base := int(LIMITS.get(key, 999))
	if key == "drones" and int(mods.get("hive", 0)) > 0:
		base += 1
	return base

func requirements_met(card: Dictionary) -> bool:
	for id in card.get("requires", []):
		if not taken.has(str(id)):
			return false
	return true

func _is_maxed(card: Dictionary) -> bool:
	if not requirements_met(card):
		return true
	if str(card.get("tier", "")) == "synergy" and taken.has(str(card.get("id", ""))):
		return true
	var effect: Dictionary = card.get("effect", {})
	for key in effect:
		if LIMITS.has(key) and int(mods.get(key, 0)) >= limit(key):
			# Kovan Zihni, drone sınırına takılmasın (kendisi sınırı yükseltir).
			if key == "drones" and effect.has("hive"):
				continue
			return true
	return false

func synergies_ready() -> Array:
	## Gereksinimleri tamam, henüz alınmamış sinerji kartları.
	var out: Array = []
	for card in pool:
		if str(card.get("tier", "")) == "synergy" and not _is_maxed(card):
			out.append(card)
	return out

func apply(card: Dictionary) -> void:
	taken.append(str(card.get("id", "?")))
	apply_effects(card.get("effect", {}))

func apply_effects(effect: Dictionary) -> void:
	## Kart, atölye veya gemi etkisini uygular. *_mult anahtarları çarpılır, diğerleri eklenir.
	## Sınır değiştiren anahtarlar (hive) önce işlenir ki aynı karttaki drone doğru sınıra tabi olsun.
	var keys: Array = effect.keys()
	keys.sort_custom(func(a, b): return str(a) == "hive" and str(b) != "hive")
	for key in keys:
		var value := float(effect[key])
		if not mods.has(key):
			mods[key] = 1.0 if str(key).ends_with("_mult") else 0.0
		if str(key).ends_with("_mult"):
			mods[key] = maxf(0.3, float(mods[key]) * (1.0 + value))
		elif key in LIMITS:
			mods[key] = mini(limit(key), int(mods[key]) + int(value))
		else:
			mods[key] = float(mods[key]) + value

func count(id: String) -> int:
	return taken.count(id)

func summary() -> Array:
	## Alınan kartlar: [{card, count}] — arayüzde yapı özeti için.
	var out: Array = []
	var seen := {}
	for id in taken:
		if seen.has(id):
			continue
		seen[id] = true
		for card in pool:
			if str(card.get("id", "")) == id:
				out.append({"card": card, "count": taken.count(id)})
				break
	return out

func m(key: String) -> float:
	return float(mods.get(key, 0.0))

func i(key: String) -> int:
	return int(mods.get(key, 0))
