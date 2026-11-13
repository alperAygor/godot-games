class_name SeasonLook
extends RefCounted

## Mevsim görünümü verisi (data/seasons.json): katman renk derecelendirmesi, mevsimlik doku
## değişimleri (taç, kışın çit), küçük zemin süsleri, gökyüzü/gün paleti ayarı, ortam efekti ve
## "mevsim geldi" afişi. Mevsimin KENDİSİ SeasonCycle'dan gelir (kural tarafıyla tek kaynak).
## Saf veri/mantık sınıfı: sahne bilgisi yok (yalnız malzeme fabrikası Godot kaynağı üretir).
## Neden scripts/game altında: mevsim görsel işi bu klasörün sahipliğinde; kural tarafı bu sınıfı
## kullanmaz, yalnız SeasonCycle'ı okur.

const DATA_PATH: String = "res://data/seasons.json"
const SHADER_PATH: String = "res://scripts/game/season_fx/season_grade.gdshader"
## Hata ayıklama/QA: `-- --season=winter` mevsimi zorlar (ekran görüntüsü matrisi için).
const SEASON_ARG: String = "--season="
const DEFAULT_FADE_SECONDS: float = 2.4
const DEFAULT_BANNER_GAP: float = 0.35
## Afiş çeviri anahtarları (data/i18n/strings.csv). Neden kodda da listeli: anahtarlar veriden okunur,
## ama "kullanılmayan anahtar" denetimi .gd kaynağını tarar; test verideki her anahtarın burada olduğunu doğrular.
const ARRIVE_KEYS: Array[String] = ["SEASON_ARRIVE_SUMMER", "SEASON_ARRIVE_AUTUMN", "SEASON_ARRIVE_WINTER",
	"SEASON_ARRIVE_SPRING"]
## Çamaşır tonu bu değerin altına inemez: renkler mevsimden bağımsız okunaklı kalsın
## (DayCycle testindeki sınırla aynı: en fazla %10 koyulaşma).
const GARMENT_MIN_CHANNEL: float = 0.9
const KEY_GRADE: String = "grade"
const KEY_LAYERS: String = "layers"
const KEY_SWAP: String = "swap"
const KEY_DECALS: String = "decals"
const KEY_DECOR: String = "decor"
const KEY_SKY: String = "sky"
const KEY_PHASES: String = "phases"
const KEY_FX: String = "fx"
const LUMA: Vector3 = Vector3(0.299, 0.587, 0.114)
## Güneşin "ufuk" yüksekliği (tasarım y): şafak/gün batımı güneşi bu civarda (day_cycle.json).
const SUN_HORIZON_Y: float = 760.0

static var _data: Dictionary = {}
static var _loaded: bool = false
static var _forced: String = ""
static var _forced_read: bool = false
static var _shader: Shader = null


## Seviyenin mevsimi; `--season=` verilmişse o (QA). Bilinmeyen değer yok sayılır.
static func season_for_level(level: int) -> String:
	var forced: String = forced_season()
	return forced if not forced.is_empty() else SeasonCycle.season_for(level)


static func forced_season() -> String:
	if not _forced_read:
		_forced_read = true
		for arg: String in OS.get_cmdline_user_args():
			if arg.begins_with(SEASON_ARG):
				var value: String = arg.substr(SEASON_ARG.length())
				if SeasonCycle.ORDER.has(value):
					_forced = value
	return _forced


## Mevsim değişimi bu seviyede mi duyurulur? Zorlanan mevsimde duyuru yok (çekimler afişsiz).
static func announces(level: int) -> bool:
	return forced_season().is_empty() and SeasonCycle.is_first_level_of_season(level)


static func spec(season: String) -> Dictionary:
	_ensure_loaded()
	return (_data.get("seasons", {}) as Dictionary).get(season, {}) as Dictionary


static func place_spec(place: String, season: String) -> Dictionary:
	_ensure_loaded()
	var places: Dictionary = _data.get("places", {}) as Dictionary
	return (places.get(place, {}) as Dictionary).get(season, {}) as Dictionary


static func fade_seconds() -> float:
	_ensure_loaded()
	return float(_data.get("fade_seconds", DEFAULT_FADE_SECONDS))


static func banner_gap() -> float:
	_ensure_loaded()
	return float(_data.get("banner_gap_seconds", DEFAULT_BANNER_GAP))


static func arrive_key(season: String) -> String:
	return String(spec(season).get("arrive_key", ""))


