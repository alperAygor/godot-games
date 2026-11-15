extends RefCounted
class_name ArenaGeometry
## Engel geometrisi (saf, testli): itme, kaçınma, görüş hattı. `obstacles` = MapBuilder.obstacles
## ({"pos2": Vector2, "radius": float, ...} sözlükleri). Formüller game3d.gd'den birebir taşındı.

static func push_out(obstacles: Array[Dictionary], pos: Vector2, radius: float) -> Vector2:
	## Engelin içine girmiş noktayı en yakın kenara çıkarır.
	for o in obstacles:
		var center: Vector2 = o["pos2"]
		var min_dist: float = radius + float(o["radius"])
		var diff := pos - center
		var dist := diff.length()
		if dist < min_dist:
			if dist < 0.001:
				diff = Vector2.RIGHT
				dist = 1.0
			pos = center + diff / dist * min_dist
	return pos

static func avoid(obstacles: Array[Dictionary], pos: Vector2, radius: float) -> Vector2:
	## Yakındaki engellerden uzaklaştıran + çevresinden dolandıran yön (uzunluk ≤ 1).
	var push := Vector2.ZERO
	for o in obstacles:
		var diff: Vector2 = pos - o["pos2"]
		var dist := diff.length()
		var limit: float = float(o["radius"]) + radius + 70.0
		if dist < limit and dist > 0.01:
			# Engelin çevresinden dolan: itme + teğet bileşeni.
			var away := diff / dist
			push += (away + Vector2(-away.y, away.x) * 0.6) * (1.0 - dist / limit)
	return push.normalized() if push.length() > 1.0 else push

static func point_blocked(obstacles: Array[Dictionary], pos: Vector2, radius: float) -> bool:
	for o in obstacles:
		var r: float = radius + float(o["radius"])
		if pos.distance_squared_to(o["pos2"]) < r * r:
			return true
	return false

static func line_blocked(obstacles: Array[Dictionary], a: Vector2, b: Vector2) -> bool:
	## a→b doğru parçası bir engelin içinden geçiyor mu (4 px tolerans).
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq < 1.0:
		return false
	for o in obstacles:
		var c: Vector2 = o["pos2"]
		var t := clampf((c - a).dot(ab) / len_sq, 0.0, 1.0)
		if (a + ab * t).distance_to(c) < float(o["radius"]) - 4.0:
			return true
	return false
