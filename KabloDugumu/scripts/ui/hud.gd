class_name GameHUD
extends CanvasLayer

## Oyun içi HUD + overlay'ler (v0.2). Sadece gösterir; karar gameplay'de.
## API imzaları ARCHITECTURE §7 — DEĞİŞMEZ (game.gd bunları çağırıyor).
## Tasarım: üst bar ≤ 180 px, alt şerit ≤ 140 px, panoyu örtmez; ince aşırı yük
## şeridi; küçük ikon reklam butonları; ASMR tonlu (yumuşak amber, sert kırmızı yok).
## Duraklatma: tüm katman/tween'ler PROCESS_ALWAYS + TWEEN_PAUSE_PROCESS (GOTCHAS #5).

signal cutter_pressed()
signal spray_pressed()
signal revive_pressed()
signal retry_pressed()
signal menu_pressed()
signal pause_pressed()
signal resume_pressed()

const TOAST_HOLD_SECONDS: float = 1.8
const VIGNETTE_START: float = 0.65
const SHIELD_PULSE_SPEED: float = 3.0
const STAR_COUNT: int = 3
const VOLTAGE_DANGER: int = 200
const VOLTAGE_WARM: int = 120
const AD_PULSE_SPEED: float = 2.2

@onready var level_label: Label = %LevelLabel
@onready var time_label: Label = %TimeLabel
@onready var connected_label: Label = %ConnectedLabel
@onready var pause_button: Button = %PauseButton
@onready var overload_label: Label = %OverloadLabel
@onready var overload_bar: OverloadBar = %OverloadBar
@onready var voltage_label: Label = %VoltageLabel
@onready var shield_label: Label = %ShieldLabel
@onready var shield_pill: PanelContainer = %ShieldPill
@onready var hint_panel: PanelContainer = %HintPanel
@onready var hint_label: Label = %HintLabel
@onready var toast_panel: PanelContainer = %ToastPanel
@onready var toast_label: Label = %ToastLabel
@onready var cutter_button: Button = %CutterButton
@onready var cutter_badge: Label = %CutterBadge
@onready var spray_button: Button = %SprayButton
@onready var spray_badge: Label = %SprayBadge
@onready var cutter_label: Label = %CutterLabel
@onready var spray_label: Label = %SprayLabel
@onready var bottom_bar: Control = %BottomBar
@onready var vignette: TextureRect = %Vignette
@onready var flash: ColorRect = %Flash
@onready var fail_overlay: Control = %FailOverlay
@onready var fail_title: Label = %FailTitle
@onready var fail_reason: Label = %FailReason
@onready var revive_button: Button = %ReviveButton
@onready var retry_button: Button = %RetryButton
@onready var fail_menu_button: Button = %FailMenuButton
@onready var pause_overlay: Control = %PauseOverlay
@onready var pause_title: Label = %PauseTitle
@onready var resume_button: Button = %ResumeButton
@onready var menu_button: Button = %MenuButton
@onready var ad_overlay: Control = %AdOverlay
@onready var ad_tag: Label = %AdTag
@onready var ad_label: Label = %AdLabel
@onready var celebrate_root: Control = %Celebrate
@onready var celebrate_title: Label = %CelebrateTitle
@onready var celebrate_star_1: Control = %CelebrateStar1
@onready var celebrate_star_2: Control = %CelebrateStar2
@onready var celebrate_star_3: Control = %CelebrateStar3

var _level_index: int = 1
var _level_name: String = ""
var _total_cables: int = 0
var _par_seconds: float = 60.0
var _elapsed: float = 0.0
var _overload: float = 0.0
var _voltage: int = 0
var _shield_left: float = 0.0
var _done: int = 0
var _hint_text: String = ""
var _fail_reason: String = ""
var _fail_can_revive: bool = false
var _ad_visible: bool = false
var _paused: bool = false
var _fail_visible: bool = false
var _celebrate_visible: bool = false
var _can_cutter: bool = false
var _can_spray: bool = false
var _time: float = 0.0
var _toast_tween: Tween = null
var _celebrate_stars: Array[Control] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_celebrate_stars = [celebrate_star_1, celebrate_star_2, celebrate_star_3]
	_wire_buttons()
	_wire_icons()
	_reset_visuals()
	_refresh_texts()
	_refresh_chrome()
	Loc.language_changed.connect(_on_language_changed)
	await get_tree().process_frame
	_center_pivots()


