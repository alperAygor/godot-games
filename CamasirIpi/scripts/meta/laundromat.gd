class_name MetaLaundromat
extends CanvasLayer

## Çamaşırhane tadilat ekranı (tam ekran katman). Oda, Blender'da aynı kamerayla render
## edilmiş saydam katmanlardan kurulur (assets/sprites/meta/room_<yuva>_<durum>.png,
## yerleşimi laundromat_layers.json). Her görev bir yuvayı "eski"den "yeni N"e çevirir.
## Ekran yalnız GÖSTERİR; kurallar MetaState'te, kalıcılık MetaStore'da.
##
## Akış: alt kartta sıradaki görev + yıldız bedeli -> dokun -> yıldız harcanır, eşya yumuşak
## bir "açılma" ve parıltıyla yenilenir -> kart 3 renk örneğine döner (anında önizleme,
## ücretsiz) -> onay. Bitmiş bir eşyaya odada dokunmak da görünüm seçimini açar.
## Mekân bitince jeton ödülü + sıradaki mekânların zarif kilitli kartları gösterilir.
##
## Kullanım (yönetmen): `MetaLaundromat.open(self)` — kapanınca `closed` yayılır.

signal closed
## Ekran tamamen opak olunca true (açılış solması bitti), kapanış başlarken false. Ana ekran
## bununla arkada kalan (görünmeyen) bahçeyi çizmeyi/işlemeyi durdurur: mobilde boşa piksel doldurma.
signal covering_changed(covering: bool)

const SCENE_PATH: String = "res://scenes/meta/Laundromat.tscn"
const LAYER_DIR: String = "res://assets/sprites/meta/"
const LAYER_FORMAT: String = "room_%s_%s"
const MANIFEST_PATH: String = "res://assets/sprites/meta/laundromat_layers.json"
const STATE_OLD: String = "old"
const CANVAS: Vector2 = Vector2(1080.0, 1920.0)

## Oda "ruh hâli": tadilat ilerledikçe soluk/sıcak-gri tondan tam renge geçer.
const MOOD_OLD: Color = Color(0.97, 0.955, 0.94)
const MOOD_SECONDS: float = 1.2
## Katman büyüklüğü bu oranı aşarsa (zemin/duvar) "açılma" yerine yumuşak çapraz geçiş.
const BIG_LAYER_SHARE: float = 0.25
const REVEAL_OUT_SECONDS: float = 0.28
const REVEAL_IN_SECONDS: float = 0.62
const REVEAL_FROM_SCALE: float = 0.9
const CROSSFADE_SECONDS: float = 0.7
const SWAP_SECONDS: float = 0.32
const SWAP_FROM_SCALE: float = 0.96
## Askıda duran eşyalar (tepeden sallanır/açılır); diğerleri tabandan büyür.
const TOP_PIVOT_SLOTS: Array[String] = ["lamp", "sign"]
const LAMP_SWAY_DEGREES: float = 0.5
const LAMP_SWAY_SECONDS: float = 5.5
## Dokunma testi: gölge pikselleri (yarı saydam) eşya sayılmasın.
const HIT_ALPHA: float = 0.6
const HALF_ALPHA_STEP: float = 0.5 / 255.0
const TAP_MAX_TRAVEL: float = 24.0

# Alt kart
const THUMB_DIAMETER: float = 150.0
const THUMB_FILL: float = 0.78
const THUMB_DISC: Color = Color("efe9dc")
## Zemin/duvar küçük resmi: katmanın ortasından bu boyda kare kırpılır.
const BIG_THUMB_CROP: float = 360.0
## Kesitin dikey konumu (0 üst, 1 alt): duvarda lambri+süpürgelik görünsün, düz boya değil.
const BIG_THUMB_FOCUS: Dictionary[String, float] = {"wall": 0.95}
const BIG_THUMB_FOCUS_DEFAULT: float = 0.55
## Boyu eninin bu katından uzun katmanlarda küçük resim alttan kare kesilir.
const TALL_LAYER_RATIO: float = 1.6
## Uzun ekranda zemini uzatmak için esnetilen alt şerit (doku pikseli).
const FLOOR_STRIP: float = 6.0
const COST_WIDTH: float = 230.0
const COST_HEIGHT: float = 124.0
const NAME_SIZE: int = 44
const SUB_SIZE: int = 30
const CARD_FADE_SECONDS: float = 0.24
const SHAKE_PIXELS: float = 14.0
const SHAKE_SECONDS: float = 0.36
const SWATCH_GAP: int = 40
const TILE_COLOR: Color = Color("f1ece1")
const TILE_RADIUS: int = 36
const TILE_HEIGHT: float = 190.0
const LOCKED_ALPHA: float = 0.55
const DONE_DISC: float = 88.0
const STAR_COLOR: Color = Color("f2b63d")

# Üst çubuk
const TITLE_SIZE: int = 30
const BAR_SIZE: Vector2 = Vector2(260.0, 12.0)
const BAR_TRACK: Color = Color(0.18, 0.23, 0.21, 0.1)