static func icon_path(season: String) -> String:
	return String(spec(season).get("icon", ""))


static func fx_spec(season: String) -> Dictionary:
	return spec(season).get(KEY_FX, {}) as Dictionary


## Katmanın derecelendirmesi: mevsim varsayılanı, mekânın katman ezmesiyle (üst düzey anahtar bazında)
## birleşir. Boş sözlük = derecelendirme yok. Mevsimlik dokusu olan katman varsayılan olarak
## derecelendirilmez (zaten mevsim renginde render edildi).
static func grade_for(place: String, season: String, file_name: String) -> Dictionary:
	var place_data: Dictionary = place_spec(place, season)
	var layers: Dictionary = place_data.get(KEY_LAYERS, {}) as Dictionary
	if layers.has(file_name):
		var raw: Variant = layers[file_name]
		if raw == null:
			return {}
		var merged: Dictionary = _base_grade(season).duplicate()
		var override: Dictionary = raw as Dictionary
		for key: Variant in override:
			merged[key] = override[key]
		return merged
	if not swap_path(place, season, file_name).is_empty():
		return {}
	return _base_grade(season).duplicate()


## Direk gibi oyunla hizalı ahşap parçalar: yalnız yeşillik maskesi (tabandaki ot tutamı mevsime
## uysun), genel doygunluk/ton/ikincil maske YOK — kışın ahşap griye, kiremit maskesiyle beyaza dönmesin.
static func prop_grade(place: String, season: String, file_name: String) -> Dictionary:
	var layers: Dictionary = place_spec(place, season).get(KEY_LAYERS, {}) as Dictionary
	if layers.has(file_name):
		return grade_for(place, season, file_name)
	var base: Dictionary = _base_grade(season)
	if not base.has("a"):
		return {}
	return {"a": base["a"], "noise": base.get("noise", 0.012)}


static func _base_grade(season: String) -> Dictionary:
	var raw: Variant = spec(season).get(KEY_GRADE, null)
	return raw as Dictionary if raw is Dictionary else {}


## Mevsimlik doku yolu (ör. kışın karlı taç); yoksa "".
static func swap_path(place: String, season: String, file_name: String) -> String:
	var swaps: Dictionary = place_spec(place, season).get(KEY_SWAP, {}) as Dictionary
	return String(swaps.get(file_name, ""))