## Görsel durum sıfırlama: yeni bölüm kurulurken game.gd setup() çağırır.
func setup(level_index: int, level_name: String, total_cables: int, par_seconds: float) -> void:
	_level_index = maxi(level_index, 1)
	_level_name = level_name
	_total_cables = maxi(total_cables, 0)
	_par_seconds = maxf(par_seconds, 1.0)
	_elapsed = 0.0
	_overload = 0.0
	_voltage = 0
	_shield_left = 0.0
	_done = 0
	_hint_text = ""
	_fail_reason = ""
	_fail_can_revive = false
	_ad_visible = false
	_paused = false
	_fail_visible = false
	_celebrate_visible = false
	_refresh_texts()
	_refresh_chrome()
	set_timer(0.0)
	set_overload(0.0)
	set_voltage(0)
	set_shield(0.0)
	set_hint("")
	set_ad_buttons(false, false)
	set_connected(0, _total_cables)
	fail_overlay.visible = false
	pause_overlay.visible = false
	ad_overlay.visible = false
	celebrate_root.visible = false
	flash.visible = false
	toast_panel.visible = false
	cutter_button.disabled = true
	spray_button.disabled = true
	cutter_badge.visible = false
	spray_badge.visible = false
	pause_button.disabled = false
	vignette.modulate = Color(UiKit.COLOR_DANGER.r, UiKit.COLOR_DANGER.g,
		UiKit.COLOR_DANGER.b, 0.0)


func set_timer(seconds: float) -> void:
	_elapsed = maxf(seconds, 0.0)
	time_label.text = _format_time(_elapsed)
	var over_par: bool = _elapsed > _par_seconds
	time_label.add_theme_color_override("font_color",
		UiKit.COLOR_DANGER if over_par else UiKit.COLOR_TEXT)


func set_connected(done: int, total: int) -> void:
	_done = clampi(done, 0, maxi(total, 0))
	_refresh_connected()


func set_overload(value: float) -> void:
	_overload = clampf(value, 0.0, 1.0)
	overload_bar.set_overload(_overload)
	var percent: int = int(roundf(_overload * 100.0))
	overload_label.text = Loc.t("hud.overload", {"pct": percent})
	var heat: float = clampf((_overload - 0.35) / 0.65, 0.0, 1.0)
	overload_label.add_theme_color_override("font_color",
		UiKit.COLOR_ACCENT.lerp(UiKit.COLOR_DANGER, heat))
	var danger: float = clampf((_overload - VIGNETTE_START) / (1.0 - VIGNETTE_START), 0.0, 1.0)
	vignette.modulate = Color(UiKit.COLOR_DANGER.r, UiKit.COLOR_DANGER.g,
		UiKit.COLOR_DANGER.b, danger * 0.40)


func set_voltage(volts: int) -> void:
	_voltage = maxi(volts, 0)
	voltage_label.text = Loc.t("hud.voltage", {"v": _voltage})
	var color: Color = UiKit.COLOR_TEXT
	if _voltage >= VOLTAGE_DANGER:
		color = UiKit.COLOR_DANGER
	elif _voltage >= VOLTAGE_WARM:
		color = UiKit.COLOR_ACCENT
	voltage_label.add_theme_color_override("font_color", color)


func set_shield(seconds_left: float) -> void:
	_shield_left = maxf(seconds_left, 0.0)
	var active: bool = _shield_left > 0.0
	shield_pill.visible = active and not _overlay_open()
	if active:
		shield_label.text = Loc.t("hud.shield", {"sec": "%.1f" % _shield_left})


