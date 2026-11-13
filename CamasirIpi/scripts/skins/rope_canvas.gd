class_name RopeCanvas
extends Node2D

## Tek bir ipi çizen küçük düğüm (ana ekrandaki süs ipi). Oyun ekranı ipleri kendi `_draw`unda
## aynı `RopePainter` ile çizer; bu sınıf yalnız ayrı bir düğümde çizmek isteyenler içindir.

var _x0: float = 0.0
var _x1: float = 0.0
var _y: float = 0.0
var _sag: float = 0.0
var _style: Dictionary = RopePainter.DEFAULT_STYLE


func setup(x0: float, x1: float, y: float, sag: float, style: Dictionary) -> void:
	_x0 = x0
	_x1 = x1
	_y = y
	_sag = sag
	_style = style
	queue_redraw()


func _draw() -> void:
	RopePainter.draw_rope(self, _x0, _x1, _y, _sag, _style)
