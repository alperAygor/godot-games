class_name ResultSheet
extends Sheet

## Kazanma ve kaybetme sayfası. `game.gd` yalnız `ResultSheet.win(...)` / `.lose(...)` çağırır
## ve sinyallere bağlanır; ödül/reklam mantığı burada değildir (yalnız gösterir).
## Kazanma: katlanmış çamaşır yığını, sayarak artan ödül, ikincil "2×", büyük "Devam".
## Kaybetme: "Fırtına çıktı", kalan çamaşır (azsa vurgulu), birincil "+1 askı", ikincil "Tekrar dene".

signal continue_pressed
signal double_pressed
signal revive_pressed
signal coins_pressed
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
## Ustalık (yıldız) bölümü.
const PERFECT_COLOR: Color = Color("e0a526")
const STAR_SIZE: float = 92.0
const STAR_GAP: float = 30.0
const STAR_TIP_ROUND: float = 7.0
const STAR_INNER_RATIO: float = 0.5
const STAR_FIRST_DELAY: float = 0.7
const STAR_STEP_SECONDS: float = 0.34
const STAR_POP_SCALE: float = 1.22
const STAR_POP_START_SCALE: float = 0.55
const STAR_POP_IN_SECONDS: float = 0.16
const STAR_POP_OUT_SECONDS: float = 0.34
const STAR_SOUND: String = "sparkle"
const STAR_SOUND_PITCH: float = 0.92
const STAR_SOUND_PITCH_STEP: float = 0.1
const STAR_SOUND_DB: float = -7.0
const BREAKDOWN_SIZE: int = 36
const BREAKDOWN_ICON: float = 36.0
const BREAKDOWN_GAP: int = 28
## Kusursuzda yumuşak "katlanmış kumaş" konfetisi.
const CONFETTI_COUNT: int = 30
const CONFETTI_LIFETIME: float = 3.4
const CONFETTI_PIECE: Vector2i = Vector2i(16, 10)
const CONFETTI_FOLD_SHADE: float = 0.86
const CONFETTI_SPEED_MIN: float = 40.0
const CONFETTI_SPEED_MAX: float = 140.0
const CONFETTI_GRAVITY: float = 110.0
const CONFETTI_SPIN: float = 140.0
const CONFETTI_SCALE_MIN: float = 0.6
const CONFETTI_SCALE_MAX: float = 1.1
const CONFETTI_SPREAD: float = 28.0
const CONFETTI_HALF_WIDTH_RATIO: float = 0.42
const CONFETTI_EXPLOSIVENESS: float = 0.55

var _reward_label: Label = null
var _reward_shown: float = 0.0
var _double_button: Button = null
var _count_tween: Tween = null
var _breakdown: Control = null
var _stars: Array[StarMark] = []
var _confetti: CPUParticles2D = null


## Tek bir yıldız: düz, çizgisiz, uçları yuvarlak. `fill` 0 = sönük, 1 = altın.
class StarMark extends Control:
	var _points: PackedVector2Array = PackedVector2Array()
	var _fill: float = 0.0

	func setup(diameter: float) -> void:
		custom_minimum_size = Vector2(diameter, diameter)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		pivot_offset = Vector2(diameter, diameter) * 0.5
		var raw: PackedVector2Array = PackedVector2Array()
		var outer: float = diameter * 0.5 - ResultSheet.STAR_TIP_ROUND
		# Yuvarlama için çokgen önce içe, sonra dışa ofsetlenir: uçlar yumuşar.
		for index: int in range(10):
			var radius: float = outer if index % 2 == 0 else outer * ResultSheet.STAR_INNER_RATIO
			var angle: float = -PI * 0.5 + PI * 0.2 * float(index)
			raw.append(Vector2(cos(angle), sin(angle)) * radius)
		var shrunk: Array[PackedVector2Array] = Geometry2D.offset_polygon(raw, -ResultSheet.STAR_TIP_ROUND * 0.4)
		var rounded: Array[PackedVector2Array] = Geometry2D.offset_polygon(
			shrunk[0], ResultSheet.STAR_TIP_ROUND * 1.4, Geometry2D.JOIN_ROUND)
		_points = rounded[0]
		for index: int in range(_points.size()):
			_points[index] += Vector2(diameter, diameter) * 0.5

	func set_fill(value: float) -> void:
		_fill = value
		queue_redraw()

	func _draw() -> void:
		if _points.size() >= 3:
			draw_colored_polygon(_points, UiKit.DISC_OFF.lerp(UiKit.GOLD, _fill))


