class_name DailyCalendar
extends Sheet

## 7 günlük giriş takvimi sayfası: 7 küçük karo (alındı / bugün / yaklaşan) ve "Al" düğmesi.
## Mantık `DailyCalendarLogic`te, kayıt `DailyStore`da; burası yalnız gösterir ve canlandırır.
## Alma animasyonu: karo yumuşakça zıplar, altın kıvılcım saçılır, ödül yukarı süzülür,
## karo "alındı" görünümüne geçer. Süreler `Motion`dan.

const SCENE_PATH: String = "res://scenes/daily/DailyCalendar.tscn"
const TITLE_SIZE: int = 48
const GAP: float = 28.0
const TILE_GAP: int = 10
const TILE_HEIGHT: float = 176.0
const TILE_MIN_WIDTH: float = 96.0
const TILE_RADIUS: int = 30
const TILE_ICON: float = 48.0
const DAY_FONT: int = 28
const AMOUNT_FONT: int = 30
const CLAIM_HEIGHT: float = 132.0
const TODAY_SCALE: float = 1.04
const POP_SCALE: float = 1.18
const CHECK_ICON: String = "lucide/check"
const COIN_ICON: String = "lucide/coins"
const GIFT_ICON: String = "lucide/package"
const FINAL_ICON: String = "lucide/trophy"
const RISE_DISTANCE: float = 110.0
const RISE_SECONDS: float = 1.1
const RISE_FONT: int = 52
const SPARK_COLOR: Color = Color(1.0, 0.93, 0.62)
const SPARK_SPEED_MIN: float = 120.0
const SPARK_SPEED_MAX: float = 320.0
const SPARK_GRAVITY: float = 220.0
const SPARK_SCALE_MIN: float = 0.05
const SPARK_SCALE_MAX: float = 0.14
const SPARK_HEIGHT_OFFSET: float = -10.0
const COIN_SOUND_VOLUME_DB: float = -4.0
const FINAL_SOUND_VOLUME_DB: float = -3.0

var _today: String = ""
var _tiles: Array[Panel] = []
var _icons: Array[TextureRect] = []
var _footer: VBoxContainer = null
var _claim_button: Button = null
var _busy: bool = false


## `today_override`: yalnız araçlar/testler içindir (boşsa yerel tarih).
static func open(parent: Node, today_override: String = "") -> DailyCalendar:
	var sheet: DailyCalendar = (load(SCENE_PATH) as PackedScene).instantiate() as DailyCalendar
	sheet._today = today_override if not today_override.is_empty() else DailyDate.today_key()
	sheet.build(parent, false)
	sheet.dismiss_on_dim = true
	sheet._fill()
	sheet.play_intro()
	return sheet


func _fill() -> void:
	var column: VBoxContainer = content()
	column.add_child(UiKit.label(DailyStrings.CALENDAR_TITLE, TITLE_SIZE))
	column.add_child(UiKit.spacer(GAP))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", TILE_GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)
	var states: Array[int] = DailyCalendarLogic.tile_states(DailyStore.calendar_state(), _today)
	for index: int in range(states.size()):
		row.add_child(_make_tile(index + 1, states[index]))
	column.add_child(UiKit.spacer(GAP * 1.6))
	_footer = VBoxContainer.new()
	_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_footer)
	_build_footer()


func _build_footer() -> void:
	for child: Node in _footer.get_children():
		child.queue_free()
	_claim_button = null
	if DailyCalendarLogic.can_claim_today(DailyStore.calendar_state(), _today):
		_claim_button = UiKit.button(DailyStrings.CLAIM, &"", COIN_ICON, CLAIM_HEIGHT)
		_claim_button.pressed.connect(_on_claim)
		_footer.add_child(_claim_button)
	else:
		var done: Button = UiKit.button(DailyStrings.CLAIMED_TODAY, &"SecondaryButton", CHECK_ICON, CLAIM_HEIGHT)
		done.pressed.connect(close)
		_footer.add_child(done)


func _make_tile(day: int, state: int) -> Panel:
	var tile: Panel = Panel.new()
	tile.custom_minimum_size = Vector2(TILE_MIN_WIDTH, TILE_HEIGHT)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var reward: Dictionary = DailyCalendarLogic.reward_for_day(day)
	var inner: VBoxContainer = VBoxContainer.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 10)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(inner)
	inner.add_child(UiKit.label(DailyStrings.CALENDAR_DAY_FORMAT % day, DAY_FONT, UiKit.TEXT_MUTED))
	var icon: TextureRect = UiKit.tinted_icon(_reward_icon(day, reward), TILE_ICON, UiKit.TEXT_MUTED)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner.add_child(icon)
	inner.add_child(UiKit.label(str(int(reward["coins"])), AMOUNT_FONT, UiKit.TEXT_MUTED))
	_tiles.append(tile)
	_icons.append(icon)
	_apply_state(day - 1, state)
	return tile


func _reward_icon(day: int, reward: Dictionary) -> String:
	if day == DailyCalendarLogic.day_count():
		return FINAL_ICON
	return GIFT_ICON if not String(reward["booster"]).is_empty() else COIN_ICON


