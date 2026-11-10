extends TestCase

## CableRope: PBD/verlet kararliligi, uzunluk korunumu, panonun onunde kalma,
## surukleme takibi ve segments() ornekleri.
## CableNode: durum makinesi + proxy'ler (drag/snap/bounce).
## ContactScanner: yakin/uzak kablo ciftleri. SparkBurst: havuz kurulumu.

const STEP_SECONDS: float = 1.0 / 60.0
## CableRope.TUBE_SIDES ile ayni (testte sabit; mesh 6 kenarli olmali).
const TUBE_SIDES_FOR_TEST: int = 6
const STEP_COUNT: int = 120
const SAMPLE_LENGTH: float = 1.9
const SAMPLE_SOURCE: Vector3 = Vector3(0.0, 1.18, 0.055)
const SAMPLE_PLUG: Vector3 = Vector3(0.12, -0.22, 0.07)
const SAMPLE_SOCKET: Vector3 = Vector3(0.0, -1.22, 0.055)
const CABLE_COLOR: Color = Color(1.0, 0.33, 0.4)

var _rope: CableRope = null
var _cable: CableNode = null
var _extra: Array[Node] = []
var _grab_count: int = 0
var _release_count: int = 0
var _snap_count: int = 0


func before_each() -> void:
	_grab_count = 0
	_release_count = 0
	_snap_count = 0
	_extra.clear()
	_rope = CableRope.new()
	_rope.name = "TestRope"
	add_node(_rope)
	_rope.setup(_make_points(SAMPLE_SOURCE, SAMPLE_PLUG), SAMPLE_LENGTH, CABLE_COLOR, 220)


func after_each() -> void:
	if _rope != null and _rope.get_parent() != null:
		_rope.free()
	_rope = null
	if _cable != null and _cable.get_parent() != null:
		_cable.free()
	_cable = null
	for node: Node in _extra:
		if node != null and node.get_parent() != null:
			node.free()
	_extra.clear()


func _make_points(source: Vector3, plug: Vector3) -> PackedVector3Array:
	# Kaynaktan fise yumusak bir egri (KnotLevel._initial_path benzeri).
	var raw: PackedVector3Array = PackedVector3Array()
	var control: Vector3 = Vector3(0.42, 0.52, 0.11)
	for i: int in 25:
		var t: float = float(i) / 24.0
		var inv: float = 1.0 - t
		var point: Vector3 = source * (inv * inv) + control * (2.0 * inv * t) + plug * (t * t)
		raw.append(point)
	return CableMath.resample(raw, 18)


func _make_spec(cable_index: int, source: Vector3, plug: Vector3) -> CableSpec:
	var spec: CableSpec = CableSpec.new()
	spec.index = cable_index
	spec.color_id = &"red"
	spec.color = CABLE_COLOR
	spec.voltage = 220
	spec.source = source
	spec.socket = SAMPLE_SOCKET
	spec.socket_index = 0
	spec.plug_rest = plug
	spec.points = _make_points(source, plug)
	spec.length = SAMPLE_LENGTH
	return spec


func _step_many(count: int) -> void:
	for _i: int in count:
		_rope.step(STEP_SECONDS)


func _make_cable(cable_index: int) -> CableNode:
	var cable: CableNode = CableNode.new()
	cable.name = "TestCable%d" % cable_index
	add_node(cable)
	cable.setup(_make_spec(cable_index, SAMPLE_SOURCE, SAMPLE_PLUG))
	_extra.append(cable)
	if _cable == null:
		_cable = cable
	cable.grabbed.connect(func(_cable_index: int) -> void: _grab_count += 1)
	cable.released.connect(func(_cable_index: int, _plug: Vector3) -> void: _release_count += 1)
	cable.snapped.connect(func(_cable_index: int, _socket: int) -> void: _snap_count += 1)
	return cable


# --- CableRope -----------------------------------------------------------

func test_rope_points_stay_finite_and_above_board() -> void:
	_step_many(STEP_COUNT)
	var points: PackedVector3Array = _rope.point_positions()
	assert_eq(points.size(), CableRope.POINT_COUNT, "POINT_COUNT nokta")
	for point: Vector3 in points:
		assert_true(point.is_finite(), "nokta sonsuz/NaN olmamali")
		assert_greater(point.z, -0.000001, "nokta panonun onunde (z >= 0)")


