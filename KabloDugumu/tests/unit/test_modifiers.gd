extends TestCase

## v0.2 bolum modifier davranislari (ARCHITECTURE §12):
##  - sway: canli hat plani (sayi, periyot >= 2.5 sn, pano siniri, determinizm)
##  - locked_socket: 0.6 sn tutma kurali (saf), veri odakli atama
##  - fast_overload: dolum carpani 1.5, modifier yoksa taban hiz aynen korunur
##  - blackout: yumusak faz kurali
## Veri FileAccess ile okunur (autoload gerekmez, -s modunda da calisir).

const LEVELS_PATH: String = "res://data/levels.json"
const BALANCE_PATH: String = "res://data/balance.json"

var _colors: Dictionary = {}
var _configs: Array[Dictionary] = []
var _balance: Dictionary = {}
var _board: Dictionary = {}
var _loaded: bool = false


func before_each() -> void:
	if _loaded:
		return
	_loaded = true
	var levels_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(LEVELS_PATH))
	var balance_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(BALANCE_PATH))
	assert_true(levels_value is Dictionary, "levels.json sozluk olmali")
	assert_true(balance_value is Dictionary, "balance.json sozluk olmali")
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
		if entry is Dictionary:
			_configs.append(entry as Dictionary)


func _modifier_cfg(modifier: String) -> Dictionary:
	var raw: Variant = _balance.get("modifiers", {})
	if raw is Dictionary:
		var entry: Variant = (raw as Dictionary).get(modifier, {})
		if entry is Dictionary:
			return entry as Dictionary
	return {}


func _build_level(level_number: int) -> KnotLevel:
	return KnotLevel.from_config(_configs[level_number - 1], _colors, _balance)


# --- sway ----------------------------------------------------------------

func test_sway_plan_obeys_period_and_board_bounds() -> void:
	var cfg: Dictionary = _modifier_cfg("sway")
	assert_false(cfg.is_empty(), "balance modifiers.sway olmali")
	var count: int = 2
	var plans: Array[Dictionary] = ObstacleCable.plan_obstacles(12101, count, _board, cfg)
	assert_eq(plans.size(), count, "sway obstacle sayisi")
	var width: float = float(_board.get("width", 1.7))
	var amp_min: float = float(cfg.get("min_amplitude", 0.09))
	var amp_max: float = float(cfg.get("max_amplitude", 0.13))
	for plan: Dictionary in plans:
		var period: float = float(plan.get("period", 0.0))
		var amplitude: float = float(plan.get("amplitude", 0.0))
		assert_true(period >= ObstacleCable.MIN_PERIOD_SECONDS,
			"salinim periyodu >= 2.5 sn (gelen %.2f)" % period)
		assert_true(amplitude >= amp_min - 0.0001 and amplitude <= amp_max + 0.0001,
			"genlik veri araliginda (%.3f)" % amplitude)
		var top: Vector3 = plan.get("top", Vector3.ZERO) as Vector3
		var bottom: Vector3 = plan.get("bottom", Vector3.ZERO) as Vector3
		assert_true(top.y > bottom.y, "ust capa alt capanin ustunde")
		assert_true(absf(top.x) + amplitude <= width * 0.5 + 0.0001,
			"canli hat panoda kalir (x=%.3f, genlik=%.3f)" % [top.x, amplitude])
		assert_almost_eq(top.z, bottom.z, 0.0001, "hat pano duzlemine paralel")


func test_sway_plan_is_deterministic_and_seeded() -> void:
	var cfg: Dictionary = _modifier_cfg("sway")
	var first: Array[Dictionary] = ObstacleCable.plan_obstacles(5501, 1, _board, cfg)
	var second: Array[Dictionary] = ObstacleCable.plan_obstacles(5501, 1, _board, cfg)
	var other: Array[Dictionary] = ObstacleCable.plan_obstacles(5502, 1, _board, cfg)
	assert_eq(first.size(), second.size(), "plan boyutu ayni")
	assert_true((first[0].get("top", Vector3.ZERO) as Vector3).is_equal_approx(
		second[0].get("top", Vector3.ZERO) as Vector3), "ayni seed ayni plan")
	assert_almost_eq(float(first[0].get("period", 0.0)),
		float(second[0].get("period", 0.0)), 0.0001, "ayni periyot")
	var changed: bool = not (first[0].get("top", Vector3.ZERO) as Vector3).is_equal_approx(
		other[0].get("top", Vector3.ZERO) as Vector3)
	assert_true(changed or absf(float(first[0].get("period", 0.0))
		- float(other[0].get("period", 0.0))) > 0.0001, "farkli seed farkli plan")


