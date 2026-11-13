class_name DayLook
extends RefCounted

## Bir günün "görünümü": gökyüzü, tonlar, güneş/ay, yıldız vb. Tek bir aşamayı ya da iki
## aşama arası karışımı tutar. Neden ayrı sınıf: geçiş (crossfade) her karede çalışır; alanları
## yerinde (in-place) karıştırarak kare başına bellek ayırmayı önlüyoruz.

## Gölge (storm) rengi koyulaşırken kullanılmaz; sadece veri taşır.
var phase_name: String = "morning"
var ambience: String = "birds"
var sky_top: Color = Color("9ad9ff")
var sky_bottom: Color = Color("f1faea")
var scenery_tint: Color = Color.WHITE
var cloud_tint: Color = Color.WHITE
var garment_tint: Color = Color.WHITE
var sun_color: Color = Color("fff2b8")
var sun_pos: Vector2 = Vector2(290.0, 240.0)
var sun_alpha: float = 0.9
var sun_size: float = 1.0
var sun_haze: float = 0.0
var moon_color: Color = Color("f6f2dc")
var moon_pos: Vector2 = Vector2(740.0, 150.0)
var moon_alpha: float = 0.0
var star_amount: float = 0.0
var firefly_amount: float = 0.0
var window_glow: float = 0.0
var storm_dim: float = 1.0


## JSON'daki bir aşama sözlüğünden görünüm üretir. Eksik alanlar varsayılan kalır.
static func from_dict(data: Dictionary) -> DayLook:
	var look: DayLook = DayLook.new()
	look.phase_name = String(data.get("name", look.phase_name))
	look.ambience = String(data.get("ambience", look.ambience))
	look.sky_top = _color(data, "sky_top", look.sky_top)
	look.sky_bottom = _color(data, "sky_bottom", look.sky_bottom)
	look.scenery_tint = _color(data, "scenery_tint", look.scenery_tint)
	look.cloud_tint = _color(data, "cloud_tint", look.cloud_tint)
	look.garment_tint = _color(data, "garment_tint", look.garment_tint)
	look.sun_color = _color(data, "sun_color", look.sun_color)
	look.moon_color = _color(data, "moon_color", look.moon_color)
	look.sun_pos = _vector(data, "sun_pos", look.sun_pos)
	look.moon_pos = _vector(data, "moon_pos", look.moon_pos)
	look.sun_alpha = float(data.get("sun_alpha", look.sun_alpha))
	look.sun_size = float(data.get("sun_size", look.sun_size))
	look.sun_haze = float(data.get("sun_haze", look.sun_haze))
	look.moon_alpha = float(data.get("moon_alpha", look.moon_alpha))
	look.star_amount = float(data.get("stars", look.star_amount))
	look.firefly_amount = float(data.get("fireflies", look.firefly_amount))
	look.window_glow = float(data.get("windows", look.window_glow))
	look.storm_dim = float(data.get("storm_dim", look.storm_dim))
	return look


static func _color(data: Dictionary, key: String, fallback: Color) -> Color:
	if not data.has(key):
		return fallback
	return Color.html(String(data[key]))


static func _vector(data: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var raw: Variant = data.get(key, null)
	if raw is Array and (raw as Array).size() >= 2:
		return Vector2(float((raw as Array)[0]), float((raw as Array)[1]))
	return fallback


## `from` ile `to` arasını t (0..1) ile bu nesnenin içine yazar; yeni nesne üretmez.
func blend(from: DayLook, to: DayLook, t: float) -> void:
	sky_top = from.sky_top.lerp(to.sky_top, t)
	sky_bottom = from.sky_bottom.lerp(to.sky_bottom, t)
	scenery_tint = from.scenery_tint.lerp(to.scenery_tint, t)
	cloud_tint = from.cloud_tint.lerp(to.cloud_tint, t)
	garment_tint = from.garment_tint.lerp(to.garment_tint, t)
	sun_color = from.sun_color.lerp(to.sun_color, t)
	moon_color = from.moon_color.lerp(to.moon_color, t)
	sun_pos = from.sun_pos.lerp(to.sun_pos, t)
	moon_pos = from.moon_pos.lerp(to.moon_pos, t)
	sun_alpha = lerpf(from.sun_alpha, to.sun_alpha, t)
	sun_size = lerpf(from.sun_size, to.sun_size, t)
	sun_haze = lerpf(from.sun_haze, to.sun_haze, t)
	moon_alpha = lerpf(from.moon_alpha, to.moon_alpha, t)
	star_amount = lerpf(from.star_amount, to.star_amount, t)
	firefly_amount = lerpf(from.firefly_amount, to.firefly_amount, t)
	window_glow = lerpf(from.window_glow, to.window_glow, t)
	storm_dim = lerpf(from.storm_dim, to.storm_dim, t)
	phase_name = to.phase_name if t >= 0.5 else from.phase_name
	ambience = to.ambience if t >= 0.5 else from.ambience


## Başka bir görünümü olduğu gibi kopyalar (geçişin başlangıç anı için).
func copy_from(other: DayLook) -> void:
	blend(other, other, 0.0)
