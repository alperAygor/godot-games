class_name RulesHud
extends Node2D

## Seviye kipi ve rüzgâr göstergeleri: güçlendirici çubuğunun iki yanında küçük, düz haplar
## (ikon + sayı ya da renk benekleri). Kurallar `LaundryBoard` içindedir; bu sınıf yalnız
## tahtadan okunan değerleri gösterir. Düğümler bir kez kurulur; `refresh` yalnız değişeni yazar
## (kare başına üretim yok).
##  - Hamle sınırı: saat + kalan hamle (son hamlelerde kırmızı nabız: kayıp önceden görünür).
##  - Kısa askı: tişört + askı yeri sayısı.
##  - Sipariş: sırayla doldurulacak sepet renkleri; tamamlanan beneğin içi beyaz, bozulunca soluk.
##  - Patron: kupa + "1/2".
##  - Rüzgâr (sağda): rüzgâr ikonu + kalan hamle; rüzgâr bitince gizlenir.
##  - Kuş / yağmur / kedi (sağda, alt alta): sıradakine kalan hamle; kuş/kedi oradayken kalkmasına
##    kalan hamle (kırmızı). Görünen haplar sağ sütunda boşluksuz dizilir.
##  - Mevsim (sağda): yaprak (sıradaki yaprağa kalan hamle), polen (sıradaki buluta kalan hamle; ip
##    tozluyken açılmasına kalan hamle, kırmızı). Üretici bir seviyede en fazla iki sayaç hapı verir.

const PILL_Y: float = 182.0
const PILL_HEIGHT: float = 76.0
const PILL_MARGIN_X: float = 56.0
const PILL_PAD: float = 18.0
const ICON_SIZE: float = 38.0
const FONT_SIZE: int = 34
const DOT_RADIUS: float = 14.0
const DOT_GAP: float = 10.0
const DOT_CURRENT_SCALE: float = 1.25
const FILL: Color = Color(1.0, 1.0, 1.0, 0.86)
const INK: Color = Color("2a2f3d")
const URGENT: Color = Color("e5484d")
const DONE_DOT: Color = Color(1.0, 1.0, 1.0, 0.95)
const BROKEN_ALPHA: float = 0.35
const URGENT_MOVES: int = 3
const ICON_MOVES: String = "lucide/clock"
const ICON_RACK: String = "lucide/shirt"
const ICON_ORDERS: String = "lucide/check"
const ICON_BOSS: String = "lucide/trophy"
const ICON_WIND: String = "lucide/wind"
const ICON_SLIDE: String = "lucide/rotate-ccw"
const SLIDE_PILL_OFFSET_Y: float = 84.0
const ICON_BIRD: String = "res://assets/sprites/critters/icon_bird.png"
const ICON_RAIN: String = "res://assets/sprites/critters/icon_cloud.png"
const ICON_CAT: String = "res://assets/sprites/critters/icon_cat.png"

var _mode_pill: Pill = null
var _wind_pill: Pill = null
var _palette: Array[Color] = []
var _shown_moves: int = -2
var _shown_wind: int = -2
var _slide_pill: Pill = null
var _shown_slide: int = -2
var _shown_orders: Vector2i = Vector2i(-1, -1)
var _shown_screen: int = -1


func setup(screen_width: float, palette: Array[Color]) -> void:
	_palette = palette
	_mode_pill = Pill.new()
	_mode_pill.position = Vector2(PILL_MARGIN_X, PILL_Y)
	add_child(_mode_pill)
	_wind_pill = Pill.new()
	_wind_pill.align_right = true
	_wind_pill.position = Vector2(screen_width - PILL_MARGIN_X, PILL_Y)
	add_child(_wind_pill)
	_wind_pill.set_icon(Icons.texture(ICON_WIND))
	# Sürgülü ip sayacı: rüzgâr sayacının hemen altında, aynı dilde küçük bir hap.
	_slide_pill = Pill.new()
	_slide_pill.align_right = true
	_slide_pill.position = Vector2(screen_width - PILL_MARGIN_X, PILL_Y + SLIDE_PILL_OFFSET_Y)
	add_child(_slide_pill)
	_slide_pill.set_icon(Icons.texture(ICON_SLIDE))
	_slide_pill.visible = false
	_guest_pills.clear()
	for path: String in [ICON_BIRD, ICON_RAIN, ICON_CAT]:
		var pill: Pill = Pill.new()
		pill.align_right = true
		pill.position = Vector2(screen_width - PILL_MARGIN_X, PILL_Y)
		add_child(pill)
		pill.set_icon(load(path) as Texture2D if ResourceLoader.exists(path) else null)
		pill.visible = false
		_guest_pills.append(pill)
	_right_x = screen_width - PILL_MARGIN_X
	_season_pills.clear()
	for path: String in [ICON_LEAF, ICON_POLLEN]:
		var season_pill: Pill = Pill.new()
		season_pill.align_right = true
		season_pill.position = Vector2(_right_x, PILL_Y)
		add_child(season_pill)
		season_pill.set_icon(load(path) as Texture2D if ResourceLoader.exists(path) else null)
		season_pill.visible = false
		_season_pills.append(season_pill)


