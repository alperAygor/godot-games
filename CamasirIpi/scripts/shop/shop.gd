class_name ShopScreen
extends CanvasLayer

## Mağaza (tam ekran katman): güçlendiriciler (jetonla, x1/x3/x5 paket + ödüllü reklamla bedava +1),
## görünümler (mandal/ip: jetonla ya da koleksiyonla açılır) ve "Reklamları kaldır" (ücretli, tek sefer).
## Ana ekranla aynı dil: düz, çizgisiz, az metin, küçük ikonlar. Fiyat/paket değerleri balance.json'da,
## kaplamalar skins.json'da, satın alma servisi `IapService`tedir; bu sınıf yalnız gösterir ve çağırır.
##
## Kullanım: `ShopScreen.open(self)` — kapanınca `closed` yayılır (MetaCollection ile aynı sözleşme).

signal closed
## Ekran tamamen opak olunca true: ana ekran arkadaki bahçeyi çizmeyi durdurur (performans).
signal covering_changed(covering: bool)

const SCENE_PATH: String = "res://scenes/shop/Shop.tscn"
const BACKGROUND_TOP: Color = Color("f7f3ea")
const BACKGROUND_BOTTOM: Color = Color("eef4ea")
const CARD_COLOR: Color = Color("fffdf8")
const TILE_FILL: Color = UiKit.SURFACE_SOFT
const ACCENT_FILL: Color = UiKit.ACCENT
const ACCENT_SOFT_FILL: Color = UiKit.ACCENT_SOFT
const CARD_RADIUS: int = UiTokens.RADIUS_SHEET
const TILE_RADIUS: int = UiKit.RADIUS_TILE
const PILL_RADIUS: int = UiTokens.RADIUS_CHIP + 8
const CARD_PAD_X: int = UiTokens.SPACE_XL + 8
const CARD_PAD_Y: int = UiTokens.SPACE_XL
const CARD_GAP: int = UiTokens.SPACE_LG
const LIST_SIDE: float = UiKit.SPACE_XL + 8.0
const TITLE_SIZE: int = UiKit.TYPE_HEADING
const NAME_SIZE: int = UiKit.TYPE_BODY + 4
const SMALL_SIZE: int = UiKit.TYPE_CAPTION
const TINY_SIZE: int = UiKit.TYPE_MICRO
const HEADER_GAP: float = 36.0
const EDGE_FADE: float = 40.0
const SCROLL_BOTTOM_PAD: float = 80.0
const GLYPH_DISC: float = 112.0
const BADGE_DISC: float = 44.0
const BADGE_COLOR: Color = BoosterBar.BADGE_COLOR
const BADGE_EMPTY_COLOR: Color = BoosterBar.BADGE_EMPTY_COLOR
const ROW_GAP: int = 22
const BLOCK_GAP: int = 40
const PACK_HEIGHT: float = 132.0
const PACK_GAP: int = 20
const COIN_ICON: float = 32.0
const FREE_HEIGHT: float = 92.0
const TILE_COLUMNS: int = 5
const TILE_GAP: int = 20
const PIN_TILE_HEIGHT: float = 236.0
const ROPE_TILE_HEIGHT: float = 176.0
const PIN_PREVIEW_HEIGHT: float = 150.0
const PREVIEW_TOP: float = 16.0
const TILE_STRIP_HEIGHT: float = 44.0
const TILE_STRIP_BOTTOM: float = 10.0
const CHECK_DISC: float = 40.0
const CHECK_ICON: float = 24.0
const LOCK_ICON: float = 26.0
const LOCKED_ALPHA: float = 0.42
const DISABLED_ALPHA: float = 0.5
const ROPE_PREVIEW_SCALE: float = 1.15
const ROPE_PREVIEW_SAG: float = 9.0
const ROPE_PREVIEW_INSET: float = 18.0
const PRICE_PILL_WIDTH: float = 250.0
const PRICE_PILL_HEIGHT: float = 104.0
const POP_SCALE: float = 1.07
const POP_IN_SECONDS: float = 0.12
const POP_OUT_SECONDS: float = 0.26
const BUY_SOUND: String = "purchase"
const BUY_SOUND_DB: float = -6.0
const SELECT_SOUND: String = "ui_soft"
const SELECT_SOUND_DB: float = -4.0
const TOAST_SECONDS: float = 2.2
const TOAST_FADE: float = 0.25
const TOAST_BOTTOM: float = 220.0
const SOON_RESTORE_SIZE: int = 30
const REMOVE_ADS_ICON: String = "lucide/shield"

