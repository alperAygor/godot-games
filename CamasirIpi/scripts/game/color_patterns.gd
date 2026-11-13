class_name ColorPatterns
extends RefCounted

## Renk körü dostu desenler: 7 renk paletinin her rengi kendi desenine sahiptir (varsayılan AÇIK).
## Renk ayrımı ton yerine ŞEKİLLE yapılabilsin diye: kırmızı düz, mavi dikey çizgi, sarı puan,
## yeşil kare, mor çapraz çizgi, turuncu zikzak, turkuaz artı.
## Üç yüzey: (1) çamaşır/katlı parça/sepet astarı = shader (cloth_sway / pattern_tint),
## (2) küçük noktalar/rozetler = glif atlası (`draw_glyph`), (3) ayar = `enabled()`.
## Desen numarası shader'daki `pattern_mask` numaralarıyla birebir aynıdır.

## game.gd COLORS paletinin kopyası: çamaşırın elinde yalnız Color vardır, desen için renk
## numarasını bundan buluruz. Birim test bu kopyanın game.gd ile aynı kalmasını doğrular.
const PALETTE: Array[Color] = [
	Color("e5484d"), Color("3e8ef7"), Color("f5c02e"), Color("3dbb6e"),
	Color("9b59d0"), Color("f58a3c"), Color("22b8b0"),
]
const NONE: int = -1
const SOLID: int = 0
const STRIPES_V: int = 1
const DOTS: int = 2
const CHECKS: int = 3
const STRIPES_DIAG: int = 4
const CHEVRON: int = 5
const CROSSES: int = 6
const PATTERN_COUNT: int = 7
## Renk numarası -> desen. Sıra değişirse kayıtlı oyunlarda renkler farklı desen alır: sabit tut.
const PATTERN_BY_COLOR: Array[int] = [SOLID, STRIPES_V, DOTS, CHECKS, STRIPES_DIAG, CHEVRON, CROSSES]

## Palet rengi sayılması için en çok uzaklık (RGB): kapalı/ıslak renk tonları buraya girmez,
## çünkü eşleme `color` alanından (asıl renk) yapılır.
const MATCH_TOLERANCE: float = 0.02
## Açık/koyu ton kararı eşiği (algısal parlaklık): parlak renk koyu baskı, koyu renk açık baskı alır.
const LIGHT_BELOW_LUMA: float = 0.55

## Kapalı (soluk) çamaşırda desen daha silik ama görünür.
const CLOSED_STRENGTH: float = 0.6
const GARMENT_CELLS: float = 8.0
## Çarşaf dokusu iki ipe gerilir: hücre sayısı genişlikle büyür ki desen devleşmesin, ama çarşafta
## hücre yine çamaşırınkinden bu kat iri kalır (küçücük de görünmesin).
const SHEET_CELL_GROWTH: float = 1.2
## Sprite tuvali, çamaşır boyunun bu katıdır (GarmentView.SPRITE_FILL ile aynı).
const CANVAS_RATIO: float = 1.14
## Katlanmış parça dokusu küçük (256 px) ve ekranda ~100 px: az hücre = iri, okunur desen.
const FOLDED_CELLS: float = 5.5
## Sepet astarı: tüp ince; hücre tüp kalınlığına yakın olmalı.
const BAND_CELLS: float = 15.0

const SETTING_SECTION: String = "settings"
const SETTING_KEY: String = "patterns"
## Ayar sayfasındaki anahtar için çeviri anahtarları (ayar satırını UI sahibi ekler).
const LABEL_KEY: String = "PATTERN_SETTING"
const HINT_KEY: String = "PATTERN_SETTING_HINT"

const SWAY_SHADER_PATH: String = "res://assets/shaders/cloth_sway.gdshader"
const TINT_SHADER_PATH: String = "res://assets/shaders/pattern_tint.gdshader"
const GLYPH_PATH: String = "res://assets/sprites/patterns/glyphs.png"
const FOLDED_FILE: String = "folded.png"
const GLYPH_CELL: float = 64.0
## Glif karesinin kenarı = yarıçap x bu oran (glifin kendi dairesi hücrenin %80'i: noktanın içinde kalır).
const GLYPH_SPAN: float = 2.1
const GLYPH_ALPHA_ON_DARK: float = 0.78
const GLYPH_ALPHA_ON_LIGHT: float = 0.55
const GLYPH_DARK: Color = Color(0.0, 0.0, 0.0, 1.0)

