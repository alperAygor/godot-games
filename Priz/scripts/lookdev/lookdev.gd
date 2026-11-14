extends Node

## Görünüm geliştirme sahnesi: oda + sekiz cihaz + sigorta kutusu + sallanan fiş kablosu.
## autoplay açıkken dört dilimi döngüyle gezer, cihazları açıp kapatır, titreme, karartma ve
## kazanma sahnesini gösterir. Klavye (masaüstü denemesi):
##   1-4 dilim · A cihazlar · F titreme · B karartma · W kazanma · Q kalite · fare = paralaks

@export var autoplay: bool = true

const APPLIANCES: Array[Array] = [
	["fridge", "res://scripts/fx/fridge_fx.gd", "Anchor_Fridge", 2],
	["oven", "res://scripts/fx/oven_fx.gd", "Anchor_Oven", 1],
	["washer", "res://scripts/fx/washer_fx.gd", "Anchor_Washer", 1],
	["kettle", "res://scripts/fx/kettle_fx.gd", "Anchor_Kettle", 1],
	["toaster", "res://scripts/fx/toaster_fx.gd", "Anchor_Toaster", 1],
	["tv", "res://scripts/fx/tv_fx.gd", "Anchor_TV", 3],
	["fan", "res://scripts/fx/fan_fx.gd", "Anchor_Fan", 2],
	["lamp", "res://scripts/fx/lamp_fx.gd", "Anchor_Lamp", 3],
]
const PLUG_SCENE: PackedScene = preload("res://assets/models/appliances/plug.glb")
const PLUG_MAT: Material = preload("res://assets/materials/cable_plug.tres")

@onready var view: RoomView = $RoomView

var appliances: Dictionary = {}  # id -> Appliance
var fuse_box: FuseBox
var demo_plug: Node3D
var demo_cable: PlugCable
var _time: float = 0.0
var _step: int = -1
var _plug_drag: bool = true
var _plug_seat_socket: String = "Socket_06"


func _ready() -> void:
	for entry: Array in APPLIANCES:
		var script: GDScript = load(String(entry[1])) as GDScript
		var a: Appliance = script.new() as Appliance
		a.name = String(entry[0]).capitalize()
		view.place_at_anchor(a, String(entry[2]))
		appliances[String(entry[0])] = a
	fuse_box = FuseBox.new()
	fuse_box.name = "FuseBox"
	view.place_at_anchor(fuse_box, "Anchor_FuseBox")
	fuse_box.set_line_count(3)
	fuse_box.set_line_capacity(1, 6)
	fuse_box.set_line_capacity(2, 5)
	fuse_box.set_line_capacity(3, 4)
	_build_demo_plug()


## Fiş + fiziksel kablo: vantilatörden çıkıp sürükleniyormuş gibi sallanır.
func _build_demo_plug() -> void:
	demo_plug = PLUG_SCENE.instantiate() as Node3D
	demo_plug.name = "DemoPlug"
	view.appliances_root.add_child(demo_plug)
	demo_cable = PlugCable.new()
	demo_cable.name = "DemoCable"
	demo_cable.cable_material = PLUG_MAT
	var fan: Appliance = appliances.get("fan", null) as Appliance
	if fan != null:
		demo_cable.start_node = fan.get_plug_anchor()
	demo_cable.end_node = demo_plug.find_child("CableAnchor", true, false) as Node3D
	view.appliances_root.add_child(demo_cable)
	_update_plug(0.0)
	demo_cable.snap_to_rest()


func set_all_running(on: bool) -> void:
	for a: Appliance in appliances.values():
		a.set_running(on)


func set_running(id: String, on: bool) -> void:
	var a: Appliance = appliances.get(id, null) as Appliance
	if a != null:
		a.set_running(on)


## Hat yükünü göstermelik doldurur (çalışan cihazların yaklaşık blok yükü).
func update_gauges() -> void:
	var load_by_line: Array[float] = [0.0, 0.0, 0.0]
	var loads: Dictionary = {"fridge": 2.0, "oven": 3.0, "washer": 2.0, "kettle": 1.0, "toaster": 1.0, "tv": 1.0,
		"fan": 1.0, "lamp": 1.0}
	for entry: Array in APPLIANCES:
		var a: Appliance = appliances[String(entry[0])] as Appliance
		if a.is_running():
			load_by_line[int(entry[3]) - 1] += float(loads[String(entry[0])])
	var caps: Array[float] = [6.0, 5.0, 4.0]
	for i: int in range(3):
		var r: float = load_by_line[i] / caps[i]
		fuse_box.set_line_fill(i + 1, r)
		view.set_line_glow(i + 1, 0.0 if r <= 0.0 else (1.0 + 1.5 * smoothstep(0.75, 1.0, r)))


