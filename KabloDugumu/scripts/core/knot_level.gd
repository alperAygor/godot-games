class_name KnotLevel
extends RefCounted

## Bir bolumun saf tanimi: kaynak terminaller, prizler, fis baslangic konumlari,
## halat egrisi ve uzunlugu. Tohumlanmis rastgelelik: ayni girdi = ayni duzen.
##
## layout sozlesmesi data/balance.json "board" bolumudur. Ek olarak tum balance
## tablosu verilebilir; o durumda "cable"/"contact" bolumlerindeki parametreler de
## okunur (ic ice arama; geriye uyumlu). Eksik anahtar icin koddaki varsayilan
## kullanilir; varsayilanlar data/balance.json degerleriyle aynidir.
##
## Uretim garantileri (birim testli: tests/unit/test_core_levels.gd):
##  (a) length >= |source - socket| + 0.15
##  (b) baslangicta farkli renkli iki kablo contact_distance*1.1'den yakin degil
##  (c) plug_rest kendi socket'inden > 0.45 uzak
##  (d) fisler birbirinden >= cable.rest_gap uzak ve pano sinirlari icinde
##  (e) her kablonun essiz renkli prizi var; kaynak ve priz renk sirasi farkli
##  (f) ayni config + seed = ayni duzen (deterministik)
##  (g) kaynak/priz panonun icinde, z = board_surface_z
##
## Ayrica halat egrisinin yay uzunlugu kablo length'ine esittir (CableRope
## noktalari length'e gore normalize eder; uyusmazsa gorsel "pop" olur).
##
## Yerlesim: kaynaklar ust seritte, fisler orta bolgede 3 satirda dagitilmis,
## prizler alt seritte karisik renkte. Kaynak sirasi ile fis sirasi ayni tutulur
## (baslangicta farkli renkli halatlar birbirine yaklasmaz); priz sirasi
## karistirilir, boylece cozerken yollar kesisir. Halatlar serbest uzunluklarini
## panoda salinan 2-3 "lob" (asagi-yukari kivrim) ile harcar: bolum "dugum" gorunur.

const MAX_CABLES: int = 7
const DEFAULT_POINT_COUNT: int = 18

## Ulasilabilirlik garantisi: length >= |source - socket| + REACH_GUARANTEE.
const REACH_GUARANTEE: float = 0.15
const REACH_MARGIN: float = 0.18
## Baslangic temas garantisi: contact_distance * CLEARANCE_SCALE + CLEARANCE_MARGIN.
const CLEARANCE_SCALE: float = 1.1
const CLEARANCE_MARGIN: float = 0.025
## Uretim dayanikliligi (oyun dengesi degil; algoritma parametresi).
const MAX_ATTEMPTS: int = 96
const PATH_TRIES: int = 20
const PLUG_SOCKET_MIN: float = 0.45
const PLUG_EDGE_MARGIN: float = 0.05
const PATH_EDGE_MARGIN: float = 0.06
const RAW_STEPS: int = 48
const PLUG_ROWS: int = 3
const MAX_LOBES: int = 3
const CONTROL_X_JITTER: float = 0.025
const SHARED_SWAY: float = 0.05
## Kivrimin iki gecisi ayni cizgiye binmesin diye ortak yatay "ilmek" genligi.
const LOOP_SWAY_SHARED: float = 0.075
const LOOP_SWAY_IND: float = 0.02
## Kivrimin merkezini asagi kaydirma (pano orta-alt bolgesini doldurur).
const SAG_BIAS_MIN: float = 0.04
const SAG_BIAS_MAX: float = 0.22
const PLUG_X_JITTER: float = 0.022
const PLUG_Y_JITTER: float = 0.03
## Halat yay uzunlugu ile length arasindaki kabul edilen fark (metre).
const PATH_LENGTH_TOLERANCE: float = 0.012


