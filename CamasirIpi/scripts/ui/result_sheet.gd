class_name ResultSheet
extends Sheet

## Kazanma ve kaybetme sayfası. `game.gd` yalnız `ResultSheet.win(...)` / `.lose(...)` çağırır
## ve sinyallere bağlanır; ödül/reklam mantığı burada değildir (yalnız gösterir).
## Kazanma: katlanmış çamaşır yığını, sayarak artan ödül, ikincil "2×", büyük "Devam".
## Kaybetme: "Fırtına çıktı", kalan çamaşır (azsa vurgulu), birincil "+1 askı", ikincil "Tekrar dene".

signal continue_pressed
signal double_pressed
signal revive_pressed
signal retry_pressed

const TITLE_SIZE: int = 56
const REWARD_SIZE: int = 84
const REWARD_ICON: float = 56.0
const REMAINING_SIZE: int = 36
const REMAINING_BIG_SIZE: int = 92
const MAIN_HEIGHT: float = 132.0
const DOUBLE_WIDTH: float = 300.0
const BLOCK_GAP: float = 24.0
const COUNT_DELAY: float = 0.5
const COUNT_SECONDS: float = 0.9
## "Sadece N çamaşır kaldı" vurgusu bu sayıya ve altına inince açılır.
const FEW_REMAINING: int = 6
const STORM_DISC: float = 112.0
const STORM_ICON: float = 56.0

var _reward_label: Label = null
var _reward_shown: float = 0.0
var _double_button: Button = null
var _count_tween: Tween = null


## Kazanma sayfası. `tints`: seviyenin renkleri (yığın bunlarla boyanır).
static func win(parent: Node, reward: int, tints: Array[Color], can_double: bool) -> ResultSheet:
	var sheet: ResultSheet = ResultSheet.new()
	sheet.build(parent, false)
	sheet._fill_win(reward, tints, can_double)
	sheet.play_intro()
	return sheet


## Kaybetme sayfası. `can_revive` false ise (seviyede zaten kullanıldı) "Tekrar dene" birincil olur.
static func lose(parent: Node, remaining: int, can_revive: bool) -> ResultSheet:
	var sheet: ResultSheet = ResultSheet.new()
	sheet.build(parent, false)
	sheet._fill_lose(remaining, can_revive)
	sheet.play_intro()
	return sheet


## "2×" sonrası: ödül toplamına yumuşakça sayar ve ikinci düğmeyi kaldırır.
func show_doubled(total: int) -> void:
	if _double_button != null:
		_double_button.visible = false
	_count_reward(total, 0.0)


func _fill_win(reward: int, tints: Array[Color], can_double: bool) -> void:
	var column: VBoxContainer = content()
	var pile: UiFoldedPile = UiFoldedPile.new()
	pile.setup(tints)
	column.add_child(pile)
	pile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pile.play(Motion.OVERLAY_FADE_SECONDS)
	column.add_child(UiKit.spacer(BLOCK_GAP))
	column.add_child(UiKit.label(UiStrings.WIN_TITLE, TITLE_SIZE))
	column.add_child(UiKit.spacer(BLOCK_GAP * 0.5))
	var reward_row: HBoxContainer = HBoxContainer.new()
	reward_row.alignment = BoxContainer.ALIGNMENT_CENTER
	reward_row.add_theme_constant_override("separation", 16)
	reward_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(reward_row)
	var coin: TextureRect = UiKit.tinted_icon("lucide/coins", REWARD_ICON, UiKit.GOLD)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reward_row.add_child(coin)
	_reward_label = UiKit.label(UiStrings.REWARD_FORMAT % 0, REWARD_SIZE)
	reward_row.add_child(_reward_label)
	_count_reward(reward, COUNT_DELAY)
	column.add_child(UiKit.spacer(BLOCK_GAP + 8.0))
	if can_double:
		_double_button = UiKit.button(UiStrings.WIN_DOUBLE, &"SecondaryButton", "lucide/video", UiKit.MIN_TOUCH)
		_double_button.custom_minimum_size.x = DOUBLE_WIDTH
		_double_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_double_button.pressed.connect(double_pressed.emit)
		column.add_child(_double_button)
		# Reklam düğmesi ile "Devam" arasında en az 42 px (16 dp) boşluk: yanlışlıkla basılmasın.
		column.add_child(UiKit.spacer(UiKit.AD_BUTTON_GAP))
	var next: Button = UiKit.button(UiStrings.WIN_CONTINUE, &"", "", MAIN_HEIGHT)
	next.pressed.connect(continue_pressed.emit)
	column.add_child(next)