## Karoyu duruma göre boyar: alındı (yeşil + onay), bugün (sıcak altın, hafif büyük), yaklaşan (sönük).
func _apply_state(index: int, state: int) -> void:
	var tile: Panel = _tiles[index]
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.set_corner_radius_all(TILE_RADIUS)
	box.anti_aliasing = true
	var icon: TextureRect = _icons[index]
	var reward: Dictionary = DailyCalendarLogic.reward_for_day(index + 1)
	tile.pivot_offset = Vector2(tile.custom_minimum_size.x * 0.5, TILE_HEIGHT * 0.5)
	tile.scale = Vector2.ONE
	match state:
		DailyCalendarLogic.TILE_CLAIMED:
			box.bg_color = UiKit.ACCENT_SOFT
			icon.texture = Icons.texture(CHECK_ICON)
			icon.modulate = UiKit.ACCENT
		DailyCalendarLogic.TILE_TODAY:
			box.bg_color = DailyUi.WARM_SOFT
			icon.texture = Icons.texture(_reward_icon(index + 1, reward))
			icon.modulate = UiKit.GOLD
			tile.scale = Vector2.ONE * TODAY_SCALE
		_:
			box.bg_color = UiKit.DISC_OFF
			icon.texture = Icons.texture(_reward_icon(index + 1, reward))
			icon.modulate = UiKit.TEXT_MUTED
	tile.add_theme_stylebox_override("panel", box)


func _on_claim() -> void:
	if _busy:
		return
	var result: Dictionary = DailyStore.claim_calendar(_today)
	if not bool(result["ok"]):
		return
	_busy = true
	_claim_button.disabled = true
	var day: int = int(result["day"])
	var reward: Dictionary = result["reward"] as Dictionary
	var final_day: bool = day == DailyCalendarLogic.day_count()
	AudioService.play_pitched("win" if final_day else "coin", 1.0,
		FINAL_SOUND_VOLUME_DB if final_day else COIN_SOUND_VOLUME_DB)
	_play_claim(day - 1, reward)


func _play_claim(index: int, reward: Dictionary) -> void:
	var tile: Panel = _tiles[index]
	var pop: Tween = create_tween()
	pop.tween_property(tile, "scale", Vector2.ONE * POP_SCALE, Motion.LAND_SQUASH_SECONDS * 1.6)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	pop.tween_callback(_swap_to_claimed.bind(index))
	pop.tween_property(tile, "scale", Vector2.ONE, Motion.LAND_SETTLE_SECONDS * 1.4)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_interval(Motion.OVERLAY_FADE_SECONDS)
	pop.tween_callback(_finish_claim)
	_sparkle(tile)
	_float_reward(tile, reward)


func _swap_to_claimed(index: int) -> void:
	_apply_state(index, DailyCalendarLogic.TILE_CLAIMED)
	_tiles[index].scale = Vector2.ONE * POP_SCALE
	var icon: TextureRect = _icons[index]
	icon.modulate.a = 0.0
	create_tween().tween_property(icon, "modulate:a", 1.0, Motion.OVERLAY_FADE_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _finish_claim() -> void:
	_busy = false
	_build_footer()


## Yumuşak, birkaç altın nokta: tek atımlık parçacık patlaması (havuz gerekmez, sayfa kısa ömürlü).
func _sparkle(tile: Panel) -> void:
	var ramp: Gradient = Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	ramp.colors = PackedColorArray([Color.WHITE, Color(1.0, 1.0, 1.0, 0.7), Color(1.0, 1.0, 1.0, 0.0)])
	var burst: CPUParticles2D = CPUParticles2D.new()
	burst.one_shot = true
	burst.emitting = false
	burst.explosiveness = 0.92
	burst.amount = Motion.SPARKLE_COUNT * 2
	burst.lifetime = Motion.SPARKLE_LIFETIME
	burst.texture = GlowTextures.dot()
	burst.color = SPARK_COLOR
	burst.color_ramp = ramp
	burst.direction = Vector2.UP
	burst.spread = 120.0
	burst.gravity = Vector2(0.0, SPARK_GRAVITY)
	burst.initial_velocity_min = SPARK_SPEED_MIN
	burst.initial_velocity_max = SPARK_SPEED_MAX
	burst.scale_amount_min = SPARK_SCALE_MIN
	burst.scale_amount_max = SPARK_SCALE_MAX
	burst.position = Vector2(tile.size.x * 0.5, tile.size.y * 0.5 + SPARK_HEIGHT_OFFSET)
	burst.z_index = 1
	tile.add_child(burst)
	burst.emitting = true


func _float_reward(tile: Panel, reward: Dictionary) -> void:
	var text: String = DailyStrings.REWARD_FORMAT % int(reward["coins"])
	var label: Label = UiKit.label(text, RISE_FONT, UiKit.GOLD)
	label.z_index = 2
	tile.add_child(label)
	label.position = Vector2((tile.size.x - label.get_minimum_size().x) * 0.5, -label.get_minimum_size().y)
	var rise: Tween = create_tween().set_parallel(true)
	rise.tween_property(label, "position:y", label.position.y - RISE_DISTANCE, RISE_SECONDS)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	rise.tween_property(label, "modulate:a", 0.0, RISE_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	rise.chain().tween_callback(label.queue_free)
