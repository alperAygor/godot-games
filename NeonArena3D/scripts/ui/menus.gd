extends MenuHost
## Menü yönlendiricisi: ana menü, hangar, atölye, ayarlar, nasıl oynanır, duraklatma, kart seçimi, oyun sonu.
## Hepsi gerçek Control düğümleri: fare, dokunmatik, klavye ve Android geri tuşuyla çalışır.
##
## Yapı (F3): her ekran `scripts/ui/screens/<ekran>.gd` modülüdür (MenuScreen); ortak altyapı ve SİNYALLER `MenuHost`ta
## (screens/menu_host.gd), saf karar mantığı `MenuLogic`te, çizim bileşenleri `screens/widgets.gd`de. Bu dosya yalnız
## modülleri kurar, genel API'yi (show_main, show_pause, show_cards, show_gameover, open_sub, notify ...) onlara yönlendirir,
## dil değişiminde yeniden kurar ve girdiyi (ESC/geri, klavye) dağıtır. Sinyaller ve düğüm adları/yolları eskisiyle aynıdır.
##
## Sonraki görevler için eklenti noktaları (her biri ilgili ekran dosyasının başında belgelidir):
##   main.add_entry()  ana menü girişi (günlük meydan okuma, görevler/başarımlar, mağaza/reklamsız)
##   settings.add_row()  ayar satırı (gizlilik seçenekleri)
##   gameover.add_reward_action()  oyun sonu "izle: ×2" düğmesi      cards.add_below_reroll()  reklamla +1 yenileme
##   workshop.add_footer()  atölye altı (mağaza girişi)

const MainScreen = preload("res://scripts/ui/screens/main.gd")
const HangarScreen = preload("res://scripts/ui/screens/hangar.gd")
const WorkshopScreen = preload("res://scripts/ui/screens/workshop.gd")
const SettingsScreen = preload("res://scripts/ui/screens/settings.gd")
const HowtoScreen = preload("res://scripts/ui/screens/howto.gd")
const PauseScreen = preload("res://scripts/ui/screens/pause.gd")
const CardsScreen = preload("res://scripts/ui/screens/cards.gd")
const GameoverScreen = preload("res://scripts/ui/screens/gameover.gd")

## Ekran modülleri (dil değişiminde yeniden oluşturulur; dışarıdan her zaman buradan alın).
var main: MainScreen
var hangar: HangarScreen
var workshop: WorkshopScreen
var settings: SettingsScreen
var howto: HowtoScreen
var pause: PauseScreen
var cards: CardsScreen
var gameover: GameoverScreen

var _pause_args: Array = []


func _ready() -> void:
	build_ui()
	get_tree().set_quit_on_go_back(false)
	I18n.language_changed.connect(_rebuild)


## Tüm ekranları ve örtüyü kurar (sahne ağacı gerektirmez; birim testler ağaç dışında çağırır).
func build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_all()
	fade = ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)


func _build_all() -> void:
	main = _add_module("main", MainScreen.new(self))
	hangar = _add_module("hangar", HangarScreen.new(self))
	workshop = _add_module("workshop", WorkshopScreen.new(self))
	settings = _add_module("settings", SettingsScreen.new(self))
	howto = _add_module("howto", HowtoScreen.new(self))
	pause = _add_module("pause", PauseScreen.new(self))
	cards = _add_module("cards", CardsScreen.new(self))
	gameover = _add_module("gameover", GameoverScreen.new(self))


func _add_module(id: String, module: MenuScreen) -> MenuScreen:
	modules[id] = module
	module.build()
	return module


func _rebuild() -> void:
	## Dil değişince tüm ekranlar yeni dilde yeniden kurulur; bulunulan ekran korunur.
	var keep := current
	var back_to := return_to
	clear_screens()
	_build_all()
	move_child(fade, get_child_count() - 1)
	return_to = back_to
	if not _pause_args.is_empty():
		show_pause(_pause_args[0], _pause_args[1], _pause_args[2], _pause_args[3])
	if keep == "main":
		show_main()
	elif keep != "":
		if keep == "settings":
			settings.refresh()
		show_screen(keep)
	else:
		hide_all()
	screens_rebuilt.emit()


func set_margins(m: Vector4) -> void:
	margin = m
	if main != null:
		main.set_margins(m)


func _process(delta: float) -> void:
	var vp := get_viewport_rect().size
	if size != vp:
		size = vp
		position = Vector2.ZERO
	if current == "gameover":
		gameover.tick(delta)


# --- Genel API (oyun sahnesi bunları çağırır) ----------------------------------------------
func show_main() -> void:
	main.present()


func sync_main_cores() -> void:
	if main != null and main.cores != null:
		main.cores.set_amount(Settings.meta.cores, false)


func notify(text: String, duration := 3.2) -> void:
	## Ana menü üstünde kısa duyuru (bonus, açılan gemi vb.).
	if main != null:
		main.notify(text, duration)


func show_pause(wave: int, level: int, score: int, build: Array) -> void:
	_pause_args = [wave, level, score, build]
	pause.present(wave, level, score, build)


func show_cards(card_list: Array, level: int, rerolls: int, counts: Dictionary) -> void:
	cards.present(card_list, level, rerolls, counts)


func show_gameover(stats: Dictionary, build: Array) -> void:
	gameover.present(stats, build)


# --- Girdi ------------------------------------------------------------------------
func _go_back() -> void:
	match MenuLogic.back_action(current, in_game, OS.has_feature("mobile")):
		MenuLogic.BackAction.BACK:
			_back()
		MenuLogic.BackAction.RESUME:
			resume_pressed.emit()
		MenuLogic.BackAction.QUIT:
			get_tree().quit()
		MenuLogic.BackAction.MENU:
			menu_pressed.emit()
		MenuLogic.BackAction.PAUSE:
			pause_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_go_back()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if current == "cards":
			var idx := MenuLogic.card_index_for_key(key.physical_keycode)
			if idx >= 0 and idx < cards.card_count():
				Sound.play("ui_click")
				card_picked.emit(idx)
				get_viewport().set_input_as_handled()
		elif current == "hangar" and MenuLogic.hangar_step_for_key(key.physical_keycode) != 0:
			hangar.step(MenuLogic.hangar_step_for_key(key.physical_keycode))
			get_viewport().set_input_as_handled()
		elif current == "gameover" and key.physical_keycode == KEY_R:
			restart_pressed.emit()
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()
	elif what == NOTIFICATION_APPLICATION_PAUSED or (what == NOTIFICATION_APPLICATION_FOCUS_OUT and OS.has_feature("mobile")):
		if in_game and current == "":
			pause_requested.emit()
