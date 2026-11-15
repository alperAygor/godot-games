extends RefCounted
class_name EnemyData
## Düşman verisinin saf yardımcıları (C2): yeni tür davranış alanlarının doğrulaması, elit ön eki seçimi ve sektör/üst-sınır
## yedek kuralı. Sahneye bağlı değildir; Spawner (oyun) ve RunSim (denge simülasyonu) AYNI kuralı buradan kullanır, rastgele
## sayıyı çağıran verir (böylece her tarafın kendi rastgele akışı korunur).
##
## C1 (dalga tabloları) için sözleşme: bir türün dalgalara girmesi `enemies.json` içindeki `unlock` (ilk dalga) ve `weight`
## (ağırlık) ile olur — RunState.unlocked_kinds/_pick bunları zaten okur; wave tablosunu değiştirmek gerekmez. Spawner ek olarak
## doğma anında `sectors` (türün görüneceği harita sırası listesi; boş = hepsi), `max_alive` (aynı anda en çok bu kadar) ve
## `fallback` (kural çiğnenirse yerine doğacak tür) alanlarını uygular. `threat` (tehdit puanı) bilgi amaçlıdır: dalga
## planlayıcı bütçe tutmak isterse kullanabilir.

const ACTIVE_FIELDS := {
	"charger": ["trigger_range", "min_range", "windup", "dash_speed", "dash_time", "dash_damage_mult", "recover", "recover_taken_mult", "cooldown", "tele_width"],
	"shielder": ["shield_arc", "shield_turn", "shield_block", "shield_pierce_damage"],
	"medic": ["keep_distance", "pulse_interval", "pulse_charge", "heal_radius", "heal_frac", "retry_delay"],
	"minelayer": ["orbit_radius", "mine_interval", "mine_delay", "mine_radius", "mine_count", "mine_lead", "mine_spread"],
	"blinker": ["blink_interval", "blink_windup", "land_dist", "strike_delay", "strike_radius"],
	"brooder": ["keep_distance", "hatch_interval", "hatch_charge", "hatch_count", "max_hatches"],
}
const SCHEDULE_FIELDS := ["threat", "max_alive"]
const PREFIX_FIELDS := ["weight", "min_wave", "hp_mult", "damage_mult", "speed_mult", "scale", "points_mult", "damage_taken_mult"]
## Telegraf (uyarı) süresi alt sınırı: yeni davranışlar kaçınılması imkânsız vuruş yapmasın.
const MIN_WARNING := 0.6
const WARNING_FIELDS := {"charger": "windup", "medic": "pulse_charge", "minelayer": "mine_delay", "blinker": "strike_delay", "brooder": "hatch_charge"}