func test_rope_average_segment_length_matches_rest() -> void:
	var expected: float = _rope.total_length() / float(_rope.point_count() - 1)
	assert_almost_eq(_rope.rest_length(), expected, expected * 0.01,
		"rest uzunluk = spec.length / (nokta-1)")
	_step_many(STEP_COUNT)
	var points: PackedVector3Array = _rope.point_positions()
	var measured: float = CableMath.polyline_length(points) / float(points.size() - 1)
	assert_almost_eq(measured, expected, expected * 0.1, "orta segment uzunlugu rest +-10%")
	assert_almost_eq(_rope.taut_ratio(), 1.0, 0.03, "fizik sonrasi halat uzunlugu korunur")


func test_rope_long_spec_keeps_its_length() -> void:
	# En uzun bolumlerde spec.length ~3.5 m: halat 1.7 m'ye kisilmamali (regresyon).
	var long_source: Vector3 = Vector3(-0.6, 1.18, 0.055)
	var long_plug: Vector3 = Vector3(0.55, -1.55, 0.07)
	var long_length: float = 3.5
	_rope.setup(_make_points(long_source, long_plug), long_length, CABLE_COLOR, 220)
	var expected: float = long_length / float(_rope.point_count() - 1)
	assert_almost_eq(_rope.rest_length(), expected, expected * 0.01, "rest uzunluk 3.5 m'den")
	_step_many(STEP_COUNT)
	assert_almost_eq(_rope.rest_length() * float(_rope.point_count() - 1), long_length,
		long_length * 0.01, "length = rest * (nokta-1)")
	var measured: float = CableMath.polyline_length(_rope.point_positions()) \
		/ float(_rope.point_count() - 1)
	assert_almost_eq(measured, expected, expected * 0.1, "uzun halat segmentleri rest +-10%")
	assert_almost_eq(_rope.taut_ratio(), 1.0, 0.03, "uzun halat uzunlugunu korur")


func test_rope_drag_reaches_ninety_percent_of_length() -> void:
	var anchor: Vector3 = _rope.point_positions()[0]
	var direction: Vector3 = Vector3(0.8, 0.5, 0.3).normalized()
	var target: Vector3 = anchor + direction * (SAMPLE_LENGTH * 0.9)
	_rope.begin_drag(target)
	_step_many(60)
	assert_almost_eq(_rope.tip_position().distance_to(target), 0.0, 0.15,
		"fis length*0.9 uzaga ulasabilmeli")
	assert_almost_eq(_rope.taut_ratio(), 1.0, 0.03, "uzatilinca halat gergin")


func test_rope_mesh_is_smoothed_six_sided_tube() -> void:
	var mount: MeshInstance3D = _rope.mesh_instance()
	assert_not_null(mount, "mesh dugumu var")
	var mesh: ArrayMesh = mount.mesh as ArrayMesh
	assert_not_null(mesh, "ArrayMesh uretildi")
	assert_eq(mesh.get_surface_count(), 1, "tek yuzey")
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var ring_count: int = (CableRope.POINT_COUNT - 1) * CableRope.MESH_SUBDIVISIONS + 1
	assert_eq(vertices.size(), ring_count * 6 + 2, "her halkada 6 kenar + 2 kapak merkezi")
	assert_eq(normals.size(), vertices.size(), "her tepe icin normal")
	assert_eq(indices.size(), (ring_count - 1) * 6 * 6 + 2 * 6 * 3, "kenar + kapak ucgenleri")
	# Paralel tasima ile cerceve donmesi yok: dejenere/bow-tie ucgen olmamali.
	var bad_normals: int = 0
	for normal: Vector3 in normals:
		if absf(normal.length() - 1.0) > 0.01:
			bad_normals += 1
	assert_eq(bad_normals, 0, "normaller birim uzunlukta")
	var smallest_area: float = INF
	for i: int in range(0, indices.size(), 3):
		var a: Vector3 = vertices[indices[i]]
		var b: Vector3 = vertices[indices[i + 1]]
		var c: Vector3 = vertices[indices[i + 2]]
		smallest_area = minf(smallest_area, (b - a).cross(c - a).length() * 0.5)
	assert_greater(smallest_area, 0.0000001, "dejenere ucgen yok")
	# Her halka gercek bir daire mi (yaricap = cable radius) ve cerceveler
	# arasinda 180 derece donme yok mu (serit gorunumu regresyonu)?
	var ring_vertices: int = TUBE_SIDES_FOR_TEST
	var ring_normals: Array[Vector3] = []
	for ring_index: int in ring_count:
		var center: Vector3 = Vector3.ZERO
		for side_index: int in ring_vertices:
			center += vertices[ring_index * ring_vertices + side_index]
		center /= float(ring_vertices)
		for side_index: int in ring_vertices:
			var offset: Vector3 = vertices[ring_index * ring_vertices + side_index] - center
			assert_almost_eq(offset.length(), 0.035, 0.002, "halka yaricapi kablo yaricapi")
		ring_normals.append((vertices[ring_index * ring_vertices] - center).normalized())
	for ring_index: int in range(1, ring_count):
		assert_greater(ring_normals[ring_index].dot(ring_normals[ring_index - 1]), 0.5,
			"cerceveler arasinda donme sicramasi yok")
	var material: StandardMaterial3D = mount.material_override as StandardMaterial3D
	assert_not_null(material, "tupe malzemesi")
	assert_true(material.emission_enabled, "kablo emission'lu")
	assert_almost_eq(material.emission_energy_multiplier, CableRope.EMISSION_ENERGY, 0.001)
	assert_almost_eq(CableRope.DEFAULT_RADIUS, 0.035, 0.0001, "varsayilan kablo yaricapi")


