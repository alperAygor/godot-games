extends Node

## Oyun akışının tek sahibi: faz, sahne yönlendirme, tur sonucu, geri tuşu.
## Sahneler `change_scene_to_file` çağırmaz; hepsi buradan geçer.

enum Phase { BOOT, MENU, GAME, RESULT }

const SCENES: Dictionary = {
	&"boot": "res://scenes/Boot.tscn",
	&"menu": "res://scenes/Menu.tscn",
	&"home": "res://scenes/Home.tscn",
	&"game": "res://scenes/Game.tscn",
	&"result": "res://scenes/Result.tscn",
}

signal phase_changed(from: Phase, to: Phase)
signal back_requested()

var phase: Phase = Phase.BOOT
## Son turun sonucu; Result sahnesi buradan okur.
var last_result: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _notification(what: int) -> void:
	# Android donanım geri tuşu
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		back_requested.emit()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Kapanışta arka plan üretimi yarıda kalmasın (iş parçacığı beklenmeden çıkılmaz).
		LevelPrefetch.drain()


func _exit_tree() -> void:
	# Her çıkış yolunda (prob/araç `quit()` dahil) bekleyen arka plan işleri bitirilir ve
	# paylaşılan statik önbellekler boşaltılır: çıkışta "sızıntı" uyarısı kalmasın.
	LevelPrefetch.drain()
	GardenBackdrop.release_textures()


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
	var error: Error = get_tree().change_scene_to_file(path as String)
	if error != OK:
		push_error("GameManager: sahne yüklenemedi (%s), hata %d" % [path, error])


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


func finish_run(result: Dictionary) -> void:
	last_result = result
	set_phase(Phase.RESULT)
	goto_scene(&"result")


func start_game() -> void:
	last_result = {}
	set_phase(Phase.GAME)
	goto_scene(&"game")