# Toz zerreleri (pencereden giren ışıkta süzülen ince noktalar — sakin his)
const MOTE_COUNT: int = 9
const MOTE_RADIUS: Vector2 = Vector2(5.0, 11.0)
const MOTE_ALPHA: float = 0.32
const MOTE_SPEED: float = 9.0
const MOTE_DRIFT: float = 22.0
const LAMP_GLOW_RADIUS: float = 170.0
const LAMP_GLOW_ALPHA: Vector2 = Vector2(0.22, 0.32)
const LAMP_GLOW_OLD_ALPHA: Vector2 = Vector2(0.06, 0.12)
const LAMP_GLOW_SECONDS: float = 2.8

enum CardMode { NEXT, CHOOSE, DONE }

var store: MetaStore = null
var _view: Vector2 = CANVAS
var _insets: Vector4 = Vector4.ZERO
var _root: Control = null
var _room: Control = null
var _floor_extension: TextureRect = null
var _effects: Node2D = null
var _layers: Dictionary[String, TextureRect] = {}
var _manifest: Dictionary = {}
var _anchors: Dictionary = {}
var _masks: Dictionary[String, BitMap] = {}
var _star_chip: UiChip = null
var _coin_chip: UiChip = null
var _title: Label = null
var _bar: MetaBar = null
var _card: PanelContainer = null
var _card_box: VBoxContainer = null
var _mode: CardMode = CardMode.NEXT
var _choose_task: int = -1
var _swatches: Array[MetaSwatch] = []
var _cost_button: Button = null
var _hint: Label = null
var _last_bonus: int = 0
var _art_location: int = 0
var _closing: bool = false
var _press_at: Vector2 = Vector2.ZERO
var _pressing: bool = false
var _motes: Array[Sprite2D] = []
var _mote_seeds: Array[Vector3] = []
var _mote_area: Rect2 = Rect2()
var _lamp_glow: Sprite2D = null
var _time: float = 0.0


## Tam ekran katman olarak açar; geri düğmesi/tuşu ile kapanır ve `closed` yayar.
static func open(parent: Node) -> Node:
	var node: MetaLaundromat = (load(SCENE_PATH) as PackedScene).instantiate() as MetaLaundromat
	parent.add_child(node)
	return node


func _ready() -> void:
	layer = MetaUi.LAYER
	if store == null:
		store = MetaStore.new()
	_load_manifest()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_room_input)
	add_child(_root)
	_view = _root.get_viewport_rect().size
	_insets = UiKit.safe_insets(_view)
	_build_room()
	_build_top_bar()
	_build_card()
	var progress: Node = store.progress()
	if progress != null and progress.has_signal("changed"):
		progress.connect("changed", _on_progress_changed)
	MetaUi.connect_back(_on_back)
	_refresh_room(false)
	_refresh_header(false)
	_show_card(_default_mode(), false)
	_root.modulate.a = 0.0
	var intro: Tween = create_tween()
	intro.tween_property(_root, "modulate:a", 1.0, Motion.OVERLAY_FADE_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	intro.tween_callback(_on_intro_done)


## Yumuşakça kapanır, `closed` yayar ve kendini siler.
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


# --- Oda ---------------------------------------------------------------------------

func _load_manifest() -> void:
	if not FileAccess.file_exists(MANIFEST_PATH):
		push_warning("MetaLaundromat: %s yok (tools/blender/make_meta.py)" % MANIFEST_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if parsed is Dictionary:
		var layers: Variant = (parsed as Dictionary).get("layers", {})
		if layers is Dictionary:
			_manifest = layers as Dictionary
		var anchors: Variant = (parsed as Dictionary).get("anchors", {})
		if anchors is Dictionary:
			_anchors = anchors as Dictionary


func _build_room() -> void:
	# Oda üste yaslanır (duvar tepesi üst çubuğun arkasında kalır). Uzun ekranlarda zemin
	# aşağı doğru UZATILIR: zemin katmanının en alt şeridi esnetilir — perspektifte tahta/karo
	# çizgileri alta doğru neredeyse dikey olduğundan devam ediyormuş gibi okunur (düz renk
	# dolgusu ise belirgin bir dikiş bırakıyordu).
	var scale_factor: float = _view.x / CANVAS.x
	var room_height: float = CANVAS.y * scale_factor
	_room = Control.new()
	_room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_room.size = CANVAS
	_room.scale = Vector2(scale_factor, scale_factor)
	_room.position = Vector2.ZERO
	_root.add_child(_room)
	_floor_extension = TextureRect.new()
	_floor_extension.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_floor_extension.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_floor_extension.stretch_mode = TextureRect.STRETCH_SCALE
	_floor_extension.position = Vector2(0.0, room_height - 1.0)
	_floor_extension.size = Vector2(_view.x, maxf(_view.y - room_height + 1.0, 0.0))
	_floor_extension.visible = _floor_extension.size.y > 1.0
	_root.add_child(_floor_extension)
	_effects = Node2D.new()
	_room.add_child(_effects)
	_build_ambience()


## Yuvanın şu an göstermesi gereken katman adı ("" = boş, ör. tabelanın eski hâli yok).
func _layer_name(slot: String) -> String:
	var catalog: MetaCatalog = store.catalog
	var task: int = catalog.task_index(_art_location, slot)
	var variant: int = store.state.variant(catalog, _art_location, task) if task >= 0 else -1
	var entry_name: String = LAYER_FORMAT % [slot, STATE_OLD if variant < 0 else str(variant)]
	return entry_name if _manifest.has(entry_name) else ""


func _layer_rect(entry_name: String) -> Rect2:
	var raw: Variant = _manifest.get(entry_name, [])
	if raw is Array and (raw as Array).size() == 4:
		var values: Array = raw as Array
		return Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))
	return Rect2()


