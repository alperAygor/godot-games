extends RefCounted
class_name ArenaSpace
## 2B oyun koordinatı (piksel) ↔ 3B dünya koordinatı (birim). Mantık 2B kalır, görüntü 3B olur.

const SCALE := 40.0
const ORIGIN := Vector2(1320.0, 840.0)
const HALF_EXTENT := Vector2(32.0, 20.0)
const ARENA_RECT := Rect2(40.0, 40.0, 2560.0, 1600.0)

static func to_world(p: Vector2, y := 0.0) -> Vector3:
	return Vector3((p.x - ORIGIN.x) / SCALE, y, (p.y - ORIGIN.y) / SCALE)

static func to_plane(p: Vector3) -> Vector2:
	return Vector2(p.x * SCALE + ORIGIN.x, p.z * SCALE + ORIGIN.y)

static func dir_to_world(d: Vector2) -> Vector3:
	return Vector3(d.x, 0.0, d.y).normalized()
