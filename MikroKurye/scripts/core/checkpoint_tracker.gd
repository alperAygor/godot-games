class_name CheckpointTracker
extends RefCounted

## Kontrol noktası kaydı ve yalnız ileri ilerleme. Sözleşme: ARCHITECTURE.md §4.6.
##
## id'ler 0..N, 0 = başlangıç. reach(id) YALNIZCA id > last_id() ise ilerler;
## kayıt şartı yoktur. reset() ilerlemeyi başa alır.

## Henüz geçilmezken son id.
const NO_PROGRESS_ID: int = -1

var _positions: Dictionary
var _last_id: int


func _init() -> void:
	_positions = {}
	_last_id = NO_PROGRESS_ID


func register(id: int, position: Vector3) -> void:
	# id'ler 0..N; 0 = başlangıç. Aşırı kaynaklar için saklanır.
	if id < 0:
		return
	_positions[id] = position


func reach(id: int) -> bool:
	# Yalnızca ileri ilerleme sayılır (id > son). Doğruysa Günceller.
	if id <= _last_id:
		return false
	_last_id = id
	return true


func last_id() -> int:
	return _last_id


func last_position() -> Vector3:
	# Kayıtsızsa Vector3.ZERO.
	if _last_id < 0:
		return Vector3.ZERO
	return _positions.get(_last_id, Vector3.ZERO)


func reset() -> void:
	# İlerlemeyi başa alır.
	_last_id = NO_PROGRESS_ID