func _make_layer(entry_name: String, slot: String) -> TextureRect:
	var rect: TextureRect = TextureRect.new()
	rect.texture = load(LAYER_DIR + entry_name + ".png") as Texture2D
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	var area: Rect2 = _layer_rect(entry_name)
	rect.position = area.position
	rect.size = area.size
	rect.pivot_offset = Vector2(area.size.x * 0.5, 0.0 if TOP_PIVOT_SLOTS.has(slot) else area.size.y)
	rect.set_meta(&"layer_name", entry_name)
	return rect


## Tüm yuvaları durumdan yeniden kurar (açılışta ya da animasyonsuz yenilemede).
func _refresh_room(animated: bool) -> void:
	var catalog: MetaCatalog = store.catalog
	_art_location = _last_art_location()
	for slot: String in catalog.draw_order:
		var entry_name: String = _layer_name(slot)
		var current: TextureRect = _layers.get(slot) as TextureRect
		var current_name: String = String(current.get_meta(&"layer_name", "")) if current != null else ""
		if current_name == entry_name:
			continue
		if current != null:
			current.queue_free()
			_layers.erase(slot)
		if entry_name.is_empty():
			continue
		var rect: TextureRect = _make_layer(entry_name, slot)
		_room.add_child(rect)
		_layers[slot] = rect
	_restack()
	_apply_mood(animated)
	_update_fills()
	_update_lamp()


## Çizim sırası katalogdaki `draw_order`; efektler en üstte.
func _restack() -> void:
	var index: int = 0
	for slot: String in store.catalog.draw_order:
		var rect: TextureRect = _layers.get(slot) as TextureRect
		if rect != null and is_instance_valid(rect):
			_room.move_child(rect, index)
			index += 1
	_room.move_child(_effects, _room.get_child_count() - 1)


## Sanatı olan son açık mekân (sanatı olmayan sonraki mekânlarda bitmiş oda gösterilir).
func _last_art_location() -> int:
	var catalog: MetaCatalog = store.catalog
	var current: int = store.state.current_location(catalog)
	for index: int in range(current, -1, -1):
		if catalog.location_has_art(index):
			return index
	return 0


func _apply_mood(animated: bool) -> void:
	var progress: float = store.state.location_progress(store.catalog, _art_location)
	var target: Color = MOOD_OLD.lerp(Color.WHITE, Motion.ease_out(progress))
	if not animated:
		_room.modulate = target
		_floor_extension.modulate = target
		return
	var tween: Tween = create_tween().set_parallel(true)
	for node: CanvasItem in [_room, _floor_extension]:
		tween.tween_property(node, "modulate", target, MOOD_SECONDS).set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN_OUT)


## Uzun ekranlarda zeminin devamı: güncel zemin katmanının alt şeridi (oda tonuyla).
func _update_fills() -> void:
	if not _floor_extension.visible:
		return
	var floor_rect: TextureRect = _layers.get("floor") as TextureRect
	if floor_rect == null or floor_rect.texture == null:
		return
	var strip: AtlasTexture = AtlasTexture.new()
	strip.atlas = floor_rect.texture
	var tex_size: Vector2 = floor_rect.texture.get_size()
	strip.region = Rect2(0.0, tex_size.y - FLOOR_STRIP, tex_size.x, FLOOR_STRIP)
	_floor_extension.texture = strip


## Dokunma maskesi (1 bit/piksel). Neden Image değil: tam RGBA kopyası katman başına ~4 MB RAM
## tutuyordu (duvar/zemin); isabet testi yalnız "alfa >= HIT_ALPHA mı" sorar. Görüntü maskeye
## çevrilip hemen bırakılır. Sıkıştırılmış doku açılabiliyorsa açılır (yoksa dikdörtgen testi).
func _mask_for(rect: TextureRect) -> BitMap:
	var entry_name: String = String(rect.get_meta(&"layer_name", ""))
	if _masks.has(entry_name):
		return _masks[entry_name]
	var mask: BitMap = null
	var image: Image = rect.texture.get_image() if rect.texture != null else null
	if image != null and image.is_compressed() and image.decompress() != OK:
		image = null
	if image != null:
		mask = BitMap.new()
		# BitMap "alfa > eşik" der; eski test "alfa >= HIT_ALPHA" idi: yarım 8 bit adım aşağı = birebir aynı.
		mask.create_from_image_alpha(image, HIT_ALPHA - HALF_ALPHA_STEP)
	_masks[entry_name] = mask
	return mask


