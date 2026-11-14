class_name DailyChallenge
extends ModeRun
## Günün Kuru: herkes aynı tarihte AYNI 12 müşteriyi görür (tohum = FNV-1a("daily-YYYY-MM-DD"), UTC tarih).
## Kurallar ve para birimleri 10. gün seviyesindedir. Müşteriler baştan üretilir (oyuncunun kasa durumuna bağlı kalmasın diye
## kasa stoğu bol tutulur). Puan = doğru x 100 + kalan saniye x 2 - hatalı işlem x 150 (data/modes.json).

var date := ""
var official := true
var _cfg: Dictionary


## UTC tarih metni "YYYY-MM-DD". `unix_time` < 0 ise şimdiki zaman.
static func date_key(unix_time := -1.0) -> String:
	var dt := Time.get_datetime_dict_from_unix_time(int(unix_time if unix_time >= 0.0 else Time.get_unix_time_from_system()))
	return "%04d-%02d-%02d" % [dt["year"], dt["month"], dt["day"]]


static func seed_text(date_text: String) -> String:
	return "daily-" + date_text


## "26.10" gibi gün.ay.
static func short_date(date_text: String) -> String:
	var parts := date_text.split("-")
	return "%s.%s" % [parts[2], parts[1]]


## Paylaşım metni (örn. "Günün Kuru 26.10 — 1840 puan 💱").
static func share_text(date_text: String, score: int, language: String) -> String:
	if language.begins_with("tr"):
		return "Günün Kuru %s — %d puan 💱" % [short_date(date_text), score]
	return "Daily Rate %s — %d pts 💱" % [short_date(date_text), score]


func _init(date_text: String, is_official := true, config: Dictionary = {}) -> void:
	kind = ModeRun.KIND_DAILY
	date = date_text
	official = is_official
	_cfg = config if not config.is_empty() else JsonIO.read_dict("res://data/modes.json")["daily"]
	var salt := DailyChallenge.seed_text(date_text)
	career = ModeRun.make_career(salt, int(_cfg["rules_day"]))
	career.shift_provider = _build_shift
	shift = _build_shift()


func _build_shift() -> Shift:
	var salt := DailyChallenge.seed_text(date)
	var ctx := career.make_context()
	ctx.till = ModeRun.scaled_till(ctx, int(_cfg["till_multiplier"]))
	var factory := CustomerFactory.new(ctx, Seed.rng("daily-customers|" + date))
	var built := Shift.new(ctx, factory)
	built.shift_seconds = float(_cfg["shift_seconds"])
	for i in int(_cfg["customers"]):
		built.queue.append(factory.make_random())
	built.use_queue = true
	shift = built
	return built


func hud() -> Dictionary:
	var left := shift.queue.size() + (1 if shift.current != null else 0)
	return {"title_key": "MODE_DAILY_TITLE", "status_key": "MODE_DAILY_STATUS", "status_arg": left, "score": live_score()}


## Şu ana kadarki puan (süre bonusu hariç).
func live_score() -> int:
	return int(shift.stats["correct"]) * int(_cfg["points_per_correct"]) \
		+ int(shift.stats["mistake_transactions"]) * int(_cfg["points_per_mistake"])


## Nihai puan: doğrular + kalan süre bonusu - hatalar (0'ın altına inmez).
func score_value() -> int:
	return maxi(0, live_score() + int(shift.seconds_left()) * int(_cfg["points_per_second"]))
