extends Node

## Ödüllü reklam orkestrasyonu. SDK bilmez; `AdsProvider` ile konuşur.
## Ödül YALNIZCA sağlayıcıdan `rewarded` geldikten sonra verilir (idempotent).

enum Placement { EXTRA_POCKET, TAPE_RESCUE, DOUBLE_REWARD }

const PLACEMENT_KEYS: Dictionary = {
	Placement.EXTRA_POCKET: "EXTRA_POCKET",
	Placement.TAPE_RESCUE: "TAPE_RESCUE",
	Placement.DOUBLE_REWARD: "DOUBLE_REWARD",
}

const LIMITS_PATH: String = "res://data/ads.json"

## Tur içi kullanım (GameManager.reset_run_limits() ile sıfırlanır).
const DEFAULT_LIMITS: Dictionary = {
	"EXTRA_POCKET": {"per_run": 1, "per_session": 3},
	"TAPE_RESCUE": {"per_run": 1, "per_session": 5},
	"DOUBLE_REWARD": {"per_run": 1, "per_session": 3},
}

signal ad_started(placement: Placement)
signal rewarded_finished(placement: Placement, success: bool)
signal ad_failed(placement: Placement, reason: String)

var provider: AdsProvider = null

var _limits: Dictionary = {}
var _used_run: Dictionary = {}
var _used_session: Dictionary = {}
var _pending: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_limits()
	set_provider(MockAdsProvider.new())


func set_provider(new_provider: AdsProvider) -> void:
	if provider != null:
		if provider.shown.is_connected(_on_provider_shown):
			provider.shown.disconnect(_on_provider_shown)
		if provider.rewarded.is_connected(_on_provider_rewarded):
			provider.rewarded.disconnect(_on_provider_rewarded)
		if provider.failed.is_connected(_on_provider_failed):
			provider.failed.disconnect(_on_provider_failed)
	provider = new_provider
	if provider != null:
		provider.shown.connect(_on_provider_shown)
		provider.rewarded.connect(_on_provider_rewarded)
		provider.failed.connect(_on_provider_failed)
		provider.initialize()


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


func show_rewarded(placement: Placement) -> void:
	if _pending != -1:
		ad_failed.emit(placement, "already_pending")
		return
	if not can_offer(placement):
		ad_failed.emit(placement, "not_available")
		return
	_pending = placement
	provider.show(placement)
	ad_started.emit(placement)


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


func _on_provider_shown() -> void:
	pass


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
	rewarded_finished.emit(placement, false)
	ad_failed.emit(placement, reason)


func _load_limits() -> void:
	_limits = DEFAULT_LIMITS.duplicate(true)
	if not FileAccess.file_exists(LIMITS_PATH):
		push_warning("AdManager: %s yok, varsayılan limitler kullanılıyor" % LIMITS_PATH)
		return
	var text: String = FileAccess.get_file_as_string(LIMITS_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("AdManager: %s okunamadı, varsayılan limitler" % LIMITS_PATH)
		return
	_limits = (parsed as Dictionary).duplicate(true)