## Cozulmus pano/denge parametreleri (data/balance.json -> board / cable / contact).
class Layout:
	var width: float = 1.7
	var height: float = 3.1
	var source_y: float = 1.18
	var socket_y: float = -1.22
	var source_x_span: float = 0.64
	var socket_x_span: float = 0.6
	var plug_x_span: float = 0.64
	var knot_y_top: float = 0.68
	var knot_y_bottom: float = -0.55
	var surface_z: float = 0.055
	var cable_points: int = 18
	var length_factor: float = 1.0
	var length_min_slack: float = 0.2
	var rest_gap: float = 0.24
	var contact_distance: float = 0.078


## Uretim sonucu (iki dizi birlikte doner).
class Built:
	var cables: Array[CableSpec] = []
	var sockets: Array[SocketSpec] = []
	var used_fallback: bool = false


var level_index: int = 1
var level_name: String = ""
var par_seconds: float = 60.0
var hint: String = ""
var seed: int = 1
var cables: Array[CableSpec] = []
var sockets: Array[SocketSpec] = []
## Duz yedek duzen kullanildi mi? (normalde false; tani/QA icin)
var used_fallback: bool = false


## config: data/levels.json icindeki tek bolum; colors_table: "colors" tablosu.
## layout: data/balance.json "board" bolumu (bos ise varsayilanlar).
static func from_config(config: Dictionary, colors_table: Dictionary,
		layout: Dictionary = {}) -> KnotLevel:
	var level: KnotLevel = KnotLevel.new()
	level.level_index = int(config.get("id", 1))
	level.level_name = String(config.get("name", "Bolum %d" % level.level_index))
	level.par_seconds = float(config.get("par_seconds", 60.0))
	level.hint = String(config.get("hint", ""))
	level.seed = int(config.get("seed", 1))
	var params: Layout = layout_from(layout)
	var count: int = clampi(int(config.get("cables", 3)), 1, MAX_CABLES)
	var color_ids: Array[StringName] = _color_ids(config, colors_table, count)
	var built: Built = _generate(level.seed, count, color_ids, colors_table, params)
	level.cables = built.cables
	level.sockets = built.sockets
	level.used_fallback = built.used_fallback
	return level


## from_config ile ayni islev (okunurluk icin alias).
static func build(config: Dictionary, colors_table: Dictionary,
		layout: Dictionary = {}) -> KnotLevel:
	return from_config(config, colors_table, layout)


## layout sozlugunu tipli parametrelere cozer. Bos sozluk = varsayilanlar.
static func layout_from(layout: Dictionary) -> Layout:
	var out: Layout = Layout.new()
	out.width = maxf(1.0, _layout_float(layout, "width", "board", out.width))
	out.height = maxf(1.0, _layout_float(layout, "height", "board", out.height))
	out.source_y = _layout_float(layout, "source_y", "board", out.source_y)
	out.socket_y = _layout_float(layout, "socket_y", "board", out.socket_y)
	out.surface_z = _layout_float(layout, "board_surface_z", "board", out.surface_z)
	out.knot_y_top = _layout_float(layout, "knot_y_top", "board", out.knot_y_top)
	out.knot_y_bottom = _layout_float(layout, "knot_y_bottom", "board", out.knot_y_bottom)
	out.cable_points = maxi(4, _layout_int(layout, "cable_points", "board", out.cable_points))
	var edge_span: float = out.width * 0.5 - PLUG_EDGE_MARGIN
	out.source_x_span = clampf(_layout_float(layout, "source_x_span", "board", out.source_x_span),
		0.05, edge_span)
	out.socket_x_span = clampf(_layout_float(layout, "socket_x_span", "board", out.socket_x_span),
		0.05, edge_span)
	out.plug_x_span = clampf(_layout_float(layout, "plug_x_span", "board", out.source_x_span),
		0.05, edge_span)
	out.length_factor = maxf(1.0, _layout_float(layout, "length_factor", "cable",
		out.length_factor))
	out.length_min_slack = maxf(0.0, _layout_float(layout, "length_min_slack", "cable",
		out.length_min_slack))
	out.rest_gap = maxf(0.05, _layout_float(layout, "rest_gap", "cable", out.rest_gap))
	var raw_contact: Variant = layout.get("contact_distance")
	if raw_contact == null:
		var contact_section: Variant = layout.get("contact")
		if contact_section is Dictionary:
			raw_contact = (contact_section as Dictionary).get("distance")
	if raw_contact != null:
		out.contact_distance = maxf(0.0, float(raw_contact))
	return out


