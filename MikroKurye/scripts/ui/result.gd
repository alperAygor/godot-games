extends Control

## Sonuç ekranı: `GameManager.last_result` sözlüğünü gösterir ve tur ödülünü
## kayda BİR KEZ işler. Sözleşme: ARCHITECTURE.md §5.4 + §5.5.
## Reklamlı bonuslar yalnız başarılı sonuçta ve `AdManager.can_offer` iken
## görünür; her biri tur başına en fazla bir kez ödül verir.

const GOLDEN_GOLD_DEFAULT: int = 150
const GOLDEN_SCRAP_DEFAULT: int = 10

@onready var title_label: Label = %Title
@onready var stars_label: Label = %Stars
@onready var detail_label: Label = %Detail
@onready var wallet_label: Label = %WalletLabel
@onready var _double_button: Button = %DoubleRewardButton
@onready var _golden_button: Button = %GoldenBoxButton

var _result: Dictionary = {}
var _save: Node = null
var _ad: Node = null
var _double_pending: bool = false
var _double_done: bool = false
var _golden_pending: bool = false
var _golden_done: bool = false


func _ready() -> void:
	GameManager.set_phase(GameManager.Phase.RESULT)
	_result = GameManager.last_result
	_double_done = bool(_result.get("doubled", false))
	_golden_done = bool(_result.get("golden_box_claimed", false))
	_save = get_node_or_null("/root/SaveService")
	_ad = get_node_or_null("/root/AdManager")
	var stars: int = int(_result.get("stars", 0))
	var fee: int = int(_result.get("fee", 0))
	var damage: float = float(_result.get("damage", 0.0))
	var gold: int = int(_result.get("gold", 0))
	var scrap: int = int(_result.get("scrap", 0))

	title_label.text = "Teslimat Tamamlandı" if stars > 0 else "Teslimat Hasarlı"
	stars_label.text = "Yıldız: %d / 3" % stars
	# `fee` eski sonuçlarla uyum için korunur; yeni akışta gold ile aynıdır.
	detail_label.text = "Hasar: %%%d    Ücret: %d\nAltın: %d    Hurda: %d" % [
		int(roundf(damage * 100.0)), fee, gold, scrap]

	# Kayıt yoksa (probe/izole sahne) sonuç değerleri gösterilir, çökme yok.
	if _save != null:
		_save.call("apply_result", _result)
		_update_wallet()

	_setup_reward_buttons()

	if stars > 0:
		AudioService.play("success")

	(%RetryButton as Button).pressed.connect(_on_retry)
	(%MenuButton as Button).pressed.connect(_on_menu)
	GameManager.back_requested.connect(_on_menu)


func _setup_reward_buttons() -> void:
	_double_button.text = UiStrings.DOUBLE_REWARD
	_golden_button.text = UiStrings.GOLDEN_BOX
	_double_button.pressed.connect(_on_double_pressed)
	_golden_button.pressed.connect(_on_golden_pressed)

	_refresh_reward_buttons()

	if _ad == null:
		# Reklam servisi yoksa düğmeler teklif edilmez; oyun reklamsız akar.
		_double_button.visible = false
		_golden_button.visible = false
		return
	if not _ad.is_connected("rewarded_finished", _on_ad_rewarded):
		_ad.connect("rewarded_finished", _on_ad_rewarded)
	if not _ad.is_connected("ad_failed", _on_ad_failed):
		_ad.connect("ad_failed", _on_ad_failed)


func _can_offer(placement: int) -> bool:
	if _ad == null:
		return false
	return bool(_ad.call("can_offer", placement))


func _reward_pending() -> bool:
	return _double_pending or _golden_pending


func _result_successful() -> bool:
	var stars: int = int(_result.get("stars", 0))
	return bool(_result.get("success", stars > 0))


