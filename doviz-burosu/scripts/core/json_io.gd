class_name JsonIO
extends RefCounted
## JSON okuma/yazma yardımcıları. Saf mantık: sahneye ve autoload'lara bağımlı değil, testte doğrudan kullanılır.


## Paketle gelen (değişmez) veri dosyaları için ÖNBELLEKLİ okuma: her çağrıda ayrıştırmaz. Dönen sözlük PAYLAŞIMLIDIR:
## değiştirme (değiştireceksen `read_dict` kullan). Sıcak yollarda (her kare / her tıklama) kullanılır.
static var _shared := {}


static func read_shared(path: String) -> Dictionary:
	if not _shared.has(path):
		_shared[path] = read_dict(path)
	return _shared[path]


## JSON dosyasını okur. Dosya yoksa veya bozuksa `fallback` döner.
static func read_dict(path: String, fallback: Dictionary = {}) -> Dictionary:
	if not FileAccess.file_exists(path):
		return fallback
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	push_warning("JsonIO: '%s' geçerli bir JSON nesnesi değil." % path)
	return fallback


## Önce geçici dosyaya yazar, sonra yerine taşır; yazma yarıda kesilirse eski kayıt bozulmaz.
static func write_dict(path: String, data: Dictionary) -> Error:
	var tmp_path := path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return DirAccess.rename_absolute(tmp_path, path)


## "player.move_speed" gibi noktalı bir yolla iç içe sözlükten değer okur.
static func get_path_value(data: Dictionary, dotted_path: String, fallback: Variant = null) -> Variant:
	var current: Variant = data
	for key in dotted_path.split("."):
		if current is Dictionary and (current as Dictionary).has(key):
			current = current[key]
		else:
			return fallback
	return current
