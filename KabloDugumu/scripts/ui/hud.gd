class_name GameHUD
extends CanvasLayer

## Oyun içi HUD + overlay'ler (fail, pause, reklam, kutlama).
## Sadece gösterir; karar mantığı gameplay'dedir (game.gd bu API'yi çağırır).
## İmzalar ARCHITECTURE §7 — DEĞİŞMEZ.
##
## Duraklatma notu: kök CanvasLayer ve tüm overlay'ler PROCESS_MODE_ALWAYS,
## tween'ler TWEEN_PAUSE_PROCESS — aksi hâlde get_tree().paused iken donar (GOTCHAS #5).

signal cutter_pressed()
signal spray_pressed()
signal revive_pressed()
signal retry_pressed()
signal menu_pressed()
signal pause_pressed()
signal resume_pressed()

## data/theme.json paletinin UI tarafı kopyası (tek kaynak tema dosyası;
## buradaki değerler StyleBox üretiminde kullanılamadığı için koda gömülü).
const COLOR_TEXT: Color = Color(0.913, 0.949, 0.965, 1.0)
const COLOR_MUTED: Color = Color(0.561, 0.639, 0.690, 1.0)
const COLOR_PRIMARY: Color = Color(0.204, 0.906, 0.769, 1.0)
const COLOR_ACCENT: Color = Color(1.000, 0.788, 0.290, 1.0)
const COLOR_DANGER: Color = Color(1.000, 0.333, 0.400, 1.0)
const COLOR_SHIELD: Color = Color(0.302, 0.820, 1.000, 1.0)
const COLOR_ON_PRIMARY: Color = Color(0.012, 0.141, 0.125, 1.0)
const COLOR_ON_ACCENT: Color = Color(0.169, 0.129, 0.000, 1.0)

const ICON_SIZE: int = 46
const TOAST_HOLD_SECONDS: float = 1.8
const VIGNETTE_START: float = 0.65
const SHIELD_PULSE_SPEED: float = 5.0
const STAR_COUNT: int = 3

@onready var level_label: Label = %LevelLabel
@onready var time_label: Label = %TimeLabel
@onready var connected_label: Label = %ConnectedLabel
@onready var pause_button: Button = %PauseButton
@onready var overload_label: Label = %OverloadLabel
@onready var overload_bar: OverloadBar = %OverloadBar
@onready var volt_gauge: VoltGauge = %VoltGauge
@onready var voltage_label: Label = %VoltageLabel
@onready var shield_label: Label = %ShieldLabel
@onready var hint_label: Label = %HintLabel
@onready var toast_label: Label = %ToastLabel
@onready var cutter_button: Button = %CutterButton
@onready var cutter_badge: Label = %CutterBadge
@onready var spray_button: Button = %SprayButton
@onready var spray_badge: Label = %SprayBadge
@onready var vignette: TextureRect = %Vignette
@onready var flash: ColorRect = %Flash
@onready var fail_overlay: Control = %FailOverlay
@onready var fail_reason: Label = %FailReason
@onready var revive_button: Button = %ReviveButton
@onready var retry_button: Button = %RetryButton
@onready var fail_menu_button: Button = %FailMenuButton
@onready var pause_overlay: Control = %PauseOverlay
@onready var resume_button: Button = %ResumeButton
@onready var menu_button: Button = %MenuButton
@onready var ad_overlay: Control = %AdOverlay
@onready var celebrate_root: Control = %Celebrate
@onready var celebrate_star_1: TextureRect = %CelebrateStar1
@onready var celebrate_star_2: TextureRect = %CelebrateStar2
@onready var celebrate_star_3: TextureRect = %CelebrateStar3

var _total_cables: int = 0
var _par_seconds: float = 60.0
var _elapsed: float = 0.0
var _overload: float = 0.0
var _shield_left: float = 0.0
var _time: float = 0.0
var _celebrate_stars: Array[TextureRect] = []
var _toast_tween: Tween = null
var _float_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_celebrate_stars.append(celebrate_star_1)
	_celebrate_stars.append(celebrate_star_2)
	_celebrate_stars.append(celebrate_star_3)
	_wire_buttons()
	_wire_icons()
	_reset_visuals()
	await get_tree().process_frame
	_center_pivots()


