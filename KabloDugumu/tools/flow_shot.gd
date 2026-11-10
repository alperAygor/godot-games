extends SceneTree

## Faz B kabul aracı: Boot -> Menu -> LevelSelect -> Menu -> Game -> (kıvılcım,
## kalkan, GERÇEK SÜRÜKLEME) -> fail -> retry -> win -> Result akışını sürer ve
## her adımda PNG alır. Headless ÇALIŞMAZ — gerçek pencere gerekir.
##
##   godot --path . -s res://tools/flow_shot.gd -- --out-dir=/tmp/kablo_shots
##
## Plan koşul bekler: sahne/oyun hazır olmadan adım ilerlemez. Zaman aşımında
## adım atlanır ve uyarı yazılır; çıktı kareleri yine montaja girer.
## Çıkış: 0 = en az MIN_SHOTS kare alındı, 1 = kritik hata.

const MIN_SHOTS: int = 6
## Bir adımın koşulunun gerçekleşmesi için tanınan süre (sn).
const STEP_TIMEOUT: float = 5.0
## Tüm akış için sert sınır.
const DEADLINE: float = 90.0
const BOOT_SCENE: String = "res://scenes/Boot.tscn"
## Gerçek sürükleme simülasyonu: parmak kaç karede hedefe gitsin.
const DRAG_FRAMES: int = 16
## Bırakmadan sonra snap kararının oturması için beklenecek kare.
const DRAG_SETTLE_FRAMES: int = 8
## Drag-temas testinde teması canlı tutma süresi (kare) — bar dolumu için.
const CONTACT_HOLD_FRAMES: int = 45
## Basılınca sahne değiştiren butonlar: yeni sahne örneği beklenir.
const SCENE_BUTTONS: Array[String] = [
	"PlayButton", "RetryButton", "NextButton", "MenuButton", "BackButton", "LevelsButton",
]

var _plan: Array[Dictionary] = []
var _index: int = 0
var _elapsed: float = 0.0
var _out_dir: String = "/tmp/kablo_shots"
var _done: bool = false
var _shots: Array[String] = []
var _warnings: Array[String] = []
## Sahne değiştiren aksiyondan sonra eski örnek: yeni örnek beklenir.
var _expect_new_instance: int = 0
var _last_state: Dictionary = {}

## Adım başına kare sayacı (settle_frames koşulu için).
var _step_frame: int = 0
var _step_seen: int = -1

## Profil yedeği: akış deterministik bölüm 1'de başlasın diye yıldızlar
## yedeklenip geçici sıfırlanır; akış sonunda diske geri yazılır.
var _profile_backup: Dictionary = {}
var _profile_frozen: bool = false

## Gerçek sürükleme doğrulaması durumu.
var _drag_phase: int = 0
var _drag_frame: int = 0
var _drag_start: Vector2 = Vector2.ZERO
var _drag_end: Vector2 = Vector2.ZERO
var _drag_cable: int = -1
var _drag_before: Dictionary = {}
## İkinci drag testi: sürüklerken başka renkli kabloya temas (shorts + bar).
var _contact_phase: int = 0
var _contact_frame: int = 0
var _contact_start: Vector2 = Vector2.ZERO
var _contact_end: Vector2 = Vector2.ZERO
var _contact_cable: int = -1
var _contact_target: int = -1
var _contact_before: Dictionary = {}


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out-dir="):
			_out_dir = arg.trim_prefix("--out-dir=")
	if DisplayServer.get_name() == "headless":
		printerr("FLOW FAIL: headless modda ekran görüntüsü alınamaz; gerçek pencere gerekir")
		_finish(1)
		return
	# Pencere başka uygulamanın arkasında kalırsa macOS çizimi durdurabilir:
	# kareler donuk (aynı sha) gelirdi. Bu yüzden akış boyunca önde tutulur.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DisplayServer.window_move_to_foreground()
	_freeze_profile()
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_clear_old_pngs()
	_plan = _build_plan()
	var packed: PackedScene = load(BOOT_SCENE) as PackedScene
	if packed == null:
		printerr("FLOW FAIL: %s yüklenemedi" % BOOT_SCENE)
		_finish(1)
		return
	var scene: Node = packed.instantiate()
	if scene == null:
		printerr("FLOW FAIL: %s örneklenemedi" % BOOT_SCENE)
		_finish(1)
		return
	root.add_child(scene)
	current_scene = scene
	print("FLOW out_dir: %s (%d adım)" % [_out_dir, _plan.size()])


