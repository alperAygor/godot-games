class_name NoteFactory
extends RefCounted
## Gerçek ve sahte banknot üretir (tohumlu RNG ile: aynı tohum aynı banknotları üretir).
## Sahte = CurrencyBook.spec'ten kasıtlı sapma. Aynı anda çelişen sahtelikler (UV yok + UV rengi yanlış)
## istenirse "yok" olan kazanır.

const DEFAULT_PARAMS := {
	"color_shift_min": 20,
	"color_shift_max": 40,
	"size_diff_min_mm": 3,
	"size_diff_max_mm": 6,
	"torn_remaining_min": 20,
	"torn_remaining_max": 45,
}

var book: CurrencyBook
var rng: RandomNumberGenerator
var params: Dictionary


## `balance_notes`: data/balance.json içindeki "notes" bölümü (eksik anahtarlar varsayılanı kullanır).
func _init(currency_book: CurrencyBook, generator: RandomNumberGenerator, balance_notes: Dictionary = {}) -> void:
	book = currency_book
	rng = generator
	params = DEFAULT_PARAMS.duplicate()
	params.merge(balance_notes, true)


func make_genuine(code: String, denom := 0, day := 0, options: Dictionary = {}) -> Banknote:
	return make(code, denom, day, [], options)


## `fakes`: Banknote.FAKE_TYPES'tan etiketler. `day` > 0 ise o gün geçerli bir seri seçilir (yoksa null).
## options: series_id (zorla, ör. eski seri), serial_number (int), taped (bool), torn (bool),
## remaining_percent (int, torn ve taped'i ezer).
func make(code: String, denom: int, day: int, fakes: Array, options: Dictionary = {}) -> Banknote:
	if not book.has(code):
		push_error("NoteFactory: bilinmeyen para birimi '%s'" % code)
		return null
	var chosen_denom := denom if denom > 0 else int(Seed.pick(rng, book.denominations(code)))
	if not book.has_denomination(code, chosen_denom):
		push_error("NoteFactory: %s için %d kupürü yok" % [code, chosen_denom])
		return null
	var series_id: String = options.get("series_id", "")
	if series_id.is_empty():
		var candidates: Array[String] = book.valid_series(code, day) if day > 0 else book.series_ids(code)
		if candidates.is_empty():
			return null
		series_id = str(Seed.pick(rng, candidates))

	var spec := book.spec(code, chosen_denom)
	var note := Banknote.new()
	note.currency = code
	note.denom = chosen_denom
	note.series_id = series_id
	var number: int = int(options["serial_number"]) if options.has("serial_number") else rng.randi_range(0, int(pow(10, book.serial_digits(code))) - 1)
	note.serial = book.make_serial(code, series_id, number)
	note.color = spec["color"]
	note.size_mm = spec["size_mm"]
	note.pattern = spec["pattern"]
	note.portrait = spec["portrait"]
	note.uv_present = true
	note.uv_color = spec["uv_color"]
	note.uv_position = spec["uv_position"]
	note.watermark_present = true
	note.watermark_shape = spec["watermark_shape"]
	note.microtext = spec["microtext"]

	for fake: Variant in _resolve_conflicts(fakes):
		_apply_fake(note, str(fake), spec)
		note.fakes.append(str(fake))
	note.fakes.sort_custom(func(a: String, b: String) -> bool: return Banknote.FAKE_TYPES.find(a) < Banknote.FAKE_TYPES.find(b))

	if options.has("remaining_percent"):
		note.remaining_percent = int(options["remaining_percent"])
		note.taped = bool(options.get("taped", false))
	elif options.get("torn", false):
		note.remaining_percent = rng.randi_range(int(params["torn_remaining_min"]), int(params["torn_remaining_max"]))
	elif options.get("taped", false):
		note.taped = true
	return note


## Verilen sahtecilik türlerinden rastgele biri (liste boşsa boş metin).
func pick_fake(available: Array) -> String:
	var choice: Variant = Seed.pick(rng, available)
	return "" if choice == null else str(choice)


func _resolve_conflicts(fakes: Array) -> Array:
	var result: Array = []
	for fake: Variant in fakes:
		if fake in result:
			continue
		if fake == Banknote.FAKE_UV_COLOR and Banknote.FAKE_UV_MISSING in fakes:
			continue
		if fake == Banknote.FAKE_WM_SHAPE and Banknote.FAKE_WM_MISSING in fakes:
			continue
		result.append(fake)
	return result


func _apply_fake(note: Banknote, fake: String, spec: Dictionary) -> void:
	match fake:
		Banknote.FAKE_COLOR:
			note.color = _shift_color(spec["color"])
		Banknote.FAKE_SIZE:
			var diff := rng.randi_range(int(params["size_diff_min_mm"]), int(params["size_diff_max_mm"]))
			if Seed.chance(rng, 50):
				diff = -diff
			var size: Vector2i = spec["size_mm"]
			if Seed.chance(rng, 50):
				size.x += diff
			else:
				size.y += diff
			note.size_mm = size
		Banknote.FAKE_PORTRAIT:
			var others: Array[int] = []
			for other in book.denominations(note.currency):
				if other != note.denom:
					others.append(other)
			note.portrait = book.portrait_id(note.currency, int(Seed.pick(rng, others)))
		Banknote.FAKE_UV_MISSING:
			note.uv_present = false
		Banknote.FAKE_UV_COLOR:
			note.uv_color = _shift_color(spec["uv_color"])
		Banknote.FAKE_WM_MISSING:
			note.watermark_present = false
		Banknote.FAKE_WM_SHAPE:
			var shapes: Array[String] = []
			for shape in book.watermark_shapes:
				if shape != spec["watermark_shape"]:
					shapes.append(shape)
			note.watermark_shape = str(Seed.pick(rng, shapes))
		Banknote.FAKE_MICROTEXT:
			note.microtext = _typo(spec["microtext"])
		_:
			push_error("NoteFactory: bilinmeyen sahtecilik '%s'" % fake)


## Rengin bir kanalını en az color_shift_min kadar kaydırır (taşarsa yön ters çevrilir).
func _shift_color(hex: String) -> String:
	var channels := [hex.substr(1, 2).hex_to_int(), hex.substr(3, 2).hex_to_int(), hex.substr(5, 2).hex_to_int()]
	var which := rng.randi_range(0, 2)
	var amount := rng.randi_range(int(params["color_shift_min"]), int(params["color_shift_max"]))
	if Seed.chance(rng, 50):
		amount = -amount
	var shifted: int = channels[which] + amount
	if shifted < 0 or shifted > 255:
		shifted = channels[which] - amount
	channels[which] = clampi(shifted, 0, 255)
	return "#%02X%02X%02X" % channels


## Mikro yazıda bir harfi başka bir harfle değiştirir (boşluklar korunur, sonuç mutlaka farklıdır).
func _typo(text: String) -> String:
	var letter_positions: Array[int] = []
	for i in text.length():
		if text[i] != " ":
			letter_positions.append(i)
	var index := int(Seed.pick(rng, letter_positions))
	var original := text[index]
	var replacement := original
	while replacement == original:
		replacement = char(rng.randi_range(65, 90))
	return text.substr(0, index) + replacement + text.substr(index + 1)