func test_rope_taut_ratio_high_after_setup() -> void:
	assert_greater(_rope.taut_ratio(), 0.95, "kurulumda halat gergin")


func test_rope_segments_count_and_world_space() -> void:
	var segments: PackedVector3Array = _rope.segments()
	assert_true(segments.size() >= 8, "temas taramasi icin yeterli ornek")
	assert_eq(segments.size(), 10)
	_rope.position = Vector3(1.0, 0.0, 0.0)
	var shifted: PackedVector3Array = _rope.segments()
	assert_almost_eq(shifted[0].x - segments[0].x, 1.0, 0.01, "segments dunya uzayinda")


func test_drag_moves_last_point_to_target() -> void:
	var target: Vector3 = Vector3(0.4, 0.45, 0.3)
	_rope.begin_drag(target)
	_step_many(8)
	assert_almost_eq(_rope.tip_position().distance_to(target), 0.0, 0.01,
		"suruklemede son nokta hedefte")
	var next_target: Vector3 = Vector3(0.35, 0.1, 0.3)
	_rope.update_drag(next_target)
	_step_many(8)
	assert_almost_eq(_rope.tip_position().distance_to(next_target), 0.0, 0.01,
		"update_drag son noktayi tasir")
	assert_true(_rope.is_dragging(), "surukleme durumu")


func test_drag_cannot_stretch_beyond_length() -> void:
	var far_target: Vector3 = SAMPLE_SOURCE + Vector3(6.0, 0.0, 0.0)
	_rope.begin_drag(far_target)
	_step_many(10)
	var tip: Vector3 = _rope.tip_position()
	var anchor: Vector3 = _rope.point_positions()[0]
	var distance: float = anchor.distance_to(tip)
	assert_true(distance <= SAMPLE_LENGTH * 0.97 + 0.02,
		"fis length*0.97'den fazla uzaga cekilemez")


func test_release_holds_plug_in_front_of_board() -> void:
	var drag_target: Vector3 = Vector3(0.3, 0.3, 0.3)
	_rope.begin_drag(drag_target)
	_step_many(6)
	_rope.end_drag(false)
	_step_many(30)
	var tip: Vector3 = _rope.tip_position()
	assert_almost_eq(tip.z, _rope.board_surface_z + 0.02, 0.005,
		"birakilan fis panoya oturur (drag_lift degil)")
	var before: Vector3 = _rope.tip_position()
	_step_many(30)
	assert_almost_eq(_rope.tip_position().distance_to(before), 0.0, 0.001,
		"birakilan fis miknatisla asili kalir")


