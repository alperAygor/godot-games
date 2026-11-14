class_name SafeAreaContainer
extends MarginContainer
## Çocuklarını ekranın güvenli alanı içinde tutar. Her tam ekran arayüzün kök kabı bu olmalı.
## Masaüstünde güvenli alan boşluğu 0'dır. Çentik denemek için oyunu şu argümanla çalıştır:
##   -- --simulate-safe-area=88,0,68,0   (üst,sağ,alt,sol; viewport birimi)

## Güvenli alana ek olarak her kenara bırakılan boşluk (viewport birimi).
@export var extra_margin := 24.0


func _ready() -> void:
	get_viewport().size_changed.connect(_update_margins)
	_update_margins()


func current_safe_margins() -> Vector4:
	var simulated: Variant = SafeAreaMath.parse_simulated(OS.get_cmdline_user_args())
	if simulated != null:
		return simulated
	if not OS.has_feature("mobile"):
		return Vector4.ZERO
	var window_size := Vector2(DisplayServer.window_get_size())
	if window_size.y <= 0.0:
		return Vector4.ZERO
	var scale := get_viewport().get_visible_rect().size.y / window_size.y
	return SafeAreaMath.margins(
		Vector2(DisplayServer.screen_get_size()),
		Rect2(DisplayServer.get_display_safe_area()),
		scale)


func _update_margins() -> void:
	var m := current_safe_margins()
	add_theme_constant_override("margin_left", int(m.x + extra_margin))
	add_theme_constant_override("margin_top", int(m.y + extra_margin))
	add_theme_constant_override("margin_right", int(m.z + extra_margin))
	add_theme_constant_override("margin_bottom", int(m.w + extra_margin))
