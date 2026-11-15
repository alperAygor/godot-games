class_name LevelTile
extends Button

## Seviye haritasındaki tek karo. Tek `_draw` ile çizilir (yüzlerce seviyede çocuk düğüm yok):
## yuvarlak düz zemin, ortada seviye numarası, altta yıldızlar / "atlandı" işareti / kilit.
## Durumlar: kilitli (sönük + kilit), açık (düz), şimdiki (vurgu rengi), çözülmüş (yumuşak yeşil + yıldız),
## atlanmış (sönük + ileri-atla işareti). Dokunma alanı karonun tamamıdır (>= 126).

enum Mode { LOCKED, OPEN, CURRENT, SOLVED, SKIPPED }

const NUMBER_SIZE: int = UiKit.TYPE_NUMERIC
const STAR_PIXELS: float = 34.0
const STAR_GAP: float = 6.0
const MARK_PIXELS: float = 40.0
const NUMBER_CENTER_RATIO: float = 0.40
const BOTTOM_ROW_RATIO: float = 0.76
const STAR_OFF: Color = Color(0.0, 0.0, 0.0, 0.08)
const SKIPPED_FILL_ALPHA: float = 0.14

var level_id: String = ""
var number: int = 1
var mode: Mode = Mode.LOCKED
var stars_earned: int = 0


func setup(new_id: String, new_number: int, new_mode: Mode, new_stars: int, tile_size: Vector2) -> void:
	level_id = new_id
	number = new_number
	mode = new_mode
	stars_earned = new_stars
	custom_minimum_size = tile_size
	focus_mode = Control.FOCUS_NONE
	flat = true
	var none: StyleBoxEmpty = StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(state, none)
	UiKit.attach_press_scale(self)
	pressed.connect(UiKit.tap_sound)


func _draw() -> void:
	var fill: Color = UiKit.SURFACE_SOFT
	var ink: Color = UiKit.TEXT
	match mode:
		Mode.LOCKED:
			fill = Color(0.0, 0.0, 0.0, 0.035)
			ink = Color(UiKit.TEXT_MUTED, 0.75)
		Mode.OPEN:
			fill = UiKit.SHEET
		Mode.CURRENT:
			fill = UiKit.ACCENT
			ink = Color.WHITE
		Mode.SOLVED:
			fill = UiKit.ACCENT_SOFT
		Mode.SKIPPED:
			fill = Color(UiKit.FLAME, SKIPPED_FILL_ALPHA)
			ink = UiKit.TEXT_MUTED
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(UiKit.RADIUS_TILE)
	box.anti_aliasing = true
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	var font: Font = UiKit.numeric_font()
	var label: String = str(number)
	var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, NUMBER_SIZE)
	var baseline: float = size.y * NUMBER_CENTER_RATIO \
		+ (font.get_ascent(NUMBER_SIZE) - font.get_descent(NUMBER_SIZE)) * 0.5
	draw_string(font, Vector2((size.x - text_size.x) * 0.5, baseline), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		NUMBER_SIZE, ink)
	var row_y: float = size.y * BOTTOM_ROW_RATIO
	match mode:
		Mode.SOLVED:
			_draw_stars(row_y)
		Mode.SKIPPED:
			_draw_mark("lucide/skip-forward", row_y, UiKit.FLAME)
		Mode.LOCKED:
			_draw_mark("lucide/lock", row_y, Color(UiKit.TEXT_MUTED, 0.75))


func _draw_stars(row_y: float) -> void:
	var texture: Texture2D = Icons.texture("shell/star-fill")
	if texture == null:
		return
	var total: float = float(LevelProgress.MAX_STARS) * STAR_PIXELS + float(LevelProgress.MAX_STARS - 1) * STAR_GAP
	var left: float = (size.x - total) * 0.5
	for index: int in LevelProgress.MAX_STARS:
		var at: Vector2 = Vector2(left + float(index) * (STAR_PIXELS + STAR_GAP), row_y - STAR_PIXELS * 0.5)
		draw_texture_rect(texture, Rect2(at, Vector2(STAR_PIXELS, STAR_PIXELS)), false,
			UiKit.STAR if index < stars_earned else STAR_OFF)


func _draw_mark(icon_name: String, row_y: float, tint: Color) -> void:
	var texture: Texture2D = Icons.texture(icon_name)
	if texture == null:
		return
	var at: Vector2 = Vector2((size.x - MARK_PIXELS) * 0.5, row_y - MARK_PIXELS * 0.5)
	draw_texture_rect(texture, Rect2(at, Vector2(MARK_PIXELS, MARK_PIXELS)), false, tint)