func _process(delta: float) -> bool:
	if _done:
		return true
	# Autoload'lar _initialize sırasında henüz _ready olmamış olabilir: profil
	# temizliğini ilk karede (GameManager.profile hazırken) yap.
	if not _profile_frozen:
		_profile_frozen = true
		_freeze_profile()
	_elapsed += delta
	if _elapsed > DEADLINE:
		_warn("genel zaman aşımı (%.1f sn), %d/%d adım" % [DEADLINE, _index, _plan.size()])
		_finish(1)
		return true
	while _index < _plan.size():
		if _index != _step_seen:
			_step_seen = _index
			_step_frame = 0
		_step_frame += 1
		var step: Dictionary = _plan[_index]
		var due: float = float(step.get("at", 0.0))
		if _elapsed < due:
			break
		var result: int = _try_step(step)
		if result == 1:
			_index += 1
			continue
		if result == 0:
			break
		# result == 2: zaman aşımı; uyarı yazıldı, sonraki adıma geç.
		_index += 1
	if _index >= _plan.size():
		_finish(0)
		return true
	return false


func _try_step(step: Dictionary) -> int:
	# Koşullu aksiyon: yalnızca verilen oyun durumunda çalışır.
	if step.has("only_if_state"):
		if String(_game_state().get("state", "")) != String(step["only_if_state"]):
			return 1
	# Koşullar aksiyondan ÖNCE: force_snap gibi bir aksiyon kendi koşulunu
	# (ör. state=playing) anında geçersiz kılabilir.
	var conditions_ok: bool = _conditions_met(step)
	var timed_out: bool = _elapsed > float(step.get("at", 0.0)) + STEP_TIMEOUT
	if step.has("shot"):
		if conditions_ok:
			_capture(String(step["shot"]))
			return 1
		if timed_out:
			_warn("adım zaman aşımı, kare atlandı: %s (%s)"
				% [String(step["shot"]), _conditions_text(step)])
			if not bool(step.get("skip_on_timeout", false)):
				_capture(String(step["shot"]) + "_timeout")
			return 2
		return 0
	if not conditions_ok:
		if timed_out:
			_warn("adım zaman aşımı, atlandı: %s (%s)" % [_step_text(step), _conditions_text(step)])
			return 2
		return 0
	if _perform(step):
		return 1
	if timed_out:
		_warn("adım gerçekleşmedi, atlandı: %s" % _step_text(step))
		return 2
	return 0


## Adımın koşulları sağlandı mı? (sahne, oyun hazır, durum, bar, kalkan, temas)
func _conditions_met(step: Dictionary) -> bool:
	if step.has("settle_frames"):
		if _step_frame < int(step["settle_frames"]):
			return false
	if step.has("wait_scene"):
		if not _scene_matches(String(step["wait_scene"])):
			return false
		if _expect_new_instance != 0:
			if current_scene != null and current_scene.get_instance_id() == _expect_new_instance:
				return false
			_expect_new_instance = 0
	if step.has("wait_game"):
		if not _game_ready():
			return false
	if step.has("wait_state"):
		if String(_game_state().get("state", "")) != String(step["wait_state"]):
			return false
	if step.has("wait_connected"):
		var state: Dictionary = _game_state()
		var total: int = int(state.get("total", 0))
		if total <= 0 or int(state.get("connected", 0)) != total:
			return false
	if step.has("wait_overload"):
		var state: Dictionary = _game_state()
		if float(state.get("overload", 0.0)) < float(step["wait_overload"]):
			return false
	if step.has("wait_shorts_gt"):
		if int(_game_state().get("shorts", 0)) <= int(step["wait_shorts_gt"]):
			return false
	if step.has("wait_shield"):
		if _shield_left() < float(step["wait_shield"]):
			return false
	return true


