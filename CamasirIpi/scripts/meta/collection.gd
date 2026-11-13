class_name MetaCollection
extends CanvasLayer

## Kıyafet koleksiyonu ekranı (tam ekran katman). Her 10 seviyede bir ülke temalı parça
## kazanılır (MetaState.pieces_earned); setler 4 parçalıdır. Her set kartında küçük bir
## çamaşır ipi: kazanılan parçalar desenli asılı, eksikler yumuşak gölge. Set tamamlanınca
## kozmetik (ip/mandal kaplaması) açılır — yalnız "meta" modülüne kaydedilir.
## Desenler `garment_pattern.gdshader` ile oyunun nötr çamaşır sprite'larına uygulanır.
##
## Kullanım (yönetmen): `MetaCollection.open(self)` — kapanınca `closed` yayılır.

signal closed
## Ekran tamamen opak olunca true (açılış solması bitti), kapanış başlarken false. Ana ekran
## bununla arkada kalan (görünmeyen) bahçeyi çizmeyi/işlemeyi durdurur: mobilde boşa piksel doldurma.
signal covering_changed(covering: bool)

const SCENE_PATH: String = "res://scenes/meta/Collection.tscn"
const SHADER_PATH: String = "res://scripts/meta/garment_pattern.gdshader"
const GARMENT_PATH: String = "res://assets/sprites/garment_%s.png"
const PIN_PATH: String = "res://assets/sprites/pin.png"
const PATTERNS: Array[String] = ["solid", "stripes", "dots", "checks", "tartan", "waves", "serape",
	"diamonds", "floral", "zigzag"]

const BACKGROUND_TOP: Color = Color("f7f3ea")
const BACKGROUND_BOTTOM: Color = Color("eef4ea")
const CARD_COLOR: Color = Color("fffdf8")
const CARD_RADIUS: int = 48
const CARD_PAD_X: int = 40
const CARD_PAD_Y: int = 34
const CARD_GAP: int = 28
const LIST_SIDE: float = 40.0
const TITLE_SIZE: int = 44
const SET_NAME_SIZE: int = 40
const SMALL_SIZE: int = 30
const HEADER_GAP: float = 40.0
const NEXT_BAR_SIZE: Vector2 = Vector2(420.0, 12.0)
const SET_BAR_HEIGHT: float = 10.0
const BAR_TRACK: Color = Color(0.18, 0.23, 0.21, 0.08)
const ROPE_COLOR: Color = Color("8a6a4a")
const ROPE_WIDTH: float = 4.0
const ROPE_SAG: float = 12.0
const ROPE_Y: float = 34.0
const ROW_HEIGHT: float = 236.0
const GARMENT_SIZE: float = 246.0
## Sprite tuvalinde çamaşırın üst kenarı (ip hizası) tuvalin bu oranında (make_sprites.py).
const GARMENT_TOP_RATIO: float = 0.1
const PIN_HEIGHT: float = 46.0
const PIN_SPREAD: float = 0.26
const MISSING_PIN_ALPHA: float = 0.35
const REWARD_ICON: float = 40.0
const NEW_DOT: float = 16.0
const NEW_POP_SECONDS: float = 0.6
const NEW_POP_DELAY: float = 0.35
const SWAY_DEGREES: float = 1.6
const SWAY_SECONDS: float = 3.2
const SCROLL_BOTTOM_PAD: float = 80.0
const SCROLL_DELAY: float = 0.3
## Liste üstündeki solma bandı; başlık ile ilk kart arasındaki boşluğa tam oturur.
const EDGE_FADE: float = 40.0
const SCROLL_SECONDS: float = 0.8
## Önceki kartın alt kenarı biraz görünsün: listenin devam ettiği sezilsin.
const SCROLL_PEEK: float = 90.0
## Bundan açık ana renk ilerleme çubuğunda kaybolur (krem kart üstünde).
const ACCENT_MAX_LUMA: float = 0.8

