extends Control

## Sonuç ekranı: `GameManager.last_result` sözlüğünü gösterir ve tur ödülünü
## kayda BİR KEZ işler. Sözleşme: ARCHITECTURE.md §5.4 + §5.5.
## Reklamlı bonuslar yalnız başarılı sonuçta ve `AdManager.can_offer` iken
## görünür; her biri tur başına en fazla bir kez ödül verir.
##
## F7.6b: büyük yıldızlar kademeli belirir, altın/hurda sayaçları sayarak
## dolar; renk/ölçü `UiTheme` (data/theme.json) token'larından okunur.

const GOLDEN_GOLD_DEFAULT: int = 150
const GOLDEN_SCRAP_DEFAULT: int = 10
const STAR_TOTAL: int = 3
const STAR_SIZE: float = 112.0
const REWARD_ICON_SIZE: float = 44.0
## Yıldızlar sırayla (200 ms arayla) büyüyerek + hafif dönerek dolar.
const STAR_STAGGER: float = 0.2
const STAR_FILL_SECONDS: float = 0.34
const STAR_ROTATION_DEG: float = -18.0
## Boş yıldız soluk çizgi; dolu yıldız tam sarı dolgu.
const STAR_EMPTY_ALPHA: float = 0.35
const STAR_FILLED_ICON: String = "res://assets/ui_icons/star_filled.svg"
const SPARKLE_TEXTURE: String = "res://assets/ui_icons/sparkle.svg"
const SPARKLE_AMOUNT: int = 10
const COUNT_SECONDS: float = 0.6
## Sayaçlar yıldızlar dolduktan SONRA başlar.
const STAR_COUNT_DELAY: float = STAR_STAGGER * float(STAR_TOTAL - 1) + STAR_FILL_SECONDS

@onready var title_label: Label = %Title
@onready var _star_box: HBoxContainer = %Stars
@onready var detail_label: Label = %Detail
@onready var wallet_label: Label = %WalletLabel
@onready var _reward_row: Control = %RewardRow
@onready var _gold_reward_label: Label = %GoldRewardLabel
@onready var _scrap_reward_label: Label = %ScrapRewardLabel
@onready var _gold_reward_icon: TextureRect = %GoldRewardIcon
@onready var _scrap_reward_icon: TextureRect = %ScrapRewardIcon
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

	_stylize()
	var endless: bool = bool(_result.get("endless", false))
	if endless:
		_show_endless(gold, scrap)
	else:
		title_label.text = UiStrings.RESULT_SUCCESS if stars > 0 else UiStrings.RESULT_FAIL
		detail_label.text = "Hasar: %d%%  ·  Ücret: %d" % [int(roundf(damage * 100.0)), fee]
		_build_stars(stars)
		# Başarısız turda ödül çipi anlamsız; sakin görünüm için gizlenir.
		_reward_row.visible = stars > 0
		if stars > 0:
			_count_rewards(gold, scrap)
		else:
			_gold_reward_label.text = "0"
			_scrap_reward_label.text = "0"

	# Kayıt yoksa (probe/izole sahne) sonuç değerleri gösterilir, çökme yok.
	if _save != null:
		_save.call("apply_result", _result)
		_update_wallet()

	_setup_reward_buttons()

	if stars > 0 or (endless and _result_successful()):
		AudioService.play("success")

	(%RetryButton as Button).text = UiStrings.RESULT_RETRY
	(%MenuButton as Button).text = UiStrings.RESULT_MENU
	(%RetryButton as Button).pressed.connect(_on_retry)
	(%MenuButton as Button).pressed.connect(_on_menu)
	GameManager.back_requested.connect(_on_menu)
	UiSfx.bind(self)
	UiMotion.fade_in(self)


## Sonsuz mod sonucu: level/mesafe/puan, kasa ödemesi ve kırılan rekorlar (PROJECT_SPEC §14).
## Rekor bayrakları kayıt işlenirken (`apply_result`) hesaplandığından kayıt önce yapılır.
func _show_endless(gold: int, scrap: int) -> void:
	if _save != null:
		_save.call("apply_result", _result)
	var reason: String = String(_result.get("reason", ""))
	var broken: bool = reason == "broken"
	title_label.text = UiStrings.ENDLESS_BROKEN if broken else UiStrings.ENDLESS_DONE
	_star_box.visible = false
	var lines: Array[String] = [UiStrings.ENDLESS_STATS_FORMAT % [
		int(_result.get("level", 1)), int(float(_result.get("distance", 0.0))), int(_result.get("score", 0))]]
	var banked: int = int(_result.get("banked_gold", 0))
	if banked > 0:
		if broken:
			var percent: int = int(round(float(_result.get("payout_fraction", 0.5)) * 100.0))
			lines.append(UiStrings.ENDLESS_PART_PAY_FORMAT % [banked, percent])
		else:
			lines.append(UiStrings.ENDLESS_FULL_PAY_FORMAT % banked)
	var flags: Dictionary = _result.get("new_records", {}) as Dictionary
	var broken_records: Array[String] = []
	if bool(flags.get("new_level", false)):
		broken_records.append(UiStrings.RECORD_LEVEL)
	if bool(flags.get("new_distance", false)):
		broken_records.append(UiStrings.RECORD_DISTANCE)
	if bool(flags.get("new_score", false)):
		broken_records.append(UiStrings.RECORD_SCORE)
	if not broken_records.is_empty():
		lines.append(UiStrings.NEW_RECORD_FORMAT % ", ".join(broken_records))
	detail_label.text = "\n".join(lines)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reward_row.visible = gold > 0 or scrap > 0
	_gold_reward_label.text = "0"
	_scrap_reward_label.text = "0"
	if _reward_row.visible:
		_count_up(_gold_reward_label, gold)
		_count_up(_scrap_reward_label, scrap)