func test_snap_freezes_points_and_emits_signal() -> void:
	var signal_count: Array[int] = [0]
	_rope.snap_finished.connect(func() -> void: signal_count[0] += 1)
	_rope.snap_to(SAMPLE_SOCKET)
	_step_many(30)
	assert_true(_rope.is_frozen(), "snap sonrasi noktalar donar")
	assert_almost_eq(_rope.tip_position().distance_to(SAMPLE_SOCKET), 0.0, 0.001)
	assert_eq(signal_count[0], 1, "snap_finished tam bir kez")


func test_bounce_returns_plug_to_board() -> void:
	_rope.begin_drag(Vector3(0.2, 0.3, 0.3))
	_step_many(4)
	_rope.end_drag(false)
	_step_many(20)
	_rope.bounce_tip_up(0.25)
	_rope.finish_animations()
	assert_almost_eq(_rope.tip_position().z, _rope.board_surface_z + 0.02, 0.005,
		"sektikten sonra fis panoya oturur")


# --- CableNode -----------------------------------------------------------

func test_node_setup_builds_plug_and_layer_state() -> void:
	var cable: CableNode = _make_cable(0)
	assert_not_null(cable.rope(), "halat olusturuldu")
	assert_eq(cable.state, CableNode.State.IDLE)
	assert_false(cable.is_linked())
	assert_true(cable.get_child_count() >= 2, "fis gorseli + halat")
	assert_true(cable.plug_position().is_finite(), "fis konumu gecerli")
	assert_almost_eq(cable.plug_position().distance_to(SAMPLE_PLUG), 0.0, 0.03,
		"fis baslangicta plug_rest'e yakin")


func test_node_plug_has_voltage_label() -> void:
	var cable: CableNode = _make_cable(0)
	var label: Label3D = cable.get_node_or_null("Plug/VoltageLabel") as Label3D
	assert_not_null(label, "fis uzerinde voltaj etiketi")
	if label != null:
		assert_eq(label.text, "220V")
	var plug: Node3D = cable.get_node_or_null("Plug") as Node3D
	assert_not_null(plug, "fis gorsel koku")
	if plug != null:
		assert_true(plug.get_child_count() >= 5, "govde + cekirdek + 2 pim + etiket")


func test_node_plug_is_big_and_layered() -> void:
	var cable: CableNode = _make_cable(0)
	var body: MeshInstance3D = cable.get_node_or_null("Plug/Body") as MeshInstance3D
	assert_not_null(body, "fis govdesi")
	if body != null:
		var body_mesh: BoxMesh = body.mesh as BoxMesh
		assert_not_null(body_mesh)
		if body_mesh != null:
			assert_almost_eq(body_mesh.size.x, 0.15, 0.001, "fis govde genisligi")
			assert_almost_eq(body_mesh.size.y, 0.12, 0.001, "fis govde yuksekligi")
			assert_almost_eq(body_mesh.size.z, 0.09, 0.001, "fis govde derinligi")
	assert_not_null(cable.get_node_or_null("Plug/Shell"), "renkli neon kabuk")
	assert_not_null(cable.get_node_or_null("Plug/PinA"), "pirinç pim A")
	assert_not_null(cable.get_node_or_null("Plug/PinB"), "pirinç pim B")
	assert_not_null(cable.get_node_or_null("Plug/TopRing"), "ust parlak halka")


func test_node_drag_proxies_and_signals() -> void:
	var cable: CableNode = _make_cable(0)
	cable.begin_drag(Vector3(0.3, 0.4, 0.3))
	assert_eq(cable.state, CableNode.State.DRAGGING)
	assert_true(cable.is_dragging())
	cable.update_drag(Vector3(0.25, 0.5, 0.3))
	cable.end_drag(false)
	assert_eq(cable.state, CableNode.State.IDLE)
	assert_eq(_grab_count, 1, "grabbed tam bir kez")
	assert_eq(_release_count, 1, "released tam bir kez")
	assert_true(not cable.is_dragging())


func test_node_snap_instant_connects_and_emits() -> void:
	var cable: CableNode = _make_cable(0)
	cable.snap_instant(SAMPLE_SOCKET)
	assert_true(cable.is_linked(), "snap_instant baglar")
	assert_true(cable.connected, "connected ozelligi")
	assert_eq(cable.state, CableNode.State.CONNECTED)
	assert_eq(_snap_count, 1, "snapped sinyali")
	assert_almost_eq(cable.plug_position().distance_to(SAMPLE_SOCKET), 0.0, 0.001)


