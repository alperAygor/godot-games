extends TestCase

## KnotLevel uretim garantileri: veri korunur, deterministik, ulasilabilir,
## baslangicta temas yok, fisler daginik, prizler essiz/karmasik, panoda kalir.
## Veri FileAccess ile okunur (autoload gerekmez, -s modunda da calisir).

const LEVELS_PATH: String = "res://data/levels.json"
const BALANCE_PATH: String = "res://data/balance.json"
const CONTACT_FACTOR: float = 1.1
const MIN_REACH_SLACK: float = 0.15
const REACH_FACTOR: float = 0.97
const LENGTH_TOLERANCE: float = 0.02

var _colors: Dictionary = {}
var _configs: Array[Dictionary] = []
var _balance: Dictionary = {}
var _board: Dictionary = {}
var _levels: Array[KnotLevel] = []
var _loaded: bool = false


func before_each() -> void:
	if _loaded:
		return
	_loaded = true
	var levels_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(LEVELS_PATH))
	var balance_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(BALANCE_PATH))
	assert_true(levels_value is Dictionary, "data/levels.json sozluk olmali")
	assert_true(balance_value is Dictionary, "data/balance.json sozluk olmali")
	if not (levels_value is Dictionary) or not (balance_value is Dictionary):
		return
	var levels_data: Dictionary = levels_value as Dictionary
	_balance = balance_value as Dictionary
	var raw_colors: Variant = levels_data.get("colors", {})
	if raw_colors is Dictionary:
		_colors = raw_colors as Dictionary
	var raw_board: Variant = _balance.get("board", {})
	if raw_board is Dictionary:
		_board = raw_board as Dictionary
	var raw_levels: Variant = levels_data.get("levels", [])
	if not (raw_levels is Array):
		return
	for entry: Variant in raw_levels as Array:
		if not (entry is Dictionary):
			continue
		var config: Dictionary = entry as Dictionary
		_configs.append(config)
		_levels.append(KnotLevel.from_config(config, _colors, _balance))


# --- yardimcilar -----------------------------------------------------------

func _board_float(key: String, fallback: float) -> float:
	var raw: Variant = _board.get(key)
	if raw == null:
		return fallback
	return float(raw)


func _cable_float(key: String, fallback: float) -> float:
	var raw: Variant = _balance.get("cable", {})
	if raw is Dictionary:
		return float((raw as Dictionary).get(key, fallback))
	return fallback


func _contact_distance() -> float:
	var raw: Variant = _balance.get("contact", {})
	if raw is Dictionary:
		return float((raw as Dictionary).get("distance", 0.078))
	return 0.078


func _rest_gap() -> float:
	return _cable_float("rest_gap", 0.24)


func _socket_y() -> float:
	return _board_float("socket_y", -1.22)


func _source_y() -> float:
	return _board_float("source_y", 1.18)


func _surface_z() -> float:
	return _board_float("board_surface_z", 0.055)


## Geometri/duzen esitligi (modifier listesi haric; modifiersiz davranis testi icin).
func _assert_layout_equal(first: KnotLevel, second: KnotLevel) -> void:
	assert_eq(first.cables.size(), second.cables.size(), "kablo sayisi")
	assert_eq(first.sockets.size(), second.sockets.size(), "priz sayisi")
	for i: int in first.sockets.size():
		var a_socket: SocketSpec = first.sockets[i]
		var b_socket: SocketSpec = second.sockets[i]
		assert_eq(a_socket.color_id, b_socket.color_id, "priz rengi")
		assert_true(a_socket.position.is_equal_approx(b_socket.position), "priz konumu")
	for i: int in first.cables.size():
		var a_cable: CableSpec = first.cables[i]
		var b_cable: CableSpec = second.cables[i]
		assert_eq(a_cable.color_id, b_cable.color_id, "kablo rengi")
		assert_true(a_cable.source.is_equal_approx(b_cable.source), "kaynak konumu")
		assert_true(a_cable.plug_rest.is_equal_approx(b_cable.plug_rest), "fis konumu")
		assert_true(a_cable.socket.is_equal_approx(b_cable.socket), "priz hedefi")
		assert_almost_eq(a_cable.length, b_cable.length, 0.0001, "uzunluk")
		var points_equal: bool = a_cable.points.size() == b_cable.points.size()
		for p: int in a_cable.points.size() if points_equal else 0:
			if not a_cable.points[p].is_equal_approx(b_cable.points[p]):
				points_equal = false
				break
		assert_true(points_equal, "egri noktalari birebir ayni olmali")