## Kazanma sayfası. `tints`: seviyenin renkleri (yığın bunlarla boyanır).
## `mastery`: `EcoFlow.on_win` sonucu ({"rating","base_coins","perfect_bonus","chain_bonus"...});
## boşsa yıldız/döküm bölümü çizilmez (eski çağrı uyumu). `reward` her durumda ÖDENEN toplamdır.
static func win(parent: Node, reward: int, tints: Array[Color], can_double: bool,
		mastery: Dictionary = {}) -> ResultSheet:
	var sheet: ResultSheet = ResultSheet.new()
	sheet.build(parent, false)
	sheet._fill_win(reward, tints, can_double, mastery)
	sheet.play_intro()
	return sheet


## Kaybetme sayfası. `can_revive` false ise (seviyede zaten kullanıldı) "Tekrar dene" birincil olur.
## `moves_out`: kayıp nedeni hamle sınırı (başlık ve devam düğmesi buna göre yazılır).
## `coin_cost` > 0 ise "jetonla devam" seçeneği de gösterilir (`can_afford` değilse sönük).
static func lose(parent: Node, remaining: int, can_revive: bool, moves_out: bool = false,
		coin_cost: int = 0, can_afford: bool = false) -> ResultSheet:
	var sheet: ResultSheet = ResultSheet.new()
	sheet.build(parent, false)
	sheet._fill_lose(remaining, can_revive, moves_out, coin_cost, can_afford)
	sheet.play_intro()
	return sheet


## "2×" sonrası: ödül toplamına yumuşakça sayar ve ikinci düğmeyi kaldırır.
func show_doubled(total: int) -> void:
	if _double_button != null:
		_double_button.visible = false
	# Döküm artık toplamla uyuşmaz (x2): kalabalık olmasın diye gizlenir.
	if _breakdown != null:
		_breakdown.visible = false
	_count_reward(total, 0.0)


func _fill_win(reward: int, tints: Array[Color], can_double: bool, mastery: Dictionary) -> void:
	var rating: int = clampi(int(mastery.get("rating", 0)), 0, ProgressData.MAX_RATING)
	var perfect: bool = rating >= StarRating.MAX_STARS
	var column: VBoxContainer = content()
	var pile: UiFoldedPile = UiFoldedPile.new()
	pile.setup(tints)
	column.add_child(pile)
	pile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pile.play(Motion.OVERLAY_FADE_SECONDS)
	column.add_child(UiKit.spacer(BLOCK_GAP * 1.6))
	if rating > 0:
		column.add_child(_star_row(rating))
		column.add_child(UiKit.spacer(BLOCK_GAP * 0.5))
	column.add_child(UiKit.label(UiStrings.perfect_title() if perfect else UiStrings.win_title(), TITLE_SIZE,
		PERFECT_COLOR if perfect else UiKit.TEXT))
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
	# Yalnız temel ödül varsa döküm toplamı tekrarlardı: ek kalem yoksa satır hiç çizilmez.
	if int(mastery.get("perfect_bonus", 0)) + int(mastery.get("chain_bonus", 0)) > 0:
		_breakdown = _breakdown_row(int(mastery.get("base_coins", reward)),
			int(mastery.get("perfect_bonus", 0)), int(mastery.get("chain_bonus", 0)))
		column.add_child(UiKit.spacer(BLOCK_GAP * 0.5))
		column.add_child(_breakdown)
	column.add_child(UiKit.spacer(BLOCK_GAP + 8.0))
	if can_double:
		_double_button = UiKit.button(UiStrings.WIN_DOUBLE, &"SecondaryButton", "lucide/video", UiKit.MIN_TOUCH)
		_double_button.custom_minimum_size.x = DOUBLE_WIDTH
		_double_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_double_button.pressed.connect(double_pressed.emit)
		column.add_child(_double_button)
		# Reklam düğmesi ile "Devam" arasında en az 42 px (16 dp) boşluk: yanlışlıkla basılmasın.
		column.add_child(UiKit.spacer(UiKit.AD_BUTTON_GAP))
	var next: Button = UiKit.button(UiStrings.win_continue(), &"", "", MAIN_HEIGHT)
	next.pressed.connect(continue_pressed.emit)
	column.add_child(next)
	if rating > 0:
		_play_stars(rating)
	if perfect:
		_play_confetti(tints)


