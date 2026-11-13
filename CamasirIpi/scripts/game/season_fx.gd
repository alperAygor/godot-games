class_name SeasonFx
extends Node2D

## Mevsim ortam efektleri (yalnız manzara; çamaşırın ARKASINDA, arka plan katmanında):
## yaz kelebek + karahindiba tohumu, sonbahar düşen yapraklar, kış iki derinlikte kar + zemin sisi,
## ilkbahar uçuşan taç yaprakları + polen. Veri data/seasons.json "fx"ten gelir (SeasonLook).
## Ucuz: her mevsim birkaç düzine yumuşak sprite; kare başına yalnız konum/ölçek yazılır.
## Mevsim değişince eski grup sönerken yenisi belirir; eski grup (ve dokuları) sonra atılır.
## Fırtına: yağış yoğunlaşır ve rüzgârla yatar, kelebek/polen saklanır; mevcut fırtına okunur kalır.

## Fırtınada yatay rüzgâr (px/sn) ve düşüş hızı artışı.
const STORM_WIND: float = 150.0
const STORM_FALL: float = 0.9
## Fırtınada görünen parça oranı artışı (havuzdaki yedekler).
const STORM_EXTRA: float = 0.6
## Efektler sahne tonunu bu oranda alır: gece kar ve yaprak da maviye çalar, ama sönük görünmez.
const TINT_SHARE: float = 0.55
## Gündüz canlıları (kelebek, polen, tohum) güneş parlaklığına göre görünür.
const DAYLIGHT_FULL: float = 0.6

var _group: SeasonGroup = null
var _old: SeasonGroup = null
var _fade: float = 1.0
var _fade_seconds: float = 2.4


## Bir mevsimin tüm efekt katmanları; sönme/belirme ağırlığı grup modulate'iyle verilir.
class SeasonGroup extends Node2D:
	var season: String = ""
	var falling: Array[SeasonFalling] = []
	var motes: SeasonMotes = null
	var butterflies: SeasonButterflies = null
	var haze: SeasonHaze = null

	func build(id: String, spec: Dictionary) -> void:
		season = id
		for raw: Variant in (spec.get("falling", []) as Array):
			var layer_spec: Dictionary = raw as Dictionary
			var textures: Array[Texture2D] = _textures(layer_spec)
			if textures.is_empty():
				continue
			var layer: SeasonFalling = SeasonFalling.new()
			add_child(layer)
			layer.setup(layer_spec, textures)
			falling.append(layer)
		if spec.has("haze"):
			haze = SeasonHaze.new()
			add_child(haze)
			haze.setup(spec["haze"] as Dictionary)
		if spec.has("motes"):
			motes = SeasonMotes.new()
			add_child(motes)
			motes.setup(spec["motes"] as Dictionary)
		if spec.has("butterflies"):
			butterflies = SeasonButterflies.new()
			add_child(butterflies)
			butterflies.setup(spec["butterflies"] as Dictionary)

	func step(time: float, delta: float, storm: float, daylight: float) -> void:
		var wind: float = storm * STORM_WIND
		var speed: float = 1.0 + storm * STORM_FALL
		var amount: float = 1.0 + storm * STORM_EXTRA
		for layer: SeasonFalling in falling:
			layer.step(time, delta, wind, speed, amount)
		if haze != null:
			haze.step(time, 1.0 + storm * 0.5)
		var calm_day: float = daylight * (1.0 - storm)
		if motes != null:
			motes.step(time, delta, wind * 0.5, calm_day)
		if butterflies != null:
			butterflies.step(time, calm_day)

	static func _textures(spec: Dictionary) -> Array[Texture2D]:
		var out: Array[Texture2D] = []
		match String(spec.get("texture", "")):
			"disc":
				out.append(GlowTextures.disc())
			"dot":
				out.append(GlowTextures.dot())
		for raw: Variant in (spec.get("textures", []) as Array):
			var texture: Texture2D = load(String(raw)) as Texture2D
			if texture != null:
				out.append(texture)
		return out


func set_fade_seconds(seconds: float) -> void:
	_fade_seconds = maxf(seconds, 0.01)


## Mevsimi ayarlar. `instant`: geçişsiz (ilk kurulum). Aynı mevsim tekrarı bir şey yapmaz.
func set_season(season: String, instant: bool) -> void:
	if _group != null and _group.season == season:
		return
	if _old != null:
		_old.queue_free()
		_old = null
	if _group != null:
		if instant:
			_group.queue_free()
		else:
			_old = _group
	_group = SeasonGroup.new()
	add_child(_group)
	_group.build(season, SeasonLook.fx_spec(season))
	_fade = 1.0 if instant or _old == null else 0.0
	_group.modulate.a = _fade


func season() -> String:
	return _group.season if _group != null else ""


func apply(look: DayLook, storm: float, time: float, delta: float) -> void:
	if _group == null:
		return
	var tint: Color = Color.WHITE.lerp(look.scenery_tint, TINT_SHARE)
	var daylight: float = clampf(look.sun_alpha / DAYLIGHT_FULL, 0.0, 1.0)
	if _fade < 1.0:
		_fade = minf(_fade + delta / _fade_seconds, 1.0)
		if _old != null:
			_old.modulate = Color(tint.r, tint.g, tint.b, 1.0 - _fade)
			_old.step(time, delta, storm, daylight)
			if _fade >= 1.0:
				_old.queue_free()
				_old = null
	_group.modulate = Color(tint.r, tint.g, tint.b, _fade)
	_group.step(time, delta, storm, daylight)
