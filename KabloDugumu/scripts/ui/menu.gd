extends Control

## Ana menü: oyna / bölümler / ayarlar. Ayarlar paneli bu sahnenin içinde yaşar.
## Sahne geçişleri yalnızca GameManager üzerinden yapılır (CLAUDE.md §4).

const TOTAL_STARS: int = 36
const RESET_CONFIRM_SECONDS: float = 3.0
const RESET_FEEDBACK_SECONDS: float = 1.4

## data/theme.json paletinin kopyası (stylebox'lar tema üreticisinden gelir).
const COLOR_ON_PRIMARY: Color = Color(0.012, 0.141, 0.125, 1.0)
const COLOR_ON_ACCENT: Color = Color(0.169, 0.129, 0.000, 1.0)

@onready var play_button: Button = %PlayButton
@onready var levels_button: Button = %LevelsButton
@onready var settings_button: Button = %SettingsButton
@onready var total_stars_label: Label = %TotalStars
@onready var version_label: Label = %Version
@onready var settings_panel: Control = %SettingsPanel
@onready var sound_button: Button = %SoundButton
@onready var reset_button: Button = %ResetButton
@onready var close_button: Button = %CloseButton

var _muted: bool = false
var _reset_armed: bool = false
var _reset_timer: SceneTreeTimer = null


func _ready() -> void:
	version_label.text = "v%s" % str(
		ProjectSettings.get_setting("application/config/version", "0.0.0"))
	_wire_buttons()
	_wire_icons()
	settings_panel.visible = false
	sound_button.text = "Ses: AÇIK"
	reset_button.text = "İlerlemeyi Sıfırla"
	_refresh_progress()
	GameManager.back_requested.connect(_on_back)


func _wire_buttons() -> void:
	play_button.pressed.connect(_on_play)
	levels_button.pressed.connect(_on_levels)
	settings_button.pressed.connect(_on_settings)
	sound_button.pressed.connect(_on_sound)
	reset_button.pressed.connect(_on_reset)
	close_button.pressed.connect(_on_close)


func _wire_icons() -> void:
	play_button.expand_icon = true
	Icons.apply(play_button, "lucide/play", COLOR_ON_PRIMARY, 48)
	levels_button.expand_icon = true
	Icons.apply(levels_button, "lucide/star", COLOR_ON_ACCENT, 40)
	settings_button.expand_icon = true
	Icons.apply(settings_button, "lucide/settings", COLOR_ON_ACCENT, 40)
	sound_button.expand_icon = true
	Icons.apply(sound_button, "lucide/volume-2", COLOR_ON_ACCENT, 36)
	reset_button.expand_icon = true
	Icons.apply(reset_button, "lucide/x", COLOR_ON_ACCENT, 36)
	close_button.expand_icon = true
	Icons.apply(close_button, "lucide/check", COLOR_ON_PRIMARY, 40)


func _refresh_progress() -> void:
	var profile: PlayerProfile = GameManager.profile
	var stars: int = 0 if profile == null else profile.total_stars()
	var next_level: int = 1 if profile == null else profile.highest_unlocked()
	total_stars_label.text = "%d / %d" % [stars, TOTAL_STARS]
	play_button.text = "OYNA · BÖLÜM %02d" % next_level


func _on_play() -> void:
	AudioService.play("ui_tap")
	var profile: PlayerProfile = GameManager.profile
	var level: int = 1 if profile == null else profile.highest_unlocked()
	GameManager.start_level(level)


func _on_levels() -> void:
	AudioService.play("ui_tap")
	GameManager.goto_levels()


func _on_settings() -> void:
	AudioService.play("ui_tap")
	settings_panel.visible = true
	_refresh_progress()


func _on_sound() -> void:
	_muted = not _muted
	sound_button.text = "Ses: KAPALI" if _muted else "Ses: AÇIK"
	# AudioService.set_muted sözleşmede var; paralel geliştirmede henüz yoksa
	# oyunu kırmamak için çağrı dinamik yapılır.
	if AudioService.has_method(&"set_muted"):
		AudioService.call(&"set_muted", _muted)
	if not _muted:
		AudioService.play("ui_tap")


## İki adımlı onay: ilk dokunuş silahlandırır, ikincisi sıfırlar.
func _on_reset() -> void:
	if not _reset_armed:
		AudioService.play("ui_tap")
		_reset_armed = true
		reset_button.text = "EMİN MİSİN? TEKRAR BAS"
		_reset_timer = get_tree().create_timer(RESET_CONFIRM_SECONDS)
		_reset_timer.timeout.connect(_on_reset_timeout)
		return
	_reset_armed = false
	var profile: PlayerProfile = GameManager.profile
	if profile != null:
		profile.best_stars.clear()
		profile.best_times.clear()
		profile.save()
	_refresh_progress()
	reset_button.text = "İlerleme Sıfırlandı"
	var tween: Tween = create_tween()
	tween.tween_interval(RESET_FEEDBACK_SECONDS)
	tween.tween_callback(_restore_reset_button)


func _on_reset_timeout() -> void:
	if not _reset_armed:
		return
	_reset_armed = false
	reset_button.text = "İlerlemeyi Sıfırla"


func _restore_reset_button() -> void:
	reset_button.text = "İlerlemeyi Sıfırla"


func _on_close() -> void:
	AudioService.play("ui_tap")
	settings_panel.visible = false


func _on_back() -> void:
	get_tree().quit()