func _assert_levels_equal(first: KnotLevel, second: KnotLevel) -> void:
	assert_eq(first.level_index, second.level_index, "level_index")
	assert_eq(first.level_name, second.level_name, "level_name")
	assert_almost_eq(first.par_seconds, second.par_seconds, 0.0001, "par_seconds")
	assert_eq(first.seed, second.seed, "seed")
	assert_eq(first.modifiers, second.modifiers, "modifier listesi")
	assert_eq(first.cables.size(), second.cables.size(), "kablo sayisi")
	assert_eq(first.sockets.size(), second.sockets.size(), "priz sayisi")
	for i: int in first.sockets.size():
		var a_socket: SocketSpec = first.sockets[i]
		var b_socket: SocketSpec = second.sockets[i]
		assert_eq(a_socket.color_id, b_socket.color_id, "priz rengi")
		assert_true(a_socket.position.is_equal_approx(b_socket.position), "priz konumu")
	for i: int in first.cables.size():
		var a_cable: CableSpec = first.cables[i]
		var b_cable: CableSpec = second.cables[i]
		assert_eq(a_cable.color_id, b_cable.color_id, "kablo rengi")
		assert_true(a_cable.source.is_equal_approx(b_cable.source), "kaynak konumu")
		assert_true(a_cable.socket.is_equal_approx(b_cable.socket), "priz hedefi")
		assert_eq(a_cable.socket_index, b_cable.socket_index, "priz sirasi")
		assert_true(a_cable.plug_rest.is_equal_approx(b_cable.plug_rest), "fis konumu")
		assert_almost_eq(a_cable.length, b_cable.length, 0.0001, "uzunluk")
		assert_eq(a_cable.points.size(), b_cable.points.size(), "egri nokta sayisi")
		var points_equal: bool = true
		for p: int in a_cable.points.size():
			if not a_cable.points[p].is_equal_approx(b_cable.points[p]):
				points_equal = false
				break
		assert_true(points_equal, "egri noktalari birebir ayni olmali")


# --- veri ------------------------------------------------------------------

func test_data_has_twelve_levels_with_required_fields() -> void:
	assert_eq(_configs.size(), 12, "12 bolum olmali")
	for i: int in _configs.size():
		var config: Dictionary = _configs[i]
		assert_eq(int(config.get("id", 0)), i + 1, "bolum id sirasi")
		assert_true(String(config.get("name", "")) != "", "bolum %d adi bos" % (i + 1))
		assert_true(String(config.get("hint", "")) != "", "bolum %d ipucu bos" % (i + 1))
		assert_greater(float(config.get("par_seconds", 0.0)), 0.0, "bolum %d par suresi" % (i + 1))
		var count: int = int(config.get("cables", 0))
		assert_true(count >= 3 and count <= 7, "bolum %d kablo sayisi 3..7" % (i + 1))


func test_levels_build_with_matching_counts() -> void:
	assert_eq(_levels.size(), 12, "tum bolumler uretilmeli")
	var points_expected: int = int(_board.get("cable_points", 18))
	for level: KnotLevel in _levels:
		assert_eq(level.cables.size(), level.sockets.size(),
			"bolum %d: kablo/priz sayisi esit" % level.level_index)
		assert_true(level.cables.size() >= 3 and level.cables.size() <= 7,
			"bolum %d: 3..7 kablo" % level.level_index)
		for cable: CableSpec in level.cables:
			assert_eq(cable.points.size(), points_expected,
				"bolum %d: egri nokta sayisi" % level.level_index)
			assert_eq(cable.index, level.cables.find(cable),
				"bolum %d: kablo index sirali" % level.level_index)


func test_colors_are_unique_within_each_level() -> void:
	for level: KnotLevel in _levels:
		var cable_colors: Array[StringName] = []
		for cable: CableSpec in level.cables:
			assert_false(cable_colors.has(cable.color_id),
				"bolum %d: kablo rengi tekrar etmemeli" % level.level_index)
			cable_colors.append(cable.color_id)
		var socket_colors: Array[StringName] = []
		for socket: SocketSpec in level.sockets:
			assert_false(socket_colors.has(socket.color_id),
				"bolum %d: priz rengi tekrar etmemeli" % level.level_index)
			socket_colors.append(socket.color_id)
		for color_id: StringName in cable_colors:
			assert_true(socket_colors.has(color_id),
				"bolum %d: her kablonun prizi var" % level.level_index)


