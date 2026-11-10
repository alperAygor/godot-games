class_name Package
extends Node3D

## Çantaya yerleştirilebilir paket.
## Origin modelin taban merkezidir (assets/models/README.md) — bu yüzden ölçek
## animasyonları tabana yapışık squash/stretch gibi okunur.

const GROUP_DRAGGABLE: String = "draggable"

## Izgarada kapladığı hücre sayısı (sütun, satır).
@export var footprint: Vector2i = Vector2i.ONE
@export var display_label: String = ""

var home_position: Vector3 = Vector3.ZERO
var home_scale: Vector3 = Vector3.ONE

func _ready() -> void:
	add_to_group(GROUP_DRAGGABLE)
	home_position = global_position
	home_scale = scale
	if footprint.x < 1 or footprint.y < 1:
		push_error("Package '%s': geçersiz footprint %s" % [name, footprint])
