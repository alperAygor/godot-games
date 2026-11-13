class_name DailyPuzzle
extends RefCounted

## Günün bulmacası: saf mantık. Aynı tarih -> herkes için aynı seviye; her zaman çözülebilir.
## "Bugün" her yerde parametredir (testler saate bağlı kalmaz). Kayıt/UI burada değil:
## kayıt `DailyStore`, ekranlar `DailyCard` / `DailyFlow`.
##
## Zorluk: oyuncunun seviye kovasının (10'luk) biraz ÜSTÜNDEKİ bir seviye numarası
## `LevelGenerator.generate` ile üretilir, sonra tarihe bağlı renk eşlemesi, ayna ve ip
## karıştırması (çözülebilirliği bozmaz) ve ek sepet kaydırmaları (çözücüyle doğrulanır) eklenir.
## Neden yalnız genel API: üretici başka dalda değişse de bu sınıf onun iç işlevlerine bağlı kalmasın.

const RULES_PATH: String = "res://data/daily_rewards.json"
const SEED_SALT: int = 104729
const SEED_ATTEMPT_STEP: int = 7727
const SEED_MIX: int = 2654435761
const SEED_MASK: int = 0x7fffffff
const MAX_PALETTE: int = LevelGenerator.MAX_COLORS
const META_DATE: String = "daily_date"
const META_FLAG: String = "daily"
const TWIST_TRIES_PER_TWIST: int = 3

## Oyun sahnesine verilecek seviye (tek seferlik devir). `take_pending` okur ve temizler;
## böylece oyundan çıkınca normal "Oyna" yanlışlıkla günlük seviyeyi açmaz.
static var pending_level: Dictionary = {}

static var _rules_cache: Dictionary = {}


# --- Kurallar (JSON) ---------------------------------------------------------

static func rules() -> Dictionary:
	if _rules_cache.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
		if parsed is Dictionary:
			_rules_cache = parsed as Dictionary
		else:
			push_error("DailyPuzzle: %s okunamadı" % RULES_PATH)
	return _rules_cache


static func _difficulty() -> Dictionary:
	return rules().get("difficulty", {}) as Dictionary


static func _int_rule(source: Dictionary, key: String, fallback: int) -> int:
	return int(source.get(key, fallback))


static func unlock_level() -> int:
	return _int_rule(rules(), "unlock_level", 1)


# --- Tohum ve seviye ---------------------------------------------------------

## Tarih -> tohum. Gün numarası karıştırılır ki ardışık günler benzer seviye vermesin.
static func seed_for(date_key: String, attempt: int = 0) -> int:
	var day: int = DailyDate.day_index(date_key)
	var mixed: int = (day * SEED_SALT + attempt * SEED_ATTEMPT_STEP) * SEED_MIX
	return absi(mixed) & SEED_MASK


static func bucket_of(player_level: int) -> int:
	return maxi(player_level - 1, 0) / maxi(_int_rule(_difficulty(), "bucket_size", 10), 1)


## Kova başına sabit "taban seviye": aynı kovadaki oyuncular aynı günlük bulmacayı görür.
static func base_level_for(player_level: int) -> int:
	var difficulty: Dictionary = _difficulty()
	var bucket: int = bucket_of(player_level)
	var lift: int = mini(_int_rule(difficulty, "lift_base", 4)
		+ bucket * _int_rule(difficulty, "lift_per_bucket", 1), _int_rule(difficulty, "lift_max", 9))
	return bucket * maxi(_int_rule(difficulty, "bucket_size", 10), 1) + 1 + lift


static func extra_twists_for(player_level: int) -> int:
	var difficulty: Dictionary = _difficulty()
	return mini(_int_rule(difficulty, "extra_twist_base", 3) + bucket_of(player_level)
		* _int_rule(difficulty, "extra_twist_per_bucket", 1), _int_rule(difficulty, "extra_twist_max", 8))


