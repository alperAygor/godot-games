extends Node

## Oyun akışının tek sahibi: faz, sahne yönlendirme, tur sonucu, geri tuşu.
## Sahneler `change_scene_to_file` çağırmaz; hepsi buradan geçer.
## Akış: Boot -> Home -> Game (sonuç sayfası Game üstünde açılır) -> Home / yeni tur.

enum Phase { BOOT, HOME, GAME, RESULT }

## Sahne kayıt defteri: yeni sahne eklerken yalnız buraya satır eklenir.
const SCENES: Dictionary = {
	&"boot": "res://scenes/Boot.tscn",
	&"home": "res://scenes/Home.tscn",
	&"game": "res://scenes/Game.tscn",
}

signal phase_changed(from: Phase, to: Phase)
signal back_requested()

var phase: Phase = Phase.BOOT
## Son turun sonucu (`finish_run`); sonuç sayfası ve araçlar buradan okur.
var last_result: Dictionary = {}
## Arka planda (ResourceLoader iş parçacığı) yüklenmesi istenmiş sahne yolları. Neden: sahne ve
## betik derlemesi ana iş parçacığını dondurabiliyor; Boot beklemesinde yüklenirse geçiş anında olur.
var _preloading: Dictionary[String, bool] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _notification(what: int) -> void:
	# Android donanım geri tuşu
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		back_requested.emit()


func _exit_tree() -> void:
	# Her çıkış yolunda (prob/araç `quit()` dahil) bekleyen arka plan yüklemeleri bitirilir:
	# çıkışta "sızıntı" uyarısı kalmasın.
	for path: String in _preloading.keys():
		ResourceLoader.load_threaded_get(path)
	_preloading.clear()


func _unhandled_input(event: InputEvent) -> void:
	# Masaüstünde Esc (ui_cancel) — geri tuşunun test edilebilir eşi
	if event.is_action_pressed("ui_cancel"):
		back_requested.emit()
		get_viewport().set_input_as_handled()


func goto_scene(scene_key: StringName) -> void:
	var path: Variant = SCENES.get(scene_key)
	if not (path is String):
		push_error("GameManager: bilinmeyen sahne '%s'" % scene_key)
		return
	get_tree().paused = false
	var packed: PackedScene = _take_preloaded(path as String)
	var error: Error = get_tree().change_scene_to_packed(packed) if packed != null \
		else get_tree().change_scene_to_file(path as String)
	if error != OK:
		push_error("GameManager: sahne yüklenemedi (%s), hata %d" % [path, error])


## Sahneyi (ve betiklerini) arka planda yüklemeye başlar; `goto_scene` hazır olanı alır, bitmemişse
## bekler. Zaten bellekteyse ya da istenmişse bir şey yapmaz. Yalnız kaynak yüklenir: düğüm kurulumu
## (`_ready`) her zaman ana iş parçacığında, `goto_scene` anında olur.
func preload_scene(scene_key: StringName) -> void:
	var path: Variant = SCENES.get(scene_key)
	if not (path is String) or _preloading.has(path) or ResourceLoader.has_cached(path as String):
		return
	if ResourceLoader.load_threaded_request(path as String, "PackedScene") == OK:
		_preloading[path as String] = true


## Sahne kaynağı: arka planda istendiyse oradan (gerekirse bitmesini bekler), değilse eşzamanlı yükler.
func scene_resource(scene_key: StringName) -> PackedScene:
	var path: Variant = SCENES.get(scene_key)
	if not (path is String):
		return null
	var packed: PackedScene = _take_preloaded(path as String)
	return packed if packed != null else load(path as String) as PackedScene


func _take_preloaded(path: String) -> PackedScene:
	if not _preloading.has(path):
		return null
	_preloading.erase(path)
	return ResourceLoader.load_threaded_get(path) as PackedScene


## Geçerli sahneyi baştan kurar (dil değişince ekran yarım çevrilmiş kalmasın).
func reload_scene() -> void:
	get_tree().paused = false
	var error: Error = get_tree().reload_current_scene()
	if error != OK:
		push_error("GameManager: sahne yeniden yüklenemedi, hata %d" % error)


func set_phase(next: Phase) -> void:
	if next == phase:
		return
	var previous: Phase = phase
	phase = next
	phase_changed.emit(previous, next)


## Tur bitti: sonuç saklanır, faz RESULT olur. Sonuç sayfasını Game sahnesi kendisi açar.
func finish_run(result: Dictionary) -> void:
	last_result = result
	set_phase(Phase.RESULT)


## Oyun başlamadan önce çevrimiçi kapısı (`OnlineGate`): bağlantı yoksa sakin bir sayfa açılır ve
## bağlantı gelene dek tur başlamaz. Kapı headless/editör/araçlarda kendiliğinden kapalıdır;
## "çevrimdışı oynamak yasak" varsayılanı data/balance.json `require_online` ile değişir.
func start_game() -> void:
	OnlineGate.guard(self, _enter_game)


func _enter_game() -> void:
	last_result = {}
	set_phase(Phase.GAME)
	goto_scene(&"game")
