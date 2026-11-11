class_name ContactMonitor
extends RefCounted

## Temas taraması + aşırı yük barı: farklı renkli kabloların teması, requires_drag
## kuralı, yalıtım kalkanı ve sigorta. Konum/görsel yok; LevelController efektleri
## ve HUD'u yönetir. Saf mantığa yakın: sahnesiz de kurulabilir.
##
## v0.2 modifier'ları (ARCHITECTURE §12):
##  - fast_overload: bar dolum hızı fill_per_second * multiplier (data/balance.json).
##  - sway: canlı hatlar (ObstacleCable) ayrı obstacles listesiyle taranır; temas
##    her zaman kısa devre sayılır ve barı doldurur.
## Modifier yoksa davranış eskisiyle birebir aynıdır (obstacles boş liste).

signal short_circuit(point: Vector3, color: Color)
signal fuse_blown()
signal shield_changed(active: bool)

const MODIFIER_FAST_OVERLOAD: StringName = &"fast_overload"

## Açılışta halatlar fizikle otururken temas sayılmaz (oyuncu hile yapamaz: intro ~0.9 sn).
const WARMUP_SECONDS: float = 1.1

var overload: OverloadModel = OverloadModel.new()
var shorts: int = 0
var requires_drag: bool = true
var active_contacts: int = 0
## cable_index -> temas ettiği kare sayısı (altın keski hedefi için).
var contact_ticks: Dictionary = {}
## QA: force_contact sırasında sürükleme kapısını geçici açar; gerçek tarama korunur.
var force_active_contacts: bool = false

var _scanner: ContactScanner = ContactScanner.new()
var _contact_distance: float = 0.078
var _wrong_penalty: float = 0.12
var _shield_visual: bool = false
var _fused: bool = false
var _warmup_left: float = WARMUP_SECONDS
var _pairs: Dictionary = {}
var _has_fast_overload: bool = false
var _fast_multiplier: float = 1.5


## balance: data/balance.json; modifiers: KnotLevel.modifiers (boş = eski davranış).
func configure(balance: Dictionary, modifiers: Array[StringName] = []) -> void:
	var contact: Dictionary = _section(balance, "contact")
	var overload_cfg: Dictionary = _section(balance, "overload")
	var modifiers_cfg: Dictionary = _section(balance, "modifiers")
	var fast_cfg: Dictionary = _section(modifiers_cfg, "fast_overload")
	_contact_distance = float(contact.get("distance", 0.078))
	requires_drag = bool(contact.get("requires_drag", true))
	_wrong_penalty = float(overload_cfg.get("wrong_socket_penalty", 0.12))
	_fast_multiplier = maxf(1.0, float(fast_cfg.get("multiplier", 1.5)))
	_has_fast_overload = modifiers.has(MODIFIER_FAST_OVERLOAD)
	var fill: float = float(overload_cfg.get("fill_per_second", 0.55))
	if _has_fast_overload:
		fill *= _fast_multiplier
	overload.configure(fill,
		float(overload_cfg.get("drain_per_second", 0.32)),
		float(overload_cfg.get("extra_per_contact", 0.3)))


## fast_overload aktifken uygulanan çarpan (tanı/test).
func fill_multiplier() -> float:
	return _fast_multiplier if _has_fast_overload else 1.0


func tick(delta: float, cables: Array[CableNode], obstacles: Array[CableNode]) -> void:
	if _warmup_left > 0.0:
		# fizik otursun: açılış temasları kısa devre sayılmaz
		_warmup_left = maxf(0.0, _warmup_left - delta)
		active_contacts = 0
		overload.tick(delta, 0)
		_sync_shield()
		return
	_scan(cables, obstacles)
	overload.tick(delta, active_contacts)
	_sync_shield()
	_emit_fuse_if_needed()


## Yanlış prize takma cezası (kalkan engeller) + olası sigorta.
func apply_wrong_socket_penalty() -> void:
	overload.add_load(_wrong_penalty)
	_emit_fuse_if_needed()


## Yedek sigorta: yük sıfır, temas sayaçları temiz; kalkan LevelController'da eklenir.
func reset() -> void:
	overload.reset()
	_pairs.clear()
	contact_ticks.clear()
	active_contacts = 0
	_fused = false
	force_active_contacts = false
	_sync_shield()


func refresh_shield() -> void:
	_sync_shield()


func is_fused() -> bool:
	return overload.blown


func _scan(cables: Array[CableNode], obstacles: Array[CableNode]) -> void:
	var cable_count: int = cables.size()
	var targets: Array[CableNode] = cables
	if not obstacles.is_empty():
		targets = []
		for cable: CableNode in cables:
			targets.append(cable)
		for obstacle: CableNode in obstacles:
			targets.append(obstacle)
	var pairs: Array[Dictionary] = _scanner.scan(targets, _contact_distance)
	var next: Dictionary = {}
	var qualifying: int = 0
	for pair: Dictionary in pairs:
		var a: int = int(pair.get("a", -1))
		var b: int = int(pair.get("b", -1))
		if a < 0 or b < 0 or a >= targets.size() or b >= targets.size() or a == b:
			continue
		var a_obstacle: bool = a >= cable_count
		var b_obstacle: bool = b >= cable_count
		if a_obstacle and b_obstacle:
			continue  # iki canlı hat birbirine değse de ekstra ceza yok
		var dragging: bool = false
		if not a_obstacle:
			dragging = dragging or cables[a].is_dragging()
		if not b_obstacle:
			dragging = dragging or cables[b].is_dragging()
		if not a_obstacle and not b_obstacle:
			var cable_a: CableNode = cables[a]
			var cable_b: CableNode = cables[b]
			if cable_a.spec == null or cable_b.spec == null:
				continue
			if cable_a.spec.color_id == cable_b.spec.color_id:
				continue  # aynı renk teması güvenli
		# ADALET KURALI: dinlenen kablolar teması kıvılcım/bar/sayı ÜRETMEZ.
		# Canlı hat bile yalnızca bir kablo sürüklenirken tehlikelidir.
		if not (force_active_contacts or dragging or not requires_drag):
			continue
		var key: String = "%d:%d" % [mini(a, b), maxi(a, b)]
		next[key] = true
		var color: Color = _pair_color(targets, a, b, cable_count)
		for cable_index: int in [a, b]:
			if cable_index < cable_count:
				contact_ticks[cable_index] = int(contact_ticks.get(cable_index, 0)) + 1
		if not _pairs.has(key):
			shorts += 1
			var point: Vector3 = pair.get("point", Vector3.ZERO)
			short_circuit.emit(point, color)
		qualifying += 1
	_pairs = next
	active_contacts = qualifying


func _pair_color(targets: Array[CableNode], a: int, b: int, cable_count: int) -> Color:
	var color_a: Color = Color(1.0, 0.72, 0.28)
	var color_b: Color = Color(1.0, 0.72, 0.28)
	if a < cable_count:
		color_a = targets[a].color()
	if b < cable_count:
		color_b = targets[b].color()
	return color_a.lerp(color_b, 0.5)


func _sync_shield() -> void:
	var active: bool = overload.is_shielded()
	if active == _shield_visual:
		return
	_shield_visual = active
	shield_changed.emit(active)


func _emit_fuse_if_needed() -> void:
	if overload.blown and not _fused:
		_fused = true
		fuse_blown.emit()


func _section(balance: Dictionary, key: String) -> Dictionary:
	var raw: Variant = balance.get(key, {})
	if raw is Dictionary:
		return raw as Dictionary
	return {}
