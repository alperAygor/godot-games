class_name SliceTray
extends Node3D
## Başparmak bölgesindeki cihaz tepsisi: her yuva için yumuşak kenarlı bir sunum diski (keçe kaplı
## ahşap altlık). Yuvalar ekran koordinatında tanımlanır, kameradan dünyaya izdüşürülür
## (diorama ile aynı dünya: aynı ışık, aynı gölge, aynı paralaks).

const DISC_SEGMENTS: int = 64

var _discs: Array[MeshInstance3D] = []
var _rims: Array[MeshInstance3D] = []
var _felt: StandardMaterial3D
var _wood: Material


func _ready() -> void:
	_felt = StandardMaterial3D.new()
	_felt.albedo_color = Color(0.62, 0.56, 0.5)
	_felt.roughness = 0.92
	_felt.rim_enabled = true
	_felt.rim = 0.25
	_felt.rim_tint = 0.6
	_wood = load("res://assets/materials/wood_walnut.tres") as Material


## Yuva sayısı kadar disk hazırlar (fazlası gizlenir).
func set_slot_count(n: int) -> void:
	while _discs.size() < n:
		var rim: MeshInstance3D = MeshInstance3D.new()
		var rim_mesh: CylinderMesh = CylinderMesh.new()
		rim_mesh.radial_segments = DISC_SEGMENTS
		rim_mesh.rings = 1
		rim.mesh = rim_mesh
		rim.material_override = _wood
		add_child(rim)
		_rims.append(rim)
		var disc: MeshInstance3D = MeshInstance3D.new()
		var disc_mesh: CylinderMesh = CylinderMesh.new()
		disc_mesh.radial_segments = DISC_SEGMENTS
		disc_mesh.rings = 1
		disc.mesh = disc_mesh
		disc.material_override = _felt
		add_child(disc)
		_discs.append(disc)
	for i: int in _discs.size():
		_discs[i].visible = i < n
		_rims[i].visible = i < n
		_rims[i].set_meta(&"used", i < n)
		_discs[i].set_meta(&"empty_alpha", 0.0)
		_discs[i].transparency = 0.0
		_rims[i].transparency = 0.0


## i. yuvanın diski: üst yüz merkezi `top_center`, yarıçap `radius` (dünya).
func place_slot(i: int, top_center: Vector3, radius: float) -> void:
	if i < 0 or i >= _discs.size():
		return
	var rim_h: float = radius * 0.16
	var rim_mesh: CylinderMesh = _rims[i].mesh as CylinderMesh
	rim_mesh.top_radius = radius
	rim_mesh.bottom_radius = radius * 0.93
	rim_mesh.height = rim_h
	_rims[i].global_position = top_center - Vector3(0.0, rim_h * 0.5 + radius * 0.01, 0.0)
	var disc_mesh: CylinderMesh = _discs[i].mesh as CylinderMesh
	disc_mesh.top_radius = radius * 0.9
	disc_mesh.bottom_radius = radius * 0.9
	disc_mesh.height = radius * 0.03
	_discs[i].global_position = top_center - Vector3(0.0, radius * 0.005, 0.0)


## Yuva boşken (cihaz odada) disk hafifçe söner.
func set_slot_empty(i: int, empty: bool) -> void:
	if i < 0 or i >= _discs.size():
		return
	_discs[i].set_meta(&"empty_alpha", 0.35 if empty else 0.0)
	_discs[i].transparency = 0.35 if empty else 0.0


## Kazanma sahnesinde tepsi yavaşça kaybolur (0 görünür, 1 kayıp); yeni seviyede geri gelir.
func set_faded(v: float) -> void:
	for i: int in _discs.size():
		_discs[i].transparency = maxf(v, _discs[i].get_meta(&"empty_alpha", 0.0) as float)
		_rims[i].transparency = v
		_discs[i].visible = v < 0.99 and _rims[i].get_meta(&"used", true) as bool
		_rims[i].visible = _discs[i].visible
