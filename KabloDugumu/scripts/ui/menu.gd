extends Control

## Ana menü (v0.2): İngilizce kimlik (CABLE KNOT / CURRENT MASTER), animasyonlu
## arka plan (AmbientBackdrop SubViewport; yoksa animasyonlu circuit fallback),
## küçük ikon-öncelikli butonlar, üst köşede dil değiştirici, yıldız sayacı.
## Ayarlar paneli (dil / ses / sıfırla / krediler) bu sahnenin içinde yaşar.
## Sahne geçişleri YALNIZCA GameManager üzerinden (CLAUDE.md §4).

const AMBIENT_SCENE: String = "res://scenes/AmbientBackdrop.tscn"
const TOTAL_STARS: int = 36
const AMBIENT_FADE: float = 1.2
const AMBIENT_INTENSITY: float = 0.8
const SETTINGS_FADE_SECONDS: float = 0.22
const RESET_FEEDBACK_SECONDS: float = 2.2

@onready var backdrop: Control = %Backdrop
@onready var ambient_host: Control = %AmbientHost
@onready var title_label: Label = %Title
@onready var subtitle_label: Label = %Subtitle
@onready var tagline_label: Label = %Tagline
@onready var local_title_label: Label = %LocalTitle
@onready var stars_label: Label = %TotalStars
@onready var version_label: Label = %Version
@onready var play_button: Button = %PlayButton
@onready var levels_button: Button = %LevelsButton
@onready var settings_button: Button = %SettingsButton
@onready var lang_button: Button = %LangButton
@onready var mute_button: Button = %MuteButton
@onready var settings_panel: Control = %SettingsPanel
@onready var settings_title: Label = %SettingsTitle
@onready var sound_row_label: Label = %SoundRowLabel
@onready var language_row_label: Label = %LanguageRowLabel
@onready var sound_button: Button = %SoundButton
@onready var lang_en_button: Button = %LangEnButton
@onready var lang_tr_button: Button = %LangTrButton
@onready var reset_button: Button = %ResetButton
@onready var reset_confirm_row: Control = %ResetConfirmRow
@onready var confirm_reset_button: Button = %ConfirmResetButton
@onready var cancel_reset_button: Button = %CancelResetButton
@onready var reset_feedback: Label = %ResetFeedback
@onready var credits_label: Label = %CreditsLabel
@onready var close_button: Button = %CloseButton

var _ambient_node: Node = null
var _settings_open: bool = false
var _reset_tween: Tween = null


func _ready() -> void:
	_setup_ambient()
	_wire_buttons()
	_apply_icons()
	settings_panel.visible = false
	reset_confirm_row.visible = false
	reset_feedback.visible = false
	_apply_texts()
	_refresh_progress()
	_refresh_settings()
	Loc.language_changed.connect(_on_language_changed)
	GameManager.back_requested.connect(_on_back)
	_start_ambient()


# --- arka plan -----------------------------------------------------------

## AmbientBackdrop varsa SubViewport ile canlı atölye; yoksa animasyonlu
## circuit fallback (resource varlığına göre güvenli geçiş).
func _setup_ambient() -> void:
	if not ResourceLoader.exists(AMBIENT_SCENE):
		return
	var packed: PackedScene = load(AMBIENT_SCENE) as PackedScene
	if packed == null:
		return
	var instance: Node = packed.instantiate()
	if instance == null:
		return
	var viewport: SubViewport = SubViewport.new()
	viewport.name = "AmbientViewport"
	viewport.size = Vector2i(540, 960)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	viewport.handle_input_locally = false
	var container: SubViewportContainer = SubViewportContainer.new()
	container.name = "AmbientContainer"
	container.stretch = true
	container.stretch_shrink = 2
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.add_child(viewport)
	viewport.add_child(instance)
	ambient_host.add_child(container)
	if instance.has_method(&"set_intensity"):
		instance.call(&"set_intensity", AMBIENT_INTENSITY)
	_ambient_node = instance
	backdrop.visible = false
	backdrop.set_process(false)


