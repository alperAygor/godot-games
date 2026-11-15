class_name ThemeVariants
extends RefCounted
## Ana temadan (assets/theme/main_theme.tres, tools/build_theme.py üretir) erişilebilirlik türevi üretir: yazı boyutu çarpanı ve
## renk körü paleti. Taban tema DEĞİŞMEZ (kopya üzerinde çalışılır); ikisi de kapalıysa taban temanın kendisi döner.
## Kodla verilen sabit yazı boyutları ve `_draw` yazıları temayla ölçeklenmez; onlar `A11y.scaled()` ile kendileri ölçeklenir.


static func build(base: Theme, text_size: Variant, color_blind: bool) -> Theme:
	var scale := Accessibility.text_scale(text_size)
	if is_equal_approx(scale, 1.0) and not color_blind:
		return base
	var out := Theme.new()
	out.merge_with(base)
	out.default_base_scale = base.default_base_scale
	out.default_font = base.default_font
	out.default_font_size = maxi(1, roundi(base.default_font_size * scale)) if base.default_font_size > 0 else base.default_font_size
	if not is_equal_approx(scale, 1.0):
		for type: StringName in out.get_font_size_type_list():
			for item: StringName in out.get_font_size_list(type):
				out.set_font_size(item, type, maxi(1, roundi(out.get_font_size(item, type) * scale)))
	if color_blind:
		_adapt_colors(out)
	return out


static func _adapt_colors(theme: Theme) -> void:
	for type: StringName in theme.get_color_type_list():
		for item: StringName in theme.get_color_list(type):
			theme.set_color(item, type, Accessibility.adapt(theme.get_color(item, type), true))
	var copies := {}  # aynı StyleBox birden çok yerde paylaşılır: bir kez kopyala
	for type: StringName in theme.get_stylebox_type_list():
		for item: StringName in theme.get_stylebox_list(type):
			var box := theme.get_stylebox(item, type)
			if not (box is StyleBoxFlat):
				continue
			if not copies.has(box):
				var copy := (box as StyleBoxFlat).duplicate() as StyleBoxFlat
				copy.bg_color = Accessibility.adapt(copy.bg_color, true)
				copy.border_color = Accessibility.adapt(copy.border_color, true)
				copies[box] = copy
			theme.set_stylebox(item, type, copies[box])