var _view: Vector2 = Vector2(1080.0, 1920.0)
var _insets: Vector4 = Vector4.ZERO
var _root: Control = null
var _scroll: ScrollContainer = null
var _list: VBoxContainer = null
var _coin_chip: UiChip = null
var _closing: bool = false
var _toast: PanelContainer = null
var _toast_tween: Tween = null
var _skins: SkinStore = null
var _iap: IapService = null
var _eco: EcoFlow = null
var _balance: Dictionary = {}
## Satın alma/seçim sonrası kısa "pop" için son dokunulan öğenin anahtarı ve oluşturulan düğümler.
var _pop_key: String = ""
var _nodes: Dictionary = {}
var _boosters_card: PanelContainer = null
var _pins_card: PanelContainer = null
var _ropes_card: PanelContainer = null
var _ads_card: PanelContainer = null


## Tam ekran katman olarak açar; geri düğmesi/tuşu ile kapanır ve `closed` yayar.
static func open(parent: Node) -> ShopScreen:
	var node: ShopScreen = (load(SCENE_PATH) as PackedScene).instantiate() as ShopScreen
	parent.add_child(node)
	return node


func _ready() -> void:
	layer = MetaUi.LAYER
	_balance = Progress.balance_table()
	_skins = SkinStore.new()
	_iap = IapService.ensure(get_tree())
	_eco = EcoFlow.new()
	add_child(_eco)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	_view = _root.get_viewport_rect().size
	_insets = UiKit.safe_insets(_view)
	_build_background()
	var list_top: float = _build_header()
	_build_list(list_top)
	_build_toast()
	_refresh()
	UiData.connect_changed(_on_progress_changed)
	_iap.state_changed.connect(_refresh)
	_iap.purchase_failed.connect(_on_iap_failed)
	_iap.restore_done.connect(_on_restore_done)
	MetaUi.connect_back(_on_back)
	AnalyticsLog.record("shop_open", {"coins": Progress.coins(), "remove_ads": Progress.remove_ads_owned()})
	_root.modulate.a = 0.0
	var intro: Tween = create_tween()
	intro.tween_property(_root, "modulate:a", 1.0, Motion.OVERLAY_FADE_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	intro.tween_callback(_on_intro_done)


func close() -> void:
	if _closing:
		return
	_closing = true
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


func _exit_tree() -> void:
	# Geri tuşu sinyali ağaçtan çıkan ekrana bağlı kalmasın.
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	var manager: Node = loop.root.get_node_or_null("GameManager") if loop != null else null
	if manager != null and manager.is_connected("back_requested", _on_back):
		manager.disconnect("back_requested", _on_back)


# --- İskelet ----------------------------------------------------------------------------------

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


## Üst çubuk: geri + başlık + jeton sayacı. Dönen: listenin başlayacağı y.
func _build_header() -> float:
	var back: UiIconButton = MetaUi.back_button(_view, _insets)
	back.pressed.connect(close)
	_root.add_child(back)
	var title: Label = UiKit.label(ShopStrings.title(), TITLE_SIZE)
	title.position = Vector2(0.0, _insets.y)
	title.size = Vector2(_view.x, UiKit.MIN_TOUCH)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_root.add_child(title)
	_coin_chip = MetaUi.counter_chip("lucide/coins", UiKit.GOLD)
	_root.add_child(_coin_chip)
	_coin_chip.set_value(Progress.coins(), false)
	MetaUi.place_right(_coin_chip, _view, _insets)
	return _insets.y + UiKit.MIN_TOUCH + HEADER_GAP


func _build_list(top: float) -> void:
	_scroll = ScrollContainer.new()
	var scroll_top: float = top - EDGE_FADE
	_scroll.position = Vector2(_insets.x + LIST_SIDE, scroll_top)
	_scroll.size = Vector2(_view.x - _insets.x - _insets.z - LIST_SIDE * 2.0, _view.y - scroll_top)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_root.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", CARD_GAP)
	_list.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(_list)
	_list.add_child(UiKit.spacer(EDGE_FADE - CARD_GAP))
	_boosters_card = _new_card()
	_pins_card = _new_card()
	_ropes_card = _new_card()
	_ads_card = _new_card()
	_list.add_child(UiKit.spacer(maxf(_insets.w, UiKit.MIN_BOTTOM_MARGIN) + SCROLL_BOTTOM_PAD))
	_root.add_child(_edge_fade(scroll_top))


func _new_card() -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.add_theme_stylebox_override("panel", MetaUi.tile_style(CARD_COLOR, CARD_RADIUS, CARD_PAD_X, CARD_PAD_Y))
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	_list.add_child(card)
	return card


## Liste üst kenarında yumuşak solma: kartlar sert bir çizgiyle kesilmez.
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


func _build_toast() -> void:
	_toast = PanelContainer.new()
	_toast.theme_type_variation = &"ChipPanel"
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0
	var label: Label = UiKit.label("", SMALL_SIZE, UiKit.TEXT)
	label.name = "Text"
	_toast.add_child(label)
	_root.add_child(_toast)


## Kısa bilgi balonu (ekranın altında, kendiliğinden kaybolur).
func _show_toast(text: String) -> void:
	var label: Label = _toast.get_node("Text") as Label
	label.text = text
	_toast.reset_size()
	var toast_size: Vector2 = _toast.get_combined_minimum_size()
	_toast.size = toast_size
	_toast.position = Vector2((_view.x - toast_size.x) * 0.5, _view.y - _insets.w - TOAST_BOTTOM)
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, TOAST_FADE)
	_toast_tween.tween_interval(TOAST_SECONDS)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, TOAST_FADE)