func _fill_lose(remaining: int, can_revive: bool) -> void:
	var column: VBoxContainer = content()
	var storm: CenterContainer = CenterContainer.new()
	storm.custom_minimum_size = Vector2(0.0, STORM_DISC)
	storm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var disc: Panel = Panel.new()
	var disc_box: StyleBoxFlat = StyleBoxFlat.new()
	disc_box.bg_color = UiKit.ACCENT_SOFT
	disc_box.set_corner_radius_all(int(STORM_DISC * 0.5))
	disc_box.anti_aliasing = true
	disc.add_theme_stylebox_override("panel", disc_box)
	disc.custom_minimum_size = Vector2(STORM_DISC, STORM_DISC)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	storm.add_child(disc)
	var wind: TextureRect = UiKit.tinted_icon("lucide/wind", STORM_ICON, UiKit.TEXT_MUTED)
	wind.position = Vector2((STORM_DISC - STORM_ICON) * 0.5, (STORM_DISC - STORM_ICON) * 0.5)
	disc.add_child(wind)
	column.add_child(storm)
	column.add_child(UiKit.spacer(BLOCK_GAP))
	column.add_child(UiKit.label(UiStrings.LOSE_TITLE, TITLE_SIZE))
	column.add_child(UiKit.spacer(BLOCK_GAP * 0.5))
	column.add_child(_remaining_label(remaining))
	column.add_child(UiKit.spacer(BLOCK_GAP * 2.0))
	if can_revive:
		var revive: Button = UiKit.button(UiStrings.LOSE_REVIVE, &"", "lucide/video", MAIN_HEIGHT)
		revive.pressed.connect(revive_pressed.emit)
		column.add_child(revive)
		column.add_child(UiKit.spacer(UiKit.AD_BUTTON_GAP))
	var retry: Button = UiKit.button(UiStrings.LOSE_RETRY, &"SecondaryButton" if can_revive else &"",
		"lucide/rotate-ccw", MAIN_HEIGHT if not can_revive else UiKit.MIN_TOUCH)
	retry.pressed.connect(retry_pressed.emit)
	column.add_child(retry)


## Kalan sayısı azsa ("Sadece 4 çamaşır kaldı") sayı büyük ve mercan renginde vurgulanır:
## oyuncu "neredeyse bitirdim" hissiyle tekrar denemeye itilir.
func _remaining_label(remaining: int) -> RichTextLabel:
	var few: bool = remaining <= FEW_REMAINING
	var text: String = UiStrings.LOSE_REMAINING_SUFFIX
	var rich: RichTextLabel = RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.scroll_active = false
	rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rich.add_theme_font_size_override("normal_font_size", REMAINING_SIZE)
	rich.add_theme_color_override("default_color", UiKit.TEXT_MUTED)
	var number: String = "[font_size=%d][color=#%s]%d[/color][/font_size]" % [
		REMAINING_BIG_SIZE if few else REMAINING_SIZE + 12,
		(UiKit.DANGER if few else UiKit.TEXT).to_html(false), remaining]
	var prefix: String = (UiStrings.LOSE_FEW_PREFIX + " ") if few else ""
	rich.text = "[center]%s%s %s[/center]" % [prefix, number, text]
	return rich


func _count_reward(total: int, delay: float) -> void:
	if _count_tween != null and _count_tween.is_valid():
		_count_tween.kill()
	_count_tween = create_tween()
	_count_tween.tween_interval(delay)
	_count_tween.tween_method(_set_reward_shown, _reward_shown, float(total), COUNT_SECONDS)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _set_reward_shown(value: float) -> void:
	_reward_shown = value
	_reward_label.text = UiStrings.REWARD_FORMAT % roundi(value)