## Görevi yenilenmiş hâline geçirir: eski eşya küçülüp söner, yenisi yumuşakça açılır.
func _reveal(slot: String, big_sparkle: bool) -> void:
	var entry_name: String = _layer_name(slot)
	var old: TextureRect = _layers.get(slot) as TextureRect
	if entry_name.is_empty():
		return
	var fresh: TextureRect = _make_layer(entry_name, slot)
	_room.add_child(fresh)
	_layers[slot] = fresh
	_restack()
	if old != null and is_instance_valid(old):
		# Eski katman yeninin hemen altında kalsın: geçiş sırasında arkası boş görünmesin.
		_room.move_child(old, fresh.get_index())
	var area: Rect2 = _layer_rect(entry_name)
	var big: bool = area.get_area() > CANVAS.x * CANVAS.y * BIG_LAYER_SHARE
	if big:
		fresh.modulate.a = 0.0
		var fade: Tween = create_tween()
		fade.tween_property(fresh, "modulate:a", 1.0, CROSSFADE_SECONDS).set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN_OUT)
		if old != null and is_instance_valid(old):
			fade.tween_callback(old.queue_free)
	else:
		if old != null and is_instance_valid(old):
			var out: Tween = create_tween().set_parallel(true)
			out.tween_property(old, "modulate:a", 0.0, REVEAL_OUT_SECONDS).set_trans(Tween.TRANS_SINE)\
				.set_ease(Tween.EASE_IN)
			out.tween_property(old, "scale", Vector2.ONE * REVEAL_FROM_SCALE, REVEAL_OUT_SECONDS)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			out.chain().tween_callback(old.queue_free)
		fresh.modulate.a = 0.0
		fresh.scale = Vector2.ONE * REVEAL_FROM_SCALE
		var reveal: Tween = create_tween().set_parallel(true)
		reveal.tween_property(fresh, "modulate:a", 1.0, REVEAL_IN_SECONDS * 0.5).set_delay(REVEAL_OUT_SECONDS * 0.6)
		reveal.tween_property(fresh, "scale", Vector2.ONE, REVEAL_IN_SECONDS).set_delay(REVEAL_OUT_SECONDS * 0.6)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var center: Vector2 = _sparkle_center(slot, area)
	var spread: float = clampf(minf(area.size.x, area.size.y) * 0.5, 90.0, 260.0)
	get_tree().create_timer(REVEAL_OUT_SECONDS * 0.6).timeout.connect(
		_sparkle.bind(center, spread, big_sparkle))
	_apply_mood(true)
	_update_lamp()
	get_tree().create_timer(CROSSFADE_SECONDS).timeout.connect(_update_fills)


## Yalnız görünüm değişimi (varyant): hızlı çapraz geçiş + küçük parıltı.
func _swap(slot: String) -> void:
	var entry_name: String = _layer_name(slot)
	var old: TextureRect = _layers.get(slot) as TextureRect
	if entry_name.is_empty():
		return
	var fresh: TextureRect = _make_layer(entry_name, slot)
	_room.add_child(fresh)
	_layers[slot] = fresh
	_restack()
	if old != null and is_instance_valid(old):
		_room.move_child(old, fresh.get_index())
	fresh.modulate.a = 0.0
	var area: Rect2 = _layer_rect(entry_name)
	var big: bool = area.get_area() > CANVAS.x * CANVAS.y * BIG_LAYER_SHARE
	if not big:
		fresh.scale = Vector2.ONE * SWAP_FROM_SCALE
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(fresh, "modulate:a", 1.0, SWAP_SECONDS).set_trans(Tween.TRANS_SINE)
	tween.tween_property(fresh, "scale", Vector2.ONE, SWAP_SECONDS * 1.4).set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	if old != null and is_instance_valid(old):
		tween.chain().tween_callback(old.queue_free)
	if not big:
		MetaSparkle.burst(_effects, _sparkle_center(slot, area), clampf(area.size.x * 0.35, 70.0, 180.0),
			Motion.SPARKLE_COUNT / 2)
	MetaUi.play_sound("ui_soft", 1.12, -6.0)
	_update_lamp()
	get_tree().create_timer(SWAP_SECONDS).timeout.connect(_update_fills)


func _sparkle_center(slot: String, area: Rect2) -> Vector2:
	if slot == "floor":
		return Vector2(CANVAS.x * 0.5, area.position.y + area.size.y * 0.35)
	if slot == "wall":
		return Vector2(CANVAS.x * 0.5, area.position.y + area.size.y * 0.45)
	return area.get_center()


func _sparkle(center: Vector2, spread: float, big: bool) -> void:
	MetaSparkle.burst(_effects, center, spread, Motion.SPARKLE_COUNT if big else Motion.SPARKLE_COUNT / 2)
	MetaUi.play_sound("sparkle", 1.0, -2.0)


# --- Ortam ---------------------------------------------------------------------------

func _build_ambience() -> void:
	var window: Variant = _anchors.get("window", [])
	_mote_area = Rect2(80.0, 200.0, 560.0, 900.0)
	if window is Array and (window as Array).size() == 4:
		var values: Array = window as Array
		_mote_area = Rect2(float(values[0]), float(values[1]), float(values[2]) * 1.6, float(values[3]) * 2.0)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for _index: int in range(MOTE_COUNT):
		var mote: Sprite2D = GlowTextures.make_sprite(GlowTextures.dot(), rng.randf_range(MOTE_RADIUS.x, MOTE_RADIUS.y), true)
		mote.modulate = Color(1.0, 0.97, 0.88, MOTE_ALPHA)
		_effects.add_child(mote)
		_motes.append(mote)
		_mote_seeds.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(0.6, 1.4)))
	_lamp_glow = GlowTextures.make_sprite(GlowTextures.halo(), LAMP_GLOW_RADIUS, true)
	_lamp_glow.modulate = Color(1.0, 0.86, 0.6, 0.0)
	_effects.add_child(_lamp_glow)


