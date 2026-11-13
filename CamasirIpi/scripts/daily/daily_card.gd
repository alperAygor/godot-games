class_name DailyCard
extends Sheet

## Günün bulmacası kartı: durum (bekliyor / çözüldü), seri, ödül ve "Oyna".
## Oyna: seviye `DailyPuzzle.pending_level`a konur ve oyun sahnesine geçilir (normal ilerleme
## akışından bağımsız; sonucu `DailyFlow` gösterir).

const TITLE_SIZE: int = 48
const SUBTITLE_SIZE: int = 32
const GAP: float = 24.0
const PLAY_HEIGHT: float = 132.0
const READY_DISC: Color = DailyUi.WARM_SOFT
const SOLVED_ICON: String = "lucide/check"
const READY_ICON: String = "lucide/star"

var _today: String = ""


## `today_override`: yalnız araçlar/testler içindir (boşsa yerel tarih).
static func open(parent: Node, today_override: String = "") -> DailyCard:
	var card: DailyCard = DailyCard.new()
	card._today = today_override if not today_override.is_empty() else DailyDate.today_key()
	card.build(parent, false)
	card.dismiss_on_dim = true
	card._fill()
	card.play_intro()
	return card


func _fill() -> void:
	var column: VBoxContainer = content()
	var state: Dictionary = DailyStore.puzzle_state()
	var level: int = Progress.level()
	var solved: bool = DailyPuzzle.won_on(state, _today)
	var locked: bool = level < DailyPuzzle.unlock_level()
	column.add_child(DailyUi.icon_disc(SOLVED_ICON if solved else READY_ICON,
		UiKit.ACCENT_SOFT if solved else READY_DISC, UiKit.ACCENT if solved else UiKit.GOLD))
	column.add_child(UiKit.spacer(GAP))
	column.add_child(UiKit.label(DailyStrings.PUZZLE_TITLE, TITLE_SIZE))
	column.add_child(UiKit.spacer(GAP * 0.4))
	var subtitle: String = DailyStrings.PUZZLE_READY
	if solved:
		subtitle = DailyStrings.PUZZLE_TOMORROW
	elif locked:
		subtitle = DailyStrings.PUZZLE_LOCKED % DailyPuzzle.unlock_level()
	column.add_child(UiKit.label(subtitle, SUBTITLE_SIZE, UiKit.TEXT_MUTED))
	column.add_child(UiKit.spacer(GAP * 1.4))
	column.add_child(DailyUi.streak_row(DailyPuzzle.display_streak(state, _today), int(state["best"])))
	if not solved:
		var preview: Dictionary = DailyPuzzle.reward_for(DailyPuzzle.streak_after_win(state, _today), level)
		column.add_child(UiKit.spacer(GAP))
		column.add_child(DailyUi.reward_row(int(preview["coins"]), String(preview["booster"]),
			int(preview["booster_count"])))
	column.add_child(UiKit.spacer(GAP * 1.6))
	if solved or locked:
		var close_button: Button = UiKit.button(DailyStrings.CLOSE, &"SecondaryButton", "lucide/x", PLAY_HEIGHT)
		close_button.pressed.connect(close)
		column.add_child(close_button)
		return
	var play: Button = UiKit.button(DailyStrings.PLAY, &"", "lucide/play", PLAY_HEIGHT)
	play.pressed.connect(_on_play)
	column.add_child(play)


func _on_play() -> void:
	# Seviye oyuncunun seviye kovasına göre kurulur; oyun sahnesi devri tek seferde alır.
	DailyPuzzle.pending_level = DailyPuzzle.build_level(_today, Progress.level())
	GameManager.goto_scene(&"game")