## Günün seviye sözlüğü (LevelGenerator ile aynı biçim) + "daily"/"daily_date" işaretleri.
static func build_level(date_key: String, player_level: int) -> Dictionary:
	var difficulty: Dictionary = _difficulty()
	var attempts: int = maxi(_int_rule(difficulty, "max_attempts", 8), 1)
	var budget: int = _int_rule(difficulty, "node_budget", 60000)
	var spread: int = maxi(_int_rule(difficulty, "spread", 6), 1)
	var base: int = base_level_for(player_level)
	for attempt: int in range(attempts):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = seed_for(date_key, attempt)
		var level: Dictionary = LevelGenerator.generate(base + rng.randi_range(0, spread - 1))
		_relabel_colors(level, rng)
		_mirror_and_reorder(level, rng)
		_extra_twists(level, extra_twists_for(player_level), rng, budget)
		if LevelSolver.is_solvable(level, budget):
			return _mark(level, date_key)
	# Hiçbir aday doğrulanamazsa: üreticinin kendi (kurulum gereği çözülebilir) seviyesi.
	return _mark(LevelGenerator.generate(base), date_key)


static func _mark(level: Dictionary, date_key: String) -> Dictionary:
	level[META_FLAG] = true
	level[META_DATE] = date_key
	return level


