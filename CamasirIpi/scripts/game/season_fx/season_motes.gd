class_name SeasonMotes
extends Node2D

## Havada süzülen yumuşak noktalar: yazın karahindiba tohumu (beyaz, yavaşça yükselir), ilkbaharda
## polen (sıcak sarı, toplamalı parıltı). Ateş böceği gibi bir çapa etrafında gezinir ve çok yavaş
## yükselir; alan tepesinden çıkan alttan yeniden girer. Kare başına yalnız sin/cos.

const WANDER_MIN: float = 30.0
const WANDER_MAX: float = 80.0
const SPEED_MIN: float = 0.15
const SPEED_MAX: float = 0.4
const BLINK_MIN: float = 0.4
const BLINK_MAX: float = 1.0
const SEED: int = 2203

var _motes: Array[Sprite2D] = []
var _anchor: PackedVector2Array = PackedVector2Array()
var _radius: PackedVector2Array = PackedVector2Array()
var _speed: PackedVector2Array = PackedVector2Array()
var _phase: PackedVector2Array = PackedVector2Array()
var _area: Rect2 = Rect2()
var _rise: float = 0.0
var _alpha: float = 1.0
var _color: Color = Color.WHITE


func setup(spec: Dictionary) -> void:
	var raw_area: Array = spec.get("area", [0, 0, 1080, 1920]) as Array
	_area = Rect2(float(raw_area[0]), float(raw_area[1]), float(raw_area[2]), float(raw_area[3]))
	_rise = float(spec.get("rise", 0.0))
	_alpha = float(spec.get("alpha", 0.6))
	_color = Color.html(String(spec.get("color", "#ffffff")))
	var radius_range: Array = spec.get("radius", [8.0, 12.0]) as Array
	var additive: bool = bool(spec.get("additive", false))
	var texture: Texture2D = GlowTextures.disc() if String(spec.get("texture", "dot")) == "disc" else GlowTextures.dot()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED + int(spec.get("count", 0))
	for index: int in range(int(spec.get("count", 0))):
		var mote: Sprite2D = GlowTextures.make_sprite(texture, rng.randf_range(float(radius_range[0]), float(radius_range[1])), additive)
		mote.visible = false
		add_child(mote)
		_motes.append(mote)
		_anchor.append(_area.position + Vector2(rng.randf() * _area.size.x, rng.randf() * _area.size.y))
		_radius.append(Vector2(rng.randf_range(WANDER_MIN, WANDER_MAX), rng.randf_range(WANDER_MIN, WANDER_MAX) * 0.6))
		_speed.append(Vector2(rng.randf_range(SPEED_MIN, SPEED_MAX), rng.randf_range(SPEED_MIN, SPEED_MAX)))
		_phase.append(Vector2(rng.randf() * TAU, rng.randf_range(BLINK_MIN, BLINK_MAX)))


func step(time: float, delta: float, wind: float, amount: float) -> void:
	var on: bool = amount > 0.01
	if visible != on:
		visible = on
	if not on:
		return
	for index: int in range(_motes.size()):
		var mote: Sprite2D = _motes[index]
		if not mote.visible:
			mote.visible = true
		var anchor: Vector2 = _anchor[index]
		anchor.y -= _rise * delta
		anchor.x += wind * delta
		if anchor.y < _area.position.y:
			anchor.y = _area.end.y
		if anchor.x > _area.end.x:
			anchor.x -= _area.size.x
		_anchor[index] = anchor
		var phase: Vector2 = _phase[index]
		mote.position = Vector2(anchor.x + sin(time * _speed[index].x + phase.x) * _radius[index].x,
			anchor.y + cos(time * _speed[index].y + phase.x) * _radius[index].y)
		var blink: float = 0.6 + 0.4 * sin(time * phase.y + phase.x)
		mote.modulate = Color(_color.r, _color.g, _color.b, _alpha * blink * minf(amount, 1.0))
