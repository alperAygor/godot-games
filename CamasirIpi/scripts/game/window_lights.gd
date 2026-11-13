class_name WindowLights
extends Node2D

## Alacakaranlık/gecede yanan sıcak ışıklar: bahçede uzak ev pencereleri, sahilde kabinler ve
## deniz feneri, çatı katında ampul dizisi ve şehir pencereleri. Konumlar ait oldukları katman
## dokusunun pikselidir; düğüm o katmanın çocuğu olduğu için parallaks ile birlikte kayar.
## Kare başı maliyet sabit: ışık sayısından bağımsız olarak yalnız düğümün `modulate`'i yazılır
## (titreşim tüm grup için ortak; çok sayıda ampulde de tek yazım).

## Bahçe varsayılanı: bg_far.png içindeki pencere merkezleri (kırmızı, turuncu, mavi ev).
const WINDOWS: Array[Vector2] = [Vector2(259.0, 304.0), Vector2(573.0, 294.0), Vector2(873.0, 234.0)]
const PANE_RADIUS: float = 7.0
const HALO_RADIUS: float = 34.0
const PANE_COLOR: Color = Color(1.0, 0.74, 0.3)
const HALO_COLOR: Color = Color(1.0, 0.6, 0.22)
const HALO_ALPHA: float = 0.6
const FLICKER_SPEED: float = 1.3
const FLICKER_DEPTH: float = 0.08
const VISIBLE_EPSILON: float = 0.01

var _flicker_speed: float = FLICKER_SPEED
var _flicker_depth: float = FLICKER_DEPTH
var _phase: float = 0.0


## Geriye uyumlu kurulum: bahçe pencereleri.
func setup() -> void:
	setup_points(WINDOWS, PANE_RADIUS, HALO_RADIUS, PANE_COLOR, HALO_COLOR, FLICKER_DEPTH, FLICKER_SPEED)


## Veri sözlüğünden (data/locations.json "lights" girdisi) kurulum.
func setup_from(spec: Dictionary) -> void:
	var points: Array[Vector2] = []
	for raw: Variant in (spec.get("points", []) as Array):
		if raw is Array and (raw as Array).size() >= 2:
			points.append(Vector2(float((raw as Array)[0]), float((raw as Array)[1])))
	var pane_color: Color = Color.html(String(spec["color"])) if spec.has("color") else PANE_COLOR
	var halo_color: Color = Color.html(String(spec["halo_color"])) if spec.has("halo_color") else HALO_COLOR
	_phase = float(points.size()) * 0.7
	setup_points(points, float(spec.get("pane", PANE_RADIUS)), float(spec.get("halo", HALO_RADIUS)),
		pane_color, halo_color, float(spec.get("flicker", FLICKER_DEPTH)), float(spec.get("speed", FLICKER_SPEED)))


func setup_points(points: Array[Vector2], pane_radius: float, halo_radius: float, pane_color: Color,
		halo_color: Color, flicker_depth: float, flicker_speed: float) -> void:
	_flicker_depth = flicker_depth
	_flicker_speed = flicker_speed
	for point: Vector2 in points:
		var halo: Sprite2D = GlowTextures.make_sprite(GlowTextures.halo(), halo_radius, true)
		halo.position = point
		halo.modulate = Color(halo_color.r, halo_color.g, halo_color.b, HALO_ALPHA)
		add_child(halo)
		# Cam normal karışımla çizilir: toplamalı olsaydı beyaza doyar, pencere değil nokta gibi görünürdü.
		var pane: Sprite2D = GlowTextures.make_sprite(GlowTextures.disc(), pane_radius, false)
		pane.position = point
		pane.modulate = Color(pane_color.r, pane_color.g, pane_color.b, 1.0)
		add_child(pane)
	visible = false


func apply(glow: float, time: float) -> void:
	var on: bool = glow > VISIBLE_EPSILON
	if visible != on:
		visible = on
	if not on:
		return
	# Çok hafif titreşim: mum/lamba ışığı gibi canlı, ama dikkat dağıtmaz (fenerde derin = yanıp söner).
	var flicker: float = 1.0 - _flicker_depth * (0.5 + 0.5 * sin(time * _flicker_speed + _phase))
	modulate.a = glow * flicker
