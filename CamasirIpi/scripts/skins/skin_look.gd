class_name SkinLook
extends RefCounted

## Oyunda/ana ekranda UYGULANAN görünüm: seçili mandal dokusu + ip stili. Seviye kurulurken bir kez
## `reload()` edilir; ekranlar yalnız `apply_pin` ve `draw_rope` çağırır (kaplama mantığı game.gd'ye girmez).

var pin_texture: Texture2D = null
var pin_id: String = ""
var rope_id: String = ""
var rope_style: Dictionary = RopePainter.DEFAULT_STYLE


func reload(store: SkinStore = null) -> void:
	var skins: SkinStore = store if store != null else SkinStore.new()
	pin_id = skins.selected(SkinCatalog.KIND_PIN)
	rope_id = skins.selected(SkinCatalog.KIND_ROPE)
	pin_texture = load_pin_texture(skins.catalog, pin_id)
	rope_style = skins.catalog.rope_style(rope_id)


## Kaplama dokusu; dosya yoksa/yüklenemezse varsayılan ahşap mandal.
static func load_pin_texture(catalog: SkinCatalog, id: String) -> Texture2D:
	var path: String = catalog.texture_path(id)
	if not ResourceLoader.exists(path):
		path = SkinCatalog.DEFAULT_PIN_TEXTURE
	return load(path) as Texture2D


func apply_pin(view: GarmentView) -> void:
	if pin_texture != null:
		view.set_pin_texture(pin_texture)


func draw_rope(canvas: CanvasItem, x0: float, x1: float, y: float, sag: float) -> void:
	RopePainter.draw_rope(canvas, x0, x1, y, sag, rope_style)