var store: MetaStore = null
var _view: Vector2 = Vector2(1080.0, 1920.0)
var _insets: Vector4 = Vector4.ZERO
var _root: Control = null
var _shader: Shader = null
var _closing: bool = false
var _seen_before: int = 0
var _newly_unlocked: Array[String] = []
var _scroll: ScrollContainer = null
var _cards: Array[Control] = []


## Tam ekran katman olarak açar; geri düğmesi/tuşu ile kapanır ve `closed` yayar.
static func open(parent: Node) -> Node:
	var node: MetaCollection = (load(SCENE_PATH) as PackedScene).instantiate() as MetaCollection
	parent.add_child(node)
	return node


func _ready() -> void:
	layer = MetaUi.LAYER
	if store == null:
		store = MetaStore.new()
	_shader = load(SHADER_PATH) as Shader
	# Yeni rozetleri için eşitlemeden ÖNCEKİ görülen sayı tutulur; sonra kozmetikler kaydedilir.
	_seen_before = store.state.pieces_seen
	_newly_unlocked = store.sync_collection()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	_view = _root.get_viewport_rect().size
	_insets = UiKit.safe_insets(_view)
	_build_background()
	var list_top: float = _build_header()
	_build_list(list_top)
	MetaUi.connect_back(_on_back)
	_root.modulate.a = 0.0
	var intro: Tween = create_tween()
	intro.tween_property(_root, "modulate:a", 1.0, Motion.OVERLAY_FADE_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	intro.tween_callback(_on_intro_done)


func close() -> void:
	if _closing:
		return
	_closing = true
	# Solarak kapanırken arkası görünür: ana ekran önce yeniden çizilmeye başlasın.
	covering_changed.emit(false)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween: Tween = create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, Motion.OVERLAY_FADE_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(_finish_close)


func _on_intro_done() -> void:
	if not _closing:
		covering_changed.emit(true)


func _finish_close() -> void:
	closed.emit()
	queue_free()


func _on_back() -> void:
	if is_inside_tree() and not _closing:
		close()


func _build_background() -> void:
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, BACKGROUND_TOP)
	gradient.set_color(1, BACKGROUND_BOTTOM)
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	var back: TextureRect = TextureRect.new()
	back.texture = texture
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.stretch_mode = TextureRect.STRETCH_SCALE
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(back)


## Üst çubuk + "sıradaki parça" çubuğu. Dönen: listenin başlayacağı y.
func _build_header() -> float:
	var back: UiIconButton = MetaUi.back_button(_view, _insets)
	back.pressed.connect(close)
	_root.add_child(back)
	var title: Label = UiKit.label(MetaStrings.COLLECTION_TITLE, TITLE_SIZE)
	title.position = Vector2(0.0, _insets.y)
	title.size = Vector2(_view.x, UiKit.MIN_TOUCH)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_root.add_child(title)
	var catalog: MetaCatalog = store.catalog
	var total: int = catalog.total_pieces()
	var earned: int = MetaState.pieces_earned(store.level(), catalog.levels_per_piece, total)
	var count: UiChip = MetaUi.counter_chip("lucide/shirt", UiKit.ACCENT)
	_root.add_child(count)
	count.set_value(earned, false)
	MetaUi.place_right(count, _view, _insets)
	var next: VBoxContainer = VBoxContainer.new()
	next.alignment = BoxContainer.ALIGNMENT_CENTER
	next.add_theme_constant_override("separation", 12)
	next.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var remaining: int = MetaState.levels_to_next_piece(store.level(), catalog.levels_per_piece, total)
	var text: String = MetaStrings.NEXT_PIECE_FORMAT % remaining if remaining > 0 else MetaStrings.ALL_PIECES
	next.add_child(UiKit.label(text, SMALL_SIZE, UiKit.TEXT_MUTED))
	var bar: MetaBar = MetaBar.new()
	bar.setup(NEXT_BAR_SIZE, UiKit.GOLD, BAR_TRACK)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	next.add_child(bar)
	bar.set_value(0.0, false)
	bar.set_value(MetaState.next_piece_progress(store.level(), catalog.levels_per_piece, total))
	_root.add_child(next)
	var next_size: Vector2 = next.get_combined_minimum_size()
	var top: float = _insets.y + UiKit.MIN_TOUCH + HEADER_GAP * 0.5
	next.position = Vector2((_view.x - next_size.x) * 0.5, top)
	next.size = next_size
	return top + next_size.y + HEADER_GAP


