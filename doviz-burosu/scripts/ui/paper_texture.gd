class_name PaperTexture
extends Control
## Gazete kâğıdı dokusu: çok hafif lif çizgileri ve benekler. Tohumludur (her açılışta aynı görünür) ve yalnızca bir kez çizilir.

@export var speck_count := 420
@export var seed_text := "paper"


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _draw() -> void:
	var rng := Seed.rng("paper|" + seed_text)
	for i in speck_count:
		var at := Vector2(rng.randf() * size.x, rng.randf() * size.y)
		var tone := 0.3 + rng.randf() * 0.4
		draw_circle(at, 0.6 + rng.randf() * 1.2, Color(0.35, 0.27, 0.12, 0.05 + tone * 0.06))
	for i in 70:
		var from := Vector2(rng.randf() * size.x, rng.randf() * size.y)
		draw_line(from, from + Vector2(6.0 + rng.randf() * 22.0, rng.randf() * 3.0 - 1.5), Color(0.45, 0.35, 0.18, 0.07), 1.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
