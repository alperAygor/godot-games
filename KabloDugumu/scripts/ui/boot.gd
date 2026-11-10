extends Control

## Açılış: koyu splash + kısa animasyon, 0.9 sn sonra menü.
## Bekleme "flash" hissini önler; süreyi 0.4 sn altına düşürmeyin (PROJECT_SPEC §9).

const HOLD_SECONDS: float = 0.9
const BAR_FILL_SECONDS: float = 0.7
const TITLE_FADE_SECONDS: float = 0.35

@onready var logo: TextureRect = %BootLogo
@onready var title_label: Label = %BootTitle
@onready var subtitle_label: Label = %BootSubtitle
@onready var power_bar: ProgressBar = %PowerBar

var _navigated: bool = false


func _ready() -> void:
	_play_intro()
	await get_tree().create_timer(HOLD_SECONDS).timeout
	_go_menu()


func _play_intro() -> void:
	logo.modulate.a = 0.0
	title_label.modulate.a = 0.0
	subtitle_label.modulate.a = 0.0
	power_bar.value = 0.0
	var tween: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(logo, "modulate:a", 1.0, 0.25)
	tween.tween_property(title_label, "modulate:a", 1.0, TITLE_FADE_SECONDS).set_delay(0.08)
	tween.tween_property(subtitle_label, "modulate:a", 1.0, TITLE_FADE_SECONDS).set_delay(0.18)
	tween.tween_property(power_bar, "value", 100.0, BAR_FILL_SECONDS).set_delay(0.15)


func _go_menu() -> void:
	if _navigated:
		return
	_navigated = true
	GameManager.goto_menu()
