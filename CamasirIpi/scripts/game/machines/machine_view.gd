class_name MachineView
extends Node2D

## Çamaşır/kurutma makinesinin görünümü (çimde, sepetlerin yanında). Konum = makinenin tabanı
## (ayakların ortası). Katmanlar: gölge -> gövde (koyu tambur) -> dönen katlı çamaşırlar -> cam +
## halka. Makinenin ÜSTÜNDE beyaz bir sayaç hapı durur: her yuva için çamaşır renginde halka + büyük
## kalan hamle sayısı; boş yuva soluk nokta, biten parça yeşil onay. Neden üstte ve büyük: eski küçük
## panel ışıkları telefonda okunmuyordu (oyuncu geri bildirimi). Kurallar `LaundryBoard`'dadır.
## Düğümler kurulumda bir kez üretilir; kare başına yalnız tamburun açısı yazılır.

const BODY_PATHS: Array[String] = [
	"res://assets/sprites/machines/machine_washer.png",
	"res://assets/sprites/machines/machine_dryer.png",
]
const GLASS_PATH: String = "res://assets/sprites/machines/machine_glass.png"
const FOLDED_PATH: String = "res://assets/sprites/folded.png"
## Kadraj oranları (tools/blender/make_machines.py ile birlikte değişir): kapak merkezi tuvalin
## üstünden yüksekliğin bu oranında; cam yarıçapı yüksekliğin bu oranı.
const DOOR_Y_RATIO: float = 0.5735
const DOOR_RADIUS_RATIO: float = 0.2206
## Sprite tuvalinde gövdenin görünen üst kenarı (yüksekliğin oranı; 51/512).
const VISIBLE_TOP_RATIO: float = 0.1
const MAX_SLOTS: int = LaundryBoard.MACHINE_MAX_CAPACITY
## Tambur: çamaşırlar kapak yarıçapının bu oranında bir çemberde döner.
const ORBIT_RATIO: float = 0.42
const CLOTH_WIDTH_RATIO: float = 0.86
const SPIN_SPEED: float = 2.4
const SPIN_EASE: float = 2.5
const CLOTH_SWAY: float = 0.35
const CLOTH_SWAY_SPEED: float = 3.1
const SHADOW_COLOR: Color = Color(0.1, 0.15, 0.25, 0.2)
const SHADOW_SIZE: Vector2 = Vector2(1.05, 0.16)
const CHIP_RADIUS_MAX: float = 27.0
## Sayaç hapı: makinenin üstünde, aradaki boşluk ve iç dolgu (piksel).
const PILL_GAP: float = 10.0
const PILL_PAD: float = 12.0
const PILL_FILL: Color = Color(1.0, 1.0, 1.0, 0.93)
const PILL_SHADOW: Color = Color(0.1, 0.15, 0.25, 0.16)
const PILL_SHADOW_OFFSET: Vector2 = Vector2(0.0, 4.0)

const CHIP_GAP_RATIO: float = 0.45
const CHIP_FILL: Color = Color(1.0, 1.0, 1.0, 0.98)
const CHIP_EMPTY: Color = Color(0.0, 0.0, 0.0, 0.1)
const CHIP_INK: Color = Color("2a2f3d")
const CHIP_RING_RATIO: float = 0.22
## Renk körü deseni açıkken çalışan yuva dolu renkli disk olur: glif temiz, kalan hamle sağ-alt rozette.
const CHIP_GLYPH_ALPHA: float = 0.9
const CHIP_TAG_OFFSET: Vector2 = Vector2(0.62, 0.62)
const CHIP_TAG_RATIO: float = 0.55
const CHIP_TAG_FONT_RATIO: float = 1.75
const CHIP_FONT_RATIO: float = 1.4
const READY_INK: Color = Color("38a276")
const BOUNCE: Vector2 = Vector2(1.06, 0.92)
const BOUNCE_IN_SECONDS: float = 0.1
const BOUNCE_OUT_SECONDS: float = 0.35
const SHAKE_DEGREES: float = 4.0
const SHAKE_SECONDS: float = 0.07
const POP_SCALE: float = 1.35
const POP_SECONDS: float = 0.18

var machine: int = LaundryBoard.MACHINE_WASHER
var height: float = 190.0
var capacity: int = LaundryBoard.WASHER_CAPACITY
## Ekrandaki genişlik (sprite oranından; yerleşim bununla kenara yaslanır).
var width: float = 166.0

