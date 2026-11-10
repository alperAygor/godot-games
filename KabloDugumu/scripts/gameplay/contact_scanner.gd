class_name ContactScanner
extends RefCounted

## Kablo-cift temas tarayicisi. Once her kablonun segments() AABB'si ile on eleme,
## sonra CableMath.segment_distance ile cift tarama yapar. Renk filtresi UYGULAMAZ;
## ayni/farkli renk ayrimi cagiranin (game.gd) isidir.

## AABB'leri komsuluk mesafesi kadar sisir ki sinirdaki temaslar kacmasin.
const BOUNDS_MARGIN_FACTOR: float = 1.0


## cables: taranacak kablolar; contact_distance: temas esigi (metre).
## Donen ogeler: {"a": int, "b": int, "point": Vector3, "distance": float}
func scan(cables: Array[CableNode], contact_distance: float) -> Array[Dictionary]:
	var contacts: Array[Dictionary] = []
	if contact_distance <= 0.0 or cables.size() < 2:
		return contacts
	var segments: Array[PackedVector3Array] = []
	var bounds: Array[AABB] = []
	for cable: CableNode in cables:
		var cable_segments: PackedVector3Array = PackedVector3Array()
		if cable != null and is_instance_valid(cable):
			cable_segments = cable.segments()
		segments.append(cable_segments)
		bounds.append(_segments_bounds(cable_segments))
	var margin: float = contact_distance * BOUNDS_MARGIN_FACTOR
	for a: int in cables.size() - 1:
		if segments[a].size() < 2:
			continue
		var expanded: AABB = bounds[a].grow(margin)
		for b: int in range(a + 1, cables.size()):
			if segments[b].size() < 2:
				continue
			if not expanded.intersects(bounds[b]):
				continue
			var pair: Dictionary = _closest_pair(segments[a], segments[b], contact_distance)
			if pair.is_empty():
				continue
			pair["a"] = a
			pair["b"] = b
			contacts.append(pair)
	return contacts


func _segments_bounds(segments: PackedVector3Array) -> AABB:
	if segments.is_empty():
		return AABB()
	var bounds: AABB = AABB(segments[0], Vector3.ZERO)
	for i: int in range(1, segments.size()):
		bounds = bounds.expand(segments[i])
	return bounds


## Iki polyline'in temas esiginden yakin ilk ciftini bulur; kontak noktasi
## en yakin iki segmentin en yakin noktalar arasindaki orta noktadir.
func _closest_pair(first: PackedVector3Array, second: PackedVector3Array,
		contact_distance: float) -> Dictionary:
	var best_distance: float = INF
	var best_point: Vector3 = Vector3.ZERO
	for i: int in first.size() - 1:
		var a0: Vector3 = first[i]
		var a1: Vector3 = first[i + 1]
		for j: int in second.size() - 1:
			var b0: Vector3 = second[j]
			var b1: Vector3 = second[j + 1]
			var distance: float = CableMath.segment_distance(a0, a1, b0, b1)
			if distance >= best_distance:
				continue
			best_distance = distance
			best_point = _contact_midpoint(a0, a1, b0, b1)
	if best_distance > contact_distance:
		return {}
	return {"point": best_point, "distance": best_distance}


## Iki segmentin en yakin noktalarinin orta noktasi.
func _contact_midpoint(a0: Vector3, a1: Vector3, b0: Vector3, b1: Vector3) -> Vector3:
	var closest: PackedVector3Array = _closest_points(a0, a1, b0, b1)
	if closest.size() < 2:
		return (a0 + b0) * 0.5
	return (closest[0] + closest[1]) * 0.5


## Iki dogru parcasinin en yakin noktalari (CableMath.segment_distance ile ayni
## formul; orada yalnizca mesafe dondugu icin kontak noktasi icin burada).
func _closest_points(a0: Vector3, a1: Vector3, b0: Vector3, b1: Vector3) -> PackedVector3Array:
	var points: PackedVector3Array = PackedVector3Array()
	var d1: Vector3 = a1 - a0
	var d2: Vector3 = b1 - b0
	var r: Vector3 = a0 - b0
	var a: float = d1.dot(d1)
	var e: float = d2.dot(d2)
	var f: float = d2.dot(r)
	var s: float = 0.0
	var t: float = 0.0
	if a <= 0.000000001 and e <= 0.000000001:
		points.append(a0)
		points.append(b0)
		return points
	if a <= 0.000000001:
		s = 0.0
		t = clampf(f / e, 0.0, 1.0)
	else:
		var c: float = d1.dot(r)
		if e <= 0.000000001:
			t = 0.0
			s = clampf(-c / a, 0.0, 1.0)
		else:
			var b: float = d1.dot(d2)
			var denominator: float = a * e - b * b
			if absf(denominator) > 0.000000000001:
				s = clampf((b * f - c * e) / denominator, 0.0, 1.0)
			else:
				s = 0.0
			t = (b * s + f) / e
			if t < 0.0:
				t = 0.0
				s = clampf(-c / a, 0.0, 1.0)
			elif t > 1.0:
				t = 1.0
				s = clampf((b - c) / a, 0.0, 1.0)
	points.append(a0 + d1 * s)
	points.append(b0 + d2 * t)
	return points