# --- locked_socket -------------------------------------------------------

func test_locked_socket_hold_seconds_from_balance() -> void:
	var cfg: Dictionary = _modifier_cfg("locked_socket")
	assert_false(cfg.is_empty(), "balance modifiers.locked_socket olmali")
	assert_almost_eq(float(cfg.get("hold_seconds", 0.0)), 0.6, 0.0001,
		"kural: fis 0.6 sn tutulur")
	assert_almost_eq(SocketNode.hold_seconds_from(_balance), 0.6, 0.0001,
		"SocketNode veriyi okur")
	var empty: Dictionary = {}
	assert_almost_eq(SocketNode.hold_seconds_from(empty), SocketNode.DEFAULT_HOLD_SECONDS,
		0.0001, "veri yoksa varsayilan 0.6 sn")


func test_locked_socket_hold_progress_rule() -> void:
	var hold: float = SocketNode.hold_seconds_from(_balance)
	assert_almost_eq(SocketNode.advance_hold(0.0, 0.3, hold), 0.3, 0.0001, "0.3 sn ilerler")
	assert_false(SocketNode.is_hold_complete(0.3, hold), "0.3 sn'de kilit acilmaz")
	assert_almost_eq(SocketNode.advance_hold(0.3, 0.31, hold), hold, 0.0001,
		"toplam 0.61 sn -> hold suresine kirpilir")
	assert_true(SocketNode.is_hold_complete(hold, hold), "0.6 sn'de kilit acilir")
	assert_false(SocketNode.is_hold_complete(hold - 0.001, hold), "sinirda tolerans")
	assert_almost_eq(SocketNode.advance_hold(0.4, -0.5, hold), 0.4, 0.0001,
		"negatif delta ilerlemeyi geri almaz")
	# Birakinca ilerleme sifirlanir (LevelController _reset_hold ile ayni kural).
	assert_almost_eq(SocketNode.advance_hold(0.0, 0.2, hold), 0.2, 0.0001,
		"yeniden tutma sifirdan baslar")


func test_locked_sockets_only_with_modifier() -> void:
	var first: KnotLevel = _build_level(1)
	assert_eq(first.locked_socket_count(), 0, "L1: kilitli priz yok")
	assert_false(first.has_modifier(KnotLevel.MODIFIER_LOCKED_SOCKET), "L1 modifier yok")
	var seventh: KnotLevel = _build_level(7)
	assert_true(seventh.has_modifier(KnotLevel.MODIFIER_LOCKED_SOCKET), "L7 modifier var")
	assert_true(seventh.locked_socket_count() >= 1, "L7: en az 1 kilitli priz")
	var cfg: Dictionary = _modifier_cfg("locked_socket")
	assert_true(seventh.locked_socket_count() <= int(cfg.get("max_locked", 2)),
		"kilit sayisi max_locked'i asmaz")
	var again: KnotLevel = _build_level(7)
	var same: bool = seventh.locked_socket_count() == again.locked_socket_count()
	for i: int in seventh.sockets.size():
		if seventh.sockets[i].locked != again.sockets[i].locked:
			same = false
	assert_true(same, "kilit atamasi deterministik")
	# Kilitli prizlerin geri kalani serbest (oynanabilirlik).
	assert_true(seventh.locked_socket_count() < seventh.sockets.size(),
		"tum prizler kilitlenmez")


# --- fast_overload -------------------------------------------------------

func test_fast_overload_multiplier_applies_to_fill_rate() -> void:
	var overload_cfg: Dictionary = _balance.get("overload", {}) as Dictionary
	var base_fill: float = float(overload_cfg.get("fill_per_second", 0.55))
	var cfg: Dictionary = _modifier_cfg("fast_overload")
	var multiplier: float = float(cfg.get("multiplier", 1.5))
	assert_almost_eq(multiplier, 1.5, 0.0001, "fast_overload carpani 1.5")
	var none: Array[StringName] = []
	var monitor: ContactMonitor = ContactMonitor.new()
	monitor.configure(_balance, none)
	assert_almost_eq(monitor.fill_multiplier(), 1.0, 0.0001, "modifier yoksa carpan 1")
	assert_almost_eq(monitor.overload.current_fill_rate(1), base_fill, 0.0001,
		"modifier yoksa taban dolum hizi aynen korunur")
	var fast: Array[StringName] = [ContactMonitor.MODIFIER_FAST_OVERLOAD]
	var fast_monitor: ContactMonitor = ContactMonitor.new()
	fast_monitor.configure(_balance, fast)
	assert_almost_eq(fast_monitor.fill_multiplier(), multiplier, 0.0001,
		"modifier varsa carpan uygulanir")
	assert_almost_eq(fast_monitor.overload.current_fill_rate(1), base_fill * multiplier,
		0.0001, "bar 1.5 kat hizli dolar")
	# Bir saniyelik temas: fast bar daha cok dolar.
	monitor.overload.tick(1.0, 1)
	fast_monitor.overload.tick(1.0, 1)
	assert_almost_eq(fast_monitor.overload.value, monitor.overload.value * multiplier,
		0.001, "1 sn temas sonucu 1.5x")


