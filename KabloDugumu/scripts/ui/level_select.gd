extends Control

## Bölüm seçimi: 12 bölüm, kilit ve yıldız durumu GameManager.profile'dan okunur.
## Buton adları (Level1Button..Level12Button) QA sözleşmesidir — değiştirme.

const LEVEL_COUNT: int = 12
const STAR_ICON_SIZE: int = 34

const COLOR_STAR_ON: Color = Color(1.000, 0.788, 0.290, 1.0)
const COLOR_STAR_OFF: Color = Color(0.220, 0.280, 0.330, 1.0)
const COLOR_LOCKED: Color = Color(0.451, 0.522, 0.573, 1.0)
const COLOR_UNLOCKED: Color = Color(0.913, 0.949, 0.965, 1.0)

@onready var grid: GridContainer = %Grid
@onready var subtitle_label: Label = %Subtitle
@onready var back_button: Button = %BackButton

var _level_names: Array[String] = []


func _ready() -> void:
	_level_names = _read_level_names()
	_build_buttons()
	back_button.expand_icon = true
	Icons.apply(back_button, "lucide/arrow-left", Color(0.169, 0.129, 0.0, 1.0), 36)
	back_button.pressed.connect(_on_back)
	GameManager.back_requested.connect(_on_back)


func _build_buttons() -> void:
	var profile: PlayerProfile = GameManager.profile
	var total_stars: int = 0 if profile == null else profile.total_stars()
	subtitle_label.text = "12 BÖLÜM · %d/%d YILDIZ" % [total_stars, LEVEL_COUNT * 3]
	for index: int in range(1, LEVEL_COUNT + 1):
		var button: Button = grid.get_node_or_null("Level%dButton" % index) as Button
		if button == null:
			push_error("LevelSelect: Level%dButton bulunamadı" % index)
			continue
		var unlocked: bool = profile == null or profile.is_unlocked(index)
		var stars: int = 0 if profile == null else profile.stars(index)
		_decorate_button(button, index, unlocked, stars)
		button.pressed.connect(_on_level_pressed.bind(index))


func _decorate_button(button: Button, index: int, unlocked: bool, stars: int) -> void:
	button.text = ""
	button.disabled = not unlocked
	button.modulate = Color(1.0, 1.0, 1.0, 0.7) if not unlocked else Color(1.0, 1.0, 1.0, 1.0)

	var content: VBoxContainer = VBoxContainer.new()
	content.name = "Content"
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 10.0
	content.offset_top = 10.0
	content.offset_right = -10.0
	content.offset_bottom = -10.0
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 6)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(content)

	var number_label: Label = Label.new()
	number_label.name = "Number"
	number_label.text = "%02d" % index
	number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number_label.add_theme_font_size_override("font_size", 56)
	number_label.add_theme_color_override("font_color",
		COLOR_UNLOCKED if unlocked else COLOR_LOCKED)
	number_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(number_label)

	var name_label: Label = Label.new()
	name_label.name = "LevelName"
	name_label.text = _level_name(index) if unlocked else "KİLİTLİ"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", COLOR_LOCKED)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(name_label)

	var stars_row: HBoxContainer = HBoxContainer.new()
	stars_row.name = "StarsRow"
	stars_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stars_row.add_theme_constant_override("separation", 4)
	stars_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(stars_row)

	var star_texture: Texture2D = Icons.texture("lucide/star")
	for star_index: int in range(3):
		var star: TextureRect = TextureRect.new()
		star.name = "Star%d" % (star_index + 1)
		star.texture = star_texture
		star.custom_minimum_size = Vector2(float(STAR_ICON_SIZE), float(STAR_ICON_SIZE))
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star.modulate = COLOR_STAR_ON if unlocked and star_index < stars else COLOR_STAR_OFF
		star.visible = unlocked
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stars_row.add_child(star)


func _level_name(index: int) -> String:
	if index >= 1 and index <= _level_names.size():
		return _level_names[index - 1]
	return "BÖLÜM %d" % index


## JSON sınırı: levels tablosu Variant döner, burada tipli listeye çevrilir.
func _read_level_names() -> Array[String]:
	var result: Array[String] = []
	var rows_variant: Variant = GameData.table("levels").get("levels", [])
	if not (rows_variant is Array):
		return result
	var rows: Array = rows_variant as Array
	for entry: Variant in rows:
		if entry is Dictionary:
			var row: Dictionary = entry as Dictionary
			result.append(String(row.get("name", "")))
	return result


func _on_level_pressed(level: int) -> void:
	AudioService.play("ui_tap")
	GameManager.start_level(level)


func _on_back() -> void:
	AudioService.play("ui_tap")
	GameManager.goto_menu()
