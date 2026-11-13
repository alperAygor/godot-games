class_name MetaState
extends RefCounted

## Meta katmanının saf durumu: çamaşırhane tadilatı + kıyafet koleksiyonu.
## Sahneye/autoload'a bağımlı değildir (test edilir); kalıcılık `MetaStore`'un işidir.
##
## Kurallar:
##  * Görevler mekân içinde SABİT sırayla yapılır; durum yalnız "kaç görev bitti" sayısıdır.
##    NEDEN sayı: sıra veride sabit olduğu için id listesi tutmak hem gereksiz hem de veri
##    güncellenince (görev adı değişince) kayıt bozulmasına açık olurdu.
##  * Her bitmiş görevin seçili görünüm varyantı ("mekân/görev" anahtarıyla) saklanır;
##    bitmiş görevin varyantı sonradan ücretsiz değiştirilebilir.
##  * Mekân bitince tamamlama jetonu BİR KEZ verilir ve sıradaki mekâna geçilir.
##  * Koleksiyon parçaları kayıtta tutulmaz; `Progress.level()`'den hesaplanır (saf fonksiyon).
##    Kayıtta yalnız "görülen parça sayısı" (yeni rozeti) ve açılan kozmetikler durur.
##
## `from_dict` bozuk veriye toleranslıdır: JSON sayıları float gelir, alanlar eksik/yanlış
## tipte olabilir; her alan ayrı ayrı doğrulanır, bozuk alan varsayılana düşer.

const VERSION: int = 1
const KEY_VERSION: String = "v"
const KEY_LOCATION: String = "location"
const KEY_DONE: String = "done"
const KEY_VARIANTS: String = "variants"
const KEY_BONUS: String = "bonus_paid"
const KEY_SEEN: String = "pieces_seen"
const KEY_COSMETICS: String = "cosmetics"
## Kayıttaki sayılar için üst sınır: bozuk/kurcalanmış kayıt devasa döngü açmasın.
const MAX_COUNT: int = 9999

var location: int = 0
## mekân id -> bitmiş görev sayısı
var done: Dictionary[String, int] = {}
## "mekân/görev" -> varyant indeksi
var variants: Dictionary[String, int] = {}
## tamamlama jetonu ödenmiş mekân id'leri
var bonus_paid: Array[String] = []
var pieces_seen: int = 0
var cosmetics: Array[String] = []


# --- Kalıcılık -------------------------------------------------------------------

func to_dict() -> Dictionary:
	var done_out: Dictionary = {}
	for key: String in done:
		done_out[key] = done[key]
	var variants_out: Dictionary = {}
	for key: String in variants:
		variants_out[key] = variants[key]
	return {
		KEY_VERSION: VERSION,
		KEY_LOCATION: location,
		KEY_DONE: done_out,
		KEY_VARIANTS: variants_out,
		KEY_BONUS: bonus_paid.duplicate(),
		KEY_SEEN: pieces_seen,
		KEY_COSMETICS: cosmetics.duplicate(),
	}


static func from_dict(raw: Variant) -> MetaState:
	var state: MetaState = MetaState.new()
	if not (raw is Dictionary):
		return state
	var source: Dictionary = raw as Dictionary
	state.location = _count(source.get(KEY_LOCATION, 0))
	state.pieces_seen = _count(source.get(KEY_SEEN, 0))
	var done_raw: Variant = source.get(KEY_DONE, {})
	if done_raw is Dictionary:
		for key: Variant in (done_raw as Dictionary):
			state.done[str(key)] = _count((done_raw as Dictionary)[key])
	var variants_raw: Variant = source.get(KEY_VARIANTS, {})
	if variants_raw is Dictionary:
		for key: Variant in (variants_raw as Dictionary):
			state.variants[str(key)] = _count((variants_raw as Dictionary)[key])
	state.bonus_paid = _strings(source.get(KEY_BONUS, []))
	state.cosmetics = _strings(source.get(KEY_COSMETICS, []))
	return state