func _process(delta: float) -> void:
	_time += delta
	if _plug_drag:
		_update_plug(_time)
	if autoplay:
		_autoplay()
	update_gauges()


func _update_plug(t: float) -> void:
	if demo_plug == null:
		return
	# Prizin önünde "sürüklenen" fiş: yumuşak sekiz çizer
	# Halının önünde, vantilatörün yanında havada sallanan fiş (sürükleme benzetimi)
	var base: Vector3 = view.to_global(Vector3(4.15, 0.42, 3.35))
	var p: Vector3 = base + Vector3(0.14 * sin(t * 1.3), 0.1 + 0.07 * sin(t * 2.6), 0.16 * cos(t * 1.3))
	demo_plug.global_position = p
	demo_plug.global_basis = Basis(Vector3.UP, deg_to_rad(40.0 + 15.0 * sin(t * 0.9)))


## Fişi dünya noktasında sabit tutar (görünüm aracı); kablo sarkıp sallanmaya devam eder.
func hold_plug(world_pos: Vector3, yaw_deg: float = 30.0) -> void:
	_plug_drag = false
	demo_plug.global_position = world_pos
	demo_plug.global_basis = Basis(Vector3.UP, deg_to_rad(yaw_deg))


## Fişi prize oturtur (görünüm aracı ve demo için).
func seat_plug(socket_id: String) -> void:
	var s: Node3D = view.get_socket(socket_id)
	if s == null or demo_plug == null:
		return
	_plug_drag = false
	demo_plug.global_transform = s.global_transform


func _autoplay() -> void:
	# Zaman çizelgesi (saniye): döngü 36 sn
	var cycle: float = fmod(_time, 36.0)
	var step: int = int(cycle / 3.0)
	if step == _step:
		return
	_step = step
	match step:
		0:
			view.day_light.set_slice(DayLight.Slice.MORNING, 2.0)
			fuse_box.set_slice_dial(0)
			set_all_running(false)
			set_running("fridge", true)
			set_running("kettle", true)
		1:
			set_running("toaster", true)
		2:
			view.day_light.set_slice(DayLight.Slice.NOON, 2.0)
			fuse_box.set_slice_dial(1)
			set_running("kettle", false)
			set_running("toaster", false)
			set_running("washer", true)
			set_running("fan", true)
		3:
			set_running("oven", true)
			view.day_light.flicker(0.8, 1.5)
		4:
			view.day_light.set_slice(DayLight.Slice.EVENING, 2.0)
			fuse_box.set_slice_dial(2)
			set_running("tv", true)
			set_running("lamp", true)
		5:
			fuse_box.trip(1)
			view.day_light.blackout(1.2)
		6:
			fuse_box.set_breaker(1, true)
			view.day_light.set_slice(DayLight.Slice.NIGHT, 2.0)
			fuse_box.set_slice_dial(3)
		7:
			set_all_running(true)
			fuse_box.set_main_lever(true)
		8:
			view.day_light.play_win(3.6)
		10:
			fuse_box.set_main_lever(false)
			view.camera_rig.reset_view()


func _unhandled_input(event: InputEvent) -> void:
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		var vs: Vector2 = get_viewport().get_visible_rect().size
		view.camera_rig.set_parallax((mm.position / vs - Vector2(0.5, 0.5)) * 2.0)
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed:
		return
	autoplay = false
	match k.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4:
			var s: int = int(k.keycode - KEY_1)
			view.day_light.set_slice(s, 1.6)
			fuse_box.set_slice_dial(s)
		KEY_A:
			var any_on: bool = false
			for a: Appliance in appliances.values():
				any_on = any_on or a.is_running()
			set_all_running(not any_on)
		KEY_F:
			view.day_light.flicker(1.0, 1.5)
		KEY_B:
			fuse_box.trip(1)
			view.day_light.blackout()
		KEY_W:
			if view.day_light.is_win_playing():
				view.day_light.skip_win()
			else:
				view.day_light.play_win(3.6)
		KEY_Q:
			view.set_quality((view.quality + 2) % 3)
			print("kalite: ", QualityTiers.TIER_NAMES[view.quality])
