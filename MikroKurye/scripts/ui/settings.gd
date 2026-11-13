extends Control

## Ayarlar: ses aç/kapat. Karar `ProfileData`/`SaveService` içinde; bu ekran
## yalnızca gösterir ve değişikliği servislere iletir (ARCHITECTURE.md §5.6).
##
## F7.6b: iOS tarzı toggle (toggle_on/off izleri) + ses ikonu; renk/ölçü
## `UiTheme` (data/theme.json) token'larından okunur.

const BACK_ICON_SIZE: int = 20
const SOUND_ICON_SIZE: float = 24.0
const TOGGLE_ON: String = "res://assets/ui_icons/toggle_on.svg"
const TOGGLE_OFF: String = "res://assets/ui_icons/toggle_off.svg"

@onready var _sound_toggle: CheckButton = %SoundToggle
@onready var _sound_label: Label = %SoundLabel
@onready var _sound_icon: TextureRect = %SoundIcon
@onready var _back_button: Button = %BackButton
@onready var _title_label: Label = %Title
@onready var _hint_label: Label = %Hint


func _ready() -> void:
	GameManager.set_phase(GameManager.Phase.SETTINGS)
	_stylize()
	_title_label.text = UiStrings.SETTINGS_TITLE
	_hint_label.text = UiStrings.SETTINGS_HINT
	_sound_label.text = UiStrings.SOUND_LABEL
	_back_button.text = UiStrings.BACK
	Icons.apply(_back_button, "lucide/arrow-left", UiTheme.color("on_surface"), BACK_ICON_SIZE)
	_back_button.add_theme_constant_override("h_separation", 14)
	_setup_toggle()
	# Kayıtlı ayar başlangıç değeridir; programatik atama `toggled` yaymaz.
	_sound_toggle.button_pressed = SaveService.setting("sound_on")
	_refresh_toggle()
	_sound_toggle.toggled.connect(_on_sound_toggled)
	_back_button.pressed.connect(_on_back)
	GameManager.back_requested.connect(_on_back)
	UiSfx.bind(self)
	UiMotion.fade_in(self)


func _stylize() -> void:
	(%Background as ColorRect).color = UiTheme.color("background")
	_title_label.add_theme_color_override("font_color", UiTheme.color("text"))
	_hint_label.add_theme_color_override("font_color", UiTheme.color("text_muted"))
	_sound_label.add_theme_color_override("font_color", UiTheme.color("text"))
	_sound_icon.texture = Icons.texture("lucide/volume-2")
	_sound_icon.modulate = UiTheme.color("primary_dark")


## iOS tarzı toggle: arka plan/çerçeve yok, yalnız on/off izi + metin.
func _setup_toggle() -> void:
	_sound_toggle.add_theme_icon_override("checked", load(TOGGLE_ON) as Texture2D)
	_sound_toggle.add_theme_icon_override("unchecked", load(TOGGLE_OFF) as Texture2D)
	_sound_toggle.add_theme_icon_override("checked_disabled", load(TOGGLE_OFF) as Texture2D)
	_sound_toggle.add_theme_icon_override("unchecked_disabled", load(TOGGLE_OFF) as Texture2D)
	_sound_toggle.flat = true
	var empty := StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		_sound_toggle.add_theme_stylebox_override(state, empty)
	_sound_toggle.add_theme_color_override("font_color", UiTheme.color("text"))
	_sound_toggle.add_theme_color_override("font_hover_color", UiTheme.color("text"))
	_sound_toggle.add_theme_color_override("font_pressed_color", UiTheme.color("text"))


func _refresh_toggle() -> void:
	var on: bool = _sound_toggle.button_pressed
	_sound_toggle.text = UiStrings.SOUND_ON_TEXT if on else UiStrings.SOUND_OFF_TEXT
	_sound_icon.texture = Icons.texture("lucide/volume-2" if on else "lucide/volume-x")


func _on_sound_toggled(pressed: bool) -> void:
	SaveService.set_setting("sound_on", pressed)
	AudioService.set_muted(not pressed)
	_refresh_toggle()


func _on_back() -> void:
	GameManager.goto_scene(&"menu")
