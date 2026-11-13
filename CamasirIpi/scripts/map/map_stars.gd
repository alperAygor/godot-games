class_name MapStars
extends Control

## Küçük yıldız sırası (kartta): kazanılanlar altın, kalanlar sönük. Düz çokgenler, çizgisiz.

const SIZE_PIXELS: float = 76.0
const GAP: float = 26.0

var earned: int = 0


func setup(earned_stars: int) -> void:
	earned = earned_stars
	custom_minimum_size = Vector2(SIZE_PIXELS * 3.0 + GAP * 2.0, SIZE_PIXELS)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	for index: int in range(StarRating.MAX_STARS):
		var center: Vector2 = Vector2(SIZE_PIXELS * 0.5 + float(index) * (SIZE_PIXELS + GAP), SIZE_PIXELS * 0.5)
		MapDraw.star(self, center, SIZE_PIXELS * 0.5, MapDraw.STAR_COLOR if index < earned else MapDraw.STAR_OFF)
