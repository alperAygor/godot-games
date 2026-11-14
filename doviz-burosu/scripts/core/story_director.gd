class_name StoryDirector
extends RefCounted
## Bir vardiya boyunca hikaye olaylarını (beat) yönetir: sıradaki olay, senaryolu müşteri, seçimler ve sonuçları.
## Olay = {id, after, character, lines, customer?, choice?, effects?, on_decision?, requires?}.
## - `after`: o olaydan önce en az bu kadar müşteri servis edilmiş olmalı (0 = vardiya başı). Her olay vardiyada en çok bir kez çıkar.
## - `customer`: {scenario, expect?}; olayın müşterisi. `expect` verilirse (reject/police/complete) o hükme çıkana dek denenir.
## - `choice.options[]`: {id, text, tag, effects, requires?}. Seçim müşteri görünmeden ÖNCE yapılır.
## - `on_decision`: oyuncunun karar verdiği anda (complete/reject/police) işleyen etkiler.
## Etkiler: {flags, counters, cash_pl (zarf: akşam maaşla nakde girer), savings ({FED: kuruş}), mood}.
## Tüm rastgelelik (olay müşterisi) gün ve tuzdan türer; aynı oyun aynı olayı verir.

const CUSTOMER_ID_BASE := 1000
const BUILD_ATTEMPTS := 80

var career: Career
var db: StoryDb
var day_def: Dictionary
var fired: Array[String] = []


func _init(for_career: Career, story_db: StoryDb = null) -> void:
	career = for_career
	db = story_db if story_db != null else StoryDb.load_default()
	day_def = db.day_def(for_career.day)


## Serviste `served` müşteri geçtiyse sıradaki olay (yoksa boş sözlük). Olayı "çıktı" olarak işaretler.
func next_beat(served: int) -> Dictionary:
	for beat: Dictionary in day_def.get("beats", []):
		if str(beat["id"]) in fired or int(beat.get("after", 0)) > served:
			continue
		if not career.story.matches(beat.get("requires", {})):
			continue
		fired.append(str(beat["id"]))
		return beat
	return {}


## Olayın senaryolu müşterisi; kurulamazsa null (o gün senaryo mümkün değilse).
func build_customer(beat: Dictionary, ctx: DayContext) -> Customer:
	var spec: Dictionary = beat.get("customer", {})
	if spec.is_empty():
		return null
	var character: Dictionary = db.character(str(beat["character"]))
	var factory := CustomerFactory.new(ctx, Seed.rng("beat|%s|%d|%s" % [career.salt, career.day, beat["id"]]))
	if not character.is_empty():
		factory.identity = {"holder_name": character["holder_name"], "face_id": int(character["face_id"])}
	var expect := str(spec.get("expect", ""))
	for attempt in BUILD_ATTEMPTS:
		var customer := factory.make_scenario(str(spec["scenario"]))
		if customer == null:
			return null
		if expect.is_empty() or str(customer.truth["decision"]) == expect:
			customer.id = CUSTOMER_ID_BASE + _beat_index(str(beat["id"]))
			customer.character = str(beat["character"])
			customer.beat_id = str(beat["id"])
			return customer
	return null


# --- Seçimler ------------------------------------------------------------------

## Olayın seçenekleri: [{id, text, tag, available}] (seçimsiz olayda boş).
func options(beat: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for option: Dictionary in beat.get("choice", {}).get("options", []):
		result.append({"id": option["id"], "text": option["text"], "tag": str(option.get("tag", "")), "available": requirement_met(option.get("requires", {}))})
	return result


func has_choice(beat: Dictionary) -> bool:
	return not beat.get("choice", {}).get("options", []).is_empty()


## Hikaye koşulu + döviz birikimi (`savings_min`: {FED: kuruş}) sağlanıyor mu?
func requirement_met(requires: Dictionary) -> bool:
	if not career.story.matches(requires):
		return false
	var savings: Dictionary = requires.get("savings_min", {})
	for code: Variant in savings.keys():
		if int(career.household.savings.get(str(code), 0)) < int(savings[code]):
			return false
	return true


## `tags` sırasıyla ilk uygun etiketli seçenek; yoksa "honest" etiketli, o da yoksa ilk uygun seçenek. Boş = seçenek yok.
func pick_option(beat: Dictionary, tags: Array) -> String:
	var available := options(beat).filter(func(option: Dictionary) -> bool: return option["available"])
	for tag: Variant in tags:
		for option: Dictionary in available:
			if option["tag"] == tag:
				return str(option["id"])
	for option: Dictionary in available:
		if option["tag"] == "honest":
			return str(option["id"])
	return "" if available.is_empty() else str(available[0]["id"])


## Seçimi uygular. Dönen: {"ok", "story_minor"}. Seçenek yoksa ya da koşulu sağlanmıyorsa ok=false.
func choose(beat: Dictionary, option_id: String) -> Dictionary:
	for option: Dictionary in beat.get("choice", {}).get("options", []):
		if option["id"] == option_id:
			if not requirement_met(option.get("requires", {})):
				return {"ok": false, "story_minor": 0}
			return {"ok": true, "story_minor": apply_effects(option.get("effects", {}))}
	return {"ok": false, "story_minor": 0}


## Seçimsiz olay çözülürken olayın kendi etkileri (örn. Hayri'nin hediyesi).
func resolve_plain(beat: Dictionary) -> int:
	return apply_effects(beat.get("effects", {}))


## Oyuncu karar verdi: olayın `on_decision` etkilerini uygular. Dönen: nakde girecek zarf (kuruş).
func on_decision(beat_id: String, decision: String) -> int:
	for beat: Dictionary in day_def.get("beats", []):
		if beat["id"] == beat_id:
			return apply_effects(beat.get("on_decision", {}).get(decision, {}))
	return 0


## Etkileri uygular. Dönen: `cash_pl` (kuruş).
func apply_effects(effects: Dictionary) -> int:
	var flags: Dictionary = effects.get("flags", {})
	for id: Variant in flags.keys():
		career.story.set_flag(str(id), bool(flags[id]))
	var counters: Dictionary = effects.get("counters", {})
	for id: Variant in counters.keys():
		career.story.add(str(id), int(counters[id]))
	var savings: Dictionary = effects.get("savings", {})
	for code: Variant in savings.keys():
		career.household.savings[str(code)] = maxi(0, int(career.household.savings.get(str(code), 0)) + int(savings[code]))
	if effects.has("mood"):
		career.household.mood = clampi(career.household.mood + int(effects["mood"]), 0, 100)
	return Money.units(int(effects.get("cash_pl", 0)))


## Gizli kâr (patronun kesintisi) bu olaylarla açıldıysa vardiyanın kesinti tutarı (kuruş), değilse 0.
func skim_minor() -> int:
	return career.skim_amount_minor()


func _beat_index(beat_id: String) -> int:
	var index := 0
	for beat: Dictionary in day_def.get("beats", []):
		if beat["id"] == beat_id:
			return index
		index += 1
	return index