func _start_ambient() -> void:
	if AudioService.has_method(&"play_ambient"):
		AudioService.call(&"play_ambient", "ambient_pad", AMBIENT_FADE)


# --- metin ve ikonlar ----------------------------------------------------

func _apply_texts() -> void:
	title_label.text = Loc.t("game.title")
	subtitle_label.text = Loc.t("game.subtitle")
	tagline_label.text = Loc.t("game.tagline")
	local_title_label.text = Loc.t("game.title_local")
	# İngilizce kimlik sabit (CLAUDE.md §9.2); yerelleştirilmiş ad yalnızca TR'de görünür.
	local_title_label.visible = Loc.locale != "en"
	version_label.text = Loc.t("menu.version", {
		"version": str(ProjectSettings.get_setting("application/config/version", "0.0.0")),
	})
	play_button.text = Loc.t("menu.play_short")
	levels_button.text = Loc.t("menu.levels")
	lang_button.text = Loc.locale.to_upper()



	settings_title.text = Loc.t("settings.title")
	sound_row_label.text = Loc.t("settings.sound")
	language_row_label.text = Loc.t("settings.language")
	reset_button.text = Loc.t("menu.reset")
	confirm_reset_button.text = Loc.t("menu.confirm")
	cancel_reset_button.text = Loc.t("menu.cancel")
	close_button.text = Loc.t("menu.close")
	credits_label.text = Loc.t("settings.credits")
	reset_feedback.text = Loc.t("settings.reset_done")
	lang_en_button.text = Loc.t("lang.english")
	lang_tr_button.text = Loc.t("lang.turkish")


func _apply_icons() -> void:
	play_button.expand_icon = true
	Icons.apply(play_button, "lucide/play", UiKit.COLOR_ON_PRIMARY, 44)
	levels_button.expand_icon = true
	Icons.apply(levels_button, "lucide/star", UiKit.COLOR_ON_ACCENT, 36)
	settings_button.expand_icon = true
	settings_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Icons.apply(settings_button, "lucide/settings", UiKit.COLOR_TEXT, 42)
	mute_button.expand_icon = true
	mute_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Icons.apply(mute_button, "lucide/volume-2", UiKit.COLOR_TEXT, 36)
	sound_button.expand_icon = true
	Icons.apply(sound_button, "lucide/volume-2", UiKit.COLOR_TEXT, 36)
	reset_button.expand_icon = true
	Icons.apply(reset_button, "lucide/x", UiKit.COLOR_DANGER, 34)
	confirm_reset_button.expand_icon = true
	Icons.apply(confirm_reset_button, "lucide/check", UiKit.COLOR_ON_PRIMARY, 34)
	cancel_reset_button.expand_icon = true
	Icons.apply(cancel_reset_button, "lucide/arrow-left", UiKit.COLOR_MUTED, 30)
	close_button.expand_icon = true
	Icons.apply(close_button, "lucide/check", UiKit.COLOR_ON_PRIMARY, 34)


func _wire_buttons() -> void:
	play_button.pressed.connect(_on_play)
	levels_button.pressed.connect(_on_levels)
	settings_button.pressed.connect(_on_settings)
	lang_button.pressed.connect(_on_lang_toggle)
	mute_button.pressed.connect(_on_sound)
	sound_button.pressed.connect(_on_sound)
	lang_en_button.pressed.connect(_on_lang_selected.bind("en"))
	lang_tr_button.pressed.connect(_on_lang_selected.bind("tr"))
	reset_button.pressed.connect(_on_reset)
	confirm_reset_button.pressed.connect(_on_confirm_reset)
	cancel_reset_button.pressed.connect(_on_cancel_reset)
	close_button.pressed.connect(_on_close_settings)


func _refresh_progress() -> void:
	var profile: PlayerProfile = GameManager.profile
	var stars: int = 0 if profile == null else profile.total_stars()
	stars_label.text = "%d / %d" % [stars, TOTAL_STARS]
	play_button.text = Loc.t("menu.play_short")


