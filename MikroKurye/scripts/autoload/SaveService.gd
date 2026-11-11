extends Node

## Kalıcı oyuncu ilerlemesi: `ProfileData`'yı `user://save.json`'a yazar/okur.
## Sözleşme: ARCHITECTURE.md §5.4.
##
## - Yazma atomiktir: önce geçici dosyaya yazılır, sonra yeniden adlandırılır.
##   Böylece yazma ortasında kesilen bir kayıt yarım JSON bırakmaz.
## - Bozuk kayıt çökme üretmez: dosya `.corrupt` olarak yedeklenir, varsayılan
##   profil yüklenir ve temiz bir kayıt bırakılır.
## - `apply_result` aynı sonucu iki kez uygulamaz; işaret çağıranın sözlüğüne
##   yazılır (sözleşmedeki `result["applied"]` işareti).
##
## `-s` probunda autoload kimliği derlenmediği için GameData'ya `/root/...`
## yoluyla erişilir (GOTCHAS.md #2).

const DEFAULT_SAVE_PATH: String = "user://save.json"
const CORRUPT_SUFFIX: String = ".corrupt"
const TEMP_SUFFIX: String = ".tmp"
const UPGRADES_TABLE: String = "upgrades"
const JSON_INDENT: String = "\t"

## Test için değiştirilebilir; varsayılan gerçek kayıt dosyasıdır.
var _save_path: String = DEFAULT_SAVE_PATH
var _profile: ProfileData = null
## Deneme (TRY_BEFORE_BUY) yalnızca bir sonraki koşu için geçerlidir; bu yüzden
## diske yazılmaz. GameController koşu başında modlara kattıktan sonra temizler.
var _trial_category: String = ""


func _ready() -> void:
	# Kayıt servisi duraklatılmış sahnede de yanıt versin (CLAUDE.md §4).
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_profile()


func profile() -> ProfileData:
	# `_profile` yalnız load_profile ile değişir; canlı referans döner.
	if _profile == null:
		_profile = ProfileData.new()
	return _profile


## Testlerin gerçek kaydı ezmemesi için yol değiştirilebilir.
func set_save_path(path: String) -> void:
	_save_path = path if not path.is_empty() else DEFAULT_SAVE_PATH


func load_profile() -> void:
	# Her yükleme temiz bir modelle başlar: eksik alanlar varsayılana döner.
	_profile = ProfileData.new()
	if not FileAccess.file_exists(_save_path):
		return
	var file: FileAccess = FileAccess.open(_save_path, FileAccess.READ)
	if file == null:
		push_warning("SaveService: kayıt okunamadı (%s); varsayılan profil" % _save_path)
		_backup_corrupt()
		return
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		_profile = ProfileData.from_dict(parsed as Dictionary)
		return
	push_warning("SaveService: kayıt bozuk (%s); varsayılan profil" % _save_path)
	_backup_corrupt()


## Geçici dosyaya yaz + yeniden adlandır. Hedef dosya yarım kalmaz.
func save_profile() -> bool:
	var target_abs: String = ProjectSettings.globalize_path(_save_path)
	var temp_path: String = _save_path + TEMP_SUFFIX
	var temp_abs: String = ProjectSettings.globalize_path(temp_path)
	var directory: DirAccess = DirAccess.open(target_abs.get_base_dir())
	if directory == null:
		push_warning("SaveService: kayıt dizini açılamadı (%s)" % target_abs.get_base_dir())
		return false
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_warning("SaveService: geçici kayıt açılamadı (%s)" % temp_path)
		return false
	file.store_string(JSON.stringify(profile().to_dict(), JSON_INDENT))
	file.flush()
	file.close()
	var error: Error = DirAccess.rename_absolute(temp_abs, target_abs)
	if error != OK:
		push_warning("SaveService: kayıt yerine konamadı (%s), hata %d" % [_save_path, error])
		DirAccess.remove_absolute(temp_abs)
		return false
	return true


## Aynı sonuç iki kez uygulanmaz: ilk çağrı `result["applied"]` işaretini bırakır.
func apply_result(result: Dictionary) -> void:
	var applied: Variant = result.get("applied", false)
	if applied is bool and bool(applied):
		return
	profile().record_result(result)
	# Kayıt yazılamasa bile aynı tur sonucu ikinci kez ödüllendirilmez.
	result["applied"] = true
	save_profile()


