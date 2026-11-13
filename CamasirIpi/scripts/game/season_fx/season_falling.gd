class_name SeasonFalling
extends Node2D

## Yavaşça düşen mevsim parçacıkları: sonbahar yaprağı, ilkbahar taç yaprağı, kar tanesi.
## Az sayıda sprite; konumlar kare başında yerinde güncellenir (bellek ayırma yok). Ekranın altından
## çıkan parça üstten, kayık bir x ile yeniden girer. Rüzgâr (fırtına) yatay sürüklenmeyi ve düşüş
## hızını artırır; `amount` > 1 iken havuzdaki yedek parçalar da görünür (fırtınada daha yoğun kar).

## Fırtınada gösterilebilecek ek parça oranı (havuz bu kadar büyük kurulur).
const POOL_EXTRA: float = 0.6
## Takla: yaprak dönerken yassılaşır (kartın kenarı görünür); en ince hâli bu oran.
const FLUTTER_MIN: float = 0.3
## Yeniden girişte x kaydırması (altın oran): parçalar aynı sütunda tekrar etmez, rastgele gibi dağılır.
const RESPAWN_STEP: float = 0.618034

var _sprites: Array[Sprite2D] = []
var _pos: PackedVector2Array = PackedVector2Array()
var _fall: PackedFloat32Array = PackedFloat32Array()
var _sway: PackedFloat32Array = PackedFloat32Array()
var _sway_speed: PackedFloat32Array = PackedFloat32Array()
var _phase: PackedFloat32Array = PackedFloat32Array()
var _spin: PackedFloat32Array = PackedFloat32Array()
var _base_scale: PackedFloat32Array = PackedFloat32Array()
var _area: Rect2 = Rect2(0.0, 0.0, 1080.0, 1920.0)
var _count: int = 0
var _flutter: float = 0.0
var _drift: float = 0.0


func setup(spec: Dictionary, textures: Array[Texture2D]) -> void:
	var raw_area: Array = spec.get("area", [0, 0, 1080, 1920]) as Array
	_area = Rect2(float(raw_area[0]), float(raw_area[1]), float(raw_area[2]), float(raw_area[3]))
	_count = int(spec.get("count", 0))
	_flutter = float(spec.get("flutter", 0.0))
	_drift = float(spec.get("drift", 0.0))
	var size: Vector2 = _pair(spec, "size", Vector2(20.0, 30.0))
	var fall: Vector2 = _pair(spec, "fall", Vector2(30.0, 50.0))
	var sway: Vector2 = _pair(spec, "sway", Vector2(20.0, 40.0))
	var sway_speed: Vector2 = _pair(spec, "sway_speed", Vector2(0.5, 1.0))
	var spin: Vector2 = _pair(spec, "spin", Vector2.ZERO)
	var colors: Array = spec.get("colors", ["#ffffff"]) as Array
	var alpha: float = float(spec.get("alpha", 1.0))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(spec.get("seed", 1))
	var pool: int = ceili(float(_count) * (1.0 + POOL_EXTRA))
	for index: int in range(pool):
		var texture: Texture2D = textures[index % textures.size()]
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = texture
		var color: Color = Color.html(String(colors[index % colors.size()]))
		sprite.modulate = Color(color.r, color.g, color.b, alpha)
		var scale_value: float = rng.randf_range(size.x, size.y) / maxf(texture.get_size().x, 1.0)
		sprite.scale = Vector2.ONE * scale_value
		sprite.visible = false
		add_child(sprite)
		_sprites.append(sprite)
		_base_scale.append(scale_value)
		_pos.append(_area.position + Vector2(rng.randf() * _area.size.x, rng.randf() * _area.size.y))
		# Büyük (yakın) parça daha hızlı düşer: derinlik hissi.
		var depth: float = inverse_lerp(size.x, maxf(size.y, size.x + 0.001), scale_value * texture.get_size().x)
		_fall.append(lerpf(fall.x, fall.y, clampf(depth * 0.6 + rng.randf() * 0.4, 0.0, 1.0)))
		_sway.append(rng.randf_range(sway.x, sway.y))
		_sway_speed.append(rng.randf_range(sway_speed.x, sway_speed.y))
		_phase.append(rng.randf() * TAU)
		_spin.append(rng.randf_range(spin.x, spin.y) * (1.0 if rng.randf() < 0.5 else -1.0))


## `wind` px/sn yatay sürüklenme (fırtına), `speed` düşüş çarpanı, `amount` görünür oran (1 = veri sayısı).
func step(time: float, delta: float, wind: float, speed: float, amount: float) -> void:
	var shown: int = mini(ceili(float(_count) * maxf(amount, 0.0)), _sprites.size())
	for index: int in range(_sprites.size()):
		var sprite: Sprite2D = _sprites[index]
		var on: bool = index < shown
		if sprite.visible != on:
			sprite.visible = on
		if not on:
			continue
		var pos: Vector2 = _pos[index]
		pos.y += _fall[index] * speed * delta
		pos.x += (_drift + wind) * delta
		if pos.y > _area.end.y:
			pos.y = _area.position.y
			pos.x = _area.position.x + fposmod(pos.x - _area.position.x + _area.size.x * RESPAWN_STEP, _area.size.x)
		if pos.x > _area.end.x:
			pos.x -= _area.size.x
		elif pos.x < _area.position.x:
			pos.x += _area.size.x
		_pos[index] = pos
		var wave: float = time * _sway_speed[index] + _phase[index]
		sprite.position = Vector2(pos.x + sin(wave) * _sway[index], pos.y)
		if _spin[index] != 0.0:
			# Salınımla birlikte yatar: yaprak sağa giderken o yana eğilir (sarkaç gibi süzülme).
			sprite.rotation = time * _spin[index] * 0.35 + cos(wave) * 0.6
		if _flutter > 0.0:
			var flat: float = FLUTTER_MIN + (1.0 - FLUTTER_MIN) * absf(cos(wave * 1.3 + _phase[index]))
			sprite.scale = Vector2(_base_scale[index] * lerpf(1.0, flat, _flutter), _base_scale[index])


static func _pair(spec: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var raw: Variant = spec.get(key, null)
	if raw is Array and (raw as Array).size() >= 2:
		return Vector2(float((raw as Array)[0]), float((raw as Array)[1]))
	return fallback
