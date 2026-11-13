class_name LocationCycle
extends RefCounted

## Mekân döngüsü: seviye ilerledikçe çamaşır ipinin kurulduğu yer değişir (Bahçe -> Sahil ->
## Çatı Katı -> başa sarar). Neden: uzun seviye serisinde oyuncu bir yolculukta olduğunu
## hissetsin; gün döngüsü (DayCycle) her seviyede saati, bu sınıf her ~40 seviyede yeri değiştirir.
## Saf mantık: sahne bilgisi yok; veri `data/locations.json`'dadır. Gün paleti mekâna göre ayarlanır
## (`look_for_level`), ayarlı görünümler önbelleğe alınır: seviye başında bile tekrar üretilmez.

const DATA_PATH: String = "res://data/locations.json"
## Veri dosyası bozuk/eksikse oyun yine açılır: tek mekân (bahçe), katmanlar arka planın
## kendi varsayılanlarıyla kurulur.
const FALLBACK_ID: String = "garden"
const FALLBACK_LEVELS: int = 40
const KEY_ID: String = "id"
const KEY_LEVELS: String = "levels"
const KEY_NAME: String = "name_key"
const KEY_AMBIENCE: String = "ambience"
const KEY_PALETTE: String = "palette"
const KEY_PHASES: String = "phases"
const KEY_SKY_TOP_MIX: String = "sky_top_mix"
const KEY_SKY_BOTTOM_MIX: String = "sky_bottom_mix"
const KEY_SCENERY_MUL: String = "scenery_mul"
## Mekân adlarının çeviri anahtarları (data/i18n/strings.csv). Neden kodda da listeli: adlar veriden
## (locations.json) okunur, ama çeviri tablosu "kullanılmayan anahtar" denetimi .gd kaynağını tarar;
## ayrıca test, verideki her mekânın adının bu listede (yani tabloda) olduğunu doğrular.
const NAME_KEYS: Array[String] = ["PLACE_GARDEN", "PLACE_BEACH", "PLACE_ROOFTOP"]

static var _locations: Array[Dictionary] = []
## "mekân:aşama" -> mekâna göre ayarlanmış paylaşılan görünüm (değiştirilmemeli).
static var _looks: Dictionary[String, DayLook] = {}


static func count() -> int:
	_ensure_loaded()
	return _locations.size()


## Tüm mekânların bir turu kaç seviye sürer (bundan sonra döngü başa sarar).
static func cycle_length() -> int:
	_ensure_loaded()
	var total: int = 0
	for index: int in range(_locations.size()):
		total += _span(index)
	return total


## 1 tabanlı seviye -> mekân sırası (0 = bahçe). Geçersiz seviyeler ilk mekâna düşer.
static func index_for(level: int) -> int:
	var step: int = posmod(maxi(level, 1) - 1, cycle_length())
	for index: int in range(_locations.size()):
		var span: int = _span(index)
		if step < span:
			return index
		step -= span
	return 0


static func location_for(level: int) -> String:
	return id_at(index_for(level))


static func id_at(index: int) -> String:
	_ensure_loaded()
	return String(_locations[posmod(index, _locations.size())].get(KEY_ID, FALLBACK_ID))


## Mekânın tüm verisi (katmanlar, çapalar, palet). Bilinmeyen kimlik ilk mekânı döndürür.
static func data_for(id: String) -> Dictionary:
	_ensure_loaded()
	for entry: Dictionary in _locations:
		if String(entry.get(KEY_ID, "")) == id:
			return entry
	return _locations[0]


## Seviyenin içinde bulunduğu mekân aralığının ilk seviyesi (ör. 52 -> 41).
static func first_level_of(level: int) -> int:
	var clamped: int = maxi(level, 1)
	var step: int = posmod(clamped - 1, cycle_length())
	var offset: int = step
	for index: int in range(_locations.size()):
		var span: int = _span(index)
		if offset < span:
			return clamped - offset
		offset -= span
	return clamped - step


## Bu seviye bir mekânın ilk seviyesi mi (yeni yer "karşılama" anı için).
static func is_first_level_of_location(level: int) -> bool:
	return maxi(level, 1) == first_level_of(level)


static func name_key(id: String) -> String:
	return String(data_for(id).get(KEY_NAME, ""))


## Ses katmanı için ipucu ("garden" / "waves" / "city"). Ses üretimi bu sınıfın işi değil.
static func ambience_for(level: int) -> String:
	return String(data_for(location_for(level)).get(KEY_AMBIENCE, ""))


## Seviyenin mekâna göre ayarlanmış gün görünümü. `forced_phase` >= 0 ise o aşama (QA çekimleri).
## Aşamalar arası karışım (DayCycle.LEVELS_PER_PHASE > 1) varsa yeni nesne döner; yoksa paylaşılan.
static func look_for_level(level: int, id: String, forced_phase: int = -1) -> DayLook:
	if forced_phase >= 0:
		return look_for(forced_phase, id)
	var phase: int = DayCycle.phase_for(level)
	var blend: float = DayCycle.blend_for(level)
	var current: DayLook = look_for(phase, id)
	if blend <= 0.0:
		return current
	var mixed: DayLook = DayLook.new()
	mixed.blend(current, look_for(phase + 1, id), blend)
	return mixed


## Aşamanın mekâna göre ayarlanmış paylaşılan görünümü (DayCycle'ın paylaşılan nesnesi bozulmaz).
static func look_for(phase: int, id: String) -> DayLook:
	var wrapped: int = posmod(phase, DayCycle.PHASE_COUNT)
	var key: String = "%s:%d" % [id, wrapped]
	if _looks.has(key):
		return _looks[key]
	var look: DayLook = DayLook.new()
	look.copy_from(DayCycle.look_for_phase(wrapped))
	_apply_palette(look, data_for(id).get(KEY_PALETTE, {}) as Dictionary)
	_looks[key] = look
	return look


static func _apply_palette(look: DayLook, palette: Dictionary) -> void:
	if palette.is_empty():
		return
	look.sky_top = _mixed(look.sky_top, palette.get(KEY_SKY_TOP_MIX, null))
	look.sky_bottom = _mixed(look.sky_bottom, palette.get(KEY_SKY_BOTTOM_MIX, null))
	if palette.has(KEY_SCENERY_MUL):
		look.scenery_tint *= Color.html(String(palette[KEY_SCENERY_MUL]))
	var phases: Dictionary = palette.get(KEY_PHASES, {}) as Dictionary
	if phases.has(look.phase_name):
		look.apply_dict(phases[look.phase_name] as Dictionary)


## [renk, oran] çiftiyle karıştırır; veri yoksa rengi aynen bırakır.
static func _mixed(color: Color, spec: Variant) -> Color:
	if not (spec is Array) or (spec as Array).size() < 2:
		return color
	return color.lerp(Color.html(String((spec as Array)[0])), clampf(float((spec as Array)[1]), 0.0, 1.0))


static func _span(index: int) -> int:
	return maxi(int(_locations[index].get(KEY_LEVELS, FALLBACK_LEVELS)), 1)


static func _ensure_loaded() -> void:
	if not _locations.is_empty():
		return
	var parsed: Variant = null
	if FileAccess.file_exists(DATA_PATH):
		parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if parsed is Dictionary:
		for entry: Variant in ((parsed as Dictionary).get("locations", []) as Array):
			if entry is Dictionary and (entry as Dictionary).has(KEY_ID):
				_locations.append(entry as Dictionary)
	if _locations.is_empty():
		_locations.append({KEY_ID: FALLBACK_ID, KEY_LEVELS: FALLBACK_LEVELS})