func _refresh_reward_buttons() -> void:
	var pending: bool = _reward_pending()
	_double_button.visible = _result_successful() and not bool(_result.get("doubled", false)) \
		and not _double_done and _can_offer(AdManager.Placement.DOUBLE_REWARD)
	_golden_button.visible = _result_successful() and bool(_result.get("golden_box", false)) \
		and not bool(_result.get("golden_box_claimed", false)) and not _golden_done \
		and _can_offer(AdManager.Placement.GOLDEN_BOX)
	_double_button.disabled = pending or not _double_button.visible
	_golden_button.disabled = pending or not _golden_button.visible
	(%RetryButton as Button).disabled = pending
	(%MenuButton as Button).disabled = pending


func _on_double_pressed() -> void:
	if _reward_pending() or _double_done or bool(_result.get("doubled", false)):
		return
	if not _double_button.visible or _double_button.disabled or not _result_successful():
		return
	if not _can_offer(AdManager.Placement.DOUBLE_REWARD):
		return
	_double_pending = true
	_refresh_reward_buttons()
	_ad.call("show_rewarded", AdManager.Placement.DOUBLE_REWARD)


func _on_golden_pressed() -> void:
	if _reward_pending() or _golden_done or bool(_result.get("golden_box_claimed", false)):
		return
	if not _golden_button.visible or _golden_button.disabled or not _result_successful():
		return
	if not bool(_result.get("golden_box", false)):
		return
	if not _can_offer(AdManager.Placement.GOLDEN_BOX):
		return
	_golden_pending = true
	_refresh_reward_buttons()
	_ad.call("show_rewarded", AdManager.Placement.GOLDEN_BOX)


func _on_ad_rewarded(placement: int, success: bool) -> void:
	if placement == AdManager.Placement.DOUBLE_REWARD and _double_pending:
		_double_pending = false
		if success:
			_apply_double()
	elif placement == AdManager.Placement.GOLDEN_BOX and _golden_pending:
		_golden_pending = false
		if success:
			_apply_golden()
	_refresh_reward_buttons()


func _on_ad_failed(placement: int, _reason: String) -> void:
	if placement == AdManager.Placement.DOUBLE_REWARD and _double_pending:
		_double_pending = false
	elif placement == AdManager.Placement.GOLDEN_BOX and _golden_pending:
		_golden_pending = false
	_refresh_reward_buttons()


## İkinci kez ödül yok: düğme hem gizlenir hem `_double_done` ile korunur.
func _apply_double() -> void:
	if _double_done or bool(_result.get("doubled", false)):
		return
	_double_done = true
	_result["doubled"] = true
	if _save != null:
		_save.call("grant", int(_result.get("gold", 0)), int(_result.get("scrap", 0)))
	_double_button.visible = false
	_double_button.disabled = true
	_update_wallet()


func _apply_golden() -> void:
	if _golden_done or bool(_result.get("golden_box_claimed", false)):
		return
	_golden_done = true
	_result["golden_box_claimed"] = true
	if _save != null:
		var gold: int = GOLDEN_GOLD_DEFAULT
		var scrap: int = GOLDEN_SCRAP_DEFAULT
		var data: Node = get_node_or_null("/root/GameData")
		if data != null:
			var balance: Dictionary = data.call("table", "balance") as Dictionary
			var game_params: Dictionary = balance.get("game", {}) as Dictionary
			gold = int(game_params.get("golden_box_gold", GOLDEN_GOLD_DEFAULT))
			scrap = int(game_params.get("golden_box_scrap", GOLDEN_SCRAP_DEFAULT))
		_save.call("grant", gold, scrap)
	_golden_button.visible = false
	_golden_button.disabled = true
	_update_wallet()


func _update_wallet() -> void:
	var gold: int = int(_result.get("gold", 0))
	var scrap: int = int(_result.get("scrap", 0))
	if _save != null:
		var profile: ProfileData = _save.call("profile") as ProfileData
		if profile != null:
			gold = profile.wallet().gold()
			scrap = profile.wallet().scrap()
	wallet_label.text = UiStrings.wallet_label(gold, scrap)


func _on_retry() -> void:
	if _reward_pending():
		return
	GameManager.start_game()


func _on_menu() -> void:
	if _reward_pending():
		return
	GameManager.goto_scene(&"menu")
