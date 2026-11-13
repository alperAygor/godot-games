class_name SkinCatalog
extends RefCounted

## Mandal ve ip kaplamalarının SAF kataloğu (sahne/dosya yok; yükleme dışında): hangi kaplama
## nasıl edinilir, sahiplik/seçim kuralları. Kayıt `SkinStore`dadır; burası yalnız kural bilir.
## Kaynaklar: default (herkeste), coins (jetonla), collection (koleksiyon seti tamamlanınca).

const CATALOG_PATH: String = "res://data/skins.json"
const KIND_PIN: String = "pin"
const KIND_ROPE: String = "rope"
const KINDS: Array[String] = [KIND_PIN, KIND_ROPE]
const SOURCE_DEFAULT: String = "default"
const SOURCE_COINS: String = "coins"
const SOURCE_COLLECTION: String = "collection"
const TEXTURE_DIR: String = "res://assets/sprites/skins/"
const TEXTURE_EXT: String = ".png"
## Varsayılan mandal dokusu (kaplama dosyası yoksa da buna düşülür).
const DEFAULT_PIN_TEXTURE: String = "res://assets/sprites/pin.png"

var _entries: Dictionary = {}
var _order: Dictionary = {}


static func load_default() -> SkinCatalog:
	var parsed: Variant = null
	if FileAccess.file_exists(CATALOG_PATH):
		parsed = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	return from_dict(parsed if parsed is Dictionary else {})


static func from_dict(source: Dictionary) -> SkinCatalog:
	var catalog: SkinCatalog = SkinCatalog.new()
	for kind: String in KINDS:
		var ids: Array[String] = []
		var raw: Variant = source.get(kind)
		if raw is Array:
			for entry: Variant in raw as Array:
				if entry is Dictionary and not String((entry as Dictionary).get("id", "")).is_empty():
					var item: Dictionary = (entry as Dictionary).duplicate(true)
					item["kind"] = kind
					catalog._entries[String(item["id"])] = item
					ids.append(String(item["id"]))
		catalog._order[kind] = ids
	return catalog


func ids(kind: String) -> Array[String]:
	var result: Array[String] = []
	var raw: Variant = _order.get(kind, [])
	for id: Variant in raw as Array:
		result.append(String(id))
	return result


func has_skin(id: String) -> bool:
	return _entries.has(id)


func kind_of(id: String) -> String:
	return String(entry(id).get("kind", ""))


func entry(id: String) -> Dictionary:
	return _entries.get(id, {}) as Dictionary


func default_id(kind: String) -> String:
	for id: String in ids(kind):
		if source_type(id) == SOURCE_DEFAULT:
			return id
	var all: Array[String] = ids(kind)
	return all[0] if not all.is_empty() else ""


func source_type(id: String) -> String:
	return String((entry(id).get("source", {}) as Dictionary).get("type", SOURCE_DEFAULT))


## Jetonla alınanlarda fiyat; diğerlerinde 0.
func price(id: String) -> int:
	return ProgressData.to_count((entry(id).get("source", {}) as Dictionary).get("price"))


## Koleksiyonla açılanlarda set kimliği ("turkiye"); diğerlerinde boş.
func set_id(id: String) -> String:
	return String((entry(id).get("source", {}) as Dictionary).get("set", ""))


## `purchased`: jetonla alınmış kimlikler; `cosmetics`: koleksiyondan açılmış kimlikler.
func is_available(id: String, purchased: Array, cosmetics: Array) -> bool:
	if not has_skin(id):
		return false
	match source_type(id):
		SOURCE_DEFAULT:
			return true
		SOURCE_COINS:
			return purchased.has(id)
		SOURCE_COLLECTION:
			return cosmetics.has(id)
	return false


## Kayıtlı seçim geçersizse (artık sahip olunmayan/yanlış tür) türün varsayılanına düşer.
func resolve_selected(kind: String, selected_id: String, purchased: Array, cosmetics: Array) -> String:
	if has_skin(selected_id) and kind_of(selected_id) == kind and is_available(selected_id, purchased, cosmetics):
		return selected_id
	return default_id(kind)


func texture_path(id: String) -> String:
	if source_type(id) == SOURCE_DEFAULT:
		return DEFAULT_PIN_TEXTURE
	return TEXTURE_DIR + id + TEXTURE_EXT


## Ip stili (RopePainter sözlüğü); ip olmayan/bilinmeyen kimlikte varsayılan ip stili.
func rope_style(id: String) -> Dictionary:
	var style: Variant = entry(id).get("style")
	if style is Dictionary:
		return style as Dictionary
	return RopePainter.DEFAULT_STYLE.duplicate(true)