const P_ID: StringName = &"pattern_id"
const P_ID_B: StringName = &"pattern_id_b"
const P_SPLIT: StringName = &"pattern_split"
const P_CELLS: StringName = &"pattern_cells"
const P_STRENGTH: StringName = &"pattern_strength"
const P_LIGHT: StringName = &"pattern_light"
const P_LIGHT_B: StringName = &"pattern_light_b"
const P_SWAY: StringName = &"strength"
const META_STATE: StringName = &"_pattern_state"
const META_HOOKED: StringName = &"_pattern_hooked"

## -1 = henüz okunmadı; 0/1 = kapalı/açık. Ayar her çizimde diskten okunmasın.
static var _cached: int = -1
static var _glyphs: Texture2D = null
static var _tint_shader: Shader = null
## Renk numarası -> ortak astar materyali: aynı renkli sepetler aynı materyali paylaşır (toplu çizim) ve
## sepet her gelişinde yeni materyal üretilmez.
static var _band_cache: Dictionary = {}


# --- Ayar -----------------------------------------------------------------------------------

## Desenler açık mı? Kayıt yoksa AÇIK (kullanıcı kararı: varsayılan açık).
static func enabled() -> bool:
	if _cached < 0:
		var value: Variant = true
		var progress: Node = _progress()
		if progress != null:
			value = progress.call("module_value", SETTING_SECTION, SETTING_KEY, true)
		_cached = 1 if bool(value) else 0
	return _cached == 1


## `persist=false`: yalnız bellekte (test/ekran görüntüsü aracı oyuncu kaydına dokunmasın).
## Ayar değişince sahnedeki çamaşır/sepet/rozetler HEMEN yenilenir (`refresh_all`): ayar satırı
## ayrıca bir şey çağırmak zorunda kalmaz, desen bir sonraki seviyeyi beklemez.
static func set_enabled(value: bool, persist: bool = true) -> void:
	var changed: bool = _cached != (1 if value else 0)
	_cached = 1 if value else 0
	if changed:
		refresh_all(Engine.get_main_loop() as SceneTree)
	if not persist:
		return
	var progress: Node = _progress()
	if progress != null:
		progress.call("set_module_value", SETTING_SECTION, SETTING_KEY, value)


## Önbelleği unutur (kayıt sıfırlama/yükleme sonrası).
static func reset_cache() -> void:
	_cached = -1


## Ağaçtaki tüm desen yüzeylerini bugünkü ayara göre yeniler: çamaşır materyalleri, sepet astarı ve
## `_draw` ile çizilen glifler (kuyruk noktası, kilit/boya rozeti, sipariş hapı, makine yuvası).
## Neden ağaç gezisi: tek seferlik (ayar anahtarı çevrilince) ve yüzlerce düğümden fazla değil;
## her yüzeyi bir gruba kaydettirmek ek bağımlılık ve unutma riski getirirdi.
static func refresh_all(tree: SceneTree) -> void:
	if tree == null or tree.root == null:
		return
	_refresh_node(tree.root)


static func _refresh_node(node: Node) -> void:
	if node is GarmentView:
		(node as GarmentView).refresh_pattern()
	elif node is BasketView and node.get("_band_back") != null:
		# Astar materyali özel yöntemle verilir; sepet dosyası bu işin dışında kaldığı için çağrı dolaylıdır.
		node.call("_apply_band_pattern", node.get("color"))
	if node is CanvasItem and not (node is Sprite2D):
		(node as CanvasItem).queue_redraw()
	for child: Node in node.get_children():
		_refresh_node(child)


static func _progress() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("Progress")


# --- Eşleme ---------------------------------------------------------------------------------

## Renk numarasının deseni. Kapalıyken veya `hidden` (gizemli çamaşır: rengi sızdırır) iken NONE.
static func pattern_for(color_id: int, hidden: bool = false) -> int:
	if hidden or color_id < 0 or not enabled():
		return NONE
	return PATTERN_BY_COLOR[color_id % PATTERN_BY_COLOR.size()]


## Palet rengi -> renk numarası; palette yoksa (joker beyazı, gizem grisi) -1.
static func color_id_of(tint: Color) -> int:
	for index: int in range(PALETTE.size()):
		var ref: Color = PALETTE[index]
		if absf(ref.r - tint.r) + absf(ref.g - tint.g) + absf(ref.b - tint.b) <= MATCH_TOLERANCE:
			return index
	return -1