## Renk kimlikleri bir eşlemeyle (bijection) değişir: kural aynı kalır, görünüm değişir.
static func _relabel_colors(level: Dictionary, rng: RandomNumberGenerator) -> void:
	var used: int = 0
	for color: Variant in level["queue"] as Array:
		used = maxi(used, int(color) + 1)
	for entry: Dictionary in level["items"] as Array[Dictionary]:
		used = maxi(used, int(entry["color"]) + 1)
	var palette: int = clampi(maxi(used, 2), 2, MAX_PALETTE)
	var mapping: Array[int] = []
	for index: int in range(palette):
		mapping.append(index)
	for index: int in range(palette - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var held: int = mapping[index]
		mapping[index] = mapping[other]
		mapping[other] = held
	var queue: Array[int] = []
	for color: Variant in level["queue"] as Array:
		queue.append(mapping[int(color)])
	level["queue"] = queue
	for entry: Dictionary in level["items"] as Array[Dictionary]:
		entry["color"] = mapping[int(entry["color"])]
		if entry.has("lock"):
			entry["lock"] = mapping[int(entry["lock"])]


## Sağ-sol ayna ve ip sırası karışımı: kapatma ilişkileri (blockers) değişmez -> çözülebilirlik aynı.
static func _mirror_and_reorder(level: Dictionary, rng: RandomNumberGenerator) -> void:
	var items: Array[Dictionary] = level["items"] as Array[Dictionary]
	var widest: float = 0.0
	var lines: int = 0
	for entry: Dictionary in items:
		widest = maxf(widest, float(entry["slot"]))
		lines = maxi(lines, int(entry["line"]) + 1)
	var mirror: bool = rng.randi_range(0, 1) == 1
	var order: Array[int] = []
	for index: int in range(lines):
		order.append(index)
	for index: int in range(lines - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var held: int = order[index]
		order[index] = order[other]
		order[other] = held
	for entry: Dictionary in items:
		entry["line"] = order[int(entry["line"])]
		if mirror:
			entry["slot"] = widest - float(entry["slot"])


## Sepet kuyruğunda komşu yer değişimleri; her biri çözücüyle doğrulanır, bozarsa geri alınır.
static func _extra_twists(level: Dictionary, twists: int, rng: RandomNumberGenerator, budget: int) -> void:
	var queue: Array[int] = level["queue"] as Array[int]
	if queue.size() < 3 or twists <= 0:
		return
	var applied: int = 0
	var tries: int = 0
	while applied < twists and tries < twists * TWIST_TRIES_PER_TWIST:
		tries += 1
		var a: int = rng.randi_range(0, queue.size() - 2)
		var b: int = mini(a + rng.randi_range(1, 2), queue.size() - 1)
		if queue[a] == queue[b]:
			continue
		var swapped: Array[int] = queue.duplicate()
		swapped[a] = queue[b]
		swapped[b] = queue[a]
		var candidate: Dictionary = level.duplicate()
		candidate["queue"] = swapped
		if LevelSolver.is_solvable(candidate, budget):
			queue = swapped
			level["queue"] = swapped
			applied += 1


# --- Seri mantığı (durum sözlüğü: last_won, streak, best) ---------------------

static func last_won(state: Dictionary) -> String:
	return String(state.get("last_won", ""))


static func won_on(state: Dictionary, date_key: String) -> bool:
	return last_won(state) == date_key


## Bu tarihte kazanılırsa seri kaç olur: dün kazanıldıysa +1, kaçırıldıysa 1, aynı gün değişmez.
static func streak_after_win(state: Dictionary, date_key: String) -> int:
	var current: int = maxi(int(state.get("streak", 0)), 0)
	var gap: int = DailyDate.days_between(last_won(state), date_key)
	if gap == 0:
		return current
	if gap == 1:
		return current + 1
	return 1


## Ekranda gösterilecek seri: dünden eski kazanım seriyi koparmıştır (0).
static func display_streak(state: Dictionary, date_key: String) -> int:
	var gap: int = DailyDate.days_between(last_won(state), date_key)
	if gap == 0 or gap == 1:
		return maxi(int(state.get("streak", 0)), 0)
	return 0


## Kazanımı işler: yeni durum sözlüğü döner (aynı gün tekrar -> değişmez).
static func state_after_win(state: Dictionary, date_key: String) -> Dictionary:
	if won_on(state, date_key):
		return state.duplicate()
	var streak: int = streak_after_win(state, date_key)
	return {"last_won": date_key, "streak": streak,
		"best": maxi(int(state.get("best", 0)), streak)}


## Oyuncu bugünkü bulmacayı oynayabilir mi (açık + henüz kazanılmadı). Ana ekran rozeti için.
static func is_available(state: Dictionary, date_key: String, player_level: int) -> bool:
	return player_level >= unlock_level() and not won_on(state, date_key)


# --- Ödül -------------------------------------------------------------------

## Kazanımdan sonraki seriye göre ödül: {coins, booster ("" olabilir), booster_count}.
static func reward_for(streak_after: int, player_level: int) -> Dictionary:
	var table: Dictionary = rules()
	var bonus_days: int = clampi(streak_after - 1, 0, _int_rule(table, "streak_bonus_max_days", 6))
	var coins: int = _int_rule(table, "base_coins", 60) \
		+ bonus_days * _int_rule(table, "streak_bonus_per_day", 10)
	var reward: Dictionary = {"coins": coins, "booster": "", "booster_count": 0}
	var every: int = _int_rule(table, "booster_every_streak", 3)
	if every <= 0 or streak_after <= 0 or streak_after % every != 0:
		return reward
	# Oyuncunun henüz açmadığı güçlendirici verilmez; sırayla dönülür.
	var eligible: Array[String] = []
	for entry: Variant in table.get("boosters", []) as Array:
		var booster: Dictionary = entry as Dictionary
		if player_level >= int(booster.get("min_level", 1)):
			eligible.append(String(booster["id"]))
	if not eligible.is_empty():
		reward["booster"] = eligible[(streak_after / every - 1) % eligible.size()]
		reward["booster_count"] = 1
	return reward


# --- Giriş noktaları (yürütme zamanında çözülür: bu dosya testlerde de yüklenir) ---

## Oyun sahnesi başlarken çağırır: bekleyen günlük seviyeyi alır ve devri temizler.
static func take_pending() -> Dictionary:
	var level: Dictionary = pending_level
	pending_level = {}
	return level


## Ana ekran: `DailyPuzzle.open_card(self)`. Küçük kart sayfasını açar.
static func open_card(parent: Node) -> Node:
	return (load("res://scripts/daily/daily_card.gd") as GDScript).call("open", parent) as Node


## Ana ekran rozeti: bugün oynanabilir günlük bulmaca var mı (kayıt + saat okunur).
static func available_today() -> bool:
	return bool((load("res://scripts/daily/daily_store.gd") as GDScript).call("puzzle_available"))
