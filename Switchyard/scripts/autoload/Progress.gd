extends Node

## Oyuncu ilerlemesinin tek sahibi (autoload `Progress`): ayar, bayrak, modül verisi (seviye kayıtları dahil).
## Kurallar `ProgressData`'dadır; burası diske atomik yazar ve sinyal verir.
## Diğer sistemler YALNIZ bu genel API'yi kullanır.

signal changed

const SAVE_PATH: String = "user://progress.json"
const TEMP_SUFFIX: String = ".tmp"
const BACKUP_SUFFIX: String = ".bak"
## "Reklamları kaldır" sahipliği: modül "shop", anahtar "remove_ads".
const SHOP_SECTION: String = "shop"
const KEY_REMOVE_ADS: String = "remove_ads"

## false iken diske HİÇ yazılmaz. Araçlar/problar bunu İLK İŞ olarak false yapar
## (oyuncunun gerçek kaydını ezmesin).
var persist: bool = true
var save_path: String = SAVE_PATH
var data: ProgressData = ProgressData.new()
var balance: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	balance = ProgressData.load_balance()
	load_from_disk()


# --- Genel API (sözleşme: adlar/imzalar değişmez) ----------------------------

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


## Modül verisi (bkz. ProgressData.modules): `section` modülün adıdır ("settings", "shop"...).
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


## Bir modül bölümünün kopyası (boşsa boş sözlük). Seviye kayıtları gibi toplu okumalar için.
func module_section(section: String) -> Dictionary:
	var entry: Variant = data.modules.get(section)
	return (entry as Dictionary).duplicate(true) if entry is Dictionary else {}


## "Reklamları kaldır" satın alındı mı (geçiş reklamları kapanır; ödüllü reklam açık kalır).
func remove_ads_owned() -> bool:
	return bool(module_value(SHOP_SECTION, KEY_REMOVE_ADS, false))


func set_remove_ads_owned(owned: bool) -> void:
	if remove_ads_owned() != owned:
		set_module_value(SHOP_SECTION, KEY_REMOVE_ADS, owned)


# --- Reklam sıklığı sayaçları (RunFlow kullanır) -----------------------------

func mark_rewarded_watched() -> void:
	data.last_rewarded_time = Time.get_unix_time_from_system()
	_commit()


## `at`: Unix saniyesi (probe/test sahte saat verir); negatifse sistem saati.
func mark_interstitial_shown(at: float = -1.0) -> void:
	data.last_interstitial_time = at if at >= 0.0 else Time.get_unix_time_from_system()
	_commit()


func balance_table() -> Dictionary:
	return _balance()


# --- Disk --------------------------------------------------------------------

## Kaydı yükler. Dosya yoksa varsayılan; bozuksa .bak'a kopyalayıp varsayılana döner.
func load_from_disk() -> void:
	data = ProgressData.new()
	if FileAccess.file_exists(save_path):
		# JSON.new().parse: bozuk dosyada motor hata basmaz, kodu döner.
		var parser: JSON = JSON.new()
		var parse_ok: bool = parser.parse(FileAccess.get_file_as_string(save_path)) == OK
		if parse_ok and parser.data is Dictionary:
			data = ProgressData.from_dict(parser.data)
		else:
			_backup_corrupt()
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
	return true


## Testler/araçlar için: bellekteki durumu sıfırlar (diske yazmaz).
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