func test_level_metadata_is_preserved() -> void:
	for i: int in _configs.size():
		var config: Dictionary = _configs[i]
		var level: KnotLevel = _levels[i]
		assert_eq(level.level_index, int(config.get("id", 0)))
		assert_eq(level.level_name, String(config.get("name", "")))
		assert_eq(level.hint, String(config.get("hint", "")))
		assert_almost_eq(level.par_seconds, float(config.get("par_seconds", 0.0)), 0.0001)
		assert_eq(level.seed, int(config.get("seed", 0)))
		assert_eq(level.cables.size(), int(config.get("cables", 0)))
		var expected: Array[StringName] = KnotLevel.modifiers_from(config)
		assert_eq(level.modifiers, expected,
			"bolum %d: modifiers config'ten okunmali" % level.level_index)


# --- determinizm -----------------------------------------------------------

func test_generation_is_deterministic() -> void:
	_assert_levels_equal(_levels[0],
		KnotLevel.from_config(_configs[0], _colors, _balance))
	_assert_levels_equal(_levels[11],
		KnotLevel.from_config(_configs[11], _colors, _balance))


func test_different_seed_changes_layout() -> void:
	var variant: Dictionary = (_configs[0] as Dictionary).duplicate(true)
	variant["seed"] = int(variant.get("seed", 1)) + 1
	var other: KnotLevel = KnotLevel.from_config(variant, _colors, _balance)
	var current: KnotLevel = _levels[0]
	assert_eq(other.cables.size(), current.cables.size())
	var changed: bool = false
	for i: int in current.cables.size():
		if not current.cables[i].plug_rest.is_equal_approx(other.cables[i].plug_rest):
			changed = true
			break
	assert_true(changed, "farkli seed farkli fis duzeni vermeli")


# --- (a) ulasilabilirlik ---------------------------------------------------

func test_reachability_guarantee_for_every_cable() -> void:
	for level: KnotLevel in _levels:
		var worst_slack: float = INF
		for cable: CableSpec in level.cables:
			var needed: float = cable.source.distance_to(cable.socket) + MIN_REACH_SLACK
			worst_slack = minf(worst_slack, cable.length - needed)
		assert_greater(worst_slack, 0.0,
			"bolum %d: length >= |source-socket| + 0.15" % level.level_index)


func test_rope_reach_factor_reaches_own_socket() -> void:
	# CableRope suruklemeyi length*0.97 yaricapina kirpar; fis prize yetismeli.
	for level: KnotLevel in _levels:
		var worst_reach: float = INF
		for cable: CableSpec in level.cables:
			var straight: float = cable.source.distance_to(cable.socket)
			worst_reach = minf(worst_reach, cable.length * REACH_FACTOR - straight)
		assert_greater(worst_reach, 0.0,
			"bolum %d: rope reach faktoru prizine yeter" % level.level_index)


func test_initial_curve_length_matches_cable_length() -> void:
	for level: KnotLevel in _levels:
		var worst_error: float = 0.0
		for cable: CableSpec in level.cables:
			worst_error = maxf(worst_error,
				absf(CableMath.polyline_length(cable.points) - cable.length))
		assert_true(worst_error <= LENGTH_TOLERANCE,
			"bolum %d: egri yay uzunlugu length'e esit (hata %.4f)" % [level.level_index, worst_error])


# --- (b) baslangicta farkli renk temasi yok --------------------------------

func test_no_different_color_contact_at_start() -> void:
	var threshold: float = _contact_distance() * CONTACT_FACTOR
	for level: KnotLevel in _levels:
		var closest: float = INF
		var pairs: int = 0
		for i: int in level.cables.size():
			for j: int in range(i + 1, level.cables.size()):
				if level.cables[i].color_id == level.cables[j].color_id:
					continue
				pairs += 1
				closest = minf(closest, CableMath.polyline_distance(
					level.cables[i].points, level.cables[j].points))
		assert_true(pairs > 0, "bolum %d: farkli renk cifti var" % level.level_index)
		assert_greater(closest, threshold,
			"bolum %d: baslangicta farkli renk temas yok (en yakin %.4f)" % [level.level_index, closest])


# --- (c) fis kendi prizinden uzak ------------------------------------------