func _update_lamp() -> void:
	var lamp: TextureRect = _layers.get("lamp") as TextureRect
	if lamp == null or not is_instance_valid(lamp):
		return
	if not lamp.has_meta(&"swaying"):
		lamp.set_meta(&"swaying", true)
		lamp.rotation_degrees = -LAMP_SWAY_DEGREES
		var sway: Tween = lamp.create_tween().set_loops()
		sway.tween_property(lamp, "rotation_degrees", LAMP_SWAY_DEGREES, LAMP_SWAY_SECONDS * 0.5)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		sway.tween_property(lamp, "rotation_degrees", -LAMP_SWAY_DEGREES, LAMP_SWAY_SECONDS * 0.5)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _process(delta: float) -> void:
	_time += delta
	for index: int in range(_motes.size()):
		var mote_seed: Vector3 = _mote_seeds[index]
		var travel: float = fposmod(mote_seed.y + _time * MOTE_SPEED * mote_seed.z / _mote_area.size.y, 1.0)
		var x: float = _mote_area.position.x + mote_seed.x * _mote_area.size.x \
			+ sin(_time * 0.4 * mote_seed.z + mote_seed.x * TAU) * MOTE_DRIFT
		var y: float = _mote_area.end.y - travel * _mote_area.size.y
		_motes[index].position = Vector2(x, y)
		# Uçlarda sönerek doğar/kaybolur: zerreler "belirip kaybolur", sınırda atlamaz.
		_motes[index].modulate.a = MOTE_ALPHA * sin(travel * PI)
	_update_lamp_glow()


func _update_lamp_glow() -> void:
	var lamp: TextureRect = _layers.get("lamp") as TextureRect
	var bulb: Variant = _anchors.get("lamp_bulb", [])
	if lamp == null or not is_instance_valid(lamp) or not (bulb is Array) or (bulb as Array).size() != 2:
		_lamp_glow.visible = false
		return
	_lamp_glow.visible = true
	var anchor: Vector2 = Vector2(float((bulb as Array)[0]), float((bulb as Array)[1]))
	# Ampul lambayla birlikte sallanır: tepe noktası etrafında aynı açıyla döndürülür.
	var pivot: Vector2 = lamp.position + lamp.pivot_offset
	_lamp_glow.position = pivot + (anchor - pivot).rotated(lamp.rotation)
	var renovated: bool = String(lamp.get_meta(&"layer_name", "")).ends_with(STATE_OLD) == false
	var range_alpha: Vector2 = LAMP_GLOW_ALPHA if renovated else LAMP_GLOW_OLD_ALPHA
	var wave: float = 0.5 + 0.5 * sin(_time * TAU / LAMP_GLOW_SECONDS)
	_lamp_glow.modulate.a = lerpf(range_alpha.x, range_alpha.y, wave) * lamp.modulate.a


# --- Üst çubuk -----------------------------------------------------------------------

func _build_top_bar() -> void:
	var back: UiIconButton = MetaUi.back_button(_view, _insets)
	back.pressed.connect(close)
	_root.add_child(back)
	_star_chip = MetaUi.counter_chip("lucide/star", STAR_COLOR)
	_root.add_child(_star_chip)
	_star_chip.set_value(store.stars(), false)
	MetaUi.place_right(_star_chip, _view, _insets)
	var head: PanelContainer = PanelContainer.new()
	head.theme_type_variation = &"ChipPanel"
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(column)
	_title = UiKit.label("", TITLE_SIZE)
	column.add_child(_title)
	_bar = MetaBar.new()
	_bar.setup(BAR_SIZE, UiKit.ACCENT, BAR_TRACK)
	column.add_child(_bar)
	_root.add_child(head)
	head.set_meta(&"center_y", _insets.y + UiKit.MIN_TOUCH * 0.5)
	head.resized.connect(_center_head.bind(head))
	_center_head(head)


func _center_head(head: PanelContainer) -> void:
	var head_size: Vector2 = head.get_combined_minimum_size()
	head.size = head_size
	head.position = Vector2((_view.x - head_size.x) * 0.5, float(head.get_meta(&"center_y")) - head_size.y * 0.5)


func _refresh_header(animated: bool) -> void:
	var catalog: MetaCatalog = store.catalog
	_title.text = MetaStrings.location_name(catalog.location_id(_art_location))
	_bar.set_value(store.state.location_progress(catalog, _art_location), animated)


func _on_progress_changed() -> void:
	if _star_chip != null:
		_star_chip.set_value(store.stars())
	if _coin_chip != null:
		_coin_chip.set_value(store.coins())
	if _mode == CardMode.NEXT:
		_update_cost_button()


# --- Alt kart ------------------------------------------------------------------------

