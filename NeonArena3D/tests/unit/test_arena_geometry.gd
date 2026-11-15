extends TestCase
## Engel geometrisi (ArenaGeometry, game3d.gd'den taşındı): itme, kaçınma, nokta/çizgi engeli.

func _obs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append({"pos2": Vector2(500, 500), "radius": 60.0})
	out.append({"pos2": Vector2(900, 500), "radius": 40.0})
	return out

func test_push_out_moves_point_to_edge() -> void:
	var p := ArenaGeometry.push_out(_obs(), Vector2(520, 500), 10.0)
	near(p.distance_to(Vector2(500, 500)), 70.0, 0.001, "engel yarıçapı + nesne yarıçapı kadar dışarı")
	check(p.x > 500.0, "itme engelden uzaklaşan yönde")

func test_push_out_keeps_free_point() -> void:
	var at := Vector2(700, 300)
	eq(ArenaGeometry.push_out(_obs(), at, 10.0), at, "engelden uzak nokta değişmez")

func test_push_out_center_is_defined() -> void:
	var p := ArenaGeometry.push_out(_obs(), Vector2(500, 500), 10.0)
	near(p.x, 570.0, 0.001, "tam merkezdeki nokta sağa itilir (sıfıra bölme yok)")
	near(p.y, 500.0, 0.001, "tam merkezde y değişmez")

func test_avoid_points_away_and_is_bounded() -> void:
	var v := ArenaGeometry.avoid(_obs(), Vector2(580, 500), 15.0)
	check(v.x > 0.0, "engelin sağındaki nokta sağa itilir")
	check(v.length() <= 1.0001, "kaçınma vektörü ≤ 1")
	eq(ArenaGeometry.avoid(_obs(), Vector2(100, 100), 15.0), Vector2.ZERO, "uzaktaysa itme yok")

func test_avoid_has_tangent_component() -> void:
	var v := ArenaGeometry.avoid(_obs(), Vector2(580, 500), 15.0)
	check(absf(v.y) > 0.0, "engelin çevresinden dolanmak için teğet bileşen var")

func test_point_blocked() -> void:
	check(ArenaGeometry.point_blocked(_obs(), Vector2(540, 500), 30.0), "engel + yarıçap içinde: engelli")
	check(not ArenaGeometry.point_blocked(_obs(), Vector2(700, 500), 30.0), "iki engel arası boş")

func test_line_blocked() -> void:
	check(ArenaGeometry.line_blocked(_obs(), Vector2(300, 500), Vector2(700, 500)), "engelin içinden geçen çizgi engelli")
	check(not ArenaGeometry.line_blocked(_obs(), Vector2(300, 300), Vector2(700, 300)), "engelin yanından geçen çizgi açık")
	check(not ArenaGeometry.line_blocked(_obs(), Vector2(500, 500), Vector2(500.5, 500)), "çok kısa çizgi hiç engelli sayılmaz")

func test_empty_obstacles() -> void:
	var none: Array[Dictionary] = []
	eq(ArenaGeometry.push_out(none, Vector2(1, 2), 5.0), Vector2(1, 2), "engel yoksa itme yok")
	check(not ArenaGeometry.line_blocked(none, Vector2.ZERO, Vector2(100, 0)), "engel yoksa çizgi açık")
