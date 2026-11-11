extends Control

## Açılış (v0.2): sade splash — logo, İngilizce oyun adı, sürüm.
## 0.6 sn sonra menüye geçer (PROJECT_SPEC §9). Yumuşak fade; sert flaş yok.

const HOLD_SECONDS: float = 0.6
const LOGO_FADE_SECONDS: float = 0.25
const TITLE_FADE_SECONDS: float = 0.30
const AMBIENT_FADE: float = 1.2

@onready var logo: TextureRect = %BootLogo
@onready var title_label: Label = %BootTitle
@onready var subtitle_label: Label = %BootSubtitle
@onready var local_title_label: Label = %BootLocalTitle
@onready var version_label: Label = %BootVersion

var _navigated: bool = false


func _ready() -> void:
	_apply_texts()
	_start_ambient()
	_play_intro()
	await get_tree().create_timer(HOLD_SECONDS, true, false, true).timeout
	_go_menu()


func _apply_texts() -> void:
	title_label.text = Loc.t("game.title")
	subtitle_label.text = Loc.t("game.subtitle")
	local_title_label.text = Loc.t("game.title_local")
	local_title_label.visible = Loc.locale != "en"
	version_label.text = Loc.t("menu.version", {
		"version": str(ProjectSettings.get_setting("application/config/version", "0.0.0")),
	})


func _start_ambient() -> void:
	if AudioService.has_method(&"play_ambient"):
		AudioService.call(&"play_ambient", "ambient_pad", AMBIENT_FADE)


func _play_intro() -> void:
	logo.modulate.a = 0.0
	title_label.modulate.a = 0.0
	subtitle_label.modulate.a = 0.0
	version_label.modulate.a = 0.0
	var tween: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(logo, "modulate:a", 1.0, LOGO_FADE_SECONDS)
	tween.tween_property(title_label, "modulate:a", 1.0, TITLE_FADE_SECONDS).set_delay(0.06)
	tween.tween_property(subtitle_label, "modulate:a", 1.0, TITLE_FADE_SECONDS).set_delay(0.14)
	tween.tween_property(version_label, "modulate:a", 1.0, TITLE_FADE_SECONDS).set_delay(0.20)


func _go_menu() -> void:
	if _navigated:
		return
	_navigated = true
	GameManager.goto_menu()
