class_name ResultSheet
extends Sheet

## Kazanma ve kaybetme sayfası. Game yalnız `ResultSheet.win(...)` / `.lose(...)` çağırır ve
## sinyallere bağlanır; ödül/reklam mantığı burada değildir (yalnız gösterir).
## Kazanma: kupa diski, başlık, yıldız noktaları, jeton ödülü (jeton SİMGELERİ, rakam yok), ikincil
## "İkiye katla" (ödüllü reklam), büyük "Devam".
## Kaybetme: sakin disk, başlık, birincil "Bir hak daha" (YALNIZ ödüllü reklam), ikincil "Tekrar dene".
## Priz kuralı: bu sayfada hiçbir rakam görünmez.

signal continue_pressed
signal double_pressed
signal revive_pressed
signal retry_pressed

const TITLE_SIZE: int = UiKit.TITLE_SIZE
const MAIN_HEIGHT: float = UiKit.HEIGHT_PRIMARY
const DOUBLE_WIDTH: float = 460.0
const STARS_GAP: float = UiKit.SPACE_MD
const BLOCK_GAP: float = UiKit.SPACE_LG
const COUNT_DELAY: float = 0.5
const WIN_SOUND: String = "win"
const COIN_SOUND: String = "coin"

var _reward_chip: UiChip = null
var _double_button: Button = null


## Kazanma sayfası. `reward` ÖDENEN jetondur; `can_double` ödüllü reklam sunulabiliyorsa true.
static func win(parent: Node, reward: int, can_double: bool, stars: int = 0) -> ResultSheet:
	var sheet: ResultSheet = ResultSheet.new()
	sheet.build(parent, false)
	sheet._fill_win(reward, can_double, stars)
	sheet.play_intro()
	return sheet


## Kaybetme sayfası. `can_revive` false ise (bu turda kullanıldı / reklam yok) "Tekrar dene" birincil olur.
static func lose(parent: Node, can_revive: bool) -> ResultSheet:
	var sheet: ResultSheet = ResultSheet.new()
	sheet.build(parent, false)
	sheet._fill_lose(can_revive)
	sheet.play_intro()
	return sheet


## "İkiye katla" sonrası: ödül simgeleri çoğalır ve ikinci düğme kalkar.
func show_doubled(total: int) -> void:
	if _double_button != null:
		_double_button.visible = false
	_show_reward(total, 0.0)


## Ödül sırasındaki jeton simgesi sayısı (testler/problar için).
func reward_icons() -> int:
	return _reward_chip.icon_count() if _reward_chip != null else 0


func _fill_win(reward: int, can_double: bool, stars: int) -> void:
	var column: VBoxContainer = content()
	column.add_child(UiKit.centered_disc("lucide/trophy", UiKit.COIN_SOFT, UiKit.GOLD))
	column.add_child(UiKit.spacer(BLOCK_GAP))
	column.add_child(UiKit.label(UiStrings.win_title(), TITLE_SIZE))
	column.add_child(UiKit.spacer(STARS_GAP))
	var star_row: UiPips = UiPips.new()
	star_row.name = "StarPips"
	star_row.color = UiKit.STAR
	star_row.set_state(ProgressData.MAX_STARS, stars)
	column.add_child(star_row)
	column.add_child(UiKit.spacer(UiKit.SPACE_SM))
	var reward_row: CenterContainer = CenterContainer.new()
	reward_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(reward_row)
	_reward_chip = UiChip.new()
	_reward_chip.name = "RewardChip"
	_reward_chip.setup("lucide/coins", UiKit.GOLD)
	_reward_chip.set_value(0)
	reward_row.add_child(_reward_chip)
	_show_reward(reward, COUNT_DELAY)
	column.add_child(UiKit.spacer(UiKit.SPACE_XL))
	if can_double:
		_double_button = UiKit.button(UiStrings.win_double(), &"SecondaryButton", "lucide/video", UiKit.MIN_TOUCH)
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
	Haptics.success()


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


## Ödül simgelerini bir süre sonra doldurur (jeton sesiyle); simgeler sırayla "pop" yapar.
func _show_reward(total: int, delay: float) -> void:
	var timer: SceneTreeTimer = get_tree().create_timer(delay, true, false, true)
	timer.timeout.connect(_apply_reward.bind(total))


func _apply_reward(total: int) -> void:
	if not is_inside_tree() or _reward_chip == null:
		return
	AudioService.play(COIN_SOUND)
	_reward_chip.set_value(total)
