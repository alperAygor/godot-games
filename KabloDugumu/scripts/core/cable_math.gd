class_name CableMath
extends RefCounted

## Halat/temas geometrisi icin saf matematik. Sahne bilmez, test edilir.


## Iki 3D dogru parcasinin en kisa mesafesi.
static func segment_distance(a0: Vector3, a1: Vector3, b0: Vector3, b1: Vector3) -> float:
	var d1: Vector3 = a1 - a0
	var d2: Vector3 = b1 - b0
	var r: Vector3 = a0 - b0
	var a: float = d1.dot(d1)
	var e: float = d2.dot(d2)
	var f: float = d2.dot(r)
	if a <= 1e-9 and e <= 1e-9:
		return a0.distance_to(b0)
	var s: float = 0.0
	var t: float = 0.0
	if a <= 1e-9:
		s = 0.0
		t = clampf(f / e, 0.0, 1.0)
	else:
		var c: float = d1.dot(r)
		if e <= 1e-9:
			t = 0.0
			s = clampf(-c / a, 0.0, 1.0)
		else:
			var b: float = d1.dot(d2)
			var denom: float = a * e - b * b
			if absf(denom) > 1e-12:
				s = clampf((b * f - c * e) / denom, 0.0, 1.0)
			else:
				s = 0.0
			t = (b * s + f) / e
			if t < 0.0:
				t = 0.0
				s = clampf(-c / a, 0.0, 1.0)
			elif t > 1.0:
				t = 1.0
				s = clampf((b - c) / a, 0.0, 1.0)
	var p1: Vector3 = a0 + d1 * s
	var p2: Vector3 = b0 + d2 * t
	return p1.distance_to(p2)


## Iki polyline arasindaki en kisa mesafe (tum segment ciftleri).
static func polyline_distance(a: PackedVector3Array, b: PackedVector3Array) -> float:
	if a.size() < 2 or b.size() < 2:
		return INF
	var best: float = INF
	for i: int in a.size() - 1:
		var a0: Vector3 = a[i]
		var a1: Vector3 = a[i + 1]
		for j: int in b.size() - 1:
			var d: float = segment_distance(a0, a1, b[j], b[j + 1])
			if d < best:
				best = d
	return best


## Polyline'in toplam uzunlugu (2'den az noktada 0).
static func polyline_length(points: PackedVector3Array) -> float:
	var total: float = 0.0
	for i: int in points.size() - 1:
		total += points[i].distance_to(points[i + 1])
	return total


## Polyline'i esit yay uzunluguyla count noktaya ornekler (uclar korunur).
static func resample(points: PackedVector3Array, count: int) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	if points.size() == 0 or count <= 0:
		return out
	if points.size() == 1 or count <= 2:
		out.append(points[0])
		if count >= 2:
			out.append(points[points.size() - 1])
		return out
	var total: float = polyline_length(points)
	if total <= 1e-6:
		for _i: int in count:
			out.append(points[0])
		return out
	var step: float = total / float(count - 1)
	var target: float = 0.0
	var segment_index: int = 0
	var segment_start: float = 0.0
	out.append(points[0])
	for k: int in range(1, count - 1):
		target = step * float(k)
		while segment_index < points.size() - 2:
			var seg_len: float = points[segment_index].distance_to(points[segment_index + 1])
			if segment_start + seg_len >= target:
				break
			segment_start += seg_len
			segment_index += 1
		var seg_end: float = segment_start + points[segment_index].distance_to(points[segment_index + 1])
		var t: float = 0.0
		if seg_end - segment_start > 1e-9:
			t = (target - segment_start) / (seg_end - segment_start)
		out.append(points[segment_index].lerp(points[segment_index + 1], clampf(t, 0.0, 1.0)))
	out.append(points[points.size() - 1])
	return out
