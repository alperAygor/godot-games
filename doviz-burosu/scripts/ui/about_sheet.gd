class_name AboutSheet
extends Control
## "Hakkında ve lisanslar" tam ekran penceresi (Ayarlar'dan açılır).
##  - Sürüm, kısa tanıtım, "Bu bir simülasyondur; kurgusal para, finansal tavsiye değildir" bildirimi, emeği geçenler.
##  - Pakete giren üçüncü taraf bileşenlerin lisansları: yazı tipleri ve eklentiler `data/licenses.json` (tools/build_licenses.py
##    üretir; metinler kaynak dosyalarla birebir, tests/unit/test_about.gd denetler), Godot Engine lisansı motordan (`Engine.get_license_text`).
##  - Gizlilik politikası bağlantısı Ayarlar'dadır (adres geçerliyse); burada tekrarlanmaz.
## Düğme adları (TouchInput): AboutCloseButton, License_<id>, LicenseBackButton; metinler AboutVersion, AboutSimNotice, LicenseText.

const LICENSES_PATH := "res://data/licenses.json"
const ENGINE_ID := "godot"

signal closed

var _column: VBoxContainer
var _detail_id := ""


func _init() -> void:
	name = "AboutSheet"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 50
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.055, 0.045, 1.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var safe := MarginContainer.new()
	safe.set_script(load("res://scripts/ui/safe_area_container.gd"))
	safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(safe)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 14)
	safe.add_child(_column)


func _ready() -> void:
	_show_list()


## Geri tuşu: lisans metni açıksa listeye dön, değilse pencereyi kapat.
func handle_back() -> bool:
	if not _detail_id.is_empty():
		_show_list()
	else:
		close()
	return true


func close() -> void:
	closed.emit()
	queue_free()


## Lisans kayıtları (data/licenses.json), motor kaydı en sonda. Her kayıt: id, name, license, copyright, url, text, used.
static func components() -> Array:
	var list: Array = []
	list.assign(JsonIO.read_dict(LICENSES_PATH).get("components", []))
	return list


static func game_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", ""))


func _clear() -> void:
	for child in _column.get_children():
		_column.remove_child(child)
		child.queue_free()


func _title_row(title: String, back_name: String, back_text: String, on_back: Callable) -> void:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	var heading := UiKit.wrapped(title, &"BoothTitle", "AboutTitle")  # uzun başlık satıra sarılır; düğmeyi ekran dışına itmez
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.custom_minimum_size.x = 120.0
	top.add_child(heading)
	var back := UiKit.icon_button("back", back_text, back_name, true, true, 76.0)
	back.custom_minimum_size.x = 190.0
	back.pressed.connect(on_back)
	top.add_child(back)
	_column.add_child(top)


func _show_list() -> void:
	_detail_id = ""
	_clear()
	_title_row(tr("ACC_ABOUT_TITLE"), "AboutCloseButton", tr("COMMON_CLOSE"), close)
	var scroll_list := UiKit.scroll_box()
	var scroll: ScrollContainer = scroll_list.get_meta("scroll")
	scroll.name = "AboutScroll"
	_column.add_child(scroll)

	scroll_list.add_child(UiKit.label(tr("APP_TITLE"), &"BoothHeading", "AboutAppName"))
	var version := game_version()
	if not version.is_empty():
		scroll_list.add_child(UiKit.label(tr("ACC_ABOUT_VERSION") % version, &"BoothMuted", "AboutVersion"))
	scroll_list.add_child(UiKit.wrapped(tr("ACC_ABOUT_TAGLINE"), &"BoothBody", "AboutTagline"))

	var notice := UiKit.card(tr("ACC_ABOUT_SIM_TITLE"), &"SlipPanel", "AboutSimNotice", "warning")
	notice.add_child(UiKit.wrapped(tr("ACC_ABOUT_SIM_TEXT"), &"SlipLine", "AboutSimText"))
	scroll_list.add_child(notice.get_meta("panel"))

	scroll_list.add_child(UiKit.wrapped(tr("ACC_ABOUT_CREDITS_TITLE"), &"BoothHeading"))
	scroll_list.add_child(UiKit.wrapped(tr("ACC_ABOUT_CREDITS"), &"BoothBody", "AboutCredits"))

	scroll_list.add_child(UiKit.wrapped(tr("ACC_ABOUT_LICENSES_TITLE"), &"BoothHeading"))
	for entry: Dictionary in components():
		scroll_list.add_child(_license_button(str(entry["id"]), str(entry["name"]), str(entry["license"])))
	scroll_list.add_child(_license_button(ENGINE_ID, "Godot Engine %s" % engine_version(), "MIT"))
	scroll_list.add_child(UiKit.wrapped(tr("ACC_ABOUT_GOOGLE"), &"BoothMuted", "AboutGoogleNote"))


func _license_button(id: String, display_name: String, license_name: String) -> Button:
	var button := UiKit.button(tr("ACC_LICENSE_BY") % [display_name, license_name], "License_%s" % id, &"GhostButton", 84.0)
	button.pressed.connect(_show_license.bind(id))
	return button


func _show_license(id: String) -> void:
	_detail_id = id
	_clear()
	var heading := id
	var meta := ""
	var body := ""
	if id == ENGINE_ID:
		heading = "Godot Engine"
		meta = "MIT · https://godotengine.org"
		body = Engine.get_license_text()
		body += "\n\n" + tr("ACC_LICENSE_ENGINE_PARTS") + "\n" + ", ".join(engine_component_names())
	else:
		for entry: Dictionary in components():
			if str(entry["id"]) == id:
				heading = str(entry["name"])
				var version := str(entry.get("version", ""))
				meta = "%s%s\n%s\n%s" % [str(entry["license"]), (" · v" + version) if not version.is_empty() else "", str(entry["copyright"]), str(entry["url"])]
				body = str(entry.get("text", ""))
	if body.strip_edges().is_empty():
		body = tr("ACC_LICENSE_NO_TEXT")
	_title_row(heading, "LicenseBackButton", tr("COMMON_BACK"), _show_list)
	var list := UiKit.scroll_box()
	var scroll: ScrollContainer = list.get_meta("scroll")
	scroll.name = "LicenseScroll"
	_column.add_child(scroll)
	list.add_child(UiKit.wrapped(meta, &"BoothMuted", "LicenseMeta"))
	list.add_child(UiKit.wrapped(body, &"DeskLabel", "LicenseText"))


static func engine_version() -> String:
	var info := Engine.get_version_info()
	return "%d.%d.%d" % [int(info.get("major", 0)), int(info.get("minor", 0)), int(info.get("patch", 0))]


## Godot'un kendi üçüncü taraf bileşen adları (Engine.get_copyright_info), yinelenmeden.
static func engine_component_names() -> PackedStringArray:
	var names := PackedStringArray()
	for entry: Dictionary in Engine.get_copyright_info():
		var component := str(entry.get("name", ""))
		if not component.is_empty() and not names.has(component):
			names.append(component)
	return names
