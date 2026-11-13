class_name SeasonHaze
extends Node2D

## Kış: zemine yakın, nefes buharı gibi çok yumuşak, yassı sis bulutları. Yavaşça yana kayar ve
## nefes alır gibi hafifçe parlayıp söner. Az sayıda (4) büyük hale sprite'ı; kare başı sin/cos.

const BREATH_SPEED: float = 0.35
const DRIFT_SPEED: float = 0.06

var _puffs: Array[Sprite2D] = []
var _base: PackedVector2Array = PackedVector2Array()
var _phase: PackedFloat32Array = PackedFloat32Array()
var _alpha: float = 0.2
var _drift: float = 20.0
var _color: Color = Color.WHITE


func setup(spec: Dictionary) -> void:
	var band: Array = spec.get("band", [1080, 1240]) as Array
	var size: Array = spec.get("size", [500.0, 150.0]) as Array
	_alpha = float(spec.get("alpha", 0.2))
	_drift = float(spec.get("drift", 20.0))
	_color = Color.html(String(spec.get("color", "#ffffff")))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(spec.get("seed", 1))
	var count: int = int(spec.get("count", 0))
	for index: int in range(count):
		# Normal karışım: toplamalı olsaydı soluk zeminde beyaza doyar, sis değil leke gibi görünürdü.
		var puff: Sprite2D = GlowTextures.make_sprite(GlowTextures.halo(), 1.0, false)
		puff.scale = Vector2(float(size[0]), float(size[1])) * rng.randf_range(0.8, 1.15) / GlowTextures.RADIUS
		add_child(puff)
		_puffs.append(puff)
		var x: float = (float(index) + 0.5) / float(maxi(count, 1)) * 1080.0 + rng.randf_range(-80.0, 80.0)
		_base.append(Vector2(x, rng.randf_range(float(band[0]), float(band[1]))))
		_phase.append(rng.randf() * TAU)


func step(time: float, amount: float) -> void:
	var on: bool = amount > 0.01
	if visible != on:
		visible = on
	if not on:
		return
	for index: int in range(_puffs.size()):
		var phase: float = _phase[index]
		_puffs[index].position = _base[index] + Vector2(sin(time * DRIFT_SPEED + phase) * _drift, 0.0)
		var breath: float = 0.7 + 0.3 * sin(time * BREATH_SPEED + phase)
		_puffs[index].modulate = Color(_color.r, _color.g, _color.b, _alpha * breath * minf(amount, 1.5))
