class_name RewardButton
extends UiIconButton
## Ödüllü reklam yerleşimine giden ikon düğmesi (ipucu, gün önizleme): disk + ikon, sağ altta küçük
## "video" rozeti (reklam izleneceğini yazısız söyler). Rozet, ödül bu seviyede alındıysa gizlenir.

var show_badge: bool = true:
	set(v):
		show_badge = v
		queue_redraw()


func _draw() -> void:
	super._draw()
	if not show_badge:
		return
	var center: Vector2 = size * 0.5 + Vector2(DISC_DIAMETER * 0.33, DISC_DIAMETER * 0.33)
	draw_circle(center, 17.0, UiKit.ACCENT, true, -1.0, true)
	var k: float = 7.0
	var tri: PackedVector2Array = PackedVector2Array([center + Vector2(-k * 0.6, -k), center + Vector2(-k * 0.6, k),
		center + Vector2(k, 0.0)])
	draw_colored_polygon(tri, Color.WHITE)