func test_plugs_are_far_from_their_socket() -> void:
	for level: KnotLevel in _levels:
		var closest: float = INF
		for cable: CableSpec in level.cables:
			closest = minf(closest, cable.plug_rest.distance_to(cable.socket))
		assert_greater(closest, 0.45,
			"bolum %d: fis kendi prizinden > 0.45 uzak" % level.level_index)


func test_plugs_are_far_from_all_sockets() -> void:
	for level: KnotLevel in _levels:
		var closest: float = INF
		for cable: CableSpec in level.cables:
			for socket: SocketSpec in level.sockets:
				closest = minf(closest, cable.plug_rest.distance_to(socket.position))
		assert_greater(closest, 0.45,
			"bolum %d: fisler tum prizlerden > 0.45 uzak" % level.level_index)


# --- (h) fis kendi kaynagindan yatayda uzak (dugum gorunumu) ----------------

func test_plugs_are_horizontally_far_from_their_source() -> void:
	for level: KnotLevel in _levels:
		var closest: float = INF
		for cable: CableSpec in level.cables:
			closest = minf(closest, absf(cable.plug_rest.x - cable.source.x))
		assert_true(closest >= KnotLevel.MIN_PLUG_SOURCE_DX - 0.0001,
			"bolum %d: fis kaynagindan >= %.2f m yatay uzakta (en yakin %.3f)"
				% [level.level_index, KnotLevel.MIN_PLUG_SOURCE_DX, closest])


func test_cables_hang_diagonally_not_straight_down() -> void:
	# Her kabloda fis kaynagin tam altinda DEGIL: ilk halatlar capraz sarkar.
	for level: KnotLevel in _levels:
		var diagonal: int = 0
		for cable: CableSpec in level.cables:
			if absf(cable.plug_rest.x - cable.source.x) >= KnotLevel.MIN_PLUG_SOURCE_DX:
				diagonal += 1
		assert_eq(diagonal, level.cables.size(),
			"bolum %d: tum halatlar capraz" % level.level_index)


# --- (d) fisler birbirinden uzak ve panoda ---------------------------------

func test_plugs_respect_rest_gap_and_board_bounds() -> void:
	var max_x: float = _board_float("width", 1.7) * 0.5
	var max_y: float = _board_float("height", 3.1) * 0.5
	var rest_gap: float = _rest_gap()
	for level: KnotLevel in _levels:
		var closest: float = INF
		for i: int in level.cables.size():
			for j: int in range(i + 1, level.cables.size()):
				closest = minf(closest,
					level.cables[i].plug_rest.distance_to(level.cables[j].plug_rest))
		assert_true(closest >= rest_gap - 0.0001,
			"bolum %d: fisler arasi >= rest_gap (en yakin %.4f)" % [level.level_index, closest])
		for cable: CableSpec in level.cables:
			assert_true(absf(cable.plug_rest.x) <= max_x,
				"bolum %d: fis x panoda" % level.level_index)
			assert_true(absf(cable.plug_rest.y) <= max_y,
				"bolum %d: fis y panoda" % level.level_index)


# --- (e) priz eslesmesi ve karmasik sira -----------------------------------

func test_sockets_match_cables_uniquely() -> void:
	for level: KnotLevel in _levels:
		for cable: CableSpec in level.cables:
			assert_true(cable.socket_index >= 0 and cable.socket_index < level.sockets.size(),
				"bolum %d: socket_index gecerli" % level.level_index)
			var socket: SocketSpec = level.sockets[cable.socket_index]
			assert_eq(socket.color_id, cable.color_id,
				"bolum %d: priz rengi kablo rengine esit" % level.level_index)
			assert_true(socket.position.is_equal_approx(cable.socket),
				"bolum %d: cable.socket priz konumuna esit" % level.level_index)


func test_socket_order_differs_from_source_order() -> void:
	for level: KnotLevel in _levels:
		assert_false(level.color_order_matches_source(),
			"bolum %d: kaynak ve priz renk sirasi farkli olmali" % level.level_index)
		for i: int in level.cables.size():
			assert_true(level.cables[i].color_id != level.sockets[i].color_id,
				"bolum %d: dogrudan altinda ayni renk olmamali" % level.level_index)


# --- (g) pano duzlemi ve sinirlar ------------------------------------------

