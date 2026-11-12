class_name EndlessLevel
extends LevelRoot
## Sonsuz mod seviyesi: level planını (LevelProgression) parçalardan kurar, robotun
## ilerisini önceden üretir, gerideki parçaları siler ve uzak parçaları gizler.
## Sözleşme: PROJECT_SPEC §14. Teslimat noktası (`DeliveryZone`) her level'da ileri taşınır.
## Oyun mantığı (ödül, hasar, batarya) GameController'dadır; bu sınıf yalnız dünyayı kurar.

## Yeni bir kontrol noktası eklendiğinde (konum dünyadadır).
signal checkpoint_added(position: Vector3)

const TABLE_NAME: String = "segments"
const DEFAULT_SEED: int = 20261113
## Robotun ilerisinde en az bu kadar yol hazır tutulur (sis ~130 m'de bitiyor).
const BUILD_HORIZON: float = 150.0
## Bu kadar geride kalan parçalar silinir.
const KEEP_BEHIND: float = 30.0
const ACTIVE_BEHIND: float = 25.0
const ACTIVE_AHEAD: float = 120.0
const CHECKPOINT_SPACING: float = 40.0
const CHECKPOINT_MIN_TAIL: float = 10.0
const CHECKPOINT_HEIGHT: float = 0.58
const PAD_HEIGHT: float = 1.0
## Parça güncellemesi her kare gerekmez.
const UPDATE_EVERY_FRAMES: int = 6

@export var seed_value: int = DEFAULT_SEED

var current_level: int = 1

var _library: Array = []
var _scenes: Dictionary[String, PackedScene] = {}
var _live: Array[Segment] = []
var _level_end: Dictionary[int, float] = {}
var _built_level: int = 0
var _built_end_z: float = 0.0
var _frame: int = 0
var _checkpoints: Array[Vector3] = []

@onready var _segments_root: Node3D = $Segments
@onready var _pad: Area3D = $DeliveryZone
@onready var _backdrop: Node3D = $Backdrop
@onready var _style: StyleA = $StyleA as StyleA


func _ready() -> void:
	super._ready()
	_load_library()
	_build_next_level()
	_place_pad()


func is_endless() -> bool:
	return true


## Mevcut level'ın bitiş çizgisinin dünya z'si (negatif).
func level_end_z() -> float:
	return float(_level_end.get(current_level, _built_end_z))


## Level tamamlandı: sonraki level'a geçer, teslimat noktasını ileri taşır.
func advance() -> void:
	current_level += 1
	while _built_level < current_level:
		_build_next_level()
	_place_pad()


## GameController her fizik karesinde çağırır; maliyet düşük tutulur.
func update_world(robot_z: float) -> void:
	_backdrop.position.z = robot_z
	_frame += 1
	if _frame % UPDATE_EVERY_FRAMES != 0:
		return
	while _built_end_z > robot_z - BUILD_HORIZON:
		_build_next_level()
	for segment: Segment in _live.duplicate():
		var near_z: float = segment.position.z
		var far_z: float = near_z - segment.length
		if far_z > robot_z + KEEP_BEHIND:
			_live.erase(segment)
			segment.queue_free()
			continue
		var active: bool = near_z > robot_z - ACTIVE_AHEAD and far_z < robot_z + ACTIVE_BEHIND
		segment.set_active(active)


## Şimdiye kadar üretilen ara kontrol noktaları (GameController bağlanmadan önce de oluşur).
func checkpoint_positions() -> Array[Vector3]:
	return _checkpoints


func segment_count() -> int:
	return _live.size()


func _load_library() -> void:
	var data: Node = get_node_or_null("/root/GameData")
	if data == null:
		return
	var table: Variant = data.call("table", TABLE_NAME)
	if table is Dictionary:
		var entries: Variant = (table as Dictionary).get("segments", [])
		if entries is Array:
			_library = entries as Array


func _build_next_level() -> void:
	var level: int = _built_level + 1
	var plan: Array[Dictionary] = LevelProgression.plan(level, seed_value, _library)
	var start_z: float = _built_end_z
	for entry: Dictionary in plan:
		var segment: Segment = _instantiate_segment(String(entry["id"]))
		if segment == null:
			continue
		segment.position = Vector3(0.0, 0.0, start_z - float(entry["offset"]))
		_segments_root.add_child(segment)
		segment.apply_level(level)
		if _style != null:
			_style.restyle(segment)
		_live.append(segment)
	var length: float = LevelProgression.plan_length(plan)
	if plan.is_empty():
		length = LevelProgression.length_for(level)
	_built_end_z = start_z - length
	_level_end[level] = _built_end_z
	_built_level = level
	var marker_offset: float = CHECKPOINT_SPACING
	while marker_offset < length - CHECKPOINT_MIN_TAIL:
		var position_3d: Vector3 = Vector3(0.0, CHECKPOINT_HEIGHT, start_z - marker_offset)
		_checkpoints.append(position_3d)
		checkpoint_added.emit(position_3d)
		marker_offset += CHECKPOINT_SPACING


func _instantiate_segment(segment_id: String) -> Segment:
	var packed: PackedScene = _scenes.get(segment_id)
	if packed == null:
		for entry_raw: Variant in _library:
			var entry: Dictionary = entry_raw as Dictionary
			if String(entry.get("id", "")) == segment_id:
				packed = load(String(entry.get("scene", ""))) as PackedScene
				break
		if packed == null:
			push_warning("EndlessLevel: parça sahnesi yüklenemedi: %s" % segment_id)
			return null
		_scenes[segment_id] = packed
	return packed.instantiate() as Segment


func _place_pad() -> void:
	_pad.global_position = Vector3(0.0, PAD_HEIGHT, level_end_z())