## Yıldız sırası: doldurulacaklar altın, kalanlar sönük kalır.
func _star_row(rating: int) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(STAR_GAP))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stars.clear()
	for _index: int in range(StarRating.MAX_STARS):
		var mark: StarMark = StarMark.new()
		mark.setup(STAR_SIZE)
		row.add_child(mark)
		_stars.append(mark)
	return row


## Dökümde yalnız sıfırdan büyük kalemler: [jeton] temel  [yıldız] kusursuz  [şimşek] zincir.
func _breakdown_row(base: int, perfect: int, chain: int) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", BREAKDOWN_GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var entries: Array[Array] = [["lucide/coins", UiKit.GOLD, base], ["lucide/star", PERFECT_COLOR, perfect],
		["lucide/zap", UiKit.FLAME, chain]]
	for entry: Array in entries:
		var amount: int = int(entry[2])
		if amount <= 0:
			continue
		var pair: HBoxContainer = HBoxContainer.new()
		pair.add_theme_constant_override("separation", 8)
		pair.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon: TextureRect = UiKit.tinted_icon(String(entry[0]), BREAKDOWN_ICON, entry[1] as Color)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pair.add_child(icon)
		pair.add_child(UiKit.label(UiStrings.REWARD_FORMAT % amount, BREAKDOWN_SIZE, UiKit.TEXT_MUTED))
		row.add_child(pair)
	return row


## Yıldızlar tek tek dolar: yumuşak büyüme + `sparkle` sesi (perde her yıldızda biraz yükselir).
func _play_stars(rating: int) -> void:
	for index: int in range(mini(rating, _stars.size())):
		var mark: StarMark = _stars[index]
		mark.scale = Vector2.ONE * STAR_POP_START_SCALE
		var tween: Tween = create_tween()
		tween.tween_interval(STAR_FIRST_DELAY + STAR_STEP_SECONDS * float(index))
		tween.tween_callback(AudioService.play_pitched.bind(STAR_SOUND,
			STAR_SOUND_PITCH + STAR_SOUND_PITCH_STEP * float(index), STAR_SOUND_DB))
		tween.set_parallel(true)
		tween.tween_method(mark.set_fill, 0.0, 1.0, STAR_POP_IN_SECONDS + STAR_POP_OUT_SECONDS)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(mark, "scale", Vector2.ONE * STAR_POP_SCALE, STAR_POP_IN_SECONDS)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.chain().tween_property(mark, "scale", Vector2.ONE, STAR_POP_OUT_SECONDS)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Kusursuz: son yıldızdan sonra kartın üstünden yavaşça süzülen küçük, katlı kumaş parçaları.
