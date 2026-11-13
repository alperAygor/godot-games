extends Node

## Oyuncu ilerlemesinin tek sahibi (autoload `Progress`): seviye, jeton, yıldız, seri, güçlendirici,
## ayar, bayrak. Kurallar `ProgressData`'dadır; burası diske atomik yazar ve sinyal verir.
## Diğer sistemler YALNIZ bu genel API'yi kullanır.

signal changed

const SAVE_PATH: String = "user://progress.json"
const TEMP_SUFFIX: String = ".tmp"
const BACKUP_SUFFIX: String = ".bak"
## Eski sürümün ConfigFile kaydı; bir kez içe aktarılır.
const LEGACY_PATH: String = "user://progress.cfg"
const LEGACY_DONE_SUFFIX: String = ".migrated"
const LEGACY_SECTION: String = "progress"
## "Reklamları kaldır" sahipliği: modül "shop", anahtar "remove_ads" (mağaza servisi de buradan okur).
const SHOP_SECTION: String = "shop"
const KEY_REMOVE_ADS: String = "remove_ads"

## false iken diske HİÇ yazılmaz (prob/test oyuncunun gerçek kaydını ezmesin).
var persist: bool = true
var save_path: String = SAVE_PATH
var legacy_path: String = LEGACY_PATH
var data: ProgressData = ProgressData.new()
var balance: Dictionary = {}

var _legacy_pending_cleanup: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	balance = ProgressData.load_balance()
	load_from_disk()


# --- Genel API (sözleşme: adlar/imzalar değişmez) ----------------------------

func level() -> int:
	return data.level


func coins() -> int:
	return data.coins


func stars() -> int:
	return data.stars


func streak() -> int:
	return data.streak


func add_coins(amount: int) -> void:
	data.add_coins(amount)
	_commit()


func spend_coins(amount: int) -> bool:
	var ok: bool = data.spend_coins(amount)
	if ok:
		_commit()
	return ok


## Dönen: {"coins","stars","streak","streak_bonus"}; coins/stars BU seviyenin kazancı.
func complete_level(hard: bool) -> Dictionary:
	var result: Dictionary = data.complete_level(hard, _balance())
	_commit()
	return result


## Derecelendirmeli kazanç (bkz. ProgressData.complete_level_rated). Dönen sözlük `complete_level`
## alanlarına ek olarak {"base_coins","bonus_coins","rating","replay"} içerir.
func complete_level_rated(hard: bool, rating: int, bonus_coins: int, level_number: int = 0) -> Dictionary:
	var result: Dictionary = data.complete_level_rated(hard, rating, bonus_coins, _balance(), level_number)
	_commit()
	return result


## Bir seviyenin kayıtlı en iyi yıldızı (0 = hiç bitirilmedi).
func best_stars(level_number: int) -> int:
	return data.best_stars_of(level_number)


func fail_level() -> void:
	data.fail_level()
	_commit()


func booster_count(id: String) -> int:
	return data.booster_count(id)


func use_booster(id: String) -> bool:
	var ok: bool = data.use_booster(id)
	if ok:
		_commit()
	return ok


func add_booster(id: String, amount: int) -> void:
	data.add_booster(id, amount)
	_commit()


func setting(key: String) -> bool:
	return data.setting(key)


func set_setting(key: String, value: bool) -> void:
	data.set_setting(key, value)
	_commit()


func seen(flag: String) -> bool:
	return data.seen(flag)


func mark_seen(flag: String) -> void:
	data.mark_seen(flag)
	_commit()


## Modül verisi (bkz. ProgressData.modules): `section` modülün adıdır ("daily", "meta"...).
## Değerler JSON'a yazılabilir türde olmalıdır (sayı, metin, bool, dizi, sözlük).
func module_value(section: String, key: String, fallback: Variant = null) -> Variant:
	var entry: Variant = data.modules.get(section)
	if entry is Dictionary:
		return (entry as Dictionary).get(key, fallback)
	return fallback


func set_module_value(section: String, key: String, value: Variant) -> void:
	if not data.modules.has(section):
		data.modules[section] = {}
	(data.modules[section] as Dictionary)[key] = value
	_commit()


## Jetonla güçlendirici alımı TEK kayıtta: jeton düşer + adet eklenir (arada çökme olursa
## oyuncu jetonunu kaybedip ürünü alamamış olmasın). Yetersiz jeton/bilinmeyen id: false.
func purchase_booster(id: String, quantity: int, price: int) -> bool:
	if quantity <= 0 or not ProgressData.BOOSTER_IDS.has(id) or not data.spend_coins(price):
		return false
	data.add_booster(id, quantity)
	_commit()
	return true