func _build_card() -> void:
	_card = PanelContainer.new()
	_card.theme_type_variation = &"SheetPanel"
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_card)
	_card_box = VBoxContainer.new()
	_card_box.add_theme_constant_override("separation", 0)
	_card_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_card_box)
	_card.resized.connect(_place_card)


func _place_card() -> void:
	var width: float = _view.x - _insets.x - _insets.z - MetaUi.CARD_SIDE_GAP * 2.0
	var height: float = _card.get_combined_minimum_size().y
	_card.size = Vector2(width, height)
	var gap: float = maxf(_insets.w, UiKit.MIN_BOTTOM_MARGIN)
	_card.position = Vector2(_insets.x + MetaUi.CARD_SIDE_GAP, _view.y - gap - height)


func _default_mode() -> CardMode:
	var catalog: MetaCatalog = store.catalog
	var current: int = store.state.current_location(catalog)
	if not catalog.location_has_art(current) or store.state.next_task(catalog) < 0:
		return CardMode.DONE
	return CardMode.NEXT


func _show_card(mode: CardMode, animated: bool = true) -> void:
	_mode = mode
	# Hemen ağaçtan çıkar: silinmeyi bekleyen eski içerik kartın boy hesabına karışmasın.
	for child: Node in _card_box.get_children():
		_card_box.remove_child(child)
		child.queue_free()
	_swatches.clear()
	_cost_button = null
	_hint = null
	_coin_chip = null
	match mode:
		CardMode.NEXT:
			_fill_next()
		CardMode.CHOOSE:
			_fill_choose()
		CardMode.DONE:
			_fill_done()
	_place_card.call_deferred()
	if animated:
		_card_box.modulate.a = 0.0
		create_tween().tween_property(_card_box, "modulate:a", 1.0, CARD_FADE_SECONDS)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _fill_next() -> void:
	var catalog: MetaCatalog = store.catalog
	var task: int = store.state.next_task(catalog)
	var id: String = catalog.task_id(_art_location, task)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 32)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_box.add_child(row)
	row.add_child(_thumbnail(id))
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	var entry_name: Label = UiKit.label(MetaStrings.task_name(id), NAME_SIZE)
	entry_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(entry_name)
	_hint = UiKit.label("", SUB_SIZE, UiKit.TEXT_MUTED)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(_hint)
	_cost_button = UiKit.button(MetaStrings.COST_FORMAT % catalog.task_cost(_art_location, task), &"",
		"lucide/star", COST_HEIGHT)
	_cost_button.custom_minimum_size = Vector2(COST_WIDTH, COST_HEIGHT)
	_cost_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_cost_button.pivot_offset = Vector2(COST_WIDTH, COST_HEIGHT) * 0.5
	_cost_button.pressed.connect(_on_cost_pressed)
	row.add_child(_cost_button)
	_update_cost_button()


## Yıldız yetmiyorsa düğme ikincil (soluk) görünür, alt satırda nazik ipucu durur.
func _update_cost_button() -> void:
	if _cost_button == null or not is_instance_valid(_cost_button):
		return
	var affordable: bool = store.state.can_afford_next(store.catalog, store.stars())
	_cost_button.theme_type_variation = &"" if affordable else &"SecondaryButton"
	var tint: Color = Color.WHITE if affordable else UiKit.TEXT
	for node: Node in _cost_button.find_children("*", "Label", true, false):
		(node as Label).add_theme_color_override("font_color", tint)
	for node: Node in _cost_button.find_children("*", "TextureRect", true, false):
		(node as TextureRect).modulate = STAR_COLOR if not affordable else Color.WHITE
	var catalog: MetaCatalog = store.catalog
	_hint.text = MetaStrings.PROGRESS_FORMAT % [store.state.done_count(catalog, _art_location),
		catalog.task_count(_art_location)] if affordable else MetaStrings.need_stars()


func _thumbnail(task_id: String) -> Control:
	var holder: Control = Control.new()
	holder.custom_minimum_size = Vector2(THUMB_DIAMETER, THUMB_DIAMETER)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(MetaUi.disc(THUMB_DIAMETER, THUMB_DISC))
	var entry_name: String = LAYER_FORMAT % [task_id, "0"]
	if not _manifest.has(entry_name):
		return holder
	var texture: Texture2D = load(LAYER_DIR + entry_name + ".png") as Texture2D
	var picture: TextureRect = TextureRect.new()
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var area: Rect2 = _layer_rect(entry_name)
	if area.get_area() > CANVAS.x * CANVAS.y * BIG_LAYER_SHARE:
		# Zemin/duvar: katmanın ortasından kare kesit, daire maskeli (doku "örneği" gibi).
		# NEDEN shader bölgesi: doku GPU-sıkıştırmalıdır; CPU'da açıp kırpmak ("Zemin" küçük resmi)
		# bozuk görünüyordu. Kesit artık GPU'da, UV bölgesiyle örneklenir (bkz. MetaUi.circle_region_mask).
		var tex_size: Vector2 = texture.get_size()
		var crop: float = minf(BIG_THUMB_CROP * tex_size.x / area.size.x, minf(tex_size.x, tex_size.y))
		var focus: float = float(BIG_THUMB_FOCUS.get(task_id, BIG_THUMB_FOCUS_DEFAULT))
		var origin: Vector2 = (tex_size - Vector2(crop, crop)) * Vector2(0.5, focus)
		picture.texture = texture
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_SCALE
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		picture.material = MetaUi.circle_region_mask(Rect2(origin / tex_size, Vector2(crop, crop) / tex_size))
		picture.size = Vector2(THUMB_DIAMETER, THUMB_DIAMETER)
	else:
		picture.texture = texture
		if area.size.y > area.size.x * TALL_LAYER_RATIO:
			# Uzun ince katman (tavandan sarkan lamba): kablo değil eşyanın kendisi görünsün.
			var tall: AtlasTexture = AtlasTexture.new()
			tall.atlas = texture
			var tex_size: Vector2 = texture.get_size()
			tall.region = Rect2(0.0, tex_size.y - tex_size.x, tex_size.x, tex_size.x)
			picture.texture = tall
		var inner: float = THUMB_DIAMETER * THUMB_FILL
		picture.size = Vector2(inner, inner)
		picture.position = Vector2(THUMB_DIAMETER - inner, THUMB_DIAMETER - inner) * 0.5
	holder.add_child(picture)
	return holder


