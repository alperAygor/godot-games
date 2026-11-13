class_name PauseSheet
extends Sheet

## Duraklatma sayfası: ses/müzik/titreşim, yeniden başlat, ana ekran ve büyük "Devam".
## Oyunu durdurur (Sheet.pause_tree); kapanınca devam eder.

signal resume_pressed
signal restart_pressed
signal home_pressed

const TITLE_SIZE: int = 44
const ROW_GAP: float = 28.0
const ROW_SEPARATION: int = 24
const RESUME_HEIGHT: float = 132.0


static func open(parent: Node) -> PauseSheet:
	var sheet: PauseSheet = PauseSheet.new()
	sheet.build(parent, true)
	sheet.dismiss_on_dim = true
	sheet._fill()
	sheet.play_intro()
	return sheet


func _fill() -> void:
	var column: VBoxContainer = content()
	column.add_child(UiKit.label(UiStrings.paused(), TITLE_SIZE))
	column.add_child(UiKit.spacer(ROW_GAP))
	column.add_child(UiSettingsRow.new())
	column.add_child(UiKit.spacer(ROW_GAP + 12.0))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", ROW_SEPARATION)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)
	var restart: UiIconButton = UiIconButton.new()
	restart.setup("lucide/rotate-ccw")
	restart.disc_color = UiKit.ACCENT_SOFT
	restart.pressed.connect(_emit_after_close.bind(restart_pressed))
	row.add_child(restart)
	var home: UiIconButton = UiIconButton.new()
	home.setup("lucide/house")
	home.disc_color = UiKit.ACCENT_SOFT
	home.pressed.connect(_emit_after_close.bind(home_pressed))
	row.add_child(home)
	var resume: Button = UiKit.button(UiStrings.resume(), &"", "lucide/play", RESUME_HEIGHT)
	resume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resume.pressed.connect(_emit_after_close.bind(resume_pressed))
	row.add_child(resume)


## Önce oyun devam eder (duraklatma kalkar), sonra sinyal gider; böylece "yeniden başlat"
## ve "ana ekran" donuk ağaçta çalışmaz.
func _emit_after_close(signal_to_emit: Signal) -> void:
	close()
	signal_to_emit.emit()
