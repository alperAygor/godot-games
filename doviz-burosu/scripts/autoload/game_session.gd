extends Node
## Oyun oturumu: sahneler arasında taşınan kariyer ve biten vardiya, kayıt/devam.
## Kayıt `SaveManager.data["career"]` içinde tutulur. Her SABAH kaydedilir (vardiya ortasında uygulama kapanırsa o günün sabahına dönülür).
## 15 gün oynanır; Gün LAST_PLAYABLE_DAY sonunda oyun bayraklara göre bir sonla biter (Endings).

const SAVE_KEY := "career"
const LAST_PLAYABLE_DAY := 15
const ENDINGS_KEY := "endings_seen"

## Testlerde kısaltılabilir; varsayılan LAST_PLAYABLE_DAY.
var last_playable_day := LAST_PLAYABLE_DAY
## Hikaye olayları vardiyalara karışsın mı (testler arayüz akışını hikayesiz sınamak için kapatabilir).
var story_enabled := true
var office_enabled := true
## Masaya iğnelenen kural notları (kural kimlikleri; yalnızca oturum boyunca, kayda girmez).
const MAX_PINS := 3
var pinned_rules: Array = []
var career: Career
## Çalışan mod koşusu (Günün Kuru / Sonsuz); hikaye oynanırken null.
var mode: ModeRun = null
## Bitmiş koşunun sonucu (sonuç ekranı okur): {"kind", "score", "best", "new_best", "official", "date", "correct", "mistakes", "seconds_left", "served", "rules_added"}.
var mode_result: Dictionary = {}
## Az önce biten vardiya (akşam ekranı okur).
var shift: Shift


## Mod kayıtları (SaveManager.data["modes"]); hikaye kaydından bağımsızdır.
func modes() -> ModeStore:
	if not (SaveManager.data.get("modes") is Dictionary):
		SaveManager.data["modes"] = {}
	return ModeStore.new(SaveManager.data["modes"])


func mode_unlocked(kind: String) -> bool:
	return modes().is_unlocked(kind)


## Günün Kuru'nu başlatır (resmi deneme kalmadıysa puansız alıştırma). `date` boşsa bugün (UTC).
func start_daily(date := "") -> void:
	var date_text := date if not date.is_empty() else DailyChallenge.date_key()
	var official := modes().start_daily_attempt(date_text)
	SaveManager.save_game()
	mode = DailyChallenge.new(date_text, official)
	_enter_mode()


func start_endless(seed_key := "") -> void:
	mode = EndlessRun.new(seed_key if not seed_key.is_empty() else str(Time.get_ticks_usec()))
	_enter_mode()


func _enter_mode() -> void:
	Analytics.log_event("mode_start", {"kind": mode.kind})
	career = mode.career
	shift = null
	mode_result = {}


## Koşuyu yarıda bırakır (duraklatma > ana menü). Resmi deneme zaten harcanmıştır, skor kaydedilmez.
func abort_mode() -> void:
	mode = null
	career = null
	shift = null


## Koşu bitti: skoru kaydeder ve `mode_result`u doldurur. Dönen: sonuç sözlüğü.
func finish_mode() -> Dictionary:
	var store := modes()
	var result := {"kind": mode.kind, "score": mode.score_value(), "new_best": false, "official": true}
	if mode is DailyChallenge:
		var daily := mode as DailyChallenge
		result["date"] = daily.date
		result["official"] = daily.official
		result["correct"] = int(daily.shift.stats["correct"])
		result["mistakes"] = int(daily.shift.stats["mistake_transactions"])
		result["seconds_left"] = int(daily.shift.seconds_left())
		if daily.official:
			result["new_best"] = store.record_daily(daily.date, int(result["score"]))
		result["best"] = maxi(store.best_daily(daily.date), 0)
		result["attempts_left"] = store.official_attempts_left(daily.date)
	else:
		var endless := mode as EndlessRun
		result["served"] = endless.served
		result["rules_added"] = endless.added_rules.duplicate()
		result["can_continue"] = endless.lives <= 0 and endless.continues_used < 1
		result["new_best"] = store.record_endless(endless.served)
		result["best"] = store.endless_best()
	SaveManager.save_game()
	mode_result = result
	return result


# --- Isıtma (arka planda ön yükleme) -------------------------------------------------------------------