func set_hint(text: String) -> void:
	_hint_text = text
	var has_text: bool = not text.is_empty()
	hint_panel.visible = has_text and not _overlay_open()
	if not has_text:
		return
	hint_label.text = text
	hint_panel.modulate.a = 0.0
	var tween: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(hint_panel, "modulate:a", 1.0, 0.30) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Alt ortada kısa pop mesaj. Boş metin = temizle (game.gd _clear_toast kullanır).
func toast(text: String) -> void:
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	if text.is_empty():
		toast_panel.visible = false
		return
	toast_label.text = text
	toast_panel.visible = true
	toast_panel.modulate = Color(1.0, 1.0, 1.0, 1.0)
	toast_panel.pivot_offset = toast_panel.size * 0.5
	toast_panel.scale = Vector2(0.96, 0.96)
	_toast_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_toast_tween.tween_property(toast_panel, "scale", Vector2.ONE, 0.20) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_toast_tween.parallel().tween_property(toast_panel, "modulate:a", 1.0, 0.20)
	_toast_tween.tween_interval(TOAST_HOLD_SECONDS)
	_toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.35) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_toast_tween.tween_callback(_hide_toast)


func set_ad_buttons(can_cutter: bool, can_spray: bool) -> void:
	if can_cutter == _can_cutter and can_spray == _can_spray:
		return
	_can_cutter = can_cutter
	_can_spray = can_spray
	_apply_ad_state(cutter_button, cutter_badge, can_cutter)
	_apply_ad_state(spray_button, spray_badge, can_spray)


func show_fail(reason: String, can_revive: bool) -> void:
	_fail_reason = reason
	_fail_can_revive = can_revive
	_fail_visible = true
	_refresh_fail_texts()
	_refresh_chrome()
	revive_button.visible = can_revive
	fail_overlay.visible = true
	fail_overlay.modulate.a = 0.0
	var tween: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(fail_overlay, "modulate:a", 1.0, 0.25) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func hide_fail() -> void:
	_fail_visible = false
	fail_overlay.visible = false
	_refresh_chrome()


func show_ad_overlay(visible_now: bool) -> void:
	_ad_visible = visible_now
	ad_overlay.visible = visible_now
	_refresh_chrome()
	if visible_now:
		_refresh_ad_texts()


func show_pause(visible_now: bool) -> void:
	_paused = visible_now
	pause_overlay.visible = visible_now
	pause_button.disabled = visible_now
	_refresh_chrome()
	if visible_now:
		_refresh_pause_texts()


## Bölüm sonu kutlaması: sakin parıltı + yumuşak yıldızlar (agresif flaş yok).
func celebrate(stars: int) -> void:
	var earned: int = clampi(stars, 0, STAR_COUNT)
	_celebrate_visible = true
	_refresh_chrome()
	flash.visible = true
	flash.modulate = Color(UiKit.COLOR_ACCENT.r, UiKit.COLOR_ACCENT.g,
		UiKit.COLOR_ACCENT.b, 0.0)
	var flash_tween: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	flash_tween.tween_property(flash, "modulate:a", 0.10, 0.20) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.45) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	flash_tween.tween_callback(_hide_flash)
	celebrate_root.visible = true
	celebrate_title.text = Loc.t("result.title")
	celebrate_title.visible = true
	celebrate_title.modulate.a = 0.0
	celebrate_title.pivot_offset = celebrate_title.size * 0.5
	celebrate_title.scale = Vector2(0.96, 0.96)
	var title_tween: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	title_tween.tween_property(celebrate_title, "modulate:a", 1.0, 0.35) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	title_tween.parallel().tween_property(celebrate_title, "scale", Vector2.ONE, 0.45) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for index: int in _celebrate_stars.size():
		var star: Control = _celebrate_stars[index]
		var lit: bool = index < earned
		star.visible = true
		if star.has_method(&"set_lit"):
			star.call(&"set_lit", lit)
		star.modulate.a = 0.0
		star.pivot_offset = star.size * 0.5
		star.scale = Vector2(0.82, 0.82) if lit else Vector2.ONE
		var star_tween: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		star_tween.tween_interval(0.12 * float(index))
		star_tween.tween_property(star, "modulate:a", 1.0, 0.32) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		if lit:
			star_tween.parallel().tween_property(star, "scale", Vector2.ONE, 0.48) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_time += delta
	if _shield_left > 0.0:
		shield_label.modulate.a = 0.72 + 0.28 * absf(sin(_time * SHIELD_PULSE_SPEED))
	if _ad_visible:
		ad_label.modulate.a = 0.55 + 0.45 * absf(sin(_time * AD_PULSE_SPEED))