var _visual: Node2D = null
var _drum: Node2D = null
var _cloths: Array[Sprite2D] = []
var _panel: ChipPanel = null
var _spin: float = 0.0
var _speed: float = 0.0
var _time: float = 0.0
var _react: Tween = null


## `display_height`: ekrandaki boy (piksel). Genişlik sprite oranından gelir.
func setup(kind: int, display_height: float, slots: int) -> void:
	machine = kind
	height = display_height
	capacity = clampi(slots, 1, MAX_SLOTS)
	var body_texture: Texture2D = load(BODY_PATHS[kind]) as Texture2D
	var factor: float = height / body_texture.get_size().y
	width = body_texture.get_size().x * factor
	var shadow: Sprite2D = Sprite2D.new()
	shadow.texture = GarmentView.circle_texture()
	shadow.modulate = SHADOW_COLOR
	shadow.scale = Vector2(width * SHADOW_SIZE.x, width * SHADOW_SIZE.y) / float(GarmentView.CIRCLE_TEXTURE_SIZE)
	add_child(shadow)
	# Tepki düğümü tabanda: ezilme/sallanma makineyi yerden koparmaz.
	_visual = Node2D.new()
	add_child(_visual)
	var body: Sprite2D = _layer(body_texture, factor)
	_visual.add_child(body)
	_drum = Node2D.new()
	_drum.position = door_local()
	_visual.add_child(_drum)
	var folded: Texture2D = load(FOLDED_PATH) as Texture2D
	var radius: float = height * DOOR_RADIUS_RATIO
	for index: int in range(MAX_SLOTS):
		var cloth: Sprite2D = Sprite2D.new()
		cloth.texture = folded
		cloth.scale = Vector2.ONE * (radius * CLOTH_WIDTH_RATIO / folded.get_size().x)
		cloth.visible = false
		_drum.add_child(cloth)
		_cloths.append(cloth)
	if ResourceLoader.exists(GLASS_PATH):
		_visual.add_child(_layer(load(GLASS_PATH) as Texture2D, factor))
	_panel = ChipPanel.new()
	_panel.span = width
	# Hap makinenin üstünde, tepki düğümünün DIŞINDA: makine sallanınca sayılar titremesin.
	add_child(_panel)
	_panel.configure(capacity)
	_panel.position = Vector2(0.0, -height + height * VISIBLE_TOP_RATIO - PILL_GAP - _panel.pill_height() * 0.5)
	set_process(false)


func _layer(texture: Texture2D, factor: float) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.scale = Vector2.ONE * factor
	sprite.position = Vector2(-texture.get_size().x * factor * 0.5, -height)
	return sprite


## Kapak merkezi (yerel): uçuş hedefi ve tambur ekseni.
func door_local() -> Vector2:
	return Vector2(0.0, -height + height * DOOR_Y_RATIO)


func door_global() -> Vector2:
	return to_global(door_local())


func door_radius() -> float:
	return height * DOOR_RADIUS_RATIO


## Tahtadan baştan kurulum (seviye başı / geri al).
func sync(board: LaundryBoard, palette: Array[Color]) -> void:
	for slot: int in range(capacity):
		var entry: Vector2i = board.machine_slot(machine, slot)
		if entry.x == LaundryBoard.EMPTY:
			clear_slot(slot)
		else:
			fill_slot(slot, palette[board.color_of(entry.x) % palette.size()], entry.y, false)


## Yuvaya çamaşır girdi (inince çağrılır): tamburda katlı parça, panelde sayaç.
func fill_slot(slot: int, tint: Color, left: int, animate: bool = true) -> void:
	if slot < 0 or slot >= capacity:
		return
	_cloths[slot].visible = true
	_cloths[slot].modulate = tint
	_panel.set_slot(slot, tint, left)
	_wake()
	if animate:
		bounce()


func clear_slot(slot: int) -> void:
	if slot < 0 or slot >= capacity:
		return
	_cloths[slot].visible = false
	_panel.set_slot(slot, Color.TRANSPARENT, -1)


func set_left(slot: int, left: int) -> void:
	if slot < 0 or slot >= capacity:
		return
	_panel.set_left(slot, left)
	_panel.pop(slot)


