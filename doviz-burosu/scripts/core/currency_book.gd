class_name CurrencyBook
extends RefCounted
## data/currencies.json okuyucusu: hangi para birimi hangi günden itibaren var, kupürleri, serileri ve
## "gerçek banknot nasıl görünür" (spec). Kural ve üretici sınıflar bilgiyi buradan alır.
## Not: Godot JSON sayıları float okur; burada her sayı int()'e çevrilir.

const DEFAULT_PATH := "res://data/currencies.json"

var local_code := ""
var watermark_shapes: Array[String] = []

var _defs: Dictionary = {}
var _codes: Array[String] = []


func _init(table: Dictionary = {}) -> void:
	local_code = str(table.get("local", ""))
	for shape: Variant in table.get("watermark_shapes", []):
		watermark_shapes.append(str(shape))
	_defs = table.get("currencies", {})
	for code: Variant in _defs.keys():
		_codes.append(str(code))


static func load_default() -> CurrencyBook:
	return CurrencyBook.new(JsonIO.read_dict(DEFAULT_PATH))


func codes() -> Array[String]:
	return _codes


func has(code: String) -> bool:
	return _defs.has(code)


func is_local(code: String) -> bool:
	return code == local_code


## `day` gününde dolaşımda olan yabancı para birimleri (day <= 0: hepsi).
func foreign_codes(day := 0) -> Array[String]:
	var result: Array[String] = []
	for code in _codes:
		if code != local_code and (day <= 0 or from_day(code) <= day):
			result.append(code)
	return result


func from_day(code: String) -> int:
	return int(_defs[code]["from_day"])


func name_key(code: String) -> String:
	return str(_defs[code]["name_key"])


func country_key(code: String) -> String:
	return str(_defs[code]["country_key"])


func denominations(code: String) -> Array[int]:
	var result: Array[int] = []
	for value: Variant in _defs[code]["denominations"]:
		result.append(int(value))
	return result


func denomination_index(code: String, denom: int) -> int:
	return denominations(code).find(denom)


func has_denomination(code: String, denom: int) -> bool:
	return has(code) and denomination_index(code, denom) >= 0


## Kupürün kuruş değeri.
func value_minor(denom: int) -> int:
	return Money.units(denom)


## Orta kur (1 birim = kaç PL, x RATE_SCALE) ve alış/satış farkı (baz puan).
func base_rate(code: String) -> int:
	return int(_defs[code]["rate"])


func spread_bp(code: String) -> int:
	return int(_defs[code]["spread_bp"])


func serial_digits(code: String) -> int:
	return int(_defs[code]["serial_digits"])


# --- Seriler -----------------------------------------------------------------

func series_ids(code: String) -> Array[String]:
	var result: Array[String] = []
	for series: Dictionary in _defs[code]["series"]:
		result.append(str(series["id"]))
	return result


func _series(code: String, series_id: String) -> Dictionary:
	for series: Dictionary in _defs[code]["series"]:
		if str(series["id"]) == series_id:
			return series
	return {}


func series_prefix(code: String, series_id: String) -> String:
	return str(_series(code, series_id).get("prefix", ""))


## Seri `day` gününde geçerli mi (başlangıç ve bitiş günü dahil).
func series_valid_on(code: String, series_id: String, day: int) -> bool:
	var series := _series(code, series_id)
	if series.is_empty():
		return false
	if day < int(series["valid_from"]):
		return false
	var until: Variant = series["valid_until"]
	return until == null or day <= int(until)


## Serinin ilk geçerli günü.
func series_valid_from(code: String, series_id: String) -> int:
	return int(_series(code, series_id).get("valid_from", 0))


## Serinin son geçerli günü; süresizse -1.
func series_valid_until(code: String, series_id: String) -> int:
	var until: Variant = _series(code, series_id).get("valid_until")
	return -1 if until == null else int(until)


## `day` gününden önce bitmiş (eski) seriler.
func expired_series(code: String, day: int) -> Array[String]:
	var result: Array[String] = []
	for series: Dictionary in _defs[code]["series"]:
		if series["valid_until"] != null and day > int(series["valid_until"]):
			result.append(str(series["id"]))
	return result


func valid_series(code: String, day: int) -> Array[String]:
	var result: Array[String] = []
	for series_id in series_ids(code):
		if series_valid_on(code, series_id, day):
			result.append(series_id)
	return result


## Seri numarası: önek + serial_digits haneli sıfır dolgulu sayı. number 0..10^hane-1.
func make_serial(code: String, series_id: String, number: int) -> String:
	return "%s%0*d" % [series_prefix(code, series_id), serial_digits(code), number]


func is_serial_valid(code: String, series_id: String, serial: String) -> bool:
	var prefix := series_prefix(code, series_id)
	if prefix.is_empty() or serial.length() != prefix.length() + serial_digits(code):
		return false
	return serial.begins_with(prefix) and serial.substr(prefix.length()).is_valid_int()


# --- Gerçek banknotun görünümü -----------------------------------------------

func portrait_id(code: String, denom: int) -> String:
	return "%s_p%d" % [code.to_lower(), denomination_index(code, denom)]


func size_mm(code: String, denom: int) -> Vector2i:
	var def: Dictionary = _defs[code]
	var index := denomination_index(code, denom)
	var base: Array = def["size_base"]
	var step: Array = def["size_step"]
	return Vector2i(int(base[0]) + index * int(step[0]), int(base[1]) + index * int(step[1]))


## Gerçek (sahte olmayan) banknotun olması gereken özellikleri.
func spec(code: String, denom: int) -> Dictionary:
	var def: Dictionary = _defs[code]
	return {
		"color": str(def["colors"][denomination_index(code, denom)]),
		"size_mm": size_mm(code, denom),
		"pattern": str(def["pattern"]),
		"portrait": portrait_id(code, denom),
		"uv_color": str(def["uv"]["color"]),
		"uv_position": str(def["uv"]["position"]),
		"watermark_shape": str(def["watermark"]),
		"microtext": str(def["microtext"]),
	}