## Jetonla modül verisi alımı (ör. kaplama): jeton düşer + değer yazılır, tek kayıt.
func purchase_module_value(price: int, section: String, key: String, value: Variant) -> bool:
	if not data.spend_coins(price):
		return false
	if not data.modules.has(section):
		data.modules[section] = {}
	(data.modules[section] as Dictionary)[key] = value
	_commit()
	return true


## "Reklamları kaldır" satın alındı mı (geçiş reklamları ve bannerlar kapanır; ödüllü reklam açık kalır).
func remove_ads_owned() -> bool:
	return bool(module_value(SHOP_SECTION, KEY_REMOVE_ADS, false))


func set_remove_ads_owned(owned: bool) -> void:
	if remove_ads_owned() != owned:
		set_module_value(SHOP_SECTION, KEY_REMOVE_ADS, owned)


func add_stars(amount: int) -> void:
	data.stars = clampi(data.stars + amount, 0, ProgressData.MAX_VALUE)
	_commit()


func spend_stars(amount: int) -> bool:
	if amount < 0 or data.stars < amount:
		return false
	data.stars -= amount
	_commit()
	return true


func streak_extra_slot() -> bool:
	return data.streak_extra_slot(_balance())


# --- Reklam sıklığı sayaçları (EcoFlow kullanır) -----------------------------

func mark_rewarded_watched() -> void:
	data.last_rewarded_time = Time.get_unix_time_from_system()
	_commit()


func mark_interstitial_shown() -> void:
	data.last_interstitial_time = Time.get_unix_time_from_system()
	data.levels_since_interstitial = 0
	_commit()


func balance_table() -> Dictionary:
	return _balance()


# --- Disk --------------------------------------------------------------------

## Kaydı yükler. Dosya yoksa eski .cfg'den göç eder; bozuksa .bak'a kopyalayıp varsayılana döner.
func load_from_disk() -> void:
	data = ProgressData.new()
	_legacy_pending_cleanup = false
	if FileAccess.file_exists(save_path):
		# JSON.new().parse: bozuk dosyada motor hata basmaz, kodu döner.
		var parser: JSON = JSON.new()
		var parse_ok: bool = parser.parse(FileAccess.get_file_as_string(save_path)) == OK
		if parse_ok and parser.data is Dictionary:
			data = ProgressData.from_dict(parser.data)
		else:
			_backup_corrupt()
	elif FileAccess.file_exists(legacy_path):
		_migrate_legacy()
	# Eski kayıtta henüz verilmemiş açılış hediyeleri tamamlanır (bayrakla tek sefer).
	data.grant_unlocked_boosters(_balance())
	changed.emit()


## Atomik yazım: önce geçici dosya, sonra yeniden adlandırma; yarım yazım asıl kaydı bozmaz.
func save() -> bool:
	if not persist:
		return false
	var temp_path: String = save_path + TEMP_SUFFIX
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_warning("Progress: %s yazılamadı" % temp_path)
		return false
	file.store_string(JSON.stringify(data.to_dict()))
	file.close()
	if DirAccess.rename_absolute(temp_path, save_path) != OK:
		# Bazı platformlarda hedef varken yeniden adlandırma başarısız olur.
		DirAccess.remove_absolute(save_path)
		if DirAccess.rename_absolute(temp_path, save_path) != OK:
			push_warning("Progress: %s yerine konamadı" % save_path)
			return false
	if _legacy_pending_cleanup:
		_legacy_pending_cleanup = false
		DirAccess.rename_absolute(legacy_path, legacy_path + LEGACY_DONE_SUFFIX)
	return true


## Testler için: bellekteki durumu sıfırlar (diske yazmaz).
func reset_state() -> void:
	data = ProgressData.new()
	changed.emit()


func _commit() -> void:
	save()
	changed.emit()


func _balance() -> Dictionary:
	if balance.is_empty():
		balance = ProgressData.load_balance()
	return balance


func _backup_corrupt() -> void:
	push_warning("Progress: %s bozuk, varsayılana dönülüyor (.bak tutuldu)" % save_path)
	if not persist:
		return
	var backup_path: String = save_path + BACKUP_SUFFIX
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)
	DirAccess.copy_absolute(save_path, backup_path)


func _migrate_legacy() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(legacy_path) != OK:
		return
	data.level = maxi(ProgressData.to_count(config.get_value(LEGACY_SECTION, "level", 1), 1), 1)
	data.coins = ProgressData.to_count(config.get_value(LEGACY_SECTION, "coins", 0))
	# .cfg ancak yeni kayıt başarıyla yazılınca işaretlenir; o zamana dek göç tekrarlanabilir.
	_legacy_pending_cleanup = true