## Yeni seviye: kipe göre sol hap kurulur, sayaçlar sıfırlanır.
func start(board: LaundryBoard) -> void:
	_shown_moves = -2
	_shown_wind = -2
	_shown_slide = -2
	_shown_orders = Vector2i(-1, -1)
	_shown_screen = -1
	_shown_guests = [-2, -2, -2]
	_shown_season = [-2, -2]
	_mode_pill.visible = board.mode() != LaundryBoard.MODE_NONE
	_mode_pill.set_dots([] as Array[Color], 0, false)
	_mode_pill.set_urgent(false)
	match board.mode():
		LaundryBoard.MODE_MOVES:
			_mode_pill.set_icon(Icons.texture(ICON_MOVES))
		LaundryBoard.MODE_SHORT_RACK:
			_mode_pill.set_icon(Icons.texture(ICON_RACK))
			_mode_pill.set_text(str(board.rack_slots()))
		LaundryBoard.MODE_ORDERS:
			_mode_pill.set_icon(Icons.texture(ICON_ORDERS))
			_mode_pill.set_text("")
		LaundryBoard.MODE_BOSS:
			_mode_pill.set_icon(Icons.texture(ICON_BOSS))
	refresh(board)


## Tahtadan okunan değerler; yalnız değişince yazılır ve nabız atar.
func refresh(board: LaundryBoard) -> void:
	match board.mode():
		LaundryBoard.MODE_MOVES:
			var left: int = board.moves_left()
			if left != _shown_moves:
				_mode_pill.set_text(str(left))
				_mode_pill.set_urgent(left <= URGENT_MOVES)
				if _shown_moves != -2:
					_mode_pill.pulse()
				_shown_moves = left
		LaundryBoard.MODE_SHORT_RACK:
			_mode_pill.set_text(str(board.rack_slots()))
		LaundryBoard.MODE_ORDERS:
			var state: Vector2i = Vector2i(board.order_progress(), 1 if board.order_broken() else 0)
			if state != _shown_orders:
				var colors: Array[Color] = []
				for color: int in board.orders():
					colors.append(_palette[color % _palette.size()])
				_mode_pill.set_dots(colors, board.order_progress(), board.order_broken())
				if _shown_orders.x >= 0:
					_mode_pill.pulse()
				_shown_orders = state
		LaundryBoard.MODE_BOSS:
			if board.current_screen() != _shown_screen:
				_mode_pill.set_text("%d/%d" % [board.current_screen() + 1, board.screen_count()])
				if _shown_screen >= 0:
					_mode_pill.pulse()
				_shown_screen = board.current_screen()
	var wind: int = board.wind_left()
	if wind != _shown_wind:
		_wind_pill.visible = wind > 0
		_wind_pill.set_text(str(wind))
		_wind_pill.set_urgent(wind == 1)
		if _shown_wind != -2 and wind > 0:
			_wind_pill.pulse()
		_shown_wind = wind
	var slide: int = board.slide_left()
	if slide != _shown_slide:
		_slide_pill.visible = slide > 0
		_slide_pill.set_text(str(slide))
		_slide_pill.set_urgent(slide == 1)
		if _shown_slide != -2 and slide > 0:
			_slide_pill.pulse()
		_shown_slide = slide
	_refresh_guests(board)


func mode_pill() -> Node2D:
	return _mode_pill


func wind_pill() -> Node2D:
	return _wind_pill


