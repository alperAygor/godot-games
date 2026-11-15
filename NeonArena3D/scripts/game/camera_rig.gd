extends GameModule
class_name CameraRig
## Kamera: menüde gemi çevresinde süzülme, oyunda nişan yönüne öne bakış + boss yakınlaştırma + sarsıntı;
## fare nişanı (ekran → zemin düzlemi) ve nişan halkası.

const CAM_OFFSET := Vector3(0.0, 19.5, 13.0)

var camera: Camera3D
var rig: Node3D
var aim_marker: MeshInstance3D
var _cam_lead := Vector2.ZERO
var _cam_basis := Basis.IDENTITY
var _zoom := 1.0

func build(parent: Node3D) -> void:
	## Sahne sırası korunur: önce kamera düzeneği, sonra nişan halkası.
	rig = Node3D.new()
	_cam_basis = Basis.looking_at(Vector3(0.0, 0.0, 0.8) - CAM_OFFSET, Vector3.UP)
	rig.position = ArenaSpace.to_world(ARENA.get_center(), 0.0) + CAM_OFFSET
	rig.basis = _cam_basis
	parent.add_child(rig)
	camera = Camera3D.new()
	camera.fov = 46.0
	camera.near = 0.3
	camera.far = 260.0
	rig.add_child(camera)
	camera.current = true
	aim_marker = _make_aim_marker()
	parent.add_child(aim_marker)
	aim_marker.visible = false

func reset_run() -> void:
	_cam_lead = Vector2.ZERO

func snap_to(pos2: Vector2) -> void:
	## Harita değişiminde kamerayı oyuncunun üstüne ışınla.
	rig.position = ArenaSpace.to_world(pos2, 0.0) + CAM_OFFSET * _zoom

func _make_aim_marker() -> MeshInstance3D:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.36
	torus.outer_radius = 0.44
	torus.rings = 24
	torus.ring_segments = 4
	var node := MeshInstance3D.new()
	node.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(0.9, 1.5, 1.7, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

func update(delta: float) -> void:
	var shake := Fx.offset()
	var player := ctx.player
	var elapsed := ctx.elapsed
	if ctx.state == "menu":
		var ship: Vector3 = player.position
		var ang := elapsed * 0.14 + 0.5
		var want := ship + Vector3(sin(ang) * 9.0, 3.4 + sin(elapsed * 0.3) * 0.5, cos(ang) * 9.0)
		rig.position = rig.position.lerp(want, clampf(delta * 2.5, 0.0, 1.0))
		var right: Vector3 = rig.global_transform.basis.x
		var look := Basis.looking_at((ship - right * 2.9 + Vector3(0, 0.5, 0)) - rig.position, Vector3.UP)
		rig.basis = rig.basis.orthonormalized().slerp(look, clampf(delta * 4.0, 0.0, 1.0))
		camera.fov = lerpf(camera.fov, 50.0, clampf(delta * 3.0, 0.0, 1.0))
		camera.position = Vector3.ZERO
		return
	var lead: Vector2 = player.aim2 * 44.0 + player.velocity2 * 0.13
	_cam_lead = _cam_lead.lerp(lead, clampf(delta * 2.4, 0.0, 1.0))
	var focus2: Vector2 = player.pos2 + _cam_lead
	var zoom_target := 1.0
	var boss := ctx.boss
	if boss != null and is_instance_valid(boss) and boss.alive:
		zoom_target = 1.13
		if boss.pos2.distance_to(player.pos2) < 900.0:
			focus2 = focus2.lerp(boss.pos2, 0.16)
	_zoom = lerpf(_zoom, zoom_target, clampf(delta * 1.4, 0.0, 1.0))
	var margin := Vector2(380.0, 290.0)
	focus2.x = clampf(focus2.x, ARENA.position.x + margin.x, ARENA.end.x - margin.x)
	focus2.y = clampf(focus2.y, ARENA.position.y + margin.y, ARENA.end.y - margin.y)
	var focus := ArenaSpace.to_world(focus2, 0.0)
	rig.position = rig.position.lerp(focus + CAM_OFFSET * _zoom, clampf(delta * 6.0, 0.0, 1.0))
	rig.basis = rig.basis.orthonormalized().slerp(_cam_basis, clampf(delta * 5.0, 0.0, 1.0))
	camera.fov = lerpf(camera.fov, 46.0, clampf(delta * 3.0, 0.0, 1.0))
	camera.position = Vector3(shake.x, shake.y, 0.0) * 0.013

func mouse_aim() -> Vector2:
	var player := ctx.player
	var mouse := ctx.host.get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var normal := camera.project_ray_normal(mouse)
	var plane := Plane(Vector3.UP, 1.0)
	var hit: Variant = plane.intersects_ray(origin, normal)
	if hit == null:
		return player.pos2 + player.aim2 * 200.0
	return ArenaSpace.to_plane(hit)

func update_aim_marker(delta: float, locked: Variant, aim_target: Vector2) -> void:
	if ctx.options.demo:
		aim_marker.visible = false
		return
	aim_marker.rotation.y += delta * 2.5
	if Settings.touch:
		if locked != null:
			var lp: Vector2 = locked.pos2
			var lr: float = locked.radius
			aim_marker.visible = true
			aim_marker.position = ArenaSpace.to_world(lp, 0.12)
			var k := lr / ArenaSpace.SCALE * 2.9 * (1.0 + 0.08 * sin(ctx.elapsed * 9.0))
			aim_marker.scale = Vector3(k, 1.0, k)
		else:
			aim_marker.visible = false
	else:
		aim_marker.visible = true
		aim_marker.scale = Vector3.ONE
		aim_marker.position = ArenaSpace.to_world(aim_target, 0.06)
