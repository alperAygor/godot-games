class_name IconButton
extends Button
## Küçük, minimal ikon düğmesi. İki yerleşim:
## - dikey (varsayılan): ikon üstte, küçük etiket altta (araç çubuğu, menü kısayolları);
## - satır içi (`inline_layout`): ikon solda, metin sağda (geri, paylaş, reklam).
## `text` erişilebilirlik/testler için tam metin olarak durur; ekranda `label_text` (varsa, kısa) ya da `text` çizilir.
## Açık/kapalı (toggle) düğmeler basılıyken dolgulu daire içinde görünür. `locked` kilit işareti ve soluk renk verir.

@export var glyph := "":  # (Button.icon ile çakışmasın diye "glyph")
	set(value):
		glyph = value
		queue_redraw()
@export var label_text := ""
@export var inline_layout := false
@export var round_frame := true
@export var accent := Color("2E5B8A")
@export var ink := Color("2B2A33")
@export var light_on_dark := false
## Satır içi düğmede ince yuvarlak çerçeve (ana eylem olmayan ikincil düğmeler için).
@export var framed := true
## Sağ üst köşede kırmızı sayı rozeti (0 = yok); okunmamış not gibi.
var badge := 0:
	set(value):
		badge = value
		queue_redraw()
var _frame_style := StyleBoxFlat.new()
var locked := false:
	set(value):
		locked = value
		queue_redraw()


func _init() -> void:
	flat = true
	clip_text = true  # Button metne göre genişlemesin: etiketi kendimiz çiziyoruz (satır içinde sığacak kadar küçültülür)
	focus_mode = Control.FOCUS_NONE
	_frame_style.bg_color = Color(0, 0, 0, 0)
	_frame_style.set_border_width_all(2)
	_frame_style.set_corner_radius_all(0)  # piksel görünümü: keskin köşe
	for state in ["font_color", "font_pressed_color", "font_hover_color", "font_focus_color", "font_disabled_color", "font_hover_pressed_color"]:
		add_theme_color_override(state, Color(0, 0, 0, 0))


## Satır içi düğme kısa metinde alt genişlik ister; yan yana dizilen düğmelerde kapatılır (yazı sığacak kadar küçülür).
var fit_minimum := true


func _ready() -> void:
	if inline_layout and fit_minimum:
		# Metin kırpıldığı için düğme kendiliğinden genişlemez: kısa metinler tam görünsün diye (uzunlar küçülür) alt sınır koy.
		var shown := label_text if not label_text.is_empty() else text
		var natural := get_theme_default_font().get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x + 34.0 + 12.0 + 44.0
		custom_minimum_size.x = maxf(custom_minimum_size.x, minf(natural, 320.0))


func _text_color() -> Color:
	var base := Color("F5EEDC") if light_on_dark else ink
	return Color(base, 0.4) if (disabled or locked) else base


func _draw() -> void:
	var font := get_theme_default_font()
	var color := _text_color()
	var pressed_look := button_pressed or get_draw_mode() == DRAW_PRESSED or get_draw_mode() == DRAW_HOVER_PRESSED
	var shown_label := label_text if not label_text.is_empty() else text
	if inline_layout:
		var icon_size := minf(size.y * 0.5, 34.0)
		var gap := 12.0
		var font_size := 32
		while font_size > 20 and font.get_string_size(shown_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > size.x - icon_size - gap - 36.0:
			font_size -= 1
		var text_width := font.get_string_size(shown_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var total := icon_size + gap + text_width
		var left := (size.x - total) / 2.0
		if framed:
			_frame_style.border_color = Color(color, 0.45 if not pressed_look else 0.9)
			_frame_style.bg_color = Color(color, 0.1) if pressed_look else Color(0, 0, 0, 0)
			draw_style_box(_frame_style, Rect2(Vector2.ZERO, size))
		elif pressed_look:
			draw_rect(Rect2(Vector2.ZERO, size), Color(color, 0.08))
		Icons.draw_on(self, glyph, Rect2(Vector2(left, (size.y - icon_size) / 2.0), Vector2(icon_size, icon_size)), color, 2.4)
		draw_string(font, Vector2(left + icon_size + gap, size.y / 2.0 + font_size * 0.35), shown_label, HORIZONTAL_ALIGNMENT_LEFT, text_width + 4.0, font_size, color)
		_draw_badge(font)
		return
	var diameter := minf(size.x, size.y - (22.0 if not shown_label.is_empty() else 0.0)) * 0.86
	var center := Vector2(size.x / 2.0, diameter / 2.0 + 4.0)
	if round_frame:  # (adı eski; şimdi keskin kare çerçeve: piksel görünümü)
		var frame := Rect2(center - Vector2(diameter, diameter) / 2.0, Vector2(diameter, diameter))
		if pressed_look:
			draw_rect(frame, Color(accent, 0.95))
			draw_rect(frame, Color("14120E"), false, 3.0)
		else:
			draw_rect(frame, Color(color, 0.08))
			draw_rect(frame, Color(color, 0.55), false, 2.0)
	var icon_color := Color("F5EEDC") if pressed_look and round_frame else color
	Icons.draw_on(self, glyph, Rect2(center - Vector2(diameter, diameter) * 0.3, Vector2(diameter, diameter) * 0.6), icon_color, 2.4)
	if locked:
		Icons.draw_on(self, "lock", Rect2(center + Vector2(diameter, diameter) * 0.16, Vector2(diameter, diameter) * 0.34), Color(ink, 0.8), 1.8)
	if not shown_label.is_empty():
		var label_size := 24
		draw_string(font, Vector2(0, size.y - 4.0), shown_label, HORIZONTAL_ALIGNMENT_CENTER, size.x, label_size, color)
	_draw_badge(font)


func _draw_badge(font: Font) -> void:
	if badge <= 0:
		return
	var center := Vector2(size.x - 12.0, 12.0)
	draw_circle(center, 11.0, Color("C03A2B"))
	draw_circle(center, 11.0, Color("F5EEDC"), false, 1.5)
	draw_string(font, center + Vector2(-20.0, 5.0), str(mini(badge, 9)), HORIZONTAL_ALIGNMENT_CENTER, 40.0, 20, Color("F5EEDC"))