func test_sources_and_sockets_are_inside_board_on_plane() -> void:
	var max_x: float = _board_float("width", 1.7) * 0.5
	var max_y: float = _board_float("height", 3.1) * 0.5
	var surface_z: float = _surface_z()
	for level: KnotLevel in _levels:
		for cable: CableSpec in level.cables:
			assert_true(absf(cable.source.x) <= max_x, "kaynak x panoda")
			assert_true(cable.source.y <= max_y and cable.source.y >= -max_y, "kaynak y panoda")
			assert_almost_eq(cable.source.z, surface_z, 0.0001, "kaynak z pano yuzeyi")
			assert_true(absf(cable.socket.x) <= max_x, "priz x panoda")
			assert_true(cable.socket.y <= max_y and cable.socket.y >= -max_y, "priz y panoda")
			assert_almost_eq(cable.socket.z, surface_z, 0.0001, "priz z pano yuzeyi")
		var ascending: bool = true
		for i: int in range(1, level.cables.size()):
			if level.cables[i].source.x <= level.cables[i - 1].source.x:
				ascending = false
		assert_true(ascending, "bolum %d: kaynaklar soldan saga" % level.level_index)


func test_cable_curves_stay_on_board() -> void:
	var max_x: float = _board_float("width", 1.7) * 0.5
	var max_y: float = _board_float("height", 3.1) * 0.5
	var surface_z: float = _surface_z()
	var layer_gap: float = _cable_float("rest_layer_gap", 0.12)
	for level: KnotLevel in _levels:
		var violations: int = 0
		var worst_z_low: float = 0.0
		var worst_z_high: float = 0.0
		for cable: CableSpec in level.cables:
			for point: Vector3 in cable.points:
				if absf(point.x) > max_x or absf(point.y) > max_y:
					violations += 1
				worst_z_low = minf(worst_z_low, point.z - surface_z)
				worst_z_high = maxf(worst_z_high, point.z - surface_z)
		assert_eq(violations, 0,
			"bolum %d: halat egrisi pano icinde" % level.level_index)
		assert_true(worst_z_low >= -0.0001,
			"bolum %d: halat pano yuzeyinin onunde" % level.level_index)
		assert_true(worst_z_high <= layer_gap * 3.0 + 0.0001,
			"bolum %d: halat katman araligini asmaz (%.3f)" % [level.level_index, worst_z_high])


## v0.2 "orgu" garantisi: iki katman panonun onunde ayrilir; katmanlar arasi
## z farki temas esiginden buyuk oldugu icin capraz halatlar baslangicta degmez.
func test_cable_layers_are_separated_and_weave() -> void:
	var surface_z: float = _surface_z()
	var layer_gap: float = _cable_float("rest_layer_gap", 0.12)
	var contact: float = _contact_distance()
	for level: KnotLevel in _levels:
		var layers: Dictionary = {}
		for cable: CableSpec in level.cables:
			var offset: float = cable.plug_rest.z - surface_z
			var layer: float = offset / maxf(layer_gap, 0.0001)
			assert_almost_eq(layer, roundf(layer), 0.02,
				"bolum %d: fis katmani veriye uygun (%.3f)" % [level.level_index, offset])
			assert_true(layer >= -0.02 and layer <= 2.02,
				"bolum %d: katman 0..2 araliginda" % level.level_index)
			layers[int(roundf(layer))] = true
		assert_true(layers.size() >= 2,
			"bolum %d: en az iki katman var (orgu)" % level.level_index)
		assert_true(layer_gap > contact * 1.15,
			"katman araligi temas esiginden buyuk (%.3f > %.3f)" % [layer_gap, contact])


# --- dugum hissi / fis dagilimi --------------------------------------------

func test_plugs_scattered_in_middle_band() -> void:
	var socket_y: float = _socket_y()
	var source_y: float = _source_y()
	for level: KnotLevel in _levels:
		var min_y: float = INF
		var max_y: float = -INF
		var min_x: float = INF
		var max_x: float = -INF
		for cable: CableSpec in level.cables:
			min_y = minf(min_y, cable.plug_rest.y)
			max_y = maxf(max_y, cable.plug_rest.y)
			min_x = minf(min_x, cable.plug_rest.x)
			max_x = maxf(max_x, cable.plug_rest.x)
		assert_greater(min_y, socket_y + 0.45,
			"bolum %d: fisler priz seridinin ustunde" % level.level_index)
		assert_true(max_y < source_y,
			"bolum %d: fisler kaynak hattinin altinda" % level.level_index)
		assert_greater(max_y - min_y, 0.15,
			"bolum %d: fisler dikeyde dagilmis" % level.level_index)
		assert_greater(max_x - min_x, 0.2,
			"bolum %d: fisler yatayda dagilmis" % level.level_index)


