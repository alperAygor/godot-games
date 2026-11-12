class_name ProfileData
extends RefCounted

## Saf veri modeli: cüzdan, yükseltme seviyeleri, istatistikler ve ayarlar.
## Dosya/IO YOK; kaydı `SaveService` sarar. Sözleşme: ARCHITECTURE.md §4.8.
##
## Kayıt JSON olduğu için bütün sayılar float gelebilir (GOTCHAS #20);
## küsuratsız float tamsayı sayılır. Eksik/yanlış tip/negatif/küsuratlı değer
## varsayılana döner; bilinmeyen anahtar ve kategoriler yok sayılır.

const VERSION: int = 1

## Bilinen yükseltme kategorileri. Kayıt yalnız bunları taşır; tabloya yeni
## kategori eklenirse burası da güncellenmelidir.
const CATEGORIES: Array[String] = ["chassis", "wheels", "battery", "shock_gel"]

## Ayarlar yalnız bilinen anahtarları taşır; eksik/yanlış tip varsayılana döner.
const DEFAULT_SETTINGS: Dictionary = {"sound_on": true, "tutorial_done": false}

var _wallet: Wallet
var _levels: Dictionary
var _deliveries: int
var _breaks: int
var _best_stars: Dictionary
var _settings: Dictionary
var _records: RunRecords


func _init() -> void:
	_wallet = Wallet.new()
	_levels = {}
	for category: String in CATEGORIES:
		_levels[category] = 0
	_deliveries = 0
	_breaks = 0
	_best_stars = {}
	_settings = DEFAULT_SETTINGS.duplicate()
	_records = RunRecords.new()


## Canlı referans: çağıranın cüzdanı değiştirmesi profile yansır.
func wallet() -> Wallet:
	return _wallet


func level(category: String) -> int:
	return int(_levels.get(category, 0))


func set_level(category: String, level: int) -> void:
	# Bilinmeyen kategori kayda giremez; negatif seviye 0'a kırpılır.
	if not CATEGORIES.has(category):
		return
	_levels[category] = maxi(level, 0)


func levels() -> Dictionary:
	var copy: Dictionary = {}
	for category: String in CATEGORIES:
		copy[category] = int(_levels.get(category, 0))
	return copy


## Tur sonucunu işler. Başarıda ödül + teslimat + kargo başına en iyi yıldız;
## başarısızlıkta yalnız kırılma sayacı artar (para ve yıldız eklenmez).
func record_result(result: Dictionary) -> void:
	var endless_raw: Variant = result.get("endless", false)
	if endless_raw is bool and bool(endless_raw):
		_record_endless(result)
		return
	var success_raw: Variant = result.get("success", false)
	var success: bool = success_raw is bool and bool(success_raw)
	if not success:
		_breaks += 1
		return

	# Wallet.add zaten negatifi 0 sayar; yine de bozuk tipleri burada eleriz.
	_wallet.add(_whole_or_zero(result.get("gold", 0)),
		_whole_or_zero(result.get("scrap", 0)))
	_deliveries += 1

	var stars: int = _whole_or_zero(result.get("stars", 0))
	var cargo_id: String = String(result.get("cargo_id", ""))
	# Kargo kimliği yoksa en iyi yıldız için anlamlı bir anahtar da yoktur.
	if cargo_id.is_empty():
		return
	var previous: int = int(_best_stars.get(cargo_id, 0))
	# İlk başarılı teslimat 0 yıldızla bile kayda girer: sözleşme
	# best_stars[cargo_id] = max(eski, stars) der; "hiç yok" ile "0 yıldız" farklıdır.
	if stars > previous or not _best_stars.has(cargo_id):
		_best_stars[cargo_id] = stars


