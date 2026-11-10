extends Node

## Ödüllü reklam orkestrasyonu. SDK bilmez; `AdsProvider` ile konuşur.
## Ödül YALNIZCA sağlayıcıdan `rewarded` geldikten sonra verilir (idempotent).
## Sözleşme: ARCHITECTURE.md §3 — Placement, can_offer, show_rewarded,
## reset_run_limits, rewarded_finished(placement, success).

## Yerleşimler PROJECT_SPEC.md §6. Sıra sabittir; panel-ui/panel-world bu
## değerleri `AdManager.Placement.X` olarak okur.
enum Placement { FUSE_RESCUE, GOLDEN_CUTTER, INSULATION_SPRAY }

const PLACEMENT_KEYS: Dictionary = {
	Placement.FUSE_RESCUE: "FUSE_RESCUE",
	Placement.GOLDEN_CUTTER: "GOLDEN_CUTTER",
	Placement.INSULATION_SPRAY: "INSULATION_SPRAY",
}

const LIMITS_PATH: String = "res://data/ads.json"

## Tur içi kullanım (GameManager.start_level -> reset_run_limits() ile sıfırlanır).
## `data/ads.json` yoksa/bozuksa bu değerler geçerlidir.
const DEFAULT_LIMITS: Dictionary = {
	"FUSE_RESCUE": {"per_run": 1, "per_session": 5},
	"GOLDEN_CUTTER": {"per_run": 1, "per_session": 3},
	"INSULATION_SPRAY": {"per_run": 1, "per_session": 3},
}

signal ad_started(placement: Placement)
signal rewarded_finished(placement: Placement, success: bool)
signal ad_failed(placement: Placement, reason: String)

var provider: AdsProvider = null

var _limits: Dictionary = {}
var _used_run: Dictionary = {}
var _used_session: Dictionary = {}
## Gösterimi süren yerleşim; -1 = boşta. Aynı anda ikinci reklamı engeller.
var _pending: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_limits()
	set_provider(MockAdsProvider.new())


func set_provider(new_provider: AdsProvider) -> void:
	if provider != null:
		_disconnect_provider(provider)
	provider = new_provider
	if provider != null:
		provider.shown.connect(_on_provider_shown)
		provider.rewarded.connect(_on_provider_rewarded)
		provider.failed.connect(_on_provider_failed)
		provider.initialize()


## Bu yerleşim şu anda ödüllü reklamla sunulabilir mi? (sağlayıcı hazır +
## limit var + başka reklam gösterilmiyor)
func can_offer(placement: Placement) -> bool:
	if provider == null or not provider.is_ready(placement):
		return false
	if _pending != -1:
		return false
	var key: String = PLACEMENT_KEYS.get(placement, "")
	var limit: Dictionary = _limits.get(key, DEFAULT_LIMITS.get(key, {"per_run": 1, "per_session": 1}))
	var used_run: int = int(_used_run.get(key, 0))
	var used_session: int = int(_used_session.get(key, 0))
	return used_run < int(limit.get("per_run", 1)) and used_session < int(limit.get("per_session", 1))


## Ödüllü reklamı başlatır. Ödül buradan DEĞİL, `rewarded_finished` sinyalinden verilir.
func show_rewarded(placement: Placement) -> void:
	if _pending != -1:
		ad_failed.emit(placement, "already_pending")
		return
	if not can_offer(placement):
		ad_failed.emit(placement, "not_available")
		return
	_pending = placement
	ad_started.emit(placement)
	provider.show(placement)


## Yeni bölüm: tur içi sayaçlar sıfırlanır. Yarım kalmış reklam akışı da iptal edilir
## (sağlayıcı geç gelen sonucu gönderirse `_pending` boş olduğu için yok sayılır).
func reset_run_limits() -> void:
	_used_run.clear()
	_pending = -1


## Oturum limitlerini de sıfırlar (testler ve "yeni oyun" için).
func reset_session_limits() -> void:
	_used_run.clear()
	_used_session.clear()
	_pending = -1


func used_in_run(placement: Placement) -> int:
	return int(_used_run.get(PLACEMENT_KEYS.get(placement, ""), 0))


func used_in_session(placement: Placement) -> int:
	return int(_used_session.get(PLACEMENT_KEYS.get(placement, ""), 0))


## Reklam akışı sürüyor mu? HUD butonlarını kilitlemek için.
func has_pending() -> bool:
	return _pending != -1


func _disconnect_provider(target: AdsProvider) -> void:
	if target.shown.is_connected(_on_provider_shown):
		target.shown.disconnect(_on_provider_shown)
	if target.rewarded.is_connected(_on_provider_rewarded):
		target.rewarded.disconnect(_on_provider_rewarded)
	if target.failed.is_connected(_on_provider_failed):
		target.failed.disconnect(_on_provider_failed)


func _on_provider_shown() -> void:
	pass


## Ödül yolu tek: _pending boşsa geç gelen/çift gelen provider sinyali yok sayılır.
func _on_provider_rewarded() -> void:
	if _pending == -1:
		return
	var placement: Placement = _pending
	_pending = -1
	var key: String = PLACEMENT_KEYS.get(placement, "")
	_used_run[key] = int(_used_run.get(key, 0)) + 1
	_used_session[key] = int(_used_session.get(key, 0)) + 1
	rewarded_finished.emit(placement, true)


func _on_provider_failed(reason: String) -> void:
	if _pending == -1:
		return
	var placement: Placement = _pending
	_pending = -1
	# Başarısız reklam limit tüketmez; yalnızca başarılı ödül sayaç artırır.
	rewarded_finished.emit(placement, false)
	ad_failed.emit(placement, reason)


## `data/ads.json` varsayılanların üzerine bindirilir; eksik alan varsayılanda kalır.
func _load_limits() -> void:
	_limits = DEFAULT_LIMITS.duplicate(true)
	if not FileAccess.file_exists(LIMITS_PATH):
		push_warning("AdManager: %s yok, varsayılan limitler kullanılıyor" % LIMITS_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LIMITS_PATH))
	if not (parsed is Dictionary):
		push_warning("AdManager: %s okunamadı, varsayılan limitler" % LIMITS_PATH)
		return
	var table: Dictionary = parsed as Dictionary
	for key: Variant in table.keys():
		var key_text: String = String(key)
		if not DEFAULT_LIMITS.has(key_text) or not (table[key] is Dictionary):
			continue
		var source: Dictionary = table[key] as Dictionary
		var merged: Dictionary = (_limits[key_text] as Dictionary).duplicate()
		if source.has("per_run"):
			merged["per_run"] = maxi(0, int(source["per_run"]))
		if source.has("per_session"):
			merged["per_session"] = maxi(0, int(source["per_session"]))
		_limits[key_text] = merged
