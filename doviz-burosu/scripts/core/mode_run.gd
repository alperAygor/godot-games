class_name ModeRun
extends RefCounted
## Hikaye dışı bir oyun koşusunun ortak arayüzü (Günün Kuru, Sonsuz). Masa ekranı koşuyu bu arayüzle sürer:
## `career` (kurallar/araçlar için sahte kariyer), `new_shift()`, her işlemden sonra `on_submit(sonuç)`, bitince `score_value()`.

const KIND_DAILY := "daily"
const KIND_ENDLESS := "endless"

var kind := ""
var career: Career
var shift: Shift
## Koşu bitti mi (süre, müşteriler ya da canlar tükendi). Masa ekranı kapanışı Shift'ten de anlar.
var finished := false


## Modlar için kariyer: hikaye kapalı, tüm araçlar elde, gün = mod kural günü.
static func make_career(salt: String, rules_day: int) -> Career:
	var mode_career := Career.load_default(salt)
	mode_career.day = rules_day
	mode_career.story_enabled = false
	mode_career.office_enabled = false
	for tool_def: Variant in JsonIO.read_dict("res://data/tools.json").get("tools", []):
		var tool_id := str((tool_def as Dictionary)["id"])
		if not (tool_id in mode_career.tools):
			mode_career.tools.append(tool_id)
	return mode_career


## Kasa stoğunu `multiplier` ile çarpılmış bir kopya kasa.
static func scaled_till(ctx: DayContext, multiplier: int) -> Till:
	var scaled: Dictionary = ctx.balance.duplicate(true)
	var start: Dictionary = scaled["till"]["start_counts"]
	for code: Variant in start.keys():
		for denom: Variant in start[code].keys():
			start[code][denom] = int(start[code][denom]) * multiplier
	return Till.from_balance(ctx.book, scaled, ctx.day)


func new_shift() -> Shift:
	return shift


## Masa üstü başlıkları: {"title_key", "status_key", "status_arg", "score"}.
func hud() -> Dictionary:
	return {"title_key": "", "status_key": "", "status_arg": 0, "score": 0}


## Bir işlem bitti (`result` Shift.submit sonucu). Koşu canlar/kurallar gibi durumunu günceller.
## Dönen sözlük koşuya özeldir (Sonsuz: life_lost, rule_added, over).
func on_submit(_result: Dictionary) -> Dictionary:
	return {}


func score_value() -> int:
	return 0