func _perform(step: Dictionary) -> bool:
	if step.has("contact"):
		var pair: Array = step["contact"] as Array
		if pair.size() < 2:
			return false
		return _contact(int(pair[0]), int(pair[1]))
	if step.has("snap"):
		for value: Variant in step["snap"] as Array:
			if not _snap(int(value)):
				return false
		return true
	if step.has("snap_rest"):
		if not _game_ready():
			return false
		var state: Dictionary = _game_state()
		for i: int in int(state.get("total", 0)):
			_snap(i)  # zaten bağlıysa false döner; hata değil
		return true
	if step.has("drag_verify"):
		return _drag_verify()
	if step.has("drag_contact_verify"):
		return _drag_contact_verify()
	if step.has("force_overload"):
		return _force_overload(float(step["force_overload"]))
	if step.has("press"):
		return _press(String(step["press"]))
	if step.has("call"):
		return _invoke(String(step["call"]))
	return true


# --- gerçek sürükleme ------------------------------------------------------

## Oyuncu yolunu (kamera unproject + sürükleme düzlemi + bırakma/snap) taklit
## eder: touch press -> 16 kare ScreenDrag -> release; sonra debug_state kontrolü.
func _drag_verify() -> bool:
	if _drag_phase == 0:
		return _drag_begin()
	if _drag_phase == 1:
		return _drag_advance()
	if _drag_phase == 2:
		return _drag_check()
	return false


func _drag_begin() -> bool:
	if current_scene == null or not _game_ready():
		return false
	if String(_game_state().get("state", "")) != "playing":
		return false
	var camera: Camera3D = current_scene.get_node_or_null("CameraRig/Camera3D") as Camera3D
	var level: Variant = current_scene.get("_level")
	if camera == null or not (level is Object):
		_warn("drag: kamera ya da _level erişilemedi")
		return true
	var cables_variant: Variant = (level as Object).get("cables")
	if not (cables_variant is Array):
		_warn("drag: cables dizisi yok")
		return true
	var cables: Array = cables_variant as Array
	var chosen: Object = null
	var chosen_index: int = -1
	for i: int in cables.size():
		var cable_variant: Variant = cables[i]
		if not (cable_variant is Object):
			continue
		var cable: Object = cable_variant as Object
		if bool(cable.call("is_linked")) or not bool(cable.call("is_grabbable")):
			continue
		chosen = cable
		chosen_index = i
		break
	if chosen == null:
		_warn("drag: sürüklenecek boşta kablo bulunamadı")
		return true
	var lift: float = 0.3
	var plane_variant: Variant = current_scene.get("_drag_plane")
	if typeof(plane_variant) == TYPE_PLANE:
		var plane: Plane = plane_variant
		lift = plane.d
	var plug: Vector3 = chosen.call("plug_position")
	var socket: Vector3 = chosen.call("socket_position")
	# Sürükleme düzlemindeki (z=lift) karşılık gelen dünya noktaları unproject edilir.
	# unproject VIEWPORT koordinatı verir; girdi olayları PENCERE koordinatı bekler
	# (stretch canvas_items: 1080x1920 -> 540x960 pencerede 0.5 ölçek).
	_drag_start = _to_input_position(camera.unproject_position(Vector3(plug.x, plug.y, lift)))
	_drag_end = _to_input_position(camera.unproject_position(Vector3(socket.x, socket.y, lift)))
	_drag_cable = chosen_index
	_drag_before = _game_state().duplicate(true)
	_send_touch(true, _drag_start)
	_drag_phase = 1
	_drag_frame = 0
	print("DRAG begin cable=%d start=%s end=%s" % [chosen_index, str(_drag_start), str(_drag_end)])
	return false