## Overlay açıkken alt eylem şeridi ve pill'ler gizlenir (temiz görünüm).
func _overlay_open() -> bool:
	return _fail_visible or _paused or _ad_visible or _celebrate_visible


func _refresh_chrome() -> void:
	var chrome_visible: bool = not _overlay_open()
	bottom_bar.visible = chrome_visible
	hint_panel.visible = chrome_visible and not _hint_text.is_empty()
	shield_pill.visible = chrome_visible and _shield_left > 0.0


# --- metin / görsel yenileme --------------------------------------------

func _refresh_texts() -> void:
	_refresh_level_label()
	_refresh_connected()
	_refresh_overload_text()
	set_voltage(_voltage)
	set_shield(_shield_left)
	if not _hint_text.is_empty():
		hint_label.text = _hint_text
	_refresh_ad_texts()
	_refresh_fail_texts()
	_refresh_pause_texts()
	_apply_ad_state(cutter_button, cutter_badge, _can_cutter)
	_apply_ad_state(spray_button, spray_badge, _can_spray)


func _refresh_level_label() -> void:
	var level_name: String = _level_name
	var key: String = "level.%d.name" % _level_index
	if Loc.has(key):
		level_name = Loc.t(key)
	level_label.text = "%s · %s" % [
		Loc.t("hud.level", {"n": "%02d" % _level_index}),
		level_name,
	]


func _refresh_connected() -> void:
	connected_label.text = Loc.t("hud.connected_label", {
		"done": _done,
		"total": _total_cables,
	})
	var complete: bool = _total_cables > 0 and _done >= _total_cables
	connected_label.add_theme_color_override("font_color",
		UiKit.COLOR_ACCENT if complete else UiKit.COLOR_PRIMARY)


func _refresh_overload_text() -> void:
	overload_label.text = Loc.t("hud.overload",
		{"pct": int(roundf(_overload * 100.0))})


func _refresh_ad_texts() -> void:
	cutter_badge.text = Loc.t("hud.ad_badge")
	spray_badge.text = Loc.t("hud.ad_badge")
	cutter_label.text = Loc.t("hud.cutter_short")
	spray_label.text = Loc.t("hud.spray_short")
	ad_tag.text = Loc.t("hud.ad_badge")
	ad_label.text = Loc.t("ad.loading")


func _refresh_fail_texts() -> void:
	fail_title.text = Loc.t("fail.title")
	# Yerelleştirme kuralı: görünen metin Loc'tan gelir (CLAUDE §9.1). Çağıran
	# Türkçe sabit gönderse bile TR/EN doğru kalır; ham metin yalnızca yedektir.
	fail_reason.text = Loc.t("fail.reason") if Loc.has("fail.reason") else _fail_reason
	revive_button.text = Loc.t("fail.revive")
	retry_button.text = Loc.t("fail.retry")
	fail_menu_button.text = Loc.t("fail.menu")


func _refresh_pause_texts() -> void:
	pause_title.text = Loc.t("pause.title")
	resume_button.text = Loc.t("pause.resume")
	menu_button.text = Loc.t("pause.menu")


func _on_language_changed(_locale: String) -> void:
	_refresh_texts()


# --- kurulum / animasyon yardımcıları ------------------------------------

