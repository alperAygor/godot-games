class_name TutorialCard
extends CanvasLayer

## Küçük, sakin tanıtım kartı: döngüde mini gösteri + tek kısa satır + "Tamam".
## Gösteri gerçek sprite'larla (GarmentView/BasketView) kurulur; tanınmayan gösteri tipi
## ikon + metne düşer. Kart açıkken girdiyi kendisi yutar (tam ekran Control).

signal dismissed

const CARD_LAYER: int = 40
const PANEL_WIDTH: float = 640.0
const PANEL_RADIUS: int = UiTokens.RADIUS_SHEET
const PANEL_MARGIN: float = UiKit.SPACE_XL + UiKit.SPACE_SM
const PANEL_COLOR: Color = UiKit.SHEET
const DIM_COLOR: Color = UiKit.DIM
const TEXT_COLOR: Color = UiKit.TEXT
const LINE_COLOR: Color = UiKit.TEXT_MUTED
const STAGE_SIZE: Vector2 = Vector2(560.0, 290.0)
const STAGE_COLOR: Color = UiKit.SURFACE_SOFT
const STAGE_RADIUS: int = UiKit.RADIUS_CARD
const ROPE_COLOR: Color = Color("8a6a4a")
const ROPE_Y: float = 34.0
const ROPE_WIDTH: float = 5.0
const GARMENT_SIZE: float = 170.0
const BASKET_SIZE: float = 170.0
const TITLE_FONT: int = UiKit.TYPE_HEADING
const LINE_FONT: int = UiKit.TYPE_CAPTION + 4
const BUTTON_MIN_WIDTH: float = 300.0
const COLUMN_GAP: int = UiTokens.SPACE_LG
const ICON_SIZE: float = 150.0
const ICON_PLATE: float = 210.0
const BADGE_FONT: int = UiKit.TYPE_DISPLAY + 12
const HAND_SCALE: float = 0.62
const HAND_TARGET_RATIO: float = 0.42
const WET_KIND: int = 0
const COVER_KIND: int = 3
const SPARE_KIND: int = 1
const LOOP_PAUSE: float = 0.7
const AFTER_TAP_PAUSE: float = 1.5
const FALLBACK_ICON: String = "lucide/star"
## Gerçek sprite gösterisi (tutorials.json `sprite` / `frames` / `falling` / `typed_kind` / `booster`).
const SPRITE_HEIGHT: float = 230.0
const FRAME_SECONDS: float = 0.9
const SWAY_DEGREES: float = 3.0
const SWAY_SECONDS: float = 1.6
const FALL_DISTANCE: float = 90.0
const FALL_SECONDS: float = 1.1
const FALL_SPREAD: float = 70.0
const FALL_COUNT: int = 3
const FALL_HEIGHT: float = 46.0
const CLOUD_Y_RATIO: float = 0.4
const TYPED_KIND_DEFAULT: int = 1
const BOOSTER_GLYPH: float = 200.0
const DEFAULT_COLORS: Array[Color] = [
	Color("e5484d"), Color("3e8ef7"), Color("f5c02e"), Color("3dbb6e"),
]

var _stage: Control = null
var _hand: TutorialHand = null
var _panel: Control = null
var _root: Control = null
var _colors: Array[Color] = DEFAULT_COLORS
var _alive: bool = true
var _closing: bool = false