func _drag_advance() -> bool:
	_drag_frame += 1
	var previous_t: float = clampf(float(_drag_frame - 1) / float(DRAG_FRAMES), 0.0, 1.0)
	var current_t: float = clampf(float(_drag_frame) / float(DRAG_FRAMES), 0.0, 1.0)
	var previous: Vector2 = _drag_start.lerp(_drag_end, previous_t)
	var position: Vector2 = _drag_start.lerp(_drag_end, current_t)
	_send_drag(position, position - previous)
	if _drag_frame >= DRAG_FRAMES:
		_send_touch(false, _drag_end)
		_drag_phase = 2
		_drag_frame = 0
	return false


func _drag_check() -> bool:
	_drag_frame += 1
	if _drag_frame < DRAG_SETTLE_FRAMES:
		return false
	var state: Dictionary = _game_state()
	var connected: int = int(state.get("connected", 0))
	var before: int = int(_drag_before.get("connected", 0))
	var shorts: int = int(state.get("shorts", 0))
	var overload: float = float(state.get("overload", 0.0))
	if connected > before:
		print("DRAG PASS: cable=%d connected=%d->%d shorts=%d overload=%.2f state=%s"
			% [_drag_cable, before, connected, shorts, overload, String(state.get("state", ""))])
	else:
		_warn("drag başarısız: cable=%d connected=%d, shorts=%d, overload=%.2f"
			% [_drag_cable, connected, shorts, overload])
	_drag_phase = 0
	return true


## İkinci gerçek-drag testi: bir kabloyu farklı renkli başka bir kabloya doğru
## sürükle, ~0.8 sn temas ettir; ContactMonitor shorts sayacı ve aşırı yük barı
## artmalı (requires_drag kuralı sürükleyen kabloyla sağlanır).
func _drag_contact_verify() -> bool:
	if _contact_phase == 0:
		return _contact_begin()
	if _contact_phase == 1:
		return _contact_advance()
	if _contact_phase == 2:
		return _contact_check()
	return false


func _contact_begin() -> bool:
	if current_scene == null or not _game_ready():
		return false
	if String(_game_state().get("state", "")) != "playing":
		return false
	var camera: Camera3D = current_scene.get_node_or_null("CameraRig/Camera3D") as Camera3D
	var level: Variant = current_scene.get("_level")
	if camera == null or not (level is Object):
		_warn("drag-temas: kamera ya da _level erişilemedi")
		return true
	var cables_variant: Variant = (level as Object).get("cables")
	if not (cables_variant is Array):
		_warn("drag-temas: cables dizisi yok")
		return true
	var cables: Array = cables_variant as Array
	var drag_index: int = -1
	var target_index: int = -1
	for i: int in cables.size():
		var cable_variant: Variant = cables[i]
		if not (cable_variant is Object):
			continue
		var cable: Object = cable_variant as Object
		if bool(cable.call("is_linked")) or not bool(cable.call("is_grabbable")):
			continue
		if drag_index < 0:
			drag_index = i
			continue
		var color_a: StringName = _cable_color(cables[drag_index])
		var color_b: StringName = _cable_color(cable_variant)
		if color_a != color_b and color_a != &"" and color_b != &"":
			target_index = i
			break
	if drag_index < 0 or target_index < 0:
		_warn("drag-temas: farklı renkli iki boşta kablo bulunamadı")
		return true
	var lift: float = 0.3
	var plane_variant: Variant = current_scene.get("_drag_plane")
	if typeof(plane_variant) == TYPE_PLANE:
		var plane: Plane = plane_variant
		lift = plane.d
	var plug_a: Vector3 = (cables[drag_index] as Object).call("plug_position")
	var plug_b: Vector3 = (cables[target_index] as Object).call("plug_position")
	_contact_start = _to_input_position(camera.unproject_position(Vector3(plug_a.x, plug_a.y, lift)))
	_contact_end = _to_input_position(camera.unproject_position(Vector3(plug_b.x, plug_b.y, lift)))
	_contact_cable = drag_index
	_contact_target = target_index
	_contact_before = _game_state().duplicate(true)
	_send_touch(true, _contact_start)
	_contact_phase = 1
	_contact_frame = 0
	print("DRAG-TEMAS begin cable=%d hedef=%d start=%s end=%s"
		% [drag_index, target_index, str(_contact_start), str(_contact_end)])
	return false