## Sayıya çevrilebilen değeri [0, MAX_COUNT] aralığında int yapar; değilse 0.
static func _count(value: Variant) -> int:
	if value is int or value is float:
		var number: float = float(value)
		if is_nan(number) or is_inf(number):
			return 0
		return clampi(int(number), 0, MAX_COUNT)
	if value is String and (value as String).is_valid_float():
		return clampi(int((value as String).to_float()), 0, MAX_COUNT)
	return 0


static func _strings(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry: Variant in value as Array:
			if entry is String and not (entry as String).is_empty() and not result.has(entry as String):
				result.append(entry as String)
	return result


# --- Çamaşırhane -------------------------------------------------------------------

## Geçerli mekân indeksi (katalog küçülmüşse son mekâna sıkıştırılır).
func current_location(catalog: MetaCatalog) -> int:
	if catalog.location_count() == 0:
		return 0
	return clampi(location, 0, catalog.location_count() - 1)


func done_count(catalog: MetaCatalog, index: int) -> int:
	var id: String = catalog.location_id(index)
	if id.is_empty():
		return 0
	return clampi(int(done.get(id, 0)), 0, catalog.task_count(index))


func is_location_complete(catalog: MetaCatalog, index: int) -> bool:
	var total: int = catalog.task_count(index)
	return total > 0 and done_count(catalog, index) >= total


## Mekân açık mı: geçerli mekân ve öncekiler açıktır.
func is_location_unlocked(catalog: MetaCatalog, index: int) -> bool:
	return index >= 0 and index <= current_location(catalog)


func is_task_done(catalog: MetaCatalog, index: int, task: int) -> bool:
	return task >= 0 and task < done_count(catalog, index)


## Sıradaki görevin indeksi; mekân bitmişse -1.
func next_task(catalog: MetaCatalog) -> int:
	var index: int = current_location(catalog)
	var count: int = done_count(catalog, index)
	return count if count < catalog.task_count(index) else -1


## Sıradaki görevin yıldız bedeli; görev yoksa 0.
func next_cost(catalog: MetaCatalog) -> int:
	var task: int = next_task(catalog)
	return catalog.task_cost(current_location(catalog), task) if task >= 0 else 0


func can_afford_next(catalog: MetaCatalog, stars: int) -> bool:
	var task: int = next_task(catalog)
	return task >= 0 and stars >= next_cost(catalog)


## Sıradaki görevi bitirir (yıldız harcamak çağıranın işidir). Dönen: görev indeksi ya da -1.
func complete_next(catalog: MetaCatalog, variant: int = 0) -> int:
	var task: int = next_task(catalog)
	if task < 0:
		return -1
	var index: int = current_location(catalog)
	var id: String = catalog.location_id(index)
	done[id] = task + 1
	variants[variant_key(id, catalog.task_id(index, task))] = clampi(variant, 0, catalog.variants_per_task - 1)
	return task


static func variant_key(location_id: String, task_id: String) -> String:
	return "%s/%s" % [location_id, task_id]


## Bitmiş görevin seçili varyantı; bitmemişse -1 ("eski" görünüm).
func variant(catalog: MetaCatalog, index: int, task: int) -> int:
	if not is_task_done(catalog, index, task):
		return -1
	var key: String = variant_key(catalog.location_id(index), catalog.task_id(index, task))
	return clampi(int(variants.get(key, 0)), 0, catalog.variants_per_task - 1)


## Bitmiş görevin görünümünü değiştirir (ücretsiz). Bitmemiş görev / geçersiz varyant: false.
func set_variant(catalog: MetaCatalog, index: int, task: int, value: int) -> bool:
	if not is_task_done(catalog, index, task):
		return false
	if value < 0 or value >= catalog.variants_per_task:
		return false
	variants[variant_key(catalog.location_id(index), catalog.task_id(index, task))] = value
	return true


## Ödenmesi bekleyen tamamlama jetonu (geçerli mekân bitmiş ve henüz ödenmemişse).
func pending_bonus(catalog: MetaCatalog) -> int:
	var index: int = current_location(catalog)
	if not is_location_complete(catalog, index):
		return 0
	if bonus_paid.has(catalog.location_id(index)):
		return 0
	return catalog.completion_coins(index)


## Tamamlama jetonunu "ödendi" işaretler ve sıradaki mekâna geçer. Dönen: jeton miktarı
## (çağıran `Progress.add_coins` ile verir). Bekleyen ödül yoksa 0 ve hiçbir şey değişmez.
func claim_bonus(catalog: MetaCatalog) -> int:
	var index: int = current_location(catalog)
	if not is_location_complete(catalog, index):
		return 0
	var id: String = catalog.location_id(index)
	var coins: int = 0
	if not bonus_paid.has(id):
		bonus_paid.append(id)
		coins = catalog.completion_coins(index)
	if index + 1 < catalog.location_count():
		location = index + 1
	return coins


## Mekânın ilerleme oranı 0..1 (ilerleme çubuğu için).
func location_progress(catalog: MetaCatalog, index: int) -> float:
	var total: int = catalog.task_count(index)
	if total == 0:
		return 0.0
	return float(done_count(catalog, index)) / float(total)


# --- Koleksiyon (saf hesaplar) -------------------------------------------------------

## Kazanılan parça sayısı. `level` = Progress.level(), yani SIRADAKİ oynanacak seviye;
## bitirilen seviye sayısı level-1'dir. Her `levels_per_piece` bitirilen seviyede bir parça.
static func pieces_earned(level: int, levels_per_piece: int, total: int) -> int:
	var completed: int = maxi(level - 1, 0)
	return clampi(completed / maxi(levels_per_piece, 1), 0, maxi(total, 0))


## Sıradaki parçaya kalan seviye; hepsi kazanıldıysa 0.
static func levels_to_next_piece(level: int, levels_per_piece: int, total: int) -> int:
	var step: int = maxi(levels_per_piece, 1)
	if pieces_earned(level, step, total) >= total:
		return 0
	var completed: int = maxi(level - 1, 0)
	return step - completed % step


## Sıradaki parçaya ilerleme 0..1 (ince çubuk için).
static func next_piece_progress(level: int, levels_per_piece: int, total: int) -> float:
	var step: int = maxi(levels_per_piece, 1)
	if pieces_earned(level, step, total) >= total:
		return 1.0
	return float(maxi(level - 1, 0) % step) / float(step)


## Setlerin sırayla dolduğu varsayımıyla, `set_index` setinde kazanılmış parça sayısı.
static func set_owned(earned: int, sizes: Array[int], set_index: int) -> int:
	var before: int = 0
	for index: int in range(mini(set_index, sizes.size())):
		before += sizes[index]
	if set_index < 0 or set_index >= sizes.size():
		return 0
	return clampi(earned - before, 0, sizes[set_index])


static func piece_owned(earned: int, sizes: Array[int], set_index: int, piece: int) -> bool:
	return piece >= 0 and piece < set_owned(earned, sizes, set_index)


## Kazanılan ama henüz koleksiyon ekranında görülmemiş parça sayısı ("yeni" rozeti).
func unseen_pieces(catalog: MetaCatalog, level: int) -> int:
	var earned: int = pieces_earned(level, catalog.levels_per_piece, catalog.total_pieces())
	return maxi(earned - pieces_seen, 0)


## Kazanılan parçalara göre tamamlanan setlerin kozmetiklerini açar (idempotent).
## Dönen: BU çağrıda yeni açılan kozmetik id'leri. Görülen parça sayısı da güncellenir.
func sync_collection(catalog: MetaCatalog, level: int) -> Array[String]:
	var sizes: Array[int] = catalog.set_sizes()
	var earned: int = pieces_earned(level, catalog.levels_per_piece, catalog.total_pieces())
	var unlocked: Array[String] = []
	for index: int in range(sizes.size()):
		if sizes[index] == 0 or set_owned(earned, sizes, index) < sizes[index]:
			continue
		var reward: String = catalog.set_reward(index)
		if not reward.is_empty() and not cosmetics.has(reward):
			cosmetics.append(reward)
			unlocked.append(reward)
	pieces_seen = maxi(pieces_seen, earned)
	return unlocked


func has_cosmetic(id: String) -> bool:
	return cosmetics.has(id)