func _refresh_settings() -> void:
	var muted: bool = AudioService.muted
	sound_button.text = "%s · %s" % [
		Loc.t("settings.sound"),
		Loc.t("menu.sound_off") if muted else Loc.t("menu.sound_on"),
	]
	lang_en_button.theme_type_variation = &"AccentButton" if Loc.locale == "en" else &"GhostButton"
	lang_tr_button.theme_type_variation = &"AccentButton" if Loc.locale == "tr" else &"GhostButton"
	reset_button.disabled = _profile_is_empty()
	var mute_color: Color = UiKit.COLOR_MUTED if muted else UiKit.COLOR_TEXT
	mute_button.add_theme_color_override("icon_normal_color", mute_color)
	mute_button.add_theme_color_override("icon_hover_color", mute_color)
	mute_button.add_theme_color_override("icon_pressed_color", mute_color)
	mute_button.modulate = Color(1.0, 1.0, 1.0, 0.65 if muted else 1.0)


func _profile_is_empty() -> bool:
	var profile: PlayerProfile = GameManager.profile
	if profile == null:
		return true
	return profile.best_stars.is_empty() and profile.best_times.is_empty()


# --- ayarlar paneli ------------------------------------------------------

func _on_settings() -> void:
	UiKit.tap()
	_settings_open = true
	settings_panel.visible = true
	settings_panel.modulate.a = 0.0
	reset_confirm_row.visible = false
	reset_feedback.visible = false
	_refresh_settings()
	var tween: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(settings_panel, "modulate:a", 1.0, SETTINGS_FADE_SECONDS) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_close_settings() -> void:
	UiKit.tap()
	_close_settings()


func _close_settings() -> void:
	_settings_open = false
	var tween: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(settings_panel, "modulate:a", 0.0, SETTINGS_FADE_SECONDS) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_hide_settings)


func _hide_settings() -> void:
	if _settings_open:
		return
	settings_panel.visible = false


func _on_lang_toggle() -> void:
	UiKit.tap()
	Loc.toggle_locale()


func _on_lang_selected(code: String) -> void:
	UiKit.tap()
	Loc.set_locale(code)


func _on_sound() -> void:
	var muted: bool = not AudioService.muted
	AudioService.set_muted(muted)
	if not muted:
		UiKit.tap()
	_refresh_settings()


func _on_reset() -> void:
	if reset_button.disabled:
		return
	UiKit.tap()
	reset_confirm_row.visible = true
	reset_feedback.visible = false


func _on_cancel_reset() -> void:
	UiKit.tap()
	reset_confirm_row.visible = false


func _on_confirm_reset() -> void:
	UiKit.tap()
	var profile: PlayerProfile = GameManager.profile
	if profile != null:
		profile.best_stars.clear()
		profile.best_times.clear()
		profile.save()
	reset_confirm_row.visible = false
	reset_feedback.visible = true
	_refresh_progress()
	_refresh_settings()
	if _reset_tween != null and _reset_tween.is_valid():
		_reset_tween.kill()
	_reset_tween = create_tween()
	_reset_tween.tween_interval(RESET_FEEDBACK_SECONDS)
	_reset_tween.tween_callback(_hide_reset_feedback)


func _hide_reset_feedback() -> void:
	reset_feedback.visible = false


# --- eylemler ------------------------------------------------------------

func _on_play() -> void:
	UiKit.tap()
	var profile: PlayerProfile = GameManager.profile
	var level: int = 1 if profile == null else profile.highest_unlocked()
	GameManager.start_level(level)


func _on_levels() -> void:
	UiKit.tap()
	GameManager.goto_levels()


func _on_back() -> void:
	if _settings_open:
		_close_settings()
		return
	get_tree().quit()


func _on_language_changed(_locale: String) -> void:
	_apply_texts()
	_refresh_progress()
	_refresh_settings()


# Menü girişinde alpha animasyonu YOK: sahne geçişi anında tam okunur olmalı
# (QA kareleri ilk 0.1 sn'de alınabiliyor); ASMR hissi ambient backdrop + basış
# animasyonlarından gelir.