func _contact_advance() -> bool:
	_contact_frame += 1
	if _contact_frame == DRAG_FRAMES + CONTACT_HOLD_FRAMES:
		print("DRAG-TEMAS mid: %s" % str(_game_state()))
	if _contact_frame <= DRAG_FRAMES:
		var t: float = clampf(float(_contact_frame) / float(DRAG_FRAMES), 0.0, 1.0)
		var previous_t: float = clampf(float(_contact_frame - 1) / float(DRAG_FRAMES), 0.0, 1.0)
		var previous: Vector2 = _contact_start.lerp(_contact_end, previous_t)
		var position: Vector2 = _contact_start.lerp(_contact_end, t)
		_send_drag(position, position - previous)
		return false
	var held: int = _contact_frame - DRAG_FRAMES
	if held <= CONTACT_HOLD_FRAMES:
		# Teması canlı tut: küçük dairesel titreme (tarama her karede çalışır).
		var wobble: Vector2 = Vector2(sin(float(held) * 0.6), cos(float(held) * 0.6)) * 2.0
		_send_drag(_contact_end + wobble, wobble)
		return false
	_send_touch(false, _contact_end)
	_contact_phase = 2
	_contact_frame = 0
	return false


func _contact_check() -> bool:
	_contact_frame += 1
	if _contact_frame < DRAG_SETTLE_FRAMES:
		return false
	var state: Dictionary = _game_state()
	var shorts_before: int = int(_contact_before.get("shorts", 0))
	var overload_before: float = float(_contact_before.get("overload", 0.0))
	var shorts: int = int(state.get("shorts", 0))
	var overload: float = float(state.get("overload", 0.0))
	var pass_shorts: bool = shorts > shorts_before
	var pass_bar: bool = overload > overload_before
	print("DRAG-TEMAS cable=%d hedef=%d shorts %d->%d overload %.2f->%.2f state=%s"
		% [_contact_cable, _contact_target, shorts_before, shorts, overload_before,
			overload, String(state.get("state", ""))])
	if pass_shorts and pass_bar:
		print("DRAG-TEMAS PASS: shorts arttı ve bar doldu")
	elif pass_shorts or pass_bar:
		_warn("drag-temas kısmi: shorts=%s bar=%s" % [str(pass_shorts), str(pass_bar)])
	else:
		_warn("drag-temas başarısız: ne shorts ne bar arttı")
	_contact_phase = 0
	return true


func _cable_color(cable: Variant) -> StringName:
	if not (cable is Object):
		return &""
	var spec: Variant = (cable as Object).get("spec")
	if spec == null or not (spec is Object):
		return &""
	var color_id: Variant = (spec as Object).get("color_id")
	if color_id is StringName:
		return color_id as StringName
	return StringName(str(color_id))


## Viewport (1080x1920) koordinatını pencere/input (540x960) koordinatına çevirir.
func _to_input_position(viewport_position: Vector2) -> Vector2:
	var viewport_size: Vector2 = root.get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return viewport_position
	var window_size: Vector2 = Vector2(DisplayServer.window_get_size())
	return viewport_position * (window_size / viewport_size)


func _send_touch(pressed: bool, position: Vector2) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = 0
	event.pressed = pressed
	event.position = position
	Input.parse_input_event(event)


func _send_drag(position: Vector2, relative: Vector2) -> void:
	var event: InputEventScreenDrag = InputEventScreenDrag.new()
	event.index = 0
	event.position = position
	event.relative = relative
	Input.parse_input_event(event)


# --- aksiyonlar ------------------------------------------------------------