func _play_confetti(tints: Array[Color]) -> void:
	var piece: Image = Image.create(CONFETTI_PIECE.x, CONFETTI_PIECE.y, false, Image.FORMAT_RGBA8)
	piece.fill(Color.WHITE)
	# Alt yarı biraz koyu: tek parçada "katlanmış" izlenimi, çizgi/kenarlık yok.
	piece.fill_rect(Rect2i(0, CONFETTI_PIECE.y / 2, CONFETTI_PIECE.x, CONFETTI_PIECE.y - CONFETTI_PIECE.y / 2),
		Color(CONFETTI_FOLD_SHADE, CONFETTI_FOLD_SHADE, CONFETTI_FOLD_SHADE))
	var palette: Gradient = Gradient.new()
	palette.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var colors: PackedColorArray = PackedColorArray()
	var offsets: PackedFloat32Array = PackedFloat32Array()
	var count: int = maxi(tints.size(), 1)
	for index: int in range(count):
		colors.append(tints[index] if not tints.is_empty() else UiKit.ACCENT)
		offsets.append(float(index) / float(count))
	palette.offsets = offsets
	palette.colors = colors
	var fade: Gradient = Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	fade.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1.0, 1.0, 1.0, 0.0)])
	_confetti = CPUParticles2D.new()
	_confetti.texture = ImageTexture.create_from_image(piece)
	_confetti.one_shot = true
	_confetti.emitting = false
	_confetti.amount = CONFETTI_COUNT
	_confetti.lifetime = CONFETTI_LIFETIME
	_confetti.explosiveness = CONFETTI_EXPLOSIVENESS
	_confetti.direction = Vector2.DOWN
	_confetti.spread = CONFETTI_SPREAD
	_confetti.gravity = Vector2(0.0, CONFETTI_GRAVITY)
	_confetti.initial_velocity_min = CONFETTI_SPEED_MIN
	_confetti.initial_velocity_max = CONFETTI_SPEED_MAX
	_confetti.angular_velocity_min = -CONFETTI_SPIN
	_confetti.angular_velocity_max = CONFETTI_SPIN
	_confetti.scale_amount_min = CONFETTI_SCALE_MIN
	_confetti.scale_amount_max = CONFETTI_SCALE_MAX
	_confetti.color_initial_ramp = palette
	_confetti.color_ramp = fade
	_confetti.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_confetti.emission_rect_extents = Vector2(1.0, 1.0)
	add_child(_confetti)
	var timer: Tween = create_tween()
	timer.tween_interval(STAR_FIRST_DELAY + STAR_STEP_SECONDS * float(StarRating.MAX_STARS - 1))
	timer.tween_callback(_start_confetti)


func _start_confetti() -> void:
	# Kart yerleşimi bitmiş olur; konum kartın üst kenarının ortasıdır.
	var card_rect: Rect2 = card().get_global_rect()
	_confetti.global_position = Vector2(card_rect.get_center().x, card_rect.position.y)
	_confetti.emission_rect_extents = Vector2(card_rect.size.x * CONFETTI_HALF_WIDTH_RATIO, 1.0)
	_confetti.emitting = true


func _fill_lose(remaining: int, can_revive: bool, moves_out: bool = false, coin_cost: int = 0,
		can_afford: bool = false) -> void:
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
	column.add_child(UiKit.label(UiStrings.lose_title_moves() if moves_out else UiStrings.lose_title(), TITLE_SIZE))
	column.add_child(UiKit.spacer(BLOCK_GAP * 0.5))
	column.add_child(_remaining_label(remaining))
	column.add_child(UiKit.spacer(BLOCK_GAP * 2.0))
	if can_revive:
		var revive: Button = UiKit.button(UiStrings.lose_revive_moves() if moves_out else UiStrings.lose_revive(),
			&"", "lucide/video", MAIN_HEIGHT)
		revive.pressed.connect(revive_pressed.emit)
		column.add_child(revive)
		column.add_child(UiKit.spacer(UiKit.AD_BUTTON_GAP))
	if coin_cost > 0:
		# Reklam izlemek istemeyen oyuncu jetonla devam edebilir; yetmiyorsa düğme sönük kalır.
		var pay: Button = UiKit.button(UiStrings.lose_coins(coin_cost), &"SecondaryButton", "lucide/coins",
			UiKit.MIN_TOUCH)
		pay.disabled = not can_afford
		pay.pressed.connect(coins_pressed.emit)
		column.add_child(pay)
		column.add_child(UiKit.spacer(UiKit.AD_BUTTON_GAP))
	var retry: Button = UiKit.button(UiStrings.lose_retry(), &"SecondaryButton" if can_revive else &"",
		"lucide/rotate-ccw", MAIN_HEIGHT if not can_revive else UiKit.MIN_TOUCH)
	retry.pressed.connect(retry_pressed.emit)
	column.add_child(retry)


## Kalan sayısı azsa ("Sadece 4 çamaşır kaldı") sayı büyük ve mercan renginde vurgulanır:
## oyuncu "neredeyse bitirdim" hissiyle tekrar denemeye itilir.
func _remaining_label(remaining: int) -> RichTextLabel:
	var few: bool = remaining <= FEW_REMAINING
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
	rich.text = "[center]%s[/center]" % UiStrings.remaining_sentence(number, remaining, few)
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