static func validate(enemies: Dictionary, elite: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	for kind in ACTIVE_FIELDS:
		if not enemies.has(kind):
			continue
		var stats: Dictionary = enemies[kind]
		for field in ACTIVE_FIELDS[kind] + SCHEDULE_FIELDS:
			if not stats.has(field) or not _is_num(stats[field]):
				errors.append("enemies.%s.%s eksik ya da sayı değil" % [kind, field])
			elif float(stats[field]) < 0.0:
				errors.append("enemies.%s.%s negatif olamaz" % [kind, field])
		if WARNING_FIELDS.has(kind) and _is_num(stats.get(WARNING_FIELDS[kind])) and float(stats[WARNING_FIELDS[kind]]) < MIN_WARNING:
			errors.append("enemies.%s.%s en az %.1f sn olmalı (kaçınılamaz vuruş yok)" % [kind, WARNING_FIELDS[kind], MIN_WARNING])
		if str(stats.get("name", "")) == "" or str(stats.get("hint", "")) == "":
			errors.append("enemies.%s.name/hint (oyuncuya görünen metin) eksik" % kind)
	for kind in enemies:
		var s: Dictionary = enemies[kind]
		if s.has("fallback") and (not enemies.has(str(s["fallback"])) or str(s["fallback"]) == str(kind)):
			errors.append("enemies.%s.fallback geçerli başka bir tür olmalı" % kind)
		if s.has("sectors") and typeof(s["sectors"]) != TYPE_ARRAY:
			errors.append("enemies.%s.sectors dizi olmalı" % kind)
		if s.has("max_alive") and _is_num(s["max_alive"]) and int(s["max_alive"]) < 1:
			errors.append("enemies.%s.max_alive en az 1 olmalı" % kind)
	if enemies.has("brooder"):
		var hk := str((enemies["brooder"] as Dictionary).get("hatch_kind", ""))
		if not enemies.has(hk):
			errors.append("enemies.brooder.hatch_kind bilinmeyen tür: " + hk)
	var prefixes: Variant = elite.get("prefixes", {})
	if typeof(prefixes) != TYPE_DICTIONARY:
		errors.append("elite.prefixes sözlük olmalı")
		return errors
	for id in prefixes:
		var p: Dictionary = prefixes[id]
		for field in PREFIX_FIELDS:
			if not p.has(field) or not _is_num(p[field]):
				errors.append("elite.prefixes.%s.%s eksik ya da sayı değil" % [id, field])
		if str(p.get("name", "")) == "":
			errors.append("elite.prefixes.%s.name eksik" % id)
		if Color.from_string(str(p.get("color", "")), Color(0, 0, 0, 0)) == Color(0, 0, 0, 0):
			errors.append("elite.prefixes.%s.color geçersiz" % id)
		for list_key in ["kinds", "exclude"]:
			if p.has(list_key):
				if typeof(p[list_key]) != TYPE_ARRAY:
					errors.append("elite.prefixes.%s.%s dizi olmalı" % [id, list_key])
				else:
					for k in p[list_key]:
						if not enemies.has(str(k)):
							errors.append("elite.prefixes.%s.%s bilinmeyen tür: %s" % [id, list_key, str(k)])
		if float(p.get("damage_taken_mult", 1.0)) <= 0.0:
			errors.append("elite.prefixes.%s.damage_taken_mult pozitif olmalı" % id)
		if p.has("split_count") and (int(p["split_count"]) < 1 or float(p.get("split_hp_frac", 0.0)) <= 0.0):
			errors.append("elite.prefixes.%s: split_count>=1 ve split_hp_frac>0 gerekli" % id)
	return errors

static func elite_chance(elite: Dictionary, eff_wave: float, boss_wave: bool) -> float:
	## Elit olma olasılığı; -1 = bu doğuşta elit denemesi YOK (rastgele sayı çekilmez). `eff_wave` = RunState.difficulty_wave(dalga):
	## hızlı mod (wave_scale 1,6) elitleri dalga numarasına göre değil etkin zorluğa göre açar; sonsuz/standartta (ölçek 1)
	## etkin dalga = dalga numarası → eski kuralla birebir aynı. Boss dalgasında elit yok.
	if elite.is_empty() or boss_wave or eff_wave < float(elite.get("from_wave", 4)):
		return -1.0
	return minf(float(elite.get("chance_max", 0.16)), float(elite.get("chance", 0.05)) + float(elite.get("chance_per_wave", 0.006)) * eff_wave)

static func prefix_wave(eff_wave: float) -> int:
	## Ön eklerin `min_wave` karşılaştırması için etkin dalganın tam kısmı (sonsuzda = dalga numarası).
	return int(floor(eff_wave + 0.0001))

static func prefix_applies(prefix: Dictionary, kind: String, wave: int) -> bool:
	if wave < int(prefix.get("min_wave", 1)):
		return false
	if prefix.has("kinds") and not (kind in prefix["kinds"]):
		return false
	if prefix.has("exclude") and kind in prefix["exclude"]:
		return false
	return float(prefix.get("weight", 0.0)) > 0.0

static func pick_prefix(elite: Dictionary, kind: String, wave: int, roll: float) -> String:
	## `roll` 0..1 aralığında çağıranın rastgele sayısı. Uygun ön ek yoksa "" (düz altın elit).
	var prefixes: Dictionary = elite.get("prefixes", {})
	var total := 0.0
	for id in prefixes:
		if prefix_applies(prefixes[id], kind, wave):
			total += float(prefixes[id].get("weight", 0.0))
	if total <= 0.0:
		return ""
	var left := roll * total
	var last := ""
	for id in prefixes:
		if not prefix_applies(prefixes[id], kind, wave):
			continue
		last = str(id)
		left -= float(prefixes[id].get("weight", 0.0))
		if left <= 0.0:
			return last
	return last

static func merged_elite(elite: Dictionary, id: String) -> Dictionary:
	## Genel elit ayarı + ön ekin üzerine yazmaları (+ `prefix` kimliği). Ön ek boşsa genel elit.
	var out := elite.duplicate()
	out.erase("prefixes")
	if id != "":
		var p: Dictionary = (elite.get("prefixes", {}) as Dictionary).get(id, {})
		out.merge(p, true)
		out["prefix"] = id
	return out

static func resolve_kind(enemies: Dictionary, kind: String, sector: int, alive_by_kind: Dictionary) -> String:
	## Sektör uygunluğu ve eşzamanlı üst sınır: kural çiğnenirse `fallback` türü döner (zincirleme yok; yedek hep geçerlidir).
	var s: Dictionary = enemies.get(kind, {})
	var sectors: Array = s.get("sectors", [])
	var in_sector := sectors.is_empty()
	for sec in sectors:
		if int(sec) == sector:   # JSON sayıları float gelir
			in_sector = true
	var blocked := not in_sector
	if not blocked and s.has("max_alive") and int(alive_by_kind.get(kind, 0)) >= int(s["max_alive"]):
		blocked = true
	if blocked:
		return str(s.get("fallback", "chaser"))
	return kind

static func _is_num(v: Variant) -> bool:
	return typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT
