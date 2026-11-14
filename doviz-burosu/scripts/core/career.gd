class_name Career
extends RefCounted
## Oyuncunun ilerlemesi: gün, ev, hikaye durumu, araçlar, geçmiş. Kayıt kökü budur (SaveManager.data["career"]).
## Gün döngüsü: new_shift() -> (vardiya oynanır) -> finish_day(shift, ödenecek_giderler) -> bir sonraki gün.
## Kasa her sabah data/balance.json'daki başlangıç sayımına döner; yabancı para stoğu gün İÇİNDE müşterilerle değişir.

const SAVE_VERSION := 1

var day := 1
var salt := "story"
var household: Household
var story: StoryState
var tools: Array[String] = []
## Bugün için kazanılmış ödüllü reklamlar ("<yer>:<gün>"); günlük sınırlar için. Sabah anlık görüntüsüyle birlikte geri döner.
var ads_used: Array[String] = []
## Biten günlerin raporları (vardiya + ev).
var history: Array[Dictionary] = []
## "" | evicted | family_left | fired | arrested
var game_over := ""
## Sabah anlık görüntüsü ("günü tekrar oyna" bu duruma döner).
var morning_snapshot: Dictionary = {}
## Akşam başladı ama henüz bitmedi: vardiya raporu (kaydedilmez).
var pending_report: Dictionary = {}
## Hikaye olayları (patron, Tilki, müfettiş...) vardiyalara karışsın mı? Oyun oturumu açar; denge ölçümleri ve eski testler kapalı kullanır.
var story_enabled := false
## Merkez talimatları ve tüple gelen notlar (oyun oturumu açar; denge ölçümleri/eski testler kapalı).
var office_enabled := false
## Doluysa new_shift() bunu çağırır (Günün Kuru / Sonsuz kendi vardiyasını kurar).
var shift_provider := Callable()

var _balance: Dictionary
var _household_table: Dictionary
var _tool_defs: Array[Dictionary] = []


func _init(balance_table: Dictionary = {}, household_table: Dictionary = {}, tool_table: Dictionary = {}, salt_text := "story") -> void:
	_balance = balance_table
	_household_table = household_table
	salt = salt_text
	household = Household.new(household_table)
	story = StoryState.new()
	for tool_def: Variant in tool_table.get("tools", []):
		_tool_defs.append(tool_def)
		if bool(tool_def.get("start", false)):
			tools.append(str(tool_def["id"]))


static func load_default(salt_text := "story") -> Career:
	return Career.new(JsonIO.read_dict("res://data/balance.json"), JsonIO.read_dict(Household.DEFAULT_PATH),
		JsonIO.read_dict("res://data/tools.json"), salt_text)


func _cfg(path: String, fallback: Variant) -> Variant:
	return JsonIO.get_path_value(_balance, path, fallback)


# --- Gün başı -----------------------------------------------------------------

## Günün hikaye bayraklarını ayarlar, ücretsiz araçları verir ve sabah anlık görüntüsünü alır (bir kez).
func begin_day() -> void:
	if day >= int(_cfg("story.mother_sick_day", 6)):
		household.flags["mother_sick"] = true
	for tool_def in _tool_defs:
		if tool_def.has("free_on_day") and day >= int(tool_def["free_on_day"]) and not (tool_def["id"] in tools):
			tools.append(str(tool_def["id"]))
	if int(morning_snapshot.get("day", 0)) != day:
		morning_snapshot = {}
		morning_snapshot = to_dict()


## Patronun "her işlemden 5 PL kes" önerisini kabul eder (gizli kâr, 14. günde müfettiş riski).
func accept_skim() -> void:
	story.set_flag("skim_accepted")


func skim_active() -> bool:
	return story.flag("skim_accepted") and day >= int(_cfg("story.skim_offer_day", 8))


## Bugün işlem başı eksik ödenecek tutar (kuruş); kesinti açık değilse 0.
func skim_amount_minor() -> int:
	return Money.units(int(_cfg("shift.skim_pl", 5))) if skim_active() else 0


## O günün bağlamı: kurlar, kurallar, kasa ve bülten (tohumlar gün ve salt'tan türer; sabah gazetesi de bunu kullanır).
func make_context() -> DayContext:
	var ctx := DayContext.for_day(day, {"salt": salt})
	ctx.bulletin = CustomerFactory.make_bulletin(ctx, Seed.rng("bulletin|%s|%d" % [salt, day]))
	return ctx


## O günün vardiyası: bağlam, bülten, müşteri üretici ve vardiya.
func new_shift() -> Shift:
	if shift_provider.is_valid():
		return shift_provider.call()
	begin_day()
	var ctx := make_context()
	var factory := CustomerFactory.new(ctx, Seed.rng("customers|%s|%d" % [salt, day]))
	var shift := Shift.new(ctx, factory)
	shift.skim_minor = skim_amount_minor()
	if story_enabled:
		shift.director = StoryDirector.new(self)
	if office_enabled:
		shift.directive = todays_directive()
		shift.memo_salt = salt
		shift.memo_plan = OfficeMemos.plan(day, salt, ctx)
	return shift


## Bugünün Merkez talimatı (sabah gazetesi ve vardiya aynı talimatı gösterir); kapalıysa boş.
func todays_directive() -> Dictionary:
	return Directives.pick(day, salt) if office_enabled else {}


# --- Gün sonu -----------------------------------------------------------------

## Akşam başlar: bugünkü maaş (ve gizli kâr) nakde girer. Bir gün için yalnızca bir kez işler; tekrar çağrılırsa aynı rapor döner.
## Kaydedilmez: akşamda uygulama kapanırsa oyun o günün sabahına döner.
func begin_evening(shift: Shift) -> Dictionary:
	if pending_report.is_empty():
		pending_report = shift.report()
		household.cash_minor = maxi(0, household.cash_minor + int(pending_report["net_minor"]) + int(pending_report["skim_minor"]) + int(pending_report["story_minor"]))
		story.add("skim_count", int(pending_report["skim_count"]))
		# Telefon: cevap verilen aramaların etkisi; cevapsız her arama ailenin ruh halini biraz düşürür.
		household.mood = clampi(household.mood + int(pending_report["call_mood"]) - 2 * int(pending_report["calls_missed"]), 0, 100)
		story.add("kind", int(pending_report["call_kind"]))
	return pending_report


## Akşam bitti ("Eve git"): `paid_ids` giderleri ödenir, kovulma/müfettiş/ev kontrol edilir, gün ilerler.
## Dönen rapor: {day, shift, household, over}.
func settle_evening(paid_ids: Array) -> Dictionary:
	var shift_report := pending_report
	var home_report := household.settle_day(day, paid_ids)
	var over := str(home_report["over"])
	if over.is_empty() and int(shift_report["mistake_transactions"]) >= int(_cfg("shift.fire_mistakes", 8)):
		over = "fired"
	if over.is_empty() and day == int(_cfg("story.inspector_day", 14)) and inspector_catches():
		over = "arrested"
	var report := {"day": day, "shift": shift_report, "household": home_report, "over": over}
	history.append(report)
	pending_report = {}
	if not over.is_empty():
		game_over = over
	else:
		day += 1
	return report


## Vardiyayı hesaba katar ve akşamı tek adımda bitirir (bot ve testler için kısayol).
func finish_day(shift: Shift, paid_ids: Array) -> Dictionary:
	begin_evening(shift)
	return settle_evening(paid_ids)


## Akşam varsayılanı: bugünkü maaş dahil nakdin yettiği kadar giderleri öncelik sırasıyla öder (bot ve "otomatik öde" butonu).
func affordable_expense_ids(shift: Shift) -> Array:
	var cash := household.cash_minor
	if pending_report.is_empty():  # akşam henüz başlamadıysa bugünkü maaş da sayılır
		var report := shift.report()
		cash += int(report["net_minor"]) + int(report["skim_minor"]) + int(report["story_minor"])
	var ids: Array = []
	for expense in household.due_expenses(day):
		if int(expense["amount_minor"]) <= cash:
			cash -= int(expense["amount_minor"])
			ids.append(expense["id"])
	return ids


func is_over() -> bool:
	return not game_over.is_empty()


## Müfettişin yakalama olasılığı (yüzde): kesinti sayısı ve Tilki ile ilişkiler artırır; Deniz'e kanıt verdiysen Tilki kısmı
## silinir (tanıksın); müfettişe (şapkalı müşteri) kurala uygun davrandıysan olasılık yarıya iner. Üst sınırı aşmaz.
func inspector_chance_percent() -> int:
	var chance := story.counter("skim_count") * int(_cfg("story.inspector_catch_per_skim_percent", 2))
	if not story.flag("deniz_evidence"):
		chance += story.counter("tilki_helped") * int(_cfg("story.inspector_tilki_helped_percent", 40))
		chance += story.counter("tilki_money") * int(_cfg("story.inspector_tilki_money_percent", 20))
	chance = mini(int(_cfg("story.inspector_max_percent", 90)), chance)
	if story.flag("inspector_pleased"):
		chance /= 2
	return chance


## Müfettiş yakalar mı? Sonuç salt'a bağlı sabit tohumla çekilir.
func inspector_catches() -> bool:
	var chance := inspector_chance_percent()
	if chance <= 0:
		return false
	return Seed.rng("inspector|%s" % salt).randi_range(1, 100) <= chance


# --- Ödüllü reklamlar ----------------------------------------------------------

func ad_key(placement: String) -> String:
	return "%s:%d" % [placement, day]