## v0.2 zorluk egrisi: kablo 3 -> 7, par L1 45 sn -> L12 95 sn, modifier'lar
## kademeli girer (her bolumun kumesi bir oncekini kapsar).
func test_difficulty_curve_is_escalating() -> void:
	var previous_cables: int = 0
	var previous_par: float = 0.0
	var previous_modifiers: Array[StringName] = []
	var first_seen: Dictionary = {}
	for i: int in _configs.size():
		var config: Dictionary = _configs[i]
		var level: KnotLevel = _levels[i]
		var cables: int = int(config.get("cables", 0))
		var par: float = float(config.get("par_seconds", 0.0))
		assert_true(cables >= previous_cables, "bolum %d: kablo sayisi azalmamali" % (i + 1))
		assert_true(par >= previous_par, "bolum %d: par suresi azalmamali" % (i + 1))
		assert_true(float(config.get("par_seconds", 0.0)) <= 95.0,
			"bolum %d: par <= 95 sn (v0.2 hedefi)" % (i + 1))
		for modifier: StringName in previous_modifiers:
			assert_true(level.modifiers.has(modifier),
				"bolum %d: onceki modifier '%s' korunmali" % [i + 1, modifier])
		if i == 0:
			assert_true(level.modifiers.is_empty(), "bolum 1 temel (modifier yok)")
		for modifier: StringName in level.modifiers:
			if not first_seen.has(modifier):
				first_seen[modifier] = i + 1
		previous_cables = cables
		previous_par = par
		previous_modifiers = level.modifiers
	assert_eq(int(first_seen.get(KnotLevel.MODIFIER_SWAY, -1)), 5, "sway L5'te girer")
	assert_eq(int(first_seen.get(KnotLevel.MODIFIER_LOCKED_SOCKET, -1)), 7,
		"locked_socket L7'de girer")
	assert_eq(int(first_seen.get(KnotLevel.MODIFIER_BLACKOUT, -1)), 9, "blackout L9'da girer")
	assert_eq(int(first_seen.get(KnotLevel.MODIFIER_FAST_OVERLOAD, -1)), 10,
		"fast_overload L10'da girer")
	assert_almost_eq(float(_configs[0].get("par_seconds", 0.0)), 45.0, 0.001, "L1 par ~45")
	assert_almost_eq(float(_configs[11].get("par_seconds", 0.0)), 95.0, 0.001, "L12 par ~95")
	assert_eq(int(_configs[11].get("cables", 0)), 7, "L12: 7 kablo")
	assert_eq(_levels[11].modifiers.size(), KnotLevel.VALID_MODIFIERS.size(),
		"L12: tum modifier'lar acik")


## Modifier'lar duzeni (kablo/egri/priz konumlari) DEGISTIRMEZ; yalnizca kilit
## isaretleri ve oyun içi mekanikler eklenir (geri uyum: ARCHITECTURE §12).
func test_modifiers_do_not_change_knot_layout() -> void:
	var config: Dictionary = (_configs[6] as Dictionary).duplicate(true)
	var with_modifiers: KnotLevel = KnotLevel.from_config(config, _colors, _balance)
	var bare: Dictionary = config.duplicate(true)
	bare["modifiers"] = []
	var without_modifiers: KnotLevel = KnotLevel.from_config(bare, _colors, _balance)
	assert_eq(without_modifiers.modifiers.size(), 0, "modifiersiz bolum")
	assert_eq(with_modifiers.modifiers.size(), 2, "L7: sway + locked_socket")
	_assert_layout_equal(with_modifiers, without_modifiers)
	assert_true(with_modifiers.locked_socket_count() > 0, "L7: kilitli priz var")
	assert_eq(without_modifiers.locked_socket_count(), 0, "modifiersiz: kilit yok")


func test_generation_is_organic_not_corridor_fallback() -> void:
	var fallback_count: int = 0
	for level: KnotLevel in _levels:
		if level.used_fallback:
			fallback_count += 1
	assert_eq(fallback_count, 0, "veri seed'leri organik duzen uretmeli (yedek duzen yok)")


func test_board_section_equals_full_balance_layout() -> void:
	# panel-world layout olarak balance["board"] gecerse de ayni duzen cikmali.
	var config: Dictionary = _configs[11]
	var full: KnotLevel = KnotLevel.from_config(config, _colors, _balance)
	var board_only: KnotLevel = KnotLevel.from_config(config, _colors, _board)
	_assert_levels_equal(full, board_only)