func _stylize() -> void:
	(%Background as ColorRect).color = UiTheme.color("background")
	title_label.add_theme_color_override("font_color", UiTheme.color("text"))
	detail_label.add_theme_color_override("font_color", UiTheme.color("text_muted"))
	wallet_label.add_theme_color_override("font_color", UiTheme.color("text_muted"))
	_gold_reward_icon.texture = Icons.texture("lucide/coins")
	_scrap_reward_icon.texture = Icons.texture("lucide/cog")
	_gold_reward_icon.modulate = UiTheme.color("secondary")
	_scrap_reward_icon.modulate = UiTheme.color("text_muted")


func _build_stars(count: int) -> void:
	for child: Node in _star_box.get_children():
		child.queue_free()
	for i: int in STAR_TOTAL:
		var filled: bool = i < count
		var star := TextureRect.new()
		# Dolu = sarı dolgu ikonu; boş = soluk çizgi ikonu (stil farkı net).
		if filled:
			star.texture = load(STAR_FILLED_ICON) as Texture2D
			star.modulate = UiTheme.color("secondary")
		else:
			star.texture = Icons.texture("lucide/star")
			star.modulate = UiTheme.color("text_muted")
		star.custom_minimum_size = Vector2(STAR_SIZE, STAR_SIZE)
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star.pivot_offset = Vector2(STAR_SIZE, STAR_SIZE) * 0.5
		star.scale = Vector2.ONE * 0.3
		star.rotation = deg_to_rad(STAR_ROTATION_DEG)
		star.modulate.a = 0.0
		_star_box.add_child(star)
		_animate_star(star, float(i) * STAR_STAGGER, filled)


func _animate_star(star: TextureRect, delay: float, filled: bool) -> void:
	var target_alpha: float = 1.0 if filled else STAR_EMPTY_ALPHA
	var tween: Tween = star.create_tween()
	tween.tween_interval(delay)
	tween.set_parallel(true)
	tween.tween_property(star, "modulate:a", target_alpha, STAR_FILL_SECONDS * 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(star, "scale", Vector2.ONE, STAR_FILL_SECONDS) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(star, "rotation", 0.0, STAR_FILL_SECONDS) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Yıldız yerine oturunca küçük kıvılcım patlaması.
	if filled:
		var sparkle: Tween = star.create_tween()
		sparkle.tween_interval(delay + STAR_FILL_SECONDS)
		sparkle.tween_callback(_sparkle.bind(star))


## Yıldız üstünde tek seferlik kıvılcım (CPUParticles2D, ≤12 parçacık); bitince
## düğüm kendini temizler (bellek sızıntısı yok).
func _sparkle(star: Control) -> void:
	if not is_instance_valid(star):
		return
	var particles := CPUParticles2D.new()
	particles.amount = SPARKLE_AMOUNT
	particles.one_shot = true
	particles.emitting = true
	particles.explosiveness = 1.0
	particles.lifetime = 0.45
	particles.texture = load(SPARKLE_TEXTURE) as Texture2D
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.gravity = Vector2(0.0, 120.0)
	particles.initial_velocity_min = 40.0
	particles.initial_velocity_max = 90.0
	particles.scale_amount_min = 0.4
	particles.scale_amount_max = 1.0
	particles.position = star.size * 0.5
	particles.modulate = UiTheme.color("secondary")
	star.add_child(particles)
	particles.finished.connect(particles.queue_free)


func _count_rewards(gold: int, scrap: int) -> void:
	_gold_reward_label.text = "0"
	_scrap_reward_label.text = "0"
	_count_up(_gold_reward_label, gold, STAR_COUNT_DELAY)
	_count_up(_scrap_reward_label, scrap, STAR_COUNT_DELAY)


func _count_up(label: Label, target: int, delay: float = 0.0) -> void:
	var tween: Tween = create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_method(func(value: float) -> void: _set_count(label, value), 0.0, float(target), COUNT_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _set_count(label: Label, value: float) -> void:
	label.text = str(int(roundf(value)))


func _setup_reward_buttons() -> void:
	_double_button.text = UiStrings.DOUBLE_REWARD
	_golden_button.text = UiStrings.GOLDEN_BOX
	Icons.apply(_double_button, "lucide/circle-play", UiTheme.color("on_primary"), 40)
	Icons.apply(_golden_button, "lucide/gift", UiTheme.color("on_surface"), 40)
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
	if _double_button.visible:
		# Nabız basış ölçeğiyle çakışmasın; döngü ölçeği UiMotion'a bırakılır.
		_double_button.add_to_group(UiMotion.NO_PRESS_SCALE_GROUP)
		UiMotion.pulse(_double_button)


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