## Bu hikaye gününde `placement` ödülü şimdiye dek kaç kez kazanıldı.
func ad_uses(placement: String) -> int:
	return ads_used.count(ad_key(placement))


func mark_ad_used(placement: String) -> void:
	ads_used.append(ad_key(placement))


## `double_pay` önizlemesi: ödül alınırsa nakde eklenecek fark (kuruş); akşam başlamadıysa ya da zaten alındıysa 0.
func double_pay_preview() -> int:
	if pending_report.is_empty() or bool(pending_report.get("doubled", false)):
		return 0
	var earned := int(pending_report["base_minor"]) + int(pending_report["bonus_minor"])
	return maxi(0, 2 * earned - int(pending_report["fines_minor"])) - int(pending_report["net_minor"])


## `double_pay` ödülü: günün maaşı ve primi 2 katına çıkar (cezalar çıkarılmaz). Akşam başlamış olmalı; bir kez işler.
## Dönen: nakde eklenen fark (kuruş), işlemediyse 0.
func double_pay() -> int:
	if pending_report.is_empty() or bool(pending_report.get("doubled", false)):
		return 0
	var old_net := int(pending_report["net_minor"])
	var earned := int(pending_report["base_minor"]) + int(pending_report["bonus_minor"])
	var new_net := maxi(0, 2 * earned - int(pending_report["fines_minor"]))
	pending_report["net_minor"] = new_net
	pending_report["doubled"] = true
	pending_report["double_minor"] = new_net - old_net
	household.cash_minor += new_net - old_net
	return new_net - old_net


## `rate_tip` ödülü: FED'in yarın sabahki orta kuru bugünküne göre ne yönde ve yaklaşık yüzde kaç değişir.
## {"code", "percent_tenths" (işaretli, yüzde x10), "direction": 1 | -1 | 0}.
func rate_tip(code := "FED") -> Dictionary:
	var ctx := make_context()
	var tomorrow := ctx.rates.change_bp(code, day + 1)
	return {"code": code, "percent_tenths": tomorrow / 10, "direction": signi(tomorrow)}


# --- Araçlar ------------------------------------------------------------------

func has_tool(tool_id: String) -> bool:
	return tool_id in tools


func tool_price_minor(tool_id: String) -> int:
	for tool_def in _tool_defs:
		if tool_def["id"] == tool_id:
			return Money.units(int(tool_def["price_pl"]))
	return -1


## Akşam dükkanında bugün satın alınabilecek araçlar: ücretli, günü gelmiş, henüz alınmamış.
func buyable_tool_ids() -> Array[String]:
	var result: Array[String] = []
	for tool_def in _tool_defs:
		if int(tool_def["price_pl"]) > 0 and day >= int(tool_def["unlock_day"]) and not (tool_def["id"] in tools):
			result.append(str(tool_def["id"]))
	return result


## Akşam dükkanından araç satın alır (günü gelmişse, nakit yetiyorsa). Başarılıysa true.
func buy_tool(tool_id: String) -> bool:
	if has_tool(tool_id):
		return false
	for tool_def in _tool_defs:
		if tool_def["id"] == tool_id and day >= int(tool_def["unlock_day"]) and int(tool_def["price_pl"]) > 0:
			var price := Money.units(int(tool_def["price_pl"]))
			if price <= household.cash_minor:
				household.cash_minor -= price
				tools.append(tool_id)
				return true
	return false


# --- Kayıt --------------------------------------------------------------------

func to_dict() -> Dictionary:
	var data := {
		"version": SAVE_VERSION, "day": day, "salt": salt, "household": household.to_dict(), "story": story.to_dict(),
		"tools": tools.duplicate(), "ads_used": ads_used.duplicate(), "history": history.duplicate(true), "game_over": game_over,
	}
	if not morning_snapshot.is_empty():
		data["morning_snapshot"] = morning_snapshot.duplicate(true)
	return data


func load_dict(data: Dictionary) -> void:
	day = int(data.get("day", 1))
	salt = str(data.get("salt", "story"))
	household.load_dict(data.get("household", {}))
	story = StoryState.from_dict(data.get("story", {}))
	tools.clear()
	for tool_id: Variant in data.get("tools", []):
		tools.append(str(tool_id))
	ads_used.clear()
	for key: Variant in data.get("ads_used", []):
		ads_used.append(str(key))
	history.clear()
	for entry: Variant in data.get("history", []):
		history.append(entry)
	game_over = str(data.get("game_over", ""))
	morning_snapshot = (data.get("morning_snapshot", {}) as Dictionary).duplicate(true)
	pending_report = {}


## "Günü tekrar oyna": sabah anlık görüntüsüne döner. Anlık görüntü yoksa false.
func restore_morning() -> bool:
	if morning_snapshot.is_empty():
		return false
	var snapshot := morning_snapshot.duplicate(true)
	load_dict(snapshot)
	morning_snapshot = snapshot
	return true
