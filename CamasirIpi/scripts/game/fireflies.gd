class_name Fireflies
extends Node2D

## Alacakaranlık/gece ateş böcekleri: az sayıda, yumuşak, toplamalı parıltı. Kare başına
## yalnızca sin/cos hesaplanır; yeni nesne üretilmez.

const COUNT: int = 12
const AREA: Rect2 = Rect2(40.0, 880.0, 1000.0, 860.0)
const WANDER_RADIUS_MIN: float = 25.0
const WANDER_RADIUS_MAX: float = 70.0
const SPEED_MIN: float = 0.25
const SPEED_MAX: float = 0.6
const GLOW_RADIUS: float = 26.0
const BLINK_SPEED_MIN: float = 0.8
const BLINK_SPEED_MAX: float = 1.8
const COLOR: Color = Color(1.0, 0.92, 0.5)
const MAX_ALPHA: float = 0.9
const SEED: int = 1907
const VISIBLE_EPSILON: float = 0.01

var _flies: Array[Sprite2D] = []
var _anchor: PackedVector2Array = PackedVector2Array()
var _radius: PackedVector2Array = PackedVector2Array()
var _speed: PackedVector2Array = PackedVector2Array()
var _phase: PackedVector2Array = PackedVector2Array()
var _blink: PackedVector2Array = PackedVector2Array()


func setup() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	for index: int in range(COUNT):
		var fly: Sprite2D = GlowTextures.make_sprite(GlowTextures.dot(), GLOW_RADIUS, true)
		add_child(fly)
		_flies.append(fly)
		_anchor.append(AREA.position + Vector2(rng.randf() * AREA.size.x, rng.randf() * AREA.size.y))
		_radius.append(Vector2(rng.randf_range(WANDER_RADIUS_MIN, WANDER_RADIUS_MAX), rng.randf_range(WANDER_RADIUS_MIN, WANDER_RADIUS_MAX)))
		_speed.append(Vector2(rng.randf_range(SPEED_MIN, SPEED_MAX), rng.randf_range(SPEED_MIN, SPEED_MAX)))
		_phase.append(Vector2(rng.randf() * TAU, rng.randf() * TAU))
		_blink.append(Vector2(rng.randf_range(BLINK_SPEED_MIN, BLINK_SPEED_MAX), rng.randf() * TAU))


func apply(amount: float, time: float) -> void:
	var on: bool = amount > VISIBLE_EPSILON
	visible = on
	if not on:
		return
	# `amount` hem görünür sayıyı hem parlaklığı belirler: alacakaranlıkta az, gecede çok.
	var shown: int = ceili(amount * float(COUNT))
	for index: int in range(COUNT):
		var fly: Sprite2D = _flies[index]
		fly.visible = index < shown
		if index >= shown:
			continue
		var anchor: Vector2 = _anchor[index]
		fly.position = Vector2(
			anchor.x + sin(time * _speed[index].x + _phase[index].x) * _radius[index].x,
			anchor.y + cos(time * _speed[index].y + _phase[index].y) * _radius[index].y)
		var blink: float = 0.5 + 0.5 * sin(time * _blink[index].x + _blink[index].y)
		fly.modulate = Color(COLOR.r, COLOR.g, COLOR.b, MAX_ALPHA * blink * minf(amount * 1.5, 1.0))
