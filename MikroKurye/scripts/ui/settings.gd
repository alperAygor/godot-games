extends Control

## Ayarlar: ses aç/kapat. Karar `ProfileData`/`SaveService` içinde; bu ekran
## yalnızca gösterir ve değişikliği servislere iletir (ARCHITECTURE.md §5.6).

const BACK_ICON_SIZE: int = 44

@onready var _sound_toggle: CheckButton = %SoundToggle
@onready var _sound_label: Label = %SoundLabel
@onready var _back_button: Button = %BackButton
@onready var _title_label: Label = %Title
@onready var _hint_label: Label = %Hint


func _ready() -> void:
	GameManager.set_phase(GameManager.Phase.SETTINGS)
	_title_label.text = UiStrings.SETTINGS_TITLE
	_hint_label.text = UiStrings.SETTINGS_HINT
	_sound_label.text = UiStrings.SOUND_LABEL
	_back_button.text = UiStrings.BACK
	Icons.apply(_back_button, "lucide/arrow-left", Color(0.29, 0.20, 0.09), BACK_ICON_SIZE)
	# Kayıtlı ayar başlangıç değeridir; programatik atama `toggled` yaymaz.
	_sound_toggle.button_pressed = SaveService.setting("sound_on")
	_sound_toggle.toggled.connect(_on_sound_toggled)
	_back_button.pressed.connect(_on_back)
	GameManager.back_requested.connect(_on_back)
	UiSfx.bind(self)


func _on_sound_toggled(pressed: bool) -> void:
	SaveService.set_setting("sound_on", pressed)
	AudioService.set_muted(not pressed)


func _on_back() -> void:
	GameManager.goto_scene(&"menu")