## Düz hap: yuvarlak köşeli zemin, ikon, sayı ya da renk benekleri. Genişlik içeriğe uyar.
class Pill extends Node2D:
	var align_right: bool = false
	var _box: StyleBoxFlat = StyleBoxFlat.new()
	var _icon: Sprite2D = Sprite2D.new()
	var _label: Label = Label.new()
	var _dots: Array[Color] = []
	var _done: int = 0
	var _broken: bool = false
	var _urgent: bool = false
	var _width: float = 0.0
	var _content: Node2D = Node2D.new()
	var _tween: Tween = null
	## Beneklerin başladığı x (hap ortasına göre).
	var _dots_start: float = 0.0

	func _init() -> void:
		_box.bg_color = RulesHud.FILL
		_box.set_corner_radius_all(int(RulesHud.PILL_HEIGHT * 0.5))
		_box.anti_aliasing = true
		_box.anti_aliasing_size = 1.2
		add_child(_content)
		_content.add_child(_icon)
		_label.add_theme_font_size_override("font_size", RulesHud.FONT_SIZE)
		_label.add_theme_color_override("font_color", RulesHud.INK)
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.size = Vector2(0.0, RulesHud.PILL_HEIGHT)
		_content.add_child(_label)

	func set_icon(texture: Texture2D) -> void:
		_icon.texture = texture
		if texture != null:
			_icon.scale = Vector2.ONE * (RulesHud.ICON_SIZE / maxf(texture.get_size().x, 1.0))
		_icon.modulate = RulesHud.INK
		_layout()

	func set_text(text: String) -> void:
		_label.text = text
		_layout()

	func set_urgent(urgent: bool) -> void:
		_urgent = urgent
		var ink: Color = RulesHud.URGENT if urgent else RulesHud.INK
		_label.add_theme_color_override("font_color", ink)
		_icon.modulate = ink

	func set_dots(colors: Array[Color], done: int, broken: bool) -> void:
		_dots = colors
		_done = done
		_broken = broken
		_layout()

	## Değer değişti: hap kısa bir an büyüyüp oturur.
	func pulse() -> void:
		if _tween != null:
			_tween.kill()
		_content.scale = Vector2.ONE
		_tween = create_tween()
		_tween.tween_property(_content, "scale", Vector2.ONE * Motion.RULES_PULSE_SCALE, Motion.RULES_PULSE_IN_SECONDS)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_tween.tween_property(_content, "scale", Vector2.ONE, Motion.RULES_PULSE_OUT_SECONDS)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	## Yerleşim: içerik soldan sağa (ikon, sayı, benekler) dizilir; içerik düğümü hapın
	## ortasındadır ki nabız ölçeklemesi ortadan olsun. Sağa hizalı hap sol tarafa büyür.
	func _layout() -> void:
		var pad: float = RulesHud.PILL_PAD
		var x: float = pad
		var icon_x: float = 0.0
		if _icon.texture != null:
			icon_x = x + RulesHud.ICON_SIZE * 0.5
			x += RulesHud.ICON_SIZE + pad * 0.6
		var label_x: float = x
		if not _label.text.is_empty():
			x += _label.get_theme_font("font").get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT,
				-1.0, RulesHud.FONT_SIZE).x
		var dots_x: float = x
		var dots_width: float = float(_dots.size()) * (RulesHud.DOT_RADIUS * 2.0 + RulesHud.DOT_GAP)
		x += dots_width
		_width = x + pad * (0.5 if dots_width > 0.0 else 1.0)
		var half: float = _width * 0.5
		var left: float = -_width if align_right else 0.0
		_content.position = Vector2(left + half, RulesHud.PILL_HEIGHT * 0.5)
		_icon.position = Vector2(icon_x - half, 0.0)
		_label.position = Vector2(label_x - half, -RulesHud.PILL_HEIGHT * 0.5)
		_dots_start = dots_x - half
		queue_redraw()

	func _draw() -> void:
		var left: float = -_width if align_right else 0.0
		draw_style_box(_box, Rect2(Vector2(left, 0.0), Vector2(_width, RulesHud.PILL_HEIGHT)))
		var center_x: float = left + _width * 0.5
		var radius: float = RulesHud.DOT_RADIUS
		for index: int in range(_dots.size()):
			var tint: Color = _dots[index]
			if _broken:
				tint.a = RulesHud.BROKEN_ALPHA
			var at: Vector2 = Vector2(center_x + _dots_start + radius + float(index) * (radius * 2.0 + RulesHud.DOT_GAP),
				RulesHud.PILL_HEIGHT * 0.5)
			var scale_by: float = RulesHud.DOT_CURRENT_SCALE if index == _done and not _broken else 1.0
			draw_circle(at, radius * scale_by, tint, true, -1.0, true)
			# Renk körü: sipariş sırası yalnız renkle değil desenle de okunur (bozulunca glif de soluk).
			var glyph_alpha: float = RulesHud.BROKEN_ALPHA if _broken else 1.0
			ColorPatterns.draw_glyph(self, at, radius * scale_by, ColorPatterns.color_id_of(tint), glyph_alpha)
			if index < _done:
				draw_circle(at, radius * 0.42, RulesHud.DONE_DOT, true, -1.0, true)