## `spec`: tutorials.json kart girdisi. `palette`: oyunun renk dizisi (gösteri aynı renkleri kullanır).
func setup(feature: String, spec: Dictionary, palette: Array[Color]) -> void:
	layer = CARD_LAYER
	if palette.size() >= DEFAULT_COLORS.size():
		_colors = palette
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.modulate.a = 0.0
	add_child(_root)
	var dim: ColorRect = ColorRect.new()
	dim.color = DIM_COLOR
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	# Panel kapsayıcı içinde durur: kapsayıcıyı oynatmak yerleşimi bozmadan yükselme verir.
	var rise: Control = Control.new()
	rise.set_anchors_preset(Control.PRESET_FULL_RECT)
	rise.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(rise)
	var panel: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = PANEL_COLOR
	box.set_corner_radius_all(PANEL_RADIUS)
	box.set_content_margin_all(PANEL_MARGIN)
	box.anti_aliasing = true
	panel.add_theme_stylebox_override("panel", box)
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	rise.add_child(panel)
	_panel = rise
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", COLUMN_GAP)
	panel.add_child(column)
	var title: Label = _label(TutorialStrings.card_title(feature), TITLE_FONT, TEXT_COLOR)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(STAGE_SIZE.x, 0.0)
	column.add_child(title)
	_build_stage(column)
	var line: Label = _label(TutorialStrings.card_line(feature), LINE_FONT, LINE_COLOR)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size = Vector2(STAGE_SIZE.x, 0.0)
	column.add_child(line)
	var holder: CenterContainer = CenterContainer.new()
	holder.add_child(_ok_button())
	column.add_child(holder)
	_open_animation()
	_run_demo(String(spec.get("demo", "icon")), spec)