func _capture(shot_name: String) -> void:
	# Pencere önde olsa da son çizilen kareyi garanti et.
	RenderingServer.force_draw(true, 0.0)
	var image: Image = root.get_texture().get_image()
	if image == null:
		_warn("ekran görüntüsü alınamadı: %s" % shot_name)
		return
	var path: String = _out_dir.path_join(shot_name + ".png")
	var error: Error = image.save_png(path)
	if error != OK:
		_warn("PNG yazılamadı (%d): %s" % [error, path])
		return
	_shots.append(shot_name)
	print("SHOT %s t=%.2f drawn=%d" % [path, _elapsed, Engine.get_frames_drawn()])


func _press(node_name: String) -> bool:
	if current_scene == null:
		return false
	var node: Node = current_scene.find_child(node_name, true, false)
	if node == null:
		return false
	if not (node is Button):
		_warn("düğüm buton değil: %s" % node_name)
		return true
	if SCENE_BUTTONS.has(node_name) and current_scene != null:
		_expect_new_instance = current_scene.get_instance_id()
	(node as Button).pressed.emit()
	print("PRESS %s" % node_name)
	return true


func _contact(index_a: int, index_b: int) -> bool:
	if not _game_ready():
		return false
	var state: Dictionary = _game_state()
	var total: int = int(state.get("total", 0))
	if index_a >= total or index_b >= total or index_a == index_b:
		return false
	var game: Node = current_scene
	if not game.has_method("force_contact"):
		return false
	game.call("force_contact", index_a, index_b)
	print("CONTACT %d-%d" % [index_a, index_b])
	return true


func _snap(cable_index: int) -> bool:
	if not _game_ready():
		return false
	var game: Node = current_scene
	var snapped: bool = bool(game.call("force_snap", cable_index))
	if snapped:
		print("SNAP %d" % cable_index)
	return snapped


## QA: bar'ı doğrudan doldurur ve sigortayı attırır. Kalkan (yalıtım spreyi)
## aktifken de fail ekranı yakalanabilsin diye model doğrudan işaretlenir;
## normal oynanış kuralı değildir. LevelController bir sonraki fizik karesinde
## `blown` görüp `fuse_blown` yayar.
func _force_overload(amount: float) -> bool:
	if current_scene == null:
		return false
	if current_scene.has_method("force_overload"):
		current_scene.call("force_overload", amount)
		print("OVERLOAD api %.2f" % amount)
		return true
	var level: Variant = current_scene.get("_level")
	if not (level is Object):
		_warn("force_overload API'si yok ve _level erişilemedi")
		return true
	var model: Variant = (level as Object).get("overload")
	if not (model is Object):
		_warn("force_overload API'si yok ve overload erişilemedi")
		return true
	var target: float = clampf(amount, 0.0, 1.0)
	(model as Object).set("value", target)
	(model as Object).set("peak", maxf(float((model as Object).get("peak")), target))
	(model as Object).set("blown", target >= 1.0)
	print("OVERLOAD inject %.2f" % target)
	return true


## OverloadModel.shield_left (HUD kalkan göstergesi); debug_state'te yok.
func _shield_left() -> float:
	if current_scene == null:
		return 0.0
	var level: Variant = current_scene.get("_level")
	if not (level is Object):
		return 0.0
	var model: Variant = (level as Object).get("overload")
	if not (model is Object):
		return 0.0
	return float((model as Object).get("shield_left"))


func _invoke(target_method: String) -> bool:
	var parts: PackedStringArray = target_method.split(".", false, 1)
	if parts.size() != 2:
		_warn("geçersiz call adımı: %s" % target_method)
		return true
	var target: Node = root.get_node_or_null(parts[0])
	if target == null or not target.has_method(parts[1]):
		return false
	if current_scene != null:
		_expect_new_instance = current_scene.get_instance_id()
	target.call(parts[1])
	print("CALL %s" % target_method)
	return true


func _game_ready() -> bool:
	if current_scene == null:
		return false
	if not (current_scene.has_method("debug_state") and current_scene.has_method("force_snap")):
		return false
	return int(_game_state().get("total", 0)) > 0


func _game_state() -> Dictionary:
	if current_scene == null or not current_scene.has_method("debug_state"):
		return {}
	_last_state = current_scene.call("debug_state") as Dictionary
	return _last_state