func source_points() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for cable: CableSpec in cables:
		result.append(cable.source)
	return result


func socket_position_for(color_id: StringName) -> Vector3:
	for socket: SocketSpec in sockets:
		if socket.color_id == color_id:
			return socket.position
	return Vector3.ZERO


## Kaynak ile priz renk sirasi farkli mi (baslangic duzeninde yollar kessin)?
func color_order_matches_source() -> bool:
	for i: int in mini(cables.size(), sockets.size()):
		if cables[i].color_id != sockets[i].color_id:
			return false
	return true


# --- uretim ---------------------------------------------------------------

static func _generate(seed_value: int, count: int, color_ids: Array[StringName],
		colors_table: Dictionary, params: Layout) -> Built:
	for attempt: int in MAX_ATTEMPTS:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = _attempt_seed(seed_value, attempt)
		var candidate: Built = _attempt_layout(count, color_ids, colors_table, params, rng)
		if candidate != null:
			return candidate
	return _fallback_layout(seed_value, count, color_ids, colors_table, params)


static func _attempt_layout(count: int, color_ids: Array[StringName],
		colors_table: Dictionary, params: Layout, rng: RandomNumberGenerator) -> Built:
	var sockets: Array[SocketSpec] = _build_sockets(color_ids,
		_spread(count, params.socket_x_span), params, colors_table, rng)
	var plugs: Array[Vector3] = _build_plugs(count, params, rng)
	var source_xs: Array[float] = _spread(count, params.source_x_span)
	var sway: PackedFloat32Array = _make_sway(rng)
	var loop_sway: float = rng.randf_range(LOOP_SWAY_SHARED * 0.7, LOOP_SWAY_SHARED)
	var clearance: float = params.contact_distance * CLEARANCE_SCALE + CLEARANCE_MARGIN
	var paths: Array[PackedVector3Array] = []
	var cables: Array[CableSpec] = []
	for i: int in count:
		var source: Vector3 = Vector3(source_xs[i], params.source_y, params.surface_z)
		var plug: Vector3 = plugs[i]
		var socket_index: int = _socket_index_for(sockets, color_ids[i])
		var target: float = _target_length(
			source.distance_to(sockets[socket_index].position), params)
		var path: PackedVector3Array = PackedVector3Array()
		var found: bool = false
		for _path_try: int in PATH_TRIES:
			var candidate: PackedVector3Array = _make_path(source, plug, target, params,
				sway, loop_sway, rng)
			if candidate.size() < 2:
				continue
			if absf(CableMath.polyline_length(candidate) - target) > PATH_LENGTH_TOLERANCE:
				continue
			if not _path_is_clear(candidate, paths, clearance):
				continue
			path = candidate
			found = true
			break
		if not found:
			return null
		paths.append(path)
		cables.append(_make_cable(i, color_ids[i], source, plug, path, sockets,
			colors_table, params))
	var built: Built = Built.new()
	built.cables = cables
	built.sockets = sockets
	return built