## Sonsuz koşu: ödenen kasa (kırılmada yarısı) her durumda cüzdana girer; teslim edilen
## level sayısı teslimata eklenir; rekorlar güncellenir ve kırılanlar `new_records`a yazılır.
func _record_endless(result: Dictionary) -> void:
	_wallet.add(_whole_or_zero(result.get("gold", 0)), _whole_or_zero(result.get("scrap", 0)))
	_deliveries += _whole_or_zero(result.get("levels_delivered", 0))
	if String(result.get("reason", "")) == "broken":
		_breaks += 1
	var distance_raw: Variant = result.get("distance", 0.0)
	var distance: float = float(distance_raw) if typeof(distance_raw) in [TYPE_INT, TYPE_FLOAT] else 0.0
	result["new_records"] = _records.submit(
		_whole_or_zero(result.get("level", 0)), distance, _whole_or_zero(result.get("score", 0)))


## İstatistiklerin kopyası; `best_stars` iç sözlüğü de kopyalanır, böylece
## dönen sözlüğü değiştirmek profili etkilemez.
func stats() -> Dictionary:
	var best_copy: Dictionary = {}
	for key: Variant in _best_stars.keys():
		best_copy[String(key)] = int(_best_stars[key])
	return {
		"deliveries": _deliveries,
		"breaks": _breaks,
		"best_stars": best_copy,
	}


## Canlı referans: rekorlar (sonsuz mod). Koşu bitince `submit` çağrılır.
func records() -> RunRecords:
	return _records


## Ayarların kopyası; çağıranın değiştirmesi profili etkilemez.
func settings() -> Dictionary:
	return _settings.duplicate()


## Yalnız bilinen ayar anahtarları yazılır; bilinmeyen anahtar yok sayılır.
func set_setting(key: String, value: bool) -> void:
	if not DEFAULT_SETTINGS.has(key):
		return
	_settings[key] = value


func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"wallet": _wallet.to_dict(),
		"levels": levels(),
		"stats": stats(),
		"settings": settings(),
		"records": _records.to_dict(),
	}


static func from_dict(d: Dictionary) -> ProfileData:
	var profile: ProfileData = ProfileData.new()

	# Yanlış kapsayıcı tipinde varsayılan korunur; alan bazında tolerans uygulanır.
	var wallet_raw: Variant = d.get("wallet")
	if wallet_raw is Dictionary:
		profile._wallet = Wallet.from_dict(wallet_raw as Dictionary)

	var levels_raw: Variant = d.get("levels")
	if levels_raw is Dictionary:
		var levels_dict: Dictionary = levels_raw as Dictionary
		for category: String in CATEGORIES:
			profile._levels[category] = _whole_or_zero(levels_dict.get(category, 0))

	var settings_raw: Variant = d.get("settings")
	if settings_raw is Dictionary:
		var settings_dict: Dictionary = settings_raw as Dictionary
		for key: Variant in DEFAULT_SETTINGS.keys():
			var key_name: String = String(key)
			var value_raw: Variant = settings_dict.get(key_name)
			# Eksik ya da bool olmayan ayar, varsayılanı korur (tolerans kuralı).
			if value_raw is bool:
				profile._settings[key_name] = bool(value_raw)

	var records_raw: Variant = d.get("records")
	if records_raw is Dictionary:
		profile._records = RunRecords.from_dict(records_raw as Dictionary)

	var stats_raw: Variant = d.get("stats")
	if stats_raw is Dictionary:
		var stats_dict: Dictionary = stats_raw as Dictionary
		profile._deliveries = _whole_or_zero(stats_dict.get("deliveries", 0))
		profile._breaks = _whole_or_zero(stats_dict.get("breaks", 0))
		var best_raw: Variant = stats_dict.get("best_stars")
		if best_raw is Dictionary:
			var best_dict: Dictionary = best_raw as Dictionary
			for key: Variant in best_dict.keys():
				profile._best_stars[String(key)] = _whole_or_zero(best_dict[key])

	return profile


## Eksik/yanlış tip/küsuratlı/negatif sayı 0 sayılır (Wallet.from_dict ile aynı kural).
static func _whole_or_zero(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		return maxi(int(value), 0)
	if typeof(value) == TYPE_FLOAT:
		var number: float = float(value)
		if is_finite(number) and is_equal_approx(number, roundf(number)):
			return maxi(int(roundf(number)), 0)
	return 0