## Görsel durum sıfırlama: yeni bölüm kurulurken game.gd setup() çağırır.
func setup(level_index: int, level_name: String, total_cables: int, par_seconds: float) -> void:
	_total_cables = maxi(total_cables, 0)
	_par_seconds = maxf(par_seconds, 1.0)
	_elapsed = 0.0
	_overload = 0.0
	_shield_left = 0.0
	level_label.text = "BÖLÜM %02d · %s" % [level_index, level_name.to_upper()]
	time_label.text = _format_time(0.0)
	time_label.add_theme_color_override("font_color", COLOR_TEXT)
	connected_label.text = "BAĞLI 0/%d" % _total_cables
	connected_label.add_theme_color_override("font_color", COLOR_PRIMARY)
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
	vignette.modulate = Color(1.0, 0.18, 0.25, 0.0)


func set_timer(seconds: float) -> void:
	_elapsed = maxf(seconds, 0.0)
	time_label.text = _format_time(_elapsed)
	var over_par: bool = _elapsed > _par_seconds
	time_label.add_theme_color_override("font_color", COLOR_DANGER if over_par else COLOR_TEXT)


func set_connected(done: int, total: int) -> void:
	var safe_total: int = maxi(total, 0)
	var safe_done: int = clampi(done, 0, safe_total)
	connected_label.text = "BAĞLI %d/%d" % [safe_done, safe_total]
	var complete: bool = safe_total > 0 and safe_done >= safe_total
	connected_label.add_theme_color_override("font_color",
		COLOR_PRIMARY if not complete else COLOR_ACCENT)


func set_overload(value: float) -> void:
	_overload = clampf(value, 0.0, 1.0)
	overload_bar.set_overload(_overload)
	var percent: int = int(roundf(_overload * 100.0))
	overload_label.text = "AŞIRI YÜK %%%d" % percent
	var heat: float = clampf((_overload - 0.35) / 0.65, 0.0, 1.0)
	overload_label.add_theme_color_override("font_color", COLOR_ACCENT.lerp(COLOR_DANGER, heat))
	var danger: float = clampf((_overload - VIGNETTE_START) / (1.0 - VIGNETTE_START), 0.0, 1.0)
	vignette.modulate = Color(1.0, 0.18, 0.25, danger * 0.9)


func set_voltage(volts: int) -> void:
	volt_gauge.set_voltage(volts)
	voltage_label.text = "%d V" % volts


func set_shield(seconds_left: float) -> void:
	_shield_left = maxf(seconds_left, 0.0)
	var active: bool = _shield_left > 0.0
	shield_label.visible = active
	if active:
		shield_label.text = "KALKAN %0.1f sn" % _shield_left
		shield_label.modulate.a = 1.0


func set_hint(text: String) -> void:
	var has_text: bool = not text.is_empty()
	hint_label.visible = has_text
	if not has_text:
		return
	if hint_label.text == text:
		return
	hint_label.text = text
	hint_label.modulate.a = 0.0
	var tween: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(hint_label, "modulate:a", 1.0, 0.25)


## Alt ortada 1.8 sn'lik pop mesaj (ödül, uyarı, ipucu).
func toast(text: String) -> void:
	if text.is_empty():
		return
	toast_label.text = text
	toast_label.visible = true
	toast_label.pivot_offset = toast_label.size * 0.5
	toast_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	toast_label.scale = Vector2(0.82, 0.82)
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_toast_tween.tween_property(toast_label, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.tween_interval(TOAST_HOLD_SECONDS)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.35)
	_toast_tween.tween_callback(_hide_toast)


func set_ad_buttons(can_cutter: bool, can_spray: bool) -> void:
	_apply_ad_state(cutter_button, cutter_badge, can_cutter)
	_apply_ad_state(spray_button, spray_badge, can_spray)


func show_fail(reason: String, can_revive: bool) -> void:
	fail_reason.text = reason
	revive_button.visible = can_revive
	fail_overlay.visible = true
	fail_overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(fail_overlay, "modulate:a", 1.0, 0.22)


func hide_fail() -> void:
	fail_overlay.visible = false


func show_ad_overlay(visible_now: bool) -> void:
	ad_overlay.visible = visible_now


func show_pause(visible_now: bool) -> void:
	pause_overlay.visible = visible_now
	pause_button.disabled = visible_now