## Son care: panoda serit halinde, yapisal olarak garantili duzen (nadiren gerekir).
static func _fallback_layout(seed_value: int, count: int,
		color_ids: Array[StringName], colors_table: Dictionary, params: Layout) -> Built:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _attempt_seed(seed_value, MAX_ATTEMPTS)
	var sockets: Array[SocketSpec] = _build_sockets(color_ids,
		_spread(count, params.socket_x_span), params, colors_table, rng)
	var clearance: float = params.contact_distance * CLEARANCE_SCALE + CLEARANCE_MARGIN
	var needed_span: float = maxf(params.source_x_span,
		(clearance + 0.05) * float(maxi(count - 1, 1)) * 0.5)
	needed_span = minf(needed_span, params.width * 0.5 - PLUG_EDGE_MARGIN)
	var source_xs: Array[float] = _spread(count, needed_span)
	var plugs: Array[Vector3] = _fallback_plugs(source_xs, params)
	var sway: PackedFloat32Array = PackedFloat32Array()
	for _i: int in MAX_LOBES * 2 + 2:
		sway.append(0.0)
	var paths: Array[PackedVector3Array] = []
	var cables: Array[CableSpec] = []
	for i: int in count:
		var source: Vector3 = Vector3(source_xs[i], params.source_y, params.surface_z)
		var plug: Vector3 = plugs[i]
		var socket_index: int = _socket_index_for(sockets, color_ids[i])
		var target: float = _target_length(
			source.distance_to(sockets[socket_index].position), params)
		var path: PackedVector3Array = PackedVector3Array()
		for _path_try: int in PATH_TRIES:
			var candidate: PackedVector3Array = _make_path(source, plug, target, params,
				sway, 0.0, rng)
			if candidate.size() < 2:
				continue
			if absf(CableMath.polyline_length(candidate) - target) > PATH_LENGTH_TOLERANCE:
				continue
			if not _path_is_clear(candidate, paths, clearance):
				continue
			path = candidate
			break
		if path.size() < 2:
			path = _straight_path(source, plug, params)
		paths.append(path)
		cables.append(_make_cable(i, color_ids[i], source, plug, path, sockets,
			colors_table, params))
	var built: Built = Built.new()
	built.cables = cables
	built.sockets = sockets
	built.used_fallback = true
	return built


static func _fallback_plugs(source_xs: Array[float], params: Layout) -> Array[Vector3]:
	var row_top: float = params.knot_y_top - 0.06
	var row_bottom: float = maxf(params.knot_y_bottom + 0.06,
		params.socket_y + PLUG_SOCKET_MIN + 0.25)
	var min_gap: float = maxf(params.rest_gap + 0.04, 0.18)
	if row_bottom > row_top - min_gap * float(PLUG_ROWS - 1):
		row_bottom = row_top - min_gap * float(PLUG_ROWS - 1)
	var row_gap: float = (row_top - row_bottom) / float(PLUG_ROWS - 1)
	var result: Array[Vector3] = []
	for i: int in source_xs.size():
		var row: int = i % PLUG_ROWS
		var y: float = row_top - row_gap * float(row)
		result.append(Vector3(source_xs[i], y, params.surface_z))
	return result


static func _straight_path(source: Vector3, plug: Vector3,
		params: Layout) -> PackedVector3Array:
	var raw: PackedVector3Array = PackedVector3Array()
	for step: int in RAW_STEPS + 1:
		var t: float = float(step) / float(RAW_STEPS)
		raw.append(source.lerp(plug, t))
	return CableMath.resample(raw, maxi(4, params.cable_points))


## Ulasilabilirlik icin gereken halat uzunlugu; alt sinir garantisi REACH_MARGIN.
static func _target_length(straight: float, params: Layout) -> float:
	var reach: float = straight + REACH_MARGIN
	var tuned: float = straight * params.length_factor + params.length_min_slack
	return maxf(reach, tuned)


## Halat egrisi: kaynaktan fise, panoda salinan buyuk bir kivrimla (U / N / W
## stili). Yay uzunlugu hedefe esitlenir; stil tohumla karistirilir -> her kablo
## farkli "dugum" gorunumu verir.
static func _make_path(source: Vector3, plug: Vector3, target_length: float,
		params: Layout, sway: PackedFloat32Array, loop_sway: float,
		rng: RandomNumberGenerator) -> PackedVector3Array:
	var styles: Array[PackedFloat32Array] = _path_styles()
	var start: int = rng.randi_range(0, styles.size() - 1)
	for offset: int in styles.size():
		var style: PackedFloat32Array = styles[(start + offset) % styles.size()]
		var points: PackedVector3Array = _solve_style(source, plug, target_length,
			params, style, sway, loop_sway, rng)
		if points.size() >= 2:
			return points
	return PackedVector3Array()


## Kivrim stilleri: merkez hattina gore y ofsetleri (g genligiyle olceklenir).
## Hepsi asagi dogru baslar; ortak yatay ilmek boylece komsu kablolarla ayni yone
## acilir (serit araligi korunur) ve halat kendi uzerine katlanmaz.
static func _path_styles() -> Array[PackedFloat32Array]:
	var styles: Array[PackedFloat32Array] = []
	styles.append(PackedFloat32Array([-0.45, -1.0, -0.45]))
	styles.append(PackedFloat32Array([-1.0, 0.55]))
	styles.append(PackedFloat32Array([-1.0, 0.55, -1.0]))
	return styles