# --- Misafir sayaçları (kuş, yağmur, kedi) -------------------------------------------------------

var _guest_pills: Array[Pill] = []
var _shown_guests: Array[int] = [-2, -2, -2]
var _right_x: float = 0.0
## Önbellek kodu: misafir oradayken aynı sayı farklı anlam taşır.
const GUEST_PRESENT_CODE: int = 1000


## Kuş/kedi oradayken kalkmasına kalan hamle kırmızı gösterilir; yoksa sıradakine kalan hamle.
## Değer değişince hap nabız atar; ardından sağ sütun yeniden dizilir (kare başına değil, tazelemede).
func _refresh_guests(board: LaundryBoard) -> void:
	if _guest_pills.is_empty():
		return
	var bird_here: bool = board.bird_on() != LaundryBoard.EMPTY
	var cat_here: bool = board.cat_at() != LaundryBoard.EMPTY
	_show_guest(0, board.bird_sit_left() if bird_here else board.bird_left(), bird_here)
	_show_guest(1, board.rain_left(), false)
	_show_guest(2, board.cat_stay_left() if cat_here else board.cat_left(), cat_here)
	_refresh_season(board)
	_stack()


## `present`: misafir şu an tahtada (sayı kalkışa kalan hamle, kırmızı).
func _show_guest(index: int, left: int, present: bool) -> void:
	var code: int = left + (GUEST_PRESENT_CODE if present else 0)
	if code == _shown_guests[index]:
		return
	var pill: Pill = _guest_pills[index]
	pill.visible = left > 0
	pill.set_text(str(left))
	pill.set_urgent(present or left == 1)
	if _shown_guests[index] != -2 and pill.visible:
		pill.pulse()
	_shown_guests[index] = code


## Sağ sütun: görünen haplar yukarıdan aşağı boşluksuz (rüzgâr, sürgü, kuş, yağmur, kedi).
func _stack() -> void:
	var row: int = 0
	for pill: Pill in [_wind_pill, _slide_pill] + _guest_pills + _season_pills:
		if not pill.visible:
			continue
		pill.position = Vector2(_right_x, PILL_Y + SLIDE_PILL_OFFSET_Y * float(row))
		row += 1


func guest_pill(index: int) -> Node2D:
	return _guest_pills[index] if index >= 0 and index < _guest_pills.size() else null


# --- Mevsim sayaçları (yaprak, polen) -----------------------------------------------------------

const ICON_LEAF: String = "res://assets/sprites/seasons_fx/icon_leaf.png"
const ICON_POLLEN: String = "res://assets/sprites/seasons_fx/icon_pollen.png"
var _season_pills: Array[Pill] = []
var _shown_season: Array[int] = [-2, -2]


## Yaprak: sıradakine kalan hamle. Polen: ip tozluyken açılmasına kalan hamle (kırmızı), değilse
## sıradaki buluta kalan hamle. Yalnız değişince yazılır.
func _refresh_season(board: LaundryBoard) -> void:
	if _season_pills.is_empty():
		return
	_show_season(0, board.leaf_left(), false)
	var dusted: bool = board.dust_line() != LaundryBoard.EMPTY
	_show_season(1, board.dust_left() if dusted else board.pollen_left(), dusted)


func _show_season(index: int, left: int, present: bool) -> void:
	var code: int = left + (GUEST_PRESENT_CODE if present else 0)
	if code == _shown_season[index]:
		return
	var pill: Pill = _season_pills[index]
	pill.visible = left > 0
	pill.set_text(str(left))
	pill.set_urgent(present or left == 1)
	if _shown_season[index] != -2 and pill.visible:
		pill.pulse()
	_shown_season[index] = code


func season_pill(index: int) -> Node2D:
	return _season_pills[index] if index >= 0 and index < _season_pills.size() else null