## Bölüm sonu kutlaması: flaş + sırayla patlayan yıldızlar.
## Sahne geçişinden hemen önce çağrılır; animasyon kısadır (≈0.5 sn).
func celebrate(stars: int) -> void:
	var earned: int = clampi(stars, 0, STAR_COUNT)
	flash.visible = true
	flash.modulate = Color(1.0, 1.0, 1.0, 0.0)
	if _float_tween != null and _float_tween.is_valid():
		_float_tween.kill()
	_float_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_float_tween.tween_property(flash, "modulate:a", 0.55, 0.10)
	_float_tween.tween_property(flash, "modulate:a", 0.0, 0.40)
	_float_tween.tween_callback(_hide_flash)
	celebrate_root.visible = true
	for index: int in _celebrate_stars.size():
		var star: TextureRect = _celebrate_stars[index]
		var lit: bool = index < earned
		star.visible = true
		star.modulate = Color(1.0, 0.788, 0.290, 0.0) if lit \
			else Color(0.561, 0.639, 0.690, 0.0)
		star.scale = Vector2(1.7, 1.7) if lit else Vector2.ONE
		var tween: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_interval(0.10 * float(index))
		tween.tween_property(star, "modulate:a", 1.0, 0.10)
		if lit:
			tween.parallel().tween_property(star, "scale", Vector2.ONE, 0.30) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_time += delta
	if _shield_left > 0.0:
		shield_label.modulate.a = 0.55 + 0.45 * absf(sin(_time * SHIELD_PULSE_SPEED))


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
	Icons.apply(pause_button, "lucide/pause", COLOR_ON_PRIMARY, 44)
	cutter_button.expand_icon = true
	Icons.apply(cutter_button, "lucide/zap", COLOR_ON_ACCENT, ICON_SIZE)
	spray_button.expand_icon = true
	Icons.apply(spray_button, "lucide/shield", COLOR_ON_ACCENT, ICON_SIZE)
	revive_button.expand_icon = true
	Icons.apply(revive_button, "lucide/heart", COLOR_ON_ACCENT, 40)
	retry_button.expand_icon = true
	Icons.apply(retry_button, "lucide/play", COLOR_ON_PRIMARY, 40)
	resume_button.expand_icon = true
	Icons.apply(resume_button, "lucide/play", COLOR_ON_PRIMARY, 40)
	fail_menu_button.expand_icon = true
	Icons.apply(fail_menu_button, "lucide/arrow-left", COLOR_ON_ACCENT, 36)
	menu_button.expand_icon = true
	Icons.apply(menu_button, "lucide/arrow-left", COLOR_ON_ACCENT, 36)


func _reset_visuals() -> void:
	toast_label.visible = false
	hint_label.visible = false
	shield_label.visible = false
	fail_overlay.visible = false
	pause_overlay.visible = false
	ad_overlay.visible = false
	celebrate_root.visible = false
	flash.visible = false
	vignette.modulate = Color(1.0, 0.18, 0.25, 0.0)
	_apply_ad_state(cutter_button, cutter_badge, false)
	_apply_ad_state(spray_button, spray_badge, false)


func _center_pivots() -> void:
	toast_label.pivot_offset = toast_label.size * 0.5
	for star: TextureRect in _celebrate_stars:
		star.pivot_offset = star.size * 0.5


func _apply_ad_state(button: Button, badge: Label, available: bool) -> void:
	button.disabled = not available
	var alpha: float = 1.0 if available else 0.45
	button.modulate = Color(1.0, 1.0, 1.0, alpha)
	badge.modulate = Color(1.0, 1.0, 1.0, alpha)


func _format_time(seconds: float) -> String:
	var total: int = maxi(0, int(ceilf(seconds)))
	var minutes: int = floori(float(total) / 60.0)
	var rest: int = total - minutes * 60
	return "%02d:%02d" % [minutes, rest]


func _hide_toast() -> void:
	toast_label.visible = false


func _hide_flash() -> void:
	flash.visible = false


func _on_cutter_pressed() -> void:
	if cutter_button.disabled:
		return
	AudioService.play("ui_tap")
	cutter_pressed.emit()


func _on_spray_pressed() -> void:
	if spray_button.disabled:
		return
	AudioService.play("ui_tap")
	spray_pressed.emit()


func _on_revive_pressed() -> void:
	AudioService.play("ui_tap")
	revive_pressed.emit()


func _on_retry_pressed() -> void:
	AudioService.play("ui_tap")
	retry_pressed.emit()


func _on_menu_pressed() -> void:
	AudioService.play("ui_tap")
	menu_pressed.emit()


func _on_pause_pressed() -> void:
	AudioService.play("ui_tap")
	pause_pressed.emit()


func _on_resume_pressed() -> void:
	AudioService.play("ui_tap")
	resume_pressed.emit()