func _build_list(top: float) -> void:
	var scroll: ScrollContainer = ScrollContainer.new()
	_scroll = scroll
	# Kaydırma alanı solma bandından başlar; durağan hâlde ilk kart bandın hemen altındadır.
	var scroll_top: float = top - EDGE_FADE
	scroll.position = Vector2(_insets.x + LIST_SIDE, scroll_top)
	scroll.size = Vector2(_view.x - _insets.x - _insets.z - LIST_SIDE * 2.0, _view.y - scroll_top)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_root.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", CARD_GAP)
	list.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(list)
	list.add_child(UiKit.spacer(EDGE_FADE - CARD_GAP))
	var catalog: MetaCatalog = store.catalog
	var sizes: Array[int] = catalog.set_sizes()
	var earned: int = MetaState.pieces_earned(store.level(), catalog.levels_per_piece, catalog.total_pieces())
	var flat_index: int = 0
	for set_index: int in range(catalog.set_count()):
		var card: Control = _set_card(set_index, sizes, earned, flat_index)
		list.add_child(card)
		_cards.append(card)
		flat_index += sizes[set_index]
	list.add_child(UiKit.spacer(maxf(_insets.w, UiKit.MIN_BOTTOM_MARGIN) + SCROLL_BOTTOM_PAD))
	_root.add_child(_edge_fade(scroll_top))
	# Oyuncu doldurmakta olduğu sete yumuşakça kaydırılır (ilk set ise kaydırma yok).
	get_tree().create_timer(SCROLL_DELAY).timeout.connect(scroll_to_set.bind(_current_set(sizes, earned)))


## Liste üst kenarında yumuşak solma: kartlar sert bir çizgiyle kesilmez, zemine erir.
func _edge_fade(top: float) -> TextureRect:
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, BACKGROUND_TOP)
	gradient.set_color(1, Color(BACKGROUND_TOP, 0.0))
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	var fade: TextureRect = TextureRect.new()
	fade.texture = texture
	fade.stretch_mode = TextureRect.STRETCH_SCALE
	fade.position = Vector2(0.0, top)
	fade.size = Vector2(_view.x, EDGE_FADE)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return fade


## Kazanılacak sıradaki parçanın seti (hepsi bittiyse son set).
func _current_set(sizes: Array[int], earned: int) -> int:
	var before: int = 0
	for index: int in range(sizes.size()):
		before += sizes[index]
		if earned < before:
			return index
	return maxi(sizes.size() - 1, 0)


## Listeyi verilen setin kartı üstte görünecek şekilde yumuşakça kaydırır.
func scroll_to_set(set_index: int) -> void:
	if _scroll == null or set_index <= 0 or set_index >= _cards.size():
		return
	var bar: VScrollBar = _scroll.get_v_scroll_bar()
	var target: float = minf(_cards[set_index].position.y - SCROLL_PEEK, bar.max_value - _scroll.size.y)
	if target <= 0.0:
		return
	var tween: Tween = create_tween()
	tween.tween_method(_set_scroll, 0.0, target, SCROLL_SECONDS).set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN_OUT)


func _set_scroll(value: float) -> void:
	_scroll.scroll_vertical = roundi(value)