func test_node_drag_then_snap_end_to_end() -> void:
	var cable: CableNode = _make_cable(0)
	cable.begin_drag(Vector3(0.1, -0.6, 0.3))
	for _i: int in 10:
		cable.rope().step(STEP_SECONDS)
	cable.update_drag(Vector3(0.05, -1.0, 0.3))
	for _i: int in 10:
		cable.rope().step(STEP_SECONDS)
	cable.end_drag(true)
	cable.snap_to(SAMPLE_SOCKET)
	for _i: int in 30:
		cable.rope().step(STEP_SECONDS)
	assert_true(cable.is_linked(), "surukle-birak-snap akisi baglar")
	assert_eq(_snap_count, 1, "snapped tam bir kez")
	assert_almost_eq(cable.plug_position().distance_to(SAMPLE_SOCKET), 0.0, 0.001,
		"fis prize oturur")
	assert_false(cable.is_grabbable(), "bagli fis tekrar tutulamaz")


func test_node_wrong_socket_signal() -> void:
	var cable: CableNode = _make_cable(0)
	var count: Array[int] = [0]
	cable.wrong_socket.connect(func(_cable_index: int) -> void: count[0] += 1)
	cable.notify_wrong_socket()
	assert_eq(count[0], 1, "wrong_socket tam bir kez")


func test_node_shield_and_bounce_delegate_to_rope() -> void:
	var cable: CableNode = _make_cable(0)
	cable.set_shielded(true)
	assert_true(cable.rope().is_shielded(), "kalkan halata delege edildi")
	cable.set_shielded(false)
	assert_false(cable.rope().is_shielded())
	cable.bounce_up(0.25)
	cable.rope().finish_animations()
	assert_true(cable.rope().tip_position().is_finite(), "sekmadan sonra gecerli konum")


# --- ContactScanner ------------------------------------------------------

func test_scanner_finds_contact_between_close_cables() -> void:
	var cable_a: CableNode = _make_cable(0)
	var cable_b: CableNode = _make_cable(1)
	var cables: Array[CableNode] = [cable_a, cable_b]
	var scanner: ContactScanner = ContactScanner.new()
	var contacts: Array[Dictionary] = scanner.scan(cables, 0.078)
	assert_eq(contacts.size(), 1, "ayni hattaki iki kablo temas eder")
	if not contacts.is_empty():
		var entry: Dictionary = contacts[0]
		assert_eq(int(entry.get("a", -1)), 0)
		assert_eq(int(entry.get("b", -1)), 1)
		var point: Vector3 = entry.get("point", Vector3.ZERO)
		assert_true(point.is_finite(), "kontak noktasi gecerli")
		assert_greater(float(entry.get("distance", 99.0)), -1.0, "mesafe dolu")


func test_scanner_ignores_far_cables() -> void:
	var near_cable: CableNode = _make_cable(0)
	var far_cable: CableNode = CableNode.new()
	far_cable.name = "FarCable"
	add_node(far_cable)
	far_cable.setup(_make_spec(1, Vector3(2.0, 1.18, 0.055), Vector3(2.1, -0.22, 0.07)))
	_extra.append(far_cable)
	var cables: Array[CableNode] = [near_cable, far_cable]
	var scanner: ContactScanner = ContactScanner.new()
	var contacts: Array[Dictionary] = scanner.scan(cables, 0.078)
	assert_eq(contacts.size(), 0, "uzak kablolar temas etmez")


# --- SparkBurst ----------------------------------------------------------

func test_spark_burst_builds_pool_and_restarts() -> void:
	var sparks: SparkBurst = SparkBurst.new()
	sparks.name = "TestSparks"
	add_node(sparks)
	_extra.append(sparks)
	assert_eq(sparks.get_child_count(), SparkBurst.POOL_SIZE * 3, "4 havuz yuvasi onceden kurulur")
	sparks.burst(Vector3(0.1, 0.2, 0.3), CABLE_COLOR, 1.0)
	sparks.burst(Vector3(0.15, 0.25, 0.3), CABLE_COLOR, 1.5)
	assert_eq(sparks.get_child_count(), SparkBurst.POOL_SIZE * 3,
		"yeniden patlatma dugum eklemez")
