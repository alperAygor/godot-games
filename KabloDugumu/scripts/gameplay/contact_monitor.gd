class_name ContactMonitor
extends RefCounted

## Temas taraması + aşırı yük barı: farklı renkli kabloların teması, requires_drag
## kuralı, yalıtım kalkanı ve sigorta. Konum/görsel yok; LevelController efektleri
## ve HUD'u yönetir. Saf mantığa yakın: sahnesiz de kurulabilir.

signal short_circuit(point: Vector3, color: Color)
signal fuse_blown()
signal shield_changed(active: bool)

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


func configure(balance: Dictionary) -> void:
	var contact: Dictionary = _section(balance, "contact")
	var overload_cfg: Dictionary = _section(balance, "overload")
	_contact_distance = float(contact.get("distance", 0.078))
	requires_drag = bool(contact.get("requires_drag", true))
	_wrong_penalty = float(overload_cfg.get("wrong_socket_penalty", 0.12))
	overload.configure(float(overload_cfg.get("fill_per_second", 0.55)),
		float(overload_cfg.get("drain_per_second", 0.32)),
		float(overload_cfg.get("extra_per_contact", 0.3)))


func tick(delta: float, cables: Array[CableNode]) -> void:
	if _warmup_left > 0.0:
		# fizik otursun: açılış temasları kısa devre sayılmaz
		_warmup_left = maxf(0.0, _warmup_left - delta)
		active_contacts = 0
		overload.tick(delta, 0)
		_sync_shield()
		return
	_scan(cables)
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


func _scan(cables: Array[CableNode]) -> void:
	var pairs: Array[Dictionary] = _scanner.scan(cables, _contact_distance)
	var next: Dictionary = {}
	var qualifying: int = 0
	for pair: Dictionary in pairs:
		var a: int = int(pair.get("a", -1))
		var b: int = int(pair.get("b", -1))
		if a < 0 or b < 0 or a >= cables.size() or b >= cables.size() or a == b:
			continue
		var cable_a: CableNode = cables[a]
		var cable_b: CableNode = cables[b]
		if cable_a.spec == null or cable_b.spec == null:
			continue
		if cable_a.spec.color_id == cable_b.spec.color_id:
			continue  # aynı renk teması güvenli
		# ADALET KURALI: iki dinlenen kablo teması kıvılcım/bar/sayı ÜRETMEZ.
		# Yalnızca en az bir kablo sürükleniyorsa (requires_drag) gerçek kısa devredir.
		if not (force_active_contacts or cable_a.is_dragging()
				or cable_b.is_dragging() or not requires_drag):
			continue
		var key: String = "%d:%d" % [mini(a, b), maxi(a, b)]
		next[key] = true
		contact_ticks[a] = int(contact_ticks.get(a, 0)) + 1
		contact_ticks[b] = int(contact_ticks.get(b, 0)) + 1
		if not _pairs.has(key):
			shorts += 1
			var point: Vector3 = pair.get("point", Vector3.ZERO)
			var color: Color = cable_a.spec.color.lerp(cable_b.spec.color, 0.5)
			short_circuit.emit(point, color)
		qualifying += 1
	_pairs = next
	active_contacts = qualifying


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