func _wire_buttons() -> void:
	pause_button.pressed.connect(_on_pause_pressed)
	resume_button.pressed.connect(_on_resume_pressed)
	retry_button.pressed.connect(_on_retry_pressed)
	fail_menu_button.pressed.connect(_on_menu_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	cutter_button.pressed.connect(_on_cutter_pressed)
	spray_button.pressed.connect(_on_spray_pressed)
	revive_button.pressed.connect(_on_revive_pressed)


func _wire_icons() -> void:
	pause_button.expand_icon = true
	pause_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Icons.apply(pause_button, "lucide/pause", UiKit.COLOR_TEXT, 38)
	cutter_button.expand_icon = true
	cutter_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Icons.apply(cutter_button, "lucide/zap", UiKit.COLOR_ACCENT, 44)
	spray_button.expand_icon = true
	spray_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Icons.apply(spray_button, "lucide/shield", UiKit.COLOR_ACCENT, 42)
	revive_button.expand_icon = true
	Icons.apply(revive_button, "lucide/heart", UiKit.COLOR_ON_PRIMARY, 36)
	retry_button.expand_icon = true
	Icons.apply(retry_button, "lucide/play", UiKit.COLOR_ON_ACCENT, 34)
	fail_menu_button.expand_icon = true
	Icons.apply(fail_menu_button, "lucide/arrow-left", UiKit.COLOR_TEXT, 30)
	resume_button.expand_icon = true
	Icons.apply(resume_button, "lucide/play", UiKit.COLOR_ON_PRIMARY, 34)
	menu_button.expand_icon = true
	Icons.apply(menu_button, "lucide/arrow-left", UiKit.COLOR_TEXT, 30)


func _reset_visuals() -> void:
	hint_panel.visible = false
	toast_panel.visible = false
	shield_pill.visible = false
	cutter_badge.visible = false
	spray_badge.visible = false
	fail_overlay.visible = false
	pause_overlay.visible = false
	ad_overlay.visible = false
	celebrate_root.visible = false
	flash.visible = false
	vignette.modulate = Color(UiKit.COLOR_DANGER.r, UiKit.COLOR_DANGER.g,
		UiKit.COLOR_DANGER.b, 0.0)


func _center_pivots() -> void:
	toast_panel.pivot_offset = toast_panel.size * 0.5
	hint_panel.pivot_offset = hint_panel.size * 0.5
	for star: Control in _celebrate_stars:
		star.pivot_offset = star.size * 0.5


func _apply_ad_state(button: Button, badge: Label, available: bool) -> void:
	button.disabled = not available
	button.modulate = Color(1.0, 1.0, 1.0, 1.0 if available else 0.5)
	badge.visible = available
	badge.modulate = Color(1.0, 1.0, 1.0, 1.0 if available else 0.6)
	var caption: Label = cutter_label if button == cutter_button else spray_label
	caption.modulate = Color(1.0, 1.0, 1.0, 1.0 if available else 0.55)


func _format_time(seconds: float) -> String:
	var total: int = maxi(0, int(ceilf(seconds)))
	var minutes: int = floori(float(total) / 60.0)
	var rest: int = total - minutes * 60
	return "%02d:%02d" % [minutes, rest]


func _hide_toast() -> void:
	toast_panel.visible = false


func _hide_flash() -> void:
	flash.visible = false


# --- buton sinyalleri ----------------------------------------------------

func _on_cutter_pressed() -> void:
	if cutter_button.disabled:
		return
	UiKit.tap()
	cutter_pressed.emit()


func _on_spray_pressed() -> void:
	if spray_button.disabled:
		return
	UiKit.tap()
	spray_pressed.emit()


func _on_revive_pressed() -> void:
	UiKit.tap()
	revive_pressed.emit()


func _on_retry_pressed() -> void:
	UiKit.tap()
	retry_pressed.emit()


func _on_menu_pressed() -> void:
	UiKit.tap()
	menu_pressed.emit()


func _on_pause_pressed() -> void:
	UiKit.tap()
	pause_pressed.emit()


func _on_resume_pressed() -> void:
	UiKit.tap()
	resume_pressed.emit()
