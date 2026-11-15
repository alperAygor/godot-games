extends MenuScreen
## Duraklatma: dalga/seviye/puan özeti, kart şeridi, DEVAM ET / YENİDEN BAŞLA / AYARLAR / ANA MENÜ.

const KIT = preload("res://scripts/ui/ui_kit.gd")
const W = preload("res://scripts/ui/screens/widgets.gd")

var _info: Label
var _build: W.BuildStrip


func build() -> void:
	root = host.make_screen("pause", 0.72)
	var panel := KIT.panel(KIT.CYAN, 30.0)
	host.center(root).add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size = Vector2(400, 0)
	panel.add_child(box)
	box.add_child(KIT.heading(tr("DURAKLATILDI"), 36))
	_info = KIT.label("", 16, KIT.DIM, null, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_info)
	_build = W.BuildStrip.new()
	_build.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_build)
	box.add_child(KIT.spacer(4))
	var resume := KIT.button(tr("DEVAM ET"), KIT.CYAN, Vector2(360, 66), 26, true)
	resume.pressed.connect(func(): host.resume_pressed.emit())
	box.add_child(resume)
	host.focus["pause"] = resume
	var restart := KIT.button(tr("YENİDEN BAŞLA"), KIT.VIOLET, Vector2(360, 56), 20)
	restart.pressed.connect(func(): host.restart_pressed.emit())
	box.add_child(restart)
	var settings := KIT.button(tr("AYARLAR"), KIT.VIOLET, Vector2(360, 56), 20)
	settings.pressed.connect(func(): host.open_sub("settings", "pause"))
	box.add_child(settings)
	var menu := KIT.button(tr("ANA MENÜ"), Color(0.6, 0.66, 0.78), Vector2(360, 56), 20)
	menu.pressed.connect(func(): host.menu_pressed.emit())
	box.add_child(menu)


## Özeti günceller; ayarlar açıkken (duraklatmadan girildi) ekranı değiştirmez.
func present(wave: int, level: int, score: int, build_items: Array) -> void:
	_info.text = tr("DALGA %d   ·   SEVİYE %d   ·   %s PUAN") % [wave, level, KIT.fmt(score)]
	_build.set_items(build_items)
	if host.current != "settings":
		host.show_screen("pause")