## Kivrim genligini ikili aramayla buyuterek yay uzunlugunu target_length'e oturtur.
static func _solve_style(source: Vector3, plug: Vector3, target_length: float,
		params: Layout, style: PackedFloat32Array, sway: PackedFloat32Array,
		loop_sway: float, rng: RandomNumberGenerator) -> PackedVector3Array:
	var ind_phase: float = rng.randf_range(0.0, TAU)
	var sag: float = rng.randf_range(SAG_BIAS_MIN, SAG_BIAS_MAX)
	var control_count: int = style.size() + 2
	var jitters: PackedFloat32Array = PackedFloat32Array()
	for i: int in control_count:
		jitters.append(0.0 if (i == 0 or i == control_count - 1)
			else rng.randf_range(-CONTROL_X_JITTER, CONTROL_X_JITTER))
	var center_y: float = (source.y + plug.y) * 0.5 - sag
	var y_min: float = -params.height * 0.5 + PATH_EDGE_MARGIN
	var y_max: float = params.height * 0.5 - PATH_EDGE_MARGIN
	var amplitude_high: float = 1.2
	for factor: float in style:
		if factor > 0.0:
			amplitude_high = minf(amplitude_high, (y_max - center_y) / factor)
		elif factor < 0.0:
			amplitude_high = minf(amplitude_high, (center_y - y_min) / -factor)
	amplitude_high = maxf(amplitude_high, 0.0)
	if amplitude_high < 0.02:
		return PackedVector3Array()
	var low: float = 0.0
	var high: float = amplitude_high
	var best: PackedVector3Array = PackedVector3Array()
	var best_error: float = INF
	for _iteration: int in 30:
		var middle: float = (low + high) * 0.5
		var points: PackedVector3Array = _build_style(source, plug, params, style,
			middle, sway, jitters, loop_sway, ind_phase, sag)
		if not _path_inside_board(points, params):
			high = middle
			continue
		var length: float = CableMath.polyline_length(points)
		var error: float = absf(length - target_length)
		if error < best_error:
			best_error = error
			best = points
		if length < target_length:
			low = middle
		else:
			high = middle
	if best.size() >= 2 and best_error <= PATH_LENGTH_TOLERANCE:
		return best
	return PackedVector3Array()


static func _build_style(source: Vector3, plug: Vector3, params: Layout,
		style: PackedFloat32Array, amplitude: float, sway: PackedFloat32Array,
		jitters: PackedFloat32Array, loop_sway: float,
		ind_phase: float, sag: float) -> PackedVector3Array:
	var center_y: float = (source.y + plug.y) * 0.5 - sag
	var z: float = params.surface_z
	var control_count: int = style.size() + 2
	var controls: PackedVector3Array = PackedVector3Array()
	controls.append(source)
	var index: int = 1
	for factor: float in style:
		controls.append(Vector3(
			_control_x(source, plug, index, control_count, sway, jitters),
			center_y + factor * amplitude, z))
		index += 1
	controls.append(plug)
	var raw: PackedVector3Array = PackedVector3Array()
	for step: int in RAW_STEPS + 1:
		var t: float = float(step) / float(RAW_STEPS)
		var point: Vector3 = _spline_point(controls, t)
		point.x += loop_sway * sin(TAU * t)
		point.x += LOOP_SWAY_IND * sin(TAU * 2.0 * t + ind_phase)
		raw.append(point)
	return CableMath.resample(raw, maxi(4, params.cable_points))


static func _control_x(source: Vector3, plug: Vector3, index: int, control_count: int,
		sway: PackedFloat32Array, jitters: PackedFloat32Array) -> float:
	var t: float = float(index) / float(control_count - 1)
	var base: float = lerpf(source.x, plug.x, t)
	var shared: float = sway[index] if index < sway.size() else 0.0
	var jitter: float = jitters[index] if index < jitters.size() else 0.0
	return base + shared + jitter