## Açılışta menü beklerken sahneler ve büyük betikler arka plan iş parçacıklarında yüklenir; ilk masa/gazete geçişinde
## betik derleme/okuma takılması olmaz. Yüklenenler tutulur (zayıf önbellek bırakırdı); toplamı birkaç yüz KB.
const WARM_PATHS := [
	"res://scenes/desk.tscn", "res://scenes/morning.tscn", "res://scenes/evening.tscn", "res://scenes/game_over.tscn",
	"res://scenes/mode_result.tscn", "res://scenes/market.tscn", "res://scenes/settings.tscn",
	"res://scripts/ui/desk_screen.gd", "res://scripts/ui/booth_view.gd", "res://scripts/ui/customer_figure.gd",
	"res://scripts/ui/speech_bubble.gd", "res://scripts/ui/atmosphere.gd", "res://scripts/ui/stamp_button.gd",
	"res://scripts/ui/note_tile.gd", "res://scripts/ui/doc_tile.gd", "res://scripts/ui/banknote_view.gd",
	"res://scripts/ui/face_view.gd", "res://scripts/ui/desk_surface.gd", "res://scripts/ui/morning_screen.gd",
	"res://scripts/ui/evening_screen.gd",
]
var _warm_pending: Array[String] = []
var _warm_resources: Array[Resource] = []


func _ready() -> void:
	set_process(false)
	if Feel.instant or DisplayServer.get_name() == "headless":
		return
	for path: String in WARM_PATHS:
		if ResourceLoader.exists(path):
			ResourceLoader.load_threaded_request(path, "", true)
			_warm_pending.append(path)
	set_process(not _warm_pending.is_empty())


func _process(_delta: float) -> void:
	for path in _warm_pending.duplicate():
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_warm_resources.append(ResourceLoader.load_threaded_get(path))
			_warm_pending.erase(path)
		elif status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_warm_pending.erase(path)
	if _warm_pending.is_empty():
		set_process(false)


func _exit_tree() -> void:
	_warm_resources.clear()


func has_save() -> bool:
	return SaveManager.data.get(SAVE_KEY) is Dictionary and not (SaveManager.data[SAVE_KEY] as Dictionary).is_empty()


## Kayıtlı günün numarası (kayıt yoksa 0).
func saved_day() -> int:
	return int((SaveManager.data[SAVE_KEY] as Dictionary).get("day", 0)) if has_save() else 0


func new_game() -> void:
	pinned_rules.clear()
	career = Career.load_default("story")
	career.story_enabled = story_enabled
	career.office_enabled = office_enabled
	shift = null
	save()


## Kayıttan devam eder; kayıt yoksa false.
func continue_game() -> bool:
	if not has_save():
		return false
	career = Career.load_default("story")
	career.story_enabled = story_enabled
	career.office_enabled = office_enabled
	career.load_dict(SaveManager.data[SAVE_KEY])
	shift = null
	return true


func save() -> void:
	if career != null:
		SaveManager.data[SAVE_KEY] = career.to_dict()
		SaveManager.save_game()


func clear() -> void:
	SaveManager.data.erase(SAVE_KEY)
	SaveManager.save_game()
	career = null
	shift = null


## Oyun bitti mi (oyun içi son, ya da son gün geçildi)?
func is_finished() -> bool:
	return career != null and (career.is_over() or career.day > last_playable_day)


## Şu anki duruma göre açılacak sahne: oyun bittiyse bitiş ekranı, değilse o günün sabahı.
func route() -> String:
	return Scenes.GAME_OVER if is_finished() else Scenes.MORNING


## Görülen sonlar (kimlikler). Kayıttan bağımsız tutulur: yeni oyun bunları silmez.
func endings_seen() -> Array[String]:
	var seen: Array[String] = []
	for ending_id: Variant in SaveManager.data.get(ENDINGS_KEY, []):
		seen.append(str(ending_id))
	return seen


## Bir sonu "görüldü" diye kaydeder (zaten varsa dokunmaz).
func record_ending(ending_id: String) -> void:
	var seen := endings_seen()
	if ending_id in seen:
		return
	seen.append(ending_id)
	SaveManager.data[ENDINGS_KEY] = seen
	SaveManager.save_game()