func _set_card(set_index: int, sizes: Array[int], earned: int, first_flat: int) -> Control:
	var catalog: MetaCatalog = store.catalog
	var pieces: Array[Dictionary] = catalog.set_pieces(set_index)
	var owned: int = MetaState.set_owned(earned, sizes, set_index)
	var complete: bool = owned >= pieces.size() and pieces.size() > 0
	var card: PanelContainer = PanelContainer.new()
	card.add_theme_stylebox_override("panel", MetaUi.tile_style(CARD_COLOR, CARD_RADIUS, CARD_PAD_X, CARD_PAD_Y))
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(head)
	var title: Label = UiKit.label(MetaStrings.country_name(catalog.set_id(set_index)), SET_NAME_SIZE,
		UiKit.TEXT if owned > 0 else UiKit.TEXT_MUTED)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var counter: Label = UiKit.label(MetaStrings.SET_PROGRESS_FORMAT % [owned, pieces.size()], SMALL_SIZE,
		UiKit.TEXT_MUTED)
	counter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(counter)
	var reward: TextureRect = UiKit.tinted_icon("lucide/trophy", REWARD_ICON,
		UiKit.GOLD if complete else Color(UiKit.TEXT_MUTED, 0.45))
	reward.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(reward)
	var accent: Color = _set_accent(pieces)
	var bar: MetaBar = MetaBar.new()
	bar.setup(Vector2(0.0, SET_BAR_HEIGHT), accent, BAR_TRACK)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(bar)
	bar.set_value(float(owned) / float(maxi(pieces.size(), 1)), false)
	column.add_child(_rope_row(pieces, owned, first_flat))
	if _newly_unlocked.has(catalog.set_reward(set_index)):
		_celebrate.call_deferred(reward)
	return card


## Kartın vurgu rengi: ilk parçanın ana rengi; çok açıksa (beyaz zemin) ikinci rengi.
func _set_accent(pieces: Array[Dictionary]) -> Color:
	if pieces.is_empty():
		return UiKit.ACCENT
	var colors: Array[Color] = _piece_colors(pieces[0])
	return colors[1] if colors[0].get_luminance() > ACCENT_MAX_LUMA else colors[0]


func _piece_colors(piece: Dictionary) -> Array[Color]:
	var result: Array[Color] = []
	var raw: Variant = piece.get("colors", [])
	if raw is Array:
		for entry: Variant in raw as Array:
			result.append(Color.from_string(str(entry), Color.WHITE))
	while result.size() < 3:
		result.append(result[result.size() - 1] if not result.is_empty() else Color.WHITE)
	return result


## Kartın çamaşır ipi: çizilmiş yumuşak ip + mandallı parçalar (oyunun kendi dili).
func _rope_row(pieces: Array[Dictionary], owned: int, first_flat: int) -> Control:
	var row: Control = Control.new()
	row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.draw.connect(_draw_rope.bind(row))
	row.resized.connect(_layout_row.bind(row, pieces.size()))
	for index: int in range(pieces.size()):
		var has_it: bool = index < owned
		var is_new: bool = has_it and first_flat + index >= _seen_before
		row.add_child(_piece(pieces[index], has_it, is_new, index))
	return row


func _draw_rope(row: Control) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var steps: int = 24
	for step: int in range(steps + 1):
		var t: float = float(step) / float(steps)
		points.append(Vector2(row.size.x * t, ROPE_Y + ROPE_SAG * sin(PI * t)))
	row.draw_polyline(points, ROPE_COLOR, ROPE_WIDTH, true)


func _layout_row(row: Control, count: int) -> void:
	var slot: float = row.size.x / float(maxi(count, 1))
	for index: int in range(row.get_child_count()):
		var piece: Control = row.get_child(index) as Control
		var t: float = (float(index) + 0.5) / float(maxi(count, 1))
		var rope_y: float = ROPE_Y + ROPE_SAG * sin(PI * t)
		piece.position = Vector2(slot * (float(index) + 0.5) - GARMENT_SIZE * 0.5, rope_y - GARMENT_SIZE * GARMENT_TOP_RATIO)
	row.queue_redraw()


