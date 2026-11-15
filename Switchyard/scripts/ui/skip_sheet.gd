class_name SkipSheet
extends Sheet

## "Seviye atlansın mı?" onayı. Atlama bir ödüllü reklam ister; yanlışlıkla reklam açılmasın diye önce sorulur.
## Birincil: videoyu izle (video ikonlu). İkincil: şimdi değil. Ödül/atlama mantığı burada değil (yalnız gösterir).

signal watch_pressed
signal cancel_pressed

const BODY_SIZE: int = UiKit.TYPE_BODY
const BLOCK_GAP: float = UiKit.SPACE_LG


static func open(parent: Node) -> SkipSheet:
	var sheet: SkipSheet = SkipSheet.new()
	sheet.build(parent, false)
	sheet.dismiss_on_dim = true
	sheet._fill()
	sheet.play_intro()
	return sheet


func _fill() -> void:
	var column: VBoxContainer = content()
	column.add_child(UiKit.centered_disc("lucide/skip-forward", UiKit.ACCENT_SOFT, UiKit.ACCENT))
	column.add_child(UiKit.spacer(BLOCK_GAP))
	add_title(UiStrings.skip_title())
	column.add_child(UiKit.wrap_label(UiStrings.skip_body(), BODY_SIZE, UiKit.TEXT_MUTED))
	column.add_child(UiKit.spacer(UiKit.SPACE_XXL))
	var watch: Button = UiKit.button(UiStrings.skip_watch(), &"", "lucide/video", UiKit.HEIGHT_PRIMARY)
	watch.name = "WatchButton"
	watch.pressed.connect(_emit_after_close.bind(watch_pressed))
	column.add_child(watch)
	column.add_child(UiKit.spacer(UiKit.AD_BUTTON_GAP))
	var cancel: Button = UiKit.button(UiStrings.skip_cancel(), &"SecondaryButton", "", UiKit.HEIGHT_SECONDARY)
	cancel.name = "CancelButton"
	cancel.pressed.connect(_emit_after_close.bind(cancel_pressed))
	column.add_child(cancel)
	closed.connect(_on_closed)


func _emit_after_close(signal_to_emit: Signal) -> void:
	closed.disconnect(_on_closed)
	close()
	signal_to_emit.emit()


## Karartmaya dokunarak kapanış = vazgeçmek.
func _on_closed() -> void:
	cancel_pressed.emit()
