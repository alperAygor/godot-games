class_name UiSettingsRow
extends HBoxContainer

## Ses / müzik / titreşim (+ bildirim, varsa desen): yuvarlak aç-kapa düğmeleri ve küçük altyazılar.
## Değer `UiData` üzerinden (Progress varsa oraya) kaydedilir ve hemen uygulanır.
## Anahtar türleri: "flag" = Progress.setting; "module" = Progress.module_value("settings", ...).

const CAPTION_SIZE: int = UiKit.TYPE_CAPTION
const COLUMN_GAP: int = UiTokens.SPACE_XS
const ROW_GAP: int = UiTokens.SPACE_XL
const KIND_FLAG: String = "flag"
const KIND_MODULE: String = "module"
const ENTRIES: Array[Array] = [
	[UiData.SETTING_SOUND, "lucide/volume-2", "SOUND", KIND_FLAG],
	[UiData.SETTING_MUSIC, "lucide/music", "MUSIC", KIND_FLAG],
	[UiData.SETTING_VIBRATION, "lucide/vibrate", "VIBRATION", KIND_FLAG],
]
## `full`: bildirim ve desen anahtarları da gösterilir (ayarlar sayfası). Duraklatma sayfasında
## yalnız üç hızlı anahtar kalır: oyun içinde sakin ve kısa.
var _full: bool = false


func _init(full: bool = false) -> void:
	_full = full
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", ROW_GAP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var captions: Dictionary = {
		"SOUND": UiStrings.sound(), "MUSIC": UiStrings.music(), "VIBRATION": UiStrings.vibration(),
		"NOTIFICATIONS": Loc.t("UI_SETTING_NOTIFICATIONS"), "PATTERNS": Loc.t("UI_SETTING_PATTERNS"),
	}
	for entry: Array in _entries():
		var column: VBoxContainer = VBoxContainer.new()
		column.add_theme_constant_override("separation", COLUMN_GAP)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(column)
		var toggle: UiIconButton = UiIconButton.new()
		toggle.setup(String(entry[1]), true)
		toggle.button_pressed = _read(entry)
		toggle.toggled.connect(_on_toggled.bind(entry))
		column.add_child(toggle)
		toggle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(UiKit.label(String(captions[String(entry[2])]), CAPTION_SIZE, UiKit.TEXT_MUTED))


func _entries() -> Array[Array]:
	var list: Array[Array] = ENTRIES.duplicate()
	if _full:
		list.append([UiData.SETTING_NOTIFICATIONS, "lucide/bell", "NOTIFICATIONS", KIND_MODULE])
		if UiData.patterns_available():
			list.append([UiData.SETTING_PATTERNS, "lucide/grid-2x2", "PATTERNS", KIND_MODULE])
	return list


func _read(entry: Array) -> bool:
	if String(entry[3]) == KIND_FLAG:
		return UiData.setting(String(entry[0]))
	# Bildirim varsayılan AÇIK; desen durumunu sınıfın kendisi bilir (yoksa kapalı).
	if String(entry[0]) == UiData.SETTING_PATTERNS:
		return UiData.patterns_on()
	return UiData.module_flag(String(entry[0]), true)


func _on_toggled(on: bool, entry: Array) -> void:
	var key: String = String(entry[0])
	if String(entry[3]) == KIND_FLAG:
		UiData.set_setting(key, on)
	elif key == UiData.SETTING_PATTERNS:
		UiData.apply_patterns(on)
	else:
		UiData.set_module_flag(key, on)
