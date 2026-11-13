class_name UiSettingsRow
extends HBoxContainer

## Ses / müzik / titreşim: üç yuvarlak aç-kapa düğmesi ve küçük altyazılar.
## Değer `UiData` üzerinden (Progress varsa oraya) kaydedilir ve hemen uygulanır.

const CAPTION_SIZE: int = 28
const COLUMN_GAP: float = 8.0
const ENTRIES: Array[Array] = [
	[UiData.SETTING_SOUND, "lucide/volume-2", "SOUND"],
	[UiData.SETTING_MUSIC, "lucide/music", "MUSIC"],
	[UiData.SETTING_VIBRATION, "lucide/vibrate", "VIBRATION"],
]


func _init() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 56)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var captions: Dictionary = {
		"SOUND": UiStrings.sound(), "MUSIC": UiStrings.music(), "VIBRATION": UiStrings.vibration(),
	}
	for entry: Array in ENTRIES:
		var column: VBoxContainer = VBoxContainer.new()
		column.add_theme_constant_override("separation", int(COLUMN_GAP))
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(column)
		var toggle: UiIconButton = UiIconButton.new()
		toggle.setup(String(entry[1]), true)
		toggle.button_pressed = UiData.setting(String(entry[0]))
		toggle.toggled.connect(_on_toggled.bind(String(entry[0])))
		column.add_child(toggle)
		toggle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(UiKit.label(String(captions[String(entry[2])]), CAPTION_SIZE, UiKit.TEXT_MUTED))


func _on_toggled(on: bool, key: String) -> void:
	UiData.set_setting(key, on)