# --- blackout ------------------------------------------------------------

func test_blackout_phase_rule_is_smooth_and_bounded() -> void:
	var cfg: Dictionary = _modifier_cfg("blackout")
	assert_true(float(cfg.get("cycle_seconds", 0.0)) >= 6.0,
		"blackout dongusu period >= 6 sn (veri)")
	var max_amount: float = LevelController.MAX_BLACKOUT_AMOUNT
	assert_true(max_amount >= 0.5 and max_amount <= 0.65,
		"oynanabilirlik: max karartma 0.5-0.65 arasi (gelen %.2f)" % max_amount)
	assert_almost_eq(LevelController.blackout_amount_for_phase(0.0), 0.0, 0.0001,
		"dongu basi aydinlik")
	assert_almost_eq(LevelController.blackout_amount_for_phase(0.5), max_amount, 0.0001,
		"dongu ortasi en kisik")
	assert_almost_eq(LevelController.blackout_amount_for_phase(0.25), max_amount * 0.5,
		0.0001, "sinus yarim genlik")
	assert_true(LevelController.blackout_amount_for_phase(1.0) <= 0.0001,
		"dongu kapanisi aydinlik")
	# Yumusak sinus: faz basina degisim kucuk (sert flas yok, ASMR §16).
	var previous: float = LevelController.blackout_amount_for_phase(0.0)
	for step: int in range(1, 201):
		var phase: float = float(step) / 200.0
		var amount: float = LevelController.blackout_amount_for_phase(phase)
		assert_true(amount >= 0.0 and amount <= max_amount + 0.0001,
			"faz %.2f: deger 0..max araliginda (%.3f)" % [phase, amount])
		assert_true(absf(amount - previous) <= 0.06,
			"faz %.2f: gecis yumusak (delta %.3f)" % [phase, absf(amount - previous)])
		previous = amount


# --- modifier listesi / geri uyum ---------------------------------------

func test_modifiers_from_filters_invalid_and_duplicates() -> void:
	var config: Dictionary = {"modifiers": ["sway", "sway", "bilinmeyen", "blackout"]}
	var parsed: Array[StringName] = KnotLevel.modifiers_from(config)
	assert_eq(parsed.size(), 2, "tekrar ve bilinmeyen atilir")
	assert_true(parsed.has(KnotLevel.MODIFIER_SWAY), "sway korunur")
	assert_true(parsed.has(KnotLevel.MODIFIER_BLACKOUT), "blackout korunur")
	var no_key: Array[StringName] = KnotLevel.modifiers_from({})
	assert_eq(no_key.size(), 0, "modifiers anahtari yoksa bos liste")


func test_modifier_levels_hold_expected_mechanics() -> void:
	for i: int in _configs.size():
		var level: KnotLevel = _build_level(i + 1)
		if i < 4:
			assert_eq(level.modifiers.size(), 0, "L%d temel" % (i + 1))
		if i >= 4:
			assert_true(level.has_modifier(KnotLevel.MODIFIER_SWAY),
				"L%d: sway" % (i + 1))
		if i >= 6:
			assert_true(level.has_modifier(KnotLevel.MODIFIER_LOCKED_SOCKET),
				"L%d: locked_socket" % (i + 1))
			assert_true(level.locked_socket_count() >= 1,
				"L%d: kilitli priz atanmis" % (i + 1))
		if i >= 8:
			assert_true(level.has_modifier(KnotLevel.MODIFIER_BLACKOUT),
				"L%d: blackout" % (i + 1))
		if i >= 9:
			assert_true(level.has_modifier(KnotLevel.MODIFIER_FAST_OVERLOAD),
				"L%d: fast_overload" % (i + 1))