## 1 = açık tonlu baskı (koyu zemin), 0 = koyu tonlu baskı (açık zemin).
static func light_ink(color_id: int) -> float:
	if color_id < 0:
		return 0.0
	var ref: Color = PALETTE[color_id % PALETTE.size()]
	var luma: float = ref.r * 0.2126 + ref.g * 0.7152 + ref.b * 0.0722
	return 1.0 if luma < LIGHT_BELOW_LUMA else 0.0


# --- Çamaşır (shader) -----------------------------------------------------------------------

## Tek hamlede çamaşır materyali + katlı parça: `GarmentView._apply_color` bunu çağırır.
## `color_a` asıl renk (gizemde bile gerçek renk; desen `mystery` ile gizlenir). Çift renkli
## çamaşır için `apply_ids` iki renk numarası alır.
static func apply_garment(view: Node2D, material: ShaderMaterial, color_a: Color, mystery: bool, open: bool) -> void:
	var color_id: int = color_id_of(color_a)
	var strength: float = 1.0 if open else CLOSED_STRENGTH
	apply_ids(view, material, color_id, -1, strength, mystery)


## İki renk numarası: ikincisi geçerliyse sol yarı `id_a`, sağ yarı `id_b` deseni alır.
## İkinci rengin (çift renkli çamaşırın sağ-alt yarısı) deseni: yalnız ikinci katmanın kendi
## materyaline yazılır. Neden ayrı materyal: iki yarı aynı sprite'tır, tek materyalde tek desen olurdu.
static func apply_second(view: Node2D, material: ShaderMaterial, color_b: Color, hidden: bool, open: bool) -> void:
	var state: Dictionary = {
		"id": pattern_for(color_id_of(color_b), hidden),
		"id_b": NONE,
		"split": false,
		"strength": 1.0 if open else CLOSED_STRENGTH,
		"light": light_ink(color_id_of(color_b)),
		"light_b": 0.0,
	}
	_write(material, state, _garment_cells(view))


static func apply_ids(view: Node2D, material: ShaderMaterial, id_a: int, id_b: int, strength: float,
		hidden: bool) -> void:
	var split: bool = id_b >= 0 and id_b != id_a
	var state: Dictionary = {
		"id": pattern_for(id_a, hidden),
		"id_b": pattern_for(id_b, hidden) if split else NONE,
		"split": split,
		"strength": strength,
		"light": light_ink(id_a),
		"light_b": light_ink(id_b),
	}
	_write(material, state, _garment_cells(view))
	if view == null:
		return
	view.set_meta(META_STATE, state)
	if not view.has_meta(META_HOOKED):
		# Katlı sprite uçuşta sonradan eklenir: o an materyalini bu kanca verir.
		view.set_meta(META_HOOKED, true)
		view.child_entered_tree.connect(_on_view_child.bind(view))
		# `make_sheet` setup'tan hemen sonra çağrılır: çarşaf mı olduğu bir kare sonra bilinir.
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		if tree != null:
			# Lambda: aynı kare sinyaline bağlanan her çamaşır ayrı bağ olsun (bind'lı çağrılar eşit sayılıp yutuluyordu).
			var refine: Callable = func() -> void: _refine_cells(view, material)
			tree.process_frame.connect(refine, CONNECT_ONE_SHOT)
	var folded: Variant = view.get("_folded_sprite")
	if folded is Sprite2D:
		_style_folded(folded as Sprite2D, state)


## Çarşafta hücre sayısı genişliğe göre ölçeklenir (bkz. SHEET_CELL_GROWTH).
static func _garment_cells(view: Node2D) -> float:
	if view == null or not view.has_method("is_sheet") or not bool(view.call("is_sheet")):
		return GARMENT_CELLS
	var sheet: Vector2 = view.get("_sheet_size") as Vector2
	var size: float = float(view.get("size"))
	if size <= 0.0:
		return GARMENT_CELLS
	return GARMENT_CELLS * sheet.x / (size * CANVAS_RATIO) / SHEET_CELL_GROWTH


static func _refine_cells(view: Node2D, material: ShaderMaterial) -> void:
	if is_instance_valid(view) and material != null:
		material.set_shader_parameter(P_CELLS, _garment_cells(view))


static func _on_view_child(child: Node, view: Node2D) -> void:
	if child is Sprite2D and view.has_meta(META_STATE):
		_style_folded(child as Sprite2D, view.get_meta(META_STATE) as Dictionary)


