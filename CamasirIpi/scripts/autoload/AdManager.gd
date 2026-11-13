extends Node

## Ödüllü reklam orkestrasyonu. SDK bilmez; `AdsProvider` ile konuşur.
## Ödül YALNIZCA sağlayıcıdan `rewarded` geldikten sonra verilir (idempotent).

## Eski üç yerleşim korunur; ekonomi yerleşimleri sona eklendi (sıra numaraları değişmez).
## INTERSTITIAL ödüllü değildir: `show_interstitial()` ile gösterilir, ödül sinyali vermez.
enum Placement { EXTRA_POCKET, TAPE_RESCUE, DOUBLE_REWARD, REVIVE_EXTRA_SLOT, DOUBLE_COINS, REFILL_BOOSTER, INTERSTITIAL }

const PLACEMENT_KEYS: Dictionary = {
	Placement.EXTRA_POCKET: "EXTRA_POCKET",
	Placement.TAPE_RESCUE: "TAPE_RESCUE",
	Placement.DOUBLE_REWARD: "DOUBLE_REWARD",
	Placement.REVIVE_EXTRA_SLOT: "REVIVE_EXTRA_SLOT",
	Placement.DOUBLE_COINS: "DOUBLE_COINS",
	Placement.REFILL_BOOSTER: "REFILL_BOOSTER",
	Placement.INTERSTITIAL: "INTERSTITIAL",
}

const LIMITS_PATH: String = "res://data/ads.json"

## Tur içi kullanım (GameManager.reset_run_limits() ile sıfırlanır).
const DEFAULT_LIMITS: Dictionary = {
	"EXTRA_POCKET": {"per_run": 1, "per_session": 3},
	"TAPE_RESCUE": {"per_run": 1, "per_session": 5},
	"DOUBLE_REWARD": {"per_run": 1, "per_session": 3},
	"REVIVE_EXTRA_SLOT": {"per_run": 1, "per_session": 30},
	"DOUBLE_COINS": {"per_run": 1, "per_session": 30},
	"REFILL_BOOSTER": {"per_run": 3, "per_session": 30},
	"INTERSTITIAL": {"per_run": 99, "per_session": 999},
}

signal ad_started(placement: Placement)
signal rewarded_finished(placement: Placement, success: bool)
signal ad_failed(placement: Placement, reason: String)
## Geçiş reklamı bitti (success=false: gösterilemedi); akış her iki durumda da devam eder.
signal interstitial_finished(success: bool)

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


## Geçiş reklamı: sıklık kararı `AdPacing`de; burası yalnız sağlayıcıyı çalıştırır.
func show_interstitial() -> bool:
	if _pending != -1 or provider == null or not provider.is_ready(Placement.INTERSTITIAL):
		return false
	_pending = Placement.INTERSTITIAL
	provider.show(Placement.INTERSTITIAL)
	ad_started.emit(Placement.INTERSTITIAL)
	return true


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
	if placement == Placement.INTERSTITIAL:
		interstitial_finished.emit(true)
		return
	var key: String = PLACEMENT_KEYS.get(placement, "")
	_used_run[key] = int(_used_run.get(key, 0)) + 1
	_used_session[key] = int(_used_session.get(key, 0)) + 1
	rewarded_finished.emit(placement, true)


func _on_provider_failed(reason: String) -> void:
	if _pending == -1:
		return
	var placement: Placement = _pending
	_pending = -1
	if placement == Placement.INTERSTITIAL:
		interstitial_finished.emit(false)
		return
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