# --- İçerik (her değişimde yeniden kurulur; kaydırma konumu korunur) ----------------------------

func _on_progress_changed() -> void:
	_refresh()


func _refresh() -> void:
	if _coin_chip == null or _closing:
		return
	var scroll_before: int = _scroll.scroll_vertical
	_coin_chip.set_value(Progress.coins())
	_nodes.clear()
	for card: PanelContainer in [_boosters_card, _pins_card, _ropes_card, _ads_card]:
		for child: Node in card.get_children():
			card.remove_child(child)
			child.queue_free()
	_boosters_card.add_child(_build_boosters())
	_pins_card.add_child(_build_skin_section(SkinCatalog.KIND_PIN))
	_ropes_card.add_child(_build_skin_section(SkinCatalog.KIND_ROPE))
	_ads_card.add_child(_build_remove_ads())
	_scroll.set_deferred("scroll_vertical", scroll_before)
	if not _pop_key.is_empty():
		_pop.call_deferred(_pop_key)
		_pop_key = ""


func _column(separation: int) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", separation)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return column


func _row(separation: int) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", separation)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return row


func _section_title(text: String) -> Label:
	var label: Label = UiKit.label(text, SMALL_SIZE, UiKit.TEXT_MUTED)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return label


# --- Güçlendiriciler ----------------------------------------------------------------------------

func _build_boosters() -> Control:
	var column: VBoxContainer = _column(BLOCK_GAP)
	column.add_child(_section_title(ShopStrings.boosters()))
	for id: String in ProgressData.BOOSTER_IDS:
		column.add_child(_booster_block(id))
	return column