## Katlanmış parça: sallanmayan aynı shader (strength 0) + iri hücreli desen. Gölge sprite'ı
## (materyali zaten var) ve mandal/rozetler atlanır.
static func _style_folded(sprite: Sprite2D, state: Dictionary) -> void:
	if sprite.texture == null or not sprite.texture.resource_path.ends_with(FOLDED_FILE):
		return
	var material: ShaderMaterial = sprite.material as ShaderMaterial
	if material == null:
		if sprite.material != null:
			return
		var shader: Shader = load(SWAY_SHADER_PATH) as Shader
		if shader == null:
			return
		material = ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter(P_SWAY, 0.0)
		sprite.material = material
	_write(material, state, FOLDED_CELLS)


static func _write(material: ShaderMaterial, state: Dictionary, cells: float) -> void:
	if material == null:
		return
	material.set_shader_parameter(P_ID, int(state["id"]))
	material.set_shader_parameter(P_ID_B, int(state["id_b"]))
	material.set_shader_parameter(P_SPLIT, bool(state["split"]))
	material.set_shader_parameter(P_STRENGTH, float(state["strength"]))
	material.set_shader_parameter(P_LIGHT, float(state["light"]))
	material.set_shader_parameter(P_LIGHT_B, float(state["light_b"]))
	material.set_shader_parameter(P_CELLS, cells)


# --- Sepet astarı ---------------------------------------------------------------------------

## Sepet astarı (arka + ön yarı) için ORTAK materyal: tek materyal = bir toplu çizim grubu.
## `color_id` -1 ise (joker henüz renksiz) desen yoktur; desen kapalıyken null döner
## (çağıran sprite.material = null yapar -> bugünkü görünüm).
static func band_material(color_id: int) -> ShaderMaterial:
	var id: int = pattern_for(color_id)
	if id < 1:
		return null
	if _band_cache.has(color_id):
		return _band_cache[color_id] as ShaderMaterial
	if _tint_shader == null:
		_tint_shader = load(TINT_SHADER_PATH) as Shader
	if _tint_shader == null:
		return null
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = _tint_shader
	material.set_shader_parameter(P_ID, id)
	material.set_shader_parameter(P_CELLS, BAND_CELLS)
	material.set_shader_parameter(P_LIGHT, light_ink(color_id))
	_band_cache[color_id] = material
	return material


# --- Glif (küçük noktalar, rozetler, kartlar) -----------------------------------------------

## 7 hücreli beyaz glif atlası (assets/sprites/patterns/glyphs.png).
static func glyph_texture() -> Texture2D:
	if _glyphs == null and ResourceLoader.exists(GLYPH_PATH):
		_glyphs = load(GLYPH_PATH) as Texture2D
	return _glyphs


## Atlas içindeki hücre (piksel).
static func glyph_region(color_id: int) -> Rect2:
	var cell: int = PATTERN_BY_COLOR[posmod(color_id, PATTERN_BY_COLOR.size())]
	return Rect2(float(cell) * GLYPH_CELL, 0.0, GLYPH_CELL, GLYPH_CELL)


## Noktanın içine desen glifi çizer. `canvas` `_draw` içindeki düğüm; `radius` noktanın yarıçapı;
## Glifin koyu/açık tonu renk numarasından seçilir. Desen kapalı / düz renk: hiçbir şey çizmez.
## `alpha_scale`: üstüne sayı yazılan rozetlerde glifi biraz silikleştirir (sayı okunur kalsın).
static func draw_glyph(canvas: CanvasItem, center: Vector2, radius: float, color_id: int,
		alpha_scale: float = 1.0) -> void:
	if pattern_for(color_id) < 1:
		return
	var atlas: Texture2D = glyph_texture()
	if atlas == null:
		return
	var side: float = radius * GLYPH_SPAN
	var rect: Rect2 = Rect2(center - Vector2(side, side) * 0.5, Vector2(side, side))
	var dark_ink: bool = light_ink(color_id) < 0.5
	var ink: Color = Color(GLYPH_DARK.r, GLYPH_DARK.g, GLYPH_DARK.b, GLYPH_ALPHA_ON_LIGHT * alpha_scale) if dark_ink \
		else Color(1.0, 1.0, 1.0, GLYPH_ALPHA_ON_DARK * alpha_scale)
	canvas.draw_texture_rect_region(atlas, rect, glyph_region(color_id), ink)


## Dikdörtgen içine ortalanmış glif (rozet/kart için kısayol).
static func draw_glyph_rect(canvas: CanvasItem, rect: Rect2, color_id: int) -> void:
	draw_glyph(canvas, rect.get_center(), minf(rect.size.x, rect.size.y) * 0.5, color_id)
