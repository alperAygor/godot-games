class_name WatermarkShapes
extends RefCounted
## Filigran şekilleri (yıldız, daire, elmas, ay, taç, yaprak) çokgen noktaları. Banknot ve katalog aynı şekilleri çizer.

const SHAPES: Array[String] = ["star", "circle", "diamond", "moon", "crown", "leaf"]


## Verilen şeklin `center` merkezli, yaklaşık `radius` yarıçaplı çokgeni (saat yönünde).
static func points(shape: String, center: Vector2, radius: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	match shape:
		"star":
			for i in 10:
				var angle := -PI / 2.0 + i * PI / 5.0
				var r := radius if i % 2 == 0 else radius * 0.45
				result.append(center + Vector2(cos(angle), sin(angle)) * r)
		"circle":
			for i in 32:
				var angle := TAU * i / 32.0
				result.append(center + Vector2(cos(angle), sin(angle)) * radius)
		"diamond":
			result.append(center + Vector2(0, -radius))
			result.append(center + Vector2(radius * 0.7, 0))
			result.append(center + Vector2(0, radius))
			result.append(center + Vector2(-radius * 0.7, 0))
		"moon":
			# Dış daireden iç dairenin içinde kalan kısım çıkarılır (hilal).
			var inner_center := center + Vector2(radius * 0.45, 0)
			var inner_radius := radius * 0.8
			var steps := 48
			var outer: Array[Vector2] = []
			for i in steps:
				var p := center + Vector2(cos(TAU * i / steps), sin(TAU * i / steps)) * radius
				if p.distance_to(inner_center) >= inner_radius:
					outer.append(p)
			var inner: Array[Vector2] = []
			for i in steps:
				var p := inner_center + Vector2(cos(TAU * i / steps), sin(TAU * i / steps)) * inner_radius
				if p.distance_to(center) <= radius:
					inner.append(p)
			result.append_array(PackedVector2Array(outer))
			inner.reverse()
			result.append_array(PackedVector2Array(inner))
		"crown":
			result.append(center + Vector2(-radius, radius * 0.7))
			result.append(center + Vector2(-radius, -radius * 0.3))
			result.append(center + Vector2(-radius * 0.5, radius * 0.2))
			result.append(center + Vector2(0, -radius))
			result.append(center + Vector2(radius * 0.5, radius * 0.2))
			result.append(center + Vector2(radius, -radius * 0.3))
			result.append(center + Vector2(radius, radius * 0.7))
		"leaf":
			for i in 24:
				var t := TAU * i / 24.0
				result.append(center + Vector2(cos(t) * radius * 0.55, sin(t) * radius))
			result.append(center + Vector2(0, radius * 1.1))
		_:
			result.append(center)
	return result
