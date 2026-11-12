class_name Hud
extends CanvasLayer

## HUD yalnızca gösterir: GameController her fizik karesinde 0..100 yüzdeyi
## `set_*` ile iter. Hesap `scripts/core/` sınıflarındadır (ARCHITECTURE §6).
## F7.6b: ince "hap" çubuklar + ikonlar, sağlık/batarya rengi token'dan canlı
## boyanır; düşük bataryada nazik nabız; revive kartı alttan kayarak girer.

const MIN_PERCENT: float = 0.0
const MAX_PERCENT: float = 100.0
const LOW_BATTERY: float = 30.0

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
var _pulse: Tween = null


func _ready() -> void:
	var radius: int = int(UiTheme.metric("radius_pill", 120.0))
	for fill: StyleBoxFlat in [_cargo_fill, _battery_fill]:
		fill.corner_radius_top_left = radius
		fill.corner_radius_top_right = radius
		fill.corner_radius_bottom_right = radius
		fill.corner_radius_bottom_left = radius
	_cargo_bar.add_theme_stylebox_override("fill", _cargo_fill)
	_battery_bar.add_theme_stylebox_override("fill", _battery_fill)
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


func set_cargo_health(percent: float) -> void:
	_cargo_bar.value = clampf(percent, MIN_PERCENT, MAX_PERCENT)
	_cargo_fill.bg_color = _health_color(_cargo_bar.value)
	_cargo_icon.modulate = _cargo_fill.bg_color
	_cargo_percent.text = "%d%%" % int(roundf(_cargo_bar.value))


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


func _refresh_colors(cargo: float, battery: float) -> void:
	_cargo_fill.bg_color = _health_color(cargo)
	_cargo_icon.modulate = _cargo_fill.bg_color
	_battery_fill.bg_color = UiTheme.color("primary")
	_battery_bar.value = clampf(battery, MIN_PERCENT, MAX_PERCENT)
	_cargo_bar.value = clampf(cargo, MIN_PERCENT, MAX_PERCENT)


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


## Revive kartı alttan kayarak girer (F7.6b mikro-etkileşim).
func _slide_in(panel: Control) -> void:
	panel.visible = true
	var base: Vector2 = panel.position
	panel.position = base + Vector2(0.0, 280.0)
	panel.modulate.a = 0.0
	var tween: Tween = panel.create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "position", base, 0.28) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
