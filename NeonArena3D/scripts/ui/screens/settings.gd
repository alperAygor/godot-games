extends MenuScreen
## Ayarlar: müzik, efekt, otomatik ateş, titreşim (dokunmatik), sarsıntı, grafik kalitesi, FPS, dil.
##
## EKLENECEK YER: "Gizlilik seçenekleri" (UMP) satırı ve benzeri yeni satırlar `add_row(başlık, denetim)` ile
## GERİ düğmesinin üstüne eklenir (reklam görevi: yalnız `Ads.privacy_options_required()` iken bir düğme satırı;
## başlık ve düğme metinleri çeviri anahtarı olarak data/lang_en.json'a eklenmelidir).

const KIT = preload("res://scripts/ui/ui_kit.gd")

var box: VBoxContainer
var _quality_button: Button
var _nodes: Dictionary = {}
var _footer_index := 0


func _row(parent: VBoxContainer, title: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	var l := KIT.label(title, 20, KIT.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(250, 0)
	row.add_child(l)
	control.size_flags_horizontal = Control.SIZE_SHRINK_END
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)
	parent.add_child(row)
	return row


func _add_toggle(parent: VBoxContainer, title: String, key: String, accent := KIT.CYAN) -> void:
	var b := KIT.toggle(bool(Settings.get(key)), accent)
	b.toggled.connect(func(on: bool):
		Settings.set_value(key, on)
		KIT.restyle_toggle(b, on, accent)
		Sound.play("ui_toggle"))
	KIT.restyle_toggle(b, bool(Settings.get(key)), accent)
	_nodes[key] = b
	_row(parent, title, b)


func build() -> void:
	root = host.make_screen("settings", 0.78)
	var panel := KIT.panel(KIT.CYAN, 30.0)
	host.center(root).add_child(panel)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size = Vector2(580, 0)
	panel.add_child(box)
	box.add_child(KIT.heading(tr("AYARLAR"), 38))
	box.add_child(KIT.spacer(4))
	var music := KIT.slider(Settings.music, KIT.CYAN)
	music.value_changed.connect(func(v: float): Settings.set_value("music", v))
	_nodes["music"] = music
	_row(box, tr("MÜZİK"), music)
	var sfx := KIT.slider(Settings.sfx, KIT.MAGENTA)
	sfx.value_changed.connect(func(v: float):
		Settings.set_value("sfx", v)
		Sound.play("ui_toggle"))
	_nodes["sfx"] = sfx
	_row(box, tr("EFEKTLER"), sfx)
	_add_toggle(box, tr("OTOMATİK ATEŞ"), "auto_fire")
	if Settings.touch:
		_add_toggle(box, tr("TİTREŞİM"), "vibration")
	_add_toggle(box, tr("EKRAN SARSINTISI"), "shake")
	_quality_button = KIT.button(tr(Settings.QUALITY_NAMES[Settings.quality]), KIT.GOLD, Vector2(170, 50), 20)
	_quality_button.pressed.connect(func():
		Settings.set_value("quality", (Settings.quality + 1) % 3)
		_quality_button.text = tr(Settings.QUALITY_NAMES[Settings.quality])
		host.quality_changed.emit())
	_row(box, tr("GRAFİK KALİTESİ"), _quality_button)
	_add_toggle(box, tr("FPS GÖSTER"), "show_fps")
	var lang := KIT.button(str(I18n.NAMES.get(Settings.language, "TÜRKÇE")), KIT.GREEN, Vector2(170, 50), 20)
	lang.pressed.connect(func(): I18n.set_language(I18n.next_language()))
	_row(box, tr("DİL / LANGUAGE"), lang)
	_footer_index = box.get_child_count()
	box.add_child(KIT.spacer(6))
	var back := KIT.button(tr("GERİ"), KIT.CYAN, Vector2(240, 58), 22, true)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(host._back)
	box.add_child(back)
	host.focus["settings"] = back


func on_open() -> void:
	refresh()


func refresh() -> void:
	(_nodes["music"] as HSlider).set_value_no_signal(Settings.music)
	(_nodes["sfx"] as HSlider).set_value_no_signal(Settings.sfx)
	for key in ["auto_fire", "vibration", "shake", "show_fps"]:
		if _nodes.has(key):
			var b: Button = _nodes[key]
			b.set_pressed_no_signal(bool(Settings.get(key)))
			KIT.restyle_toggle(b, bool(Settings.get(key)))
	_quality_button.text = tr(Settings.QUALITY_NAMES[Settings.quality])


## SEAM: "başlık | denetim" satırını GERİ düğmesinin üstüne ekler (ör. gizlilik seçenekleri). Satırı döndürür.
func add_row(title: String, control: Control) -> HBoxContainer:
	var row := _row(box, title, control)
	box.move_child(row, _footer_index)
	_footer_index += 1
	return row