func _booster_block(id: String) -> Control:
	var block: VBoxContainer = _column(ROW_GAP)
	var head: HBoxContainer = _row(24)
	head.add_child(_booster_glyph(id))
	var names: VBoxContainer = _column(0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	var name_label: Label = UiKit.label(ShopStrings.booster_name(id), NAME_SIZE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	names.add_child(name_label)
	head.add_child(names)
	# Sayı 0 iken ödüllü reklamla bedava +1 (EcoFlow.refill_booster = mevcut REFILL_BOOSTER yerleşimi).
	if Progress.booster_count(id) == 0 and _eco.can_watch(AdManager.Placement.REFILL_BOOSTER):
		head.add_child(_free_button(id))
	block.add_child(head)
	var packs: HBoxContainer = _row(PACK_GAP)
	for quantity: int in ShopLogic.pack_sizes(_balance):
		packs.add_child(_pack_button(id, quantity))
	block.add_child(packs)
	return block


## Güçlendirici simgesi: oyun içi çubukla AYNI çizim (BoosterBar.BoosterButton), yuvarlak zeminde.
func _booster_glyph(id: String) -> Control:
	var holder: Control = Control.new()
	holder.custom_minimum_size = Vector2(GLYPH_DISC, GLYPH_DISC)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(MetaUi.disc(GLYPH_DISC, UiKit.ACCENT_SOFT))
	var glyph: BoosterBar.BoosterButton = BoosterBar.BoosterButton.new()
	glyph.booster = id
	glyph.badge_color = Color(0.0, 0.0, 0.0, 0.0)
	glyph.flat = true
	glyph.focus_mode = Control.FOCUS_NONE
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.size = Vector2(GLYPH_DISC, GLYPH_DISC)
	holder.add_child(glyph)
	# Eldeki adet: oyun içi çubuktaki gibi küçük yuvarlak rozet (sıfırsa soluk).
	var count: int = Progress.booster_count(id)
	var badge: Panel = MetaUi.disc(BADGE_DISC, BADGE_COLOR if count > 0 else BADGE_EMPTY_COLOR)
	badge.position = Vector2(GLYPH_DISC - BADGE_DISC * 0.8, -BADGE_DISC * 0.2)
	var number: Label = UiKit.label(str(count), TINY_SIZE + 4, Color.WHITE)
	number.size = Vector2(BADGE_DISC, BADGE_DISC)
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(number)
	holder.add_child(badge)
	return holder


func _free_button(id: String) -> Button:
	var button: Button = _flat_button(ACCENT_FILL, PILL_RADIUS, FREE_HEIGHT)
	button.custom_minimum_size = Vector2(190.0, FREE_HEIGHT)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var content: HBoxContainer = _row(10)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(UiKit.tinted_icon("lucide/video", 36.0, Color.WHITE))
	content.add_child(UiKit.label(ShopStrings.FREE_PLUS_FORMAT, NAME_SIZE, Color.WHITE))
	_fill(button, content)
	button.pressed.connect(_on_free_pressed.bind(id, button))
	return button


func _pack_button(id: String, quantity: int) -> Button:
	var price: int = ShopLogic.pack_price(_balance, id, quantity)
	var affordable: bool = ShopLogic.can_afford(Progress.coins(), price)
	var button: Button = _flat_button(ACCENT_SOFT_FILL, TILE_RADIUS, PACK_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content: VBoxContainer = _column(4)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(UiKit.label(ShopStrings.PACK_FORMAT % quantity, NAME_SIZE))
	content.add_child(_price_line(price, SMALL_SIZE, UiKit.TEXT_MUTED))
	_fill(button, content)
	var discount: int = ShopLogic.discount_percent(_balance, quantity)
	if discount > 0:
		button.add_child(_discount_tag(discount))
	button.disabled = not affordable
	button.modulate.a = 1.0 if affordable else DISABLED_ALPHA
	button.pressed.connect(_on_pack_pressed.bind(id, quantity, price))
	_nodes["booster:%s:%d" % [id, quantity]] = button
	return button


func _discount_tag(percent: int) -> Control:
	var tag: Label = UiKit.label(ShopStrings.DISCOUNT_FORMAT % percent, TINY_SIZE, UiKit.ACCENT)
	tag.position = Vector2(14.0, 8.0)
	return tag


## Jeton ikonu + fiyat (tek satır, ortalı).
func _price_line(price: int, font_size: int, color: Color) -> Control:
	var line: HBoxContainer = _row(8)
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	var coin: TextureRect = UiKit.tinted_icon("lucide/coins", COIN_ICON, UiKit.GOLD)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(coin)
	line.add_child(UiKit.label(str(price), font_size, color))
	return line


# --- Görünümler ---------------------------------------------------------------------------------

func _build_skin_section(kind: String) -> Control:
	var column: VBoxContainer = _column(ROW_GAP)
	var is_pin: bool = kind == SkinCatalog.KIND_PIN
	if is_pin:
		column.add_child(_section_title(ShopStrings.skins() + "  ·  " + ShopStrings.pins()))
	else:
		column.add_child(_section_title(ShopStrings.ropes()))
	var grid: GridContainer = GridContainer.new()
	grid.columns = TILE_COLUMNS
	grid.add_theme_constant_override("h_separation", TILE_GAP)
	grid.add_theme_constant_override("v_separation", TILE_GAP)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(grid)
	for id: String in _skins.catalog.ids(kind):
		grid.add_child(_skin_tile(id, kind))
	return column


func _skin_tile(id: String, kind: String) -> Button:
	var catalog: SkinCatalog = _skins.catalog
	var is_pin: bool = kind == SkinCatalog.KIND_PIN
	var available: bool = _skins.is_available(id)
	var selected: bool = available and _skins.selected(kind) == id
	var price: int = catalog.price(id)
	var buyable: bool = not available and catalog.source_type(id) == SkinCatalog.SOURCE_COINS
	var affordable: bool = buyable and ShopLogic.can_afford(Progress.coins(), price)
	var height: float = PIN_TILE_HEIGHT if is_pin else ROPE_TILE_HEIGHT
	var button: Button = _flat_button(ACCENT_SOFT_FILL if selected else TILE_FILL, TILE_RADIUS, height)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0.0, height)
	var preview: Control = _pin_preview(id) if is_pin else _rope_preview(id)
	preview.modulate.a = 1.0 if available or buyable else LOCKED_ALPHA
	button.add_child(preview)
	var strip: HBoxContainer = _row(6)
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.anchor_left = 0.0
	strip.anchor_right = 1.0
	strip.anchor_top = 1.0
	strip.anchor_bottom = 1.0
	strip.offset_top = -TILE_STRIP_HEIGHT - TILE_STRIP_BOTTOM
	strip.offset_bottom = -TILE_STRIP_BOTTOM
	if buyable:
		strip.add_child(_price_line(price, SMALL_SIZE, UiKit.TEXT if affordable else UiKit.TEXT_MUTED))
	elif not available:
		strip.add_child(MetaUi.lock_icon(LOCK_ICON, UiKit.TEXT_MUTED))
		var set_label: Label = UiKit.label(MetaStrings.country_name(catalog.set_id(id)), TINY_SIZE, UiKit.TEXT_MUTED)
		strip.add_child(set_label)
	button.add_child(strip)
	if selected:
		button.add_child(_check_badge())
	button.disabled = not available and not affordable
	button.modulate.a = DISABLED_ALPHA if (buyable and not affordable) else 1.0
	button.pressed.connect(_on_skin_pressed.bind(id))
	_nodes["skin:" + id] = button
	return button


func _pin_preview(id: String) -> Control:
	var rect: TextureRect = TextureRect.new()
	rect.texture = SkinLook.load_pin_texture(_skins.catalog, id)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.anchor_left = 0.0
	rect.anchor_right = 1.0
	rect.offset_top = PREVIEW_TOP
	rect.offset_bottom = PREVIEW_TOP + PIN_PREVIEW_HEIGHT
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## İp önizlemesi: karonun genişliğine yayılan küçük ip (oyundaki çizimle AYNI `RopePainter`).
func _rope_preview(id: String) -> Control:
	var holder: Control = Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var canvas: RopePreview = RopePreview.new()
	canvas.style = _skins.catalog.rope_style(id)
	holder.add_child(canvas)
	return holder


func _check_badge() -> Control:
	var disc: Panel = MetaUi.disc(CHECK_DISC, UiKit.ACCENT)
	disc.anchor_left = 1.0
	disc.anchor_right = 1.0
	disc.offset_left = -CHECK_DISC - 10.0
	disc.offset_right = -10.0
	disc.offset_top = 10.0
	disc.offset_bottom = 10.0 + CHECK_DISC
	var icon: TextureRect = UiKit.tinted_icon("lucide/check", CHECK_ICON, Color.WHITE)
	icon.position = Vector2((CHECK_DISC - CHECK_ICON) * 0.5, (CHECK_DISC - CHECK_ICON) * 0.5)
	disc.add_child(icon)
	return disc


## Ip karosu içinde ipi çizen küçük düğüm: boyutu karoya göre yerleşir.
class RopePreview extends Control:
	var style: Dictionary = RopePainter.DEFAULT_STYLE

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var y: float = (size.y - ShopScreen.TILE_STRIP_HEIGHT) * 0.42
		RopePainter.draw_rope(self, ShopScreen.ROPE_PREVIEW_INSET, size.x - ShopScreen.ROPE_PREVIEW_INSET,
			y, ShopScreen.ROPE_PREVIEW_SAG, style, ShopScreen.ROPE_PREVIEW_SCALE)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()


# --- Reklamları kaldır --------------------------------------------------------------------------

func _build_remove_ads() -> Control:
	var column: VBoxContainer = _column(ROW_GAP)
	var row: HBoxContainer = _row(24)
	var holder: Control = Control.new()
	holder.custom_minimum_size = Vector2(GLYPH_DISC, GLYPH_DISC)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(MetaUi.disc(GLYPH_DISC, UiKit.ACCENT_SOFT))
	var icon: TextureRect = UiKit.tinted_icon(REMOVE_ADS_ICON, 52.0, UiKit.ACCENT)
	icon.position = Vector2((GLYPH_DISC - 52.0) * 0.5, (GLYPH_DISC - 52.0) * 0.5)
	holder.add_child(icon)
	row.add_child(holder)
	var texts: VBoxContainer = _column(4)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	var title: Label = UiKit.label(ShopStrings.remove_ads(), NAME_SIZE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	texts.add_child(title)
	var note: Label = UiKit.label(ShopStrings.remove_ads_note(), TINY_SIZE + 2, UiKit.TEXT_MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(1.0, 0.0)
	texts.add_child(note)
	row.add_child(texts)
	row.add_child(_remove_ads_pill())
	column.add_child(row)
	if not _iap.remove_ads_owned():
		var restore: Button = _flat_button(Color(0.0, 0.0, 0.0, 0.0), PILL_RADIUS, 72.0)
		restore.focus_mode = Control.FOCUS_NONE
		var caption: Label = UiKit.label(ShopStrings.restore(), SOON_RESTORE_SIZE, UiKit.TEXT_MUTED)
		_fill(restore, caption)
		restore.pressed.connect(_on_restore_pressed)
		column.add_child(restore)
	return column


func _remove_ads_pill() -> Button:
	var owned: bool = _iap.remove_ads_owned()
	var button: Button = _flat_button(ACCENT_SOFT_FILL if owned else ACCENT_FILL, PILL_RADIUS, PRICE_PILL_HEIGHT)
	button.custom_minimum_size = Vector2(PRICE_PILL_WIDTH, PRICE_PILL_HEIGHT)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var content: HBoxContainer = _row(10)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	if owned:
		content.add_child(UiKit.tinted_icon("lucide/check", 36.0, UiKit.ACCENT))
		content.add_child(UiKit.label(ShopStrings.owned(), SMALL_SIZE, UiKit.ACCENT))
		button.disabled = true
	else:
		var price: String = _iap.price_text()
		content.add_child(UiKit.label(price if not price.is_empty() else "…", NAME_SIZE, Color.WHITE))
		button.pressed.connect(_on_remove_ads_pressed)
		button.modulate.a = 1.0 if _iap.store_available() else DISABLED_ALPHA
	_fill(button, content)
	_nodes["remove_ads"] = button
	return button


# --- Eylemler -----------------------------------------------------------------------------------

func _on_pack_pressed(id: String, quantity: int, price: int) -> void:
	# Pop anahtarı ÖNCE yazılır: satın alma `Progress.changed` ile yeniden çizimi tetikler.
	_pop_key = "booster:%s:%d" % [id, quantity]
	if not Progress.purchase_booster(id, quantity, price):
		_pop_key = ""
		return
	AnalyticsLog.record("purchase", {"item": "booster_%s_x%d" % [id, quantity], "price": price, "currency": "coins"})
	MetaUi.play_sound(BUY_SOUND, 1.0, BUY_SOUND_DB)


func _on_free_pressed(id: String, button: Button) -> void:
	button.disabled = true
	_eco.refill_booster(id, Callable(), _on_free_failed.bind(button))


func _on_free_failed(button: Button) -> void:
	if is_instance_valid(button):
		button.disabled = false
	_show_toast(ShopStrings.ad_unavailable())


func _on_skin_pressed(id: String) -> void:
	var kind: String = _skins.catalog.kind_of(id)
	_pop_key = "skin:" + id
	if _skins.is_available(id):
		if _skins.selected(kind) == id:
			_pop_key = ""
			return
		_skins.select(id)
		MetaUi.play_sound(SELECT_SOUND, 1.0, SELECT_SOUND_DB)
	else:
		var price: int = _skins.catalog.price(id)
		if not _skins.buy(id):
			_pop_key = ""
			return
		AnalyticsLog.record("purchase", {"item": id, "price": price, "currency": "coins"})
		MetaUi.play_sound(BUY_SOUND, 1.0, BUY_SOUND_DB)
	AnalyticsLog.record("skin_selected", {"id": id, "kind": kind})


func _on_remove_ads_pressed() -> void:
	if not _iap.store_available():
		_show_toast(ShopStrings.store_unavailable())
		return
	# Başarı `state_changed` ile gelir (sahte mağazada anında); yeniden çizilince kısa pop oynar.
	_pop_key = "remove_ads"
	_iap.buy_remove_ads()
	if _iap.remove_ads_owned():
		MetaUi.play_sound(BUY_SOUND, 1.0, BUY_SOUND_DB)


func _on_iap_failed(reason: String) -> void:
	_pop_key = ""
	if reason == IapProvider.REASON_CANCELED:
		return
	_show_toast(ShopStrings.store_unavailable() if reason == IapProvider.REASON_UNAVAILABLE
		else ShopStrings.purchase_failed())


func _on_restore_pressed() -> void:
	_iap.restore_purchases()


func _on_restore_done(found: bool) -> void:
	_show_toast(ShopStrings.restored() if found else ShopStrings.nothing_to_restore())


## Yumuşak "pop": öğe hafifçe büyür ve oturur.
func _pop(key: String) -> void:
	var node: Control = _nodes.get(key) as Control
	if node == null or not is_instance_valid(node):
		return
	node.pivot_offset = node.size * 0.5
	var tween: Tween = node.create_tween()
	tween.tween_property(node, "scale", Vector2.ONE * POP_SCALE, POP_IN_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2.ONE, POP_OUT_SECONDS)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- Küçük yapı taşları ---------------------------------------------------------------------------

## Düz, çizgisiz yuvarlak düğme (her durumda aynı zemin; basılınca hafif koyulaşır).
func _flat_button(color: Color, radius: int, min_height: float) -> Button:
	var button: Button = Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0.0, min_height)
	for state: String in ["normal", "hover", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, _box(color, radius))
	button.add_theme_stylebox_override("pressed", _box(color.darkened(0.06), radius))
	button.pressed.connect(UiKit.tap_sound)
	# Her dokunma hedefi aynı yumuşak basma hissini verir (kit ortak davranışı).
	UiKit.attach_press_scale(button)
	return button


func _box(color: Color, radius: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	return box


## Düğmenin içine tüm alanı kaplayan, ortalanmış içerik koyar (içerik dokunuşu yutmaz).
func _fill(button: Button, content: Control) -> void:
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(content)
	button.add_child(center)