func _on_cost_pressed() -> void:
	if not store.state.can_afford_next(store.catalog, store.stars()):
		_shake(_cost_button)
		MetaUi.play_sound("blocked", 1.0, -6.0)
		return
	var result: Dictionary = store.renovate_next()
	if not bool(result.get("ok", false)):
		_shake(_cost_button)
		return
	var task: int = int(result["task"])
	_last_bonus = int(result.get("bonus", 0))
	var slot: String = store.catalog.task_id(int(result["location"]), task)
	_reveal(slot, true)
	_refresh_header(true)
	_choose_task = task
	_show_card(CardMode.CHOOSE)


func _shake(node: Control) -> void:
	if node == null or not is_instance_valid(node):
		return
	var origin: float = node.position.x
	var tween: Tween = create_tween()
	var step: float = SHAKE_SECONDS / 5.0
	for offset: float in [SHAKE_PIXELS, -SHAKE_PIXELS * 0.8, SHAKE_PIXELS * 0.5, -SHAKE_PIXELS * 0.25, 0.0]:
		tween.tween_property(node, "position:x", origin + offset, step).set_trans(Tween.TRANS_SINE)


func _fill_choose() -> void:
	var catalog: MetaCatalog = store.catalog
	var id: String = catalog.task_id(_art_location, _choose_task)
	var head: HBoxContainer = HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_box.add_child(head)
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(column)
	var entry_name: Label = UiKit.label(MetaStrings.task_name(id), NAME_SIZE)
	entry_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(entry_name)
	var sub: Label = UiKit.label(MetaStrings.pick_look(), SUB_SIZE, UiKit.TEXT_MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(sub)
	var confirm: UiIconButton = UiIconButton.new()
	confirm.setup("lucide/check")
	confirm.disc_color = UiKit.ACCENT
	confirm.icon_color = Color.WHITE
	confirm.pressed.connect(_on_confirm)
	head.add_child(confirm)
	_card_box.add_child(UiKit.spacer(18.0))
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", SWATCH_GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_box.add_child(row)
	var selected: int = store.state.variant(catalog, _art_location, _choose_task)
	var colors: Array[Color] = catalog.task_swatches(_art_location, _choose_task)
	for index: int in range(catalog.variants_per_task):
		var swatch: MetaSwatch = MetaSwatch.new()
		swatch.setup(colors[index] if index < colors.size() else UiKit.DISC_OFF)
		swatch.set_selected(index == selected, false)
		swatch.pressed.connect(_on_swatch.bind(index))
		row.add_child(swatch)
		_swatches.append(swatch)


func _on_swatch(index: int) -> void:
	var catalog: MetaCatalog = store.catalog
	if store.state.variant(catalog, _art_location, _choose_task) == index:
		return
	if not store.set_variant(_art_location, _choose_task, index):
		return
	for swatch_index: int in range(_swatches.size()):
		_swatches[swatch_index].set_selected(swatch_index == index)
	_swap(catalog.task_id(_art_location, _choose_task))


func _on_confirm() -> void:
	_choose_task = -1
	var mode: CardMode = _default_mode()
	if mode == CardMode.DONE and _last_bonus > 0:
		MetaUi.play_sound("coin")
	_show_card(mode)
	if mode == CardMode.DONE:
		_refresh_header(true)


func _fill_done() -> void:
	var catalog: MetaCatalog = store.catalog
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 24)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_box.add_child(head)
	var done: Control = Control.new()
	done.custom_minimum_size = Vector2(DONE_DISC, DONE_DISC)
	done.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	done.mouse_filter = Control.MOUSE_FILTER_IGNORE
	done.add_child(MetaUi.disc(DONE_DISC, UiKit.ACCENT))
	var check: TextureRect = UiKit.tinted_icon("lucide/check", UiIconButton.ICON_PIXELS, Color.WHITE)
	check.position = Vector2(DONE_DISC - UiIconButton.ICON_PIXELS, DONE_DISC - UiIconButton.ICON_PIXELS) * 0.5
	check.size = Vector2(UiIconButton.ICON_PIXELS, UiIconButton.ICON_PIXELS)
	done.add_child(check)
	head.add_child(done)
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(column)
	var entry_name: Label = UiKit.label(MetaStrings.location_name(catalog.location_id(_art_location)), NAME_SIZE - 4)
	entry_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(entry_name)
	var sub: Label = UiKit.label(MetaStrings.location_done(), SUB_SIZE, UiKit.TEXT_MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(sub)
	if _last_bonus > 0:
		var bonus: PanelContainer = PanelContainer.new()
		bonus.theme_type_variation = &"ChipPanel"
		bonus.add_theme_stylebox_override("panel", MetaUi.tile_style(UiKit.ACCENT_SOFT, 40, 24, 8))
		bonus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bonus.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var line: HBoxContainer = HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bonus.add_child(line)
		line.add_child(UiKit.tinted_icon("lucide/coins", 40.0, UiKit.GOLD))
		line.add_child(UiKit.label(MetaStrings.BONUS_FORMAT % _last_bonus, 40))
		head.add_child(bonus)
		bonus.pivot_offset = bonus.get_combined_minimum_size() * 0.5
		bonus.scale = Vector2.ONE * 0.6
		create_tween().tween_property(bonus, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_OUT)
		_last_bonus = 0
	_card_box.add_child(UiKit.spacer(28.0))
	var tiles: HBoxContainer = HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 20)
	tiles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_box.add_child(tiles)
	for index: int in range(1, catalog.location_count()):
		tiles.add_child(_location_tile(index))


