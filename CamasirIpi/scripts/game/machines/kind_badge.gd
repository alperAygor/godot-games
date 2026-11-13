class_name KindBadge
extends Node2D

## Türlü sepet rozeti: sepetin önünde beyaz disk içinde sepet renginde çamaşır silüeti ("bu sepet
## yalnız pantolon alır"). BasketView'a dokunmadan, ayrı düğüm olarak sepeti izler. Sepet
## kayarken (giderken/gelirken) gizlenir, yerine oturunca o anki türle belirir.

const PATH: String = "res://assets/sprites/machines/kind_%s.png"
const DISC_RATIO: float = 0.3
const ICON_RATIO: float = 0.72
const Y_RATIO: float = 0.13
const DISC_COLOR: Color = Color(1.0, 1.0, 1.0, 0.96)
const INK_DARKEN: float = 0.12
const SETTLED_EPSILON: float = 2.0
const FADE_RATE: float = 10.0
const Z_INDEX: int = 70

var basket: BasketView = null
var _kind: int = LaundryBoard.EMPTY
var _disc: Sprite2D = null
var _icon: Sprite2D = null
var _size: float = 250.0
var _textures: Array[Texture2D] = []


func setup(target: BasketView, basket_size: float) -> void:
	basket = target
	_size = basket_size
	z_index = Z_INDEX
	for name: String in GarmentView.KINDS:
		var path: String = PATH % name
		_textures.append(load(path) as Texture2D if ResourceLoader.exists(path) else null)
	_disc = Sprite2D.new()
	_disc.texture = GarmentView.circle_texture()
	_disc.modulate = DISC_COLOR
	_disc.scale = Vector2.ONE * (_size * DISC_RATIO / float(GarmentView.CIRCLE_TEXTURE_SIZE))
	add_child(_disc)
	_icon = Sprite2D.new()
	add_child(_icon)
	modulate.a = 0.0
	visible = false


## Gösterilecek tür (EMPTY: rozet yok) ve sepet rengi.
func set_kind(kind: int, tint: Color) -> void:
	_kind = kind
	if kind == LaundryBoard.EMPTY or kind >= _textures.size() or _textures[kind] == null:
		visible = false
		set_process(false)
		return
	_icon.texture = _textures[kind]
	_icon.scale = Vector2.ONE * (_size * DISC_RATIO * ICON_RATIO / _textures[kind].get_size().x)
	_icon.modulate = tint.darkened(INK_DARKEN)
	visible = true
	set_process(true)


func _process(delta: float) -> void:
	if basket == null or not is_instance_valid(basket):
		return
	position = basket.position + Vector2(0.0, _size * Y_RATIO)
	var settled: bool = basket.visible and absf(basket.position.y - basket.rest_position.y) < SETTLED_EPSILON
	modulate.a = lerpf(modulate.a, 1.0 if settled else 0.0, 1.0 - exp(-FADE_RATE * delta))