## Egriyi gecen uniform Catmull-Rom orneklemesi (uclar birebir korunur).
static func _spline_point(controls: PackedVector3Array, t: float) -> Vector3:
	var count: int = controls.size()
	if count == 1:
		return controls[0]
	var scaled: float = clampf(t, 0.0, 1.0) * float(count - 1)
	var index: int = mini(int(floor(scaled)), count - 2)
	var local: float = scaled - float(index)
	var p0: Vector3 = controls[maxi(index - 1, 0)]
	var p1: Vector3 = controls[index]
	var p2: Vector3 = controls[index + 1]
	var p3: Vector3 = controls[mini(index + 2, count - 1)]
	var t2: float = local * local
	var t3: float = t2 * local
	return (p1 * 2.0 + (p2 - p0) * local
		+ (p0 * 2.0 - p1 * 5.0 + p2 * 4.0 - p3) * t2
		+ (p1 * 3.0 - p0 - p2 * 3.0 + p3) * t3) * 0.5


static func _make_sway(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var sway: PackedFloat32Array = PackedFloat32Array()
	var size: int = MAX_LOBES * 2 + 2
	for index: int in size:
		if index == 0 or index == size - 1:
			sway.append(0.0)
		else:
			sway.append(rng.randf_range(-SHARED_SWAY, SHARED_SWAY))
	return sway


static func _make_cable(index: int, color_id: StringName, source: Vector3,
		plug: Vector3, points: PackedVector3Array, sockets: Array[SocketSpec],
		colors_table: Dictionary, params: Layout) -> CableSpec:
	var cable: CableSpec = CableSpec.new()
	cable.index = index
	cable.color_id = color_id
	cable.color = _color_of(color_id, colors_table)
	cable.voltage = _voltage_of(color_id, colors_table)
	cable.source = source
	cable.plug_rest = plug
	var socket_index: int = _socket_index_for(sockets, color_id)
	cable.socket_index = socket_index
	cable.socket = sockets[socket_index].position
	cable.points = points
	cable.length = _target_length(source.distance_to(cable.socket), params)
	return cable


static func _build_sockets(color_ids: Array[StringName], x_slots: Array[float],
		params: Layout, colors_table: Dictionary, rng: RandomNumberGenerator) -> Array[SocketSpec]:
	var order: Array[int] = _derangement(color_ids.size(), rng)
	var sockets: Array[SocketSpec] = []
	for i: int in color_ids.size():
		var socket: SocketSpec = SocketSpec.new()
		socket.index = i
		socket.color_id = color_ids[order[i]]
		socket.color = _color_of(socket.color_id, colors_table)
		socket.voltage = _voltage_of(socket.color_id, colors_table)
		socket.position = Vector3(x_slots[i], params.socket_y, params.surface_z)
		sockets.append(socket)
	return sockets


## Fisler orta bolgede 3 satira dagitilir; ayni satirdakiler arasi 3*step,
## farkli satir arasi y farki buyuk oldugu icin rest_gap garantisi yapisaldir.
static func _build_plugs(count: int, params: Layout,
		rng: RandomNumberGenerator) -> Array[Vector3]:
	var span: float = minf(params.plug_x_span, params.width * 0.5 - PLUG_EDGE_MARGIN)
	var step: float = 2.0 * span / float(maxi(count, 1))
	var row_top: float = params.knot_y_top - 0.06
	var row_bottom: float = maxf(params.knot_y_bottom + 0.06,
		params.socket_y + PLUG_SOCKET_MIN + 0.25)
	var min_gap: float = maxf(params.rest_gap + 0.04, 0.18)
	if row_bottom > row_top - min_gap * float(PLUG_ROWS - 1):
		row_bottom = row_top - min_gap * float(PLUG_ROWS - 1)
	var row_gap: float = (row_top - row_bottom) / float(PLUG_ROWS - 1)
	var jitter_x: float = minf(PLUG_X_JITTER, step * 0.4)
	var x_limit: float = params.width * 0.5 - PLUG_EDGE_MARGIN
	var result: Array[Vector3] = []
	for i: int in count:
		var row: int = i % PLUG_ROWS
		var x: float = -span + step * (float(i) + 0.5)
		x += rng.randf_range(-jitter_x, jitter_x)
		var y: float = row_top - row_gap * float(row)
		y += rng.randf_range(-PLUG_Y_JITTER, PLUG_Y_JITTER)
		result.append(Vector3(clampf(x, -x_limit, x_limit), y, params.surface_z))
	return result


static func _path_inside_board(points: PackedVector3Array, params: Layout) -> bool:
	var limit_x: float = params.width * 0.5 - PATH_EDGE_MARGIN + 0.002
	var limit_y: float = params.height * 0.5 - PATH_EDGE_MARGIN + 0.002
	for point: Vector3 in points:
		if absf(point.x) > limit_x or absf(point.y) > limit_y:
			return false
	return true


static func _path_is_clear(candidate: PackedVector3Array,
		accepted: Array[PackedVector3Array], clearance: float) -> bool:
	for other: PackedVector3Array in accepted:
		if CableMath.polyline_distance(candidate, other) <= clearance:
			return false
	return true


static func _attempt_seed(seed_value: int, attempt: int) -> int:
	return (seed_value << 16) ^ (attempt * 2654435761 + 1013904223)


# --- kucuk yardimcilar -----------------------------------------------------

static func _layout_float(layout: Dictionary, key: String, section: String,
		fallback: float) -> float:
	var raw: Variant = layout.get(key)
	if raw == null:
		var nested: Variant = layout.get(section)
		if nested is Dictionary:
			raw = (nested as Dictionary).get(key)
	if raw == null:
		return fallback
	return float(raw)


static func _layout_int(layout: Dictionary, key: String, section: String,
		fallback: int) -> int:
	return int(roundf(_layout_float(layout, key, section, float(fallback))))


static func _color_ids(config: Dictionary, colors_table: Dictionary,
		count: int) -> Array[StringName]:
	var result: Array[StringName] = []
	var raw: Variant = config.get("colors", [])
	if raw is Array:
		for item: Variant in raw as Array:
			result.append(StringName(String(item)))
			if result.size() >= count:
				break
	if result.is_empty():
		var fallback: Array[String] = ["red", "blue", "yellow", "green", "purple"]
		var available: int = maxi(1, colors_table.size())
		for i: int in count:
			result.append(StringName(fallback[i % mini(fallback.size(), available)]))
	while result.size() < count:
		result.append(result[result.size() % result.size()])
	return result


static func _color_of(color_id: StringName, colors_table: Dictionary) -> Color:
	var entry: Variant = colors_table.get(String(color_id))
	if entry is Dictionary:
		var hex_value: String = String((entry as Dictionary).get("hex", "#FFFFFF"))
		return Color.from_string(hex_value, Color.WHITE)
	return Color.WHITE


static func _voltage_of(color_id: StringName, colors_table: Dictionary) -> int:
	var entry: Variant = colors_table.get(String(color_id))
	if entry is Dictionary:
		return int((entry as Dictionary).get("voltage", 0))
	return 0


## [-span, span] araliginda esit aralikli konumlar.
static func _spread(count: int, span: float) -> Array[float]:
	var result: Array[float] = []
	if count <= 1:
		result.append(0.0)
		return result
	for i: int in count:
		result.append(-span + 2.0 * span * float(i) / float(count - 1))
	return result


## Sabit noktasi olmayan karisim: hicbir kablo dogrudan altindaki renge denk gelmez.
static func _derangement(count: int, rng: RandomNumberGenerator) -> Array[int]:
	var order: Array[int] = []
	for i: int in count:
		order.append(i)
	for i: int in range(count - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: int = order[i]
		order[i] = order[j]
		order[j] = tmp
	if count <= 1:
		return order
	for i: int in count:
		if order[i] == i:
			var j: int = (i + 1) % count
			var tmp: int = order[i]
			order[i] = order[j]
			order[j] = tmp
	return order


static func _socket_index_for(sockets: Array[SocketSpec], color_id: StringName) -> int:
	for i: int in sockets.size():
		if sockets[i].color_id == color_id:
			return i
	return 0
