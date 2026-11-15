class_name ResultSheet
extends Sheet

## Kazanma ve kaybetme sayfası. Game yalnız `ResultSheet.win(...)` / `.lose(...)` çağırır ve
## sinyallere bağlanır; ödül/reklam mantığı burada değildir (yalnız gösterir).
## Kazanma: kupa diski, başlık, sayarak artan jeton ödülü, ikincil "2×" (ödüllü reklam), büyük "Devam".
## Kaybetme: sakin disk, başlık, birincil "Devam et" (YALNIZ ödüllü reklam), ikincil "Tekrar dene".

signal continue_pressed
signal double_pressed
signal revive_pressed
signal retry_pressed

const TITLE_SIZE: int = UiKit.TITLE_SIZE
const REWARD_SIZE: int = UiKit.TYPE_DISPLAY
const REWARD_ICON: float = UiKit.ICON_LG
const MAIN_HEIGHT: float = UiKit.HEIGHT_PRIMARY
const DOUBLE_WIDTH: float = 300.0
const BLOCK_GAP: float = UiKit.SPACE_LG
const COUNT_DELAY: float = 0.5
const COUNT_SECONDS: float = 0.9
const REWARD_ROW_GAP: int = UiTokens.SPACE_MD
const WIN_SOUND: String = "win"
const COIN_SOUND: String = "coin"

var _reward_label: Label = null
var _reward_shown: float = 0.0
var _double_button: Button = null
var _count_tween: Tween = null


## Kazanma sayfası. `reward` ÖDENEN jetondur; `can_double` ödüllü reklam sunulabiliyorsa true.
static func win(parent: Node, reward: int, can_double: bool) -> ResultSheet:
	var sheet: ResultSheet = ResultSheet.new()
	sheet.build(parent, false)
	sheet._fill_win(reward, can_double)
	sheet.play_intro()
	return sheet


## Kaybetme sayfası. `can_revive` false ise (bu turda kullanıldı / reklam yok) "Tekrar dene" birincil olur.
static func lose(parent: Node, can_revive: bool) -> ResultSheet:
	var sheet: ResultSheet = ResultSheet.new()
	sheet.build(parent, false)
	sheet._fill_lose(can_revive)
	sheet.play_intro()
	return sheet


## "2×" sonrası: ödül toplamına yumuşakça sayar ve ikinci düğmeyi kaldırır.
func show_doubled(total: int) -> void:
	if _double_button != null:
		_double_button.visible = false
	_count_reward(total, 0.0)


func reward_text() -> String:
	return _reward_label.text if _reward_label != null else ""


func _fill_win(reward: int, can_double: bool) -> void:
	var column: VBoxContainer = content()
	column.add_child(UiKit.centered_disc("lucide/trophy", UiKit.COIN_SOFT, UiKit.GOLD))
	column.add_child(UiKit.spacer(BLOCK_GAP))
	column.add_child(UiKit.label(UiStrings.win_title(), TITLE_SIZE))
	column.add_child(UiKit.spacer(UiKit.SPACE_SM))
	var reward_row: HBoxContainer = HBoxContainer.new()
	reward_row.alignment = BoxContainer.ALIGNMENT_CENTER
	reward_row.add_theme_constant_override("separation", REWARD_ROW_GAP)
	reward_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(reward_row)
	var coin: TextureRect = UiKit.tinted_icon("lucide/coins", REWARD_ICON, UiKit.GOLD)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reward_row.add_child(coin)
	# Sayarken basamaklar oynamasın diye sabit genişlikli rakamlar.
	_reward_label = UiKit.numeric_label(UiStrings.REWARD_FORMAT % 0, REWARD_SIZE)
	reward_row.add_child(_reward_label)
	_count_reward(reward, COUNT_DELAY)
	column.add_child(UiKit.spacer(UiKit.SPACE_XL))
	if can_double:
		_double_button = UiKit.button(UiStrings.WIN_DOUBLE, &"SecondaryButton", "lucide/video", UiKit.MIN_TOUCH)
		_double_button.custom_minimum_size.x = DOUBLE_WIDTH
		_double_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_double_button.name = "DoubleButton"
		_double_button.pressed.connect(double_pressed.emit)
		column.add_child(_double_button)
		# Reklam düğmesi ile "Devam" arasında en az 42 px (16 dp) boşluk: yanlışlıkla basılmasın.
		column.add_child(UiKit.spacer(UiKit.AD_BUTTON_GAP))
	var next: Button = UiKit.button(UiStrings.win_continue(), &"", "", MAIN_HEIGHT)
	next.name = "ContinueButton"
	next.pressed.connect(continue_pressed.emit)
	column.add_child(next)
	AudioService.play(WIN_SOUND)


func _fill_lose(can_revive: bool) -> void:
	var column: VBoxContainer = content()
	column.add_child(UiKit.centered_disc("lucide/wind", UiKit.ACCENT_SOFT, UiKit.TEXT_MUTED))
	column.add_child(UiKit.spacer(BLOCK_GAP))
	column.add_child(UiKit.label(UiStrings.lose_title(), TITLE_SIZE))
	column.add_child(UiKit.spacer(UiKit.SPACE_XXL))
	if can_revive:
		var revive: Button = UiKit.button(UiStrings.lose_revive(), &"", "lucide/video", MAIN_HEIGHT)
		revive.name = "ReviveButton"
		revive.pressed.connect(revive_pressed.emit)
		column.add_child(revive)
		column.add_child(UiKit.spacer(UiKit.AD_BUTTON_GAP))
	var retry: Button = UiKit.button(UiStrings.lose_retry(), &"SecondaryButton" if can_revive else &"",
		"lucide/rotate-ccw", MAIN_HEIGHT if not can_revive else UiKit.MIN_TOUCH)
	retry.name = "RetryButton"
	retry.pressed.connect(retry_pressed.emit)
	column.add_child(retry)


func _count_reward(total: int, delay: float) -> void:
	if _count_tween != null and _count_tween.is_valid():
		_count_tween.kill()
	_count_tween = create_tween()
	_count_tween.tween_interval(delay)
	_count_tween.tween_callback(AudioService.play.bind(COIN_SOUND))
	_count_tween.tween_method(_set_reward_shown, _reward_shown, float(total), COUNT_SECONDS)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _set_reward_shown(value: float) -> void:
	_reward_shown = value
	_reward_label.text = UiStrings.REWARD_FORMAT % roundi(value)