## Dolu makine reddetti: kısa sallanma + panel nabzı.
func refuse() -> void:
	_kill_react()
	_react = create_tween()
	for angle: float in [SHAKE_DEGREES, -SHAKE_DEGREES, SHAKE_DEGREES * 0.5, 0.0]:
		_react.tween_property(_visual, "rotation_degrees", angle, SHAKE_SECONDS)
	for slot: int in range(capacity):
		_panel.pop(slot)


func bounce() -> void:
	_kill_react()
	_visual.scale = Vector2.ONE
	_react = create_tween()
	_react.tween_property(_visual, "scale", BOUNCE, BOUNCE_IN_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_react.tween_property(_visual, "scale", Vector2.ONE, BOUNCE_OUT_SECONDS)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _kill_react() -> void:
	if _react != null:
		_react.kill()
	_visual.rotation_degrees = 0.0


func _wake() -> void:
	set_process(true)


## Tambur yumuşakça hızlanır/yavaşlar; boşken durur ve işlem kapanır (boşta CPU harcanmaz).
func _process(delta: float) -> void:
	var busy: bool = false
	for cloth: Sprite2D in _cloths:
		if cloth.visible:
			busy = true
			break
	_speed = lerpf(_speed, SPIN_SPEED if busy else 0.0, 1.0 - exp(-SPIN_EASE * delta))
	_time += delta
	_spin = fmod(_spin + _speed * delta, TAU)
	var radius: float = door_radius() * ORBIT_RATIO
	for index: int in range(_cloths.size()):
		var angle: float = _spin + TAU * float(index) / float(MAX_SLOTS)
		var cloth: Sprite2D = _cloths[index]
		cloth.position = Vector2(cos(angle), sin(angle)) * radius
		cloth.rotation = angle * 0.5 + CLOTH_SWAY * sin(_time * CLOTH_SWAY_SPEED + float(index))
	if not busy and _speed < 0.01:
		set_process(false)


## Üst paneldeki yuva ışıkları. Sayılar ve renkler yalnız değişince yeniden çizilir.
class ChipPanel extends Node2D:
	var span: float = 120.0
	var icon: Texture2D = null
	var _count: int = 2
	var _box: StyleBoxFlat = StyleBoxFlat.new()
	var _tints: Array[Color] = []
	var _lefts: Array[int] = []
	var _font: Font = null

	func configure(count: int) -> void:
		_count = count
		_tints.resize(count)
		_tints.fill(Color.TRANSPARENT)
		_lefts.resize(count)
		_lefts.fill(-1)
		# Proje temasının yazı tipi (HUD ile aynı); yoksa motorun yedeği.
		var theme: Theme = ThemeDB.get_project_theme()
		_font = theme.default_font if theme != null and theme.default_font != null else ThemeDB.fallback_font
		_box.set_corner_radius_all(int(pill_height() * 0.5))
		_box.anti_aliasing = true
		queue_redraw()

	func pill_height() -> float:
		return _radius() * 2.0 + MachineView.PILL_PAD * 1.4

	func _icon_size() -> float:
		return _radius() * 1.5 if icon != null else 0.0

	func _pill_width() -> float:
		var radius: float = _radius()
		var step: float = radius * (2.0 + MachineView.CHIP_GAP_RATIO)
		var icon_room: float = _icon_size() + MachineView.PILL_PAD * 0.7 if icon != null else 0.0
		return step * float(_count - 1) + radius * 2.0 + MachineView.PILL_PAD * 2.0 + icon_room

	func set_slot(slot: int, tint: Color, left: int) -> void:
		_tints[slot] = tint
		_lefts[slot] = left
		queue_redraw()

	## Yalnız dolu yuvada: çamaşır henüz kapağa inmediyse sayı inişte yazılır.
	func set_left(slot: int, left: int) -> void:
		if _lefts[slot] < 0:
			return
		_lefts[slot] = left
		queue_redraw()

	func pop(slot: int) -> void:
		if slot >= _count or _lefts[slot] < 0:
			return
		var tween: Tween = create_tween()
		scale = Vector2.ONE
		tween.tween_property(self, "scale", Vector2.ONE * 1.06, MachineView.POP_SECONDS * 0.5)
		tween.tween_property(self, "scale", Vector2.ONE, MachineView.POP_SECONDS)

	## Yarıçap: hap makine genişliğinin ~1.3 katını aşmasın (4 yuvaya yükseltilince küçülür).
	func _radius() -> float:
		var room: float = span * 1.3 - MachineView.PILL_PAD * 2.0
		return minf(MachineView.CHIP_RADIUS_MAX, room / (float(_count) * (2.0 + MachineView.CHIP_GAP_RATIO) + 1.2))

	func _draw() -> void:
		var radius: float = _radius()
		var step: float = radius * (2.0 + MachineView.CHIP_GAP_RATIO)
		var pill_w: float = _pill_width()
		var pill_h: float = pill_height()
		var rect: Rect2 = Rect2(Vector2(-pill_w * 0.5, -pill_h * 0.5), Vector2(pill_w, pill_h))
		_box.bg_color = MachineView.PILL_SHADOW
		draw_style_box(_box, Rect2(rect.position + MachineView.PILL_SHADOW_OFFSET, rect.size))
		_box.bg_color = MachineView.PILL_FILL
		draw_style_box(_box, rect)
		var start: float = rect.position.x + MachineView.PILL_PAD + radius
		if icon != null:
			var size: float = _icon_size()
			draw_texture_rect(icon, Rect2(Vector2(rect.position.x + MachineView.PILL_PAD, -size * 0.5), Vector2.ONE * size),
				false, MachineView.CHIP_INK)
			start += size + MachineView.PILL_PAD * 0.7
		for slot: int in range(_count):
			var at: Vector2 = Vector2(start + step * float(slot), 0.0)
			if _lefts[slot] < 0:
				draw_circle(at, radius * 0.55, MachineView.CHIP_EMPTY, true, -1.0, true)
				continue
			draw_circle(at, radius, _tints[slot], true, -1.0, true)
			var color_id: int = ColorPatterns.color_id_of(_tints[slot])
			if _lefts[slot] > 0 and ColorPatterns.pattern_for(color_id) >= ColorPatterns.SOLID:
				# Renk körü: halka desen taşıyamayacak kadar ince. Çalışırken yuva dolu renkli disktir ve temiz
				# desen glifi taşır; kalan hamle sayısı sağ-altta küçük beyaz bir rozete taşınır (bitince
				# beyaz iç disk + onay eski gibi). Sayı glifin üstüne binmez, ikisi de okunur.
				ColorPatterns.draw_glyph(self, at, radius, color_id, MachineView.CHIP_GLYPH_ALPHA)
				var tag_at: Vector2 = at + Vector2(radius, radius) * MachineView.CHIP_TAG_OFFSET
				var tag_radius: float = radius * MachineView.CHIP_TAG_RATIO
				draw_circle(tag_at, tag_radius, MachineView.CHIP_FILL, true, -1.0, true)
				draw_arc(tag_at, tag_radius, 0.0, TAU, 20, _tints[slot], maxf(1.5, radius * 0.1), true)
				var count_text: String = str(_lefts[slot])
				var count_size: int = int(tag_radius * MachineView.CHIP_TAG_FONT_RATIO)
				var count_extent: Vector2 = _font.get_string_size(count_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, count_size)
				draw_string(_font, tag_at + Vector2(-count_extent.x * 0.5, count_size * 0.36), count_text,
					HORIZONTAL_ALIGNMENT_LEFT, -1.0, count_size, MachineView.CHIP_INK)
				continue
			draw_circle(at, radius * (1.0 - MachineView.CHIP_RING_RATIO), MachineView.CHIP_FILL, true, -1.0, true)
			if _lefts[slot] == 0:
				# Bitti: yeşil onay (çıkmayı bekliyor ya da çıkıyor).
				var ink: Color = MachineView.READY_INK
				var width: float = maxf(2.0, radius * 0.22)
				draw_polyline(PackedVector2Array([at + Vector2(-radius * 0.38, 0.0), at + Vector2(-radius * 0.08, radius * 0.3),
					at + Vector2(radius * 0.4, -radius * 0.32)]), ink, width, true)
				continue
			var text: String = str(_lefts[slot])
			var font_size: int = int(radius * MachineView.CHIP_FONT_RATIO)
			var text_size: Vector2 = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
			draw_string(_font, at + Vector2(-text_size.x * 0.5, font_size * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT,
				-1.0, font_size, MachineView.CHIP_INK)
