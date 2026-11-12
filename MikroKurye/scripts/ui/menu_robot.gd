extends Node3D
## Menü vitrini: v2 robotu canlı 3B olarak yavaşça döndürür/zıplatır (statik PNG yerine).
## Yalnız görsel; oyun mantığına dokunmaz. Düşük maliyet: gölgesiz tek ışık, 2x MSAA.

const SWAY_DEGREES: float = 28.0
const SWAY_SPEED: float = 0.55
const BASE_YAW_DEGREES: float = 155.0
const BOB_HEIGHT: float = 0.025
const BOB_SPEED: float = 2.2

@onready var _pivot: Node3D = $Pivot
@onready var _camera: Camera3D = $Camera3D

var _time: float = 0.0


func _ready() -> void:
	_camera.look_at(Vector3(0.0, 0.12, 0.0))


func _process(delta: float) -> void:
	_time += delta
	_pivot.rotation_degrees.y = BASE_YAW_DEGREES + sin(_time * SWAY_SPEED) * SWAY_DEGREES
	_pivot.position.y = sin(_time * BOB_SPEED) * BOB_HEIGHT
