extends Node

## Oyun akışının tek sahibi: faz makinesi, başarısızlık/revive ve duraklatma.
## Sahneler kendi başlarına `get_tree().paused` değiştirmez; buradan geçer.

## Yeni degerler SONA eklenir: mevcut sayisal degerler korunur (testler ve
## araclar FAILED=2 varsayimini kullanir).
enum Phase { PACKING, DELIVERING, FAILED, DELIVERED, BOOT, MENU }

const SCENES: Dictionary = {
	&"boot": "res://scenes/Boot.tscn",
	&"menu": "res://scenes/Menu.tscn",
	&"game": "res://scenes/Main.tscn",
	&"result": "res://scenes/Result.tscn",
}

var phase: Phase = Phase.PACKING
## Son turun sonucu; Result sahnesi buradan okur.
var last_result: Dictionary = {}

signal phase_changed(from: Phase, to: Phase)
signal run_started()
signal run_failed(reason: StringName)
signal run_revived()
signal run_delivered()
signal back_requested()

var _failed_reason: StringName = &""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _notification(what: int) -> void:
	# Android donanim geri tusu
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		back_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	# Masaustunde Esc — geri tusunun test edilebilir esi
	if event.is_action_pressed("ui_cancel"):
		back_requested.emit()
		get_viewport().set_input_as_handled()


## Sahne gecisi tek yerden. Sahneler change_scene_to_file cagirmaz.
func goto_scene(scene_key: StringName) -> void:
	var path: Variant = SCENES.get(scene_key)
	if not (path is String):
		push_error("GameManager: bilinmeyen sahne '%s'" % scene_key)
		return
	get_tree().paused = false
	var error: Error = get_tree().change_scene_to_file(path as String)
	if error != OK:
		push_error("GameManager: sahne yuklenemedi (%s), hata %d" % [path, error])


## Turu bitirir: sonucu saklar ve sonuc ekranina gecer.
func finish_run(result: Dictionary) -> void:
	last_result = result
	get_tree().paused = false
	_set_phase(Phase.DELIVERED)
	run_delivered.emit()
	goto_scene(&"result")


func start_delivery() -> void:
	if phase != Phase.PACKING:
		return
	_failed_reason = &""
	_set_phase(Phase.DELIVERING)
	run_started.emit()


func fail_run(reason: StringName) -> void:
	if phase == Phase.FAILED or phase == Phase.DELIVERED:
		return
	_failed_reason = reason
	_set_phase(Phase.FAILED)
	run_failed.emit(reason)
	get_tree().paused = true


func revive() -> void:
	if phase != Phase.FAILED:
		return
	get_tree().paused = false
	_failed_reason = &""
	_set_phase(Phase.DELIVERING)
	run_revived.emit()


func complete_run() -> void:
	if phase == Phase.DELIVERED:
		return
	_set_phase(Phase.DELIVERED)
	run_delivered.emit()


func reset_run() -> void:
	get_tree().paused = false
	_failed_reason = &""
	AdManager.reset_run_limits()
	_set_phase(Phase.PACKING)


func failed_reason() -> StringName:
	return _failed_reason


func _set_phase(next: Phase) -> void:
	if next == phase:
		return
	var previous: Phase = phase
	phase = next
	phase_changed.emit(previous, next)