## Sıradaki seviyenin bedeli; maksimumda ya da bilinmeyen kategoride {}.
func upgrade_cost(category: String) -> Dictionary:
	return UpgradeModel.cost(_upgrade_table(), category, profile().level(category) + 1)


## Yetersiz bakiye/maksimum/bilinmeyen kategori: false ve profilde DEĞİŞİKLİK YOK.
func purchase(category: String) -> bool:
	var table: Dictionary = _upgrade_table()
	var current_wallet: Wallet = profile().wallet()
	var purchase_result: Dictionary = UpgradeModel.purchase(
		table, current_wallet.to_dict(), profile().levels(), category)
	if not bool(purchase_result.get("ok", false)):
		return false
	var next_wallet: Dictionary = purchase_result.get("wallet", {}) as Dictionary
	var next_levels: Dictionary = purchase_result.get("levels", {}) as Dictionary
	# UpgradeModel kararı zaten bakiyeyi doğruladı; farkı uygulamak canlı
	# Wallet referansını korur ve modele tekrar hesap yaptırmaz.
	var spent: Dictionary = {
		"gold": current_wallet.gold() - int(next_wallet.get("gold", 0)),
		"scrap": current_wallet.scrap() - int(next_wallet.get("scrap", 0)),
	}
	if not current_wallet.spend(spent):
		return false
	profile().set_level(category, int(next_levels.get(category, profile().level(category))))
	save_profile()
	return true


## Reklamla kazanılan ek ödül; negatif değerler Wallet.add tarafından 0 sayılır.
func grant(gold: int, scrap: int) -> void:
	profile().wallet().add(gold, scrap)
	save_profile()


## Bir sonraki koşu için kategori denemesi açar; bilinmeyen kategori yok sayılır.
func set_trial(category: String) -> void:
	var table: Dictionary = _upgrade_table()
	if category.is_empty() or not table.has(category):
		return
	_trial_category = category


func clear_trial() -> void:
	_trial_category = ""


func trial() -> String:
	return _trial_category


## Sahip olunan seviyelerin mod toplamları; GameController bunları uygular.
## Deneme kategorisinin SONRAKİ seviyesinin modları da eklenir (§5.5).
func mods() -> Dictionary:
	var table: Dictionary = _upgrade_table()
	var totals: Dictionary = UpgradeModel.stats(table, profile().levels())
	if _trial_category.is_empty() or not table.has(_trial_category):
		return totals
	var level: int = profile().level(_trial_category)
	# `stats` 1..N seviyelerini toplar; farkı almak yalnız N+1'in katkısını verir
	# ve sahip olunan seviyelerin iki kez sayılmasını engeller.
	var owned: Dictionary = UpgradeModel.stats(table, {_trial_category: level})
	var with_next: Dictionary = UpgradeModel.stats(table, {_trial_category: level + 1})
	for key: Variant in with_next.keys():
		var name: String = String(key)
		var extra: float = float(with_next[key]) - float(owned.get(name, 0.0))
		if absf(extra) > 0.0001:
			totals[name] = float(totals.get(name, 0.0)) + extra
	return totals


func _upgrade_table() -> Dictionary:
	var data: Node = get_node_or_null("/root/GameData")
	if data == null:
		return {}
	var found: Variant = data.call("table", UPGRADES_TABLE)
	if found is Dictionary:
		return found as Dictionary
	return {}


## Bozuk kaydı yanına kopyalar, sonra temiz bir varsayılan kayıt bırakır.
func _backup_corrupt() -> void:
	var source_abs: String = ProjectSettings.globalize_path(_save_path)
	var backup_abs: String = ProjectSettings.globalize_path(_save_path + CORRUPT_SUFFIX)
	# Önceki bozuk yedek varsa üzerine yazılabilsin diye kaldırılır.
	DirAccess.remove_absolute(backup_abs)
	var error: Error = DirAccess.copy_absolute(source_abs, backup_abs)
	if error != OK:
		push_warning("SaveService: bozuk kayıt yedeklenemedi (%s), hata %d" % [backup_abs, error])
	# Atomik yazma bozuk hedefin üzerine geçer; sonraki açılış temiz başlar.
	save_profile()