## Sıradaki mekân karosu: açılmış ama sanatı henüz yok -> "Yakında"; kilitli -> kilit, soluk.
func _location_tile(index: int) -> Control:
	var catalog: MetaCatalog = store.catalog
	var unlocked: bool = store.state.is_location_unlocked(catalog, index)
	var tile: PanelContainer = PanelContainer.new()
	tile.add_theme_stylebox_override("panel", MetaUi.tile_style(TILE_COLOR, TILE_RADIUS, 16, 20))
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.custom_minimum_size = Vector2(0.0, TILE_HEIGHT)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(column)
	var icon: TextureRect = UiKit.tinted_icon("lucide/house", 44.0, UiKit.ACCENT) if unlocked \
		else MetaUi.lock_icon(40.0, UiKit.TEXT_MUTED)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(icon)
	var entry_name: Label = UiKit.label(MetaStrings.location_name(catalog.location_id(index)), 28,
		UiKit.TEXT if unlocked else UiKit.TEXT_MUTED)
	entry_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	entry_name.custom_minimum_size = Vector2(200.0, 0.0)
	column.add_child(entry_name)
	if unlocked:
		column.add_child(UiKit.label(MetaStrings.soon(), 24, UiKit.ACCENT))
	else:
		tile.modulate.a = LOCKED_ALPHA
	return tile


# --- Odaya dokunma: bitmiş eşyanın görünümünü değiştir --------------------------------

func _on_room_input(event: InputEvent) -> void:
	var press: bool = false
	var release: bool = false
	var at: Vector2 = Vector2.ZERO
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		press = (event as InputEventMouseButton).pressed
		release = not press
		at = (event as InputEventMouseButton).position
	elif event is InputEventScreenTouch:
		press = (event as InputEventScreenTouch).pressed
		release = not press
		at = (event as InputEventScreenTouch).position
	if press:
		_pressing = true
		_press_at = at
	elif release and _pressing:
		_pressing = false
		if at.distance_to(_press_at) <= TAP_MAX_TRAVEL:
			_tap_room(at)


func _tap_room(at: Vector2) -> void:
	var local: Vector2 = (at - _room.position) / _room.scale.x
	var catalog: MetaCatalog = store.catalog
	var order: Array[String] = catalog.draw_order.duplicate()
	order.reverse()
	for slot: String in order:
		var task: int = catalog.task_index(_art_location, slot)
		if task < 0 or not store.state.is_task_done(catalog, _art_location, task):
			continue
		var rect: TextureRect = _layers.get(slot) as TextureRect
		if rect == null or not Rect2(rect.position, rect.size).has_point(local):
			continue
		var mask: BitMap = _mask_for(rect)
		if mask != null:
			var uv: Vector2 = (local - rect.position) / rect.size
			var mask_size: Vector2i = mask.get_size()
			var pixel: Vector2i = Vector2i(int(uv.x * float(mask_size.x - 1)), int(uv.y * float(mask_size.y - 1)))
			if not mask.get_bitv(pixel):
				continue
		_choose_task = task
		MetaUi.play_sound("ui_soft", 1.0, -4.0)
		_pulse(rect)
		_show_card(CardMode.CHOOSE)
		return


func _pulse(rect: TextureRect) -> void:
	var area: Rect2 = Rect2(rect.position, rect.size)
	if area.get_area() > CANVAS.x * CANVAS.y * BIG_LAYER_SHARE:
		return
	var tween: Tween = create_tween()
	tween.tween_property(rect, "scale", Vector2.ONE * 1.03, 0.12).set_trans(Tween.TRANS_SINE)
	tween.tween_property(rect, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
