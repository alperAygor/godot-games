class_name Hud
extends CanvasLayer

## HUD yalnızca gösterir: GameController her fizik karesinde 0..100 yüzdeyi
## `set_*` ile iter. Hesap `scripts/core/` sınıflarındadır (ARCHITECTURE §6).
## F7.6b: ince "hap" çubuklar + ikonlar, sağlık/batarya rengi token'dan canlı
## boyanır; düşük bataryada nazik nabız; revive kartı alttan kayarak girer.
## F7.11a: sağlık çubuğu dolgusu yumuşak interpolasyonlu — ama yalnız dolgu
## GÖRSELİ; `CargoHealthBar.value`/`BatteryBar.value` probe için ANINDA hedef
## değerde kalır (flow_probe bunları okur). Hasar anında kalp ikonu "vuruş" yapar.

const MIN_PERCENT: float = 0.0
const MAX_PERCENT: float = 100.0
const LOW_BATTERY: float = 30.0
## Kalp ikonu hasar anında 1.25'e büyür, kısa sürede geri oturur (kırmızı flaş).
const HEART_HIT_SCALE: float = 1.25
const HEART_HIT_SECONDS: float = 0.24
## Bu eşikten küçük düşüşler (küsurat gürültüsü) "vuruş" sayılmaz.
const HIT_EPSILON: float = 0.5
## Dolgu görselinin hedefe yumuşak yakınsama hızı (üs sönümü; tween her karede
## yeniden kurulmaz, allocation yok).
const BAR_SMOOTH_SPEED: float = 10.0

signal revive_accepted()
signal revive_declined()
signal recharge_requested()

@onready var _cargo_bar: ProgressBar = %CargoHealthBar
@onready var _battery_bar: ProgressBar = %BatteryBar
@onready var _cargo_percent: Label = %CargoPercent
@onready var _battery_percent: Label = %BatteryPercent
@onready var _cargo_icon: TextureRect = %CargoIcon
@onready var _battery_icon: TextureRect = %BatteryIcon
@onready var _battery_hap: Control = %BatteryHap
@onready var _revive_panel: Control = %RevivePanel
@onready var _revive_title: Label = %ReviveTitle
@onready var _revive_text: Label = %ReviveText
@onready var _revive_button: Button = %ReviveButton
@onready var _decline_button: Button = %DeclineButton
@onready var _recharge_button: Button = %RechargeButton

var _cargo_fill: StyleBoxFlat = StyleBoxFlat.new()
var _battery_fill: StyleBoxFlat = StyleBoxFlat.new()
## Yerleşik çubuğun dolgusu görünmez yapılır; yumuşak dolgu overlay'de çizilir.
var _empty_fill: StyleBoxEmpty = StyleBoxEmpty.new()
var _cargo_smooth: ProgressBar = null
var _battery_smooth: ProgressBar = null
var _pulse: Tween = null
var _heart_flash: Tween = null
var _last_cargo: float = MAX_PERCENT


func _ready() -> void:
	var radius: int = int(UiTheme.metric("radius_pill", 120.0))
	for fill: StyleBoxFlat in [_cargo_fill, _battery_fill]:
		fill.corner_radius_top_left = radius
		fill.corner_radius_top_right = radius
		fill.corner_radius_bottom_right = radius
		fill.corner_radius_bottom_left = radius
	# Yerleşik `value` dolgusu gizlenir; görünür dolgu overlay'de yumuşak ilerler.
	_cargo_bar.add_theme_stylebox_override("fill", _empty_fill)
	_battery_bar.add_theme_stylebox_override("fill", _empty_fill)
	_cargo_smooth = _make_smooth_overlay(_cargo_fill)
	_battery_smooth = _make_smooth_overlay(_battery_fill)
	_cargo_bar.add_child(_cargo_smooth)
	_battery_bar.add_child(_battery_smooth)
	# İkonlar tek ailede; renk `modulate` ile verilir.
	_cargo_icon.texture = Icons.texture("lucide/heart")
	_battery_icon.texture = Icons.texture("lucide/zap")
	_battery_icon.modulate = UiTheme.color("secondary")
	# Metinler tek yerde (strings.gd); sahne yalnızca yerleşim taşır.
	_revive_title.text = UiStrings.REVIVE_TITLE
	_revive_text.text = UiStrings.REVIVE_TEXT
	_revive_button.text = UiStrings.REVIVE_ACCEPT
	_decline_button.text = UiStrings.REVIVE_DECLINE
	_recharge_button.text = UiStrings.RECHARGE
	_recharge_button.tooltip_text = UiStrings.RECHARGE_HINT
	Icons.apply(_revive_button, "lucide/circle-play", UiTheme.color("on_primary"), 44)
	Icons.apply(_decline_button, "lucide/x", UiTheme.color("on_surface"), 40)
	Icons.apply(_recharge_button, "lucide/zap", UiTheme.color("on_primary"), 40)
	_revive_button.add_theme_constant_override("h_separation", 14)
	_decline_button.add_theme_constant_override("h_separation", 12)
	_recharge_button.add_theme_constant_override("h_separation", 12)
	_revive_panel.visible = false
	_recharge_button.visible = false
	_revive_button.pressed.connect(func() -> void: revive_accepted.emit())
	_decline_button.pressed.connect(func() -> void: revive_declined.emit())
	_recharge_button.pressed.connect(func() -> void: recharge_requested.emit())
	_refresh_colors(MAX_PERCENT, MAX_PERCENT)
	_cargo_smooth.value = MAX_PERCENT
	_battery_smooth.value = MAX_PERCENT


