class_name ResultSheet
extends Sheet

## Seviye sonucu sayfası: 1-3 yıldız, başlık, hamle ve par, "yeni rekor" notu; altta tek büyük birincil
## (Sonraki; son seviyede Seviyeler) ve iki sakin ikincil (Tekrar, Seviyeler). Yalnız gösterir;
## ilerleme/reklam mantığı Game sahnesindedir.

signal next_pressed
signal retry_pressed
signal levels_pressed

const STAR_PIXELS: float = 120.0
const STAR_GAP: int = UiTokens.SPACE_LG
const TITLE_SIZE: int = UiKit.TITLE_SIZE
const MAIN_HEIGHT: float = UiKit.HEIGHT_PRIMARY
const BLOCK_GAP: float = UiKit.SPACE_LG
const ROW_GAP: int = UiTokens.SPACE_MD
const WIN_SOUND: String = "win"
const STAR_SOUND: String = "ui_soft"
const STAR_PITCH_BASE: float = 1.0
const STAR_PITCH_STEP: float = 0.18
const STAR_VOLUME_DB: float = -2.0

var _stars: UiStarRow = null


## info: { stars:int, moves:int, par:int, new_best:bool, has_next:bool }
static func solved(parent: Node, info: Dictionary) -> ResultSheet:
	var sheet: ResultSheet = ResultSheet.new()
	sheet.build(parent, false)
	sheet._fill(info)
	sheet.play_intro()
	return sheet


func stars_shown() -> int:
	return _stars.earned() if _stars != null else 0


func _fill(info: Dictionary) -> void:
	var column: VBoxContainer = content()
	var earned: int = int(info.get("stars", 1))
	_stars = UiStarRow.new()
	_stars.name = "Stars"
	_stars.setup(earned, STAR_PIXELS, STAR_GAP)
	column.add_child(_stars)
	column.add_child(UiKit.spacer(BLOCK_GAP))
	var title: Label = UiKit.wrap_label(UiStrings.result_title(earned), TITLE_SIZE)
	title.name = "Title"
	column.add_child(title)
	column.add_child(UiKit.spacer(UiKit.SPACE_XS))
	var detail: Label = UiKit.label(UiStrings.result_moves(int(info.get("moves", 0)), int(info.get("par", 0))),
		UiKit.TYPE_BODY, UiKit.TEXT_MUTED)
	detail.name = "Detail"
	column.add_child(detail)
	if bool(info.get("new_best", false)):
		var best: Label = UiKit.label(UiStrings.result_best(), UiKit.TYPE_CAPTION, UiKit.ACCENT)
		best.name = "NewBest"
		column.add_child(best)
	column.add_child(UiKit.spacer(UiKit.SPACE_XXL))
	var has_next: bool = bool(info.get("has_next", false))
	var main: Button = UiKit.button(UiStrings.result_next() if has_next else UiStrings.levels(), &"",
		"lucide/chevron-right" if has_next else "lucide/grid-2x2", MAIN_HEIGHT)
	main.name = "NextButton"
	main.pressed.connect((next_pressed if has_next else levels_pressed).emit)
	column.add_child(main)
	column.add_child(UiKit.spacer(UiKit.SPACE_MD))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", ROW_GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)
	var retry: Button = UiKit.button(UiStrings.result_retry(), &"SecondaryButton", "lucide/rotate-ccw", UiKit.HEIGHT_SECONDARY)
	retry.name = "RetryButton"
	retry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	retry.pressed.connect(retry_pressed.emit)
	row.add_child(retry)
	if has_next:
		var levels: Button = UiKit.button(UiStrings.levels(), &"SecondaryButton", "lucide/grid-2x2", UiKit.HEIGHT_SECONDARY)
		levels.name = "LevelsButton"
		levels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		levels.pressed.connect(levels_pressed.emit)
		row.add_child(levels)
	AudioService.play(WIN_SOUND)
	_stars.pop_in(_play_star)


func _play_star(index: int) -> void:
	AudioService.play_pitched(STAR_SOUND, STAR_PITCH_BASE + STAR_PITCH_STEP * float(index), STAR_VOLUME_DB)
