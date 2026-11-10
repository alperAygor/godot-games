extends Node

## Oyun akisinin tek sahibi: faz, sahne yonlendirme, bolum secimi, tur sonucu, kayit.
## Sahneler change_scene_to_file cagirmaz; hepsi buradan gecer.

enum Phase { BOOT, MENU, LEVELS, GAME, RESULT }

const MAX_LEVEL: int = 12

const SCENES: Dictionary = {
	&"boot": "res://scenes/Boot.tscn",
	&"menu": "res://scenes/Menu.tscn",
	&"levels": "res://scenes/LevelSelect.tscn",
	&"game": "res://scenes/Game.tscn",
	&"result": "res://scenes/Result.tscn",
}

signal phase_changed(from: Phase, to: Phase)
signal back_requested()

var phase: Phase = Phase.BOOT
## Aktif bolum (1..MAX_LEVEL).
var level_index: int = 1
## Son turun sonucu; Result sahnesi buradan okur.
var last_result: Dictionary = {}
## Kalici kayit (yildiz en iyi sureler).
var profile: PlayerProfile = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	profile = PlayerProfile.new()
	profile.load_save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		back_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	# Masaustunde Esc, Android geri tusunun test edilebilir esidir.
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
		push_error("GameManager: sahne yuklenemedi (%s), hata %d" % [path, error])


func set_phase(next: Phase) -> void:
	if next == phase:
		return
	var previous: Phase = phase
	phase = next
	phase_changed.emit(previous, next)


## Bolumu kurar ve oyun sahnesine gecer. Reklam limitleri oyun sahnesinde sifirlanir.
func start_level(level_number: int) -> void:
	level_index = clampi(level_number, 1, MAX_LEVEL)
	last_result = {}
	set_phase(Phase.GAME)
	goto_scene(&"game")


func replay_level() -> void:
	start_level(level_index)


func next_playable_level() -> int:
	return profile.highest_unlocked()


func has_next_level() -> bool:
	return level_index < MAX_LEVEL


func complete_level(result: Dictionary) -> void:
	last_result = result.duplicate(true)
	var earned_stars: int = int(result.get("stars", 0))
	var elapsed: float = float(result.get("elapsed", 0.0))
	if profile != null:
		profile.record(level_index, earned_stars, elapsed)
		profile.save()
	set_phase(Phase.RESULT)
	goto_scene(&"result")


func goto_menu() -> void:
	set_phase(Phase.MENU)
	goto_scene(&"menu")


func goto_levels() -> void:
	set_phase(Phase.LEVELS)
	goto_scene(&"levels")