func _piece(piece: Dictionary, has_it: bool, is_new: bool, index: int) -> Control:
	var holder: Control = Control.new()
	holder.size = Vector2(GARMENT_SIZE, GARMENT_SIZE)
	holder.pivot_offset = Vector2(GARMENT_SIZE * 0.5, GARMENT_SIZE * GARMENT_TOP_RATIO)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var kind: String = str(piece.get("kind", "tshirt"))
	var texture: Texture2D = load(GARMENT_PATH % kind) as Texture2D
	if texture == null:
		texture = load(GARMENT_PATH % "tshirt") as Texture2D
	var picture: TextureRect = TextureRect.new()
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.size = holder.size
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.material = _pattern_material(piece, not has_it)
	holder.add_child(picture)
	for side: float in [-1.0, 1.0]:
		var pin: TextureRect = TextureRect.new()
		pin.texture = load(PIN_PATH) as Texture2D
		pin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pin.size = Vector2(PIN_HEIGHT * 0.5, PIN_HEIGHT)
		pin.position = Vector2(GARMENT_SIZE * (0.5 + side * PIN_SPREAD) - pin.size.x * 0.5,
			GARMENT_SIZE * GARMENT_TOP_RATIO - PIN_HEIGHT * 0.45)
		pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not has_it:
			pin.modulate.a = MISSING_PIN_ALPHA
		holder.add_child(pin)
	if has_it:
		# Kazanılan parçalar ipte çok hafif sallanır (oyundaki çamaşırlar gibi canlı).
		var phase: float = float(index) * 0.7
		holder.rotation_degrees = SWAY_DEGREES * sin(phase)
		var sway: Tween = holder.create_tween().set_loops()
		sway.tween_property(holder, "rotation_degrees", SWAY_DEGREES, SWAY_SECONDS * 0.5)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		sway.tween_property(holder, "rotation_degrees", -SWAY_DEGREES, SWAY_SECONDS * 0.5)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if is_new:
		var dot: Panel = MetaUi.disc(NEW_DOT, UiKit.FLAME)
		dot.position = Vector2(GARMENT_SIZE * 0.82, GARMENT_SIZE * 0.2)
		holder.add_child(dot)
		holder.scale = Vector2.ONE * 0.6
		holder.modulate.a = 0.0
		var pop: Tween = holder.create_tween().set_parallel(true)
		pop.tween_property(holder, "scale", Vector2.ONE, NEW_POP_SECONDS).set_delay(NEW_POP_DELAY + 0.12 * index)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pop.tween_property(holder, "modulate:a", 1.0, NEW_POP_SECONDS * 0.5).set_delay(NEW_POP_DELAY + 0.12 * index)
		pop.chain().tween_callback(MetaUi.play_sound.bind("pin_click", 1.0, -4.0))
	return holder


func _pattern_material(piece: Dictionary, missing: bool) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = _shader
	var colors: Array[Color] = _piece_colors(piece)
	material.set_shader_parameter(&"pattern", maxi(PATTERNS.find(str(piece.get("pattern", "solid"))), 0))
	material.set_shader_parameter(&"color_a", colors[0])
	material.set_shader_parameter(&"color_b", colors[1])
	material.set_shader_parameter(&"color_c", colors[2])
	material.set_shader_parameter(&"scale", float(piece.get("scale", 6.0)))
	material.set_shader_parameter(&"angle", float(piece.get("angle", 0.0)))
	material.set_shader_parameter(&"silhouette", 1.0 if missing else 0.0)
	return material


## Set yeni tamamlandı: kupa hafifçe zıplar, parıltı çıkar.
func _celebrate(reward: TextureRect) -> void:
	if not is_instance_valid(reward):
		return
	reward.pivot_offset = reward.size * 0.5
	var tween: Tween = reward.create_tween()
	tween.tween_interval(NEW_POP_DELAY + 0.5)
	tween.tween_property(reward, "scale", Vector2.ONE * 1.35, 0.22).set_trans(Tween.TRANS_SINE)
	tween.tween_property(reward, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_sparkle_at.bind(reward))


func _sparkle_at(reward: TextureRect) -> void:
	if not is_instance_valid(reward):
		return
	var host: Node2D = Node2D.new()
	_root.add_child(host)
	MetaSparkle.burst(host, reward.get_global_rect().get_center(), 70.0, Motion.SPARKLE_COUNT / 2)
	MetaUi.play_sound("unlock", 1.0, -4.0)