static func decals(place: String, season: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for raw: Variant in (place_spec(place, season).get(KEY_DECALS, []) as Array):
		if raw is Dictionary:
			out.append(raw as Dictionary)
	return out


static func shows_decor(place: String, season: String) -> bool:
	return bool(place_spec(place, season).get(KEY_DECOR, true))


## Bir mekân x mevsimin ek doku yolları (değişim + süs; `with_fx` ise efekt + afiş simgesi de).
## Arka planın ön yüklemesi efektleri istemez: onlar SeasonFx'te doğrudan `load` ile açılır ve
## iş parçacığı kuyruğunda alınmadan beklemeleri gerekmez.
static func extra_paths(place: String, season: String, with_fx: bool = true) -> Array[String]:
	var paths: Array[String] = []
	for value: Variant in (place_spec(place, season).get(KEY_SWAP, {}) as Dictionary).values():
		_add_unique(paths, String(value))
	for decal: Dictionary in decals(place, season):
		_add_unique(paths, String(decal.get("file", "")))
	if not with_fx:
		return paths
	_add_unique(paths, icon_path(season))
	var fx: Dictionary = fx_spec(season)
	for raw: Variant in (fx.get("falling", []) as Array):
		for texture_path: Variant in ((raw as Dictionary).get("textures", []) as Array):
			_add_unique(paths, String(texture_path))
	return paths


static func _add_unique(paths: Array[String], path: String) -> void:
	if not path.is_empty() and not paths.has(path):
		paths.append(path)


## Gün görünümüne mevsim ayarı (yerinde). Önce genel, sonra aşama adına özel anahtarlar.
## Neden karışım (mix) ve çarpan: mekân paleti zaten uygulanmış görünümü ezmeden kaydırır;
## ör. kış sahildeki geceyi de yalnız biraz serinletir.
static func apply_sky(look: DayLook, season: String) -> void:
	var sky: Dictionary = spec(season).get(KEY_SKY, {}) as Dictionary
	if sky.is_empty():
		return
	# Genel renk karışımları gündüz içindir: gece (yıldızlı aşamalar) koyu kalsın, yoksa kışın gece
	# göğü soluk griye döner ve HUD yazısı gökyüzüne karışır. Gece ayarları "phases" ile verilir.
	_apply_sky_ops(look, sky, 1.0 - clampf(look.star_amount, 0.0, 1.0))
	var phases: Dictionary = sky.get(KEY_PHASES, {}) as Dictionary
	if phases.has(look.phase_name):
		_apply_sky_ops(look, phases[look.phase_name] as Dictionary, 1.0)


static func _apply_sky_ops(look: DayLook, ops: Dictionary, weight: float) -> void:
	look.sky_top = _mixed(look.sky_top, ops.get("sky_top_mix", null), weight)
	look.sky_bottom = _mixed(look.sky_bottom, ops.get("sky_bottom_mix", null), weight)
	look.scenery_tint = _mixed(look.scenery_tint, ops.get("scenery_mix", null), weight)
	look.cloud_tint = _mixed(look.cloud_tint, ops.get("cloud_mix", null), weight)
	look.sun_color = _mixed(look.sun_color, ops.get("sun_color_mix", null), weight)
	var garment: Color = _mixed(look.garment_tint, ops.get("garment_mix", null), weight)
	# Okunaklılık sınırı: mevsim verisi ne derse desin çamaşır %10'dan fazla koyulaşmaz.
	look.garment_tint = Color(maxf(garment.r, GARMENT_MIN_CHANNEL), maxf(garment.g, GARMENT_MIN_CHANNEL),
		maxf(garment.b, GARMENT_MIN_CHANNEL), garment.a)
	if ops.has("sun_lower"):
		# Kısa kış günü: güneş ufka doğru alçalır (yüksekteki güneş en çok iner, ufuktaki yerinde kalır).
		look.sun_pos.y = lerpf(look.sun_pos.y, maxf(look.sun_pos.y, SUN_HORIZON_Y), clampf(float(ops["sun_lower"]), 0.0, 1.0))
	look.sun_size *= float(ops.get("sun_size_mul", 1.0))
	look.sun_haze = clampf(look.sun_haze + float(ops.get("sun_haze_add", 0.0)), 0.0, 1.0)
	look.firefly_amount *= float(ops.get("firefly_mul", 1.0))
	if look.window_glow > 0.0:
		# Kışın pencereler daha erken/daha sıcak yanar; gündüz (0) aşamaları etkilenmez.
		look.window_glow = clampf(look.window_glow + float(ops.get("window_add", 0.0)), 0.0, 1.0)


static func _mixed(color: Color, raw: Variant, weight: float = 1.0) -> Color:
	if not (raw is Array) or (raw as Array).size() < 2:
		return color
	return color.lerp(Color.html(String((raw as Array)[0])), clampf(float((raw as Array)[1]), 0.0, 1.0) * weight)


## Derecelendirme sözlüğünden gölgelendirici malzemesi. Boş sözlük = null (düz sprite, yaz maliyeti).
static func make_material(grade: Dictionary) -> ShaderMaterial:
	if grade.is_empty():
		return null
	if _shader == null:
		_shader = load(SHADER_PATH) as Shader
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = _shader
	var a: Dictionary = grade.get("a", {}) as Dictionary
	var b: Dictionary = grade.get("b", {}) as Dictionary
	material.set_shader_parameter(&"a_mask", _mask(a))
	material.set_shader_parameter(&"a_one", _op(a, "one"))
	material.set_shader_parameter(&"a_two", _op(a, "two") if a.has("two") else _op(a, "one"))
	material.set_shader_parameter(&"a_split", Vector2(float(a.get("split", 0.5)), float(a.get("split_bright", 0.0))))
	material.set_shader_parameter(&"a_mix", _target(a.get("mix", null)))
	material.set_shader_parameter(&"b_mask", _mask(b))
	material.set_shader_parameter(&"b_one", _op(b, "one"))
	material.set_shader_parameter(&"b_mix", _target(b.get("mix", null)))
	material.set_shader_parameter(&"g_sat", float(grade.get("sat", 1.0)))
	var tint: Color = Color.html(String(grade.get("tint", "#ffffff")))
	material.set_shader_parameter(&"g_tint", Vector3(tint.r, tint.g, tint.b))
	material.set_shader_parameter(&"g_lift", _target(grade.get("lift", null)))
	material.set_shader_parameter(&"noise_scale", float(grade.get("noise", 0.012)))
	material.set_shader_parameter(&"edge_snow", float(grade.get("edge_snow", 0.0)))
	material.set_shader_parameter(&"edge_px", float(grade.get("edge_px", 9.0)))
	var snow: Color = Color.html(String(grade.get("snow", "#f4f8ff")))
	material.set_shader_parameter(&"snow_color", Vector3(snow.r, snow.g, snow.b))
	return material


static func _mask(mask: Dictionary) -> Vector4:
	if mask.is_empty():
		return Vector4(0.0, 0.1, 1.0, 0.0)
	return Vector4(float(mask.get("hue", 0.3)), float(mask.get("width", 0.1)), float(mask.get("sat_min", 0.06)),
		float(mask.get("amount", 1.0)))


static func _op(mask: Dictionary, key: String) -> Vector3:
	var raw: Array = mask.get(key, [0.0, 1.0, 1.0]) as Array
	if raw.size() < 3:
		return Vector3(0.0, 1.0, 1.0)
	return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))


