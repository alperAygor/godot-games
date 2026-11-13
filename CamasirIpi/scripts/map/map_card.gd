class_name MapCard
extends Sheet

## Bitirilmiş seviyeye dokunulunca açılan küçük kart: seviye adı, en iyi yıldızlar, kısa not ve
## "Tekrar oyna". Düz, çizgisiz, az metin; kart dışına dokunmak kapatır.

signal replay_pressed(level: int)

const TITLE_SIZE: int = 56
const NOTE_SIZE: int = 30
const GAP: float = 28.0
const BUTTON_HEIGHT: float = 132.0

var level: int = 0


static func open(parent: Node, level_number: int) -> MapCard:
	var card: MapCard = MapCard.new()
	card.level = level_number
	card.build(parent, false)
	card.dismiss_on_dim = true
	card._fill()
	card.play_intro()
	return card


func _fill() -> void:
	var column: VBoxContainer = content()
	column.add_child(UiKit.label(UiStrings.level(level), TITLE_SIZE))
	column.add_child(UiKit.spacer(GAP))
	var stars: MapStars = MapStars.new()
	stars.setup(Progress.best_stars(level))
	stars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(stars)
	column.add_child(UiKit.spacer(GAP * 0.7))
	column.add_child(UiKit.label(Loc.t("MAP_REPLAY_NOTE"), NOTE_SIZE, UiKit.TEXT_MUTED))
	column.add_child(UiKit.spacer(GAP * 1.3))
	var replay: Button = UiKit.button(Loc.t("MAP_REPLAY"), &"", "lucide/rotate-ccw", BUTTON_HEIGHT)
	replay.pressed.connect(_on_replay)
	column.add_child(replay)


func _on_replay() -> void:
	replay_pressed.emit(level)
	MapFlow.start_replay(level)
