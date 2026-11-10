extends Node

## Oyun akışının tek sahibi: faz makinesi, başarısızlık/revive ve duraklatma.
## Sahneler kendi başlarına `get_tree().paused` değiştirmez; buradan geçer.

enum Phase { PACKING, DELIVERING, FAILED, DELIVERED }

var phase: Phase = Phase.PACKING

signal phase_changed(from: Phase, to: Phase)
signal run_started()
signal run_failed(reason: StringName)
signal run_revived()
signal run_delivered()

var _failed_reason: StringName = &""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


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
