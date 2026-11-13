class_name WindowLights
extends Node2D

## Uzak evlerin pencerelerinde yanan sıcak ışıklar (alacakaranlık/gece). Konumlar bg_far.png
## piksel koordinatıdır; üst düğüm uzak katmanın konumunu izler (parallaks ile birlikte kayar).

## bg_far.png içindeki pencere merkezleri (kırmızı, turuncu, mavi ev).
const WINDOWS: Array[Vector2] = [Vector2(259.0, 304.0), Vector2(573.0, 294.0), Vector2(873.0, 234.0)]
const PANE_RADIUS: float = 7.0
const HALO_RADIUS: float = 34.0
const PANE_COLOR: Color = Color(1.0, 0.74, 0.3)
const HALO_COLOR: Color = Color(1.0, 0.6, 0.22)
const HALO_ALPHA: float = 0.6
const FLICKER_SPEED: float = 1.3
const FLICKER_DEPTH: float = 0.08
const VISIBLE_EPSILON: float = 0.01

var _panes: Array[Sprite2D] = []
var _halos: Array[Sprite2D] = []


func setup() -> void:
	for window: Vector2 in WINDOWS:
		var halo: Sprite2D = GlowTextures.make_sprite(GlowTextures.halo(), HALO_RADIUS, true)
		halo.position = window
		add_child(halo)
		_halos.append(halo)
		# Cam normal karışımla çizilir: toplamalı olsaydı beyaza doyar, pencere değil nokta gibi görünürdü.
		var pane: Sprite2D = GlowTextures.make_sprite(GlowTextures.disc(), PANE_RADIUS, false)
		pane.position = window
		add_child(pane)
		_panes.append(pane)


func apply(glow: float, time: float) -> void:
	var on: bool = glow > VISIBLE_EPSILON
	visible = on
	if not on:
		return
	for index: int in range(_panes.size()):
		# Çok hafif titreşim: mum/lamba ışığı gibi canlı, ama dikkat dağıtmaz.
		var flicker: float = 1.0 - FLICKER_DEPTH * (0.5 + 0.5 * sin(time * FLICKER_SPEED + float(index) * 2.1))
		_panes[index].modulate = Color(PANE_COLOR.r, PANE_COLOR.g, PANE_COLOR.b, glow * flicker)
		_halos[index].modulate = Color(HALO_COLOR.r, HALO_COLOR.g, HALO_COLOR.b, glow * flicker * HALO_ALPHA)
