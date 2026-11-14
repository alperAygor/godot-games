class_name Glow
extends RefCounted
## Yumuşak ışık lekesi: tek bir radyal degrade dokusu. Üst üste dizilen şeffaf daireler yerine kullanılır (her biri ekranı
## ayrı ayrı doldurup mobil GPU'da "overdraw" yaratıyordu); tek dörtgen çizilir, bantlanma da olmaz. Doku küçüktür (128 px) ve
## çizilirken büyütülür. Önbellek tutulmaz: sahip düğüm referansı taşır, düğüm gidince doku da gider.


## `peak_alpha` merkezdeki saydamlık, kenarda 0.
static func texture(tint: Color, peak_alpha: float) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([Color(tint, peak_alpha), Color(tint, peak_alpha * 0.35), Color(tint, 0.0)])
	var result := GradientTexture2D.new()
	result.gradient = gradient
	result.fill = GradientTexture2D.FILL_RADIAL
	result.fill_from = Vector2(0.5, 0.5)
	result.fill_to = Vector2(1.0, 0.5)
	result.width = 128
	result.height = 128
	return result
