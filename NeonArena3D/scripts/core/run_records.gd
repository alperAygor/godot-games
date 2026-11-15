extends RefCounted
class_name RunRecords
## C1: mod başına rekorlar ve seçili mod. SAF: yalnız verilen bayrak sözlüğünü okur/yazar (oyunda `Settings.flags`,
## kayıt `Settings.record_run`/`save` ile diske gider). `settings.gd`'ye dokunmadan kalıcıdır: Settings bilinmeyen
## basit (int/str) bayrakları korur. Anahtarlar `rec_<mod>_<alan>` ve `run_mode` (≤ 48 karakter).

const MODE_KEY := "run_mode"
const FIELDS := ["best", "wave", "runs", "wins", "fastest"]

static func key(mode: String, field: String) -> String:
	return "rec_%s_%s" % [mode, field]

static func selected_mode(flags: Dictionary, known: Array, fallback: String) -> String:
	var m := str(flags.get(MODE_KEY, ""))
	return m if known.has(m) else fallback

static func select_mode(flags: Dictionary, mode: String) -> void:
	flags[MODE_KEY] = mode

static func next_mode(current: String, order: Array) -> String:
	if order.is_empty():
		return current
	var i := order.find(current)
	return str(order[(i + 1) % order.size()]) if i >= 0 else str(order[0])

static func get_record(flags: Dictionary, mode: String) -> Dictionary:
	var out := {}
	for f in FIELDS:
		var v: Variant = flags.get(key(mode, f), 0)
		out[f] = int(v) if typeof(v) in [TYPE_INT, TYPE_FLOAT] else 0
	return out

static func record(flags: Dictionary, mode: String, result: Dictionary) -> Dictionary:
	## result: {score, wave, won, time}. Dönüş: {"best": yeni puan rekoru mu, "first_win": ilk zafer mi, "fastest": en hızlı zafer mi}.
	var rec := get_record(flags, mode)
	var score := int(result.get("score", 0))
	var won := bool(result.get("won", false))
	var secs := int(round(float(result.get("time", 0.0))))
	var out := {"best": score > int(rec["best"]) and score > 0, "first_win": won and int(rec["wins"]) == 0, "fastest": false}
	flags[key(mode, "best")] = maxi(int(rec["best"]), score)
	flags[key(mode, "wave")] = maxi(int(rec["wave"]), int(result.get("wave", 0)))
	flags[key(mode, "runs")] = int(rec["runs"]) + 1
	if won:
		flags[key(mode, "wins")] = int(rec["wins"]) + 1
		if secs > 0 and (int(rec["fastest"]) <= 0 or secs < int(rec["fastest"])):
			flags[key(mode, "fastest")] = secs
			out["fastest"] = true
	return out
