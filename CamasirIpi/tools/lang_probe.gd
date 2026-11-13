extends SceneTree

## Dil değiştirme probu (headless): ayarlar sayfasındaki dil düğmesi GERÇEKTEN basılır.
##  (a) Ana ekranda tr -> en: sahne baştan kurulur, düğme/etiket metinleri yeni dilde, kayıt "en" der;
##  (b) seçilen dil kayıtta kalır: yerel ayar sıfırlanıp `Loc.apply_saved` ile geri gelir (yeniden açılış);
##  (c) yeni dilde oyun sahnesi (duraklatma sayfası), harita ve mağaza katmanları yeni dilde kurulur;
##  (d) oyunun içinde dil değişse bile (GameManager.reload_scene) seviye sahnesi yeni dille yeniden kurulur.
##   godot --headless --path . -s res://tools/lang_probe.gd      çıkış 0 = geçti
## Oyuncunun gerçek kaydına ASLA yazmaz (persist=false).

const SETTLE_FRAMES: int = 6
const HOME_SCENE: String = "res://scenes/Home.tscn"
const GAME_SCENE: String = "res://scenes/Game.tscn"
const PLAYER_LEVEL: int = 12

var _progress: Node = null
var _phase: String = "start"
var _wait: int = 0
var _failed: bool = false
var _scene_before: Node = null


func _initialize() -> void:
	_progress = root.get_node("Progress")
	_progress.set("persist", false)
	AnalyticsLog.echo = false


func _process(_delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	match _phase:
		"start":
			_progress.call("reset_state")
			(_progress.get("data") as ProgressData).level = PLAYER_LEVEL
			Loc.set_language(Loc.LANG_TR)
			_open_scene(HOME_SCENE)
			_phase = "home_settings"
			_wait = SETTLE_FRAMES
		"home_settings":
			_check(_has_text(current_scene, Loc.f("LEVEL", [PLAYER_LEVEL])) and Loc.language() == "tr", "ana ekran tr açılmalı")
			current_scene.call("_open_settings")
			_phase = "home_press"
			_wait = SETTLE_FRAMES
		"home_press":
			_scene_before = current_scene
			var pill: Button = _language_pill("en")
			_check(pill != null, "ayarlarda EN düğmesi bulunmalı")
			if pill != null:
				pill.pressed.emit()
			_phase = "home_after"
			_wait = SETTLE_FRAMES * 2
		"home_after":
			_check(current_scene != null and current_scene != _scene_before, "dil değişince ana ekran baştan kurulmalı")
			_check(Loc.language() == "en", "dil en olmalı")
			_check(String(_progress.call("module_value", Loc.SETTINGS_SECTION, Loc.SETTINGS_KEY, "")) == "en", "seçim kayda yazılmalı")
			_check(_has_text(current_scene, "Level %d" % PLAYER_LEVEL), "oynat düğmesi yeni dilde olmalı: Level %d" % PLAYER_LEVEL)
			_check(not _has_text(current_scene, "Seviye"), "eski dilden metin kalmamalı")
			# Yeniden açılış: yerel ayar başka dile düşse de kayıtlı dil geri gelir.
			Loc.set_language(Loc.LANG_TR)
			Loc.apply_saved()
			_check(Loc.language() == "en", "kayıtlı dil yeniden açılışta uygulanmalı")
			print("PROBE ana ekran tr->en: yeniden kuruldu, kayıt=en, yeniden açılışta kalıcı")
			current_scene.call("_open_settings")
			_phase = "home_es"
			_wait = SETTLE_FRAMES
		"home_es":
			var pill: Button = _language_pill("es")
			_check(pill != null, "ayarlarda ES düğmesi bulunmalı")
			_scene_before = current_scene
			if pill != null:
				pill.pressed.emit()
			_phase = "overlays"
			_wait = SETTLE_FRAMES * 2
		"overlays":
			_check(Loc.language() == "es" and _has_text(current_scene, "Nivel %d" % PLAYER_LEVEL), "es: ana ekran Nivel olmalı")
			var map_layer: Node = (load("res://scripts/map/level_map.gd") as GDScript).call("open", current_scene) as Node
			var shop_layer: Node = (load("res://scripts/shop/shop.gd") as GDScript).call("open", current_scene) as Node
			_phase = "overlays_check"
			_wait = SETTLE_FRAMES
			_check(map_layer != null and shop_layer != null, "harita ve mağaza açılmalı")
		"overlays_check":
			_check(_has_text(current_scene, Loc.t("SHOP_TITLE")) or _has_text(current_scene, Loc.t("SHOP_BOOSTERS")), "mağaza es metni (Tienda/Potenciadores)")
			_check(Loc.t("SHOP_BOOSTERS") == "Potenciadores", "es tablo")
			print("PROBE harita+mağaza yeni dilde kuruldu")
			_open_scene(GAME_SCENE)
			_phase = "game_check"
			_wait = SETTLE_FRAMES * 2
		"game_check":
			current_scene.call("_on_pause_requested")
			_phase = "game_pause"
			_wait = SETTLE_FRAMES
		"game_pause":
			_check(_has_text(current_scene, Loc.t("PAUSED")) and Loc.t("PAUSED") == "En pausa", "duraklatma sayfası es olmalı")
			Loc.set_language(Loc.LANG_EN)
			_scene_before = current_scene
			root.get_node("GameManager").call("reload_scene")
			_phase = "game_after"
			_wait = SETTLE_FRAMES * 2
		"game_after":
			_check(current_scene != null and current_scene != _scene_before, "oyun sahnesi baştan kurulmalı")
			current_scene.call("_on_pause_requested")
			_phase = "game_pause_en"
			_wait = SETTLE_FRAMES
		"game_pause_en":
			_check(_has_text(current_scene, "Paused") and not _has_text(current_scene, "En pausa"), "oyun içi dil değişimi: duraklatma en olmalı")
			print("PROBE oyun içinde dil değişimi: sahne yeniden kuruldu, metinler yeni dilde")
			Loc.set_language(Loc.LANG_TR)
			print("PROBE SONUC: %s" % ("BASARISIZ" if _failed else "gecti"))
			quit(1 if _failed else 0)
			return true
	return false


func _open_scene(path: String) -> void:
	if current_scene != null:
		current_scene.queue_free()
	var scene: Node = (load(path) as PackedScene).instantiate()
	if path == GAME_SCENE:
		scene.set("_persist", false)
	root.add_child(scene)
	current_scene = scene


## Ayarlar sayfasındaki dil hapı (düğme içinde TR/EN/ES etiketi olan).
func _language_pill(code: String) -> Button:
	for node: Node in _all_nodes(current_scene):
		if node is UiLanguageRow:
			for button: Node in _all_nodes(node):
				if button is Button and _has_text(button, code.to_upper()):
					return button as Button
	return null


func _all_nodes(from: Node) -> Array[Node]:
	var found: Array[Node] = [from]
	for child: Node in from.get_children():
		found.append_array(_all_nodes(child))
	return found


func _has_text(from: Node, text: String) -> bool:
	for node: Node in _all_nodes(from):
		if node is Label and (node as Label).text == text:
			return true
		if node is Button and (node as Button).text == text:
			return true
	return false


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failed = true
		printerr("PROBE HATA: %s" % message)
