class_name LevelTile
extends RefCounted

## Seviye haritasındaki tek karonun ÇİZİMİ (düğüm yok: `WorldGrid` yüzlerce karoyu tek `_draw` ile çizer).
## Durumlar: kilitli (sönük + kilit), açık (düz), şimdiki (vurgu rengi + oynat işareti), çözülmüş (dünya renginde
## yumuşak zemin + yıldız), atlanmış (amber + ileri-atla işareti). Üstte 5 noktalık zorluk işareti (katalog `difficulty` 1-10).
## Tutarlılık: renk, yarıçap, boy ölçüleri `data/theme.json` belirteçlerinden.

enum Mode { LOCKED, OPEN, CURRENT, SOLVED, SKIPPED }

const NUMBER_SIZE: int = UiKit.TYPE_NUMERIC
const STAR_PIXELS: float = float(UiTokens.ICON_STAR_TILE)
const STAR_GAP: float = 6.0
const MARK_PIXELS: float = float(UiTokens.ICON_MARK)
const CUE_ROW_RATIO: float = 0.17
const NUMBER_CENTER_RATIO: float = 0.48
const BOTTOM_ROW_RATIO: float = 0.80
const STAR_OFF: Color = Color(0.0, 0.0, 0.0, 0.08)
const SKIPPED_FILL_ALPHA: float = 0.14
const CUE_DOTS: int = 5
const PRESS_SCALE: float = 0.95
const LOCKED_INK_ALPHA: float = 0.75
const SOLVED_TINT: float = 0.82

static var _box: StyleBoxFlat = null


## Zorluk 1-10 -> 1-5 nokta.
static func cue_dots(difficulty: int) -> int:
	return clampi(ceili(float(clampi(difficulty, 1, 10)) / 2.0), 1, CUE_DOTS)


static func paint(canvas: CanvasItem, rect: Rect2, number: int, mode: Mode, stars_earned: int, difficulty: int,
		accent: Color, press: float) -> void:
	if _box == null:
		_box = StyleBoxFlat.new()
		_box.set_corner_radius_all(UiKit.RADIUS_TILE)
		_box.anti_aliasing = true
	var fill: Color = UiKit.SURFACE_SOFT
	var ink: Color = UiKit.TEXT
	var cue_on: Color = Color(accent, 0.9)
	match mode:
		Mode.LOCKED:
			fill = Color(0.0, 0.0, 0.0, 0.035)
			ink = Color(UiKit.TEXT_MUTED, LOCKED_INK_ALPHA)
			cue_on = Color(UiKit.TEXT_MUTED, 0.35)
		Mode.OPEN:
			fill = UiKit.SHEET
		Mode.CURRENT:
			fill = UiKit.ACCENT
			ink = Color.WHITE
			cue_on = Color(1.0, 1.0, 1.0, 0.85)
		Mode.SOLVED:
			fill = accent.lerp(UiKit.SHEET, SOLVED_TINT)
		Mode.SKIPPED:
			fill = Color(UiKit.FLAME, SKIPPED_FILL_ALPHA)
			ink = UiKit.TEXT_MUTED
			cue_on = Color(UiKit.FLAME, 0.55)
	var scaled: Rect2 = rect
	if press > 0.0:
		var factor: float = lerpf(1.0, PRESS_SCALE, press)
		scaled = Rect2(rect.get_center() - rect.size * factor * 0.5, rect.size * factor)
	_box.bg_color = fill
	canvas.draw_style_box(_box, scaled)
	_paint_cue(canvas, scaled, difficulty, cue_on, ink, mode)
	var font: Font = UiKit.numeric_font()
	var label: String = str(number)
	var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, NUMBER_SIZE)
	var baseline: float = scaled.position.y + scaled.size.y * NUMBER_CENTER_RATIO \
		+ (font.get_ascent(NUMBER_SIZE) - font.get_descent(NUMBER_SIZE)) * 0.5
	canvas.draw_string(font, Vector2(scaled.position.x + (scaled.size.x - text_size.x) * 0.5, baseline), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, NUMBER_SIZE, ink)
	var row_y: float = scaled.position.y + scaled.size.y * BOTTOM_ROW_RATIO
	match mode:
		Mode.SOLVED:
			_paint_stars(canvas, scaled, row_y, stars_earned)
		Mode.SKIPPED:
			_paint_mark(canvas, scaled, "lucide/skip-forward", row_y, UiKit.FLAME)
		Mode.LOCKED:
			_paint_mark(canvas, scaled, "lucide/lock", row_y, Color(UiKit.TEXT_MUTED, LOCKED_INK_ALPHA))
		Mode.CURRENT:
			_paint_mark(canvas, scaled, "lucide/play", row_y, Color.WHITE)


static func _paint_cue(canvas: CanvasItem, rect: Rect2, difficulty: int, on: Color, ink: Color, mode: Mode) -> void:
	var dot: float = float(UiTokens.SIZE_CUE_DOT)
	var gap: float = float(UiTokens.SIZE_CUE_GAP)
	var total: float = float(CUE_DOTS) * dot + float(CUE_DOTS - 1) * gap
	var left: float = rect.position.x + (rect.size.x - total) * 0.5 + dot * 0.5
	var y: float = rect.position.y + rect.size.y * CUE_ROW_RATIO
	var lit: int = cue_dots(difficulty)
	var off: Color = Color(ink, 0.16 if mode != Mode.CURRENT else 0.3)
	for index: int in CUE_DOTS:
		canvas.draw_circle(Vector2(left + float(index) * (dot + gap), y), dot * 0.5, on if index < lit else off,
			true, -1.0, true)


static func _paint_stars(canvas: CanvasItem, rect: Rect2, row_y: float, earned: int) -> void:
	var texture: Texture2D = Icons.texture("shell/star-fill")
	if texture == null:
		return
	var total: float = float(LevelProgress.MAX_STARS) * STAR_PIXELS + float(LevelProgress.MAX_STARS - 1) * STAR_GAP
	var left: float = rect.position.x + (rect.size.x - total) * 0.5
	for index: int in LevelProgress.MAX_STARS:
		var at: Vector2 = Vector2(left + float(index) * (STAR_PIXELS + STAR_GAP), row_y - STAR_PIXELS * 0.5)
		canvas.draw_texture_rect(texture, Rect2(at, Vector2(STAR_PIXELS, STAR_PIXELS)), false,
			UiKit.STAR if index < earned else STAR_OFF)


static func _paint_mark(canvas: CanvasItem, rect: Rect2, icon_name: String, row_y: float, tint: Color) -> void:
	var texture: Texture2D = Icons.texture(icon_name)
	if texture == null:
		return
	var at: Vector2 = Vector2(rect.position.x + (rect.size.x - MARK_PIXELS) * 0.5, row_y - MARK_PIXELS * 0.5)
	canvas.draw_texture_rect(texture, Rect2(at, Vector2(MARK_PIXELS, MARK_PIXELS)), false, tint)