func _label(text: String, font_size: int, tint: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Tek birincil eylem: ortak düğme (UiKit) — diğer sayfalarla aynı yeşil, boy ve basma hissi.
func _ok_button() -> Button:
	var button: Button = UiKit.button(TutorialStrings.ok_button(), &"", "", UiKit.HEIGHT_COMPACT)
	button.custom_minimum_size.x = BUTTON_MIN_WIDTH
	button.pressed.connect(close)
	return button


func _build_stage(column: VBoxContainer) -> void:
	_stage = Control.new()
	_stage.custom_minimum_size = STAGE_SIZE
	_stage.clip_contents = true
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate: Panel = Panel.new()
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = STAGE_COLOR
	box.set_corner_radius_all(STAGE_RADIUS)
	box.anti_aliasing = true
	plate.add_theme_stylebox_override("panel", box)
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(plate)
	column.add_child(_stage)
	_hand = TutorialHand.new()
	_hand.scale = Vector2.ONE * HAND_SCALE
	_stage.add_child(_hand)


func _open_animation() -> void:
	_panel.position.y = Motion.OVERLAY_RISE_DISTANCE
	var intro: Tween = _root.create_tween().set_parallel(true)
	intro.tween_property(_root, "modulate:a", 1.0, Motion.OVERLAY_FADE_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	intro.tween_property(_panel, "position:y", 0.0, Motion.OVERLAY_RISE_SECONDS)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func close() -> void:
	if _closing:
		return
	_closing = true
	_alive = false
	var outro: Tween = _root.create_tween()
	outro.tween_property(_root, "modulate:a", 0.0, Motion.OVERLAY_FADE_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	outro.tween_callback(_finish)


func _finish() -> void:
	dismissed.emit()
	queue_free()


# --- Gösteriler -----------------------------------------------------------------------------

func _run_demo(kind: String, spec: Dictionary) -> void:
	# Gerçek sprite alanları varsa (veri güdümlü) kind'a bakılmadan onlar gösterilir.
	if spec.has("typed_kind"):
		_demo_typed(int(spec["typed_kind"]))
		return
	if spec.has("booster"):
		_demo_booster(String(spec["booster"]))
		return
	if spec.has("sprite") or spec.has("frames"):
		_demo_sprite(spec)
		return
	match kind:
		"wet":
			_demo_wet()
		"mystery":
			_demo_mystery()
		"lock":
			_demo_lock()
		"badge":
			_demo_badge(String(spec.get("badge", "+1")))
		_:
			_demo_icon(String(spec.get("icon", FALLBACK_ICON)))


func _pause(seconds: float) -> bool:
	if not _alive or not is_inside_tree():
		return false
	await get_tree().create_timer(seconds).timeout
	return _alive


func _garment(slot_x: float, color_index: int, kind: int, layer: int = 0) -> GarmentView:
	var view: GarmentView = GarmentView.new()
	view.setup(color_index, _colors[color_index % _colors.size()], GARMENT_SIZE, kind, layer)
	view.position = Vector2(slot_x, ROPE_Y)
	_stage.add_child(view)
	view.set_sway_strength(Motion.SWAY_CALM)
	return view


func _rope() -> void:
	var rope: Line2D = Line2D.new()
	rope.points = PackedVector2Array([Vector2(24.0, ROPE_Y - 4.0), Vector2(STAGE_SIZE.x - 24.0, ROPE_Y - 4.0)])
	rope.width = ROPE_WIDTH
	rope.default_color = ROPE_COLOR
	rope.antialiased = true
	_stage.add_child(rope)
	_stage.move_child(rope, 1)


func _target_of(view: GarmentView) -> Vector2:
	return view.position + Vector2(0.0, GARMENT_SIZE * HAND_TARGET_RATIO)


## Islak: iki dokunuş. İlk dokunuş sıkar (damlalar), ikincisi alır.
func _demo_wet() -> void:
	_rope()
	while _alive:
		var view: GarmentView = _garment(STAGE_SIZE.x * 0.5, 1, WET_KIND)
		view.set_wet(true)
		if not await _pause(LOOP_PAUSE + 0.4):
			return
		_hand.tap_once(_target_of(view))
		if not await _pause(Motion.OVERLAY_FADE_SECONDS + 0.2):
			return
		view.wring()
		if not await _pause(AFTER_TAP_PAUSE):
			return
		_hand.tap_once(_target_of(view))
		if not await _pause(Motion.OVERLAY_FADE_SECONDS + 0.2):
			return
		var gone: Tween = view.create_tween().set_parallel(true)
		gone.tween_property(view, "position:y", ROPE_Y - 30.0, 0.4)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		gone.tween_property(view, "modulate:a", 0.0, 0.4)
		if not await _pause(AFTER_TAP_PAUSE):
			return
		view.queue_free()


## Gizemli: üstü kapalı çamaşırın "?"si, üstündeki alınınca gerçek renge döner.
func _demo_mystery() -> void:
	_rope()
	while _alive:
		var hidden: GarmentView = _garment(STAGE_SIZE.x * 0.5 - 55.0, 2, SPARE_KIND, 0)
		hidden.set_mystery(true)
		var cover: GarmentView = _garment(STAGE_SIZE.x * 0.5 + 55.0, 0, COVER_KIND, 1)
		cover.position.y += 16.0
		hidden.set_open(false)
		if not await _pause(LOOP_PAUSE + 0.5):
			return
		_hand.tap_once(_target_of(cover))
		if not await _pause(Motion.OVERLAY_FADE_SECONDS + 0.2):
			return
		var gone: Tween = cover.create_tween().set_parallel(true)
		gone.tween_property(cover, "position:y", cover.position.y - 40.0, 0.4)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		gone.tween_property(cover, "modulate:a", 0.0, 0.4)
		hidden.set_open(true)
		if not await _pause(AFTER_TAP_PAUSE + 0.8):
			return
		hidden.queue_free()
		cover.queue_free()


## Kilit: kilitli çamaşıra dokununca sarsılır; anahtar renkli sepet dolunca kilit açılır.
func _demo_lock() -> void:
	_rope()
	var key_index: int = 3
	var basket: BasketView = BasketView.new()
	basket.setup(BASKET_SIZE)
	basket.position = Vector2(STAGE_SIZE.x * 0.74, STAGE_SIZE.y * 0.62)
	_stage.add_child(basket)
	basket.set_color(_colors[key_index % _colors.size()])
	while _alive:
		basket.set_filled(0)
		var view: GarmentView = _garment(STAGE_SIZE.x * 0.27, 0, SPARE_KIND)
		view.set_lock(_colors[key_index % _colors.size()])
		if not await _pause(LOOP_PAUSE + 0.4):
			return
		_hand.tap_once(_target_of(view))
		if not await _pause(Motion.OVERLAY_FADE_SECONDS + 0.2):
			return
		view.wobble()
		basket.hop()
		if not await _pause(AFTER_TAP_PAUSE):
			return
		for count: int in range(1, LaundryBoard.BASKET_CAPACITY + 1):
			basket.receive(0.8)
			basket.set_filled(count)
			if not await _pause(0.45):
				return
		basket.pulse_band()
		view.unlock()
		if not await _pause(AFTER_TAP_PAUSE + 0.8):
			return
		view.queue_free()


func _demo_badge(text: String) -> void:
	var plate: Panel = Panel.new()
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = UiKit.ACCENT
	box.set_corner_radius_all(int(ICON_PLATE * 0.5))
	box.anti_aliasing = true
	plate.add_theme_stylebox_override("panel", box)
	plate.size = Vector2.ONE * ICON_PLATE
	plate.position = (STAGE_SIZE - plate.size) * 0.5
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label: Label = _label(text, BADGE_FONT, Color.WHITE)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plate.add_child(label)
	_stage.add_child(plate)
	_breathe(plate)


## Yedek gösteri: yuvarlak zemin üstünde ikon (tanınmayan gösteri tipleri buraya düşer).
func _demo_icon(icon_name: String) -> void:
	var texture: Texture2D = Icons.texture(icon_name)
	if texture == null:
		texture = Icons.texture(FALLBACK_ICON)
	var plate: Panel = Panel.new()
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = UiKit.ACCENT
	box.set_corner_radius_all(int(ICON_PLATE * 0.5))
	box.anti_aliasing = true
	plate.add_theme_stylebox_override("panel", box)
	plate.size = Vector2.ONE * ICON_PLATE
	plate.position = (STAGE_SIZE - plate.size) * 0.5
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(plate)
	if texture != null:
		var icon: TextureRect = TextureRect.new()
		icon.texture = texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size = Vector2.ONE * ICON_SIZE
		icon.position = (plate.size - icon.size) * 0.5
		icon.modulate = Color.WHITE
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.add_child(icon)
	_breathe(plate)


## Hafif nefes: durağan kart ölü görünmesin.
func _breathe(node: Control) -> void:
	node.pivot_offset = node.size * 0.5
	var loop: Tween = node.create_tween().set_loops()
	loop.tween_property(node, "scale", Vector2.ONE * 1.05, 1.1)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	loop.tween_property(node, "scale", Vector2.ONE, 1.1)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Gerçek sprite gösterisi: tek görsel (`sprite`) ya da sırayla değişen kareler (`frames`: kuş kanat
## çırpar, kedi uyur/uyanır). `falling`: bulutun altından süzülen damlalar. Hafif sallanma: durağan
## kart ölü görünmesin. Görseller ağırlıksız (≤512 px) ve elle ölçeklenir; piksel kırılması yok (mipmap/linear).
func _demo_sprite(spec: Dictionary) -> void:
	var paths: Array[String] = []
	if spec.has("frames"):
		for entry: Variant in spec["frames"] as Array:
			paths.append(String(entry))
	else:
		paths.append(String(spec["sprite"]))
	var height: float = float(spec.get("sprite_height", SPRITE_HEIGHT))
	var holder: Control = Control.new()
	holder.position = STAGE_SIZE * 0.5
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(holder)
	var frames: Array[TextureRect] = []
	for path: String in paths:
		var texture: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
		if texture == null:
			continue
		var view: TextureRect = TextureRect.new()
		view.texture = texture
		view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var ratio: float = texture.get_size().x / texture.get_size().y
		view.size = Vector2(height * ratio, height)
		view.position = -view.size * 0.5
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.visible = frames.is_empty()
		holder.add_child(view)
		frames.append(view)
	if frames.is_empty():
		_demo_icon(String(spec.get("icon", FALLBACK_ICON)))
		holder.queue_free()
		return
	if spec.has("falling"):
		_rain(holder, String(spec["falling"]), frames[0].size)
	_sway(holder)
	var index: int = 0
	while _alive and frames.size() > 1:
		if not await _pause(FRAME_SECONDS):
			return
		frames[index].visible = false
		index = (index + 1) % frames.size()
		frames[index].visible = true


func _sway(node: Control) -> void:
	var loop: Tween = node.create_tween().set_loops()
	loop.tween_property(node, "rotation_degrees", SWAY_DEGREES, SWAY_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	loop.tween_property(node, "rotation_degrees", -SWAY_DEGREES, SWAY_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Bulutun altında yavaşça düşüp solan birkaç damla (ASMR yağmur; hafif: 3 sprite + 3 tween).
func _rain(holder: Control, path: String, cloud_size: Vector2) -> void:
	var texture: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	if texture == null:
		return
	for index: int in range(FALL_COUNT):
		var drop: TextureRect = TextureRect.new()
		drop.texture = texture
		drop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		drop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		drop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var ratio: float = texture.get_size().x / texture.get_size().y
		drop.size = Vector2(FALL_HEIGHT * ratio, FALL_HEIGHT)
		var x: float = (float(index) - float(FALL_COUNT - 1) * 0.5) * FALL_SPREAD
		var top: float = cloud_size.y * CLOUD_Y_RATIO
		drop.position = Vector2(x, top) - drop.size * 0.5
		drop.modulate.a = 0.0
		drop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(drop)
		var loop: Tween = drop.create_tween().set_loops()
		loop.tween_interval(FALL_SECONDS * float(index) / float(FALL_COUNT))
		loop.tween_property(drop, "modulate:a", 1.0, FALL_SECONDS * 0.2)
		loop.parallel().tween_property(drop, "position:y", drop.position.y + FALL_DISTANCE, FALL_SECONDS)\
			.from(drop.position.y).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		loop.tween_property(drop, "modulate:a", 0.0, FALL_SECONDS * 0.3)


## Türlü sepet: gerçek sepet + önünde türün rozeti (oyundakiyle aynı KindBadge).
func _demo_typed(kind_index: int) -> void:
	var basket: BasketView = BasketView.new()
	basket.setup(BASKET_SIZE)
	basket.position = Vector2(STAGE_SIZE.x * 0.5, STAGE_SIZE.y * 0.6)
	_stage.add_child(basket)
	basket.set_color(_colors[TYPED_KIND_DEFAULT % _colors.size()])
	var badge: KindBadge = KindBadge.new()
	badge.setup(basket, BASKET_SIZE)
	_stage.add_child(badge)
	badge.set_kind(kind_index, _colors[TYPED_KIND_DEFAULT % _colors.size()])
	_breathe_node(basket)


## Güçlendirici: oyun çubuğundaki aynı çizim (BoosterButton) yuvarlak zeminde, nefes alır.
func _demo_booster(id: String) -> void:
	var plate: Panel = Panel.new()
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = UiKit.ACCENT_SOFT
	box.set_corner_radius_all(int(ICON_PLATE * 0.5))
	box.anti_aliasing = true
	plate.add_theme_stylebox_override("panel", box)
	plate.size = Vector2.ONE * ICON_PLATE
	plate.position = (STAGE_SIZE - plate.size) * 0.5
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(plate)
	var glyph: BoosterBar.BoosterButton = BoosterBar.BoosterButton.new()
	glyph.booster = id
	glyph.badge_color = Color(0.0, 0.0, 0.0, 0.0)
	glyph.flat = true
	glyph.focus_mode = Control.FOCUS_NONE
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.size = Vector2.ONE * BOOSTER_GLYPH
	glyph.position = (plate.size - glyph.size) * 0.5
	plate.add_child(glyph)
	_breathe(plate)


func _breathe_node(node: Node2D) -> void:
	var loop: Tween = node.create_tween().set_loops()
	loop.tween_property(node, "scale", Vector2.ONE * 1.04, 1.1)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	loop.tween_property(node, "scale", Vector2.ONE, 1.1)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
