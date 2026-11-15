class_name MenuHost
extends Control
## Menü altyapısı: dış dünyaya açık SİNYALLER, ekran kayıt defteri, geçiş/örtü (fade) yardımcıları ve gezinme.
## `Menus` (menus.gd) bunu genişletir; ekran modülleri (screens/*.gd) yalnız bu türü bilir (menus.gd'ye bağımlılık yok).

signal play_pressed
signal resume_pressed
signal restart_pressed
signal menu_pressed
signal pause_requested
signal card_picked(index: int)
signal reroll_pressed
signal quality_changed
signal ship_preview(id: String)
## Dil değişiminde tüm ekranlar yeniden kurulunca (modüller yeni örnek olur, eklenen seam denetimleri kaybolur).
## Seam kullanan kod (add_entry/add_row/...) ilk kurulumda bir kez uygular ve bu sinyalde yeniden uygular.
signal screens_rebuilt

const KIT = preload("res://scripts/ui/ui_kit.gd")

var current := ""
var in_game := false
## Ekran kimliği -> ekran modülü (MenuScreen).
var modules: Dictionary = {}
## Ekran kimliği -> açılışta odaklanacak denetim (klavye/kumanda).
var focus: Dictionary = {}
var return_to := "main"
var margin := Vector4(28, 20, 28, 20)
var fade: ColorRect

var _screens: Dictionary = {}


# --- Ekran yönetimi ---------------------------------------------------------------
func make_screen(id: String, dim: float) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	if dim > 0.0:
		var shade := ColorRect.new()
		shade.set_anchors_preset(Control.PRESET_FULL_RECT)
		shade.color = Color(KIT.BG, dim)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(shade)
	_screens[id] = root
	return root


func center(root: Control) -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(c)
	return c


func screen_root(id: String) -> Control:
	return _screens.get(id) as Control


func clear_screens() -> void:
	for key in _screens:
		(_screens[key] as Control).queue_free()
	_screens.clear()
	focus.clear()
	modules.clear()


func show_screen(id: String) -> void:
	for key in _screens:
		(_screens[key] as Control).visible = key == id
	current = id
	if id == "":
		return
	var root: Control = _screens[id]
	root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(root, "modulate:a", 1.0, 0.16)
	if not Settings.touch and focus.has(id):
		(focus[id] as Control).grab_focus.call_deferred()


func hide_all() -> void:
	show_screen("")


func flash(color := Color(1, 1, 1), peak := 0.5, time := 0.5) -> void:
	fade.color = Color(color, peak)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 0.0, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func fade_through(callback: Callable, time := 0.28) -> void:
	## Karart → geri çağır → aç. Harita geçişinde kullanılır.
	var tw := create_tween()
	tw.tween_property(fade, "color", Color(0, 0, 0, 1), time)
	tw.tween_callback(callback)
	tw.tween_interval(0.08)
	tw.tween_property(fade, "color", Color(0, 0, 0, 0), time * 1.4)


func side_shade(strength: float) -> TextureRect:
	## Soldan sağa yumuşak kararma: menü metni okunur, 3B sahne sağda görünür kalır.
	var grad := Gradient.new()
	grad.set_color(0, Color(KIT.BG, strength))
	grad.set_color(1, Color(KIT.BG, 0.0))
	grad.set_offset(0, 0.12)
	grad.set_offset(1, 0.7)
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 256
	tex.height = 4
	var shade := TextureRect.new()
	shade.texture = tex
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return shade


# --- Gezinme ------------------------------------------------------------------------
## Alt ekranı açar (`from`: geri düğmesinin döneceği ekran). Ekran modülü `on_open()` ile içeriği tazeler.
func open_sub(id: String, from: String) -> void:
	return_to = from
	var module: MenuScreen = modules.get(id)
	if module != null:
		module.on_open()
	show_screen(id)


func _back() -> void:
	Sound.play("ui_back")
	if current == "hangar":
		ship_preview.emit(Settings.meta.ship)
	if return_to == "main":
		show_main()
	else:
		show_screen(return_to)


# --- Alt sınıfın doldurduğu yönlendirmeler (Menus) ---------------------------------------
func show_main() -> void:
	pass


## Çekirdek miktarı değişince ana menüdeki rozeti eşitler (hangar/atölye alışverişi).
func sync_main_cores() -> void:
	pass


## Ana menü üstünde kısa duyuru.
func notify(_text: String, _duration := 3.2) -> void:
	pass