func _scene_matches(expected: String) -> bool:
	if current_scene == null:
		return false
	if String(current_scene.name) == expected:
		return true
	var path: String = current_scene.scene_file_path
	return path != "" and path.get_file().get_basename() == expected


func _conditions_text(step: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for key: String in ["wait_scene", "wait_game", "wait_state", "wait_connected",
			"wait_overload", "wait_shorts_gt", "wait_shield", "settle_frames"]:
		if step.has(key):
			parts.append("%s=%s" % [key, str(step[key])])
	if parts.is_empty():
		return "koşul yok"
	return ", ".join(parts)


func _step_text(step: Dictionary) -> String:
	for key: String in ["contact", "snap", "snap_rest", "drag_verify",
			"drag_contact_verify", "force_overload", "press", "call"]:
		if step.has(key):
			return "%s=%s" % [key, str(step[key])]
	return "adım"


func _warn(message: String) -> void:
	_warnings.append(message)
	printerr("FLOW WARN: %s" % message)


func _clear_old_pngs() -> void:
	var dir: DirAccess = DirAccess.open(_out_dir)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		if file_name.ends_with(".png"):
			dir.remove(file_name)


## Akış boyunca profil geçici olarak boşaltılır (Oyna her zaman 1. bölümü açar).
## Disk yazımı akış sonundaki _restore_profile'da yapılır; çökme olursa kayıt bozulmaz.
func _freeze_profile() -> void:
	var manager: Node = root.get_node_or_null("GameManager")
	if manager == null:
		return
	var profile_variant: Variant = manager.get("profile")
	if not (profile_variant is Object):
		return
	var profile: Object = profile_variant as Object
	var stars: Variant = profile.get("best_stars")
	var times: Variant = profile.get("best_times")
	_profile_backup = {
		"stars": (stars as Dictionary).duplicate(true) if stars is Dictionary else {},
		"times": (times as Dictionary).duplicate(true) if times is Dictionary else {},
	}
	profile.set("best_stars", {})
	profile.set("best_times", {})
	print("FLOW profile: geçici sıfırlandı (%d yıldız yedeklendi)"
		% int((_profile_backup["stars"] as Dictionary).size()))


func _restore_profile() -> void:
	if _profile_backup.is_empty():
		return
	var manager: Node = root.get_node_or_null("GameManager")
	if manager == null:
		return
	var profile_variant: Variant = manager.get("profile")
	if not (profile_variant is Object):
		return
	var profile: Object = profile_variant as Object
	profile.set("best_stars", (_profile_backup["stars"] as Dictionary).duplicate(true))
	profile.set("best_times", (_profile_backup["times"] as Dictionary).duplicate(true))
	profile.call("save")
	print("FLOW profile: geri yüklendi")


func _finish(code: int) -> void:
	if _done:
		return
	_done = true
	_restore_profile()
	for warning: String in _warnings:
		print("FLOW WARN: %s" % warning)
	print("FLOW shots: %d/%d (min %d): %s" % [_shots.size(), _plan.size(), MIN_SHOTS, ", ".join(_shots)])
	print("FLOW last_state: %s" % JSON.stringify(_last_state))
	if code == 0 and _shots.size() < MIN_SHOTS:
		_warn("yetersiz kare: %d < %d" % [_shots.size(), MIN_SHOTS])
		code = 1
	print("FLOW %s" % ("PASS" if code == 0 else "FAIL"))
	quit(code)


## Akış planı: zamanlar alt sınırdır; koşullar sağlanana kadar adım bekler.
func _build_plan() -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	# Lead'in istediği kare seti: boot, menu, levelselect, game, kivilcim,
	# kalkan, gerçek sürükleme (2 test), fail, win, result.
	plan.append({"at": 0.20, "shot": "01_boot"})
	plan.append({"at": 0.70, "wait_scene": "Menu", "shot": "02_menu"})
	plan.append({"at": 0.95, "press": "LevelsButton"})
	plan.append({"at": 1.15, "wait_scene": "LevelSelect"})
	plan.append({"at": 1.35, "wait_scene": "LevelSelect", "shot": "03_levelselect"})
	plan.append({"at": 1.55, "press": "BackButton"})
	plan.append({"at": 1.70, "wait_scene": "Menu"})
	plan.append({"at": 1.90, "press": "PlayButton"})
	plan.append({"at": 2.10, "wait_scene": "Game"})
	plan.append({"at": 2.30, "wait_scene": "Game", "wait_game": true,
		"wait_state": "playing", "shot": "04_game"})
	# Kısa devre: force_contact sonrası 10 kare bekle + shorts artışını doğrula.
	plan.append({"at": 2.60, "wait_scene": "Game", "wait_state": "playing", "contact": [0, 1]})
	# 2 kare: SparkBurst ömrü 0.45 sn; patlama ilk karelerinde daha parlak/yoğun.
	plan.append({"at": 2.85, "wait_scene": "Game", "wait_shorts_gt": 0,
		"settle_frames": 2, "shot": "05_game_kivilcim"})
	# TEST 1 — GERÇEK sürükleme: InputEventScreenTouch/Drag, kamera unproject,
	# sürükleme düzlemi ve snap. force_snap hilesi YOK; connected +1 beklenir.
	plan.append({"at": 3.20, "wait_scene": "Game", "wait_state": "playing", "drag_verify": true})
	plan.append({"at": 3.60, "wait_scene": "Game", "wait_state": "playing", "shot": "05b_drag_snap"})
	# TEST 2 — sürüklerken farklı renkli kabloya temas: shorts artışı + bar dolumu.
	# (Kalkan henüz yok; requires_drag kuralı sürükleyen kabloyla sağlanır.)
	plan.append({"at": 4.00, "wait_scene": "Game", "wait_state": "playing",
		"drag_contact_verify": true})
	plan.append({"at": 5.20, "wait_scene": "Game", "wait_state": "playing", "shot": "05c_drag_temas"})
	# INSULATION_SPRAY: HUD butonu -> ödüllü reklam (mock) -> 10 sn kalkan.
	# Aynı adla ikinci deneme: %8 mock hatasında tekrar şans (limit tüketilmez).
	plan.append({"at": 5.60, "wait_scene": "Game", "wait_state": "playing", "press": "SprayButton"})
	plan.append({"at": 5.80, "wait_scene": "Game", "wait_shield": 1.0,
		"shot": "06_game_kalkan", "skip_on_timeout": true})
	plan.append({"at": 6.80, "wait_scene": "Game", "wait_state": "playing", "press": "SprayButton"})
	plan.append({"at": 7.00, "wait_scene": "Game", "wait_shield": 1.0,
		"shot": "06_game_kalkan", "skip_on_timeout": false})
	# Fail ekranı: bar'ı doldur; sonra HUD RetryButton ile yeni tur.
	plan.append({"at": 7.40, "wait_scene": "Game", "force_overload": 1.0})
	plan.append({"at": 7.70, "wait_scene": "Game", "wait_state": "failed", "shot": "07_fail"})
	plan.append({"at": 8.10, "press": "RetryButton"})
	plan.append({"at": 8.30, "wait_scene": "Game", "wait_game": true})
	plan.append({"at": 8.60, "wait_scene": "Game", "wait_state": "playing"})
	plan.append({"at": 9.00, "wait_scene": "Game", "wait_state": "playing", "snap_rest": true})
	plan.append({"at": 9.30, "wait_scene": "Game", "wait_connected": true})
	plan.append({"at": 9.50, "wait_scene": "Game", "wait_state": "won",
		"shot": "08_win", "skip_on_timeout": true})
	# Win'den 1.2 sn sonra Result sahnesi gelir.
	plan.append({"at": 10.10, "wait_scene": "Result"})
	# Sonuç ekranındaki yıldız pop animasyonları otursun diye +0.9 sn.
	plan.append({"at": 11.00, "wait_scene": "Result", "shot": "09_result"})
	return plan
