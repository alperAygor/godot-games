class_name DailyFlow
extends Sheet

## Günlük bulmacanın sonuç sayfası. `game.gd` günlük kipte normal ekonomi/ilerleme yerine
## BUNU çağırır: seviye numarası, galibiyet serisi ve ilerleme hiç değişmez; yalnız günlük
## ödül (günde bir kez) ve günlük seri işlenir. Kazanma tekrarında ödül verilmez.

signal home_pressed
signal retry_pressed

const TITLE_SIZE: int = 52
const BODY_SIZE: int = 32
const GAP: float = 24.0
const MAIN_HEIGHT: float = 132.0
const COUNT_DELAY: float = 0.5
const COUNT_SECONDS: float = 0.9
const WIN_VOLUME_DB: float = -3.0
const COIN_VOLUME_DB: float = -4.0
const COIN_SOUND_DELAY: float = 0.35
const STORM_ICON: String = "lucide/wind"

var _coin_label: Label = null
var _coin_shown: float = 0.0


## Bitiş sayfasını `ui` altına açar. Kazanmada ödül BURADA verilir (kayıt `DailyStore`da).
## `retry`: kayıpta "Tekrar dene" (oyun seviyeyi yeniden başlatır).
static func show_end(ui: Node, level: Dictionary, won: bool, tints: Array[Color],
		retry: Callable) -> DailyFlow:
	var sheet: DailyFlow = DailyFlow.new()
	sheet.build(ui, false)
	if won:
		var outcome: Dictionary = DailyStore.record_win(String(level.get(DailyPuzzle.META_DATE, "")))
		sheet._fill_win(outcome, tints)
		AudioService.play_pitched("win", 1.0, WIN_VOLUME_DB)
		if bool(outcome["first"]):
			sheet.get_tree().create_timer(COIN_SOUND_DELAY).timeout.connect(
				AudioService.play_pitched.bind("coin", 1.0, COIN_VOLUME_DB))
	else:
		sheet._fill_lose()
		AudioService.play_pitched("lose", 1.0, WIN_VOLUME_DB)
	sheet.retry_pressed.connect(retry)
	sheet.home_pressed.connect(GameManager.goto_scene.bind(&"home"))
	sheet.play_intro()
	return sheet


func _fill_win(outcome: Dictionary, tints: Array[Color]) -> void:
	var column: VBoxContainer = content()
	var pile: UiFoldedPile = UiFoldedPile.new()
	pile.setup(tints)
	column.add_child(pile)
	pile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pile.play(Motion.OVERLAY_FADE_SECONDS)
	column.add_child(UiKit.spacer(GAP))
	column.add_child(UiKit.label(DailyStrings.WIN_TITLE, TITLE_SIZE))
	column.add_child(UiKit.spacer(GAP * 0.6))
	if bool(outcome["first"]):
		var row: HBoxContainer = DailyUi.reward_row(0, String(outcome["booster"]), int(outcome["booster_count"]))
		_coin_label = row.get_child(1) as Label
		column.add_child(row)
		_count_coins(int(outcome["coins"]))
		column.add_child(UiKit.spacer(GAP))
		column.add_child(DailyUi.streak_row(int(outcome["streak"]), int(outcome["best"])))
	else:
		column.add_child(UiKit.label(DailyStrings.WIN_AGAIN, BODY_SIZE, UiKit.TEXT_MUTED))
	column.add_child(UiKit.spacer(GAP * 1.8))
	var next: Button = UiKit.button(DailyStrings.CONTINUE, &"", "", MAIN_HEIGHT)
	next.pressed.connect(home_pressed.emit)
	column.add_child(next)


func _fill_lose() -> void:
	var column: VBoxContainer = content()
	column.add_child(DailyUi.icon_disc(STORM_ICON, UiKit.ACCENT_SOFT, UiKit.TEXT_MUTED))
	column.add_child(UiKit.spacer(GAP))
	column.add_child(UiKit.label(DailyStrings.LOSE_TITLE, TITLE_SIZE))
	column.add_child(UiKit.spacer(GAP * 2.0))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", int(GAP))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)
	var home: UiIconButton = UiIconButton.new()
	home.setup("lucide/house")
	home.disc_color = UiKit.ACCENT_SOFT
	home.pressed.connect(home_pressed.emit)
	row.add_child(home)
	var retry: Button = UiKit.button(DailyStrings.LOSE_RETRY, &"", "lucide/rotate-ccw", MAIN_HEIGHT)
	retry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	retry.pressed.connect(retry_pressed.emit)
	row.add_child(retry)


func _count_coins(total: int) -> void:
	var tween: Tween = create_tween()
	tween.tween_interval(COUNT_DELAY)
	tween.tween_method(_set_coins_shown, 0.0, float(total), COUNT_SECONDS)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _set_coins_shown(value: float) -> void:
	_coin_shown = value
	_coin_label.text = DailyStrings.REWARD_FORMAT % roundi(value)