func _process(delta: float) -> void:
	# Yumuşak dolgu: overlay değeri hedefe üs sönümüyle yaklaşır; yerleşik `value`
	# zaten anında hedeftedir (probe doğruluğu). Her karede tween kurulmaz.
	if _cargo_smooth != null and _battery_smooth != null:
		var weight: float = 1.0 - exp(-BAR_SMOOTH_SPEED * delta)
		_cargo_smooth.value = lerpf(_cargo_smooth.value, _cargo_bar.value, weight)
		_battery_smooth.value = lerpf(_battery_smooth.value, _battery_bar.value, weight)


func set_cargo_health(percent: float) -> void:
	var clamped: float = clampf(percent, MIN_PERCENT, MAX_PERCENT)
	_cargo_bar.value = clamped
	_cargo_fill.bg_color = _health_color(clamped)
	# Vuruş flaşı sürerken ikon rengine dokunulmaz; tween rengi kendi yönetir.
	if _heart_flash == null or not _heart_flash.is_valid():
		_cargo_icon.modulate = _cargo_fill.bg_color
	_cargo_percent.text = "%d%%" % int(roundf(clamped))
	if clamped < _last_cargo - HIT_EPSILON:
		_hit_heart()
	_last_cargo = clamped


func set_battery(percent: float) -> void:
	_battery_bar.value = clampf(percent, MIN_PERCENT, MAX_PERCENT)
	_battery_percent.text = "%d%%" % int(roundf(_battery_bar.value))
	var low: bool = _battery_bar.value < LOW_BATTERY
	_battery_fill.bg_color = UiTheme.color("warning") if low else UiTheme.color("primary")
	if low:
		_start_pulse()
	else:
		_stop_pulse()


func set_revive_offered(offered: bool) -> void:
	if offered:
		if not _revive_panel.visible:
			_slide_in(_revive_panel)
	else:
		_revive_panel.visible = false


func set_ad_pending(pending: bool) -> void:
	_revive_button.disabled = pending
	_decline_button.disabled = pending
	_recharge_button.disabled = pending


func set_recharge_available(available: bool) -> void:
	_recharge_button.visible = available


## Sağlık rengi: yeşil -> sarı -> kırmızı yumuşak geçiş (durum renkleri theme'den).
func _health_color(percent: float) -> Color:
	var green: Color = UiTheme.color("success")
	var yellow: Color = UiTheme.color("warning")
	var red: Color = UiTheme.color("danger")
	if percent >= 50.0:
		return green.lerp(yellow, clampf((100.0 - percent) / 50.0, 0.0, 1.0))
	return yellow.lerp(red, clampf((50.0 - percent) / 50.0, 0.0, 1.0))


## Yerleşik çubuğun üstünde, aynı geometriye sahip yumuşak dolgu overlay'i.
func _make_smooth_overlay(fill: StyleBoxFlat) -> ProgressBar:
	var overlay := ProgressBar.new()
	overlay.max_value = MAX_PERCENT
	overlay.value = MAX_PERCENT
	overlay.show_percentage = false
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_theme_stylebox_override("background", _empty_fill)
	overlay.add_theme_stylebox_override("fill", fill)
	return overlay


func _refresh_colors(cargo: float, battery: float) -> void:
	_cargo_fill.bg_color = _health_color(cargo)
	_cargo_icon.modulate = _cargo_fill.bg_color
	_battery_fill.bg_color = UiTheme.color("primary")
	_battery_bar.value = clampf(battery, MIN_PERCENT, MAX_PERCENT)
	_cargo_bar.value = clampf(cargo, MIN_PERCENT, MAX_PERCENT)


## Kalp ikonu "vuruş": 1.25'e büyür, kırmızı flaşla sağlık rengine döner.
func _hit_heart() -> void:
	if _heart_flash != null and _heart_flash.is_valid():
		_heart_flash.kill()
	_cargo_icon.pivot_offset = _cargo_icon.size * 0.5
	_cargo_icon.scale = Vector2.ONE * HEART_HIT_SCALE
	_cargo_icon.modulate = UiTheme.color("danger")
	_heart_flash = _cargo_icon.create_tween()
	_heart_flash.set_parallel(true)
	_heart_flash.tween_property(_cargo_icon, "scale", Vector2.ONE, HEART_HIT_SECONDS) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_heart_flash.tween_property(_cargo_icon, "modulate", _cargo_fill.bg_color, HEART_HIT_SECONDS) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Düşük bataryada nazik nabız: alfa 1.0 <-> 0.45, sonsuz döngü.
func _start_pulse() -> void:
	if _pulse != null and _pulse.is_valid():
		return
	_pulse = _battery_hap.create_tween()
	_pulse.set_loops()
	_pulse.tween_property(_battery_hap, "modulate:a", 0.45, 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse.tween_property(_battery_hap, "modulate:a", 1.0, 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_pulse() -> void:
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	_pulse = null
	_battery_hap.modulate.a = 1.0


## Revive kartı alttan yaylanarak girer (F7.11a: yumuşak yay, TRANS_BACK).
func _slide_in(panel: Control) -> void:
	panel.visible = true
	var base: Vector2 = panel.position
	panel.position = base + Vector2(0.0, 280.0)
	panel.modulate.a = 0.0
	var tween: Tween = panel.create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "position", base, 0.32) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