static func _target(raw: Variant) -> Vector4:
	if not (raw is Array) or (raw as Array).size() < 2:
		return Vector4(1.0, 1.0, 1.0, 0.0)
	var color: Color = Color.html(String((raw as Array)[0]))
	return Vector4(color.r, color.g, color.b, clampf(float((raw as Array)[1]), 0.0, 1.0))


## Gölgelendiricinin CPU eşi (gürültüsüz: `variant` 0 = birinci, 1 = ikinci varyant; kar yok).
## Testler bununla tipik manzara renklerinin her mevsimde soluk/okunaklı kaldığını doğrular.
static func grade_color(color: Color, grade: Dictionary, variant: float = 0.0) -> Color:
	if grade.is_empty():
		return color
	var rgb: Vector3 = Vector3(color.r, color.g, color.b)
	var hsv: Vector3 = Vector3(color.h, color.s, color.v)
	var a: Dictionary = grade.get("a", {}) as Dictionary
	var ma: float = _hue_mask(hsv, _mask(a))
	if ma > 0.0:
		var two: Vector3 = _op(a, "two") if a.has("two") else _op(a, "one")
		var graded: Vector3 = _shifted(hsv, _op(a, "one")).lerp(_shifted(hsv, two), clampf(variant, 0.0, 1.0))
		rgb = rgb.lerp(_toward(graded, _target(a.get("mix", null))), ma)
	var b: Dictionary = grade.get("b", {}) as Dictionary
	var mb: float = _hue_mask(hsv, _mask(b))
	if mb > 0.0:
		rgb = rgb.lerp(_toward(_shifted(hsv, _op(b, "one")), _target(b.get("mix", null))), mb)
	var luma: float = rgb.dot(LUMA)
	var tint: Color = Color.html(String(grade.get("tint", "#ffffff")))
	rgb = Vector3(luma, luma, luma).lerp(rgb, float(grade.get("sat", 1.0))) * Vector3(tint.r, tint.g, tint.b)
	var lift: Vector4 = _target(grade.get("lift", null))
	rgb = rgb.lerp(Vector3(lift.x, lift.y, lift.z), lift.w)
	return Color(clampf(rgb.x, 0.0, 1.0), clampf(rgb.y, 0.0, 1.0), clampf(rgb.z, 0.0, 1.0), color.a)


static func _hue_mask(hsv: Vector3, mask: Vector4) -> float:
	var dh: float = absf(fposmod(hsv.x - mask.x + 0.5, 1.0) - 0.5)
	return (1.0 - smoothstep(mask.y * 0.5, mask.y, dh)) * smoothstep(mask.z, mask.z + 0.08, hsv.y) * mask.w


static func _shifted(hsv: Vector3, op: Vector3) -> Vector3:
	var color: Color = Color.from_hsv(fposmod(hsv.x + op.x, 1.0), clampf(hsv.y * op.y, 0.0, 1.0), clampf(hsv.z * op.z, 0.0, 1.0))
	return Vector3(color.r, color.g, color.b)


static func _toward(rgb: Vector3, target: Vector4) -> Vector3:
	var shade: float = clampf(0.55 + 0.55 * rgb.dot(LUMA), 0.0, 1.15)
	return rgb.lerp(Vector3(target.x, target.y, target.z) * shade, target.w)


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if FileAccess.file_exists(DATA_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary:
			_data = parsed as Dictionary
	if _data.is_empty():
		# Veri bozuksa oyun yine açılır: tüm mevsimler bugünkü (yaz) görünümle.
		push_warning("seasons.json okunamadı; mevsim görünümü kapalı")
